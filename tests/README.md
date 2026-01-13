# Testing

This directory contains unit tests for Mikro Taskwarrior.

## Setup

Tests use `plenary.nvim` for the testing framework. To run tests, you need to have `plenary.nvim` available.

### Running Tests

**Recommended: Use the shell script:**
```bash
./tests/run_tests.sh
```

**Or from within Neovim:**
```lua
:lua require('plenary.test_harness').test_directory('tests')
```

## Test Structure

- `date_spec.lua` - Tests for date parsing utilities
- `filter_spec.lua` - Tests for task filtering logic
- `validation_spec.lua` - Tests for input validation

## Adding New Tests

Create new test files following the pattern `*_spec.lua` in the `tests/` directory.

Example:
```lua
local date_utils = require "mikro_taskwarrior.utils.date"

describe("Date parsing", function()
  it("should parse 'today' correctly", function()
    local result = date_utils.parse_due_date_from_string("today")
    assert.truthy(result)
    assert.equals(os.date("%Y-%m-%d"), result)
  end)
end)
```

