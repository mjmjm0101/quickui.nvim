# quickui.nvim

A lightweight menubar and context menu plugin for Neovim.

- **Menubar** — a non-focusable title strip at the top of the editor with a dropdown that opens below the selected title
- **Context menus** — floating popups positioned at the cursor (normal and visual mode)
- **Listbox** — a centered floating selection UI
- Nested submenus (multi-level)
- Per-item conditions (`conditions`) and filetype filters (`ft`)
- Fully configurable keybindings
- Global keybindings are automatically suppressed inside quickui buffers

---

## Requirements

- Neovim 0.10+

---

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "mjmjm0101/quickui.nvim",
  lazy = false,
  config = function()
    require("quickui").setup({})
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "mjmjm0101/quickui.nvim",
  config = function()
    require("quickui").setup({})
  end,
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'mjmjm0101/quickui.nvim'

lua require("quickui").setup({})
```

---

## Quick Start

```lua
require("quickui").setup({
  keymap = "<Space>",  -- toggle the menubar
  border = "single",

  menus = {
    {
      name  = "&File",
      items = {
        { name = "&New",  cmd = ":enew<CR>" },
        { name = "&Open", cmd = ":e " },
        { name = "separator" },
        { name = "&Quit", cmd = ":qa<CR>" },
      },
    },
    {
      name  = "&Edit",
      items = {
        { name = "&Undo", cmd = "u" },
        { name = "&Redo", cmd = "<C-r>" },
      },
    },
  },
})
```

---

## Configuration Reference

```lua
require("quickui").setup({

  -- Key to toggle the menubar (default: "<Space>")
  keymap = "<Space>",

  -- Border style: "none" | "single" | "double" | "rounded" | "dotted" | "dashed"
  border = "single",

  -- Transparency 0-100. number = both bar and menu, table = individual
  winblend = { bar = 0, menu = 15 },

  -- Number of padding spaces on each side of a menubar item (default: 1)
  menubar_padding = 2,

  -- Separator character between menubar items. "" to disable (default: "│")
  menubar_separator = "│",

  -- Highlight group overrides
  highlights = {
    accent            = "#89b4fa",  -- shortcut letter (character after &)
    rtxt              = "#a6e3a1",  -- right-aligned text (rtxt field)
    menu              = { bg = "#1e1e2e", fg = "#cdd6f4" },
    menu_sel          = { bg = "#4974aa", fg = "#cdd6f4" },
    menu_border       = { fg = "#89b4fa" },
    menubar           = { bg = "#181825", fg = "#cdd6f4" },
    menubar_sel       = { bg = "#313244", fg = "#89b4fa" },
    menubar_separator = { fg = "#585b70", bg = "#181825" },
  },

  -- Keymap overrides (merged on top of defaults)
  keymaps = {
    up        = { "k", "<Up>" },
    down      = { "j", "<Down>" },
    exec      = { "<CR>" },
    close     = { "<Esc>", "q" },
    submenu   = { "<Tab>", "<Right>" },  -- open submenu
    back      = { "<Left>" },            -- close submenu and return to parent
    menu_prev = { "h", "<Left>" },       -- menubar: move to previous menu
    menu_next = { "l" },                 -- menubar: move to next menu
    mouse     = { "<LeftMouse>" },
  },

  -- If true, start from an empty keymap set (only user-defined keys are active)
  disable_default_keymaps = false,

  -- List of top-level menu specs (see Menu Definition below)
  menus = { ... },
})
```

---

## Default Keybindings

| Action                        | Keys                         |
|-------------------------------|------------------------------|
| Move up                       | `k` / `<Up>`                 |
| Move down                     | `j` / `<Down>`               |
| Execute                       | `<CR>`                       |
| Close                         | `<Esc>` / `q`                |
| Open submenu                  | `<Tab>` / `<Right>`          |
| Close submenu / back to parent| `<Left>`                     |
| Menubar: previous menu        | `h` / `<Left>`               |
| Menubar: next menu            | `l`                          |
| Mouse click                   | `<LeftMouse>`                |
| Shortcut key                  | Character after `&` in name  |

---

## Menu Definition

### Top-level menu spec

Pass a list of specs to `setup()` via `menus`, or register dynamically with `require("quickui").menu_install()`.

```lua
{
  name       = "&File",        -- & marks the shortcut character
  priority   = 100,            -- display order, ascending left-to-right (default: 100)
  conditions = function(opt)   -- nil = always shown, false = hidden
    return true
  end,
  items = { ... },             -- item list, or function(opt) → list
}
```

Names prefixed with `&@` or `@` default to `priority = 10000` and are sorted to the far right.

### Item fields

```lua
items = {
  -- Basic item
  { name = "&Save", cmd = ":w<CR>", rtxt = "Ctrl-S" },

  -- Separator
  { name = "separator" },

  -- Submenu
  {
    name  = "&Recent",
    items = {
      { name = "file1.txt", cmd = ":e file1.txt<CR>" },
      { name = "file2.txt", cmd = ":e file2.txt<CR>" },
    },
  },

  -- Function command
  { name = "&Grep", cmd = function(opt)
    vim.ui.input({ prompt = "Pattern: " }, function(input)
      if input then vim.cmd("grep " .. input) end
    end)
  end },

  -- Conditional display
  { name = "Laravel &Artisan", cmd = ":!php artisan",
    conditions = function(opt)
      return vim.fn.filereadable("artisan") == 1
    end },

  -- Filetype filter (comma-separated)
  { name = "Validate &HTML", cmd = ":!tidy -errors %",
    ft = "html,xml" },

  -- Per-item highlight
  { name = "Danger Zone", cmd = "...", hl = "ErrorMsg" },
}
```

| Field        | Type               | Description                                                              |
|--------------|--------------------|--------------------------------------------------------------------------|
| `name`       | string             | Display name. `&X` sets the shortcut key. `%{expr}` is evaluated at open time. |
| `cmd`        | string \| function | Command to run. Strings are fed via `feedkeys`; functions receive `opt`. |
| `rtxt`       | string             | Right-aligned text (e.g. a shortcut hint).                               |
| `items`      | table              | Sub-item list — presence makes this item a submenu trigger.              |
| `conditions` | bool \| function   | `false` hides the item. Function receives `opt`, return `false` to hide. |
| `ft`         | string             | Comma-separated filetypes. Item is hidden when the current ft doesn't match. |
| `hl`         | string             | Highlight group applied to the item row.                                 |

The `opt` table passed to functions: `{ filetype, cwd, item, selection }`

---

## API

### `require("quickui").setup(opts)`

Initialize the plugin. See the Configuration Reference above for all options.

### `require("quickui").menu_install(spec)`

Register or replace a top-level menu at runtime. An existing menu with the same name is replaced.

```lua
require("quickui").menu_install({
  name  = "&Debug",
  items = { ... },
})
```

### `require("quickui").context_open(spec, opts)`

Open a context menu at the cursor position.

```lua
-- Plain item list
require("quickui").context_open({
  { name = "Copy",  cmd = '"+y' },
  { name = "Paste", cmd = '"+p' },
})

-- items field (supports a function for dynamic generation)
require("quickui").context_open({
  items = function(opt)
    return {
      { name = "Filetype: " .. opt.filetype, cmd = "" },
    }
  end,
}, { title = "Context" })
```

### `require("quickui").listbox_open(items, opts)`

Open a centered floating selection UI.

```lua
require("quickui").listbox_open({
  { name = "Option A", cmd = function() print("A") end },
  { name = "Option B", cmd = function() print("B") end },
}, { title = "Choose" })
```

---

## Context Menu Example

```lua
-- lua/plugins/quickui.lua
return {
  "mjmjm0101/quickui.nvim",
  lazy = false,
  config = function()
    require("quickui").setup({ ... })

    -- Normal mode: Tab opens a context menu
    vim.keymap.set("n", "<Tab>", function()
      require("quickui").context_open({
        { name = "&Format",      cmd = function() vim.lsp.buf.format() end },
        { name = "&Code Action", cmd = function() vim.lsp.buf.code_action() end },
        { name = "separator" },
        { name = "&Yank All",    cmd = ":%y+<CR>" },
      })
    end, { noremap = true, silent = true })

    -- Visual mode: Tab opens a context menu
    vim.keymap.set("v", "<Tab>", function()
      require("quickui").context_open({
        { name = "&Uppercase", cmd = "gU" },
        { name = "&Lowercase", cmd = "gu" },
      })
    end, { noremap = true, silent = true })
  end,
}
```

---

## Highlight Groups

| Group                      | Default link     | Target                               |
|----------------------------|------------------|--------------------------------------|
| `QuickUIMenubar`           | `StatusLine`     | Menubar background                   |
| `QuickUIMenubarSel`        | `PmenuSel`       | Selected menubar item                |
| `QuickUIMenubarSeparator`  | `NonText`        | Menubar separator character          |
| `QuickUIMenu`              | `Normal`         | Dropdown / popup background          |
| `QuickUIMenuBorder`        | `FloatBorder`    | Window border                        |
| `QuickUIMenuSel`           | `PmenuSel`       | Selected item row                    |
| `QuickUIMenuAccent`        | `Special`        | Shortcut character (after `&`)       |
| `QuickUIMenuRtxt`          | `Special`        | Right-aligned text (`rtxt` field)    |

---

## License

MIT
