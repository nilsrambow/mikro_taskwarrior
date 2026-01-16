local urgency = require "mikro_taskwarrior.core.urgency"

describe("Urgency ordering (due-first)", function()
  local real_time
  local real_date

  before_each(function()
    real_time = os.time
    real_date = os.date

    -- Freeze "now" so urgency tests are deterministic.
    os.time = function(tbl)
      if tbl == nil then
        return real_time { year = 2026, month = 1, day = 16, hour = 12, min = 0, sec = 0 }
      end
      return real_time(tbl)
    end

    os.date = function(fmt, time)
      if fmt == "*t" and time == nil then
        return { year = 2026, month = 1, day = 16, hour = 12, min = 0, sec = 0, isdst = false }
      end
      return real_date(fmt, time)
    end
  end)

  after_each(function()
    os.time = real_time
    os.date = real_date
  end)

  local function calc(task)
    return urgency.calculate_urgency(task)
  end

  it("should rank overdue > due_today > due_tomorrow > due_future > no_due", function()
    local overdue = { uuid = "o", entry = "20260101T000000Z", due = "2026-01-15" }
    local today = { uuid = "t0", entry = "20260101T000000Z", due = "2026-01-16" }
    local tomorrow = { uuid = "t1", entry = "20260101T000000Z", due = "2026-01-17" }
    local future = { uuid = "tf", entry = "20260101T000000Z", due = "2026-12-31" }
    local no_due = { uuid = "n", entry = "20260101T000000Z" }

    local u_overdue = calc(overdue)
    local u_today = calc(today)
    local u_tomorrow = calc(tomorrow)
    local u_future = calc(future)
    local u_no_due = calc(no_due)

    assert.is_true(u_overdue > u_today)
    assert.is_true(u_today > u_tomorrow)
    assert.is_true(u_tomorrow > u_future)
    assert.is_true(u_future > u_no_due)
  end)

  it("should not let tie-breakers outrank an earlier due date", function()
    local due_today = { uuid = "d0", entry = "20260101T000000Z", due = "2026-01-16" }
    local due_tomorrow_next = { uuid = "d1", entry = "20260101T000000Z", due = "2026-01-17", tags = { "next" } }

    assert.is_true(calc(due_today) > calc(due_tomorrow_next))
  end)

  it("should allow tie-breakers within the same due date (next tag)", function()
    local base = { uuid = "b", entry = "20260101T000000Z", due = "2026-01-16" }
    local with_next = { uuid = "bn", entry = "20260101T000000Z", due = "2026-01-16", tags = { "next" } }

    assert.is_true(calc(with_next) > calc(base))
  end)

  it("should keep any due task above no-due tasks", function()
    local due_far = { uuid = "df", entry = "20260101T000000Z", due = "2028-12-31" }
    local no_due_next = { uuid = "nn", entry = "20260101T000000Z", tags = { "next" } }

    assert.is_true(calc(due_far) > calc(no_due_next))
  end)
end)

