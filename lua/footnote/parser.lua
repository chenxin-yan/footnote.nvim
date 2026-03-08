local M = {}

local function is_blank(line)
  return line:match '^%s*$' ~= nil
end

local function is_indented(line)
  return line:match '^    ' ~= nil or line:match '^	' ~= nil
end

local function parse_definition_id(line)
  local id = line:match '^%[%^(-?%d+)%]:'
  return id and tonumber(id) or nil
end

local function find_definition_end(lines, start_row)
  local end_row = start_row
  local previous_was_indented = false
  local previous_was_blank = false

  for row = start_row + 1, #lines do
    local line = lines[row]
    if line:match '^%[%^%-?%d+%]:' then
      break
    end

    if is_blank(line) then
      end_row = row
      previous_was_blank = true
      previous_was_indented = false
    elseif is_indented(line) then
      end_row = row
      previous_was_blank = false
      previous_was_indented = true
    elseif previous_was_indented and not previous_was_blank then
      -- Lazy continuation of an indented paragraph.
      end_row = row
      previous_was_blank = false
      previous_was_indented = true
    else
      break
    end
  end

  while end_row > start_row and is_blank(lines[end_row]) do
    end_row = end_row - 1
  end

  return end_row
end

--- Parse references and definition blocks in current buffer.
---@param bufnr number
---@param opts? table
---@return table
function M.parse(bufnr, opts)
  opts = opts or {}
  local collect_missing_colon = opts.collect_missing_colon ~= false

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local refs = {}
  local defs = {}
  local missing_colon_locations = {}

  local row = 1
  while row <= #lines do
    local line = lines[row]
    local def_id = parse_definition_id(line)
    if def_id ~= nil then
      local end_row = find_definition_end(lines, row)
      defs[#defs + 1] = {
        id = def_id,
        header_row = row,
        start_row = row,
        end_row = end_row,
      }
      row = end_row + 1
    else
      if collect_missing_colon then
        local footnote_start, footnote_end = string.find(line, '^%[%^%-?%d+%]')
        if footnote_start and footnote_end then
          missing_colon_locations[#missing_colon_locations + 1] = { row, footnote_end }
        end
      end

      local ref_start = 0
      local ref_end = nil
      while true do
        ref_start, ref_end = string.find(line, '%[%^%-?%d+%]', ref_start + 1)
        if ref_start == nil or ref_end == nil then
          break
        end
        refs[#refs + 1] = { row, ref_start, ref_end }
      end

      row = row + 1
    end
  end

  return {
    lines = lines,
    refs = refs,
    defs = defs,
    missing_colon_locations = missing_colon_locations,
  }
end

return M
