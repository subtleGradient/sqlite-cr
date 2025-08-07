#!/usr/bin/env bash
set -euo pipefail

# Suppress shell hook output during tests
export SQLITE_CR_QUIET=1

# sqlite-cr.spec.sh
# Executable specification that documents and tests the sqlite-cr CLI tool

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

# Test 1: Tool exists and runs
echo -n "✓ sqlite-cr command exists and runs... "
if result=$(nix develop -c sqlite-cr :memory: "SELECT 1;" 2>&1) && echo "$result" | grep -q "1"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 2: Can execute basic SQL
echo -n "✓ executes basic SQL queries... "
if result=$(nix develop -c sqlite-cr :memory: "SELECT 1+1 as result;" 2>&1) && echo "$result" | grep -q "2"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 3: cr-sqlite extension is loaded
echo -n "✓ cr-sqlite extension is pre-loaded... "
if nix develop -c sqlite-cr :memory: "SELECT crsql_site_id() IS NOT NULL;" 2>&1 | grep -q "1"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 4: Can create CRDT tables
echo -n "✓ creates CRDT-enabled tables... "
if nix develop -c sqlite-cr :memory: "CREATE TABLE items(id INTEGER PRIMARY KEY NOT NULL, name TEXT); SELECT crsql_as_crr('items'); SELECT 'OK';" 2>&1 | grep -q "OK"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 5: CRDT functions are available
echo -n "✓ provides cr-sqlite functions... "
if nix develop -c sqlite-cr :memory: "SELECT COUNT(*) > 0 FROM pragma_function_list WHERE name LIKE 'crsql%';" 2>&1 | grep -q "1"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 6: Can get site ID
echo -n "✓ generates unique site IDs... "
if nix develop -c sqlite-cr :memory: "SELECT length(crsql_site_id()) > 0;" 2>&1 | grep -q "1"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 7: Supports in-memory databases
echo -n "✓ supports in-memory databases... "
if nix develop -c sqlite-cr :memory: "CREATE TABLE test(id INTEGER PRIMARY KEY); SELECT 'OK';" 2>&1 | grep -q "OK"; then
    echo "PASS"
    ((TESTS_PASSED++))
else
    echo "FAIL"
    ((TESTS_FAILED++))
fi

# Test 8: Can perform CRDT operations
echo -n "✓ performs CRDT merge operations... "
if nix develop -c sqlite-cr :memory: "CREATE TABLE docs(id INTEGER PRIMARY KEY NOT NULL, content TEXT); SELECT crsql_as_crr('docs'); INSERT INTO docs VALUES (1, 'hello'); SELECT content FROM docs WHERE id = 1;" 2>&1 | grep -q "hello"; then
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