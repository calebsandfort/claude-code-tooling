#!/usr/bin/env bash
# detect-tests.sh — Detect test-capable projects in a given folder
#
# Usage: detect-tests.sh <folder>
# Output: Lines of the format:
#   <type>:<project_path>:<test_command>:<coverage_command>
#   type: node | dotnet | python
#   coverage_command may be "none" if not available

set -euo pipefail

FOLDER="${1:?Usage: detect-tests.sh <folder>}"

# Directories to skip
EXCLUDED_DIRS="node_modules dist build bin obj .next __pycache__ .venv .git"

is_excluded() {
    local dir_name
    dir_name="$(basename "$1")"
    # Skip hidden directories
    [[ "$dir_name" == .* ]] && return 0
    for excl in $EXCLUDED_DIRS; do
        [[ "$dir_name" == "$excl" ]] && return 0
    done
    return 1
}

detect_node_project() {
    local dir="$1"
    local pkg="$dir/package.json"

    [[ -f "$pkg" ]] || return 1

    # Must have a "test" script
    if command -v node &>/dev/null; then
        node -e "
            const pkg = require('$pkg');
            if (!pkg.scripts || !pkg.scripts.test) process.exit(1);
        " 2>/dev/null || return 1
    else
        grep -q '"test"' "$pkg" || return 1
    fi

    # Determine test runner
    local test_cmd="pnpm test"
    if [[ -f "$dir/pnpm-lock.yaml" ]]; then
        test_cmd="pnpm test"
    elif [[ -f "$dir/yarn.lock" ]]; then
        test_cmd="yarn test"
    elif [[ -f "$dir/package-lock.json" ]]; then
        test_cmd="npm test"
    fi

    # Detect coverage support
    local coverage_cmd="none"
    if [[ -f "$dir/jest.config.js" ]] || [[ -f "$dir/jest.config.ts" ]] || [[ -f "$dir/jest.config.mjs" ]]; then
        coverage_cmd="${test_cmd} -- --coverage"
    elif [[ -f "$dir/vitest.config.js" ]] || [[ -f "$dir/vitest.config.ts" ]] || [[ -f "$dir/vitest.config.mts" ]]; then
        coverage_cmd="${test_cmd} -- --coverage"
    fi

    echo "node:${dir}:${test_cmd}:${coverage_cmd}"
    return 0
}

detect_dotnet_project() {
    local dir="$1"

    # Look for *.Test.csproj files in the directory tree (non-recursive from dir)
    local csproj
    csproj="$(find "$dir" -maxdepth 3 -name "*.Test.csproj" -not -path "*/obj/*" -not -path "*/bin/*" 2>/dev/null | head -1)"

    [[ -n "$csproj" ]] || return 1

    local proj_dir
    proj_dir="$(dirname "$csproj")"
    local test_cmd="dotnet test \"${csproj}\""

    # Coverage: check for coverlet or built-in coverage
    local coverage_cmd="none"
    if grep -q -i "coverlet\|coverage" "$csproj" 2>/dev/null; then
        coverage_cmd="dotnet test \"${csproj}\" --collect:\"XPlat Code Coverage\""
    fi

    echo "dotnet:${proj_dir}:${test_cmd}:${coverage_cmd}"
    return 0
}

detect_python_project() {
    local dir="$1"

    # Check for pytest indicators
    local has_pytest=false
    [[ -f "$dir/pytest.ini" ]] && has_pytest=true
    [[ -f "$dir/setup.cfg" ]] && grep -q "\[tool:pytest\]" "$dir/setup.cfg" 2>/dev/null && has_pytest=true
    [[ -f "$dir/pyproject.toml" ]] && grep -q "\[tool.pytest" "$dir/pyproject.toml" 2>/dev/null && has_pytest=true
    [[ -f "$dir/setup.py" ]] && has_pytest=true

    $has_pytest || return 1

    local python_cmd="python"
    command -v python3 &>/dev/null && python_cmd="python3"

    local test_cmd="${python_cmd} -m pytest"

    # Check for pytest-cov
    local coverage_cmd="none"
    if $python_cmd -c "import pytest_cov" 2>/dev/null; then
        coverage_cmd="${test_cmd} --cov=${dir} --cov-report=term-missing"
    fi

    echo "python:${dir}:${test_cmd}:${coverage_cmd}"
    return 0
}

scan_folder() {
    local folder="$1"

    [[ -d "$folder" ]] || return 0

    # Try detecting at the folder root level first
    detect_node_project "$folder" && return 0
    detect_dotnet_project "$folder" && return 0
    detect_python_project "$folder" && return 0

    # If not found at root, scan one level deep
    while IFS= read -r -d '' subdir; do
        is_excluded "$subdir" && continue

        detect_node_project "$subdir" 2>/dev/null && continue
        detect_dotnet_project "$subdir" 2>/dev/null && continue
        detect_python_project "$subdir" 2>/dev/null && continue
    done < <(find "$folder" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
}

scan_folder "$FOLDER"
