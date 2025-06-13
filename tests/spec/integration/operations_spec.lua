-- Integration tests for footnote.operations module
-- These tests use real buffer operations to test the complete workflow

local operations = require 'footnote.operations'
local utils = require 'footnote.utils'

-- Mock vim API for integration testing
local current_buffer_lines = {}
local cursor_position = { 1, 0 }
local insert_mode_started = false

local mock_vim = {
  api = {
    nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
      if end_line == -1 then
        return current_buffer_lines
      end
      local result = {}
      for i = start + 1, math.min(end_line, #current_buffer_lines) do
        table.insert(result, current_buffer_lines[i])
      end
      return result
    end,
    nvim_buf_set_text = function(bufnr, start_row, start_col, end_row, end_col, replacement)
      local line = current_buffer_lines[start_row + 1] or ''
      local new_line = line:sub(1, start_col) .. (replacement[1] or '') .. line:sub(end_col + 1)
      current_buffer_lines[start_row + 1] = new_line
    end,
    nvim_buf_set_lines = function(bufnr, start, end_line, strict_indexing, replacement)
      if start == -1 then
        -- Append to end
        for _, line in ipairs(replacement) do
          table.insert(current_buffer_lines, line)
        end
      else
        -- Replace lines
        for i, line in ipairs(replacement) do
          current_buffer_lines[start + i] = line
        end
      end
    end,
    nvim_win_get_cursor = function(winnr)
      return cursor_position
    end,
    nvim_win_set_cursor = function(winnr, pos)
      cursor_position = pos
    end,
    nvim_buf_line_count = function(bufnr)
      return #current_buffer_lines
    end,
  },
  cmd = function(cmd)
    if cmd == 'normal! m`' then
      -- Mock mark setting
    elseif cmd == 'startinsert!' then
      insert_mode_started = true
    end
  end,
}

-- Mock global Opts
_G.Opts = {
  organize_on_new = false,
  debug_print = false,
}

-- Save original vim and replace with mock
local original_vim = vim
vim = mock_vim
print = function(...) end -- Suppress print outputs during tests

describe('footnote.operations integration', function()
  before_each(function()
    -- Reset test state
    current_buffer_lines = {}
    cursor_position = { 1, 0 }
    insert_mode_started = false
    _G.Opts.organize_on_new = false
  end)

  describe('new_footnote', function()
    it('should create first footnote in empty buffer', function()
      current_buffer_lines = { 'Hello world' }
      cursor_position = { 1, 5 } -- At end of "Hello"

      operations.new_footnote()

      -- Should add footnote reference
      assert.are.equal('Hello[^1] world', current_buffer_lines[1])
      -- Should add footnote content at end
      assert.are.equal('', current_buffer_lines[2])
      assert.are.equal('[^1]: ', current_buffer_lines[3])
      -- Should position cursor at end of footnote content
      assert.are.equal(3, cursor_position[1])
      assert.are.equal(6, cursor_position[2]) -- After "[^1]: "
      -- Should start insert mode
      assert.is_true(insert_mode_started)
    end)

    it('should create footnote with correct number when others exist', function()
      current_buffer_lines = {
        'First footnote[^1] here',
        'Third footnote[^3] here',
        '',
        '[^1]: First note',
        '[^3]: Third note',
      }
      cursor_position = { 1, 13 } -- At end of "footnote"

      operations.new_footnote()

      -- Should create footnote with number 4 (next after 3)
      assert.are.equal('First footnote[^4][^1] here', current_buffer_lines[1])
      assert.are.equal('[^4]: ', current_buffer_lines[6])
    end)

    it('should jump to footnote content when cursor is on existing reference', function()
      current_buffer_lines = {
        'Text with footnote[^1] here',
        '',
        '[^1]: Existing footnote content',
      }
      cursor_position = { 1, 18 } -- Inside [^1]

      operations.new_footnote()

      -- Should jump to footnote content
      assert.are.equal(3, cursor_position[1])
      assert.are.equal(8, cursor_position[2]) -- After "[^1]: "
    end)

    it('should jump to reference when cursor is on footnote content line', function()
      current_buffer_lines = {
        'Text with footnote[^1] here',
        '',
        '[^1]: Existing footnote content',
      }
      cursor_position = { 3, 5 } -- On footnote content line

      operations.new_footnote()

      -- Should jump to reference
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(20, cursor_position[2]) -- Inside [^1]
    end)

    it('should handle footnote at word boundary', function()
      current_buffer_lines = { 'word' }
      cursor_position = { 1, 2 } -- Middle of "word"

      operations.new_footnote()

      -- Should add footnote at end of word
      assert.are.equal('word[^1]', current_buffer_lines[1])
    end)

    it('should remove existing footnote reference at cursor position', function()
      current_buffer_lines = {
        'Text[^1] more text',
        '',
        '[^1]: Footnote content',
      }
      cursor_position = { 1, 7 } -- Right after "Text[^1]"

      operations.new_footnote()

      -- Should remove the [^1] reference
      assert.are.equal('Text more text', current_buffer_lines[1])
    end)

    it('should organize footnotes when organize_on_new is enabled', function()
      _G.Opts.organize_on_new = true
      -- Mock the organizer module
      local organizer_called = false
      local mock_organizer = {
        organize_footnotes = function()
          organizer_called = true
        end,
      }
      package.loaded['footnote.organizer'] = mock_organizer

      current_buffer_lines = { 'Test' }
      cursor_position = { 1, 4 }

      operations.new_footnote()

      -- Should have called organizer
      assert.is_true(organizer_called)
    end)

    it('should handle multiple footnotes on same line', function()
      current_buffer_lines = { 'Text[^1] and more[^2] text' }
      cursor_position = { 1, 4 } -- At "Text"

      operations.new_footnote()

      -- Should add new footnote
      assert.are.equal('Text[^3][^1] and more[^2] text', current_buffer_lines[1])
    end)

    it('should handle cursor at beginning of line', function()
      current_buffer_lines = { 'Hello world' }
      cursor_position = { 1, 0 } -- At beginning

      operations.new_footnote()

      -- Should add footnote after first word
      assert.are.equal('Hello[^1] world', current_buffer_lines[1])
    end)

    it('should handle empty line', function()
      current_buffer_lines = { '' }
      cursor_position = { 1, 0 }

      operations.new_footnote()

      -- Should add footnote at current position
      assert.are.equal('[^1]', current_buffer_lines[1])
    end)
  end)
end)

-- Restore original vim
vim = original_vim

-- Simple test runner for standalone execution
if not package.loaded['busted'] then
  print 'Running operations integration tests...'

  local function assert_equal(expected, actual, message)
    if expected ~= actual then
      error(string.format('Assertion failed: %s\nExpected: %s\nActual: %s', message or 'values not equal', tostring(expected), tostring(actual)))
    end
  end

  local function run_simple_tests()
    -- Test that operations module loads
    assert_equal('table', type(operations), 'operations should be a module table')
    assert_equal('function', type(operations.new_footnote), 'new_footnote should be a function')

    print '✓ Basic operations integration tests passed'
  end

  run_simple_tests()
end

