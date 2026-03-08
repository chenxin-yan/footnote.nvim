local M = {}
local config = require 'footnote.config'
local parser = require 'footnote.parser'

--- Mark a footnote reference as orphan
---@param bufnr number buffer number
---@param ref_locations table locations of all the footnote references
---@param orphan_locations table locations of all the orphan references
---@param from number the label to mark as orphan
local function mark_as_orphan(bufnr, ref_locations, orphan_locations, from)
  local orphan_number = from < 0 and from or -from
  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local matching_locations = {}

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

  for i = #matching_locations, 1, -1 do
    local index, location = matching_locations[i][1], matching_locations[i][2]
    local row = location[1]
    local start_col = location[2]
    local end_col = location[3]

    vim.api.nvim_buf_set_text(bufnr, row - 1, start_col + 1, row - 1, end_col - 1, { tostring(orphan_number) })

    local diff = #tostring(orphan_number) - #tostring(from)
    orphan_locations[#orphan_locations + 1] = { row, start_col, end_col + diff }

    local shift = #tostring(orphan_number) - #tostring(from)
    if shift ~= 0 then
      ref_locations[index][3] = ref_locations[index][3] + shift
      for j = 1, #ref_locations do
        local next_location = ref_locations[j]
        if next_location ~= nil and next_location[1] == row and next_location[2] > start_col then
          ref_locations[j][2] = ref_locations[j][2] + shift
          ref_locations[j][3] = ref_locations[j][3] + shift
        end
      end
    end

    buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
end

--- Rename all footnote references with given label to another label
---@param bufnr number buffer number
---@param ref_locations table locations of all footnote references
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
    local start_col = location[2]
    local end_col = location[3]
    local shift = 0

    if number == from then
      if config.get_opts().debug_print then
        print('ref_rename: ' .. from .. ' -> ' .. to)
      end
      shift = #tostring(to) - #tostring(from)
      vim.api.nvim_buf_set_text(bufnr, row - 1, start_col + 1, row - 1, end_col - 1, { tostring(to) })
    elseif number == to then
      if config.get_opts().debug_print then
        print('ref_rename: ' .. to .. ' -> ' .. from)
      end
      vim.api.nvim_buf_set_text(bufnr, row - 1, start_col + 1, row - 1, end_col - 1, { tostring(from) })
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
      end
    end

    ::continue::
  end
end

--- Rename footnote definition headers.
---@param bufnr number buffer number
---@param definitions table parsed footnote definition blocks
---@param from number the label to change
---@param to number the label to change to
local function content_rename(bufnr, definitions, from, to)
  if from == to then
    return
  end

  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, definition in ipairs(definitions) do
    local row = definition.header_row
    local num = tonumber(string.match(buffer[row], '%-?%d+'))
    if num == from then
      local i, j = string.find(buffer[row], '%-?%d+')
      if i and j then
        vim.api.nvim_buf_set_text(bufnr, row - 1, i - 1, row - 1, j, { tostring(to) })
      end
    elseif num == to then
      local i, j = string.find(buffer[row], '%-?%d+')
      if i and j then
        vim.api.nvim_buf_set_text(bufnr, row - 1, i - 1, row - 1, j, { tostring(from) })
      end
    end
  end
end

---@param definitions table
---@param label number
---@return boolean
local function has_definition(definitions, label)
  for _, definition in ipairs(definitions) do
    if definition.id == label then
      return true
    end
  end
  return false
end

---@param bufnr number
---@param definitions table
---@param max_index number
local function reorder_definition_blocks(bufnr, definitions, max_index)
  if #definitions == 0 or max_index <= 0 then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks_by_number = {}

  for _, definition in ipairs(definitions) do
    if definition.id and definition.id > 0 then
      local block = {}
      for row = definition.start_row, definition.end_row do
        block[#block + 1] = lines[row]
      end
      blocks_by_number[definition.id] = block
    end
  end

  for idx = #definitions, 1, -1 do
    local slot = definitions[idx]
    local replacement = blocks_by_number[idx]
    if replacement ~= nil and idx <= max_index then
      vim.api.nvim_buf_set_lines(bufnr, slot.start_row - 1, slot.end_row, false, replacement)
    end
  end
end

--- Clean up orphan footnote references in a given buffer
---@param bufnr number buffer number
---@param orphan_locations table locations of all the orphans that needed to be cleaned up
local function cleanup_orphan(bufnr, orphan_locations)
  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for index = #orphan_locations, 1, -1 do
    local location = orphan_locations[index]
    if location == nil then
      goto continue
    end
    local label = string.sub(buffer[location[1]], location[2], location[3])
    local row = location[1]
    local start_col = location[2]
    local end_col = location[3]

    vim.api.nvim_buf_set_text(bufnr, row - 1, start_col - 1, row - 1, end_col, {})
    buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    vim.notify('label "' .. label .. '" at row ' .. row .. ' is deleted', vim.log.levels.INFO)
    ::continue::
  end
end

--- Organize footnote references and definitions by occurrence
---@param skip_colon_check? boolean skip checking for missing colons
function M.organize_footnotes(skip_colon_check)
  local parsed = parser.parse(0, { collect_missing_colon = not skip_colon_check })
  local ref_locations = parsed.refs
  local definitions = parsed.defs
  local orphan_locations = {}
  local missing_colon_locations = parsed.missing_colon_locations

  if not skip_colon_check and #missing_colon_locations > 0 then
    vim.ui.select({ 'Yes', 'No, continue', 'Cancel' }, {
      prompt = #missing_colon_locations .. ' footnote definitions missing colons. Add them?',
    }, function(choice)
      if choice == 'Yes' then
        for i = #missing_colon_locations, 1, -1 do
          local location = missing_colon_locations[i]
          local row, col = location[1], location[2]
          vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { ':' })
        end
        M.organize_footnotes()
      elseif choice == 'No, continue' then
        M.organize_footnotes(true)
      end
    end)
    return
  end

  if #ref_locations == 0 then
    return
  end

  local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
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

  local counter = 1
  local mapping = {}
  local orphan_numbers = {}
  for _, number in ipairs(unique_numbers) do
    if has_definition(definitions, number) then
      mapping[number] = counter
      counter = counter + 1
    else
      orphan_numbers[#orphan_numbers + 1] = number
    end
  end

  local remap_steps = {}
  for from, to in pairs(mapping) do
    if from ~= to then
      remap_steps[#remap_steps + 1] = {
        from = from,
        temp = -(1000000 + from),
        to = to,
      }
    end
  end

  for _, step in ipairs(remap_steps) do
    if config.get_opts().debug_print then
      print(step.from .. ' -> ' .. step.temp)
    end
    ref_rename(0, ref_locations, step.from, step.temp)
    content_rename(0, definitions, step.from, step.temp)
  end

  for _, step in ipairs(remap_steps) do
    if config.get_opts().debug_print then
      print(step.temp .. ' -> ' .. step.to)
    end
    ref_rename(0, ref_locations, step.temp, step.to)
    content_rename(0, definitions, step.temp, step.to)
  end

  for _, number in ipairs(orphan_numbers) do
    mark_as_orphan(0, ref_locations, orphan_locations, number)
  end

  local view = vim.fn.winsaveview()
  local parsed_after_rename = parser.parse(0, { collect_missing_colon = false })
  reorder_definition_blocks(0, parsed_after_rename.defs, counter - 1)
  vim.fn.winrestview(view)

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
