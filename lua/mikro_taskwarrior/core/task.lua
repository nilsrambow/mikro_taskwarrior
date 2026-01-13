local storage = require "mikro_taskwarrior.core.storage"
local urgency = require "mikro_taskwarrior.core.urgency"
local date_utils = require "mikro_taskwarrior.utils.date"
local uuid_utils = require "mikro_taskwarrior.utils.uuid"
local string_utils = require "mikro_taskwarrior.utils.string"
local window = require "mikro_taskwarrior.ui.window"

local M = {}

-- Function to list only open tasks with sequential display IDs
function M.list_tasks(filter_tags, exclude_tags, task_id)
  local tasks = storage.read_tasks()
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
        task.urgency = urgency.calculate_urgency(task)
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
      window.create_float_window(lines)
      return
    end
    open_tasks = { open_tasks[task_id] }
  end

  if vim.tbl_isempty(open_tasks) then
    local lines = { "No open tasks found." }
    window.create_float_window(lines)
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
    window.create_float_window(lines)
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
  local header = string_utils.pad_string("ID", id_width)
    .. " "
    .. string_utils.pad_string("Urg", urg_width)
    .. " "
    .. string_utils.pad_string("Age", age_width)
    .. " "
    .. string_utils.pad_string("Due", due_width)
    .. " "
    .. string_utils.pad_string("Tags", tags_width)
    .. " "
    .. string_utils.pad_string("Description", desc_width)
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

    local row = string_utils.pad_string(tostring(i), id_width, "right")
      .. " "
      .. string_utils.pad_string(urg_str, urg_width, "right")
      .. " "
      .. string_utils.pad_string(age, age_width)
      .. " "
      .. string_utils.pad_string(due_str, due_width)
      .. " "
      .. string_utils.pad_string(tags_str, tags_width)
      .. " "
      .. string_utils.pad_string(desc, desc_width)
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

  window.create_float_window(lines)
end

-- Function to add a new task
function M.add_task(args)
  local description_parts = {}
  local due_date = date_utils.parse_due_date(args)
  local tags = string_utils.parse_tags(args)

  -- Rebuild description, excluding the due date (smart keywords or regular dates) and tags
  for _, arg in ipairs(args) do
    if not arg:lower():match "^due:" and not arg:match "^%+.+" then table.insert(description_parts, arg) end
  end

  local description = table.concat(description_parts, " ")
  if not description or description == "" then
    print "Error: Description cannot be empty."
    return
  end

  local tasks = storage.read_tasks()
  local new_task = {
    uuid = uuid_utils.generate_uuid(),
    description = description,
    status = "pending",
    entry = date_utils.get_current_timestamp(),
    due = due_date,
    tags = tags,
  }
  table.insert(tasks, new_task)
  storage.write_tasks(tasks)

  local tags_info = tags and string.format(" [tags: %s]", table.concat(tags, ", ")) or ""
  local due_info = due_date and string.format(" [due: %s]", due_date) or ""
  print(string.format("Task added: %s%s%s (UUID: %s)", description, tags_info, due_info, new_task.uuid))
end

-- Function to mark a task as done by display ID
function M.mark_task_done_by_id(display_id)
  local tasks = storage.read_tasks()
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

  storage.write_tasks(tasks)
  print(string.format("Task marked as done: ID %d", display_id))
end

-- Function to modify tasks based on filters
function M.modify_tasks(filter_tags, exclude_tags, task_id, modifications)
  local tasks = storage.read_tasks()
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
        -- Calculate urgency for each task (same as list_tasks)
        task.urgency = urgency.calculate_urgency(task)
        table.insert(open_tasks, task)
        table.insert(open_tasks_indices, idx)
      end
    end
  end

  -- Sort by urgency (highest first) - same as list_tasks
  -- We need to sort both arrays together to maintain the index mapping
  local combined = {}
  for i = 1, #open_tasks do
    table.insert(combined, {
      task = open_tasks[i],
      original_idx = open_tasks_indices[i],
      urgency = open_tasks[i].urgency or 0
    })
  end
  table.sort(combined, function(a, b) return a.urgency > b.urgency end)
  
  -- Rebuild the sorted arrays
  open_tasks = {}
  open_tasks_indices = {}
  for _, item in ipairs(combined) do
    table.insert(open_tasks, item.task)
    table.insert(open_tasks_indices, item.original_idx)
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

  storage.write_tasks(tasks)
  print(string.format("Modified %d task(s).", modified_count))
end

return M

