local M = {}

M.default_opts = {
  debug_print = false,
  keys = {
    n = {
      new_footnote = '<leader>fn',
      organize_footnotes = '<leader>fo',
      next_footnote = ']f',
      prev_footnote = '[f',
    },
    i = {
      new_footnote = '<C-f>',
    },
  },
  organize_on_save = false,
  organize_on_new = false,
}

-- Keymap definitions: action -> { cmd, desc }
local keymap_actions = {
  new_footnote = {
    cmd = "<cmd>lua require('footnote').new_footnote()<cr>",
    desc = 'Create markdown footnote',
  },
  organize_footnotes = {
    cmd = "<cmd>lua require('footnote').organize_footnotes()<cr>",
    desc = 'Organize footnotes',
  },
  next_footnote = {
    cmd = "<cmd>lua require('footnote').next_footnote()<cr>",
    desc = 'Next footnote',
  },
  prev_footnote = {
    cmd = "<cmd>lua require('footnote').prev_footnote()<cr>",
    desc = 'Previous footnote',
  },
}

--- Check if keys config uses legacy flat structure
--- TODO: Remove legacy config support
---@param keys table the keys config table
---@return boolean true if legacy format detected
function M.is_legacy_keys(keys)
  return keys.new_footnote ~= nil or keys.organize_footnotes ~= nil or keys.next_footnote ~= nil or keys.prev_footnote ~= nil
end

--- Notify user about deprecated keymap config format
--- TODO: - remove legacy config support
function M.notify_legacy_config()
  vim.notify(
    '[footnote.nvim] Deprecated keymap config detected. Please migrate to the new format:\n'
      .. 'keys = { n = { new_footnote = "..." }, i = { new_footnote = "..." } }\n'
      .. 'See README.md for details.',
    vim.log.levels.WARN
  )
end

--- Convert legacy flat keys format to new mode-based format
--- TODO: Remove legacy config support
---@param keys table legacy flat keys config
---@return table new mode-based keys config
function M.migrate_legacy_keys(keys)
  return {
    n = {
      new_footnote = keys.new_footnote,
      organize_footnotes = keys.organize_footnotes,
      next_footnote = keys.next_footnote,
      prev_footnote = keys.prev_footnote,
    },
    i = {
      new_footnote = keys.new_footnote,
    },
  }
end

function M.setup_keymaps(opts)
  vim.api.nvim_create_autocmd('FileType', {
    desc = 'footnote.nvim keymaps',
    pattern = { 'markdown' },
    callback = function()
      for mode, mappings in pairs(opts.keys) do
        for action, lhs in pairs(mappings) do
          if lhs ~= '' and keymap_actions[action] then
            vim.keymap.set(mode, lhs, keymap_actions[action].cmd, { desc = keymap_actions[action].desc, buffer = 0 })
          end
        end
      end
    end,
  })
end

function M.setup_autocmds(opts)
  if opts.organize_on_save then
    vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
      group = vim.api.nvim_create_augroup('organize footnotes', { clear = true }),
      pattern = { '*.md' },
      callback = function()
        require('footnote').organize_footnotes()
      end,
    })
  end
end

return M
