local M = {}

local function get_next_footnote_number(buffer)
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

-- Function to get the end of the word the cursor is on
local function get_word_end(bufnr, row, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  local word_end = col
  while word_end < #line and line:sub(word_end + 1, word_end + 1):match '%w' do
    word_end = word_end + 1
  end
  return word_end
end

function M.new_footnote()
  -- FIXME: organize_on_save not work as expected when the footnote being created need to be formatted
  if Opts.organize_on_new then
    M.organize_footnotes()
  end

  -- TODO: implement when word undercursor already has footnote, goto that footnote
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2]

  local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local next_num = get_next_footnote_number(buffer)
  local footnote_ref = string.format('[^%d]', next_num)
  local footnote_content = string.format('[^%d]: ', next_num)

  -- Get the end of the word the cursor is on
  local word_end = get_word_end(0, row, col)

  -- Insert footnote label at the end of the word
  vim.api.nvim_buf_set_text(0, row - 1, word_end, row - 1, word_end, { footnote_ref })

  -- Add footnote label to jumplist
  vim.api.nvim_win_set_cursor(0, { row, word_end + string.len(footnote_ref) - 1 })
  vim.cmd 'normal! m`'

  -- Insert footnote reference at the end of the buffer
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { '', footnote_content })

  -- Move cursor to the footnote reference
  local line_count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { line_count, string.len(footnote_content) })
  vim.cmd 'startinsert!'
end

local function ref_rename(bufrn, ref_locations, from, to)
  if from == to then
    return
  end
  local buffer = vim.api.nvim_buf_get_lines(bufrn, 0, -1, false)
  for index = 1, #ref_locations, 1 do
    local location = ref_locations[index]
    if location == nil then
      goto continue
    end
    local label = string.sub(buffer[location[1]], location[2], location[3])
    local number = tonumber(string.sub(label, 3, -2))
    local row = location[1]
    local startCol = location[2]
    local endCol = location[3]

    -- swap footnote labels
    if number == from then
      if Opts.debug_print then
        print('ref_rename: ' .. from .. ' -> ' .. to)
      end
      vim.api.nvim_buf_set_text(bufrn, row - 1, startCol + 1, row - 1, endCol - 1, { tostring(to) })
    elseif number == to then
      if Opts.debug_print then
        print('ref_rename: ' .. to .. ' -> ' .. from)
      end
      vim.api.nvim_buf_set_text(bufrn, row - 1, startCol + 1, row - 1, endCol - 1, { tostring(from) })
    end
    ::continue::
  end
end

local function content_rename(bufrn, content_locations, from, to)
  if from == to then
    return
  end
  local buffer = vim.api.nvim_buf_get_lines(bufrn, 0, -1, false)
  for _, row in ipairs(content_locations) do
    local num = string.match(buffer[row], '%d+')
    if tonumber(num) == from then
      local i, j = string.find(buffer[row], '%d+')
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.api.nvim_buf_set_text(bufrn, row - 1, i - 1, row - 1, j, { tostring(to) })
    elseif tonumber(num) == to then
      local i, j = string.find(buffer[row], '%d+')
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.api.nvim_buf_set_text(bufrn, row - 1, i - 1, row - 1, j, { tostring(from) })
    end
  end
end

local function cleanup_orphan(bufrn, ref_locations, content_locations, from)
  -- FIXME: when repeat refrences before the orphan, the indexes of the line with orphan references in ref_locations would not shift correctly
  local buffer = vim.api.nvim_buf_get_lines(bufrn, 0, -1, false)
  local isOrphan = true
  for _, row in ipairs(content_locations) do
    local num = tonumber(string.match(buffer[row], '%d+'))
    if num == from then
      isOrphan = false
      break
    end
  end

  if isOrphan then
    for index = 1, #ref_locations, 1 do
      local location = ref_locations[index]
      if location == nil then
        goto continue
      end
      local label = string.sub(buffer[location[1]], location[2], location[3])
      local number = tonumber(string.sub(label, 3, -2))
      local row = location[1]
      local startCol = location[2]
      local endCol = location[3]

      if number == from then
        vim.api.nvim_buf_set_text(bufrn, row - 1, startCol - 1, row - 1, endCol, {})
        buffer = vim.api.nvim_buf_get_lines(bufrn, 0, -1, false)
        ref_locations[index] = nil
        if Opts.debug_print then
          print('cleanup_orphan: ' .. from .. ' at row ' .. row)
        end
        for j = index, #ref_locations, 1 do
          local next_location = ref_locations[j + 1]
          if next_location == nil or next_location[1] ~= row then
            break
          end
          local shift = endCol - startCol + 1
          ref_locations[j + 1][2] = ref_locations[j + 1][2] - shift
          ref_locations[j + 1][3] = ref_locations[j + 1][3] - shift
          if Opts.debug_print then
            print('shifted: ' .. ref_locations[j + 1][1] .. ', ' .. ref_locations[j + 1][2] .. ':' .. ref_locations[j + 1][3])
          end
        end
      end
      ::continue::
    end

    return true
  else
    return false
  end
end

function M.organize_footnotes()
  local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- find all footnote references with their locations
  local ref_locations = {}
  local content_locations = {}
  for i, line in ipairs(buffer) do
    if string.find(line, '^%[%^%d+%]:') then
      content_locations[#content_locations + 1] = i
      goto continue
    end
    local refStart = 0
    local refEnd = nil
    while true do
      ---@diagnostic disable-next-line: cast-local-type
      refStart, refEnd = string.find(line, '%[%^%d+%]', refStart + 1)
      if refStart == nil or refEnd == nil then
        break
      end
      ref_locations[#ref_locations + 1] = { i, refStart, refEnd }
    end
    ::continue::
  end

  -- iterate footnote and sort labels
  local counter = 1
  for index = 1, #ref_locations, 1 do
    local location = ref_locations[index]
    if location == nil then
      goto continue
    end
    buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local label = string.sub(buffer[location[1]], location[2], location[3])
    local number = tonumber(string.sub(label, 3, -2))

    print(label)

    -- Process foonotes
    if number >= counter then
      if not cleanup_orphan(0, ref_locations, content_locations, number) then
        if Opts.debug_print then
          print(number .. ' -> ' .. counter)
        end
        ref_rename(0, ref_locations, number, counter)
        content_rename(0, content_locations, number, counter)
        counter = counter + 1
      end
    end
    ::continue::
  end

  -- sort footnote content
  for i = 1, #content_locations, 1 do
    buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local target = content_locations[i]
    for j = i, #content_locations, 1 do
      local current = content_locations[j]
      local num = string.match(buffer[current], '%d+')
      if tonumber(num) == i and j ~= i then
        local temp = buffer[target]
        vim.api.nvim_buf_set_text(0, target - 1, 0, target - 1, -1, { buffer[current] })
        vim.api.nvim_buf_set_text(0, current - 1, 0, current - 1, -1, { temp })
        break
      end
    end
  end

  print 'Organize footnote'
end

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

function M.next_footnote()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2]

  -- get the index of the start of next footnote ref
  local refLocation = find_next(0, row, col)
  if refLocation == nil then
    return
  end

  -- move cursor to the next footnote ref
  vim.api.nvim_win_set_cursor(0, { refLocation[1], refLocation[2] })
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

function M.prev_footnote()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2]

  -- get the index of the start of previous footnote ref
  local refLocation = find_prev(0, row, col)
  if refLocation == nil then
    return
  end

  -- move cursor to the next footnote ref
  vim.api.nvim_win_set_cursor(0, { refLocation[1], refLocation[2] })
end

function M.setup(opts)
  opts = opts or {}
  local default = {
    debug_print = false,
    keys = {
      new_footnote = '<C-f>',
      organize_footnotes = '<leader>of',
      next_footnote = ']f',
      prev_footnote = '[f',
    },
    organize_on_save = true,
    organize_on_new = false,
  }

  Opts = vim.tbl_deep_extend('force', default, opts)
  -- print(vim.inspect(opts))

  vim.api.nvim_create_autocmd('FileType', {
    desc = 'footnote.nvim keymaps',
    pattern = { 'markdown' },
    callback = function()
      if Opts.keys.new_footnote ~= '' then
        vim.keymap.set(
          { 'i', 'n' },
          Opts.keys.new_footnote,
          "<cmd>lua require('footnote').new_footnote()<cr>",
          { buffer = 0, desc = 'Create markdown footnote' }
        )
      end
      if Opts.keys.organize_footnotes ~= '' then
        vim.keymap.set('n', Opts.keys.organize_footnotes, "<cmd>lua require('footnote').organize_footnotes()<cr>", { buffer = 0, desc = 'Organize footnote' })
      end
      if Opts.keys.next_footnote ~= '' then
        vim.keymap.set('n', Opts.keys.next_footnote, "<cmd>lua require('footnote').next_footnote()<cr>", { buffer = 0, silent = true, desc = 'Next footnote' })
      end
      if Opts.keys.prev_footnote ~= '' then
        vim.keymap.set('n', Opts.keys.prev_footnote, "<cmd>lua require('footnote').prev_footnote()<cr>", { buffer = 0, desc = 'Previous footnote' })
      end
    end,
  })

  if Opts.organize_on_save then
    vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
      group = vim.api.nvim_create_augroup('organize footnotes', { clear = true }),
      pattern = { '*.md' },
      callback = function()
        require('footnote').organize_footnotes()
      end,
    })
  end
end

return M
