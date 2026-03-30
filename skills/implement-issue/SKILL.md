---
name: implement-issue
argument-hint: "<issue-id>"
user-invocable: true
---

# Implement Issue

To execute a Linear issue implementation by fetching the issue and its plan, implementing in an isolated git worktree, collecting feedback, committing, pushing to main, and marking the issue Done in Linear.

## Step 1 — Parse Arguments

Extract the issue ID from `$ARGUMENTS`. If no argument is provided, ask the user for the issue ID before proceeding.

Validate that the issue ID looks like a valid Linear ID (e.g., `PRO-8`, `ABC-123`).

## Step 2 — Fetch Issue

Call `mcp__linear__get_issue` with the issue ID, including attachments.

Display a concise summary to the user:
- **Title**
- **Status**
- **Priority**
- **Branch**: the `gitBranchName` field or note that it will be derived

## Step 3 — Extract Implementation Plan

Check the issue's `attachments` array for a file named `Implementation-Plan.md`.

**If found:**
1. Call `mcp__linear__get_attachment` to fetch the attachment content
2. Decode the base64 content to get the plan markdown
3. Use this plan as the implementation guide

**If not found:**
1. Use the issue `description` field as the implementation source
2. Inform the user that no plan attachment was found, falling back to description

Display the plan source (attachment filename or description) and the key phases/steps to the user.

## Step 4 — Setup Worktree

Extract `gitBranchName` from the issue. If not set, derive a branch name using the format:
```
{issueIdLower}-{slugified-title}
```
Where the title is slugified by:
- Converting to lowercase
- Replacing spaces with hyphens
- Removing non-alphanumeric characters except hyphens
- Limiting to 60 characters

Call `EnterWorktree` with the branch name to create an isolated environment.

Confirm the worktree is active before proceeding.

## Step 5 — Execute Implementation

Implement the plan steps using the appropriate subagents or direct tool use.

Track progress through the plan checklist items:
- For each phase, complete the steps as specified
- If the plan references specific files or code changes, create/modify those files
- If the plan calls for launching agents, use the Agent tool with appropriate subagent types

Report progress after each major phase.

## Step 6 — Collect Feedback

**Always** call `AskUserQuestion` to request feedback, regardless of implementation outcome.

Ask the user:
- Whether the implementation meets their expectations
- If there are any changes or refinements needed
- If they approve proceeding to commit

**If feedback is provided:**
1. Incorporate the feedback into the implementation
2. Make the necessary changes
3. Loop back to Step 6 to re-collect feedback

**If user approves (no further feedback):**
Proceed to Step 7.

## Step 7 — Commit, Merge, and Push

If the user approves feedback, or if the user confirms to proceed without changes:

1. Stage all changes in the worktree: `git add -A`
2. Create a commit with a message referencing the Linear issue ID:
   ```
   feat: implement {issueId}

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   ```
3. Exit the worktree and return to main: `ExitWorktree` with `action: "keep"`
4. Merge the worktree branch into main: `git merge {branchName} --no-edit`
5. Delete the worktree branch: `git branch -d {branchName}`
6. Push main to remote: `git push origin main`

Proceed to Step 8.

**If the user does NOT approve and wants to abort:**
1. Call `ExitWorktree` with `action: "remove"` to discard changes and remove the branch
2. Report the abortion
3. Stop here — do not proceed to Step 8 or Step 9

## Step 8 — Mark Issue Done

Call `mcp__linear__save_issue` with:
- `id`: the issue ID
- `state`: `"Done"`

## Step 9 — Completion Summary

Output a clear completion summary:

```
Implemented issue {issueId}: {title}
- Plan source: {attachmentName or "issue description"}
- Pushed to origin/main
- Linear issue marked Done
```
