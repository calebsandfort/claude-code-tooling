---
argument-hint: "[hlrd-path] [sme-1] [sme-2] [sme-N...] [--tech-stack <path>]"
user-invocable: true
disable-model-invocation: true
model: opus
---

# Elaborate Requirements — Multi-Agent Orchestrator

You are orchestrating a multi-phase requirements elaboration workflow. This workflow transforms a High-Level Requirements Document (HLRD) into a detailed, SHALL-style technical requirements document through collaborative SME consultation.

## Argument Parsing

Parse `$ARGUMENTS` as follows:

- **First positional argument:** Path to the HLRD file
- **Remaining positional arguments:** SME agent slugs to invoke (e.g., `behavioral-psychology-sme`, `ai-nlp-sme`, `data-analytics-sme`)
- **`--tech-stack <path>`:** Optional flag specifying a tech stack reference file for Phase 6

Example: `/elaborate-requirements ./requirements.md behavioral-psychology-sme ai-nlp-sme data-analytics-sme --tech-stack ./AGENTS.md`

## Setup

1. Read the HLRD at the provided path
2. Determine the output directory: create a sibling directory named `<hlrd-parent-dir>-output/` next to the HLRD's parent directory. For example, if the HLRD is at `./project/requirements.md`, the output directory is `./project-output/`.
3. Create the output directory and all phase subdirectories: `phase-1/`, `phase-2/`, `phase-3/`, `phase-4/`, `phase-5/`, `phase-6/`, `phase-7/`
4. Read `~/.claude/agents/AGENTS.md` to load SME tag-to-agent-slug mappings

## Phase 1 — SME Analysis (Parallel)

Launch one Task per SME agent specified in the arguments, **all in parallel**.

Each Task should use:
- `subagent_type`: the SME agent slug (e.g., `behavioral-psychology-sme`)

Each Task prompt MUST include:
1. The full HLRD content (read it and include it in the prompt)
2. The list of all participating SME agents with their names and domains
3. Instructions to answer all `[SME:*]` questions matching their tag
4. Instructions to include a `## Questions for Other SMEs` section
5. The output file path
6. **If `--tech-stack` was provided, include the full tech stack file content with instructions: "The following tech stack is already established for this project. Constrain all technology recommendations to this stack. Do not recommend alternative tools for capabilities the stack already covers."**

Wait for all Phase 1 Tasks to complete before proceeding.

## Phase 2 — Cross-SME Consultation (Sequential orchestration, parallel execution)

### Step 2a — Question Routing (Sequential)

Launch a single Task with the `product-manager` agent:
- Provide paths to all Phase 1 analysis files
- Instruct it to extract cross-SME questions from each analysis
- Instruct it to write a questions file per target SME: `<output-dir>/phase-2/<agent-slug>-questions.md`
- Each questions file should group questions by asking SME with full context

Wait for the PM Task to complete.

### Step 2b — SME Answers (Parallel)

Read the output directory to check which SMEs received questions (which `*-questions.md` files were created).

For each SME that has a questions file, launch a Task **in parallel**:
- Use the SME's agent slug as `subagent_type`
- Provide the path to their questions file
- Provide paths to all Phase 1 analyses for context
- Instruct them to write answers to `<output-dir>/phase-2/<agent-slug>-answers.md`

Wait for all SME answer Tasks to complete before proceeding. If no cross-SME questions exist, skip Step 2b.

## Phase 3 — PM Synthesis (Sequential)

Launch a single Task with the `product-manager` agent:
- Provide the original HLRD path
- Provide paths to ALL Phase 1 analysis files
- Provide paths to ALL Phase 2 answer files (if they exist)
- **If `--tech-stack` was provided, include the full tech stack file content**
- Instruct it to synthesize everything into a SHALL-style FR/NFR requirements document
- Output path: `<output-dir>/phase-3/requirements-draft.md`

Wait for the PM Task to complete before proceeding.

## Phase 4 — SME Review (Parallel)

Launch one Task per SME agent, **all in parallel**.

Each Task should:
- Use the SME's agent slug as `subagent_type`
- Provide the path to `<output-dir>/phase-3/requirements-draft.md`
- **If `--tech-stack` was provided, include the full tech stack file content**
- Instruct them to review for accuracy, completeness, gaps, and conflicts within their domain
- Output path: `<output-dir>/phase-4/<agent-slug>-review.md`

Wait for all Phase 4 Tasks to complete before proceeding.

## Phase 5 — PM Finalization (Sequential)

Launch a single Task with the `product-manager` agent:
- Provide the path to `<output-dir>/phase-3/requirements-draft.md`
- Provide paths to ALL Phase 4 review files
- **If `--tech-stack` was provided, include the full tech stack file content**
- Instruct it to incorporate feedback, resolve conflicts, and produce the final document
- Output path: `<output-dir>/phase-5/requirements-final.md`

Wait for the PM Task to complete before proceeding.

## Phase 6 — Tech Spec Enrichment (Sequential)

Launch a single Task with the `technical-spec` agent:
- Provide the path to `<output-dir>/phase-5/requirements-final.md`
- If `--tech-stack` was provided, include that file path
- Instruct it to enrich each FR with implementation details (SQL schemas, API signatures, validation schemas, component structure, security considerations)
- Output path: `<output-dir>/phase-6/technical-requirements.md`

Wait for the Task to complete.

## Phase 7 — Implementation Planning (Sequential)

Launch a single Task with the `implementation-planner` agent:
- Provide the path to `<output-dir>/phase-6/technical-requirements.md`
- If `--tech-stack` was provided, include that file path
- Instruct it to decompose the enriched spec into parallelizable implementation units, define interface contracts, and generate a dependency diagram
- Output path: `<output-dir>/phase-7/implementation-plan.md`

Wait for the Task to complete.

## Completion

After all phases complete, output a summary:

```
Requirements elaboration complete.

Output directory: <output-dir>/

Phase outputs:
  - Phase 1 (SME Analysis): <count> analyses
  - Phase 2 (Cross-SME Consultation): <count> Q&A exchanges
  - Phase 3 (Requirements Draft): requirements-draft.md
  - Phase 4 (SME Review): <count> reviews
  - Phase 5 (Final Requirements): requirements-final.md
  - Phase 6 (Technical Spec): technical-requirements.md
  - Phase 7 (Implementation Plan): implementation-plan.md

Final documents:
  - Technical spec: <output-dir>/phase-6/technical-requirements.md
  - Implementation plan: <output-dir>/phase-7/implementation-plan.md
```

## Important Notes

- ALWAYS use parallel Task execution for independent SME operations (Phases 1, 2b, 4)
- ALWAYS wait for dependencies before starting the next phase
- If any Task fails, report the failure and ask the user how to proceed
- Use `model: sonnet` for SME Tasks and `model: opus` for PM and tech spec Tasks
- Use `model: opus` for the implementation planner Task (Phase 7) — it requires cross-cutting architectural analysis
- Include the full content of referenced files in Task prompts (agents cannot read files from prior Tasks)
