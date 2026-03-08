local utils = require 'footnote.utils'
local organizer = require 'footnote.organizer'
local config = require 'footnote.config'

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

  -- check if need to jump to footnote instead of creating one
  local word_end = utils.is_on_ref(buffer, row, col)
  if word_end == nil then
    word_end = utils.get_word_end(0, row, col)
  end

  -- if the footnote already exists and the cursor is on the reference, jump to that footnote
  local til_end = string.sub(buffer[row], word_end + 1, -1)
  local word_end_ref = string.match(til_end, '^%[%^%-?%d+%]')
  if word_end_ref ~= nil then
    local num = tonumber(string.sub(word_end_ref, 3, -2))
    for i = #buffer, 1, -1 do
      local line = buffer[i]
      if string.match(line, '^%[%^' .. num .. ']:') then
        vim.api.nvim_win_set_cursor(0, { i, #word_end_ref + 2 })
        return
      end
    end
    -- if the reference is an orphan, create a footnote definition for it
    local footnote_def = string.format('[^%d]: ', num)
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { '', footnote_def })
    local line_count = vim.api.nvim_buf_line_count(0)
    vim.api.nvim_win_set_cursor(0, { line_count, string.len(footnote_def) })
    vim.cmd 'startinsert!'
    return
  elseif string.match(buffer[row], '^%[%^%d+]:') then
    local num = string.match(buffer[row], '%d+')
    -- TODO: add multi references support. Let user select which footnote they want to go to
    for i, line in ipairs(buffer) do
      local match = string.find(line, '%[%^' .. num .. ']')
      if match ~= nil then
        vim.api.nvim_win_set_cursor(0, { i, match + 1 })
        return
      end
    end
    -- if the footnote is an orphan, delete it
    vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, -1, {})
    return
  end

  -- Get the end of the word the cursor is on
  word_end = utils.get_word_end(0, row, col)

  -- Insert footnote label at the end of the word
  vim.api.nvim_buf_set_text(0, row - 1, word_end, row - 1, word_end, { footnote_ref })

  -- Add footnote label to jumplist
  vim.api.nvim_win_set_cursor(0, { row, word_end + string.len(footnote_ref) - 1 })
  vim.cmd 'normal! m`'

  -- Insert footnote reference at the end of the buffer
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { '', footnote_content })
  print 'New footnote created'

  -- Move cursor to the footnote reference
  local line_count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { line_count, string.len(footnote_content) })
  vim.cmd 'startinsert!'

  if config.get_opts().organize_on_new then
    organizer.organize_footnotes()
  end
end

--- Link all occurrences of the word under cursor (or visual selection) to the same footnote.
--- If one occurrence already has a footnote, all others will be linked to that same reference.
--- If none have a footnote, a new one is created and all occurrences are linked.
function M.link_footnote()
  local mode = vim.fn.mode()
  local word

  if mode == 'v' or mode == 'V' or mode == '\22' then
    -- visual mode: exit visual mode first to set '< and '> marks
    vim.cmd [[normal! \<esc>]]
    word = utils.get_visual_selection()
  else
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row = cursor_pos[1]
    local col = cursor_pos[2]
    word = utils.get_word_at_cursor(0, row, col)
  end

  if not word or #word == 0 then
    vim.notify('[footnote.nvim] No word under cursor', vim.log.levels.WARN)
    return
  end

  local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local case_sensitive = config.get_opts().case_sensitive_link
  if case_sensitive == nil then
    case_sensitive = true
  end

  local existing_id = utils.find_footnoted_occurrence(buffer, word, case_sensitive)
  local occurrences = utils.find_word_occurrences(buffer, word, case_sensitive)

  if #occurrences == 0 then
    vim.notify('[footnote.nvim] No occurrences found for "' .. word .. '"', vim.log.levels.WARN)
    return
  end

  -- filter out occurrences that already have a footnote ref immediately after them
  local to_link = {}
  for _, occ in ipairs(occurrences) do
    local row, _, end_col = occ[1], occ[2], occ[3]
    local line = buffer[row]
    local after = line:sub(end_col + 1)
    if not after:match '^%[%^%d+%]' then
      to_link[#to_link + 1] = occ
    end
  end

  if #to_link == 0 then
    vim.notify('[footnote.nvim] All occurrences already have footnote references', vim.log.levels.INFO)
    return
  end

  local footnote_id
  local is_new = false

  if existing_id then
    footnote_id = existing_id
  else
    footnote_id = utils.get_next_footnote_number(buffer)
    is_new = true
  end

  local ref = string.format('[^%d]', footnote_id)

  -- insert references in reverse order to preserve positions
  -- sort by row desc, then col desc
  table.sort(to_link, function(a, b)
    if a[1] ~= b[1] then
      return a[1] > b[1]
    end
    return a[3] > b[3]
  end)

  for _, occ in ipairs(to_link) do
    local row = occ[1]
    local end_col = occ[3]
    vim.api.nvim_buf_set_text(0, row - 1, end_col, row - 1, end_col, { ref })
  end

  if is_new then
    -- append definition at end of buffer
    local footnote_def = string.format('[^%d]: ', footnote_id)
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { '', footnote_def })

    -- move cursor to definition and enter insert mode
    local line_count = vim.api.nvim_buf_line_count(0)
    vim.api.nvim_win_set_cursor(0, { line_count, #footnote_def })
    vim.cmd 'startinsert!'

    if config.get_opts().organize_on_new then
      organizer.organize_footnotes()
    end

    vim.notify(string.format('[footnote.nvim] Linked %d occurrence(s) to new footnote [^%d]', #to_link, footnote_id), vim.log.levels.INFO)
  else
    vim.notify(
      string.format('[footnote.nvim] Linked %d occurrence(s) to existing footnote [^%d]', #to_link, footnote_id),
      vim.log.levels.INFO
    )
  end
end

return M
