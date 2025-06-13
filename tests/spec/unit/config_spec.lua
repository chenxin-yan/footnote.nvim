-- Unit tests for footnote.config module

local config = require('footnote.config')

-- Mock vim.api for testing
local mock_keymaps = {}
local mock_autocmds = {}
local mock_augroups = {}

local mock_vim = {
  api = {
    nvim_create_autocmd = function(events, opts)
      table.insert(mock_autocmds, {events = events, opts = opts})
      return #mock_autocmds
    end,
    nvim_create_augroup = function(name, opts)
      mock_augroups[name] = opts
      return name
    end
  },
  keymap = {
    set = function(modes, lhs, rhs, opts)
      table.insert(mock_keymaps, {modes = modes, lhs = lhs, rhs = rhs, opts = opts})
    end
  },
  g = {}
}

-- Save original vim and replace with mock
local original_vim = vim
vim = mock_vim

describe("footnote.config", function()
  
  before_each(function()
    -- Reset mocks before each test
    mock_keymaps = {}
    mock_autocmds = {}
    mock_augroups = {}
    vim.keymap.set = function(modes, lhs, rhs, opts)
      table.insert(mock_keymaps, {modes = modes, lhs = lhs, rhs = rhs, opts = opts})
    end
  end)
  
  describe("default_opts", function()
    it("should have correct default values", function()
      assert.is_false(config.default_opts.debug_print)
      assert.is_true(config.default_opts.organize_on_save)
      assert.is_true(config.default_opts.organize_on_new)
      assert.are.equal('<C-f>', config.default_opts.keys.new_footnote)
      assert.are.equal('<leader>of', config.default_opts.keys.organize_footnotes)
      assert.are.equal(']f', config.default_opts.keys.next_footnote)
      assert.are.equal('[f', config.default_opts.keys.prev_footnote)
    end)
    
    it("should have keys table", function()
      assert.is_table(config.default_opts.keys)
      assert.is_not_nil(config.default_opts.keys.new_footnote)
      assert.is_not_nil(config.default_opts.keys.organize_footnotes)
      assert.is_not_nil(config.default_opts.keys.next_footnote)
      assert.is_not_nil(config.default_opts.keys.prev_footnote)
    end)
  end)
  
  describe("setup_keymaps", function()
    it("should create autocmd for markdown files", function()
      local opts = config.default_opts
      config.setup_keymaps(opts)
      
      assert.are.equal(1, #mock_autocmds)
      local autocmd = mock_autocmds[1]
      assert.are.equal('FileType', autocmd.events)
      assert.are.same({'markdown'}, autocmd.opts.pattern)
      assert.are.equal('footnote.nvim keymaps', autocmd.opts.desc)
      assert.is_function(autocmd.opts.callback)
    end)
    
    it("should set up all keymaps when callback is triggered", function()
      local opts = config.default_opts
      config.setup_keymaps(opts)
      
      -- Trigger the callback
      local callback = mock_autocmds[1].opts.callback
      callback()
      
      -- Should have 4 keymaps
      assert.are.equal(4, #mock_keymaps)
      
      -- Check new_footnote keymap
      local new_footnote_map = mock_keymaps[1]
      assert.are.same({'i', 'n'}, new_footnote_map.modes)
      assert.are.equal('<C-f>', new_footnote_map.lhs)
      assert.are.equal("<cmd>lua require('footnote').new_footnote()<cr>", new_footnote_map.rhs)
      assert.are.equal('Create markdown footnote', new_footnote_map.opts.desc)
      assert.are.equal(0, new_footnote_map.opts.buffer)
    end)
    
    it("should skip keymaps with empty key bindings", function()
      local opts = {
        keys = {
          new_footnote = '',  -- Empty key should be skipped
          organize_footnotes = '<leader>of',
          next_footnote = ']f',
          prev_footnote = '[f'
        }
      }
      config.setup_keymaps(opts)
      
      -- Trigger the callback
      local callback = mock_autocmds[1].opts.callback
      callback()
      
      -- Should have 3 keymaps (skipped the empty one)
      assert.are.equal(3, #mock_keymaps)
      
      -- Verify the empty one was skipped
      for _, keymap in ipairs(mock_keymaps) do
        assert.is_not.equal('', keymap.lhs)
      end
    end)
    
    it("should handle custom key bindings", function()
      local opts = {
        keys = {
          new_footnote = '<leader>fn',
          organize_footnotes = '<leader>fo',
          next_footnote = '<leader>]',
          prev_footnote = '<leader>['
        }
      }
      config.setup_keymaps(opts)
      
      -- Trigger the callback
      local callback = mock_autocmds[1].opts.callback
      callback()
      
      -- Check custom bindings
      assert.are.equal('<leader>fn', mock_keymaps[1].lhs)
      assert.are.equal('<leader>fo', mock_keymaps[2].lhs)
      assert.are.equal('<leader>]', mock_keymaps[3].lhs)
      assert.are.equal('<leader>[', mock_keymaps[4].lhs)
    end)
  end)
  
  describe("setup_autocmds", function()
    it("should create autocmd when organize_on_save is true", function()
      local opts = {organize_on_save = true}
      config.setup_autocmds(opts)
      
      assert.are.equal(1, #mock_autocmds)
      local autocmd = mock_autocmds[1]
      assert.are.same({'BufWritePost'}, autocmd.events)
      assert.are.same({'*.md'}, autocmd.opts.pattern)
      assert.are.equal('organize footnotes', autocmd.opts.group)
      assert.is_function(autocmd.opts.callback)
    end)
    
    it("should not create autocmd when organize_on_save is false", function()
      local opts = {organize_on_save = false}
      config.setup_autocmds(opts)
      
      assert.are.equal(0, #mock_autocmds)
    end)
    
    it("should create augroup with clear option", function()
      local opts = {organize_on_save = true}
      config.setup_autocmds(opts)
      
      assert.is_not_nil(mock_augroups['organize footnotes'])
      assert.is_true(mock_augroups['organize footnotes'].clear)
    end)
  end)
end)

-- Restore original vim
vim = original_vim

-- Simple test runner for standalone execution
if not package.loaded['busted'] then
  print("Running config_spec.lua tests...")
  
  local function assert_equal(expected, actual, message)
    if expected ~= actual then
      error(string.format("Assertion failed: %s\nExpected: %s\nActual: %s", 
            message or "values not equal", tostring(expected), tostring(actual)))
    end
  end
  
  local function run_simple_tests()
    -- Test default_opts structure
    assert_equal('table', type(config.default_opts), "default_opts should be a table")
    assert_equal('table', type(config.default_opts.keys), "keys should be a table")
    assert_equal('<C-f>', config.default_opts.keys.new_footnote, "new_footnote key should be <C-f>")
    
    -- Test that functions exist
    assert_equal('function', type(config.setup_keymaps), "setup_keymaps should be a function")
    assert_equal('function', type(config.setup_autocmds), "setup_autocmds should be a function")
    
    print("✓ Basic config tests passed")
  end
  
  run_simple_tests()
end