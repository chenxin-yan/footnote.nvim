local M = {}

M.default_opts = {
  debug_print = false,
  keys = {
    new_footnote = '<C-f>',
    organize_footnotes = '<leader>of',
    next_footnote = ']f',
    prev_footnote = '[f',
  },
  organize_on_save = false,
  organize_on_new = false,
}

function M.setup_keymaps(opts)
  vim.api.nvim_create_autocmd('FileType', {
    desc = 'footnote.nvim keymaps',
    pattern = { 'markdown' },
    callback = function()
      if opts.keys.new_footnote ~= '' then
        vim.keymap.set(
          { 'i', 'n' },
          opts.keys.new_footnote,
          "<cmd>lua require('footnote').new_footnote()<cr>",
          { desc = 'Create markdown footnote', buffer = 0 }
        )
      end
      if opts.keys.organize_footnotes ~= '' then
        vim.keymap.set('n', opts.keys.organize_footnotes, "<cmd>lua require('footnote').organize_footnotes()<cr>", { desc = 'Organize footnote', buffer = 0 })
      end
      if opts.keys.next_footnote ~= '' then
        vim.keymap.set('n', opts.keys.next_footnote, "<cmd>lua require('footnote').next_footnote()<cr>", { desc = 'Next footnote', buffer = 0 })
      end
      if opts.keys.prev_footnote ~= '' then
        vim.keymap.set('n', opts.keys.prev_footnote, "<cmd>lua require('footnote').prev_footnote()<cr>", { desc = 'Previous footnote', buffer = 0 })
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
