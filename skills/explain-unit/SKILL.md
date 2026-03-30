---
argument-hint: "<unit-number>"
user-invocable: true
model: opus
---

# Explain Unit

Generate a comprehensive explanation of an implemented unit by reviewing the implementation plan, technical requirements, and git history, then writing the output to a markdown file.

## Argument Parsing

Parse `$ARGUMENTS` as follows:

- **First positional argument:** Unit number to explain (e.g., `1`, `3`)

If no unit number is provided, output:
```
Usage: /explain-unit <unit-number>
Example: /explain-unit 3
```
Then stop.

## Setup

1. Extract the unit number N from `$ARGUMENTS`.
2. **Determine the project root** by running `git rev-parse --show-toplevel`. Store this as `$PROJECT_ROOT`. All file paths are relative to this root.
3. Locate the planning documents using these default paths (search up from project root if not found at exact path):
   - **Implementation plan:** `$PROJECT_ROOT/planning-docs-output/phase-7/implementation-plan.md`
   - **Technical requirements:** `$PROJECT_ROOT/planning-docs-output/phase-6/technical-requirements.md`
4. Confirm both files exist. If either is missing, note it and proceed with what is available.

## Phase 1 — Extract Unit Definition from Implementation Plan

Read the implementation plan and extract the full section for unit IU-N:

- Unit name and description
- Owned files and directories
- FR coverage (list of FR identifiers)
- Dependencies (what units must exist before this one)
- Interface contracts (what this unit exports and what it imports)
- Any notes or special requirements

## Phase 2 — Extract FR Details from Technical Requirements

Read the technical requirements document. For each FR identifier found in the unit's FR coverage list, extract:

- The FR title and description
- Any API signatures, database schemas, or data models specified
- Acceptance criteria or validation rules
- Any cross-references to other FRs

## Phase 3 — Search Git History

Run the following command to find all commits related to this unit:

```bash
git -C $PROJECT_ROOT log --all --oneline --format="%h %ad %s" --date=short
```

Filter for commits that mention "Unit N", "IU-N", or the unit name (case-insensitive). For each matching commit, also retrieve the full commit message and file change summary:

```bash
git -C $PROJECT_ROOT show --stat --format="commit %H%nDate: %ad%nAuthor: %an%n%n%s%n%n%b" --date=short <commit-hash>
```

Collect all matching commits with their hashes, dates, messages, and changed files.

## Phase 4 — Generate Explanation

Using the information gathered in Phases 1–3, compose a comprehensive explanation document with the following sections:

---

### Document Structure

```markdown
# Unit N: [Unit Name]

> **Status:** Implemented
> **FR Coverage:** [comma-separated FR identifiers]
> **Dependencies:** [units this depends on, or "None"]

## Overview

[2–3 paragraphs explaining what this unit is, what problem it solves, and its role in the overall system architecture. Be specific about the technology used and its position in the data/request flow.]

## Functionality Implemented

[Bullet list of features implemented, each mapped to its FR identifier. Group by logical area if the unit spans multiple concerns.]

- **[Feature name]** (FR X.Y) — [What it does]
- ...

## Implementation Details

[How the unit was built. Cover:]
- Technology stack and frameworks used
- Key architectural patterns (e.g., repository pattern, dependency injection, generator pipeline)
- Important design decisions and why they were made
- Any notable configuration or schema structures
- Non-obvious implementation choices

## Key Files

| File | Purpose |
|------|---------|
| `path/to/file.ext` | [What it contains and does] |
| ... | ... |

## Integration Points

### This Unit Provides
[What other units can use from this unit — exports, APIs, database tables, etc.]

### This Unit Depends On
[What must exist before this unit works — from other units or external systems]

## Usage Guide

[How a developer interacts with this unit in the context of the project. Include:]
- How to run or invoke the functionality (API calls, CLI commands, imports)
- Example usage with actual code or command snippets where helpful
- Key configuration or environment variables
- How to verify the unit is working correctly

## Git History

| Commit | Date | Message |
|--------|------|---------|
| `[hash]` | YYYY-MM-DD | [message] |
| ... | ... | ... |
```

---

Write the explanation using the actual content gathered. Do not leave placeholder text — every section must contain real information synthesized from the planning documents and git history. If information for a section is sparse, write what you can and note that the section reflects what is documented.

## Phase 5 — Write Output File

1. Ensure the `explain-units/` directory exists at `$PROJECT_ROOT/explain-units/`. Create it if it does not exist.
2. Write the explanation to `$PROJECT_ROOT/explain-units/unit-N.md` (e.g., `unit-3.md` for unit 3).
3. Overwrite if the file already exists.

## Completion

Report to the user:

```
Unit N explanation written to: explain-units/unit-N.md

Sections completed:
  ✓ Overview
  ✓ Functionality Implemented  ([count] features across [count] FRs)
  ✓ Implementation Details
  ✓ Key Files  ([count] files documented)
  ✓ Integration Points
  ✓ Usage Guide
  ✓ Git History  ([count] commits found)
```

If any section could not be fully populated due to missing documentation, note it.
