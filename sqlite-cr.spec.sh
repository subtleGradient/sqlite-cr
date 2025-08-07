#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2024 subtleGradient
# Make Kent Beck proud of me
set -euo pipefail

# sqlite-cr.spec.sh - Test specification for sqlite-cr
# Following TDD: tests describe expected behavior

# Check if we're being run inside nix develop
if [ -z "${IN_NIX_SHELL:-}" ]; then
    echo "Running tests in nix develop environment..."
    exec nix develop -c "$0" "$@"
fi

# Ensure sqlite-cr is available
if ! command -v sqlite-cr &> /dev/null; then
    echo "Error: sqlite-cr not found in PATH" >&2
    exit 1
fi

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function for robust CSV assertions
assert_csv_query() {
    local query="$1"
    local expected="$2"
    local description="$3"
    local output
    
    echo -n "✓ $description... "
    
    # Use CSV mode to get predictable output format
    if output=$(sqlite-cr -csv :memory: "$query" 2>/dev/null); then
        if [[ "$output" == "$expected" ]]; then
            echo "PASS"
            ((TESTS_PASSED++))
            return 0
        else
            echo "FAIL (expected '$expected', got: '$output')"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo "FAIL (query error: $output)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test helper for checking existence/boolean results
assert_true() {
    local query="$1"
    local description="$2"
    assert_csv_query "$query" "1" "$description"
}

echo "=== Running sqlite-cr tests ==="

# Test 1: Basic SQL execution
assert_csv_query "SELECT 2*3 as answer;" "6" "executes SQL queries correctly"

# Test 2: cr-sqlite extension loads
assert_csv_query "SELECT typeof(crsql_site_id()) as type;" "blob" "cr-sqlite extension provides site ID functionality"

# Test 3: CRDT table creation
assert_true "CREATE TABLE items(id INTEGER PRIMARY KEY NOT NULL, name TEXT); SELECT crsql_as_crr('items') IS NOT NULL;" "creates CRDT-enabled tables"

# Test 4: cr-sqlite functions available
assert_true "SELECT COUNT(*) >= 5 FROM pragma_function_list WHERE name LIKE 'crsql%';" "provides cr-sqlite function suite"

# Test 5: CRDT operations
assert_csv_query "CREATE TABLE docs(id INTEGER PRIMARY KEY NOT NULL, content TEXT); SELECT crsql_as_crr('docs'); INSERT INTO docs VALUES (42, 'test-data'); SELECT content FROM docs WHERE id = 42;" "test-data" "performs CRDT data operations"

# Test 6: Error handling
echo -n "✓ handles SQL errors with proper exit codes... "
if ! sqlite-cr :memory: "INVALID SQL SYNTAX;" 2>/dev/null; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 7: Stderr filtering (close5 error suppressed on success)
echo -n "✓ suppresses sqlite3_close error on successful execution... "
stderr_output=$(sqlite-cr :memory: "SELECT 1;" 2>&1 >/dev/null)
if [[ ! "$stderr_output" =~ "sqlite3_close() returns 5" ]]; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL (close5 error not filtered: $stderr_output)"
    ((TESTS_FAILED++))
fi

echo
echo "=== Test Summary ==="
echo "Passed: $TESTS_PASSED/7"
echo "Failed: $TESTS_FAILED/7"
echo

[ $TESTS_FAILED -eq 0 ]