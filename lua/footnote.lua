local M = {}

local function get_next_footnote_number(buffer)
  local max_num = 0
  for _, line in ipairs(buffer) do
    for match in string.gmatch(line, '%[%^%d]') do
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
  -- TODO: implement when word undercursor already has footnote, goto that footnote

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2]

  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local next_num = get_next_footnote_number(buffer)
  local footnote_ref = string.format('[^%d]', next_num)
  local footnote_content = string.format('[^%d]: ', next_num)

  -- Get the end of the word the cursor is on
  local word_end = get_word_end(bufnr, row, col)

  -- Insert footnote label at the end of the word
  vim.api.nvim_buf_set_text(bufnr, row - 1, word_end, row - 1, word_end, { footnote_ref })

  -- Add footnote label to jumplist
  vim.api.nvim_win_set_cursor(0, { row, word_end + string.len(footnote_ref) - 1 })
  vim.cmd 'normal! m`'

  -- Insert footnote reference at the end of the buffer
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { '', footnote_content })

  -- Move cursor to the footnote reference
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(0, { line_count, string.len(footnote_content) })
  vim.cmd 'startinsert!'
end

function M.organize_footnotes()
  -- TODO: implement organize footnotes
end

function M.next_footnote()
  -- TODO: implement footnote navigation
end

function M.prev_footnote()
  -- TODO: implement footnote navigation
end

function M.setup(opts)
  opts = opts or {}
  local default = {
    keys = {
      new_footnote = '<C-f>',
      organize_footnotes = '<leader>of',
      next_footnote = ']f',
      prev_footnote = '[f',
    },
    organize_on_save = true,
  }

  opts = vim.tbl_deep_extend('force', default, opts)

  vim.api.nvim_create_autocmd('FileType', {
    desc = 'footnote.nvim keymaps',
    pattern = { 'markdown' },
    callback = function()
      if opts.keys.new_footnote ~= '' then
        vim.keymap.set(
          { 'i', 'n' },
          opts.keys.new_footnote,
          "<cmd>lua require('footnote').new_footnote()<cr>",
          { buffer = 0, silent = true, desc = 'Create markdown footnote' }
        )
      end
      if opts.keys.organize_footnotes ~= '' then
        vim.keymap.set(
          { 'n' },
          opts.keys.organize_footnotes,
          "<cmd>lua require('footnote').organize_footnotes()<cr>",
          { buffer = 0, silent = true, desc = 'Organize footnote' }
        )
      end
      if opts.keys.next_footnote ~= '' then
        vim.keymap.set(
          { 'n' },
          opts.keys.next_footnote,
          "<cmd>lua require('footnote').next_footnote()<cr>",
          { buffer = 0, silent = true, desc = 'Next footnote' }
        )
      end
      if opts.keys.prev_footnote ~= '' then
        vim.keymap.set(
          { 'n' },
          opts.keys.prev_footnote,
          "<cmd>lua require('footnote').prev_footnote()<cr>",
          { buffer = 0, silent = true, desc = 'Previous footnote' }
        )
      end
    end,
  })

  if opts.organize_on_save then
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
