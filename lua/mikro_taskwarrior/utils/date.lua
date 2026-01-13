local M = {}

-- Function to get current timestamp in ISO 8601 format
function M.get_current_timestamp() return os.date "%Y%m%dT%H%M%SZ" end

-- Function to parse due date from command
function M.parse_due_date(args)
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

-- Function to check if a task is due today
function M.is_due_today(due_date)
  if not due_date then return false end
  local today = os.date "%Y-%m-%d"
  return due_date == today
end

-- Function to check if a task is overdue
function M.is_overdue(due_date)
  if not due_date then return false end
  local year, month, day = due_date:match "(%d%d%d%d)%-(%d%d)%-(%d%d)"
  if not year then return false end
  
  local due_time = os.time { year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 23, min = 59, sec = 59 }
  local now = os.time()
  return now > due_time
end

return M

