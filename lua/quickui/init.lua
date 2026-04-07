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
---                            name: menu title with & for shortcut
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
---@param spec table  { name=, priority=, conditions=, items= }
function M.menu_install(spec)
  local name     = spec.name
  local priority = spec.priority

  if not priority then
    local is_tail = name:match("^&@") or name:match("^@")
    priority = is_tail and 10000 or 100
  end

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

-- ── helpers ───────────────────────────────────────────────────────────────────

--- Resolve items from a spec { items = table|function }.
---@param spec table
---@param opt  table
---@return table
local function resolve_items(spec, opt)
  if type(spec.items) == "function" then
    return spec.items(opt)
  end
  return spec.items
end

-- ── visual selection highlight ────────────────────────────────────────────────

--- Capture visual selection positions while still in visual mode.
--- Must be called before the float window steals focus.
---@return table|nil  { vmode, srow, scol, erow, ecol }
local function capture_visual_pos()
  local mode      = vim.fn.mode()
  local in_visual = mode == "v" or mode == "V" or mode == "\22"

  local vmode, p1, p2
  if in_visual then
    vmode = mode
    p1    = vim.fn.getpos("v")
    p2    = vim.fn.getpos(".")
    if p1[2] > p2[2] or (p1[2] == p2[2] and p1[3] > p2[3]) then
      p1, p2 = p2, p1
    end
  else
    vmode = vim.fn.visualmode()
    p1    = vim.fn.getpos("'<")
    p2    = vim.fn.getpos("'>")
  end

  if p1[2] == 0 or p2[2] == 0 then return nil end
  return {
    vmode = vmode,
    srow  = p1[2] - 1,
    scol  = p1[3] - 1,
    erow  = p2[2] - 1,
    ecol  = p2[3] - 1,
  }
end

--- Build a selection table from a captured position snapshot.
--- Uses vim.fn.getregion (Neovim 0.10+).
---@param cap table  result of capture_visual_pos()
---@return table  { mode, lines, text }
local function build_selection(cap)
  local p1    = { 0, cap.srow + 1, cap.scol + 1, 0 }
  local p2    = { 0, cap.erow + 1, cap.ecol + 1, 0 }
  local lines = vim.fn.getregion(p1, p2, { type = cap.vmode })
  return {
    mode  = cap.vmode,
    lines = lines,
    text  = table.concat(lines, "\n"),
  }
end

--- Apply QuickUIVisualSel extmarks from a captured position snapshot.
---@param src_buf integer
---@param cap     table   result of capture_visual_pos()
---@return integer  ns
local function apply_visual_hl(src_buf, cap)
  local ns    = vim.api.nvim_create_namespace("quickui_vis_sel")
  local vmode = cap.vmode
  local srow, scol = cap.srow, cap.scol
  local erow, ecol = cap.erow, cap.ecol

  local function line_len(r)
    return #(vim.api.nvim_buf_get_lines(src_buf, r, r + 1, false)[1] or "")
  end

  local function mark_with_eol(r, cs)
    vim.api.nvim_buf_set_extmark(src_buf, ns, r, cs, {
      end_row  = r,
      end_col  = line_len(r) + 1,
      hl_group = "QuickUIVisualSel",
      hl_mode  = "combine",
      priority = 200,
      strict   = false,
    })
  end

  if vmode == "V" then
    for r = srow, erow do
      mark_with_eol(r, 0)
    end

  elseif vmode == "\22" then
    local cs = math.min(scol, ecol)
    local ce = math.max(scol, ecol) + 1
    for r = srow, erow do
      local safe_ce = math.min(ce, line_len(r))
      if cs < safe_ce then
        vim.api.nvim_buf_set_extmark(src_buf, ns, r, cs, {
          end_row  = r,
          end_col  = safe_ce,
          hl_group = "QuickUIVisualSel",
          hl_mode  = "combine",
          priority = 200,
        })
      end
    end

  else  -- char-wise
    for r = srow, erow do
      local cs      = (r == srow) and scol or 0
      local is_last = (r == erow)
      if is_last then
        local ce = math.min(ecol + 1, line_len(r))
        if cs < ce then
          vim.api.nvim_buf_set_extmark(src_buf, ns, r, cs, {
            end_row  = r,
            end_col  = ce,
            hl_group = "QuickUIVisualSel",
            hl_mode  = "combine",
            priority = 200,
          })
        end
      else
        mark_with_eol(r, cs)
      end
    end
  end

  return ns
end

-- ── context menus ─────────────────────────────────────────────────────────────

--- Open a context menu from normal mode.
---
--- `data` is merged into `opt`, which is passed to both `cmd` and `conditions`
--- functions.  Built-in keys added automatically: `filetype`, `cwd`.
---
---@param spec  table         { items = table|function(opt) }
---@param data  table|nil     Arbitrary context; merged into opt for cmd and conditions
function M.context_normal(spec, data)
  local opt = vim.tbl_extend("force",
    { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() },
    data or {}
  )
  popup.open(resolve_items(spec, opt), { cursor = true }, opt)
end

--- Open a context menu from visual mode.
--- Highlights the selection while the menu is open.
--- `data` is merged into `opt`, which is passed to both `cmd` and `conditions`
--- functions.  `opt.selection` is set automatically: { mode, lines, text }.
---
---@param spec  table         { items = table|function(opt) }
---@param data  table|nil     Arbitrary context passed through to cmd functions
function M.context_visual(spec, data)
  local src_buf = vim.api.nvim_get_current_buf()
  local vis_cap = capture_visual_pos()

  local opt = vim.tbl_extend("force",
    {
      filetype  = vim.bo.filetype,
      cwd       = vim.fn.getcwd(),
      selection = vis_cap and build_selection(vis_cap) or nil,
    },
    data or {}
  )

  local vis_ns = nil
  if vis_cap then
    vis_ns = apply_visual_hl(src_buf, vis_cap)
  end

  popup.open(resolve_items(spec, opt), { cursor = true }, opt,
    vis_ns and function()
      vim.api.nvim_buf_clear_namespace(src_buf, vis_ns, 0, -1)
    end or nil
  )
end

return M
