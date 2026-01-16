local M = {}

-- Urgency coefficients.
--
-- NOTE: This plugin intentionally biases urgency to achieve a stable ordering:
-- - Overdue tasks always sort above non-overdue tasks
-- - Among due tasks: earlier due date => higher urgency
-- - Tasks without a due date always sort after tasks with a due date
-- - Tags/age/next only act as tiny tie-breakers (primarily within the same due date)
local URGENCY = {
  -- Tiny tie-breakers
  next_coefficient = 0.01,
  tags_coefficient = 0.005,
  age_coefficient = 0.005,
  age_max = 365, -- days

  -- Due-date ordering driver
  due_coefficient = 12.0,
  due_present_boost = 1.0, -- Ensure any due task stays above non-due tasks
  due_max = 7, -- days overdue when overdue urgency saturates (0 = no cap)
  due_future_max = 365, -- days in the future after which due urgency bottoms out

  -- Kept for potential future use (even if not currently applied)
  project_coefficient = 1.0,
  blocked_coefficient = -5.0,
}

-- Function to calculate urgency for a task
function M.calculate_urgency(task)
  local urgency = 0.0

  -- Tiny tie-breaker: any tags
  if task.tags and #task.tags > 0 then
    urgency = urgency + URGENCY.tags_coefficient

    -- Tiny tie-breaker: next tag
    for _, tag in ipairs(task.tags) do
      if tag == "next" then
        urgency = urgency + URGENCY.next_coefficient
        break
      end
    end
  end

  -- Due date: drives primary ordering
  if task.due then
    local year, month, day = task.due:match "(%d%d%d%d)%-(%d%d)%-(%d%d)"
    if year then
      local due_time =
        os.time { year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 0, min = 0, sec = 0 }
      local now = os.date "*t"
      local today_time = os.time { year = now.year, month = now.month, day = now.day, hour = 0, min = 0, sec = 0 }

      -- Positive = due in the future, negative = overdue
      local days_until_due = math.floor((due_time - today_time) / 86400)
      local days_overdue = -days_until_due

      -- We intentionally use a step between overdue and non-overdue so
      -- overdue tasks always sort above non-overdue tasks, regardless of tags/age.
      local due_factor
      if days_overdue > 0 then
        local denom = (URGENCY.due_max and URGENCY.due_max > 0) and URGENCY.due_max or 1
        local capped = (URGENCY.due_max and URGENCY.due_max > 0) and math.min(days_overdue, URGENCY.due_max)
          or days_overdue
        -- Overdue range: [2.0 .. 3.0] (or higher if due_max == 0)
        due_factor = 2.0 + (capped / denom)
      else
        local future_max = URGENCY.due_future_max or 365
        if future_max <= 0 then future_max = 1 end
        local capped = math.min(math.max(0, days_until_due), future_max)
        -- Non-overdue range: [1.0 (today) .. 0.0 (>= future_max days away)]
        due_factor = (future_max - capped) / future_max
      end

      urgency = urgency + (URGENCY.due_present_boost or 0.0) + URGENCY.due_coefficient * due_factor
    end
  end

  -- Tiny tie-breaker: age (increases over time up to age_max)
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

  return urgency
end

return M

