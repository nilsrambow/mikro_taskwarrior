#!/bin/bash
# Run tests for Mikro Taskwarrior with enhanced output formatting
# This script should be run from the project root directory

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT" || exit 1

# Temporary file for test output
OUTPUT_FILE=$(mktemp)
trap "rm -f $OUTPUT_FILE" EXIT

# Run tests and capture output
nvim --headless -c "luafile tests/run_tests.lua" -c "qa!" 2>&1 | tee "$OUTPUT_FILE"

# Capture exit code
EXIT_CODE=${PIPESTATUS[0]}

# Analyze output for summary
echo ""
echo "================================================================================"
echo "TEST SUMMARY"
echo "================================================================================"
echo ""

# Count test files
TEST_FILE_COUNT=$(grep -c "•.*_spec.lua" "$OUTPUT_FILE" 2>/dev/null || echo "0")

# Parse plenary's test output more carefully.
# Plenary outputs lines like:
#   Success ||      Test description
#   Fail    ||      Test description
# and per-file summaries like:
#   Success:      7
#   Failed :      0
#   Errors :      0

# Count actual test results from per-test lines (most reliable).
# Plenary colorizes output, so we strip ANSI escape sequences before matching.
PASSED_COUNT=$(
  awk '
    {
      gsub(/\x1B\[[0-9;]*[A-Za-z]/, "", $0)
      if ($1 == "Success" && $2 == "||") passed++
    }
    END { print passed+0 }
  ' "$OUTPUT_FILE" 2>/dev/null
)
PASSED_COUNT=${PASSED_COUNT:-0}

FAILED_COUNT=$(
  awk '
    {
      gsub(/\x1B\[[0-9;]*[A-Za-z]/, "", $0)
      if ($1 == "Fail" && $2 == "||") failed++
    }
    END { print failed+0 }
  ' "$OUTPUT_FILE" 2>/dev/null
)
FAILED_COUNT=${FAILED_COUNT:-0}

# Sum error counts from per-file summary lines (in case errors don't show as per-test lines)
PLENARY_ERRORS=$(
  awk '
    {
      gsub(/\x1B\[[0-9;]*[A-Za-z]/, "", $0)
      if ($1 == "Errors" && $2 ~ /:/) sum += $NF
    }
    END { print sum+0 }
  ' "$OUTPUT_FILE" 2>/dev/null
)
PLENARY_ERRORS=${PLENARY_ERRORS:-0}

echo "Test files processed: $TEST_FILE_COUNT"
echo "Tests passed:        $PASSED_COUNT"
echo "Tests failed:        $FAILED_COUNT"
if [ "$PLENARY_ERRORS" -gt 0 ]; then
  echo "Errors:              $PLENARY_ERRORS"
fi
echo ""

# Determine if tests actually failed
TESTS_FAILED=false
if [ "$FAILED_COUNT" -gt 0 ] || [ "$PLENARY_ERRORS" -gt 0 ] || [ $EXIT_CODE -ne 0 ]; then
  TESTS_FAILED=true
fi

if [ "$TESTS_FAILED" = true ]; then
  echo "================================================================================"
  echo "❌ FAILURES DETECTED"
  echo "================================================================================"
  echo ""
  # Extract actual failure lines (starting with "Fail ||")
  FAILED_TESTS=$(grep -E "^[[:space:]]*Fail[[:space:]]+\|\|" "$OUTPUT_FILE" 2>/dev/null)
  if [ -n "$FAILED_TESTS" ]; then
    echo "Failed tests:"
    echo "───────────────────────────────────────────────────────────────────────────────"
    echo "$FAILED_TESTS" | head -30 | sed 's/^/  /'
    echo ""
  fi
  
  # Extract error messages
  if [ "$PLENARY_ERRORS" -gt 0 ]; then
    echo "Errors:"
    echo "───────────────────────────────────────────────────────────────────────────────"
    # Look for error patterns in the output (but exclude our summary section)
    grep -iE "error:|exception|stack trace" "$OUTPUT_FILE" 2>/dev/null | grep -v "TEST SUMMARY" | head -20 | sed 's/^/  /'
    echo ""
  fi
  
  echo ""
  echo "💡 Tips:"
  echo "   • Scroll up to see full error messages and stack traces"
  echo "   • Look for assertion failures (assert.*failed)"
  echo "   • Check that all required dependencies are installed"
  echo ""
  exit 1
else
  echo "================================================================================"
  echo "✓ ALL TESTS PASSED"
  echo "================================================================================"
  echo ""
  exit 0
fi

