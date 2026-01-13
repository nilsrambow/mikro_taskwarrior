local commands = require "mikro_taskwarrior.commands"
local task = require "mikro_taskwarrior.core.task"
local config = require "mikro_taskwarrior.config"

local M = {}

-- Setup the plugin
function M.setup(opts)
  -- Configure the plugin with user options
  config.setup(opts)
  -- Setup commands
  commands.setup()
end

-- Expose public API
M.list_tasks = task.list_tasks
M.add_task = task.add_task
M.mark_task_done_by_id = task.mark_task_done_by_id
M.modify_tasks = task.modify_tasks

-- Auto-setup when plugin is loaded (with default options)
M.setup()

return M

