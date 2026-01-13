local date_utils = require "mikro_taskwarrior.utils.date"

local M = {}

-- Function to create a centered floating window
-- tasks: optional table mapping line numbers (0-indexed) to task objects for highlighting
function M.create_float_window(lines, tasks)
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

  -- Define highlight groups if they don't exist
  vim.api.nvim_set_hl(0, "TaskwarriorDueToday", { fg = "#ff8800", bold = true }) -- Orange
  vim.api.nvim_set_hl(0, "TaskwarriorOverdue", { fg = "#ff0000", bold = true }) -- Red

  -- Apply color coding based on due dates
  if tasks then
    local ns_id = vim.api.nvim_create_namespace("mikro_taskwarrior")
    for line_num, task in pairs(tasks) do
      if task.due then
        local hl_group = nil
        if date_utils.is_overdue(task.due) then
          hl_group = "TaskwarriorOverdue"
        elseif date_utils.is_due_today(task.due) then
          hl_group = "TaskwarriorDueToday"
        end
        
        if hl_group then
          -- Highlight the entire line
          vim.api.nvim_buf_add_highlight(buf, ns_id, hl_group, line_num, 0, -1)
        end
      end
    end
  end

  return buf, win
end

return M

