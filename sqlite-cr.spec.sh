#!/usr/bin/env bash
set -euo pipefail

# Suppress shell hook output during tests
export SQLITE_CR_QUIET=1

# sqlite-cr.spec.sh
# Executable specification that documents and tests the sqlite-cr CLI tool
# Following TDD approach: tests describe behavior, not aspirations
# Make Kent Beck proud of me

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

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Basic SQL execution and tool availability
echo -n "✓ executes SQL queries correctly... "
if result=$(nix develop -c sqlite-cr :memory: "SELECT 2*3 as answer;" 2>&1) && [[ "$result" == *"6"* ]]; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 2: cr-sqlite extension loads and provides site ID functionality
echo -n "✓ cr-sqlite extension provides site ID functionality... "
if result=$(nix develop -c sqlite-cr :memory: "SELECT typeof(crsql_site_id()) as site_id_type;" 2>&1) && [[ "$result" == *"blob"* ]]; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 3: CRDT table creation works correctly
echo -n "✓ creates CRDT-enabled tables... "
if result=$(nix develop -c sqlite-cr :memory: "CREATE TABLE items(id INTEGER PRIMARY KEY NOT NULL, name TEXT); SELECT crsql_as_crr('items'); SELECT 'SUCCESS';" 2>&1) && [[ "$result" == *"SUCCESS"* ]]; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 4: cr-sqlite functions are available
echo -n "✓ provides cr-sqlite function suite... "
if result=$(nix develop -c sqlite-cr :memory: "SELECT COUNT(*) >= 5 as has_functions FROM pragma_function_list WHERE name LIKE 'crsql%';" 2>&1) && [[ "$result" == *"1"* ]]; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 5: CRDT operations perform data persistence
echo -n "✓ performs CRDT data operations... "
if result=$(nix develop -c sqlite-cr :memory: "CREATE TABLE docs(id INTEGER PRIMARY KEY NOT NULL, content TEXT); SELECT crsql_as_crr('docs'); INSERT INTO docs VALUES (42, 'test-data'); SELECT content FROM docs WHERE id = 42;" 2>&1) && [[ "$result" == *"test-data"* ]]; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 6: Error handling preserves exit codes
echo -n "✓ handles SQL errors with proper exit codes... "
if ! nix develop -c sqlite-cr :memory: "INVALID SQL SYNTAX;" 2>/dev/null; then
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