local task = require "mikro_taskwarrior.core.task"
local date_utils = require "mikro_taskwarrior.utils.date"
local string_utils = require "mikro_taskwarrior.utils.string"
local config = require "mikro_taskwarrior.config"

local M = {}

-- Create the :Task command
function M.setup()
  vim.api.nvim_create_user_command("Task", function(opts)
    local args = opts.fargs

    -- First pass: find the command to determine context
    local cmd_index = nil
    local cmd = nil
    for i, arg in ipairs(args) do
      if arg == "list" or arg == "add" or arg == "modify" or arg == "done" or arg == "info" then
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

          -- Handle smart date keywords
          if due_str == "today" then
            modifications.due = os.date "%Y-%m-%d"
          elseif due_str == "tomorrow" then
            modifications.due = os.date("%Y-%m-%d", os.time() + 86400)
          elseif due_str:match "^%d+d$" then
            -- Relative days: 1d, 5d, 30d
            local days = tonumber(due_str:match "^(%d+)d$")
            modifications.due = os.date("%Y-%m-%d", os.time() + days * 86400)
          elseif due_str:match "^%d+w$" then
            -- Relative weeks: 1w, 2w, 4w
            local weeks = tonumber(due_str:match "^(%d+)w$")
            modifications.due = os.date("%Y-%m-%d", os.time() + weeks * 7 * 86400)
          elseif due_str:match "^%d+m$" then
            -- Relative months: 1m, 2m, 6m (approximate as 30 days)
            local months = tonumber(due_str:match "^(%d+)m$")
            modifications.due = os.date("%Y-%m-%d", os.time() + months * 30 * 86400)
          elseif due_str == "monday" or due_str == "mon" then
            local current_day = tonumber(os.date "%u")
            local days_until = (8 - current_day) % 7
            if days_until == 0 then days_until = 7 end
            modifications.due = os.date("%Y-%m-%d", os.time() + days_until * 86400)
          elseif due_str == "tuesday" or due_str == "tue" then
            local current_day = tonumber(os.date "%u")
            local days_until = (9 - current_day) % 7
            if days_until == 0 then days_until = 7 end
            modifications.due = os.date("%Y-%m-%d", os.time() + days_until * 86400)
          elseif due_str == "wednesday" or due_str == "wed" then
            local current_day = tonumber(os.date "%u")
            local days_until = (10 - current_day) % 7
            if days_until == 0 then days_until = 7 end
            modifications.due = os.date("%Y-%m-%d", os.time() + days_until * 86400)
          elseif due_str == "thursday" or due_str == "thu" then
            local current_day = tonumber(os.date "%u")
            local days_until = (11 - current_day) % 7
            if days_until == 0 then days_until = 7 end
            modifications.due = os.date("%Y-%m-%d", os.time() + days_until * 86400)
          elseif due_str == "friday" or due_str == "fri" then
            local current_day = tonumber(os.date "%u")
            local days_until = (12 - current_day) % 7
            if days_until == 0 then days_until = 7 end
            modifications.due = os.date("%Y-%m-%d", os.time() + days_until * 86400)
          elseif due_str == "saturday" or due_str == "sat" then
            local current_day = tonumber(os.date "%u")
            local days_until = (13 - current_day) % 7
            if days_until == 0 then days_until = 7 end
            modifications.due = os.date("%Y-%m-%d", os.time() + days_until * 86400)
          elseif due_str == "sunday" or due_str == "sun" then
            local current_day = tonumber(os.date "%u")
            local days_until = (14 - current_day) % 7
            if days_until == 0 then days_until = 7 end
            modifications.due = os.date("%Y-%m-%d", os.time() + days_until * 86400)
          elseif due_str:match "^%d%d%d%d%-%d%d?%-%d%d?$" then
            -- Regular date format
            local year, month, day = due_str:match "^(%d+)%-(%d+)%-(%d+)$"
            if year and month and day then
              modifications.due = string.format("%s-%s-%s", year, month:gsub("^%d$", "0%1"), day:gsub("^%d$", "0%1"))
            end
          end
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
    elseif cmd == "info" then
      -- Expand ~ to home directory for display
      local display_path = config.TASKS_FILE
      if display_path:match "^~" then
        display_path = vim.fn.expand(display_path)
      end
      print(string.format("Tasks file: %s", display_path))
    else
      print "Usage: :Task [+tag] [-tag] [<id>] list|add <description>|modify [due:YYYY-MM-DD] [+tag] [-tag]|<id> done|info"
    end
  end, {
    nargs = "+",
    complete = function(arglead, cmdline, cursorpos)
      local commands = { "list", "add", "modify", "done", "info" }
      return vim.tbl_filter(function(val) return vim.startswith(val, arglead) end, commands)
    end,
  })
end

return M

