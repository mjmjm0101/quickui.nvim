local M = {}

local bar   = require("quickui.bar")
local popup = require("quickui.popup")
local panel = require("quickui.menu_panel")
local hl    = require("quickui.highlight")

-- Registry: list of menus sorted by priority
local registry = {}

--- Setup quickui.nvim.
---
---@param opts table
---   keymap            string        Key to toggle the menubar (default: "<Space>")
---   border            string        Border style: "none"|"single"|"double"|"dotted"|"dashed"
---   winblend          number|table  Transparency 0-100. number = both, { bar=, menu= } = individual
---   highlights        table         Override highlight groups
---   suppress_all_keys boolean       Map all keys to <Nop> in plugin buffers to block global keymaps (default: true)
---   menus             table         List of menu spec tables. Each entry is a module that returns:
---                              { name=, priority=, conditions=, items= }
---                            title: menu title with & for shortcut
---                            priority: display order (lower = further left, default 100)
---                            conditions: function(opt)→bool or nil (always show)
---                            items: table or function(opt)→table
function M.setup(opts)
  opts = opts or {}

  hl.setup(opts.highlights)
  panel.setup(opts)
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
    local is_tail = name:match("^&@") or name:match("^@")
    priority = is_tail and 10000 or 100
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

  local opt = {
    item     = opts.item,
    filetype = vim.bo.filetype,
    cwd      = vim.fn.getcwd(),
  }

  local items
  if type(spec) == "table" and spec.items ~= nil then
    -- New format: { items = table|function(opt) }
    if type(spec.items) == "function" then
      items = spec.items(opt)
    else
      items = spec.items
    end
  else
    -- Plain array (backward compat)
    items = spec
  end

  local popup_opts = vim.tbl_extend("force", opts, { cursor = true })
  popup.open(items, popup_opts)
end

return M
