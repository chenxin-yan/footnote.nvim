local M = {}

--- get the next foootnote number that need to added based on existing footnotes
---@param buffer table contains the entire buffer
---@return number next_footnote next footnote number
function M.get_next_footnote_number(buffer)
  local max_num = 0
  for _, line in ipairs(buffer) do
    for match in string.gmatch(line, '%[%^%d+]') do
      local num = tonumber(string.match(match, '%d+'))
      if num > max_num then
        ---@diagnostic disable-next-line: cast-local-type
        max_num = num
      end
    end
  end
  return max_num + 1
end

--- get the index of end of the word the cursor is on
---@param bufnr number buffer number ("0" for current buffer)
---@param row number row of the cursor
---@param col number col of the cursor
---@return number col the col of the end of the word
function M.get_word_end(bufnr, row, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  local word_end = col
  while word_end < #line and line:sub(word_end + 1, word_end + 1):match '%w' do
    word_end = word_end + 1
  end
  return word_end
end

--- check if a given location in on a footnote reference
---@param buffer table the buffer to check for
---@param row number the row of the given location
---@param col number the col of the given location
---@return number | nil col the start col of the footnote. If not on a footnote, return nil
function M.is_on_ref(buffer, row, col)
  local line = buffer[row]
  local refColStart = 0
  local refColEnd = 0
  while true do
    ---@diagnostic disable-next-line: cast-local-type
    refColStart, refColEnd = string.find(line, '%[%^%d+]', refColStart + 1)
    if refColStart == nil then
      break
    elseif refColStart <= col and col < refColEnd then
      return refColStart - 1
    end
  end
  return nil
end

return M

