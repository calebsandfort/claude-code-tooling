---
name: enhance-issue
description: >
  Enhances a Linear issue by interviewing the user to flesh out the description,
  updating it in Linear, generating an implementation plan, attaching the plan
  to the issue, and setting the status to In Progress. This skill should be used
  when the user wants to enrich and activate a Linear issue for implementation.
user-invocable: true
argument-hint: "<issue-id>"
---

# Enhance Issue

To activate and enrich a Linear issue for implementation by interviewing the user, updating the issue description, generating an implementation plan, attaching it, and marking the issue In Progress.

## Step 1 — Parse Arguments

Extract the issue ID from `$ARGUMENTS`. If no argument is provided, ask the user for the issue ID before proceeding.

## Step 2 — Fetch and Display Issue

Call `mcp__linear__get_issue` with the issue ID.

Display a concise summary to the user:
- **Title**
- **Status**
- **Priority**
- **Current description** (or note if empty)

## Step 3 — Interview User

Use `AskUserQuestion` to gather information needed to write a comprehensive description. Ask all relevant questions in a single prompt to minimize round-trips. Tailor questions to what is missing or vague in the current description.

Core questions to ask (adapt based on existing content):
- What is the desired outcome? How will you know this issue is done?
- What are the specific acceptance criteria or success conditions?
- Are there edge cases, error scenarios, or constraints to address?
- Are there technical approach preferences or patterns to follow / avoid?
- Any dependencies on other issues, systems, or people?

If the answers introduce new ambiguities, do one follow-up round with `AskUserQuestion` before proceeding.

## Step 4 — Generate Enhanced Description

Synthesize the original issue description and the user's interview answers into a comprehensive Markdown description. Structure it as follows:

```markdown
## Summary

[2–4 sentence overview of what this issue accomplishes and why]

## Motivation

[Why this is needed — the problem being solved or value being added]

## Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] ...

## Edge Cases & Constraints

- [Edge case or constraint 1]
- [Edge case or constraint 2]

## Notes

[Technical approach preferences, dependencies, or any other relevant context]
```

## Step 5 — Update Issue Description

Call `mcp__linear__save_issue` with:
- `id`: the issue ID
- `description`: the enhanced description markdown

## Step 6 — Generate Implementation Plan

Write a structured implementation plan in Markdown covering:

```markdown
# Implementation Plan: [Issue Title]

## Overview

[Brief description of the approach]

## Phases

### Phase 1 — [Name]
- [ ] Step 1
- [ ] Step 2

### Phase 2 — [Name]
- [ ] Step 1
- [ ] Step 2

## Files to Create / Modify

| File | Change |
|------|--------|
| `path/to/file` | [What changes] |

## Testing Approach

- [Unit tests: what to cover]
- [Integration tests: what to cover]
- [Manual verification steps]

## Open Questions

- [Any unresolved design or implementation questions]
```

## Step 7 — Attach Implementation Plan

Base64-encode the implementation plan markdown string, then call `mcp__linear__create_attachment` with:
- `issue`: the issue ID
- `base64Content`: the base64-encoded plan
- `filename`: `"implementation-plan.md"`
- `contentType`: `"text/markdown"`
- `title`: `"Implementation Plan"`

## Step 8 — Set Status to In Progress

Call `mcp__linear__save_issue` with:
- `id`: the issue ID
- `state`: `"In Progress"`

## Step 9 — Confirm

Output a brief confirmation message:

```
Enhanced issue [ID]: [Title]
- Description updated with acceptance criteria and context
- Implementation plan attached (implementation-plan.md)
- Status set to In Progress
```
