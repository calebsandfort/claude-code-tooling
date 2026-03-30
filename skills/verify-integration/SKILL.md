---
argument-hint: "<unit-numbers...> [--plan <path>] [--tech-spec <path>]"
user-invocable: true
disable-model-invocation: true
model: opus
---

# Verify Integration — Contract Test Generator

You generate and run contract tests that verify the integration seams between implementation units after they are merged onto the same branch. These tests confirm that units satisfy each other's interface contracts — that real exports match real imports, with no mocks at the boundary.

## Argument Parsing

Parse `$ARGUMENTS` as follows:

- **Positional arguments:** Unit numbers that were just merged (e.g., `2 3 4`)
- **`--plan <path>`:** Path to the Phase 7 implementation plan (default: look for `implementation-plan.md` in the current directory or nearest `*-output/phase-7/` directory)
- **`--tech-spec <path>`:** Path to the Phase 6 technical requirements document (default: look for `technical-requirements.md` in the nearest `*-output/phase-6/` directory)

Example: `/verify-integration 2 3 4 --plan ./output/phase-7/implementation-plan.md --tech-spec ./output/phase-6/technical-requirements.md`

## What Contract Tests Are

Contract tests verify the **handshake points** between units — the places where one unit's real output becomes another unit's real input. They are NOT:

- Unit tests (those already exist inside each unit)
- End-to-end tests (no running database, no HTTP server, no LLM calls)
- Regression tests (they don't test business logic)

They ARE:

- Import tests: "Can Unit B actually import the function Unit A exports?"
- Shape tests: "Does Unit A's output satisfy Unit B's input validation?"
- Wiring tests: "Is the router/provider/component actually registered in the app's entry point?"

## Setup

1. Read the implementation plan and extract for each specified unit:
   - Interface Contract — Exports
   - Interface Contract — Imports
   - Owned files
   - FR Coverage
   - Dependencies (which other units it depends on)

2. Read the Phase 6 technical requirements document. For each FR covered by the specified units:
   - Extract the intended component/file structure (exact filenames and paths)
   - Extract the functional integration intent (what the user should experience when units are connected)
   - Extract any technical implementation details (props, API signatures, data flow)
   - Build a **wiring checklist** per unit: for each FR, what components/routes/providers must exist and be registered where

   Cross-reference the tech spec against the implementation plan. If the tech spec names a file or component that no specified unit's "Owns" list claims, record it as a **coverage gap** to surface in the final report.

3. **Determine the project root** by locating the directory containing `docker-compose.yml`, `frontend/`, and `backend/`. Store as `$PROJECT_ROOT`.

4. **Map the integration seams.** For every import listed across the specified units, find the corresponding export in another unit. Each import-export pair is a seam that needs a contract test. Only generate tests for seams where BOTH sides are present (both units have been merged).

5. **Map wiring requirements.** For each specified unit, identify:
   - **Registrable artifacts** it creates — files containing `APIRouter()`, middleware classes, LangGraph graphs, React context providers
   - **Entry-point files** where those artifacts must be registered — `main.py`, central `router.py`, root `layout.tsx`, `page.tsx`, `route.ts`
   - **FR-derived wiring targets** — components/routes named in the tech spec for the unit's FR coverage that must be present and wired

   Only generate wiring tests when both the artifact-owning unit and the entry-point-owning unit are in scope (same rule as interface seams: both sides must be merged).

## Contract Test Categories

### 1. Type Compatibility Tests

Verify that one unit's output type satisfies another unit's input type — without mocks.

```python
# Example: Unit 3 extraction output → Unit 1 Pydantic model
from src.schemas.trade import TradeExtraction
from decimal import Decimal

class TestExtractionToSchemaContract:
    def test_extraction_output_satisfies_trade_model(self):
        """Verify that a realistic extraction result passes TradeExtraction validation."""
        # This is the shape Unit 3's extract_node returns
        raw_extraction = {
            "direction": "long",
            "outcome": "win",
            "pnl": Decimal("500.00"),
            "setup_description": "Pullback entry on NQ",
            "discipline_score": 1,
            "agency_score": 1,
            "confidence_score": 0.92,
            "is_estimated_pnl": False
        }
        # This must not throw — if it does, the contract is broken
        trade = TradeExtraction(**raw_extraction)
        assert trade.direction == "long"
```

```typescript
// Example: Unit 1 Zod schema validates Unit 2 API response shape
import { TradeResponseSchema } from '@/lib/schemas/trade'

describe('API Response Contract', () => {
  it('trade creation response matches Zod schema', () => {
    // This is the shape Unit 2's route handler returns
    const apiResponse = {
      success: true,
      data: {
        trade: {
          id: '550e8400-e29b-41d4-a716-446655440000',
          tradingDayId: '550e8400-e29b-41d4-a716-446655440001',
          timestamp: '2024-01-15T10:30:00Z',
          direction: 'long',
          outcome: 'win',
          pnl: 500,
          setupDescription: 'Pullback entry',
          disciplineScore: 1,
          agencyScore: 1,
          confidenceScore: 0.92,
          isEstimatedPnl: false,
        },
        insights: []
      }
    }
    const result = TradeResponseSchema.safeParse(apiResponse)
    expect(result.success).toBe(true)
  })
})
```

### 2. Function Signature Tests

Verify that one unit can actually call another unit's exported function with the expected arguments and get the expected return type.

```python
# Example: Unit 2 route handler calls Unit 3 extraction function
import inspect
from src.agents.extraction.graph import extract_trade  # or build_extraction_graph

class TestRouteToExtractionContract:
    def test_extract_trade_accepts_string_input(self):
        """Verify the extraction function signature matches what the route calls."""
        sig = inspect.signature(extract_trade)
        params = list(sig.parameters.keys())
        # Route handler calls: extract_trade(description)
        assert 'description' in params or len(params) >= 1

    def test_extraction_result_has_expected_fields(self):
        """Verify ExtractionResult has the fields the route handler reads."""
        from src.schemas.trade import ExtractionResult
        fields = ExtractionResult.model_fields
        assert 'success' in fields
        assert 'trade' in fields
        assert 'error' in fields
```

```python
# Example: Unit 2 route handler calls Unit 4 insights service
from src.services.insights_service import calculate_tilt_risk, detect_positive_patterns

class TestRouteToInsightsContract:
    def test_tilt_risk_returns_integer(self):
        """Verify tilt risk calculation returns int (not float, not dict)."""
        from unittest.mock import MagicMock
        from decimal import Decimal
        trading_day = MagicMock(
            consecutive_losses=2,
            discipline_sum=-1,
            agency_sum=0
        )
        recent_trades = [
            MagicMock(discipline_score=-1, agency_score=0),
            MagicMock(discipline_score=-1, agency_score=-1),
            MagicMock(discipline_score=0, agency_score=0),
        ]
        result = calculate_tilt_risk(trading_day, recent_trades)
        assert isinstance(result, int)
        assert 0 <= result <= 10
```

### 3. Import Resolution Tests

Verify that cross-unit imports actually resolve — no missing modules, no circular dependencies.

```python
class TestCrossUnitImports:
    def test_router_imports_extraction_agent(self):
        """Verify trades router can import extraction graph."""
        from src.routers.trades import router  # Should not raise ImportError
        assert router is not None

    def test_router_imports_insights_service(self):
        """Verify insights router can import insights service."""
        from src.routers.insights import router
        assert router is not None

    def test_insights_service_imports_schemas(self):
        """Verify insights service can import SessionSummary."""
        from src.services.insights_service import calculate_tilt_risk
        from src.schemas.insights import SessionSummary
        assert SessionSummary is not None
```

```typescript
describe('Cross-Unit Imports', () => {
  it('dashboard page imports chart components', async () => {
    const { PnlChart } = await import('@/components/dashboard/pnl-chart')
    expect(PnlChart).toBeDefined()
  })

  it('trade entry imports Zod schema', async () => {
    const { TradeEntrySchema } = await import('@/lib/schemas/trade')
    expect(TradeEntrySchema).toBeDefined()
    expect(TradeEntrySchema.parse).toBeInstanceOf(Function)
  })
})
```

### 4. Wiring Verification Tests

Verify that registrable artifacts (routers, providers, middleware, agents, components) are actually registered in the app's entry points. These tests use file inspection and route table introspection — no running server required.

Tests check both import AND usage. A dead import is not sufficient.

#### 4a. Router Registration (Backend / Python)

Import the FastAPI app or aggregator router and inspect its route table. FastAPI builds `app.routes` at import time, so this proves registration actually executed.

```python
from fastapi.routing import APIRoute

class TestRouterWiring:
    def test_api_router_includes_expected_routes(self):
        """Verify that api_router includes routes from the unit under test."""
        from src.api.router import api_router
        route_paths = [r.path for r in api_router.routes if isinstance(r, APIRoute)]
        assert any("/expected-prefix" in p for p in route_paths), (
            f"Expected route not found in api_router. Found: {route_paths}"
        )

    def test_app_mounts_api_router(self):
        """Verify the main app mounts the api_router."""
        from src.main import app
        route_paths = [r.path for r in app.routes if hasattr(r, 'path')]
        assert any("/api" in p or "/health" in p for p in route_paths), (
            f"Expected api_router routes not found in app. Found: {route_paths}"
        )
```

#### 4b. Agent Endpoint Registration (Backend / Python)

For dynamically registered endpoints (e.g. `add_langgraph_fastapi_endpoint`), inspect `app.routes` after import — dynamic registration still populates the route table at module load time.

```python
class TestAgentWiring:
    def test_langgraph_endpoint_registered(self):
        """Verify the LangGraph agent endpoint is mounted on the app."""
        from src.main import app
        route_paths = [r.path for r in app.routes if hasattr(r, 'path')]
        assert any("copilotkit" in p for p in route_paths), (
            f"Expected copilotkit endpoint not found. Found: {route_paths}"
        )
```

#### 4c. Middleware Registration (Backend / Python)

```python
class TestMiddlewareWiring:
    def test_cors_middleware_registered(self):
        """Verify CORS middleware is registered on the app."""
        from src.main import app
        # Walk the middleware stack string — works across FastAPI versions
        stack = str(app.middleware_stack)
        assert "CORSMiddleware" in stack, (
            f"CORSMiddleware not found in middleware stack: {stack}"
        )
```

#### 4d. Provider Wiring (Frontend / TypeScript)

Read the layout file and regex-check for both the import statement and the JSX tag. Derived from FR-specified component structure in the tech requirements.

```typescript
import { readFileSync } from 'fs'
import { resolve } from 'path'

describe('Provider Wiring', () => {
  const rootLayout = readFileSync(
    resolve(__dirname, '../../../app/layout.tsx'), 'utf-8'
  )

  it('root layout imports CopilotProvider', () => {
    expect(rootLayout).toMatch(/import.*CopilotProvider.*from/)
  })

  it('root layout renders CopilotProvider wrapping children', () => {
    expect(rootLayout).toMatch(/<CopilotProvider[\s>]/)
    expect(rootLayout).toMatch(/\{children\}/)
  })
})
```

#### 4e. Component Rendering in Pages (Frontend / TypeScript)

Derived from the FR-specified component structure in the tech requirements. If FR-1.1 states that `ChatSidebar` must appear in the main layout alongside `VisualizationCanvas`, generate a test for each.

```typescript
describe('Component Wiring', () => {
  it('main page imports and renders ChatSidebar (FR-1.1)', () => {
    const page = readFileSync(
      resolve(__dirname, '../../../app/page.tsx'), 'utf-8'
    )
    expect(page).toMatch(/import.*ChatSidebar.*from/)
    expect(page).toMatch(/<ChatSidebar[\s/>]/)
  })

  it('main page imports and renders VisualizationCanvas (FR-1.1)', () => {
    const page = readFileSync(
      resolve(__dirname, '../../../app/page.tsx'), 'utf-8'
    )
    expect(page).toMatch(/import.*VisualizationCanvas.*from/)
    expect(page).toMatch(/<VisualizationCanvas[\s/>]/)
  })
})
```

#### 4f. API Route Existence (Frontend / TypeScript)

```typescript
import { existsSync, readFileSync } from 'fs'
import { resolve } from 'path'

describe('API Route Wiring', () => {
  it('copilotkit API route file exists', () => {
    const routePath = resolve(__dirname, '../../../app/api/copilotkit/route.ts')
    expect(existsSync(routePath)).toBe(true)
  })

  it('copilotkit API route exports POST handler', () => {
    const routeCode = readFileSync(
      resolve(__dirname, '../../../app/api/copilotkit/route.ts'), 'utf-8'
    )
    expect(routeCode).toMatch(/export\s+(const|async\s+function)\s+POST/)
  })
})
```

## Process

When invoked:

1. Read the implementation plan and extract interface contracts for the specified units
2. Read the Phase 6 technical requirements document. For each FR covered by the specified units, extract intended component/file structure, functional integration intent, and technical implementation details. Build a wiring checklist per unit. Cross-reference against the implementation plan and record any coverage gaps (files or components named in the tech spec that no unit's "Owns" list claims).
3. Determine the project root (`$PROJECT_ROOT`)
4. Map integration seams — every import-export pair between the specified units
5. Map wiring requirements — every registrable artifact and its required entry-point registration, supplemented by FR-derived targets from the tech spec
6. For each seam, determine the test category: type compatibility, function signature, import resolution, or wiring verification
7. Write contract test files:
   - Backend: `$PROJECT_ROOT/backend/tests/integration/test_contract_<unitA>_<unitB>.py`
   - Frontend: `$PROJECT_ROOT/frontend/src/__tests__/integration/contract-<unitA>-<unitB>.test.ts`
   - Wiring tests: `$PROJECT_ROOT/backend/tests/integration/test_contract_wiring.py` and `$PROJECT_ROOT/frontend/src/__tests__/integration/contract-wiring.test.ts`
8. Run the contract tests:
   ```bash
   # Backend contract tests
   cd $PROJECT_ROOT/backend && python -m pytest tests/integration/ -v

   # Frontend contract tests
   cd $PROJECT_ROOT/frontend && npx vitest run --reporter=verbose src/__tests__/integration/
   ```
9. If tests fail, analyze the failure and report which contract is broken and between which units
10. Do NOT auto-fix — contract failures indicate a real mismatch between units that requires human judgment about which side to change

## Completion

Output a report:

```
Integration Verification Report
================================

Units verified: <list>
Seams tested: <count>

Contract Test Results:
  Type Compatibility:   <pass>/<total>
  Function Signatures:  <pass>/<total>
  Import Resolution:    <pass>/<total>
  Wiring Verification:  <pass>/<total>

[If coverage gaps found:]
Coverage Gaps (tech spec names files/components no unit owns):
  - <file or component name>: referenced in <FR-X.Y> but not claimed by any specified unit
    Action required: verify the file exists and is owned by a unit not yet merged, or add it to the plan

[If all tests pass:]
All integration contracts verified. Units are compatible.

[If test failures:]
Broken Contracts:

  1. Unit <A> → Unit <B>: <seam description>
     Test: <test name>
     Error: <error message>
     Analysis: <which side likely needs to change and why>
     Files involved:
       - <Unit A file> (exports)
       - <Unit B file> (imports)

[If wiring failures:]
Broken Wiring:

  1. Unit <A> → Entry Point: <entry point file>
     Test: <test name>
     Error: Router/Provider/Middleware/Component not registered
     Analysis: Unit <A> creates <artifact> but <entry point file> does not reference it
     Fix: Add <specific registration call> to <entry point file>
```

## Important Notes

- Contract tests import REAL modules from BOTH units — no mocks at the integration boundary
- Internal dependencies within a unit CAN still be mocked (e.g., mock the LLM when testing that the extraction function signature matches what the route handler expects)
- Only test seams where both sides are merged — don't test against stubs
- Do NOT auto-fix failures. Contract mismatches require deciding which unit needs to change. Report the analysis and let the developer decide.
- Test files go in dedicated `integration/` subdirectories to keep them separate from unit tests
- These tests should run fast (no database, no HTTP, no LLM) — if a test requires infrastructure, it's an E2E test, not a contract test
- **Conditional wiring limitation:** If registration is behind an `if` guard (e.g. `if settings.enable_feature: app.include_router(...)`), the route may not appear in `app.routes` at test time. Set the relevant environment variable in `conftest.py` to force the branch to execute.
- **Importing `main.py`** triggers all module-level code. If this causes issues (e.g. database connection attempts), add a `conftest.py` fixture that sets `DATABASE_URL` and other required env vars to safe test values before importing.
