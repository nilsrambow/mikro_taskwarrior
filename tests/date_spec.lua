local date_utils = require "mikro_taskwarrior.utils.date"

describe("Date parsing utilities", function()
  describe("parse_due_date_from_string", function()
    it("should parse 'today' correctly", function()
      local result = date_utils.parse_due_date_from_string("today")
      assert.truthy(result)
      assert.equals(os.date("%Y-%m-%d"), result)
    end)

    it("should parse 'tomorrow' correctly", function()
      local result = date_utils.parse_due_date_from_string("tomorrow")
      assert.truthy(result)
      local expected = os.date("%Y-%m-%d", os.time() + 86400)
      assert.equals(expected, result)
    end)

    it("should parse relative days (1d, 5d)", function()
      local result_1d = date_utils.parse_due_date_from_string("1d")
      assert.truthy(result_1d)
      
      local result_5d = date_utils.parse_due_date_from_string("5d")
      assert.truthy(result_5d)
      
      local expected_1d = os.date("%Y-%m-%d", os.time() + 86400)
      local expected_5d = os.date("%Y-%m-%d", os.time() + 5 * 86400)
      assert.equals(expected_1d, result_1d)
      assert.equals(expected_5d, result_5d)
    end)

    it("should parse relative weeks (1w, 2w)", function()
      local result_1w = date_utils.parse_due_date_from_string("1w")
      assert.truthy(result_1w)
      
      local expected_1w = os.date("%Y-%m-%d", os.time() + 7 * 86400)
      assert.equals(expected_1w, result_1w)
    end)

    it("should parse YYYY-MM-DD format", function()
      local result = date_utils.parse_due_date_from_string("2024-12-25")
      assert.truthy(result)
      assert.equals("2024-12-25", result)
    end)

    it("should return nil for invalid input", function()
      local result = date_utils.parse_due_date_from_string("invalid")
      assert.is_nil(result)
    end)
  end)

  describe("is_due_today", function()
    it("should return true for today's date", function()
      local today = os.date("%Y-%m-%d")
      assert.is_true(date_utils.is_due_today(today))
    end)

    it("should return false for tomorrow's date", function()
      local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
      assert.is_false(date_utils.is_due_today(tomorrow))
    end)

    it("should return false for nil", function()
      assert.is_false(date_utils.is_due_today(nil))
    end)
  end)

  describe("is_overdue", function()
    it("should return true for past dates", function()
      local past_date = os.date("%Y-%m-%d", os.time() - 86400)
      assert.is_true(date_utils.is_overdue(past_date))
    end)

    it("should return false for future dates", function()
      local future_date = os.date("%Y-%m-%d", os.time() + 86400)
      assert.is_false(date_utils.is_overdue(future_date))
    end)

    it("should return false for nil", function()
      assert.is_false(date_utils.is_overdue(nil))
    end)
  end)
end)

