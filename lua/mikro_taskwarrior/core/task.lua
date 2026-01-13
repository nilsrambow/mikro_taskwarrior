local storage = require "mikro_taskwarrior.core.storage"
local urgency = require "mikro_taskwarrior.core.urgency"
local filter = require "mikro_taskwarrior.core.filter"
local date_utils = require "mikro_taskwarrior.utils.date"
local uuid_utils = require "mikro_taskwarrior.utils.uuid"
local string_utils = require "mikro_taskwarrior.utils.string"
local validation = require "mikro_taskwarrior.utils.validation"
local window = require "mikro_taskwarrior.ui.window"

---@class Task
---@field uuid string
---@field description string
---@field status "pending"|"completed"|"active"
---@field entry string ISO 8601 timestamp
---@field due string|nil Date in YYYY-MM-DD format
---@field tags string[]|nil Array of tag strings
---@field urgency number|nil Calculated urgency score

---@class TaskModifications
---@field due string|nil New due date
---@field add_tags string[]|nil Tags to add
---@field remove_tags string[]|nil Tags to remove

local M = {}

---Get filtered and sorted tasks
---@param filter_tags string[]|nil Tags that must all be present
---@param exclude_tags string[]|nil Tags that must not be present
---@return Task[]
local function get_filtered_tasks(filter_tags, exclude_tags)
  local tasks = storage.read_tasks()
  local open_tasks = filter.filter_tasks(tasks, filter_tags, exclude_tags, "pending", true)
  filter.sort_tasks_by_urgency(open_tasks)
  return open_tasks
end

---Format a single task for detailed view
---@param task Task
---@param task_id number
---@return string[]
local function format_task_detail_view(task, task_id)
  local lines = {}
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
  return lines
end

---Calculate task age from entry timestamp
---@param entry string|nil ISO 8601 timestamp
---@return string Age string (e.g., "5d", "1y")
local function calculate_task_age(entry)
  if not entry then return "0d" end
  local year, month, day = entry:match "(%d%d%d%d)(%d%d)(%d%d)"
  if not year then return "0d" end
  
  local task_time = os.time { year = year, month = month, day = day, hour = 0, min = 0, sec = 0 }
  local diff = os.difftime(os.time(), task_time)
  local days = math.floor(diff / 86400)
  if days < 365 then
    return string.format("%dd", days)
  else
    return string.format("%dy", math.floor(days / 365))
  end
end

---Format tasks as a table view
---@param open_tasks Task[]
---@param filter_tags string[]|nil
---@param exclude_tags string[]|nil
---@return string[] lines
---@return table<number, Task> task_line_map Maps line number to task
local function format_task_table(open_tasks, filter_tags, exclude_tags)
  local lines = {}
  
  -- Column widths for table view
  local id_width = 4
  local urg_width = 6
  local age_width = 6
  local due_width = 12
  local tags_width = 25
  local desc_width = math.floor(vim.o.columns * 0.8) - (id_width + urg_width + age_width + due_width + tags_width + 10)

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

  -- Task rows - track line numbers for highlighting
  local task_line_map = {} -- Maps line number (0-indexed) to task object
  for i, task in ipairs(open_tasks) do
    local age = calculate_task_age(task.entry)
    local urg_str = string.format("%.1f", task.urgency or 0)
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
    -- Map line number to task (header at 0, separator at 1, tasks start at 2)
    task_line_map[#lines - 1] = task
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

  return lines, task_line_map
end

---List only open tasks with sequential display IDs
---@param filter_tags string[]|nil Tags that must all be present
---@param exclude_tags string[]|nil Tags that must not be present
---@param task_id number|nil Specific task ID to show
function M.list_tasks(filter_tags, exclude_tags, task_id)
  local open_tasks = get_filtered_tasks(filter_tags, exclude_tags)

  -- If task_id is provided, filter to show only that task
  if task_id then
    if task_id < 1 or task_id > #open_tasks then
      local lines = { string.format("Task ID %d not found.", task_id) }
      window.create_float_window(lines)
      return
    end
    local lines = format_task_detail_view(open_tasks[task_id], task_id)
    window.create_float_window(lines)
    return
  end

  if vim.tbl_isempty(open_tasks) then
    local lines = { "No open tasks found." }
    window.create_float_window(lines)
    return
  end

  local lines, task_line_map = format_task_table(open_tasks, filter_tags, exclude_tags)
  window.create_float_window(lines, task_line_map)
end

---Add a new task
---@param args string[] Command arguments (description, due:date, +tags)
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

  -- Validate due date if provided
  if due_date and not validation.is_valid_date_format(due_date) then
    print(string.format("Error: Invalid due date format: %s (expected YYYY-MM-DD)", due_date))
    return
  end
  
  -- Validate tags if provided
  if tags then
    for _, tag in ipairs(tags) do
      if not validation.is_valid_tag(tag) then
        print(string.format("Error: Invalid tag: %s", tag))
        return
      end
    end
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
  
  -- Validate the new task before adding
  local is_valid, error_msg = validation.validate_task(new_task)
  if not is_valid then
    print(string.format("Error: Invalid task: %s", error_msg))
    return
  end
  
  table.insert(tasks, new_task)
  storage.write_tasks(tasks)

  local tags_info = tags and string.format(" [tags: %s]", table.concat(tags, ", ")) or ""
  local due_info = due_date and string.format(" [due: %s]", due_date) or ""
  print(string.format("Task added: %s%s%s (UUID: %s)", description, tags_info, due_info, new_task.uuid))
end

---Mark a task as done by display ID
---@param display_id number Display ID of the task to mark as done
function M.mark_task_done_by_id(display_id)
  -- Use the exact same filtering and sorting logic as list_tasks
  -- This ensures IDs are calculated consistently
  local open_tasks = get_filtered_tasks(nil, nil)

  -- Check if display_id is valid
  if not validation.is_valid_task_id(display_id, #open_tasks) then
    print(string.format("Invalid task ID: %d", display_id))
    return
  end

  -- Get the target task and verify it exists
  local target_task = open_tasks[display_id]
  if not target_task or not target_task.uuid then
    print(string.format("Error: Task at ID %d is invalid", display_id))
    return
  end

  -- Safety check: Show which task is being marked as done
  -- This helps catch cases where IDs have shifted
  local target_uuid = target_task.uuid
  local target_description = target_task.description or "Unknown"
  
  -- Read tasks and find by UUID (most reliable identifier)
  local tasks = storage.read_tasks()
  local found = false
  for _, task in ipairs(tasks) do
    if task.uuid == target_uuid then
      if task.status == "completed" then
        print(string.format("Task ID %d is already completed: %s", display_id, target_description))
        return
      end
      task.status = "completed"
      found = true
      break
    end
  end

  if not found then
    print(string.format("Error: Task with UUID %s not found in storage", target_uuid))
    return
  end

  local success = storage.write_tasks(tasks)
  if success then
    print(string.format("Task marked as done (ID %d): %s", display_id, target_description))
  else
    print("Error: Failed to save task changes")
  end
end

---Find tasks to modify with their original indices
---@param tasks Task[]
---@param filter_tags string[]|nil
---@param exclude_tags string[]|nil
---@param task_id number|nil
---@return Task[]|nil tasks_to_modify
---@return number[]|nil original_indices
---@return string|nil error_msg
local function find_tasks_to_modify(tasks, filter_tags, exclude_tags, task_id)
  -- Filter all tasks at once, then track original indices
  -- This is more efficient than filtering each task individually
  local open_tasks = filter.filter_tasks(tasks, filter_tags, exclude_tags, "pending", true)
  
  -- Create a map from task UUID to original index for efficient lookup
  local uuid_to_index = {}
  for idx, task in ipairs(tasks) do
    if task.uuid then
      uuid_to_index[task.uuid] = idx
    end
  end
  
  -- Build arrays with original indices
  local open_tasks_indices = {}
  for _, task in ipairs(open_tasks) do
    table.insert(open_tasks_indices, uuid_to_index[task.uuid])
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
  if task_id then
    if task_id < 1 or task_id > #open_tasks then
      return nil, nil, string.format("Invalid task ID: %d", task_id)
    end
    return { open_tasks[task_id] }, { open_tasks_indices[task_id] }, nil
  end

  return open_tasks, open_tasks_indices, nil
end

---Apply modifications to a single task
---@param task Task Task to modify
---@param modifications TaskModifications Modifications to apply
---@return boolean modified Whether the task was modified
local function apply_task_modification(task, modifications)
  local modified = false

  -- Modify due date
  if modifications.due then
    task.due = modifications.due
    modified = true
  end

  -- Add tags
  if modifications.add_tags then
    if not task.tags then task.tags = {} end
    for _, new_tag in ipairs(modifications.add_tags) do
      -- Check if tag already exists
      local exists = false
      for _, existing_tag in ipairs(task.tags) do
        if existing_tag == new_tag then
          exists = true
          break
        end
      end
      if not exists then
        table.insert(task.tags, new_tag)
        modified = true
      end
    end
  end

  -- Remove tags
  if modifications.remove_tags then
    if task.tags then
      for _, tag_to_remove in ipairs(modifications.remove_tags) do
        for j = #task.tags, 1, -1 do
          if task.tags[j] == tag_to_remove then
            table.remove(task.tags, j)
            modified = true
          end
        end
      end
      -- Clean up empty tags array
      if #task.tags == 0 then task.tags = nil end
    end
  end

  return modified
end

---Modify tasks based on filters
---@param filter_tags string[]|nil Tags that must all be present
---@param exclude_tags string[]|nil Tags that must not be present
---@param task_id number|nil Specific task ID to modify
---@param modifications TaskModifications Modifications to apply
function M.modify_tasks(filter_tags, exclude_tags, task_id, modifications)
  local tasks = storage.read_tasks()
  
  local tasks_to_modify, tasks_to_modify_indices, error_msg = find_tasks_to_modify(tasks, filter_tags, exclude_tags, task_id)
  
  if error_msg then
    print(error_msg)
    return
  end

  if not tasks_to_modify or #tasks_to_modify == 0 then
    print "No tasks matched the filter."
    return
  end

  -- Apply modifications to matched tasks
  local modified_count = 0
  for i, task in ipairs(tasks_to_modify) do
    local original_idx = tasks_to_modify_indices[i]
    if apply_task_modification(tasks[original_idx], modifications) then
      modified_count = modified_count + 1
    end
  end

  storage.write_tasks(tasks)
  print(string.format("Modified %d task(s).", modified_count))
end

return M

