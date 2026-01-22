local operations = require 'footnote.operations'
local organizer = require 'footnote.organizer'
local navigation = require 'footnote.navigation'
local config = require 'footnote.config'

local M = {}

function M.new_footnote()
  operations.new_footnote()
end

function M.organize_footnotes()
  organizer.organize_footnotes()
end

function M.next_footnote()
  navigation.next_footnote()
end

function M.prev_footnote()
  navigation.prev_footnote()
end

function M.setup(opts)
  opts = opts or {}

  -- Detect and warn about legacy keymap config
  -- TODO: Remove legacy config support
  if opts.keys and config.is_legacy_keys(opts.keys) then
    config.notify_legacy_config()
    opts.keys = config.migrate_legacy_keys(opts.keys)
  end

  Opts = vim.tbl_deep_extend('force', config.default_opts, opts)

  config.setup_keymaps(Opts)
  config.setup_autocmds(Opts)
end

return M
