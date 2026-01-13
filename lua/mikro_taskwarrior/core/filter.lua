local urgency = require "mikro_taskwarrior.core.urgency"

---@class Task
---@field uuid string
---@field description string
---@field status "pending"|"completed"|"active"
---@field entry string|nil ISO 8601 timestamp
---@field due string|nil Date in YYYY-MM-DD format
---@field tags string[]|nil Array of tag strings
---@field urgency number|nil Calculated urgency score

local M = {}

---Check if a task matches the tag filters
---@param task Task Task object
---@param filter_tags string[]|nil Tags that must all be present
---@param exclude_tags string[]|nil Tags that must not be present
---@return boolean
local function matches_tag_filters(task, filter_tags, exclude_tags)
  -- Apply positive tag filter if provided
  if filter_tags and #filter_tags > 0 then
    local has_all_tags = true
    for _, filter_tag in ipairs(filter_tags) do
      local found = false
      if task.tags then
        for _, task_tag in ipairs(task.tags) do
          if task_tag == filter_tag then
            found = true
            break
          end
        end
      end
      if not found then
        has_all_tags = false
        break
      end
    end
    if not has_all_tags then
      return false
    end
  end

  -- Apply negative tag filter (exclude tasks with these tags)
  if exclude_tags and #exclude_tags > 0 then
    if task.tags then
      for _, exclude_tag in ipairs(exclude_tags) do
        for _, task_tag in ipairs(task.tags) do
          if task_tag == exclude_tag then
            return false
          end
        end
      end
    end
  end

  return true
end

---Filter tasks based on status and tags
---@param tasks Task[] Array of task objects
---@param filter_tags string[]|nil Tags that must all be present
---@param exclude_tags string[]|nil Tags that must not be present
---@param status string|nil Status to filter by ("pending" = non-completed, "all" = all tasks)
---@param calculate_urgency boolean|nil Whether to calculate urgency for filtered tasks
---@return Task[] Filtered array of tasks
function M.filter_tasks(tasks, filter_tags, exclude_tags, status, calculate_urgency)
  status = status or "pending" -- Default to non-completed tasks
  calculate_urgency = calculate_urgency or false
  
  local filtered = {}
  
  for _, task in ipairs(tasks) do
    -- Filter by status
    local status_match = false
    if status == "all" then
      status_match = true
    elseif status == "pending" then
      status_match = task.status ~= "completed"
    else
      status_match = task.status == status
    end
    
    if status_match then
      -- Apply tag filters
      if matches_tag_filters(task, filter_tags, exclude_tags) then
        if calculate_urgency then
          task.urgency = urgency.calculate_urgency(task)
        end
        table.insert(filtered, task)
      end
    end
  end
  
  return filtered
end

---Sort tasks by urgency (highest first)
---@param tasks Task[] Array of task objects (should have urgency calculated)
---@return Task[] Sorted array of tasks (sorted in place)
function M.sort_tasks_by_urgency(tasks)
  -- Sort by urgency (descending), then by UUID (ascending) for deterministic ordering
  -- This ensures tasks with the same urgency are always in the same order
  table.sort(tasks, function(a, b)
    local urg_a = a.urgency or 0
    local urg_b = b.urgency or 0
    if urg_a ~= urg_b then
      return urg_a > urg_b
    end
    -- Secondary sort by UUID for deterministic ordering when urgency is equal
    local uuid_a = a.uuid or ""
    local uuid_b = b.uuid or ""
    return uuid_a < uuid_b
  end)
  return tasks
end

return M

