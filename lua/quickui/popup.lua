--- Shared floating window used by both context_open() and listbox_open().
local M = {}
local util = require("quickui.util")

local cfg   = { border = "single", winblend = 0, keymaps = vim.deepcopy(util.default_keymaps) }
local ns_sc = vim.api.nvim_create_namespace("quickui_popup_sc")
local ns_hl = vim.api.nvim_create_namespace("quickui_popup_hl")

local function keymap(buf, key, fn)
  vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
end

-- ── shared highlight helpers ──────────────────────────────────────────────────

local function apply_item_hl(buf, parsed)
  vim.api.nvim_buf_clear_namespace(buf, ns_hl, 0, -1)
  for i, item in ipairs(parsed) do
    if not item.separator and item.hl then
      local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1] or ""
      vim.api.nvim_buf_set_extmark(buf, ns_hl, i - 1, 0, {
        end_col  = #line,
        hl_group = item.hl,
        priority = 50,
      })
    end
  end
end

local function apply_accent_hl(buf, parsed)
  vim.api.nvim_buf_clear_namespace(buf, ns_sc, 0, -1)
  for i, item in ipairs(parsed) do
    if not item.separator then
      if item.shortcut_col then
        local c = 1 + item.shortcut_col
        vim.api.nvim_buf_set_extmark(buf, ns_sc, i - 1, c, {
          end_col  = c + 1,
          hl_group = "QuickUIMenuAccent",
          hl_mode  = "combine",
          priority = 200,
        })
      end
      if item.right_hl_col then
        vim.api.nvim_buf_set_extmark(buf, ns_sc, i - 1, item.right_hl_col, {
          end_col  = item.right_hl_end,
          hl_group = "QuickUIMenuRtxt",
          hl_mode  = "combine",
          priority = 200,
        })
      end
    end
  end
end

-- ── item parser ───────────────────────────────────────────────────────────────

--- Parse a raw item list into display items.
--- Respects item-level conditions and ft filters.
---@param raw_items  table
---@param opt        table|nil  { filetype, cwd }
local function parse_items(raw_items, opt)
  opt = opt or { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local parsed = {}
  for _, raw in ipairs(raw_items) do
    if util.item_label(raw) == "separator" then
      table.insert(parsed, { separator = true })
    elseif util.item_conditions(raw, opt) and util.ft_match(util.item_ft(raw)) then
      local p   = util.parse_label(util.item_label(raw))
      p.cmd     = util.item_cmd(raw)
      p.right   = util.item_rtxt(raw)
      p.hl      = util.item_hl(raw)
      p.submenu = type(raw.items) == "table" and raw.items or nil
      if p.submenu then
        p.right        = "›"
        p.right_hl_col = nil
      elseif not p.shortcut and p.right and p.right ~= "" then
        p.shortcut = p.right:sub(1, 1):lower()
      end
      table.insert(parsed, p)
    end
  end
  return parsed
end

-- ── line builder ──────────────────────────────────────────────────────────────

local function build_lines(parsed, min_w)
  local max_w = min_w or 10
  for _, item in ipairs(parsed) do
    if not item.separator then
      local w = vim.fn.strdisplaywidth(item.display) + 2
      if item.right then w = w + vim.fn.strdisplaywidth(item.right) + 2 end
      if w > max_w then max_w = w end
    end
  end

  local lines = {}
  for _, item in ipairs(parsed) do
    if item.separator then
      table.insert(lines, string.rep("─", max_w))
    elseif item.right then
      local l   = " " .. item.display
      local r   = item.right .. " "
      local pad = max_w - vim.fn.strdisplaywidth(l) - vim.fn.strdisplaywidth(r)
      if pad < 1 then pad = 1 end
      if not item.submenu then
        item.right_hl_col = #l + pad
        item.right_hl_end = item.right_hl_col + #item.right
      end
      table.insert(lines, l .. string.rep(" ", pad) .. r)
    else
      local l   = " " .. item.display
      local pad = max_w - vim.fn.strdisplaywidth(l)
      if pad < 0 then pad = 0 end
      item.right_hl_col = nil
      table.insert(lines, l .. string.rep(" ", pad))
    end
  end
  return lines, max_w
end

-- ── submenu (forward declaration) ────────────────────────────────────────────

local open_submenu

-- ── main open ─────────────────────────────────────────────────────────────────

--- Open a popup window.
---@param items  table   List of items ({ name=, cmd= } etc.)
---@param opts   table   { title?, width?, cursor?, row?, col? }
---   cursor = true  → position just below the cursor (for context menus)
---   row/col        → explicit editor-relative position (for listbox)
---   title          → shown in the border
function M.open(items, opts)
  opts = opts or {}

  local opt    = { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local parsed = parse_items(items, opt)
  if #parsed == 0 then return end

  local title_w = opts.title and (vim.fn.strdisplaywidth(opts.title) + 4) or 0
  local lines, width = build_lines(parsed, math.max(opts.width or 0, title_w))

  -- Decide window position
  local relative, row, col
  if opts.cursor then
    relative = "cursor"
    row      = 1
    col      = 0
  else
    relative = "editor"
    row      = opts.row or math.floor((vim.o.lines - #lines) / 2)
    col      = opts.col or math.floor((vim.o.columns - width) / 2)
  end

  -- Clamp to screen when editor-relative
  if relative == "editor" then
    if row + #lines + 2 > vim.o.lines   then row = math.max(0, vim.o.lines   - #lines - 2) end
    if col + width + 2  > vim.o.columns then col = math.max(0, vim.o.columns - width  - 2) end
  end

  -- Limit height so the window fits on screen (allow scrolling inside)
  local has_bord = cfg.border and cfg.border ~= "none"
  local bh       = has_bord and 1 or 0
  local base_row = (relative == "editor") and row or 2  -- conservative estimate for cursor
  local max_h    = math.max(1, vim.o.lines - base_row - bh * 2)
  local height   = math.min(#lines, max_h)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"

  local win_cfg = {
    relative  = relative,
    row       = row,
    col       = col,
    width     = width,
    height    = height,
    style     = "minimal",
    border    = util.resolve_border(cfg.border),
    focusable = true,
    zindex    = 250,
  }
  if opts.title then
    win_cfg.title     = " " .. opts.title .. " "
    win_cfg.title_pos = "center"
  end

  local win      = vim.api.nvim_open_win(buf, true, win_cfg)
  local prev_win = vim.api.nvim_get_current_win()
  vim.wo[win].winhighlight = "Normal:QuickUIMenu,FloatBorder:QuickUIMenuBorder"
  vim.wo[win].winblend     = cfg.winblend
  vim.wo[win].scrolloff    = 1

  -- カーソル非表示
  local saved_guicursor      = vim.o.guicursor
  local cursor_hidden_escape = false
  if vim.fn.has("gui_running") == 1 or vim.o.termguicolors then
    vim.api.nvim_set_hl(0, "QuickUICursorHidden", { blend = 100, nocombine = true })
    vim.o.guicursor = "a:block-QuickUICursorHidden/lCursor"
  else
    io.write("\27[?25l")
    io.flush()
    cursor_hidden_escape = true
  end

  local function restore_cursor()
    if cursor_hidden_escape then
      io.write("\27[?25h")
      io.flush()
    else
      vim.o.guicursor = saved_guicursor
    end
  end

  -- ── selection state ──────────────────────────────────────────────────────
  local idx       = 1
  for i, item in ipairs(parsed) do
    if not item.separator then idx = i; break end
  end

  local child_close = nil
  local ns_sel      = vim.api.nvim_create_namespace("quickui_popup_sel_" .. tostring(buf))
  local au_group    = vim.api.nvim_create_augroup("quickui_popup_" .. tostring(buf), { clear = true })

  local function hl()
    vim.api.nvim_buf_clear_namespace(buf, ns_sel, 0, -1)
    apply_item_hl(buf, parsed)
    local item = parsed[idx]
    if item and not item.separator then
      local r    = idx - 1
      local line = vim.api.nvim_buf_get_lines(buf, r, r + 1, false)[1] or ""
      vim.api.nvim_buf_set_extmark(buf, ns_sel, r, 0, {
        end_col  = #line,
        hl_group = "QuickUIMenuSel",
        priority = 100,
      })
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { idx, 0 })
      end
    end
    apply_accent_hl(buf, parsed)
  end
  hl()

  local function move(dir)
    if child_close then child_close(); child_close = nil end
    local n     = #parsed
    local next  = idx + dir
    if next < 1 then next = n end
    if next > n then next = 1 end
    local tries = 0
    while parsed[next] and parsed[next].separator and tries < n do
      next = next + dir
      if next < 1 then next = n end
      if next > n then next = 1 end
      tries = tries + 1
    end
    idx = next
    hl()
  end

  local function close()
    if child_close then child_close(); child_close = nil end
    pcall(vim.api.nvim_del_augroup_by_id, au_group)
    restore_cursor()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    if prev_win and vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
  end

  local function open_child()
    local item = parsed[idx]
    if not item or not item.submenu then return end
    if child_close then child_close(); child_close = nil end
    child_close = open_submenu(win, item.submenu, 260, idx, opt, close, function()
      child_close = nil
    end)
  end

  local function exec()
    local item = parsed[idx]
    if not item or item.separator then return end
    if item.submenu then open_child(); return end
    local cmd = item.cmd
    close()
    vim.schedule(function() util.exec(cmd) end)
  end

  -- ── keymaps ──────────────────────────────────────────────────────────────
  local km = cfg.keymaps
  local function kmap(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
  end
  local function bind(keys, fn)
    for _, k in ipairs(keys or {}) do kmap(k, fn) end
  end

  util.suppress_keys(buf)

  bind(km.up,      function() move(-1) end)
  bind(km.down,    function() move(1)  end)
  bind(km.exec,    exec)
  bind(km.submenu, open_child)
  bind(km.close,   close)
  bind(km.mouse, function()
    local mpos = vim.fn.getmousepos()
    if mpos.winid ~= win then return end
    local r = mpos.line
    if parsed[r] and not parsed[r].separator then
      idx = r
      hl()
      exec()
    end
  end)

  -- Shortcut keys (both lower and upper)
  local sc_reserved = util.reserved_keys(km, { "up", "down", "exec", "close", "submenu" })
  for i, item in ipairs(parsed) do
    if not item.separator and item.shortcut then
      local sc    = item.shortcut
      local sc_up = sc:upper()
      local function do_exec() idx = i; exec() end
      if not sc_reserved[sc]                    then kmap(sc,    do_exec) end
      if sc_up ~= sc and not sc_reserved[sc_up] then kmap(sc_up, do_exec) end
    end
  end

  -- Close automatically if focus leaves (skip while submenu is open)
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer   = buf,
    group    = au_group,
    callback = function()
      vim.schedule(function()
        if child_close then return end
        restore_cursor()
        pcall(vim.api.nvim_win_close, win, true)
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        pcall(vim.api.nvim_del_augroup_by_id, au_group)
      end)
    end,
  })
end

-- ── submenu implementation ────────────────────────────────────────────────────

--- Open a submenu popup to the right of parent_win.
---
---@param parent_win       number    The window the submenu hangs off of
---@param raw_items        table     Raw item list
---@param zindex           number    z-index for the new window
---@param parent_item_idx  number    1-based index of the triggering parent item
---@param opt              table     { filetype, cwd } for conditions/ft
---@param on_exec          function  Called when item is executed (closes entire chain)
---@param on_close         function  Called when this submenu closes via Esc/Left
---@return function  close function
open_submenu = function(parent_win, raw_items, zindex, parent_item_idx, opt, on_exec, on_close)
  opt = opt or { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local parsed = parse_items(raw_items, opt)
  if #parsed == 0 then return function() end end

  local lines, width = build_lines(parsed, 0)

  -- Position: align first submenu item with parent's triggering item
  local ppos     = vim.api.nvim_win_get_position(parent_win)
  local pw       = vim.api.nvim_win_get_width(parent_win)
  local has_bord = cfg.border and cfg.border ~= "none"
  local bw       = has_bord and 2 or 0
  local bh       = has_bord and 1 or 0

  local row = ppos[1] + (parent_item_idx or 1) - 1
  if row + #lines + bh * 2 > vim.o.lines then
    row = vim.o.lines - #lines - bh * 2
  end
  row = math.max(0, row)

  -- Column: prefer right of parent, flip left if not enough room
  local col = ppos[2] + pw + bw
  if col + width + bw > vim.o.columns then
    col = math.max(0, ppos[2] - width - bw)
  end

  -- Limit height
  local max_h  = math.max(1, vim.o.lines - row - bh * 2)
  local height = math.min(#lines, max_h)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    row       = row,
    col       = col,
    width     = width,
    height    = height,
    style     = "minimal",
    border    = util.resolve_border(cfg.border),
    focusable = true,
    zindex    = zindex,
  })
  vim.wo[win].winhighlight = "Normal:QuickUIMenu,FloatBorder:QuickUIMenuBorder"
  vim.wo[win].winblend     = cfg.winblend
  vim.wo[win].scrolloff    = 1

  local idx       = 1
  for i, item in ipairs(parsed) do
    if not item.separator then idx = i; break end
  end

  local child_close = nil
  local closed      = false
  local ns_sel      = vim.api.nvim_create_namespace("quickui_popup_sub_" .. tostring(buf))
  local au_group    = vim.api.nvim_create_augroup("quickui_popup_sub_" .. tostring(buf), { clear = true })

  local function hl()
    vim.api.nvim_buf_clear_namespace(buf, ns_sel, 0, -1)
    apply_item_hl(buf, parsed)
    local item = parsed[idx]
    if item and not item.separator then
      local r    = idx - 1
      local line = vim.api.nvim_buf_get_lines(buf, r, r + 1, false)[1] or ""
      vim.api.nvim_buf_set_extmark(buf, ns_sel, r, 0, {
        end_col  = #line,
        hl_group = "QuickUIMenuSel",
        priority = 100,
      })
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { idx, 0 })
      end
    end
    apply_accent_hl(buf, parsed)
  end
  hl()

  local function do_close(notify)
    if closed then return end
    closed = true
    if child_close then child_close(); child_close = nil end
    pcall(vim.api.nvim_del_augroup_by_id, au_group)
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    if vim.api.nvim_win_is_valid(parent_win) then
      vim.api.nvim_set_current_win(parent_win)
    end
    if notify and on_close then on_close() end
  end

  local function move(dir)
    if child_close then child_close(); child_close = nil end
    local n     = #parsed
    local next  = idx + dir
    if next < 1 then next = n end
    if next > n then next = 1 end
    local tries = 0
    while parsed[next] and parsed[next].separator and tries < n do
      next = next + dir
      if next < 1 then next = n end
      if next > n then next = 1 end
      tries = tries + 1
    end
    idx = next
    hl()
  end

  local function open_child()
    local item = parsed[idx]
    if not item or not item.submenu then return end
    if child_close then child_close(); child_close = nil end
    child_close = open_submenu(win, item.submenu, zindex + 10, idx, opt, on_exec, function()
      child_close = nil
    end)
  end

  local function exec()
    local item = parsed[idx]
    if not item or item.separator then return end
    if item.submenu then open_child(); return end
    local cmd = item.cmd
    do_close(false)
    if on_exec then on_exec() end
    vim.schedule(function() util.exec(cmd) end)
  end

  local km = cfg.keymaps
  local function kmap(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
  end
  local function bind(keys, fn)
    for _, k in ipairs(keys or {}) do kmap(k, fn) end
  end

  util.suppress_keys(buf)

  bind(km.up,      function() move(-1) end)
  bind(km.down,    function() move(1)  end)
  bind(km.exec,    exec)
  bind(km.submenu, open_child)
  bind(km.back,    function() do_close(true) end)
  bind(km.close,   function() do_close(true) end)
  bind(km.mouse, function()
    local mpos = vim.fn.getmousepos()
    if mpos.winid ~= win then return end
    local r = mpos.line
    if parsed[r] and not parsed[r].separator then
      idx = r
      hl()
      exec()
    end
  end)

  local sc_reserved = util.reserved_keys(km, { "up", "down", "exec", "close", "submenu", "back" })
  for i, item in ipairs(parsed) do
    if not item.separator and item.shortcut then
      local sc    = item.shortcut
      local sc_up = sc:upper()
      local function do_exec() idx = i; exec() end
      if not sc_reserved[sc]                    then kmap(sc,    do_exec) end
      if sc_up ~= sc and not sc_reserved[sc_up] then kmap(sc_up, do_exec) end
    end
  end

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

  return function() do_close(true) end
end

-- ── setup ─────────────────────────────────────────────────────────────────────

function M.setup(opts)
  if opts.border ~= nil then cfg.border = opts.border end
  local wb = opts.winblend
  if type(wb) == "number" then
    cfg.winblend = wb
  elseif type(wb) == "table" and wb.menu ~= nil then
    cfg.winblend = wb.menu
  end
  local user_km = opts.keymaps or {}
  if opts.disable_default_keymaps then
    cfg.keymaps = user_km
  else
    cfg.keymaps = vim.tbl_extend("force", vim.deepcopy(util.default_keymaps), user_km)
  end
end

return M
