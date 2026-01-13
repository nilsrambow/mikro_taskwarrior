local task = require "mikro_taskwarrior.core.task"
local storage = require "mikro_taskwarrior.core.storage"
local filter = require "mikro_taskwarrior.core.filter"

describe("Task ID stability", function()
  -- Helper to create a test task
  local function create_test_task(description, due_date, tags)
    return {
      uuid = "test-uuid-" .. description:gsub("%s", "-"):lower(),
      description = description,
      status = "pending",
      entry = "20240101T120000Z",
      due = due_date,
      tags = tags,
    }
  end

  it("should maintain consistent IDs when urgency changes slightly", function()
    -- Create tasks with different urgency values
    local tasks = {
      create_test_task("Task A", "2024-12-20", { "urgent" }), -- High urgency (due soon)
      create_test_task("Task B", "2025-06-01", { "work" }),   -- Lower urgency (due later)
      create_test_task("Task C", nil, { "personal" }),        -- Lowest urgency (no due date)
    }
    
    -- Write tasks to storage (using a mock approach)
    -- Note: In a real test, we'd need to mock storage or use a test file
    
    -- Get filtered tasks twice (simulating viewing and then marking done)
    local tasks1 = filter.filter_tasks(tasks, nil, nil, "pending", true)
    filter.sort_tasks_by_urgency(tasks1)
    
    -- Simulate time passing (urgency might change slightly)
    -- Recalculate urgency
    for _, t in ipairs(tasks) do
      t.urgency = nil -- Clear cached urgency
    end
    
    local tasks2 = filter.filter_tasks(tasks, nil, nil, "pending", true)
    filter.sort_tasks_by_urgency(tasks2)
    
    -- IDs should be in the same order
    assert.equals(#tasks1, #tasks2)
    for i = 1, #tasks1 do
      assert.equals(tasks1[i].uuid, tasks2[i].uuid, 
        string.format("Task at position %d changed: expected %s, got %s", 
          i, tasks1[i].description, tasks2[i].description))
    end
  end)

  it("should use UUID as secondary sort key for deterministic ordering", function()
    -- Create tasks with identical urgency (should sort by UUID)
    local tasks = {
      create_test_task("Task Z", nil, nil),
      create_test_task("Task A", nil, nil),
      create_test_task("Task M", nil, nil),
    }
    
    -- Set same urgency for all
    for _, t in ipairs(tasks) do
      t.urgency = 5.0
    end
    
    filter.sort_tasks_by_urgency(tasks)
    
    -- Should be sorted by UUID (alphabetically)
    assert.equals("Task A", tasks[1].description)
    assert.equals("Task M", tasks[2].description)
    assert.equals("Task Z", tasks[3].description)
  end)

  it("should handle tasks with equal urgency deterministically", function()
    local tasks = {
      { uuid = "uuid-c", description = "C", urgency = 10.0 },
      { uuid = "uuid-a", description = "A", urgency = 10.0 },
      { uuid = "uuid-b", description = "B", urgency = 10.0 },
    }
    
    filter.sort_tasks_by_urgency(tasks)
    
    -- Should be sorted by UUID when urgency is equal
    assert.equals("uuid-a", tasks[1].uuid)
    assert.equals("uuid-b", tasks[2].uuid)
    assert.equals("uuid-c", tasks[3].uuid)
  end)
end)

