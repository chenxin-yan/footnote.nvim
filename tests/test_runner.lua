#!/usr/bin/env -S nvim -l

-- Test runner for footnote.nvim
-- Usage: nvim -l tests/test_runner.lua

local test_dir = vim.fn.expand('<sfile>:p:h')
local project_root = vim.fn.fnamemodify(test_dir, ':h')

-- Add lua directory to package path
local lua_dir = project_root .. '/lua'
package.path = lua_dir .. '/?.lua;' .. lua_dir .. '/?/init.lua;' .. package.path

-- Initialize minimal vim environment for testing
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Simple assertion library for testing without external dependencies
local function assert_equal(expected, actual, message)
  if expected ~= actual then
    error(string.format("Assertion failed: %s\nExpected: %s\nActual: %s", 
          message or "values not equal", tostring(expected), tostring(actual)))
  end
end

local function assert_true(value, message)
  if not value then
    error(string.format("Assertion failed: %s\nExpected: true\nActual: %s", 
          message or "value is not true", tostring(value)))
  end
end

local function assert_false(value, message) 
  if value then
    error(string.format("Assertion failed: %s\nExpected: false\nActual: %s", 
          message or "value is not false", tostring(value)))
  end
end

local function assert_nil(value, message)
  if value ~= nil then
    error(string.format("Assertion failed: %s\nExpected: nil\nActual: %s", 
          message or "value is not nil", tostring(value)))
  end
end

local function assert_not_nil(value, message)
  if value == nil then
    error(string.format("Assertion failed: %s\nExpected: not nil\nActual: nil", 
          message or "value is nil"))
  end
end

-- Mock testing framework functions
_G.describe = function(name, fn)
  print("  " .. name)
  fn()
end

_G.it = function(name, fn)
  local status, err = pcall(fn)
  if status then
    print("    ✓ " .. name)
  else
    print("    ✗ " .. name)
    print("      Error: " .. tostring(err))
  end
end

_G.before_each = function(fn)
  -- Store setup function, call before each test
  _G._before_each_fn = fn
end

-- Mock assertion library
_G.assert = {
  are = {
    equal = assert_equal,
    same = assert_equal
  },
  is_true = assert_true,
  is_false = assert_false,
  is_nil = assert_nil,
  is_not_nil = assert_not_nil,
  is_not = {
    equal = function(expected, actual, message)
      if expected == actual then
        error(string.format("Assertion failed: %s\nExpected not: %s\nActual: %s", 
              message or "values should not be equal", tostring(expected), tostring(actual)))
      end
    end
  },
  is_table = function(value, message)
    if type(value) ~= 'table' then
      error(string.format("Assertion failed: %s\nExpected: table\nActual: %s", 
            message or "value is not a table", type(value)))
    end
  end,
  is_function = function(value, message)
    if type(value) ~= 'function' then
      error(string.format("Assertion failed: %s\nExpected: function\nActual: %s", 
            message or "value is not a function", type(value)))
    end
  end
}

-- Test discovery and execution
local function run_tests()
  print("Running footnote.nvim tests...")
  
  -- Run all tests (both unit and integration)
  local all_tests = vim.fn.glob(test_dir .. '/spec/**/*_spec.lua', false, true)
  
  for _, test_file in ipairs(all_tests) do
    print("Running: " .. vim.fn.fnamemodify(test_file, ':t'))
    local status, err = pcall(dofile, test_file)
    if not status then
      print("  Error loading test file: " .. tostring(err))
    end
  end
  
  print("Tests completed!")
end

-- Run the tests
run_tests()