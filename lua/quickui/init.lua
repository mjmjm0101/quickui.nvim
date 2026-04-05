local M = {}

local bar     = require("quickui.bar")
local popup   = require("quickui.popup")
local hl      = require("quickui.highlight")

-- Registry: list of menus sorted by priority
local registry = {}

--- Setup quickui.nvim.
---
---@param opts table
---   keymap     string        Key to toggle the menubar (default: "<Space>")
---   border     string        Border style: "none"|"single"|"double"|"dotted"|"dashed"
---   winblend   number|table  Transparency 0-100. number = both, { bar=, menu= } = individual
---   highlights table         Override highlight groups
---   menus      table         List of menu spec tables. Each entry is a module that returns:
---                              { name=, priority=, conditions=, items= }
---                            title: menu title with & for shortcut
---                            priority: display order (lower = further left, default 100)
---                            conditions: function(opt)→bool or nil (always show)
---                            items: table or function(opt)→table
function M.setup(opts)
  opts = opts or {}

  hl.setup(opts.highlights)
  bar.setup(opts)
  popup.setup(opts)

  for _, spec in ipairs(opts.menus or {}) do
    if spec.name then
      M.menu_install(spec)
    end
  end

  local key = opts.keymap or "<Space>"
  vim.keymap.set("n", key, function()
    bar.toggle(registry)
  end, { noremap = true, silent = true, desc = "Toggle QuickUI menubar" })
end

--- Register a top-level menu from a spec table.
---
---@param spec table  { title=, priority=, conditions=, items= }
function M.menu_install(spec)
  local name     = spec.name
  local priority = spec.priority

  if not priority then
    -- @-prefix means "sort to end" (e.g. "&@Help")
    priority = (name:match("^&@") or name:match("^@")) and 10000 or 100
  end

  -- Remove any existing menu with the same name
  for i, m in ipairs(registry) do
    if m.name == name then
      table.remove(registry, i)
      break
    end
  end

  table.insert(registry, {
    name       = name,
    items      = spec.items,
    priority   = priority,
    conditions = spec.conditions,
  })

  table.sort(registry, function(a, b)
    return (a.priority or 100) < (b.priority or 100)
  end)
end

--- Open a context menu at the cursor position.
---
---@param spec  table  Plain items array, or { items = table|function(opt) }
---@param opts  table  Optional: { title?, width?, item? }
---                    item: caller-supplied context (e.g. snacks picker item)
function M.context_open(spec, opts)
  opts = opts or {}
  local opt   = { item = opts.item, filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local items
  if type(spec) == "table" and spec.items ~= nil then
    -- New format: { items = table|function(opt) }
    items = type(spec.items) == "function" and spec.items(opt) or spec.items
  else
    -- Plain array (backward compat)
    items = spec
  end
  popup.open(items, vim.tbl_extend("force", opts, { cursor = true }))
end

--- Open a listbox (centered floating window with optional title).
---
---@param items table  Same format as menu items
---@param opts  table  Optional: { title?, width?, row?, col? }
function M.listbox_open(items, opts)
  popup.open(items, opts or {})
end

return M
