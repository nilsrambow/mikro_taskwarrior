local task = require "mikro_taskwarrior.core.task"
local date_utils = require "mikro_taskwarrior.utils.date"
local string_utils = require "mikro_taskwarrior.utils.string"

local M = {}

-- Create the :Task command
function M.setup()
  vim.api.nvim_create_user_command("Task", function(opts)
    local args = opts.fargs

    -- First pass: find the command to determine context
    local cmd_index = nil
    local cmd = nil
    for i, arg in ipairs(args) do
      if arg == "list" or arg == "add" or arg == "modify" or arg == "done" then
        cmd_index = i
        cmd = arg
        break
      end
    end

    -- Parse filters and remaining args based on command context
    local filter_tags = {}
    local exclude_tags = {}
    local remaining_args = {}
    local task_id = nil

    for i, arg in ipairs(args) do
      if cmd == "modify" and i > cmd_index then
        -- After "modify" command, don't parse as filters
        table.insert(remaining_args, arg)
      elseif arg:match "^%+.+" then
        local tag = arg:sub(2)
        table.insert(filter_tags, tag)
      elseif arg:match "^%-.+" then
        local tag = arg:sub(2)
        table.insert(exclude_tags, tag)
      else
        table.insert(remaining_args, arg)
      end
    end

    -- Check if first remaining arg is a number (task ID)
    local first_is_number = tonumber(remaining_args[1])
    if first_is_number and remaining_args[2] then
      task_id = first_is_number
      cmd = remaining_args[2]
    elseif not cmd then
      cmd = remaining_args[1]
    end

    if cmd == "list" then
      task.list_tasks(#filter_tags > 0 and filter_tags or nil, #exclude_tags > 0 and exclude_tags or nil, task_id)
    elseif cmd == "add" then
      if not remaining_args[2] and not first_is_number then
        print "Usage: :Task add <description> [due:YYYY-MM-DD] [+tag1 +tag2 ...]"
        return
      end
      task.add_task { unpack(args, 2) }
    elseif cmd == "modify" then
      -- Check if filter is provided (mandatory for modify)
      if #filter_tags == 0 and #exclude_tags == 0 and not task_id then
        print "Error: Filter is mandatory for modify command. Use +tag, -tag, or task ID."
        return
      end

      -- Parse modifications from args after "modify" command
      local modifications = {
        due = nil,
        add_tags = {},
        remove_tags = {},
      }

      for i = cmd_index + 1, #args do
        local arg = args[i]
        if arg:lower():match "^due:" then
          local due_str = arg:lower():gsub("due:", "")
          modifications.due = date_utils.parse_due_date_from_string(due_str)
        elseif arg:match "^%+.+" then
          local tag = arg:sub(2)
          table.insert(modifications.add_tags, tag)
        elseif arg:match "^%-.+" then
          local tag = arg:sub(2)
          table.insert(modifications.remove_tags, tag)
        end
      end

      -- Ensure at least one modification is provided
      if not modifications.due and #modifications.add_tags == 0 and #modifications.remove_tags == 0 then
        print "Error: No modifications specified. Use due:YYYY-MM-DD, +tag to add, or -tag to remove."
        return
      end

      task.modify_tasks(
        #filter_tags > 0 and filter_tags or nil,
        #exclude_tags > 0 and exclude_tags or nil,
        task_id,
        modifications
      )
    elseif cmd == "done" then
      if not task_id then
        print "Usage: :Task <id> done"
        return
      end
      task.mark_task_done_by_id(task_id)
    else
      print "Usage: :Task [+tag] [-tag] [<id>] list|add <description>|modify [due:YYYY-MM-DD] [+tag] [-tag]|<id> done"
    end
  end, {
    nargs = "+",
    complete = function(arglead, cmdline, cursorpos)
      local commands = { "list", "add", "modify", "done" }
      return vim.tbl_filter(function(val) return vim.startswith(val, arglead) end, commands)
    end,
  })
end

return M

