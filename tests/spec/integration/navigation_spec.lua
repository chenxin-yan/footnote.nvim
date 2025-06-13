-- Integration tests for footnote.navigation module

local navigation = require('footnote.navigation')

-- Mock vim API for integration testing
local current_buffer_lines = {}
local cursor_position = {1, 0}

local mock_vim = {
  api = {
    nvim_buf_get_lines = function(bufnr, start, end_line, strict_indexing)
      if start == 0 and end_line == -1 then
        return current_buffer_lines
      elseif end_line == -1 then
        -- From start to end
        local result = {}
        for i = start + 1, #current_buffer_lines do
          table.insert(result, current_buffer_lines[i])
        end
        return result
      else
        -- Specific range
        local result = {}
        for i = start + 1, math.min(end_line, #current_buffer_lines) do
          table.insert(result, current_buffer_lines[i])
        end
        return result
      end
    end,
    nvim_win_get_cursor = function(winnr)
      return cursor_position
    end,
    nvim_win_set_cursor = function(winnr, pos)
      cursor_position = pos
    end
  }
}

-- Save original vim and replace with mock
local original_vim = vim
vim = mock_vim

describe("footnote.navigation integration", function()
  
  before_each(function()
    -- Reset test state
    current_buffer_lines = {}
    cursor_position = {1, 0}
  end)
  
  describe("next_footnote", function()
    it("should move to next footnote reference in same line", function()
      current_buffer_lines = {"Text[^1] and more[^2] content"}
      cursor_position = {1, 0} -- At beginning
      
      navigation.next_footnote()
      
      -- Should move to first footnote [^1]
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(6, cursor_position[2]) -- Inside [^1]
    end)
    
    it("should move to next footnote reference in different line", function()
      current_buffer_lines = {
        "First line[^1] here",
        "Second line with text",
        "Third line[^2] here"
      }
      cursor_position = {1, 15} -- After [^1]
      
      navigation.next_footnote()
      
      -- Should move to [^2] in third line
      assert.are.equal(3, cursor_position[1])
      assert.are.equal(12, cursor_position[2]) -- Inside [^2]
    end)
    
    it("should skip footnote content lines", function()
      current_buffer_lines = {
        "Text[^1] here",
        "",
        "[^1]: This is footnote content",
        "More text[^2] here"
      }
      cursor_position = {1, 0} -- At beginning
      
      navigation.next_footnote()
      
      -- Should move to [^1] in first line, not the content
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(6, cursor_position[2])
    end)
    
    it("should not move when no next footnote exists", function()
      current_buffer_lines = {"Text without footnotes"}
      cursor_position = {1, 5}
      local original_pos = {cursor_position[1], cursor_position[2]}
      
      navigation.next_footnote()
      
      -- Should stay at same position
      assert.are.equal(original_pos[1], cursor_position[1])
      assert.are.equal(original_pos[2], cursor_position[2])
    end)
    
    it("should not move when at last footnote", function()
      current_buffer_lines = {"Text[^1] here"}
      cursor_position = {1, 8} -- After [^1]
      local original_pos = {cursor_position[1], cursor_position[2]}
      
      navigation.next_footnote()
      
      -- Should stay at same position
      assert.are.equal(original_pos[1], cursor_position[1])
      assert.are.equal(original_pos[2], cursor_position[2])
    end)
    
    it("should handle multiple footnotes and find next one", function()
      current_buffer_lines = {
        "First[^1] and second[^2]",
        "Third[^3] footnote"
      }
      cursor_position = {1, 12} -- Between [^1] and [^2]
      
      navigation.next_footnote()
      
      -- Should move to [^2]
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(20, cursor_position[2])
    end)
    
    it("should stop at footnote content boundary", function()
      current_buffer_lines = {
        "Text[^1] here",
        "More text[^2]",
        "",
        "[^1]: Content starts here"
      }
      cursor_position = {2, 12} -- After [^2]
      
      navigation.next_footnote()
      
      -- Should not find any more footnotes (stops at content)
      assert.are.equal(2, cursor_position[1])
      assert.are.equal(12, cursor_position[2])
    end)
  end)
  
  describe("prev_footnote", function()
    it("should move to previous footnote reference in same line", function()
      current_buffer_lines = {"Text[^1] and more[^2] content"}
      cursor_position = {1, 25} -- After [^2]
      
      navigation.prev_footnote()
      
      -- Should move to [^2]
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(19, cursor_position[2])
    end)
    
    it("should move to previous footnote reference in different line", function()
      current_buffer_lines = {
        "First line[^1] here",
        "Second line with text",
        "Third line[^2] here"
      }
      cursor_position = {3, 5} -- Before [^2]
      
      navigation.prev_footnote()
      
      -- Should move to [^1] in first line
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(12, cursor_position[2])
    end)
    
    it("should skip footnote content lines when searching backwards", function()
      current_buffer_lines = {
        "Text[^1] here",
        "",
        "[^1]: This is footnote content",
        "More text here"
      }
      cursor_position = {4, 5} -- In line after content
      
      navigation.prev_footnote()
      
      -- Should move to [^1] in first line, skipping content
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(6, cursor_position[2])
    end)
    
    it("should not move when no previous footnote exists", function()
      current_buffer_lines = {"Text without footnotes"}
      cursor_position = {1, 5}
      local original_pos = {cursor_position[1], cursor_position[2]}
      
      navigation.prev_footnote()
      
      -- Should stay at same position
      assert.are.equal(original_pos[1], cursor_position[1])
      assert.are.equal(original_pos[2], cursor_position[2])
    end)
    
    it("should not move when at first footnote", function()
      current_buffer_lines = {"Text[^1] here"}
      cursor_position = {1, 2} -- Before [^1]
      local original_pos = {cursor_position[1], cursor_position[2]}
      
      navigation.prev_footnote()
      
      -- Should stay at same position
      assert.are.equal(original_pos[1], cursor_position[1])
      assert.are.equal(original_pos[2], cursor_position[2])
    end)
    
    it("should find last footnote on previous lines", function()
      current_buffer_lines = {
        "First[^1] and second[^2]",
        "Third line without footnotes",
        "Fourth line also without"
      }
      cursor_position = {3, 5} -- In fourth line
      
      navigation.prev_footnote()
      
      -- Should move to [^2] (last footnote on first line)
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(20, cursor_position[2])
    end)
    
    it("should handle multiple footnotes and find previous one", function()
      current_buffer_lines = {
        "First[^1] and second[^2]",
        "Third[^3] footnote"
      }
      cursor_position = {2, 2} -- In second line, before [^3]
      
      navigation.prev_footnote()
      
      -- Should move to [^2] (last on previous line)
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(20, cursor_position[2])
    end)
    
    it("should handle cursor in middle of line with multiple footnotes", function()
      current_buffer_lines = {"First[^1] middle[^2] end[^3]"}
      cursor_position = {1, 25} -- Between [^2] and [^3]
      
      navigation.prev_footnote()
      
      -- Should move to [^2]
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(15, cursor_position[2])
    end)
  end)
  
  describe("edge cases", function()
    it("should handle empty buffer", function()
      current_buffer_lines = {""}  -- At least one empty line
      cursor_position = {1, 0}
      
      -- Should not crash
      local status1, err1 = pcall(navigation.next_footnote)
      local status2, err2 = pcall(navigation.prev_footnote)
      
      -- Should not crash (both calls should succeed)
      assert.is_true(status1)
      assert.is_true(status2)
      
      -- Position should remain unchanged
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(0, cursor_position[2])
    end)
    
    it("should handle buffer with only footnote content", function()
      current_buffer_lines = {
        "[^1]: First footnote",
        "[^2]: Second footnote"
      }
      cursor_position = {1, 5}
      
      navigation.next_footnote()
      navigation.prev_footnote()
      
      -- Should not move (no references, only content)
      assert.are.equal(1, cursor_position[1])
      assert.are.equal(5, cursor_position[2])
    end)
    
    it("should handle malformed footnote references", function()
      current_buffer_lines = {
        "Text[^] incomplete",
        "Text[^abc] non-numeric", 
        "Text[^1] valid footnote"
      }
      cursor_position = {1, 0}
      
      navigation.next_footnote()
      
      -- Should skip malformed ones and find valid [^1]
      assert.are.equal(3, cursor_position[1])
      assert.are.equal(6, cursor_position[2])
    end)
  end)
end)

-- Restore original vim
vim = original_vim

-- Simple test runner for standalone execution
if not package.loaded['busted'] then
  print("Running navigation integration tests...")
  
  local function assert_equal(expected, actual, message)
    if expected ~= actual then
      error(string.format("Assertion failed: %s\nExpected: %s\nActual: %s", 
            message or "values not equal", tostring(expected), tostring(actual)))
    end
  end
  
  local function run_simple_tests()
    -- Test that navigation module loads
    assert_equal('table', type(navigation), "navigation should be a module table")
    assert_equal('function', type(navigation.next_footnote), "next_footnote should be a function")
    assert_equal('function', type(navigation.prev_footnote), "prev_footnote should be a function")
    
    print("✓ Basic navigation integration tests passed")
  end
  
  run_simple_tests()
end
