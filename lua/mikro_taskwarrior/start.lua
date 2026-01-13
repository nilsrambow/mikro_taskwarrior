local M = {}

-- Path to the tasks.json file
local TASKS_FILE = vim.fn.stdpath "data" .. "/mikro_taskwarrior/tasks.json"

-- Function to read tasks from the JSON file
local function read_tasks()
  local file = io.open(TASKS_FILE, "r")
  if not file then
    vim.notify("tasks.json not found! Creating a new file.", vim.log.levels.WARN)
    return {}
  end
  local content = file:read "*a"
  file:close()
  return vim.json.decode(content) or {}
end

-- Function to write tasks to the JSON file
local function write_tasks(tasks)
  local file = io.open(TASKS_FILE, "w")
  if not file then
    vim.notify("Failed to write to tasks.json!", vim.log.levels.ERROR)
    return
  end
  file:write(vim.json.encode(tasks, { indent = true }))
  file:close()
end

-- Function to generate a UUID (simplified for testing)
local function generate_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return template:gsub("[xy]", function(c)
    local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
    return string.format("%x", v)
  end)
end

-- Function to get current timestamp in ISO 8601 format
local function get_current_timestamp() return os.date "%Y%m%dT%H%M%SZ" end

-- Urgency coefficients (matching Taskwarrior defaults)
local URGENCY = {
  next_coefficient = 15.0,
  due_coefficient = 12.0,
  priority_coefficient = 6.0, -- H=6.0, M=3.9, L=1.8
  active_coefficient = 4.0,
  age_coefficient = 2.0,
  age_max = 365, -- days
  project_coefficient = 1.0,
  tags_coefficient = 1.0,
  annotations_coefficient = 1.0,
  waiting_coefficient = -3.0,
  blocked_coefficient = -5.0,
  due_max = 7, -- days overdue when urgency maxes out (can be configured)
}

-- Function to calculate urgency for a task
local function calculate_urgency(task)
  local urgency = 0.0

  -- Tags coefficient (1.0 if task has any tags)
  if task.tags and #task.tags > 0 then
    urgency = urgency + URGENCY.tags_coefficient

    -- Next tag (15.0)
    for _, tag in ipairs(task.tags) do
      if tag == "next" then
        urgency = urgency + URGENCY.next_coefficient
        break
      end
    end
  end

  -- Due date coefficient - Using Taskwarrior's exact formula
  if task.due then
    local year, month, day = task.due:match "(%d%d%d%d)%-(%d%d)%-(%d%d)"
    if year then
      local due_time =
        os.time { year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 0, min = 0, sec = 0 }
      local now = os.time()
      local seconds_until_due = due_time - now
      local days_until_due = seconds_until_due / 86400.0

      -- Taskwarrior formula:
      -- days_overdue = (now - due) / 86400.0
      -- So days_overdue = -days_until_due
      local days_overdue = -days_until_due

      local due_factor
      if URGENCY.due_max == 0 or days_overdue > URGENCY.due_max then
        -- Overdue beyond max: full urgency
        due_factor = 1.0
      elseif days_overdue >= -14.0 then
        -- Within 14 days before or overdue up to due_max days:
        -- Linear scale from 0.2 (at -14 days) to 1.0 (at due_max days overdue)
        due_factor = ((days_overdue + 14.0) * 0.8 / 21.0) + 0.2
      else
        -- More than 14 days away: minimum urgency
        due_factor = 0.2
      end

      urgency = urgency + URGENCY.due_coefficient * due_factor
    end
  end

  -- Age coefficient (2.0, increases over time up to age_max)
  if task.entry then
    local year, month, day = task.entry:match "(%d%d%d%d)(%d%d)(%d%d)"
    if year then
      local task_time =
        os.time { year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 0, min = 0, sec = 0 }
      local age_days = math.floor((os.time() - task_time) / 86400)
      local age_factor = math.min(1.0, age_days / URGENCY.age_max)
      urgency = urgency + URGENCY.age_coefficient * age_factor
    end
  end

  -- Active status (4.0) - we could track this if we add a "start" timestamp
  if task.status == "active" then urgency = urgency + URGENCY.active_coefficient end

  return urgency
end

-- Function to parse due date from command
local function parse_due_date(args)
  for i, arg in ipairs(args) do
    if arg:lower():match "^due:" then
      local due_str = arg:lower():gsub("due:", "")

      -- Handle smart date keywords
      if due_str == "today" then
        return os.date "%Y-%m-%d"
      elseif due_str == "tomorrow" then
        return os.date("%Y-%m-%d", os.time() + 86400)
      elseif due_str:match "^%d+d$" then
        -- Relative days: 1d, 5d, 30d
        local days = tonumber(due_str:match "^(%d+)d$")
        return os.date("%Y-%m-%d", os.time() + days * 86400)
      elseif due_str:match "^%d+w$" then
        -- Relative weeks: 1w, 2w, 4w
        local weeks = tonumber(due_str:match "^(%d+)w$")
        return os.date("%Y-%m-%d", os.time() + weeks * 7 * 86400)
      elseif due_str:match "^%d+m$" then
        -- Relative months: 1m, 2m, 6m (approximate as 30 days)
        local months = tonumber(due_str:match "^(%d+)m$")
        return os.date("%Y-%m-%d", os.time() + months * 30 * 86400)
      elseif due_str == "monday" or due_str == "mon" then
        local current_day = tonumber(os.date "%u") -- 1=Mon, 7=Sun
        local days_until = (8 - current_day) % 7
        if days_until == 0 then days_until = 7 end
        return os.date("%Y-%m-%d", os.time() + days_until * 86400)
      elseif due_str == "tuesday" or due_str == "tue" then
        local current_day = tonumber(os.date "%u")
        local days_until = (9 - current_day) % 7
        if days_until == 0 then days_until = 7 end
        return os.date("%Y-%m-%d", os.time() + days_until * 86400)
      elseif due_str == "wednesday" or due_str == "wed" then
        local current_day = tonumber(os.date "%u")
        local days_until = (10 - current_day) % 7
        if days_until == 0 then days_until = 7 end
        return os.date("%Y-%m-%d", os.time() + days_until * 86400)
      elseif due_str == "thursday" or due_str == "thu" then
        local current_day = tonumber(os.date "%u")
        local days_until = (11 - current_day) % 7
        if days_until == 0 then days_until = 7 end
        return os.date("%Y-%m-%d", os.time() + days_until * 86400)
      elseif due_str == "friday" or due_str == "fri" then
        local current_day = tonumber(os.date "%u")
        local days_until = (12 - current_day) % 7
        if days_until == 0 then days_until = 7 end
        return os.date("%Y-%m-%d", os.time() + days_until * 86400)
      elseif due_str == "saturday" or due_str == "sat" then
        local current_day = tonumber(os.date "%u")
        local days_until = (13 - current_day) % 7
        if days_until == 0 then days_until = 7 end
        return os.date("%Y-%m-%d", os.time() + days_until * 86400)
      elseif due_str == "sunday" or due_str == "sun" then
        local current_day = tonumber(os.date "%u")
        local days_until = (14 - current_day) % 7
        if days_until == 0 then days_until = 7 end
        return os.date("%Y-%m-%d", os.time() + days_until * 86400)
      elseif due_str:match "^%d%d%d%d%-%d%d?%-%d%d?$" then
        -- Regular date format YYYY-MM-DD
        local year, month, day = due_str:match "^(%d+)%-(%d+)%-(%d+)$"
        if year and month and day then
          return string.format("%s-%s-%s", year, month:gsub("^%d$", "0%1"), day:gsub("^%d$", "0%1"))
        end
      end
    end
  end
  return nil
end

-- Function to parse tags from command (words starting with +)
local function parse_tags(args)
  local tags = {}
  for _, arg in ipairs(args) do
    if arg:match "^%+.+" then
      local tag = arg:sub(2) -- Remove the + prefix
      table.insert(tags, tag)
    end
  end
  return #tags > 0 and tags or nil
end

-- Function to create a centered floating window
local function create_float_window(lines)
  -- Set width to 80% of screen width
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.min(#lines + 2, vim.o.lines - 4)

  -- Calculate position to center the window
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "taskwarrior")

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Window options
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Open Tasks ",
    title_pos = "center",
  }

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set window options
  vim.api.nvim_win_set_option(win, "wrap", false)
  vim.api.nvim_win_set_option(win, "cursorline", true)

  -- Set keymaps for the floating window
  local keymaps = {
    { "n", "q", "<cmd>close<cr>", { noremap = true, silent = true } },
    { "n", "<Esc>", "<cmd>close<cr>", { noremap = true, silent = true } },
  }

  for _, keymap in ipairs(keymaps) do
    vim.api.nvim_buf_set_keymap(buf, keymap[1], keymap[2], keymap[3], keymap[4])
  end

  return buf, win
end

-- Function to pad string to specific width
local function pad_string(str, width, align)
  align = align or "left"
  local len = #str
  if len >= width then return str:sub(1, width) end
  local padding = width - len
  if align == "right" then
    return string.rep(" ", padding) .. str
  else
    return str .. string.rep(" ", padding)
  end
end

-- Function to list only open tasks with sequential display IDs
function M.list_tasks(filter_tags, exclude_tags, task_id)
  local tasks = read_tasks()
  local open_tasks = {}

  -- Filter out completed tasks
  for _, task in ipairs(tasks) do
    if task.status ~= "completed" then
      local include_task = true

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
        include_task = has_all_tags
      end

      -- Apply negative tag filter (exclude tasks with these tags)
      if include_task and exclude_tags and #exclude_tags > 0 then
        if task.tags then
          for _, exclude_tag in ipairs(exclude_tags) do
            for _, task_tag in ipairs(task.tags) do
              if task_tag == exclude_tag then
                include_task = false
                break
              end
            end
            if not include_task then break end
          end
        end
      end

      if include_task then
        -- Calculate urgency for each task
        task.urgency = calculate_urgency(task)
        table.insert(open_tasks, task)
      end
    end
  end

  -- Sort by urgency (highest first)
  table.sort(open_tasks, function(a, b) return (a.urgency or 0) > (b.urgency or 0) end)

  -- If task_id is provided, filter to show only that task
  if task_id then
    if task_id < 1 or task_id > #open_tasks then
      local lines = { string.format("Task ID %d not found.", task_id) }
      create_float_window(lines)
      return
    end
    open_tasks = { open_tasks[task_id] }
  end

  if vim.tbl_isempty(open_tasks) then
    local lines = { "No open tasks found." }
    create_float_window(lines)
    return
  end

  local lines = {}

  -- If showing a single task, use detailed view
  if task_id then
    local task = open_tasks[1]
    table.insert(lines, string.format("ID: %d", task_id))
    table.insert(lines, string.format("UUID: %s", task.uuid))
    table.insert(lines, string.format("Description: %s", task.description))
    table.insert(lines, string.format("Status: %s", task.status))
    table.insert(lines, string.format("Urgency: %.2f", task.urgency or 0))
    table.insert(lines, string.format("Created: %s", task.entry))
    if task.due then table.insert(lines, string.format("Due: %s", task.due)) end
    if task.tags and #task.tags > 0 then
      table.insert(lines, string.format("Tags: %s", table.concat(task.tags, ", ")))
    end
    create_float_window(lines)
    return
  end

  -- Column widths for table view
  local id_width = 4
  local urg_width = 6
  local age_width = 6
  local due_width = 12
  local tags_width = 25 -- Increased from 12
  local desc_width = math.floor(vim.o.columns * 0.8) - (id_width + urg_width + age_width + due_width + tags_width + 10) -- Dynamic, uses remaining space

  -- Header
  local header = pad_string("ID", id_width)
    .. " "
    .. pad_string("Urg", urg_width)
    .. " "
    .. pad_string("Age", age_width)
    .. " "
    .. pad_string("Due", due_width)
    .. " "
    .. pad_string("Tags", tags_width)
    .. " "
    .. pad_string("Description", desc_width)
  table.insert(lines, header)

  -- Separator line
  local separator = string.rep("-", id_width)
    .. " "
    .. string.rep("-", urg_width)
    .. " "
    .. string.rep("-", age_width)
    .. " "
    .. string.rep("-", due_width)
    .. " "
    .. string.rep("-", tags_width)
    .. " "
    .. string.rep("-", desc_width)
  table.insert(lines, separator)

  -- Task rows
  for i, task in ipairs(open_tasks) do
    -- Calculate age (simplified)
    local age = "0d"
    if task.entry then
      local year, month, day = task.entry:match "(%d%d%d%d)(%d%d)(%d%d)"
      if year then
        local task_time = os.time { year = year, month = month, day = day, hour = 0, min = 0, sec = 0 }
        local diff = os.difftime(os.time(), task_time)
        local days = math.floor(diff / 86400)
        if days < 365 then
          age = string.format("%dd", days)
        else
          age = string.format("%dy", math.floor(days / 365))
        end
      end
    end

    -- Format urgency
    local urg_str = string.format("%.1f", task.urgency or 0)

    -- Format due date
    local due_str = task.due or ""

    -- Format tags
    local tags_str = ""
    if task.tags and #task.tags > 0 then
      tags_str = table.concat(task.tags, ",")
      if #tags_str > tags_width then tags_str = tags_str:sub(1, tags_width - 3) .. "..." end
    end

    -- Format description (truncate if too long)
    local desc = task.description
    if #desc > desc_width then desc = desc:sub(1, desc_width - 3) .. "..." end

    local row = pad_string(tostring(i), id_width, "right")
      .. " "
      .. pad_string(urg_str, urg_width, "right")
      .. " "
      .. pad_string(age, age_width)
      .. " "
      .. pad_string(due_str, due_width)
      .. " "
      .. pad_string(tags_str, tags_width)
      .. " "
      .. pad_string(desc, desc_width)
    table.insert(lines, row)
  end

  -- Footer with count and filter info
  table.insert(lines, "")
  local filter_parts = {}
  if filter_tags and #filter_tags > 0 then table.insert(filter_parts, "+" .. table.concat(filter_tags, " +")) end
  if exclude_tags and #exclude_tags > 0 then table.insert(filter_parts, "-" .. table.concat(exclude_tags, " -")) end

  if #filter_parts > 0 then
    table.insert(lines, string.format("%d tasks (filtered by: %s)", #open_tasks, table.concat(filter_parts, " ")))
  else
    table.insert(lines, string.format("%d tasks", #open_tasks))
  end

  create_float_window(lines)
end

-- Function to add a new task
function M.add_task(args)
  local description_parts = {}
  local due_date = parse_due_date(args)
  local tags = parse_tags(args)

  -- Rebuild description, excluding the due date (smart keywords or regular dates) and tags
  for _, arg in ipairs(args) do
    if not arg:lower():match "^due:" and not arg:match "^%+.+" then table.insert(description_parts, arg) end
  end

  local description = table.concat(description_parts, " ")
  if not description or description == "" then
    print "Error: Description cannot be empty."
    return
  end

  local tasks = read_tasks()
  local new_task = {
    uuid = generate_uuid(),
    description = description,
    status = "pending",
    entry = get_current_timestamp(),
    due = due_date,
    tags = tags,
  }
  table.insert(tasks, new_task)
  write_tasks(tasks)

  local tags_info = tags and string.format(" [tags: %s]", table.concat(tags, ", ")) or ""
  local due_info = due_date and string.format(" [due: %s]", due_date) or ""
  print(string.format("Task added: %s%s%s (UUID: %s)", description, tags_info, due_info, new_task.uuid))
end

-- Function to mark a task as done by display ID
function M.mark_task_done_by_id(display_id)
  local tasks = read_tasks()
  local open_tasks = {}

  -- Filter out completed tasks to calculate display IDs
  for _, task in ipairs(tasks) do
    if task.status ~= "completed" then table.insert(open_tasks, task) end
  end

  -- Check if display_id is valid
  if display_id < 1 or display_id > #open_tasks then
    print(string.format("Invalid task ID: %d", display_id))
    return
  end

  -- Find the task in the full list by matching UUIDs
  local target_uuid = open_tasks[display_id].uuid
  for _, task in ipairs(tasks) do
    if task.uuid == target_uuid then
      task.status = "completed"
      break
    end
  end

  write_tasks(tasks)
  print(string.format("Task marked as done: ID %d", display_id))
end

-- Function to modify tasks based on filters
function M.modify_tasks(filter_tags, exclude_tags, task_id, modifications)
  local tasks = read_tasks()
  local open_tasks = {}
  local open_tasks_indices = {}

  -- Filter out completed tasks and track their original indices
  for idx, task in ipairs(tasks) do
    if task.status ~= "completed" then
      local include_task = true

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
        include_task = has_all_tags
      end

      -- Apply negative tag filter
      if include_task and exclude_tags and #exclude_tags > 0 then
        if task.tags then
          for _, exclude_tag in ipairs(exclude_tags) do
            for _, task_tag in ipairs(task.tags) do
              if task_tag == exclude_tag then
                include_task = false
                break
              end
            end
            if not include_task then break end
          end
        end
      end

      if include_task then
        table.insert(open_tasks, task)
        table.insert(open_tasks_indices, idx)
      end
    end
  end

  -- If task_id is provided, only modify that specific task
  local tasks_to_modify = {}
  local tasks_to_modify_indices = {}

  if task_id then
    if task_id < 1 or task_id > #open_tasks then
      print(string.format("Invalid task ID: %d", task_id))
      return
    end
    table.insert(tasks_to_modify, open_tasks[task_id])
    table.insert(tasks_to_modify_indices, open_tasks_indices[task_id])
  else
    tasks_to_modify = open_tasks
    tasks_to_modify_indices = open_tasks_indices
  end

  if #tasks_to_modify == 0 then
    print "No tasks matched the filter."
    return
  end

  -- Apply modifications to matched tasks
  local modified_count = 0
  for i, task in ipairs(tasks_to_modify) do
    local original_idx = tasks_to_modify_indices[i]
    local modified = false

    -- Modify due date
    if modifications.due then
      tasks[original_idx].due = modifications.due
      modified = true
    end

    -- Add tags
    if modifications.add_tags then
      if not tasks[original_idx].tags then tasks[original_idx].tags = {} end
      for _, new_tag in ipairs(modifications.add_tags) do
        -- Check if tag already exists
        local exists = false
        for _, existing_tag in ipairs(tasks[original_idx].tags) do
          if existing_tag == new_tag then
            exists = true
            break
          end
        end
        if not exists then
          table.insert(tasks[original_idx].tags, new_tag)
          modified = true
        end
      end
    end

    -- Remove tags
    if modifications.remove_tags then
      if tasks[original_idx].tags then
        for _, tag_to_remove in ipairs(modifications.remove_tags) do
          for j = #tasks[original_idx].tags, 1, -1 do
            if tasks[original_idx].tags[j] == tag_to_remove then
              table.remove(tasks[original_idx].tags, j)
              modified = true
            end
          end
        end
        -- Clean up empty tags array
        if #tasks[original_idx].tags == 0 then tasks[original_idx].tags = nil end
      end
    end

    if modified then modified_count = modified_count + 1 end
  end

  write_tasks(tasks)
  print(string.format("Modified %d task(s).", modified_count))
end

-- Create the :Task command
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
    M.list_tasks(#filter_tags > 0 and filter_tags or nil, #exclude_tags > 0 and exclude_tags or nil, task_id)
  elseif cmd == "add" then
    if not remaining_args[2] and not first_is_number then
      print "Usage: :Task add <description> [due:YYYY-MM-DD] [+tag1 +tag2 ...]"
      return
    end
    M.add_task { unpack(args, 2) }
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

    M.modify_tasks(
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
    M.mark_task_done_by_id(task_id)
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

return M
