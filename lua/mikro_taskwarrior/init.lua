local commands = require "mikro_taskwarrior.commands"
local task = require "mikro_taskwarrior.core.task"

local M = {}

-- Setup the plugin
function M.setup()
  commands.setup()
end

-- Expose public API
M.list_tasks = task.list_tasks
M.add_task = task.add_task
M.mark_task_done_by_id = task.mark_task_done_by_id
M.modify_tasks = task.modify_tasks

-- Auto-setup when plugin is loaded
M.setup()

return M

