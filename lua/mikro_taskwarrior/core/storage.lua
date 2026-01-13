local config = require "mikro_taskwarrior.config"
local validation = require "mikro_taskwarrior.utils.validation"

local M = {}

-- Function to read tasks from the JSON file
function M.read_tasks()
  local file = io.open(config.TASKS_FILE, "r")
  if not file then
    vim.notify("tasks.json not found! Creating a new file.", vim.log.levels.WARN)
    return {}
  end
  local content = file:read "*a"
  file:close()
  
  -- Handle empty file or invalid JSON
  if not content or content:match("^%s*$") then
    return {}
  end
  
  local success, result = pcall(vim.json.decode, content)
  if not success then
    vim.notify("Error reading tasks.json: invalid JSON. Starting with empty tasks.", vim.log.levels.WARN)
    return {}
  end
  
  -- Validate task structures
  if result and type(result) == "table" then
    local valid_tasks = {}
    for _, task in ipairs(result) do
      local is_valid, error_msg = validation.validate_task(task)
      if is_valid then
        table.insert(valid_tasks, task)
      else
        vim.notify(string.format("Skipping invalid task (UUID: %s): %s", task.uuid or "unknown", error_msg or "unknown error"), vim.log.levels.WARN)
      end
    end
    return valid_tasks
  end
  
  return {}
end

---Write tasks to the JSON file
---@param tasks Task[] Array of tasks to write
---@return boolean success Whether the write operation succeeded
function M.write_tasks(tasks)
  -- Ensure the directory exists
  local dir = vim.fn.fnamemodify(config.TASKS_FILE, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local file = io.open(config.TASKS_FILE, "w")
  if not file then
    vim.notify("Failed to write to tasks.json!", vim.log.levels.ERROR)
    return false
  end
  
  local json_str = vim.json.encode(tasks)
  local success = file:write(json_str)
  file:close()
  
  if not success then
    vim.notify("Failed to write data to tasks.json!", vim.log.levels.ERROR)
    return false
  end
  
  return true
end

return M

