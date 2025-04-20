local util = require "obsidian.util"

local M = {}

---@enum obsidian.completion.RefType
M.RefType = {
  Wiki = 1,
  Markdown = 2,
}

---Backtrack through a string to find the first occurrence of '[['.
---
---@param input string
---@return string|?, string|?, obsidian.completion.RefType|?, number|?
local find_search_start = function(input)
  local pattern_pos = 0
  for i = string.len(input), 1, -1 do
    local substr = string.sub(input, i)

    if vim.startswith(substr, "]") or vim.endswith(substr, "]") then
      return nil
    elseif vim.startswith(substr, "[[") then
      pattern_pos = i
      return substr, string.sub(substr, 3), M.RefType.Wiki, pattern_pos
    elseif vim.startswith(substr, "[") and string.sub(input, i - 1, i - 1) ~= "[" then
      pattern_pos = i
      return substr, string.sub(substr, 2), M.RefType.Markdown, pattern_pos
    end
  end
  return nil
end

-- Get the number of visible characters in a string (not bytes)
local function get_char_count(str)
  local _, count = string.gsub(str, "[^\128-\193]", "")
  return count
end

---Check if a completion request can/should be carried out. Returns a boolean
---and, if true, the search string and the column indices of where the completion
---items should be inserted.
---
---@return boolean, string|?, integer|?, integer|?, obsidian.completion.RefType|?
M.can_complete = function(request)
  local before_line = request.context.cursor_before_line
  local after_line = request.context.cursor_after_line
  local cursor_col = request.context.cursor.col

  -- Use our enhanced function to get pattern position
  local input, search, ref_type, pattern_pos = find_search_start(before_line)

  if input == nil or search == nil or ref_type == nil then
    return false
  elseif string.len(search) == 0 or util.is_whitespace(search) then
    return false
  end

  -- We know from the logs that the issue is with the insertion start point
  -- Instead of trying to calculate it, we'll directly use the position from find_search_start

  if ref_type == M.RefType.Wiki then
    local suffix = string.sub(after_line, 1, 2)
    local insert_end_offset = suffix == "]]" and 1 or -1

    -- Calculate string prefix up to the pattern_pos
    local prefix = string.sub(before_line, 1, pattern_pos - 1)

    -- This is the critical fix - we take the original byte position
    -- and subtract the difference between byte count and character count
    local char_count = get_char_count(prefix)
    local byte_count = #prefix
    local byte_char_diff = byte_count - char_count

    -- This adjusts the position for multi-byte characters
    local insert_start = pattern_pos - 1 - byte_char_diff

    return true, search, insert_start, cursor_col + insert_end_offset, ref_type
  elseif ref_type == M.RefType.Markdown then
    local suffix = string.sub(after_line, 1, 1)
    local insert_end_offset = suffix == "]" and 0 or -1

    -- Calculate string prefix up to the pattern_pos
    local prefix = string.sub(before_line, 1, pattern_pos - 1)

    -- This is the critical fix - we take the original byte position
    -- and subtract the difference between byte count and character count
    local char_count = get_char_count(prefix)
    local byte_count = #prefix
    local byte_char_diff = byte_count - char_count

    -- This adjusts the position for multi-byte characters
    local insert_start = pattern_pos - 1 - byte_char_diff

    return true, search, insert_start, cursor_col + insert_end_offset, ref_type
  else
    return false
  end
end

M.get_trigger_characters = function()
  return { "[" }
end

M.get_keyword_pattern = function()
  -- Note that this is a vim pattern, not a Lua pattern. See ':help pattern'.
  -- The enclosing [=[ ... ]=] is just a way to mark the boundary of a
  -- string in Lua.
  return [=[\%(^\|[^\[]\)\zs\[\{1,2}[^\]]\+\]\{,2}]=]
end

return M
