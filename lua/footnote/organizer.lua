local M = {}

--- Mark a footnote reference as orphan
---@param bufnr number buffer number
---@param ref_locations table locations of all the footnote references
---@param orphan_locations table locations of all the orphan references
---@param from number the label to mark as orphan
local function mark_as_orphan(bufnr, ref_locations, orphan_locations, from)
  -- If number is already negative, keep it negative; otherwise make it negative
  local orphan_number = from < 0 and from or -from

  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local matching_locations = {}

  -- First pass: collect all matching locations
  for index = 1, #ref_locations, 1 do
    local location = ref_locations[index]
    if location == nil then
      goto continue
    end
    local label = string.sub(buffer[location[1]], location[2], location[3])
    local number = tonumber(string.sub(label, 3, -2))

    if number == from then
      matching_locations[#matching_locations + 1] = { index, location }
    end

    ::continue::
  end

  -- Second pass: process all matching locations (reverse order to avoid position corruption)
  for i = #matching_locations, 1, -1 do
    local index, location = matching_locations[i][1], matching_locations[i][2]
    local row = location[1]
    local startCol = location[2]
    local endCol = location[3]

    -- Rename to negative number
    vim.api.nvim_buf_set_text(bufnr, row - 1, startCol + 1, row - 1, endCol - 1, { tostring(orphan_number) })

    -- HACK: endcol + diff because if "from" is orphan
    -- the number will have a "-" prepend to the number after rename
    local diff = #tostring(orphan_number) - #tostring(from)
    orphan_locations[#orphan_locations + 1] = { row, startCol, endCol + diff }

    -- Update ref_locations for this change
    local shift = #tostring(orphan_number) - #tostring(from)
    if shift ~= 0 then
      ref_locations[index][3] = ref_locations[index][3] + shift
      -- Update positions of references that come after this one on the same row
      for j = 1, #ref_locations do
        local next_location = ref_locations[j]
        if next_location ~= nil and next_location[1] == row and next_location[2] > startCol then
          ref_locations[j][2] = ref_locations[j][2] + shift
          ref_locations[j][3] = ref_locations[j][3] + shift
        end
      end
    end

    -- Refresh buffer for next iteration
    buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
end

--- rename all footnote references with given label to another label
---@param bufnr number buffer number
---@param ref_locations table locations of all the footnote references
---@param from number the label to change
---@param to number the label to change to
local function ref_rename(bufnr, ref_locations, from, to)
  if from == to then
    return
  end
  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

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

    local shift = 0

    -- swap footnote labels
    if number == from then
      if Opts.debug_print then
        print('ref_rename: ' .. from .. ' -> ' .. to)
      end
      shift = #tostring(to) - #tostring(from)
      vim.api.nvim_buf_set_text(bufnr, row - 1, startCol + 1, row - 1, endCol - 1, { tostring(to) })
    elseif number == to then
      if Opts.debug_print then
        print('ref_rename: ' .. to .. ' -> ' .. from)
      end
      vim.api.nvim_buf_set_text(bufnr, row - 1, startCol + 1, row - 1, endCol - 1, { tostring(from) })
      shift = #tostring(from) - #tostring(to)
    end
    if shift ~= 0 then
      ref_locations[index][3] = ref_locations[index][3] + shift
      for j = index, #ref_locations, 1 do
        local next_location = ref_locations[j + 1]
        if next_location == nil or next_location[1] ~= row then
          break
        end
        ref_locations[j + 1][2] = ref_locations[j + 1][2] + shift
        ref_locations[j + 1][3] = ref_locations[j + 1][3] + shift
        if Opts.debug_print then
          print('shifted(' .. shift .. '): ' .. ref_locations[j + 1][1] .. ', ' .. ref_locations[j + 1][2] .. ':' .. ref_locations[j + 1][3])
        end
      end
    end

    ::continue::
  end
end

--- rename the footnote content list
---@param bufnr number buffer number
---@param content_locations table locations of all footnote content
---@param from number the label to change
---@param to number the label to change to
local function content_rename(bufnr, content_locations, from, to)
  if from == to then
    return
  end
  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, row in ipairs(content_locations) do
    local num = string.match(buffer[row], '%-?%d+')
    if tonumber(num) == from then
      local i, j = string.find(buffer[row], '%-?%d+')
      if i and j then
        vim.api.nvim_buf_set_text(bufnr, row - 1, i - 1, row - 1, j, { tostring(to) })
      end
    elseif tonumber(num) == to then
      local i, j = string.find(buffer[row], '%-?%d+')
      if i and j then
        vim.api.nvim_buf_set_text(bufnr, row - 1, i - 1, row - 1, j, { tostring(from) })
      end
    end
  end
end

-- check to see if a given footnote is an orphan
---@param bufnr number buffer number
---@param content_locations table locations of all the footnote content
---@param from number the refernce label to be checked
local function is_orphan(bufnr, content_locations, from)
  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local isOrphan = true
  for _, row in ipairs(content_locations) do
    local num = tonumber(string.match(buffer[row], '%-?%d+'))
    if num == from then
      isOrphan = false
      break
    end
  end

  if isOrphan then
    return true
  end

  return false
end

--- Clean up orphan footnote references in a given buffer
---@param bufnr number buffer number
---@param orphan_locations table locations of all the orphans tha needed to be cleaned up
local function cleanup_orphan(bufnr, orphan_locations)
  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  -- Process orphans in reverse order to avoid position corruption
  for index = #orphan_locations, 1, -1 do
    local location = orphan_locations[index]
    if location == nil then
      goto continue
    end
    local label = string.sub(buffer[location[1]], location[2], location[3])
    local row = location[1]
    local startCol = location[2]
    local endCol = location[3]

    vim.api.nvim_buf_set_text(bufnr, row - 1, startCol - 1, row - 1, endCol, {})
    buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    vim.notify('label "' .. label .. '" at row ' .. row .. ' is deleted', vim.log.levels.INFO)
    ::continue::
  end
end

--- Organize foonote references and content and sort based on occurence
---@param skip_colon_check? boolean skip checking for missing colons
function M.organize_footnotes(skip_colon_check)
  local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- find all footnote references with their locations
  local ref_locations = {}
  local content_locations = {}
  local orphan_locations = {}
  local missing_colon_locations = {}

  for i, line in ipairs(buffer) do
    if string.find(line, '^%[%^%-?%d+%]:') then
      content_locations[#content_locations + 1] = i
      goto continue
    end

    -- NOTE: see issue #2
    -- Check if line starts with [^d] without colon
    if not skip_colon_check then
      local footnote_start, footnote_end = string.find(line, '^%[%^%-?%d+%]')
      if footnote_start and footnote_end then
        missing_colon_locations[#missing_colon_locations + 1] = { i, footnote_end }
        goto continue
      end
    end

    local refStart = 0
    local refEnd = nil
    while true do
      ---@diagnostic disable-next-line: cast-local-type
      refStart, refEnd = string.find(line, '%[%^%-?%d+%]', refStart + 1)
      if refStart == nil or refEnd == nil then
        break
      end
      ref_locations[#ref_locations + 1] = { i, refStart, refEnd }
    end
    ::continue::
  end

  -- NOTE: see issue #2
  -- Ask user about adding colons if missing colon locations found
  if not skip_colon_check and #missing_colon_locations > 0 then
    vim.ui.select({ 'Yes', 'No, continue', 'Cancel' }, {
      prompt = #missing_colon_locations .. ' footnote definitions missing colons. Add them?',
    }, function(choice)
      if choice == 'Yes' then
        -- Add colons in reverse order to maintain position accuracy
        for i = #missing_colon_locations, 1, -1 do
          local location = missing_colon_locations[i]
          local row, col = location[1], location[2]
          vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { ':' })
          content_locations[#content_locations + 1] = row

          -- Shift ref_locations on the same line that come after the colon insertion
          for j = 1, #ref_locations do
            local ref_location = ref_locations[j]
            if ref_location[1] == row and ref_location[2] > col then
              ref_locations[j][2] = ref_locations[j][2] + 1 -- shift start position
              ref_locations[j][3] = ref_locations[j][3] + 1 -- shift end position
            end
          end
        end

        -- Refresh buffer and continue with organization
        buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)

        M.organize_footnotes()
      elseif choice == 'No, continue' then
        -- Continue organization without adding colons, skip colon check
        M.organize_footnotes(true)
      end
    end)
    return
  end

  -- if no foonote is found, do nothing
  if #ref_locations <= 0 then
    return
  end

  -- First pass: collect all unique footnote numbers from original buffer
  local unique_numbers = {}
  local seen_numbers = {}
  for index = 1, #ref_locations, 1 do
    local location = ref_locations[index]
    local label = string.sub(buffer[location[1]], location[2], location[3])
    local number = tonumber(string.sub(label, 3, -2))

    if number and not seen_numbers[number] then
      seen_numbers[number] = true
      unique_numbers[#unique_numbers + 1] = number
    end
  end

  -- Second pass: process each unique number once
  local counter = 1
  for _, number in ipairs(unique_numbers) do
    if not is_orphan(0, content_locations, number) then
      if Opts.debug_print then
        print(number .. ' -> ' .. counter)
      end
      ref_rename(0, ref_locations, number, counter)
      content_rename(0, content_locations, number, counter)
      counter = counter + 1
    else
      mark_as_orphan(0, ref_locations, orphan_locations, number)
    end
  end

  -- move cursor after sorting/modifying footnote content
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor_pos[1]
  local cursor_col = cursor_pos[2]

  -- sort footnote content
  for i = 1, #content_locations, 1 do
    buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local target = content_locations[i]
    for j = i, #content_locations, 1 do
      local current = content_locations[j]
      local num = string.match(buffer[current], '%-?%d+')
      if tonumber(num) == i and j ~= i then
        local temp = buffer[target]
        vim.api.nvim_buf_set_text(0, target - 1, 0, target - 1, -1, { buffer[current] })
        vim.api.nvim_buf_set_text(0, current - 1, 0, current - 1, -1, { temp })
        if cursor_row == current then
          cursor_row = target
        elseif cursor_row == target then
          cursor_row = current
        end
        break
      end
    end
  end

  vim.api.nvim_win_set_cursor(0, { cursor_row, cursor_col })

  print 'Organize footnote'

  if #orphan_locations > 0 then
    vim.schedule(function()
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = #orphan_locations .. ' orphans detected. Would you like to purge them?',
      }, function(choice)
        if choice == 'Yes' then
          cleanup_orphan(0, orphan_locations)
        end
      end)
    end)
  end
end

return M
