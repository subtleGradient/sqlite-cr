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

# Helper function for better assertions
assert_query() {
    local query="$1"
    local expected="$2"
    local description="$3"

    echo -n "✓ $description... "

    if result=$(sqlite-cr :memory: "$query" 2>&1) && [[ "$result" == *"$expected"* ]]; then
        echo "PASS"
        ((TESTS_PASSED++))
        return 0
    else
        echo "FAIL (expected '$expected', got: $result)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Basic SQL execution and tool availability
assert_query "SELECT 2*3 as answer;" "6" "executes SQL queries correctly"

# Test 2: cr-sqlite extension loads and provides site ID functionality
assert_query "SELECT typeof(crsql_site_id()) as site_id_type;" "blob" "cr-sqlite extension provides site ID functionality"

# Test 3: CRDT table creation works correctly
assert_query "CREATE TABLE items(id INTEGER PRIMARY KEY NOT NULL, name TEXT); SELECT crsql_as_crr('items'); SELECT 'SUCCESS';" "SUCCESS" "creates CRDT-enabled tables"

# Test 4: cr-sqlite functions are available
assert_query "SELECT COUNT(*) >= 5 as has_functions FROM pragma_function_list WHERE name LIKE 'crsql%';" "1" "provides cr-sqlite function suite"

# Test 5: CRDT operations perform data persistence
assert_query "CREATE TABLE docs(id INTEGER PRIMARY KEY NOT NULL, content TEXT); SELECT crsql_as_crr('docs'); INSERT INTO docs VALUES (42, 'test-data'); SELECT content FROM docs WHERE id = 42;" "test-data" "performs CRDT data operations"

# Test 6: Error handling preserves exit codes
echo -n "✓ handles SQL errors with proper exit codes... "
if ! sqlite-cr :memory: "INVALID SQL SYNTAX;" 2>/dev/null; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
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
