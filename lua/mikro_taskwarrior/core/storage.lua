local config = require "mikro_taskwarrior.config"

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
  
  return result or {}
end

-- Function to write tasks to the JSON file
function M.write_tasks(tasks)
  -- Ensure the directory exists
  local dir = vim.fn.fnamemodify(config.TASKS_FILE, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local file = io.open(config.TASKS_FILE, "w")
  if not file then
    vim.notify("Failed to write to tasks.json!", vim.log.levels.ERROR)
    return
  end
 -- vim.json.encode only takes one argument (the data)
  -- For pretty printing, we can use vim.fn.json_encode and format it
  local json_str = vim.json.encode(tasks)
  file:write(json_str)
  file:close()
end

return M

