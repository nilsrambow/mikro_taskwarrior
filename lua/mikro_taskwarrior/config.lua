local M = {}

-- Default path to the tasks.json file
local default_tasks_file = vim.fn.stdpath "data" .. "/mikro_taskwarrior/tasks.json"
M.TASKS_FILE = default_tasks_file

-- Setup function to configure the plugin
function M.setup(opts)
  opts = opts or {}
  if opts.tasks_file then
    M.TASKS_FILE = opts.tasks_file
  end
end

return M

