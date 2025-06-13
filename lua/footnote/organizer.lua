local M = {}

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
    local num = string.match(buffer[row], '%d+')
    if tonumber(num) == from then
      local i, j = string.find(buffer[row], '%d+')
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.api.nvim_buf_set_text(bufnr, row - 1, i - 1, row - 1, j, { tostring(to) })
    elseif tonumber(num) == to then
      local i, j = string.find(buffer[row], '%d+')
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.api.nvim_buf_set_text(bufnr, row - 1, i - 1, row - 1, j, { tostring(from) })
    end
  end
end

--- Cleanup orphan footnote references in a given buffer
---@param bufnr number buffer number
---@param ref_locations table locations of all the footnote references
---@param content_locations table locations of all the footnote content
---@param is_deleted table flags of whether a given footnote reference is deleted
---@param from number the refernce label to be checked
local function cleanup_orphan(bufnr, ref_locations, content_locations, is_deleted, from)
  local buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
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
        vim.api.nvim_buf_set_text(bufnr, row - 1, startCol - 1, row - 1, endCol, {})
        buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        is_deleted[index] = true
        if Opts.debug_print then
          print('cleanup_orphan: ' .. from .. ' at row ' .. row)
        end
        local shift = endCol - startCol + 1

        for j = index, #ref_locations, 1 do
          local next_location = ref_locations[j + 1]
          if next_location == nil or next_location[1] ~= row then
            break
          end
          ref_locations[j + 1][2] = ref_locations[j + 1][2] - shift
          ref_locations[j + 1][3] = ref_locations[j + 1][3] - shift
          if Opts.debug_print then
            print('shifted(' .. shift .. '): ' .. ref_locations[j + 1][1] .. ', ' .. ref_locations[j + 1][2] .. ':' .. ref_locations[j + 1][3])
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

--- Organize foonote references and content and sort based on occurence
function M.organize_footnotes()
  local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local ref_locations = {}
  local content_locations = {}
  local is_deleted = {}
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
      is_deleted[#is_deleted + 1] = false
    end
    ::continue::
  end

  if #ref_locations <= 0 then
    return
  end

  local counter = 1
  for index = 1, #ref_locations, 1 do
    local location = ref_locations[index]
    if is_deleted[index] then
      goto continue
    end
    buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local label = string.sub(buffer[location[1]], location[2], location[3])
    local number = tonumber(string.sub(label, 3, -2))

    if number >= counter then
      if not cleanup_orphan(0, ref_locations, content_locations, is_deleted, number) then
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

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor_pos[1]
  local cursor_col = cursor_pos[2]

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
end

return M
