--- Shared vertical menu panel renderer.
--- Used by both the menubar dropdown/submenus and the popup context/listbox menus.
local M = {}
local util = require("quickui.util")

local mcfg = {
  submenu_icon = "›",
}

local ns_item = vim.api.nvim_create_namespace("quickui_item_hl")
local ns_acc  = vim.api.nvim_create_namespace("quickui_accent_hl")
local ns_sel  = vim.api.nvim_create_namespace("quickui_sel_hl")

-- Cursor visibility management when winblend is active (supports nested panels)
local cursor_hidden_count = 0
local saved_guicursor     = nil

local function hide_cursor()
  if cursor_hidden_count == 0 then
    saved_guicursor = vim.o.guicursor
    vim.api.nvim_set_hl(0, "QuickUICursorHidden", { blend = 100, nocombine = true })
    vim.o.guicursor = "a:QuickUICursorHidden"
  end
  cursor_hidden_count = cursor_hidden_count + 1
end

local function show_cursor()
  cursor_hidden_count = math.max(0, cursor_hidden_count - 1)
  if cursor_hidden_count == 0 and saved_guicursor then
    vim.o.guicursor = saved_guicursor
    saved_guicursor = nil
  end
end

function M.setup(opts)
  if opts.submenu_icon ~= nil then mcfg.submenu_icon = opts.submenu_icon end
end

-- ── line builder ──────────────────────────────────────────────────────────────

-- Returns lines, width, and rtxt_hl: array indexed by item position.
-- rtxt_hl[i] = { col, end_col } for right-text highlight, or nil.
local function build_lines(items, min_w)
  local max_w  = min_w or 10
  local widths = {}
  for i, item in ipairs(items) do
    if not item.separator then
      local dw = vim.fn.strdisplaywidth(item.display)
      local rw = item.right and vim.fn.strdisplaywidth(item.right) or 0
      widths[i] = { dw = dw, rw = rw }
      local w = dw + 2
      if item.right then w = w + rw + 2 end
      if w > max_w then max_w = w end
    end
  end

  local lines   = {}
  local rtxt_hl = {}
  for i, item in ipairs(items) do
    if item.separator then
      table.insert(lines, string.rep("─", max_w))
    elseif item.right then
      local l   = " " .. item.display
      local r   = item.right .. " "
      local w   = widths[i]
      local pad = max_w - (w.dw + 1) - (w.rw + 1)
      if pad < 1 then pad = 1 end
      if not item.submenu then
        local col = #l + pad
        rtxt_hl[i] = { col = col, end_col = col + #item.right }
      end
      table.insert(lines, l .. string.rep(" ", pad) .. r)
    else
      local l   = " " .. item.display
      local pad = max_w - (widths[i].dw + 1)
      if pad < 0 then pad = 0 end
      table.insert(lines, l .. string.rep(" ", pad))
    end
  end
  return lines, max_w, rtxt_hl
end

-- ── highlight helpers ─────────────────────────────────────────────────────────

local function apply_item_hl(buf, ns, items, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, item in ipairs(items) do
    if not item.separator and item.hl then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        end_col  = #lines[i],
        hl_group = item.hl,
        priority = 50,
      })
    end
  end
end

local function apply_accent_hl(buf, ns, items, rtxt_hl)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, item in ipairs(items) do
    if not item.separator then
      if item.shortcut_col then
        local c = 1 + item.shortcut_col
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, c, {
          end_col  = c + 1,
          hl_group = "QuickUIMenuAccent",
          hl_mode  = "combine",
          priority = 200,
        })
      end
      local rhl = rtxt_hl and rtxt_hl[i]
      if rhl then
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, rhl.col, {
          end_col  = rhl.end_col,
          hl_group = "QuickUIMenuRtxt",
          hl_mode  = "combine",
          priority = 200,
        })
      end
    end
  end
end

-- ── position calculator ───────────────────────────────────────────────────────

local function calc_pos(anchor, width, nlines, has_border)
  local bw = has_border and 2 or 0
  local bh = has_border and 1 or 0

  if anchor.cursor then
    local max_h = math.max(1, vim.o.lines - 2 - bh * 2)
    return "cursor", 1, 0, math.min(nlines, max_h)

  elseif anchor.placement == "right" then
    if not vim.api.nvim_win_is_valid(anchor.parent_win) then
      return "editor", 0, 0, math.min(nlines, math.max(1, vim.o.lines - bh * 2))
    end
    local ppos = vim.api.nvim_win_get_position(anchor.parent_win)
    local pw   = vim.api.nvim_win_get_width(anchor.parent_win)
    local row  = anchor.row or 0
    if row + nlines + bh * 2 > vim.o.lines then
      row = vim.o.lines - nlines - bh * 2
    end
    row = math.max(0, row)
    local col = ppos[2] + pw + bw
    if col + width + bw > vim.o.columns then
      col = math.max(0, ppos[2] - width - bw)
    end
    local max_h = math.max(1, vim.o.lines - row - bh * 2)
    return "editor", row, col, math.min(nlines, max_h)

  else  -- "below" / default: explicit row/col or centered
    local row = anchor.row or math.floor((vim.o.lines - nlines) / 2)
    local col = anchor.col or math.floor((vim.o.columns - width) / 2)
    if row + nlines + bh * 2 > vim.o.lines   then row = math.max(0, vim.o.lines   - nlines - bh * 2) end
    if col + width  + bw     > vim.o.columns  then col = math.max(0, vim.o.columns - width  - bw)     end
    local max_h = math.max(1, vim.o.lines - row - bh * 2)
    return "editor", row, col, math.min(nlines, max_h)
  end
end

-- ── item parser ───────────────────────────────────────────────────────────────

--- Parse a raw item list into display items, filtering by conditions and filetype.
---@param raw_items table
---@param opt       table|nil  { filetype, cwd }
function M.parse_items(raw_items, opt)
  opt = opt or { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local result = {}
  for _, raw in ipairs(raw_items) do
    if raw.items ~= nil then
      if util.item_conditions(raw, opt) then
        local p   = util.parse_label(raw.name)
        p.submenu = raw.items
        p.right   = mcfg.submenu_icon
        p.hl      = raw.hl
        table.insert(result, p)
      end
    elseif util.item_conditions(raw, opt) and util.ft_match(raw.ft, opt.filetype) then
      local p = util.parse_label(raw.name)
      if not p.separator then
        p.cmd = raw.cmd
        p.key = raw.key
        p.hl  = raw.hl
        -- rtxt display priority:
        --   rtxt explicitly set (non-empty) → show rtxt
        --   rtxt = ""                        → show nothing (overrides key)
        --   rtxt nil + key set               → show key as rtxt fallback
        if raw.rtxt ~= nil then
          if raw.rtxt ~= "" then p.right = util.parse_label(raw.rtxt).display end
        elseif raw.key ~= nil then
          p.right = raw.key
        end
      end
      table.insert(result, p)
    end
  end
  return result
end

-- ── panel open ────────────────────────────────────────────────────────────────

--- Open a vertical menu panel.
---
--- anchor fields:
---   cursor?     true → position relative to the text cursor (context menu)
---   placement?  "right" → open to the right of parent_win (submenu); default "below"
---   parent_win? window id; required for placement="right" (col source + focus restore)
---   row?        anchor row (editor-absolute); nil → centered vertically
---   col?        anchor col (editor-absolute); nil → centered horizontally
---
--- cfg fields:
---   border, winblend, zindex, keymaps, suppress_all_keys
---   title?          shown in border (root popup only)
---   min_width?      minimum content width
---   close_on_leave? auto-close when focus leaves (popup panels)
---   esc_closes_all? if true, km.close behaves like exec (calls on_exec to close the
---                   whole hierarchy). bar sets this; popup leaves it nil so Esc in a
---                   submenu pops only one level.
---
--- opt fields: { filetype, cwd } — filtering context passed to submenu parse_items
---
--- callbacks:
---   on_exec()          called after self-close when item is executed
---   on_close()         called when panel is closed via km.back / normal close
---   on_mouse_other(id) click outside panel window
---   on_no_submenu()    submenu key pressed but item has no submenu (bar: move next menu)
---
---@return table  { buf, close, close_silent, move, exec }
---         buf          = buffer handle (caller can bind extra keymaps)
---         close        = do_close(true)  triggers on_close callback
---         close_silent = do_close(false) no callback; used for parent-initiated closes
function M.open(items, anchor, cfg, opt, callbacks)
  callbacks = callbacks or {}
  opt       = opt or { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  if #items == 0 then
    local noop = function() end
    return { buf = nil, close = noop, close_silent = noop, move = noop, exec = noop }
  end

  local lines, width, rtxt_hl = build_lines(items, cfg.min_width or 0)
  local has_border   = cfg.border and cfg.border ~= "none"
  local relative, row, col, height = calc_pos(anchor, width, #lines, has_border)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"

  local win_opts = {
    relative  = relative,
    row       = row,
    col       = col,
    width     = width,
    height    = height,
    style     = "minimal",
    border    = util.resolve_border(cfg.border),
    focusable = true,
    zindex    = cfg.zindex or 250,
  }
  if cfg.title then
    win_opts.title     = " " .. cfg.title .. " "
    win_opts.title_pos = "center"
  end

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.wo[win].winhighlight = "Normal:QuickUIMenu,FloatBorder:QuickUIMenuBorder"
  vim.wo[win].winblend     = cfg.winblend or 0
  vim.wo[win].scrolloff    = 1

  local cursor_was_hidden = (cfg.winblend or 0) > 0
  if cursor_was_hidden then hide_cursor() end

  local nav_indices = {}
  local nav_pos     = {}
  for i, item in ipairs(items) do
    if not item.separator then
      nav_pos[i] = #nav_indices + 1
      table.insert(nav_indices, i)
    end
  end
  local idx = nav_indices[1] or 1

  local child_close = nil
  local closed      = false
  local au_group    = vim.api.nvim_create_augroup("quickui_panel_" .. tostring(buf), { clear = true })

  apply_item_hl(buf, ns_item, items, lines)
  apply_accent_hl(buf, ns_acc, items, rtxt_hl)

  local function hl()
    vim.api.nvim_buf_clear_namespace(buf, ns_sel, 0, -1)
    local item = items[idx]
    if item and not item.separator then
      vim.api.nvim_buf_set_extmark(buf, ns_sel, idx - 1, 0, {
        end_col  = #lines[idx],
        hl_group = "QuickUIMenuSel",
        priority = 100,
      })
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { idx, 0 })
      end
    end
  end
  hl()

  local function do_close(notify)
    if closed then return end
    closed = true
    if child_close then child_close(); child_close = nil end
    pcall(vim.api.nvim_del_augroup_by_id, au_group)
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    if cursor_was_hidden then show_cursor() end
    if anchor.parent_win and vim.api.nvim_win_is_valid(anchor.parent_win) then
      vim.api.nvim_set_current_win(anchor.parent_win)
    end
    if notify and callbacks.on_close then callbacks.on_close() end
  end

  local function move(dir)
    if child_close then child_close(); child_close = nil end
    local n = #nav_indices
    if n == 0 then return end
    local pos = nav_pos[idx] or 1
    idx = nav_indices[((pos - 1 + dir) % n) + 1]
    hl()
  end

  local open_child  -- forward declaration

  local function exec()
    local item = items[idx]
    if not item or item.separator then return end
    if item.submenu then open_child(); return end
    local cmd = item.cmd
    do_close(false)
    if callbacks.on_exec then callbacks.on_exec() end
    vim.schedule(function() util.exec(cmd, opt) end)
  end

  open_child = function()
    local item = items[idx]
    if not item or not item.submenu then
      if callbacks.on_no_submenu then callbacks.on_no_submenu() end
      return
    end
    if child_close then child_close(); child_close = nil end
    local ppos         = vim.api.nvim_win_get_position(win)
    local child_anchor = { row = ppos[1] + idx - 1, placement = "right", parent_win = win }
    local child_cfg = vim.tbl_extend("force", cfg, {
      zindex    = (cfg.zindex or 250) + 10,
      title     = nil,
      min_width = nil,
    })
    local child_cb = {
      on_exec        = callbacks.on_exec,
      on_close       = function() child_close = nil end,
      on_mouse_other = callbacks.on_mouse_other,
      bind_extra     = callbacks.bind_extra,
    }
    local child = M.open(M.parse_items(item.submenu, opt), child_anchor, child_cfg, opt, child_cb)
    child_close = child.close_silent
  end

  -- keymaps
  local km = cfg.keymaps
  local function kmap(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
  end
  local function bind(keys, fn)
    for _, k in ipairs(keys or {}) do kmap(k, fn) end
  end

  if cfg.suppress_all_keys then util.suppress_keys(buf) end

  bind(km.up,      function() move(-1) end)
  bind(km.down,    function() move(1)  end)
  bind(km.exec,    exec)
  bind(km.submenu,  open_child)
  bind(km.nav_next, open_child)
  bind(km.back,     function() do_close(true) end)
  bind(km.nav_prev, function()
    if callbacks.on_nav_prev then
      callbacks.on_nav_prev()
    else
      do_close(true)
    end
  end)
  bind(km.close, function()
    if cfg.esc_closes_all then
      do_close(false)
      if callbacks.on_exec then callbacks.on_exec() end
    else
      do_close(true)
    end
  end)
  if callbacks.bind_extra then callbacks.bind_extra(buf) end
  bind(km.mouse, function()
    local mpos = vim.fn.getmousepos()
    if mpos.winid == win then
      local r = mpos.line
      if items[r] and not items[r].separator then
        idx = r; hl(); exec()
      end
    elseif callbacks.on_mouse_other then
      callbacks.on_mouse_other(mpos.winid)
    end
  end)

  local sc_reserved = util.reserved_keys(km, { "up", "down", "exec", "close", "submenu", "back", "menu_prev", "menu_next", "nav_prev", "nav_next" })
  for i, item in ipairs(items) do
    if not item.separator then
      if item.shortcut then
        local sc    = item.shortcut
        local sc_up = sc:upper()
        local function do_exec() idx = i; hl(); exec() end
        if not sc_reserved[sc]                    then kmap(sc,    do_exec) end
        if sc_up ~= sc and not sc_reserved[sc_up] then kmap(sc_up, do_exec) end
      end
      if item.key then
        local function do_exec_key() idx = i; hl(); exec() end
        kmap(item.key, do_exec_key)
      end
    end
  end

  if cfg.close_on_leave then
    vim.api.nvim_create_autocmd("WinLeave", {
      buffer   = buf,
      group    = au_group,
      callback = function()
        vim.schedule(function()
          if child_close then return end
          if closed then return end
          do_close(true)
        end)
      end,
    })
  end

  return {
    buf          = buf,
    close        = function() do_close(true)  end,
    close_silent = function() do_close(false) end,
    move         = move,
    exec         = exec,
  }
end

return M
