local M = {}

-- Path to the tasks.json file
M.TASKS_FILE = vim.fn.stdpath "data" .. "/mikro_taskwarrior/tasks.json"

return M

