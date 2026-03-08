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

--- get the word under the cursor along with its column boundaries
---@param bufnr number buffer number ("0" for current buffer)
---@param row number row of the cursor (1-indexed)
---@param col number col of the cursor (0-indexed)
---@return string|nil word the word text, or nil if cursor is not on a word
---@return number start_col 0-indexed start column of the word
---@return number end_col 0-indexed end column (exclusive) of the word
function M.get_word_at_cursor(bufnr, row, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if not line or #line == 0 then
    return nil, 0, 0
  end

  -- check if cursor is on a word character
  local char = line:sub(col + 1, col + 1)
  if not char:match '%w' then
    return nil, 0, 0
  end

  -- find word start
  local start_col = col
  while start_col > 0 and line:sub(start_col, start_col):match '%w' do
    start_col = start_col - 1
  end
  if not line:sub(start_col + 1, start_col + 1):match '%w' then
    start_col = start_col + 1
  end

  -- find word end
  local end_col = col + 1
  while end_col < #line and line:sub(end_col + 1, end_col + 1):match '%w' do
    end_col = end_col + 1
  end

  local word = line:sub(start_col + 1, end_col)
  return word, start_col, end_col
end

--- get the visually selected text
---@return string|nil text the selected text, or nil if no selection
function M.get_visual_selection()
  local start_pos = vim.fn.getpos "'<"
  local end_pos = vim.fn.getpos "'>"
  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  if start_row ~= end_row then
    -- only support single-line selection
    return nil
  end

  local line = vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, false)[1]
  if not line then
    return nil
  end

  return line:sub(start_col, end_col)
end

--- find all occurrences of a word in the buffer, skipping definition lines
---@param buffer table the buffer lines
---@param word string the word to search for
---@param case_sensitive boolean whether to match case-sensitively
---@return table occurrences list of {row, start_col, end_col} (1-indexed row, 0-indexed cols, end exclusive)
function M.find_word_occurrences(buffer, word, case_sensitive)
  local occurrences = {}
  local search_word = case_sensitive and word or word:lower()

  for row, line in ipairs(buffer) do
    -- skip footnote definition lines
    if line:match '^%[%^%-?%d+%]:' then
      goto continue
    end

    local search_line = case_sensitive and line or line:lower()
    local pos = 1
    while pos <= #search_line do
      local start_idx, end_idx = search_line:find(search_word, pos, true)
      if not start_idx then
        break
      end

      -- word boundary check: char before must not be %w
      local before_ok = start_idx == 1 or not search_line:sub(start_idx - 1, start_idx - 1):match '%w'
      -- char after must not be %w
      local after_ok = end_idx == #search_line or not search_line:sub(end_idx + 1, end_idx + 1):match '%w'

      if before_ok and after_ok then
        -- start_col is 0-indexed, end_col is 0-indexed exclusive
        occurrences[#occurrences + 1] = { row, start_idx - 1, end_idx }
      end

      pos = end_idx + 1
    end

    ::continue::
  end

  return occurrences
end

--- among all occurrences of a word, find one that is immediately followed by a footnote ref [^N]
---@param buffer table the buffer lines
---@param word string the word to search for
---@param case_sensitive boolean whether to match case-sensitively
---@return number|nil footnote_id the footnote ID if found, or nil
function M.find_footnoted_occurrence(buffer, word, case_sensitive)
  local occurrences = M.find_word_occurrences(buffer, word, case_sensitive)

  for _, occ in ipairs(occurrences) do
    local row, _, end_col = occ[1], occ[2], occ[3]
    local line = buffer[row]
    local after = line:sub(end_col + 1)
    local id = after:match '^%[%^(%d+)%]'
    if id then
      return tonumber(id)
    end
  end

  return nil
end

return M
