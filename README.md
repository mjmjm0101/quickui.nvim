# quickui.nvim

> It provides a UI — but the goal isn't UI.
> It's about managing the cognitive load of your own Neovim setup, so nothing gets lost.

Lightweight, keyboard-friendly TUI-style menus for Neovim (menubar + context menus)

- **Menubar** — a non-focusable title strip at the top of the editor with a dropdown that opens below the selected title
- **Context menus** — floating popups positioned at the cursor (normal and visual mode)
- Nested submenus (multi-level)
- Per-item conditions (`conditions`) and filetype filters (`ft`)
- Fully configurable keybindings
- Global keybindings are suppressed inside quickui buffers by default (configurable via `suppress_all_keys`)
- [Fuzzy finder integration (Telescope, fzf-lua, snacks, mini.pick)](#fuzzy-finder-integration)

This plugin provides similar functionality to [skywind3000/vim-quickui](https://github.com/skywind3000/vim-quickui) and [nvzone/menu](https://github.com/nvzone/menu). Both were a great source of inspiration, and I'm grateful to their authors.

---

## Requirements

- Neovim 0.10+

---


## Demo

### Menubar

Menubar with nested submenus:

![Menubar demo](https://github.com/user-attachments/assets/89e5229e-65c6-4f5b-978f-0d37ec69e0bb)

### Context Menu

Context menu at cursor position:

![Context menu demo](https://github.com/user-attachments/assets/05e99d4f-959b-4ec5-ad62-4de233f86a2a)

## 🧠 Why quickui.nvim?

Modern Neovim setups often include dozens of plugins,
but their commands and keybindings are fragmented and hard to manage.

quickui.nvim provides a structured UI — not for recalling or searching,
but for organizing your tools by meaning.

Search-based workflows work well when you already remember what exists.
But for infrequent actions, what matters more is having a structure you can navigate.

Do you have plugins that seemed useful when you installed them,
but ended up unused because you couldn’t remember how to use them?

quickui.nvim makes those features accessible again by turning them into something you can navigate.

It complements the traditional “memorize commands” workflow
by adding a new approach: organizing capabilities.

As a result, your menus can act as a portable UI layer — staying consistent
even when switching between setups like LazyVim, NvChad, or your own config.

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
        { name = "&New",   cmd = ":enew<CR>", key = "<C-n>" },
        { name = "&Open",  cmd = ":e ",       key = "<C-o>" },
        { name = "&Save",  cmd = ":w<CR>",    key = "<C-s>" },
        { name = "separator" },
        { name = "&Quit",  cmd = ":qa<CR>",   key = "<C-q>", rtxt = "Ctrl-q" },
      },
    },
    {
      name  = "&Edit",
      items = {
        { name = "&Undo",  cmd = "u",      key = "<C-z>" },
        { name = "&Redo",  cmd = "<C-r>",  key = "<C-y>", rtxt = "Ctrl-y" },
        { name = "&Copy",  cmd = '"+y',    key = "<C-c>" },
        { name = "&Paste", cmd = '"+p',    key = "<C-v>" },
      },
    },
  },
})
```

or Sample Settings

```lua
require("quickui-sample")
```

The sample includes:
- `context/normal.lua` — normal-mode context menu (LSP, diagnostics, edit, filetype-specific items)
- `context/visual.lua` — visual-mode context menu (case conversion, clipboard, indent, sort, LSP range)
- `context/snacks_explorer.lua` — context menu for [snacks.nvim](https://github.com/folke/snacks.nvim) explorer (open, new, rename, delete, copy path); see the file header for setup instructions

---

## Configuration Reference

```lua
require("quickui").setup({

  -- Key to toggle the menubar (default: "<Space>")
  keymap = "<Space>",

  -- Border style: "none" | "single" | "double" | "rounded" | "dotted" | "dashed"
  -- Note: "none" hides border characters but still reserves their cell width
  -- to prevent layout shifts. Zero-thickness borders are not supported.
  border = "single",

  -- Transparency 0-100. number = both bar and menu, table = individual
  -- Defaults: bar = 0, menu = 40
  winblend = { bar = 0, menu = 40 },

  -- Number of padding spaces on each side of a menubar item (default: 1)
  menubar_padding = 2,

  -- Separator character between menubar items. "" to disable (default: "│")
  menubar_separator = "│",

  -- Icon displayed at the right edge of a submenu item (default: "›")
  submenu_icon = "›",

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
    back      = { "<Left>", "<BS>", "<S-Tab>" }, -- close submenu and return to parent
    menu_prev = { "h" },                 -- menubar: move to previous menu
    menu_next = { "l" },                 -- menubar: move to next menu
    mouse     = { "<LeftMouse>" },
  },

  -- If true, start from an empty keymap set (only user-defined keys are active)
  disable_default_keymaps = false,

  -- When true (default), map all keys to <Nop> in plugin buffers to block
  -- global keymaps. Set to false to leave global keymaps untouched.
  suppress_all_keys = true,

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
| Close submenu / back to parent| `<Left>` / `<BS>` / `<S-Tab>` |
| Menubar: previous menu        | `h`                          |
| Menubar: next menu            | `l`                          |
| Mouse click                   | `<LeftMouse>`                |
| Shortcut key (`&`)            | Character after `&` in name  |
| Shortcut key (`key`)          | Value of the `key` item field |

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
  -- key only: "<C-s>" is shown as the right-aligned hint and triggers the item
  { name = "&Save",  cmd = ":w<CR>",  key = "<C-s>" },

  -- rtxt overrides key display (key still works as a binding)
  { name = "&Save As...", cmd = ":saveas ", key = "<C-shift-s>", rtxt = "Ctrl-Shift-S" },

  -- rtxt="" suppresses display; key is still active
  { name = "&Close", cmd = ":bd<CR>", key = "<C-w>", rtxt = "" },

  -- rtxt only: display hint with no in-menu keybinding
  { name = "&Redo",  cmd = "<C-r>",   rtxt = "Ctrl-R" },

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
| `key`        | string             | Keybinding active while the menu is open (e.g. `"<C-s>"`). Also used as the right-aligned hint text when `rtxt` is not specified. |
| `rtxt`       | string             | Right-aligned text. Overrides `key` display when specified. Set to `""` to suppress display even if `key` is set. Supports `%{expr}` evaluation (same as `name`). |
| `items`      | table              | Sub-item list — presence makes this item a submenu trigger.              |
| `conditions` | bool \| function   | `false` hides the item. Function receives `opt`, return `false` to hide. |
| `ft`         | string             | Comma-separated filetypes. Item is hidden when the current ft doesn't match. |
| `hl`         | string             | Highlight group applied to the item row.                                 |

The `opt` table passed to `cmd` and `conditions` functions:

| Key         | Type       | Always present | Description                                                          |
|-------------|------------|----------------|----------------------------------------------------------------------|
| `filetype`  | string     | ✓              | `vim.bo.filetype` at the time the menu was opened                    |
| `cwd`       | string     | ✓              | `vim.fn.getcwd()` at the time the menu was opened                    |
| `selection` | table\|nil | context_visual only | Visual selection: `{ text, lines, mode }`                       |
| _…data_     | any        | when provided  | All fields from the `data` argument of `context_normal` / `context_visual` |

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

### `require("quickui").context_normal(spec, data)`

Open a context menu at the cursor position (normal mode).

```lua
-- Plain item list
require("quickui").context_normal({
  { name = "Copy",  cmd = '"+y' },
  { name = "Paste", cmd = '"+p' },
})

-- items as a function (dynamic generation)
require("quickui").context_normal({
  items = function(opt)
    return {
      { name = "Filetype: " .. opt.filetype, cmd = "" },
    }
  end,
})

-- Pass arbitrary data through to cmd functions
require("quickui").context_normal(ctx, { target = some_item })
-- cmd = function(opt)  →  opt.target == some_item
```

### `require("quickui").context_visual(spec, data)`

Open a context menu at the cursor position (visual mode).
The visual selection is highlighted while the menu is open.
`opt.selection` is set automatically.

```lua
require("quickui").context_visual({
  items = function(opt)
    return {
      { name = "Selection: " .. opt.selection.text, cmd = "" },
      { name = "&Uppercase", cmd = function(opt)
          -- opt.selection.text  — selected text (joined with \n)
          -- opt.selection.lines — table of selected lines
          -- opt.selection.mode  — "v" | "V" | "\22" (block)
        end },
    }
  end,
})
```

---

## Context Menu Example

```lua
-- lua/plugins/quickui.lua
local quickui = require("quickui")

local ctx = {
  items = function(opt)
    return {
      { name = "&Format",      cmd = function() vim.lsp.buf.format() end },
      { name = "&Code Action", cmd = function() vim.lsp.buf.code_action() end },
      { name = "separator" },
      { name = "&Yank All",    cmd = ":%y+<CR>" },
      -- shown only from context_visual
      -- shown only from context_visual (gv re-enters the last visual selection)
      { name = "&Uppercase",   cmd = "gvU",
        conditions = function(opt) return opt.selection ~= nil end },
      { name = "&Lowercase",   cmd = "gvu",
        conditions = function(opt) return opt.selection ~= nil end },
    }
  end,
}

-- Normal mode
vim.keymap.set("n", "<Tab>", function()
  quickui.context_normal(ctx)
end, { noremap = true, silent = true })

-- Visual mode (selection is highlighted; opt.selection is set automatically)
vim.keymap.set("x", "<Tab>", function()
  quickui.context_visual(ctx)
end, { noremap = true, silent = true })
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
| `QuickUIVisualSel`         | `Visual`         | Visual selection overlay (context_visual) |

---

## Fuzzy Finder Integration

quickui.nvim menus can be exposed as searchable data,
making it possible to use fuzzy finders as an entry point to your structured UI.

Instead of relying only on remembering commands or guessing search terms,
you can search within your own curated structure.

Search results reflect your menu hierarchy and naming,
so you can find actions based on how you think about them — not how plugins name them.

- [telescope-quickui.nvim](https://github.com/mjmjm0101/telescope-quickui.nvim)
- [fzf-lua-quickui.nvim](https://github.com/mjmjm0101/fzf-lua-quickui.nvim)
- [snacks-picker-quickui.nvim](https://github.com/mjmjm0101/snacks-picker-quickui.nvim)
- [mini-pick-quickui.nvim](https://github.com/mjmjm0101/mini-pick-quickui.nvim)

## License

MIT
