#!/usr/bin/env bash
# test-report.sh — Run tests across a monorepo and generate a Markdown report
#
# Usage: test-report.sh [--folders <frontend,backend,api>]
# Output: Writes test-reports/test-report-YYYY-MM-DDTHH-MM-SS.md

set -uo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────

FOLDERS="frontend,backend,api"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --folders=*)
            FOLDERS="${1#--folders=}"
            shift
            ;;
        --folders)
            FOLDERS="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# ── Paths ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT_SCRIPT="${SCRIPT_DIR}/detect-tests.sh"
PROJECT_ROOT="$(pwd)"
REPORTS_DIR="${PROJECT_ROOT}/test-reports"

# ── Helpers ───────────────────────────────────────────────────────────────────

timestamp_local() {
    date "+%Y-%m-%dT%H-%M-%S"
}

timestamp_display() {
    date "+%Y-%m-%d %H:%M:%S %Z"
}

strip_ansi() {
    # Remove ANSI escape codes (color, bold, etc.) from output
    sed 's/\x1B\[[0-9;]*[a-zA-Z]//g; s/\x1B\[[0-9]*m//g; s/\x1B(B//g'
}

parse_node_coverage() {
    local output
    output="$(echo "$1" | strip_ansi)"
    # Jest: "All files | XX.XX | ..."
    # Vitest: "% Stmts | ..." or coverage summary table
    local pct
    pct="$(echo "$output" | grep -E 'All files\s*\|' | awk -F'|' '{gsub(/ /,"",$2); print $2}' | tr -d '%' | head -1)"
    [[ -z "$pct" ]] && pct="$(echo "$output" | grep -E '^\s*All files' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)"
    # Vitest v8 coverage: "Coverage report from v8"
    [[ -z "$pct" ]] && pct="$(echo "$output" | grep -iE '^\s*all\s*\|' | awk -F'|' '{gsub(/ /,"",$2); print $2}' | tr -d '%' | head -1)"
    echo "${pct:-N/A}"
}

parse_dotnet_coverage() {
    local output
    output="$(echo "$1" | strip_ansi)"
    # dotnet test coverage: "Line coverage: XX.X%"
    local pct
    pct="$(echo "$output" | grep -iE 'line coverage' | grep -oE '[0-9]+\.?[0-9]*' | head -1)"
    echo "${pct:-N/A}"
}

parse_python_coverage() {
    local output
    output="$(echo "$1" | strip_ansi)"
    # pytest-cov: "TOTAL    ...   XX%"
    local pct
    pct="$(echo "$output" | grep -E '^TOTAL\s' | awk '{print $NF}' | tr -d '%')"
    echo "${pct:-N/A}"
}

parse_node_counts() {
    local output
    output="$(echo "$1" | strip_ansi)"
    # Jest: "Tests: X failed, Y passed, Z total" or "X passed, Z total"
    # Vitest: "✓ X passed | ✗ Y failed" or "X tests passed"
    local passed failed
    passed="$(echo "$output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1)"
    failed="$(echo "$output" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | tail -1)"
    # Vitest summary line: "X tests | Y passed | ..."
    [[ -z "$passed" ]] && passed="$(echo "$output" | grep -iE 'tests?\s*\|' | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1)"
    passed="${passed:-0}"
    failed="${failed:-0}"
    echo "${passed}:${failed}"
}

parse_dotnet_counts() {
    local output
    output="$(echo "$1" | strip_ansi)"
    # "Passed: X, Failed: Y, Skipped: Z"
    local passed failed
    passed="$(echo "$output" | grep -iE 'passed:\s*[0-9]+' | grep -oE '[0-9]+' | tail -1)"
    failed="$(echo "$output" | grep -iE 'failed:\s*[0-9]+' | grep -oE '[0-9]+' | tail -1)"
    passed="${passed:-0}"
    failed="${failed:-0}"
    echo "${passed}:${failed}"
}

parse_python_counts() {
    local output
    output="$(echo "$1" | strip_ansi)"
    # pytest: "X passed, Y failed" or "X passed" or "=== X passed ==="
    local passed failed
    passed="$(echo "$output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1)"
    failed="$(echo "$output" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | tail -1)"
    passed="${passed:-0}"
    failed="${failed:-0}"
    echo "${passed}:${failed}"
}

# ── Collect projects ──────────────────────────────────────────────────────────

declare -a PROJECTS=()

IFS=',' read -ra FOLDER_LIST <<< "$FOLDERS"
for folder in "${FOLDER_LIST[@]}"; do
    folder_path="${PROJECT_ROOT}/${folder}"
    if [[ ! -d "$folder_path" ]]; then
        echo "⚠  Folder not found, skipping: ${folder}" >&2
        continue
    fi

    while IFS= read -r line; do
        [[ -n "$line" ]] && PROJECTS+=("$line")
    done < <(bash "$DETECT_SCRIPT" "$folder_path" 2>/dev/null)
done

# ── Prepare report ────────────────────────────────────────────────────────────

mkdir -p "$REPORTS_DIR"
REPORT_TIMESTAMP="$(timestamp_local)"
REPORT_FILE="${REPORTS_DIR}/test-report-${REPORT_TIMESTAMP}.md"

DISPLAY_TIMESTAMP="$(timestamp_display)"
REPORT_TITLE="# Test Report — ${DISPLAY_TIMESTAMP}"

# ── Run tests ─────────────────────────────────────────────────────────────────

declare -a RESULTS=()
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_COVERAGE_SUM=0
TOTAL_COVERAGE_COUNT=0

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
    echo "⚠  No test-capable projects found in: ${FOLDERS}" >&2
fi

for project_entry in "${PROJECTS[@]}"; do
    IFS=':' read -r proj_type proj_path test_cmd coverage_cmd <<< "$project_entry"

    # Use coverage command if available, fall back to plain test
    run_cmd="$test_cmd"
    use_coverage=false
    if [[ "$coverage_cmd" != "none" ]]; then
        run_cmd="$coverage_cmd"
        use_coverage=true
    fi

    proj_label="$(realpath --relative-to="$PROJECT_ROOT" "$proj_path" 2>/dev/null || echo "$proj_path")"

    echo "▶ Running tests: ${proj_label} (${proj_type})" >&2

    # Run in project directory, capture output
    set +e
    output="$(cd "$proj_path" && eval "$run_cmd" 2>&1)"
    exit_code=$?
    set -e

    status="PASS"
    [[ $exit_code -ne 0 ]] && status="FAIL"

    # Parse counts
    case "$proj_type" in
        node)
            counts="$(parse_node_counts "$output")"
            coverage="$(parse_node_coverage "$output")"
            ;;
        dotnet)
            counts="$(parse_dotnet_counts "$output")"
            coverage="$(parse_dotnet_coverage "$output")"
            ;;
        python)
            counts="$(parse_python_counts "$output")"
            coverage="$(parse_python_coverage "$output")"
            ;;
        *)
            counts="0:0"
            coverage="N/A"
            ;;
    esac

    passed="${counts%%:*}"
    failed="${counts##*:}"

    $use_coverage || coverage="N/A"

    TOTAL_PASS=$((TOTAL_PASS + passed))
    TOTAL_FAIL=$((TOTAL_FAIL + failed))

    if [[ "$coverage" != "N/A" ]] && [[ -n "$coverage" ]]; then
        # Remove trailing % if present
        cov_num="${coverage//%/}"
        TOTAL_COVERAGE_SUM=$(echo "$TOTAL_COVERAGE_SUM + $cov_num" | bc 2>/dev/null || echo "$TOTAL_COVERAGE_SUM")
        TOTAL_COVERAGE_COUNT=$((TOTAL_COVERAGE_COUNT + 1))
    fi

    # Store: label|type|passed|failed|coverage|status|output
    RESULTS+=("${proj_label}|${proj_type}|${passed}|${failed}|${coverage:-N/A}|${status}|${output}")
done

# ── Calculate aggregate coverage ─────────────────────────────────────────────

if [[ $TOTAL_COVERAGE_COUNT -gt 0 ]]; then
    AVG_COVERAGE="$(echo "scale=1; $TOTAL_COVERAGE_SUM / $TOTAL_COVERAGE_COUNT" | bc 2>/dev/null || echo "N/A")%"
else
    AVG_COVERAGE="N/A"
fi

TOTAL_TESTS=$((TOTAL_PASS + TOTAL_FAIL))
if [[ $TOTAL_TESTS -gt 0 ]]; then
    PASS_RATE="$(echo "scale=1; $TOTAL_PASS * 100 / $TOTAL_TESTS" | bc 2>/dev/null || echo "N/A")%"
else
    PASS_RATE="N/A"
fi

# ── Write report ──────────────────────────────────────────────────────────────

{
    echo "$REPORT_TITLE"
    echo ""
    echo "**Generated:** ${DISPLAY_TIMESTAMP}  "
    echo "**Folders scanned:** \`${FOLDERS}\`  "
    echo "**Projects found:** ${#PROJECTS[@]}  "
    echo ""
    echo "---"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Total Tests | ${TOTAL_TESTS} |"
    echo "| Passed | ${TOTAL_PASS} |"
    echo "| Failed | ${TOTAL_FAIL} |"
    echo "| Pass Rate | ${PASS_RATE} |"
    echo "| Avg Coverage | ${AVG_COVERAGE} |"
    echo ""
    echo "---"
    echo ""
    echo "## Per-Project Results"
    echo ""
    echo "| Project | Type | Passed | Failed | Coverage | Status |"
    echo "|---------|------|--------|--------|----------|--------|"

    if [[ ${#RESULTS[@]} -eq 0 ]]; then
        echo "| — | — | — | — | — | No projects found |"
    else
        for result in "${RESULTS[@]}"; do
            IFS='|' read -r r_label r_type r_passed r_failed r_coverage r_status r_output <<< "$result"
            status_icon="✅"
            [[ "$r_status" == "FAIL" ]] && status_icon="❌"
            echo "| \`${r_label}\` | ${r_type} | ${r_passed} | ${r_failed} | ${r_coverage} | ${status_icon} ${r_status} |"
        done
    fi

    echo ""
    echo "---"
    echo ""
    echo "## Detailed Output"
    echo ""

    if [[ ${#RESULTS[@]} -eq 0 ]]; then
        echo "_No projects were found or run._"
    else
        for result in "${RESULTS[@]}"; do
            IFS='|' read -r r_label r_type r_passed r_failed r_coverage r_status r_output <<< "$result"
            echo "### \`${r_label}\` (${r_type})"
            echo ""
            echo "\`\`\`"
            echo "$r_output"
            echo "\`\`\`"
            echo ""
        done
    fi

    echo "---"
    echo ""
    echo "_Report generated by \`/test-report\` skill._"

} > "$REPORT_FILE"

echo "Report written to: ${REPORT_FILE}"
echo "REPORT_FILE=${REPORT_FILE}"
