# 🏷️ Footnote.nvim

A lightweight Neovim plugin that simplifies working with Markdown footnotes

## ✨ Features

- Create sequential footnotes
- Organize footnotes based on occurrence
- cleanup orphan footnotes
- Goto next/prev footnote
- Move between footnote references and its content
- Pick from existing footnotes for insertion `(WIP)`

## ⚡️ Requirements

- Neovim >= 0.7.0

## 📦 Installation

Install using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  'chenxin-yan/footnote.nvim',
  opts = {
    -- add any configuration here
  }
}
```

## ⚙️ Configuration

Default Configuration:

```lua
local default = {
  debug_print = false, -- enable debug output for renaming operations
  keys = {
    new_footnote = '<C-f>',       -- works in insert and normal mode
    organize_footnotes = '<leader>of', -- normal mode only
    next_footnote = ']f',         -- normal mode only
    prev_footnote = '[f',         -- normal mode only
  },
  organize_on_save = false, -- auto-organize footnotes on file save
  organize_on_new = false,  -- auto-organize when creating a new footnote
}
```

<details><summary>Example Configuration</summary>

```lua
  return {
    'chenxin-yan/footnote.nvim',
    event = "VeryLazy"
    opts = {
      keys = {
        new_footnote = '<C-f>',
        organize_footnotes = '',
        next_footnote = ']f',
        prev_footnote = '[f',
      },
      organize_on_new = true,
    }
  }
```

</details>

## API Reference

| Function                                   | Description                                       |
| ------------------------------------------ | ------------------------------------------------- |
| `require('footnote').setup(opts)`          | Initialize the plugin with optional configuration |
| `require('footnote').new_footnote()`       | Create a new footnote or jump to existing one     |
| `require('footnote').organize_footnotes()` | Organize and renumber all footnotes by occurrence |
| `require('footnote').next_footnote()`      | Navigate to the next footnote reference           |
| `require('footnote').prev_footnote()`      | Navigate to the previous footnote reference       |

## ⌨️ Mappings

| Mapping      | Mode           | Description                             |
| ------------ | -------------- | --------------------------------------- |
| `<C-f>`      | Insert, Normal | Create new footnote or jump to existing |
| `<leader>of` | Normal         | Organize footnotes                      |
| `]f`         | Normal         | Go to next footnote                     |
| `[f`         | Normal         | Go to previous footnote                 |

You can disable any keymaps by setting it to `''`, and you can also manually set these keymaps.

<details><summary>Set Keymaps Manually</summary>

```lua
require('footnote').setup {
  keys = {
    new_footnote = '',
    organize_footnotes = '',
    next_footnote = '',
    prev_footnote = '',
  },
}
vim.keymap.set(
  { 'i', 'n' },
  opts.keys.new_footnote,
  "<cmd>lua require('footnote').new_footnote()<cr>",
  { buffer = 0, silent = true, desc = 'Create markdown footnote' }
)
vim.keymap.set(
  { 'n' },
  opts.keys.organize_footnotes,
  "<cmd>lua require('footnote').organize_footnotes()<cr>",
  { buffer = 0, silent = true, desc = 'Organize footnote' }
)
vim.keymap.set(
  { 'n' },
  opts.keys.next_footnote,
  "<cmd>lua require('footnote').next_footnote()<cr>",
  { buffer = 0, silent = true, desc = 'Next footnote' }
)
vim.keymap.set(
  { 'n' },
  opts.keys.prev_footnote,
  "<cmd>lua require('footnote').prev_footnote()<cr>",
  { buffer = 0, silent = true, desc = 'Previous footnote' }
)
```

</details>

## 🚀 Usage

**Create new footnote**: `require('footnote').new_footnote()` (default: `<C-f>`)

- If cursor is on/before an existing footnote reference, jumps to the corresponding definition
- If cursor is on a footnote definition, jumps to the first reference (clears orphan definitions)
- If cursor is on an orphan reference (no definition), creates a new definition
- Otherwise, creates a new sequential footnote at end of current word

![new-footnote-preview](./new-footnote-preview.gif)

**Organize footnote**: `require('footnote').organize_footnotes()` (default: `<leader>of`)

- Organizes all references based on order of occurrence in the document
- Footnotes are sorted based on numerical value in their references
- Detects and prompts to fix footnote definitions missing colons (e.g., `[^1]` -> `[^1]:`)
- Detects orphan references (references without definitions) and prompts to delete them

![organize-foonotes-preview](./organize-footnotes-preview.gif)

**Organize on new footnote**: `opts = {organize_on_new = true}` (default: `false`)

![organize-on-new-preview](./organize-on-new-preview.gif)

**Next/Prev footnote**: `require('footnote').next_footnote()`, `require('footnote').prev_footnote()` (default: `]f`/`[f`)

![footnote-navigation-preview](./footnote-navigation-preview.gif)

## 💡 Inspirations

- README.md inspired by [Folke](https://github.com/folke)
- [markdowny.nvim](https://github.com/antonk52/markdowny.nvim)
- [vim-markdownfootnote](https://github.com/vim-pandoc/vim-markdownfootnotes)
