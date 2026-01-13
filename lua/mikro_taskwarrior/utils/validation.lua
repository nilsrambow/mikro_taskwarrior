local M = {}

-- Function to validate a date string format (YYYY-MM-DD)
-- @param date_str: Date string to validate
-- @return: true if valid, false otherwise
function M.is_valid_date_format(date_str)
  if not date_str or type(date_str) ~= "string" then
    return false
  end
  
  local year, month, day = date_str:match "^(%d%d%d%d)%-(%d%d)%-(%d%d)$"
  if not year or not month or not day then
    return false
  end
  
  -- Basic range validation
  local y = tonumber(year)
  local m = tonumber(month)
  local d = tonumber(day)
  
  if m < 1 or m > 12 or d < 1 or d > 31 then
    return false
  end
  
  return true
end

-- Function to validate a tag string
-- @param tag: Tag string to validate
-- @return: true if valid, false otherwise
function M.is_valid_tag(tag)
  if not tag or type(tag) ~= "string" or #tag == 0 then
    return false
  end
  
  -- Tags should not contain spaces or special characters that might break parsing
  if tag:match "%s" or tag:match "^[%+%-]" then
    return false
  end
  
  return true
end

-- Function to validate a task structure
-- @param task: Task object to validate
-- @return: true if valid, false otherwise, error message
function M.validate_task(task)
  if not task or type(task) ~= "table" then
    return false, "Task must be a table"
  end
  
  if not task.uuid or type(task.uuid) ~= "string" or #task.uuid == 0 then
    return false, "Task must have a valid UUID"
  end
  
  if not task.description or type(task.description) ~= "string" or #task.description == 0 then
    return false, "Task must have a non-empty description"
  end
  
  if not task.status or type(task.status) ~= "string" then
    return false, "Task must have a status"
  end
  
  if task.status ~= "pending" and task.status ~= "completed" and task.status ~= "active" then
    return false, string.format("Invalid task status: %s", task.status)
  end
  
  if task.due and not M.is_valid_date_format(task.due) then
    return false, string.format("Invalid due date format: %s (expected YYYY-MM-DD)", task.due)
  end
  
  if task.tags then
    if type(task.tags) ~= "table" then
      return false, "Task tags must be a table/array"
    end
    for _, tag in ipairs(task.tags) do
      if not M.is_valid_tag(tag) then
        return false, string.format("Invalid tag: %s", tag)
      end
    end
  end
  
  return true, nil
end

-- Function to validate task ID (display ID)
-- @param task_id: Task ID to validate
-- @param max_id: Maximum valid task ID
-- @return: true if valid, false otherwise
function M.is_valid_task_id(task_id, max_id)
  if type(task_id) ~= "number" then
    return false
  end
  
  if task_id < 1 or task_id > max_id then
    return false
  end
  
  return true
end

return M

