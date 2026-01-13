local validation = require "mikro_taskwarrior.utils.validation"

describe("Input validation", function()
  describe("is_valid_date_format", function()
    it("should validate correct YYYY-MM-DD format", function()
      assert.is_true(validation.is_valid_date_format("2024-12-25"))
      assert.is_true(validation.is_valid_date_format("2024-01-01"))
    end)

    it("should reject invalid formats", function()
      assert.is_false(validation.is_valid_date_format("2024/12/25"))
      assert.is_false(validation.is_valid_date_format("12-25-2024"))
      assert.is_false(validation.is_valid_date_format("invalid"))
      assert.is_false(validation.is_valid_date_format(nil))
    end)

    it("should reject invalid date ranges", function()
      assert.is_false(validation.is_valid_date_format("2024-13-01")) -- Invalid month
      assert.is_false(validation.is_valid_date_format("2024-12-32")) -- Invalid day
    end)
  end)

  describe("is_valid_tag", function()
    it("should validate normal tags", function()
      assert.is_true(validation.is_valid_tag("work"))
      assert.is_true(validation.is_valid_tag("urgent"))
      assert.is_true(validation.is_valid_tag("project:website"))
    end)

    it("should reject invalid tags", function()
      assert.is_false(validation.is_valid_tag(""))
      assert.is_false(validation.is_valid_tag("tag with spaces"))
      assert.is_false(validation.is_valid_tag("+tag"))
      assert.is_false(validation.is_valid_tag("-tag"))
      assert.is_false(validation.is_valid_tag(nil))
    end)
  end)

  describe("validate_task", function()
    it("should validate a complete valid task", function()
      local task = {
        uuid = "test-uuid",
        description = "Test task",
        status = "pending",
        entry = "20240101T120000Z",
        due = "2024-12-25",
        tags = { "work", "urgent" },
      }
      local is_valid, error_msg = validation.validate_task(task)
      assert.is_true(is_valid)
      assert.is_nil(error_msg)
    end)

    it("should reject task without UUID", function()
      local task = {
        description = "Test task",
        status = "pending",
      }
      local is_valid, error_msg = validation.validate_task(task)
      assert.is_false(is_valid)
      assert.truthy(error_msg)
    end)

    it("should reject task without description", function()
      local task = {
        uuid = "test-uuid",
        status = "pending",
      }
      local is_valid, error_msg = validation.validate_task(task)
      assert.is_false(is_valid)
      assert.truthy(error_msg)
    end)

    it("should reject invalid status", function()
      local task = {
        uuid = "test-uuid",
        description = "Test task",
        status = "invalid",
      }
      local is_valid, error_msg = validation.validate_task(task)
      assert.is_false(is_valid)
      assert.truthy(error_msg)
    end)

    it("should reject invalid due date format", function()
      local task = {
        uuid = "test-uuid",
        description = "Test task",
        status = "pending",
        due = "invalid-date",
      }
      local is_valid, error_msg = validation.validate_task(task)
      assert.is_false(is_valid)
      assert.truthy(error_msg)
    end)

    it("should reject invalid tags", function()
      local task = {
        uuid = "test-uuid",
        description = "Test task",
        status = "pending",
        tags = { "valid", "tag with spaces" },
      }
      local is_valid, error_msg = validation.validate_task(task)
      assert.is_false(is_valid)
      assert.truthy(error_msg)
    end)
  end)

  describe("is_valid_task_id", function()
    it("should validate task IDs within range", function()
      assert.is_true(validation.is_valid_task_id(1, 10))
      assert.is_true(validation.is_valid_task_id(5, 10))
      assert.is_true(validation.is_valid_task_id(10, 10))
    end)

    it("should reject task IDs out of range", function()
      assert.is_false(validation.is_valid_task_id(0, 10))
      assert.is_false(validation.is_valid_task_id(11, 10))
      assert.is_false(validation.is_valid_task_id(-1, 10))
    end)

    it("should reject non-numeric task IDs", function()
      assert.is_false(validation.is_valid_task_id("1", 10))
      assert.is_false(validation.is_valid_task_id(nil, 10))
    end)
  end)
end)

