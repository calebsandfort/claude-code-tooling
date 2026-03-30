# Agent Orchestration

## Available Agents

Located in `~/.claude/agents/`:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| planner | Implementation planning | Complex features, refactoring |
| architect | System design | Architectural decisions |
| tdd-guide | Test-driven development | New features, bug fixes |
| code-reviewer | Code review | After writing code |
| security-reviewer | Security analysis | Before commits |
| build-error-resolver | Fix build errors | When build fails |
| e2e-runner | E2E testing | Critical user flows |
| refactor-cleaner | Dead code cleanup | Code maintenance |
| doc-updater | Documentation | Updating docs |
| product-manager | Requirements synthesis | Requirements elaboration workflow (Phase 2 & 4) |
| technical-spec | Technical specification | Requirements elaboration workflow (Phase 5) |
| behavioral-psychology-sme | Trading psychology SME | Requirements elaboration — behavioral domain |
| ai-nlp-sme | AI/NLP SME | Requirements elaboration — AI/ML domain |
| data-analytics-sme | Data analytics SME | Requirements elaboration — data/analytics domain |
| ai-nlp-sme | AI/NLP SME | Requirements elaboration — AI/ML domain |
| consumer-spending-sme | Consumer spending SME | Requirements elaboration — consumer behavior domain |
| market-analyst-sme | Market analyst SME | Requirements elaboration — market research domain |

## Immediate Agent Usage

No user prompt needed:
1. Complex feature requests - Use **planner** agent
2. Code just written/modified - Use **code-reviewer** agent
3. Bug fix or new feature - Use **tdd-guide** agent
4. Architectural decision - Use **architect** agent

## Parallel Task Execution

ALWAYS use parallel Task execution for independent operations:

```markdown
# GOOD: Parallel execution
Launch 3 agents in parallel:
1. Agent 1: Security analysis of auth.ts
2. Agent 2: Performance review of cache system
3. Agent 3: Type checking of utils.ts

# BAD: Sequential when unnecessary
First agent 1, then agent 2, then agent 3
```

## Multi-Perspective Analysis

For complex problems, use split role sub-agents:
- Factual reviewer
- Senior engineer
- Security expert
- Consistency reviewer
- Redundancy checker

## Requirements Elaboration Workflow

Use `/elaborate-requirements` to transform high-level requirements into implementation-ready specifications.

### 5-Phase Workflow

1. **Phase 1 — SME Analysis (Parallel):** Launch specified SME agents to analyze requirements from their domain perspective
2. **Phase 2 — PM Synthesis (Sequential):** Product Manager synthesizes SME analyses into SHALL-style FR/NFR document
3. **Phase 3 — SME Review (Parallel):** SMEs review the comprehensive document for coverage, corrections, gaps
4. **Phase 4 — PM Finalization (Sequential):** Product Manager incorporates review feedback, resolves conflicts
5. **Phase 5 — Tech Spec Enrichment (Sequential):** Technical Spec agent adds SQL schemas, API signatures, Zod schemas per FR

### SME Agent Library

SME agents follow the naming convention `*-sme.md` in `~/.claude/agents/`. You build a library of SMEs over time and specify which ones to use per invocation as arguments.

### Usage

```
/elaborate-requirements <high-level-doc-path> <sme-1> <sme-2> [sme-N...] [--tech-stack <path>]
```

### Example Invocation

```
/elaborate-requirements ./requirements.md behavioral-psychology-sme ai-nlp-sme data-analytics-sme --tech-stack ./AGENTS.md
```
