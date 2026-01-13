local M = {}

-- Function to pad string to specific width
function M.pad_string(str, width, align)
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

-- Function to parse tags from command (words starting with +)
function M.parse_tags(args)
  local tags = {}
  for _, arg in ipairs(args) do
    if arg:match "^%+.+" then
      local tag = arg:sub(2) -- Remove the + prefix
      table.insert(tags, tag)
    end
  end
  return #tags > 0 and tags or nil
end

return M

