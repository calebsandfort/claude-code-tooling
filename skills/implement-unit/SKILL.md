---
argument-hint: "<unit-number> [--plan <path>] [--spec <path>]"
user-invocable: true
model: opus
---

# Implement Unit — TDD Orchestrator

You are orchestrating a test-driven implementation workflow for a single implementation unit from a Phase 7 implementation plan. Each specialist agent writes tests for its own domain, then implements to pass them.

## Argument Parsing

Parse `$ARGUMENTS` as follows:

- **First positional argument:** Unit number to implement (e.g., `1`, `3`)
- **`--plan <path>`:** Path to the Phase 7 implementation plan (default: look for `implementation-plan.md` in the current directory or nearest `-output/phase-7/` directory)
- **`--spec <path>`:** Path to the Phase 6 technical spec (default: look for `technical-requirements.md` in the nearest `-output/phase-6/` directory)

Example: `/implement-unit 3 --plan ./output/phase-7/implementation-plan.md`

## Setup

1. Read the implementation plan and locate the target unit section
2. Read the technical spec for full FR context (if the unit's Requirements section is complete, the spec is supplementary)
3. Read the project's `AGENTS.md` for tech stack and conventions
4. Extract from the unit definition:
   - **Owned files** — what this unit creates
   - **FR coverage** — which requirements to implement
   - **Interface contracts** — exports this unit must satisfy and imports it depends on
   - **Dependencies** — what must already exist
5. **Determine the project root** by locating the directory containing `docker-compose.yml`, `frontend/`, and `backend/`. Store this as `$PROJECT_ROOT`. All file paths and commands are relative to this root.
6. Determine which specialist agents are needed based on the owned files:
   - Files in `frontend/src/db/schema/` or backend SQL → `drizzle-db` agent
   - Files in `frontend/src/lib/schemas/` (Zod) → `zod-validation` agent
   - Files in `backend/src/schemas/` (Pydantic) → `zod-validation` agent (handles both Zod and Pydantic)
   - Files in `backend/src/routers/` or `backend/src/services/` → `fastapi-backend` agent
   - Files in `backend/src/agents/` (LangGraph) → `langgraph-agent` agent
   - Files in `frontend/src/components/` or `frontend/src/app/` → `react-frontend` agent
   - Files in `frontend/src/hooks/` → `react-frontend` agent
   - Files in `api/` (ASP.NET Core) → `dotnet-api` agent
7. **Create dependency stubs.** Check that files listed in "Interface Contract — Imports" exist. If missing, create minimal stub files that export only the type definitions and interfaces needed for imports to resolve. Stubs contain ONLY type exports — no logic, no implementations.
8. **Determine the implementation order** based on dependency relationships within the unit:
   1. Database schemas and migrations (foundation — other code imports these types)
   2. Validation schemas — Pydantic models (backend) and Zod schemas (frontend)
   3. Service layer functions (business logic)
   4. API route handlers (wire services to HTTP)
   5. React components and hooks (consume API contracts)

   Assign each owned file to a step. Each step maps to exactly one specialist agent invocation.

## Phase 1 — TDD Implementation (Sequential)

For each step in the implementation order, launch an Agent with the appropriate specialist agent using the `subagent_type` parameter.

## Agent Invocation Syntax

When invoking specialist agents, use this exact format:
```
Agent with:
  - subagent_type: <agent-slug>  (e.g., "react-frontend", "langgraph-agent", "fastapi-backend", "drizzle-db", "zod-validation")
  - subject: <detailed prompt with FR requirements, TDD instructions, and test commands>
  - model: sonnet
```

Available specialist agents:
| Agent Slug | Purpose |
|------------|---------|
| `drizzle-db` | Database schemas and migrations |
| `zod-validation` | Zod and Pydantic validation schemas |
| `fastapi-backend` | API routes and services |
| `langgraph-agent` | LangGraph nodes and workflows |
| `react-frontend` | React components, hooks, pages |
| `dotnet-api` | ASP.NET Core endpoints, Dapper queries, services |

Each Agent prompt MUST include:

1. The specific FR requirements being implemented (copied from the unit definition)
2. Any files already created in prior steps of this phase (read them and include their content — agents cannot access files from prior Tasks)
3. The interface contracts this code must satisfy
4. The project's `AGENTS.md` for conventions
5. **The TDD instruction block** (see below)
6. **The exact test commands** (see below)

### TDD Instruction Block

Include this verbatim in every specialist agent Agent prompt:

```
## TDD Process

You MUST follow this test-driven development process:

### Step 1: Write Tests First
Before writing any implementation code, write the test file(s) for your domain.

Test file locations:
- Frontend TypeScript: colocate as `<filename>.test.ts` next to the source file
- Backend Python: place in `backend/tests/test_<module>.py`

Test requirements:
- Name each test after the FR it verifies: `test_fr_4_1_...` or `it('FR 4.1 — ...')`
- Every FR sub-item assigned to you must have at least one test
- Mock all external dependencies (other units, LLM calls, database connections)
- Test boundary conditions for any thresholds specified in the FRs
- Tests must be deterministic — no random values, no real API calls

CRITICAL: Only write test files in this step. Do NOT create implementation files yet.

### Step 2: Verify Tests Fail
Run the tests to confirm they fail (red phase). This validates that your tests are actually testing something. Expect import errors and missing module errors — that is correct at this stage.

### Step 3: Write Implementation
Now write the implementation files to make the tests pass.

### Step 4: Verify Tests Pass
Run the tests again. If any fail, fix the implementation (not the tests) and re-run.

IMPORTANT: If a test fails because the test itself used an incorrect API or convention for the library being tested, you MAY fix the test. But document what you changed and why in a comment: `// Fixed: Drizzle uses X not Y`.
```

### Test Commands

Include the exact commands in every Agent prompt. The agent MUST use these exact commands — no variations.

```
## Test Commands

CRITICAL: Use these EXACT commands. Do not modify them.

For frontend (TypeScript/Vitest) tests:
  cd $PROJECT_ROOT/frontend && npx vitest run --reporter=verbose <test-file-relative-path>

For backend (Python/Pytest) tests:
  cd $PROJECT_ROOT/backend && python -m pytest <test-file-relative-path> -v

For api (C#/dotnet) tests:
  cd $PROJECT_ROOT/api && dotnet test --verbosity normal

IMPORTANT:
- Always `cd` to the correct directory FIRST, then run the test command.
- Frontend tests: ALWAYS cd to `$PROJECT_ROOT/frontend`
- Backend tests: ALWAYS cd to `$PROJECT_ROOT/backend`
- API tests: ALWAYS cd to `$PROJECT_ROOT/api`
- Never run test commands from the wrong directory.
- <test-file-relative-path> is relative to the frontend/ or backend/ directory, NOT the project root.
  Example: cd $PROJECT_ROOT/frontend && npx vitest run --reporter=verbose src/db/schema/trading.test.ts
  Example: cd $PROJECT_ROOT/backend && python -m pytest tests/test_trade_schema.py -v
  Example: cd $PROJECT_ROOT/api && dotnet test --verbosity normal
```

Replace `$PROJECT_ROOT` with the actual resolved absolute path before including in the prompt.

### Agent Invocation Sequence

For each step, the orchestrator:

1. Launches the specialist agent Agent with FR requirements + TDD instructions + test commands
2. Waits for the Agent to complete
3. Reads the files created by the agent (both test files and implementation files)
4. Includes those files in the next agent's Agent prompt (agents cannot read files from prior Tasks)

Steps are **sequential** — each step may depend on files created in prior steps.

## Phase 2 — Full Verification

After all specialist agent Agents complete:

1. **Run ALL test files created during Phase 1** using the exact commands specified above. Run frontend and backend tests separately:

   ```bash
   # Frontend tests — run ONLY from frontend directory
   cd $PROJECT_ROOT/frontend && npx vitest run --reporter=verbose

   # Backend tests — run ONLY from backend directory
   cd $PROJECT_ROOT/backend && python -m pytest tests/ -v

   # API tests — run ONLY from api directory
   cd $PROJECT_ROOT/api && dotnet test --verbosity normal
   ```

   Only run the commands that apply. If the unit has no frontend files, skip the frontend command. Same for backend and api.

2. **If all tests pass:** Proceed to the Completion phase.

3. **If tests fail (attempt 1 of 3):**
   - Collect the failing test names, error messages, and stack traces
   - Determine which test file contains the failure
   - Determine which specialist agent owns the domain (based on the file mapping from Setup)
   - Launch a fix Agent with that specialist agent using `subagent_type`, providing:
     - The full test output (stdout and stderr)
     - The content of the failing test file
     - The content of the implementation file to fix
     - The FR requirements relevant to the failing tests
     - Instructions: "Fix the implementation to make the failing tests pass. If a test is using an incorrect library API or convention, you may fix the test — but add a comment explaining the correction."
     - The exact test commands (same block as above)
   - After the fix Agent completes, re-run the full test suite (step 1)

4. **Repeat** step 3 up to 3 total attempts (initial run + 2 retries).

5. **If tests still fail after 3 attempts:** Proceed to Completion with the failure report.

## Completion

Output a summary report:

```
Unit <N> Implementation Report
==============================

Status: PASS | PARTIAL | FAIL

Tests:
  Total:    <count>
  Passing:  <count>
  Failing:  <count>
  Skipped:  <count>

Files Created:
  - <file-path> (FR X.Y) [test]
  - <file-path> (FR X.Y) [implementation]
  ...

Verification:
  Attempts: <1-3>
  Final result: <pass/fail>

[If PARTIAL or FAIL:]
Unresolved Issues:
  1. <test-name>: <error-summary>
     File: <implementation-file>
     FR: <relevant-FR-number>
     Likely cause: <brief analysis>

  2. ...

[If dependency stubs were created:]
Dependency Stubs (replace when upstream units are implemented):
  - <stub-file-path> (provides types for Unit <N>)
```

## Important Notes

- Each specialist agent writes BOTH tests and implementation for its domain — there is no separate test-writing phase
- ALWAYS use sequential task execution within a unit — implementation steps depend on prior steps
- If any specialist agent is not available, fall back to the base Claude Code agent with the relevant FR requirements, TDD instructions, and test commands
- Use `model: sonnet` for specialist agent Agents
- Include the full content of referenced files in Agent prompts (agents cannot read files from prior Tasks)
- The TDD instruction block and test commands block MUST be included verbatim in every specialist agent Agent prompt — do not paraphrase or abbreviate them
- If dependency stubs were created in Setup, note them in the completion report
- **Never run test commands from the wrong directory.** Frontend tests run from `$PROJECT_ROOT/frontend`. Backend tests run from `$PROJECT_ROOT/backend`. This is the most common source of tool call failures.
