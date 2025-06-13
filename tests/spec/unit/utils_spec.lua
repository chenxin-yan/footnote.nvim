-- Unit tests for footnote.utils module

local utils = require('footnote.utils')

-- Mock vim.api for unit testing
local mock_vim_api = {
  nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
    -- Return mock buffer lines for testing
    return {"This is a test line with some words"}
  end
}

-- Save original vim.api and replace with mock
local original_vim_api = vim.api
vim.api = mock_vim_api

describe("footnote.utils", function()
  
  describe("get_next_footnote_number", function()
    it("should return 1 for empty buffer", function()
      local buffer = {}
      local result = utils.get_next_footnote_number(buffer)
      assert.are.equal(1, result)
    end)
    
    it("should return 1 for buffer with no footnotes", function()
      local buffer = {
        "This is a line without footnotes",
        "Another line without footnotes"
      }
      local result = utils.get_next_footnote_number(buffer)
      assert.are.equal(1, result)
    end)
    
    it("should return next number after existing footnotes", function()
      local buffer = {
        "This line has a footnote[^1]",
        "This line has another footnote[^3]",
        "[^1]: First footnote",
        "[^3]: Third footnote"
      }
      local result = utils.get_next_footnote_number(buffer)
      assert.are.equal(4, result)
    end)
    
    it("should handle footnotes out of order", function()
      local buffer = {
        "Line with [^5] and [^1] and [^10]",
        "[^1]: First",
        "[^5]: Fifth", 
        "[^10]: Tenth"
      }
      local result = utils.get_next_footnote_number(buffer)
      assert.are.equal(11, result)
    end)
    
    it("should handle single digit and multi-digit footnotes", function()
      local buffer = {
        "Single [^1] and double [^99] digit footnotes",
      }
      local result = utils.get_next_footnote_number(buffer)
      assert.are.equal(100, result)
    end)
  end)
  
  describe("get_word_end", function()
    before_each(function()
      -- Mock different line content for each test
      vim.api.nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
        return {"hello world test"}
      end
    end)
    
    it("should find end of word at beginning", function()
      -- Cursor at 'h' (position 0), should find end of "hello" at position 4
      local result = utils.get_word_end(0, 1, 0)
      assert.are.equal(4, result)
    end)
    
    it("should find end of word in middle", function() 
      -- Cursor at 'w' (position 6), should find end of "world" at position 10
      local result = utils.get_word_end(0, 1, 6)
      assert.are.equal(10, result)
    end)
    
    it("should handle cursor at end of word", function()
      -- Cursor at 'o' in "hello" (position 4), should stay at position 4
      local result = utils.get_word_end(0, 1, 4)
      assert.are.equal(4, result)
    end)
    
    it("should handle cursor on space", function()
      -- Cursor on space (position 5), should return same position
      local result = utils.get_word_end(0, 1, 5)
      assert.are.equal(5, result)
    end)
  end)
  
  describe("is_on_ref", function()
    it("should return nil when not on footnote reference", function()
      local buffer = {"This line has no footnotes"}
      local result = utils.is_on_ref(buffer, 1, 5)
      assert.is_nil(result)
    end)
    
    it("should return start position when cursor is on footnote reference", function()
      local buffer = {"This has a footnote[^1] here"}
      -- Cursor at position 19 (inside [^1])
      local result = utils.is_on_ref(buffer, 1, 19)
      assert.are.equal(18, result) -- Start of [^1] is at position 18 (0-indexed)
    end)
    
    it("should return nil when cursor is just before footnote", function()
      local buffer = {"Text[^1]"}
      local result = utils.is_on_ref(buffer, 1, 3) -- Just before [
      assert.is_nil(result)
    end)
    
    it("should return nil when cursor is just after footnote", function()
      local buffer = {"Text[^1] more"}
      local result = utils.is_on_ref(buffer, 1, 8) -- Just after ]
      assert.is_nil(result)
    end)
    
    it("should handle multiple footnotes on same line", function()
      local buffer = {"First[^1] and second[^2] footnotes"}
      
      -- Test first footnote
      local result1 = utils.is_on_ref(buffer, 1, 6) -- Inside [^1]
      assert.are.equal(5, result1)
      
      -- Test second footnote  
      local result2 = utils.is_on_ref(buffer, 1, 19) -- Inside [^2]
      assert.are.equal(18, result2)
      
      -- Test between footnotes
      local result3 = utils.is_on_ref(buffer, 1, 10) -- Between footnotes
      assert.is_nil(result3)
    end)
    
    it("should handle multi-digit footnote numbers", function()
      local buffer = {"Footnote [^123] here"}
      local result = utils.is_on_ref(buffer, 1, 11) -- Inside [^123]
      assert.are.equal(9, result)
    end)
  end)
end)

-- Restore original vim.api
vim.api = original_vim_api

-- Simple test runner for this file
if not package.loaded['busted'] then
  print("Running utils_spec.lua tests...")
  
  -- Simple assertion function for standalone running
  local function assert_equal(expected, actual, message)
    if expected ~= actual then
      error(string.format("Assertion failed: %s\nExpected: %s\nActual: %s", 
            message or "values not equal", tostring(expected), tostring(actual)))
    end
  end
  
  local function assert_nil(value, message)
    if value ~= nil then
      error(string.format("Assertion failed: %s\nExpected: nil\nActual: %s", 
            message or "value is not nil", tostring(value)))
    end
  end
  
  local function run_simple_tests()
    -- Test get_next_footnote_number
    local buffer1 = {}
    assert_equal(1, utils.get_next_footnote_number(buffer1), "Empty buffer should return 1")
    
    local buffer2 = {"Line with [^5] footnote"}
    assert_equal(6, utils.get_next_footnote_number(buffer2), "Should return next number after existing")
    
    -- Test is_on_ref
    local buffer3 = {"Text[^1]"}
    assert_equal(4, utils.is_on_ref(buffer3, 1, 5), "Should find footnote reference")
    assert_nil(utils.is_on_ref(buffer3, 1, 0), "Should not find reference at start")
    
    print("✓ Basic utils tests passed")
  end
  
  run_simple_tests()
end