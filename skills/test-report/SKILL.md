---
argument-hint: "[--folders <frontend,backend,api>]"
user-invocable: true
name: test-report
description: Run tests sequentially across frontend, backend, and api monorepo folders and write a timestamped Markdown report to test-reports/. Use when the user wants a test health report, test results summary, or coverage overview across all projects.
---

# Unit Test Report Skill

Generate a comprehensive test report for a mixed-language monorepo by running tests sequentially across `frontend/`, `backend/`, and `api/` root-level folders, then writing a timestamped Markdown report to `test-reports/`.

## Argument Parsing

Parse `$ARGUMENTS` as follows:

- **`--folders <list>`:** Comma-separated folder list to scan (default: `frontend,backend,api`)

Example: `/test-report` or `/test-report --folders=frontend,api`

## Execution

Run the test report script from the **current working directory** (the user's project root):

```bash
bash ~/.claude/skills/test-report/test-report.sh [--folders <list>]
```

Pass any `$ARGUMENTS` through to the script verbatim.

## Output

After the script completes:

1. Display the path to the generated report file
2. Show the full Markdown report content to the user using the Read tool
3. Summarize overall results: total pass/fail counts and aggregate coverage

## Error Handling

- If the script exits with a non-zero code, display the error output and report which project(s) failed
- If no test-capable projects are found, inform the user and suggest checking the folder structure
- If the `test-reports/` directory cannot be created, report the permission error
