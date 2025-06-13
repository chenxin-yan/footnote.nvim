local M = {}

--- Get the location of next footnote ref
---@param bufnr number the buffer numer (0 for current buffer)
---@param row number the row of current cursor
---@param col number the col of current cursor
---@return table | nil refLocation  location of the next footnote in a table {row, col}. If not found, return 'nil'
local function find_next(bufnr, row, col)
  local buffer = vim.api.nvim_buf_get_lines(bufnr, row - 1, -1, false)
  buffer[1] = string.sub(buffer[1], col + 1, -1)
  for i, line in ipairs(buffer) do
    if string.find(line, '^%[%^%d+%]:') then
      return nil
    end
    while true do
      local refCol = string.find(line, '%[%^%d+]')
      if refCol == nil then
        break
      end
      if i == 1 then
        refCol = refCol + col
      end
      return { row - 1 + i, refCol + 1 }
    end
  end
  return nil
end

--- Get the location of previous footnote ref
---@param bufnr number the buffer numer (0 for current buffer)
---@param row number the row of current cursor
---@param col number the col of current cursor
---@return table | nil refLocation  location of the previous footnote in a table {row, col}. If not found, return 'nil'
local function find_prev(bufnr, row, col)
  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, row, false)
  buffer[#buffer] = string.sub(buffer[#buffer], 0, col)
  for i = #buffer, 1, -1 do
    local line = buffer[i]
    if string.find(line, '^%[%^%d+%]:') then
      goto continue
    end
    local refCol = 0
    local last = nil
    while true do
      ---@diagnostic disable-next-line: cast-local-type
      refCol = string.find(line, '%[%^%d+]', refCol + 1)
      if refCol == nil then
        break
      end
      last = refCol
    end
    if last ~= nil then
      return { i, last + 1 }
    end
    ::continue::
  end
  return nil
end

--- Go to next footnote reference
function M.next_footnote()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2]

  local refLocation = find_next(0, row, col)
  if refLocation == nil then
    return
  end

  vim.api.nvim_win_set_cursor(0, { refLocation[1], refLocation[2] })
end

--- Go to previous footnote reference
function M.prev_footnote()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2]

  local refLocation = find_prev(0, row, col)
  if refLocation == nil then
    return
  end

  vim.api.nvim_win_set_cursor(0, { refLocation[1], refLocation[2] })
end

return M
