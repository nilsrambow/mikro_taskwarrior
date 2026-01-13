local filter = require "mikro_taskwarrior.core.filter"

describe("Task filtering", function()
  local sample_tasks = {
    {
      uuid = "test-uuid-1",
      description = "Task 1",
      status = "pending",
      entry = "20240101T120000Z",
      tags = { "work", "urgent" },
    },
    {
      uuid = "test-uuid-2",
      description = "Task 2",
      status = "pending",
      entry = "20240101T120000Z",
      tags = { "work" },
    },
    {
      uuid = "test-uuid-3",
      description = "Task 3",
      status = "completed",
      entry = "20240101T120000Z",
      tags = { "work" },
    },
    {
      uuid = "test-uuid-4",
      description = "Task 4",
      status = "pending",
      entry = "20240101T120000Z",
      tags = { "personal" },
    },
  }

  describe("filter_tasks", function()
    it("should filter out completed tasks by default", function()
      local filtered = filter.filter_tasks(sample_tasks, nil, nil, "pending", false)
      assert.equals(3, #filtered)
      for _, task in ipairs(filtered) do
        assert.not_equals("completed", task.status)
      end
    end)

    it("should filter by positive tags", function()
      local filtered = filter.filter_tasks(sample_tasks, { "work" }, nil, "pending", false)
      assert.equals(2, #filtered)
      for _, task in ipairs(filtered) do
        local has_work = false
        if task.tags then
          for _, tag in ipairs(task.tags) do
            if tag == "work" then
              has_work = true
              break
            end
          end
        end
        assert.is_true(has_work)
      end
    end)

    it("should filter by multiple positive tags (all must be present)", function()
      local filtered = filter.filter_tasks(sample_tasks, { "work", "urgent" }, nil, "pending", false)
      assert.equals(1, #filtered)
      assert.equals("Task 1", filtered[1].description)
    end)

    it("should exclude tasks with negative tags", function()
      local filtered = filter.filter_tasks(sample_tasks, nil, { "work" }, "pending", false)
      assert.equals(1, #filtered)
      assert.equals("Task 4", filtered[1].description)
    end)

    it("should combine positive and negative filters", function()
      local filtered = filter.filter_tasks(sample_tasks, { "work" }, { "urgent" }, "pending", false)
      assert.equals(1, #filtered)
      assert.equals("Task 2", filtered[1].description)
    end)

    it("should calculate urgency when requested", function()
      local filtered = filter.filter_tasks(sample_tasks, nil, nil, "pending", true)
      for _, task in ipairs(filtered) do
        assert.truthy(task.urgency)
        assert.is_true(type(task.urgency) == "number", "urgency should be a number")
      end
    end)
  end)

  describe("sort_tasks_by_urgency", function()
    it("should sort tasks by urgency (highest first)", function()
      local tasks = {
        { uuid = "1", description = "Low", urgency = 1.0 },
        { uuid = "2", description = "High", urgency = 10.0 },
        { uuid = "3", description = "Medium", urgency = 5.0 },
      }
      filter.sort_tasks_by_urgency(tasks)
      assert.equals("High", tasks[1].description)
      assert.equals("Medium", tasks[2].description)
      assert.equals("Low", tasks[3].description)
    end)
  end)
end)

