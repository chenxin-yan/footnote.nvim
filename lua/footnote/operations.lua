local utils = require 'footnote.utils'
local organizer = require 'footnote.organizer'

local M = {}

--- Create a new footnote, if the footnote already exists at the location, jump to the footnote or its reference
function M.new_footnote()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2]

  local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local next_num = utils.get_next_footnote_number(buffer)
  local footnote_ref = string.format('[^%d]', next_num)
  local footnote_content = string.format('[^%d]: ', next_num)

  local word_end = utils.is_on_ref(buffer, row, col)
  if word_end == nil then
    word_end = utils.get_word_end(0, row, col)
  end

  local til_end = string.sub(buffer[row], word_end + 1, -1)
  local word_end_ref = string.match(til_end, '^%[%^%d+]')
  if word_end_ref ~= nil then
    local num = tonumber(string.sub(word_end_ref, 3, -2))
    for i = #buffer, 1, -1 do
      local line = buffer[i]
      if string.match(line, '^%[%^' .. num .. ']:') then
        vim.api.nvim_win_set_cursor(0, { i, #word_end_ref + 2 })
        return
      end
    end
    vim.api.nvim_buf_set_text(0, row - 1, word_end, row - 1, word_end + #word_end_ref, {})
    return
  elseif string.match(buffer[row], '^%[%^%d+]:') then
    local num = string.match(buffer[row], '%d+')
    for i, line in ipairs(buffer) do
      local match = string.find(line, '%[%^' .. num .. ']')
      if match ~= nil then
        vim.api.nvim_win_set_cursor(0, { i, match + 1 })
        return
      end
    end
    vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, -1, {})
    return
  end

  word_end = utils.get_word_end(0, row, col)

  vim.api.nvim_buf_set_text(0, row - 1, word_end, row - 1, word_end, { footnote_ref })

  vim.api.nvim_win_set_cursor(0, { row, word_end + string.len(footnote_ref) - 1 })
  vim.cmd 'normal! m`'

  vim.api.nvim_buf_set_lines(0, -1, -1, false, { '', footnote_content })
  print 'New footnote created'

  local line_count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { line_count, string.len(footnote_content) })
  vim.cmd 'startinsert!'

  if Opts.organize_on_new then
    organizer.organize_footnotes()
  end
end

return M

