local M = {}

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
function M.calculate_urgency(task)
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

return M

