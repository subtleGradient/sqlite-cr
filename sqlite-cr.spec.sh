#!/usr/bin/env bash
set -euo pipefail

# Suppress shell hook output during tests
export SQLITE_CR_QUIET=1

# sqlite-cr.spec.sh
# Executable specification that documents and tests the sqlite-cr CLI tool
# Following TDD approach: tests describe behavior, not aspirations

echo "=== sqlite-cr CLI Tool Specification ==="
echo
echo "sqlite-cr provides SQLite with the cr-sqlite CRDT extension pre-loaded."
echo "It enables conflict-free replicated data types for distributed SQLite databases."
echo

echo "=== Basic Usage ==="
echo "sqlite-cr accepts all standard sqlite3 arguments:"
echo '  sqlite-cr :memory: "SELECT 1+1;"'
echo '  sqlite-cr mydb.db'
echo '  sqlite-cr -csv data.db "SELECT * FROM table;"'
echo

echo "=== Running Tests ==="
echo

# Run all tests in a single nix develop session for speed
nix develop -c bash <<'EOS'
set -euo pipefail
export SQLITE_CR_QUIET=1

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
    if output=$(sqlite-cr :memory: "$query" -csv 2>&1); then
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

# Test 1: Basic SQL execution and tool availability
assert_csv_query "SELECT 2*3 as answer;" "6" "executes SQL queries correctly"

# Test 2: cr-sqlite extension loads and provides site ID functionality
assert_csv_query "SELECT typeof(crsql_site_id()) as type;" "blob" "cr-sqlite extension provides site ID functionality"

# Test 3: CRDT table creation works correctly
assert_true "CREATE TABLE items(id INTEGER PRIMARY KEY NOT NULL, name TEXT); SELECT crsql_as_crr('items') IS NOT NULL;" "creates CRDT-enabled tables"

# Test 4: cr-sqlite functions are available
assert_true "SELECT COUNT(*) >= 5 FROM pragma_function_list WHERE name LIKE 'crsql%';" "provides cr-sqlite function suite"

# Test 5: CRDT operations perform data persistence
assert_csv_query "CREATE TABLE docs(id INTEGER PRIMARY KEY NOT NULL, content TEXT); SELECT crsql_as_crr('docs'); INSERT INTO docs VALUES (42, 'test-data'); SELECT content FROM docs WHERE id = 42;" "test-data" "performs CRDT data operations"

# Test 6: Error handling preserves exit codes
echo -n "✓ handles SQL errors with proper exit codes... "
if ! sqlite-cr :memory: "INVALID SQL SYNTAX;" 2>/dev/null; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 7: Wrapper filters specific stderr messages
echo -n "✓ filters sqlite3_close error from stderr... "
# Create a test that would trigger the error if it exists
test_output=$(sqlite-cr :memory: "SELECT 1;" 2>&1 || true)
if ! echo "$test_output" | grep -q "sqlite3_close() returns 5"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL (error not filtered)"
    ((TESTS_FAILED++))
fi

echo
echo "=== Test Summary ==="
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✅ All tests passed! sqlite-cr is working correctly."
    exit 0
else
    echo "❌ Some tests failed. Please check the implementation."
    exit 1
fi
EOS
