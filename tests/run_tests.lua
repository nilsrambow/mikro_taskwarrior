-- Enhanced test runner that provides better formatted output
local test_harness = require('plenary.test_harness')

-- Print header
print("")
print("=" .. string.rep("=", 78))
print("Running Mikro Taskwarrior Tests")
print("=" .. string.rep("=", 78))
print("")

-- Count test files first
local test_files = {}
local files = vim.fn.globpath("tests", "*_spec.lua", false, true)
for _, file in ipairs(files) do
  table.insert(test_files, vim.fn.fnamemodify(file, ":t"))
end
table.sort(test_files)

if #test_files == 0 then
  print("❌ ERROR: No test files found in tests/ directory")
  os.exit(1)
end

print(string.format("Found %d test file(s):", #test_files))
for _, file in ipairs(test_files) do
  print(string.format("  • %s", file))
end
print("")
print(string.rep("-", 80))
print("")

-- Run tests - plenary will output results
local start_time = os.clock()
test_harness.test_directory('tests')
local elapsed = os.clock() - start_time

-- Print footer summary
print("")
print(string.rep("=", 80))
print(string.format("Tests completed in %.3fs", elapsed))
print(string.rep("=", 80))
print("")
print("💡 Review the output above for test results")
print("   Look for 'FAILED' or 'Error' messages to identify issues")
print("")
