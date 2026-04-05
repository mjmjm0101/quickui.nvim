--- Menubar: a non-focusable strip at the top of the editor showing menu titles,
--- plus a focusable dropdown that opens below the selected title.
--- Supports nested submenus (parent stays visible while submenu is open).
local M = {}
local util = require("quickui.util")

local cfg = {
  border             = "single",
  winblend_bar       = 0,
  winblend_menu      = 40,
  menubar_padding    = 1,
  menubar_separator  = "│",
  keymaps            = vim.deepcopy(util.default_keymaps),
}

local ns_bar  = vim.api.nvim_create_namespace("quickui_bar")
local ns_drop = vim.api.nvim_create_namespace("quickui_drop")
local ns_sc   = vim.api.nvim_create_namespace("quickui_shortcut")
local ns_sep  = vim.api.nvim_create_namespace("quickui_separator")
local ns_item = vim.api.nvim_create_namespace("quickui_item_hl")

-- ── state ─────────────────────────────────────────────────────────────────────
local S = {
  open           = false,
  menu_idx       = 1,
  item_idx       = 1,
  prev_win       = nil,
  bar_win        = nil,
  bar_buf        = nil,
  drop_win       = nil,
  drop_buf       = nil,
  menus          = {},
  items          = {},
  menu_cols      = {},
  sub_wins       = {},   -- stack of open submenu { win, buf }
  saved_guicursor      = nil,
  cursor_hidden_escape = false,  -- true if hidden via DECTCEM instead of blend
}

-- ── helpers ───────────────────────────────────────────────────────────────────

local function visible_menus(registry)
  local opt = { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local result = {}
  for _, m in ipairs(registry) do
    local show = true
    if type(m.conditions) == "function" then
      show = m.conditions(opt) ~= false
    end
    if show then table.insert(result, m) end
  end
  return result
end

local function display_title(m)
  return m.name:gsub("&", ""):gsub("^@", "")
end

-- ── line builder (shared by dropdown and submenu) ─────────────────────────────

local function build_lines(items)
  local max_w = 12
  for _, item in ipairs(items) do
    if not item.separator then
      local w = vim.fn.strdisplaywidth(item.display) + 2
      local r = item.submenu and "›" or item.right
      if r then w = w + vim.fn.strdisplaywidth(r) + 2 end
      if w > max_w then max_w = w end
    end
  end

  local lines = {}
  for _, item in ipairs(items) do
    if item.separator then
      table.insert(lines, string.rep("─", max_w))
    else
      local l = " " .. item.display
      local r_raw = item.submenu and "›" or item.right
      if r_raw then
        local r = r_raw .. " "
        local pad = max_w - vim.fn.strdisplaywidth(l) - vim.fn.strdisplaywidth(r)
        if pad < 1 then pad = 1 end
        item.right_hl_col = #l + pad
        item.right_hl_end = item.right_hl_col + #r_raw
        table.insert(lines, l .. string.rep(" ", pad) .. r)
      else
        item.right_hl_col = nil
        local pad = max_w - vim.fn.strdisplaywidth(l)
        if pad < 0 then pad = 0 end
        table.insert(lines, l .. string.rep(" ", pad))
      end
    end
  end
  return lines, max_w
end

local function apply_item_hl(buf, items)
  vim.api.nvim_buf_clear_namespace(buf, ns_item, 0, -1)
  for i, item in ipairs(items) do
    if not item.separator and item.hl then
      local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1] or ""
      vim.api.nvim_buf_set_extmark(buf, ns_item, i - 1, 0, {
        end_col  = #line,
        hl_group = item.hl,
        priority = 50,
      })
    end
  end
end

local function apply_accent(buf, items)
  vim.api.nvim_buf_clear_namespace(buf, ns_sc, 0, -1)
  for i, item in ipairs(items) do
    if not item.separator then
      if item.shortcut_col then
        local col = 1 + item.shortcut_col
        vim.api.nvim_buf_set_extmark(buf, ns_sc, i - 1, col, {
          end_col  = col + 1,
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

-- ── menubar rendering ─────────────────────────────────────────────────────────

local function render_bar()
  if not (S.bar_buf and vim.api.nvim_buf_is_valid(S.bar_buf)) then return end

  local pad     = string.rep(" ", cfg.menubar_padding)
  local sep     = cfg.menubar_separator
  local line    = ""
  local cols    = {}
  local sep_positions = {}  -- { col, len } for each separator

  for i, m in ipairs(S.menus) do
    local t = display_title(m)
    if i > 1 and sep ~= "" then
      table.insert(sep_positions, { col = #line, len = #sep })
      line = line .. sep
    end
    cols[i] = #line
    line    = line .. pad .. t .. pad
  end

  local w = vim.o.columns
  if #line < w then line = line .. string.rep(" ", w - #line) end

  vim.bo[S.bar_buf].modifiable = true
  vim.api.nvim_buf_set_lines(S.bar_buf, 0, -1, false, { line })
  vim.bo[S.bar_buf].modifiable = false
  S.menu_cols = cols

  -- 選択ハイライト
  vim.api.nvim_buf_clear_namespace(S.bar_buf, ns_bar, 0, -1)
  local t = display_title(S.menus[S.menu_idx])
  local c = cols[S.menu_idx]
  local item_w = cfg.menubar_padding + #t + cfg.menubar_padding
  vim.api.nvim_buf_set_extmark(S.bar_buf, ns_bar, 0, c, {
    end_col  = c + item_w,
    hl_group = "QuickUIMenubarSel",
    priority = 100,
  })

  -- セパレータハイライト
  vim.api.nvim_buf_clear_namespace(S.bar_buf, ns_sep, 0, -1)
  for _, s in ipairs(sep_positions) do
    vim.api.nvim_buf_set_extmark(S.bar_buf, ns_sep, 0, s.col, {
      end_col  = s.col + s.len,
      hl_group = "QuickUIMenubarSeparator",
      priority = 100,
    })
  end

  -- アクセントハイライト (priority 200 で選択・セパレータより前面)
  vim.api.nvim_buf_clear_namespace(S.bar_buf, ns_sc, 0, -1)
  for i, m in ipairs(S.menus) do
    local amp_pos = m.name:find("&%a")
    if amp_pos then
      local col = cols[i] + cfg.menubar_padding + (amp_pos - 1)
      vim.api.nvim_buf_set_extmark(S.bar_buf, ns_sc, 0, col, {
        end_col  = col + 1,
        hl_group = "QuickUIMenuAccent",
        hl_mode  = "combine",
        priority = 200,
      })
    end
  end
end

-- ── submenu ───────────────────────────────────────────────────────────────────

local function close_all_subs()
  for _, s in ipairs(S.sub_wins) do
    if s.win and vim.api.nvim_win_is_valid(s.win) then
      vim.api.nvim_win_close(s.win, true)
    end
    if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
      vim.api.nvim_buf_delete(s.buf, { force = true })
    end
  end
  S.sub_wins = {}
end

-- Forward declaration (open_submenu calls itself recursively for sub-submenus)
local open_submenu

open_submenu = function(parent_win, raw_items, parent_item_idx)
  -- Parse items
  local opt   = { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local items = {}
  for _, raw in ipairs(raw_items) do
    if util.is_submenu_item(raw) then
      if util.item_conditions(raw, opt) then
        local p = util.parse_label(util.item_label(raw))
        p.submenu = raw.items
        p.hl      = util.item_hl(raw)
        table.insert(items, p)
      end
    else
      if util.ft_match(util.item_ft(raw)) then
        local p = util.parse_label(util.item_label(raw))
        p.cmd   = util.item_cmd(raw)
        p.right = util.item_rtxt(raw)
        p.hl    = util.item_hl(raw)
        if not p.shortcut and p.right and p.right ~= "" then
          p.shortcut = p.right:sub(1, 1):lower()
        end
        table.insert(items, p)
      end
    end
  end
  if #items == 0 then return end

  local lines, max_w = build_lines(items)

  -- Position: to the right of the parent window, aligned to the selected item
  local parent_pos = vim.api.nvim_win_get_position(parent_win)
  local parent_w   = vim.api.nvim_win_get_width(parent_win)
  local has_border = cfg.border and cfg.border ~= "none"
  local border_w   = has_border and 2 or 0
  local border_h   = has_border and 1 or 0

  -- Align submenu row so its first item matches the parent's selected item
  local row = parent_pos[1] + (parent_item_idx or 1) - 1
  -- Clamp: submenu must fit within the screen vertically
  if row + #lines + border_h * 2 > vim.o.lines then
    row = vim.o.lines - #lines - border_h * 2
  end
  row = math.max(0, row)

  -- Column: prefer right of parent, flip left if not enough room
  local col = parent_pos[2] + parent_w + border_w
  if col + max_w + border_w > vim.o.columns then
    col = math.max(0, parent_pos[2] - max_w - border_w)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"

  -- Limit height to fit on screen from the clamped row
  local max_h  = math.max(1, vim.o.lines - row - border_h * 2)
  local height = math.min(#lines, max_h)

  local zindex = 202 + #S.sub_wins
  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    row       = row,
    col       = col,
    width     = max_w,
    height    = height,
    style     = "minimal",
    border    = util.resolve_border(cfg.border),
    focusable = true,
    zindex    = zindex,
  })
  vim.wo[win].winhighlight = "Normal:QuickUIMenu,FloatBorder:QuickUIMenuBorder"
  vim.wo[win].winblend     = cfg.winblend_menu
  vim.wo[win].scrolloff    = 1

  table.insert(S.sub_wins, { win = win, buf = buf })

  -- Local selection state
  local ns  = vim.api.nvim_create_namespace("quickui_sub_" .. #S.sub_wins)
  local idx = 1
  for i, item in ipairs(items) do
    if not item.separator then idx = i; break end
  end

  local function hl()
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    apply_item_hl(buf, items)
    local item = items[idx]
    if item and not item.separator then
      local row  = idx - 1
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        end_col  = #line,
        hl_group = "QuickUIMenuSel",
        priority = 100,
      })
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { idx, 0 })
      end
    end
    -- Accent は priority 200 で選択ハイライト(100)より前面に
    apply_accent(buf, items)
  end
  hl()

  local function move(dir)
    local n = #items
    local next = idx + dir
    if next < 1 then next = n end
    if next > n then next = 1 end
    local tries = 0
    while items[next] and items[next].separator and tries < n do
      next = next + dir
      if next < 1 then next = n end
      if next > n then next = 1 end
      tries = tries + 1
    end
    idx = next
    hl()
  end

  local function close_this()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    table.remove(S.sub_wins)
    -- Return focus to parent window
    if vim.api.nvim_win_is_valid(parent_win) then
      vim.api.nvim_set_current_win(parent_win)
    end
  end

  local function exec()
    local item = items[idx]
    if not item or item.separator then return end
    if item.submenu then
      open_submenu(win, item.submenu, idx)
      return
    end
    local cmd = item.cmd
    M.close()
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

  local function open_child()
    local item = items[idx]
    if item and item.submenu then open_submenu(win, item.submenu, idx) end
  end

  bind(km.up,        function() move(-1) end)
  bind(km.down,      function() move(1)  end)
  bind(km.menu_prev, function() M.move_menu(-1) end)
  bind(km.menu_next, function() M.move_menu(1)  end)
  bind(km.submenu,   open_child)
  bind(km.exec,      exec)
  bind(km.back,      close_this)
  bind(km.close,     M.close)
  bind(km.mouse, function()
    local mpos = vim.fn.getmousepos()
    if mpos.winid == win then
      local r = mpos.line
      if items[r] and not items[r].separator then
        idx = r
        hl()
        exec()
      end
    elseif mpos.winid == S.bar_win then
      local c = mpos.wincol - 1
      for i = #S.menu_cols, 1, -1 do
        if c >= S.menu_cols[i] then
          S.menu_idx = i
          M.move_menu(0)
          return
        end
      end
    else
      M.close()
    end
  end)

  -- Shortcut keys (both lower and upper)
  local sc_reserved_sub = util.reserved_keys(km, { "up", "down", "exec", "close", "submenu", "menu_prev", "menu_next", "back" })
  for i, item in ipairs(items) do
    if not item.separator and item.shortcut then
      local sc    = item.shortcut
      local sc_up = sc:upper()
      local function do_exec()
        idx = i
        hl()
        exec()
      end
      if not sc_reserved_sub[sc]                    then kmap(sc,    do_exec) end
      if sc_up ~= sc and not sc_reserved_sub[sc_up] then kmap(sc_up, do_exec) end
    end
  end
end

-- ── dropdown ──────────────────────────────────────────────────────────────────

local function close_drop()
  close_all_subs()
  if S.drop_win and vim.api.nvim_win_is_valid(S.drop_win) then
    vim.api.nvim_win_close(S.drop_win, true)
  end
  if S.drop_buf and vim.api.nvim_buf_is_valid(S.drop_buf) then
    vim.api.nvim_buf_delete(S.drop_buf, { force = true })
  end
  S.drop_win, S.drop_buf = nil, nil
end

local function hl_drop()
  if not (S.drop_buf and vim.api.nvim_buf_is_valid(S.drop_buf)) then return end
  vim.api.nvim_buf_clear_namespace(S.drop_buf, ns_drop, 0, -1)
  apply_item_hl(S.drop_buf, S.items)
  local item = S.items[S.item_idx]
  if item and not item.separator then
    local row  = S.item_idx - 1
    local line = vim.api.nvim_buf_get_lines(S.drop_buf, row, row + 1, false)[1] or ""
    vim.api.nvim_buf_set_extmark(S.drop_buf, ns_drop, row, 0, {
      end_col  = #line,
      hl_group = "QuickUIMenuSel",
      priority = 100,
    })
    if S.drop_win and vim.api.nvim_win_is_valid(S.drop_win) then
      vim.api.nvim_win_set_cursor(S.drop_win, { S.item_idx, 0 })
    end
  end
  -- Accent は priority 200 で選択ハイライト(100)より前面に
  apply_accent(S.drop_buf, S.items)
end

local function open_drop()
  close_drop()

  local menu = S.menus[S.menu_idx]
  local opt  = { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local raw_items = type(menu.items) == "function" and menu.items(opt) or menu.items

  S.items = {}
  for _, raw in ipairs(raw_items) do
    if util.is_submenu_item(raw) then
      if util.item_conditions(raw, opt) then
        local p = util.parse_label(util.item_label(raw))
        p.submenu = raw.items
        p.hl      = util.item_hl(raw)
        table.insert(S.items, p)
      end
    else
      if util.ft_match(util.item_ft(raw)) then
        local p = util.parse_label(util.item_label(raw))
        p.cmd   = util.item_cmd(raw)
        p.right = util.item_rtxt(raw)
        p.hl    = util.item_hl(raw)
        if not p.shortcut and p.right and p.right ~= "" then
          p.shortcut = p.right:sub(1, 1):lower()
        end
        table.insert(S.items, p)
      end
    end
  end
  if #S.items == 0 then return end

  local lines, max_w = build_lines(S.items)

  local buf = vim.api.nvim_create_buf(false, true)
  S.drop_buf = buf
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"

  local has_border = cfg.border and cfg.border ~= "none"
  local border_w   = has_border and 2 or 0
  local border_h   = has_border and 1 or 0
  local col        = S.menu_cols[S.menu_idx] or 0
  if col + max_w + border_w > vim.o.columns then
    col = math.max(0, vim.o.columns - max_w - border_w)
  end

  -- Limit height: bar occupies row 0, dropdown starts at row 1
  local max_h  = math.max(1, vim.o.lines - 1 - border_h * 2)
  local height = math.min(#lines, max_h)

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    row       = 1,
    col       = col,
    width     = max_w,
    height    = height,
    style     = "minimal",
    border    = util.resolve_border(cfg.border),
    focusable = true,
    zindex    = 201,
  })
  S.drop_win = win
  vim.wo[win].winhighlight = "Normal:QuickUIMenu,FloatBorder:QuickUIMenuBorder"
  vim.wo[win].winblend     = cfg.winblend_menu
  vim.wo[win].scrolloff    = 1

  S.item_idx = 1
  for i, item in ipairs(S.items) do
    if not item.separator then S.item_idx = i; break end
  end
  hl_drop()  -- apply_accent is called inside hl_drop

  local km = cfg.keymaps
  local function kmap(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
  end
  local function bind(keys, fn)
    for _, k in ipairs(keys or {}) do kmap(k, fn) end
  end

  -- Suppress all global keymaps first, then apply quickui-specific ones
  util.suppress_keys(buf)

  local function submenu_or_next()
    local item = S.items[S.item_idx]
    if item and item.submenu then open_submenu(S.drop_win, item.submenu, S.item_idx)
    else M.move_menu(1) end
  end

  bind(km.up,        function() M.move_item(-1) end)
  bind(km.down,      function() M.move_item(1)  end)
  bind(km.menu_prev, function() M.move_menu(-1) end)
  bind(km.menu_next, function() M.move_menu(1)  end)
  bind(km.submenu,   submenu_or_next)
  bind(km.exec,      M.exec_item)
  bind(km.close,     M.close)
  bind(km.mouse, function()
    local mpos = vim.fn.getmousepos()
    if mpos.winid == S.bar_win then
      local c = mpos.wincol - 1
      for i = #S.menu_cols, 1, -1 do
        if c >= S.menu_cols[i] then S.menu_idx = i; M.move_menu(0); return end
      end
    elseif mpos.winid == S.drop_win then
      local r = mpos.line
      if S.items[r] and not S.items[r].separator then
        S.item_idx = r; hl_drop(); M.exec_item()
      end
    else
      M.close()
    end
  end)

  -- Item shortcut keys (both lower and upper); skip keys reserved for navigation
  local sc_reserved_drop = util.reserved_keys(km, { "up", "down", "exec", "close", "submenu", "menu_prev", "menu_next" })
  for i, item in ipairs(S.items) do
    if not item.separator and item.shortcut then
      local sc    = item.shortcut
      local sc_up = sc:upper()
      local function do_exec() S.item_idx = i; hl_drop(); M.exec_item() end
      if not sc_reserved_drop[sc]                    then kmap(sc,    do_exec) end
      if sc_up ~= sc and not sc_reserved_drop[sc_up] then kmap(sc_up, do_exec) end
    end
  end

  -- Menu title shortcut keys (single-char from &Letter in name)
  for i, m in ipairs(S.menus) do
    local sc = m.name:match("&(%a)")
    if sc then
      sc = sc:lower()
      if not sc_reserved_drop[sc] then
        kmap(sc, function() S.menu_idx = i; render_bar(); open_drop() end)
      end
    end
  end

end

-- ── navigation ────────────────────────────────────────────────────────────────

function M.move_item(dir)
  local n = #S.items
  if n == 0 then return end
  local idx   = S.item_idx + dir
  local tries = 0
  if idx < 1 then idx = n end
  if idx > n then idx = 1 end
  while S.items[idx].separator and tries < n do
    idx = idx + dir
    if idx < 1 then idx = n end
    if idx > n then idx = 1 end
    tries = tries + 1
  end
  S.item_idx = idx
  -- Close any open submenus when navigating the parent
  close_all_subs()
  hl_drop()
end

function M.move_menu(dir)
  S.menu_idx = ((S.menu_idx - 1 + dir) % #S.menus) + 1
  render_bar()
  open_drop()
end

function M.exec_item()
  local item = S.items[S.item_idx]
  if not item or item.separator then return end
  if item.submenu then
    open_submenu(S.drop_win, item.submenu, S.item_idx)
    return
  end
  local cmd = item.cmd
  M.close()
  vim.schedule(function() util.exec(cmd) end)
end

-- ── open / close / toggle ─────────────────────────────────────────────────────

function M.open(registry)
  S.prev_win = vim.api.nvim_get_current_win()
  S.menus    = visible_menus(registry)
  S.menu_idx = 1
  S.open     = true

  -- Hide cursor while menu is open.
  -- GUI or termguicolors (modern TUI): blend=100 → fully transparent cursor.
  -- Older TUI (no termguicolors): DECTCEM escape sequence as fallback.
  S.saved_guicursor = vim.o.guicursor
  if vim.fn.has("gui_running") == 1 or vim.o.termguicolors then
    vim.api.nvim_set_hl(0, "QuickUICursorHidden", { blend = 100, nocombine = true })
    vim.o.guicursor = "a:block-QuickUICursorHidden/lCursor"
    S.cursor_hidden_escape = false
  else
    io.write("\27[?25l")
    io.flush()
    S.cursor_hidden_escape = true
  end

  if #S.menus == 0 then return end

  local buf = vim.api.nvim_create_buf(false, true)
  S.bar_buf = buf
  vim.bo[buf].buftype = "nofile"

  local win = vim.api.nvim_open_win(buf, false, {
    relative  = "editor",
    row       = 0,
    col       = 0,
    width     = vim.o.columns,
    height    = 1,
    style     = "minimal",
    focusable = false,
    zindex    = 200,
  })
  S.bar_win = win
  vim.wo[win].winhighlight = "Normal:QuickUIMenubar"
  vim.wo[win].winblend     = cfg.winblend_bar

  render_bar()
  open_drop()
end

function M.close()
  close_drop()  -- also calls close_all_subs()

  if S.bar_win and vim.api.nvim_win_is_valid(S.bar_win) then
    vim.api.nvim_win_close(S.bar_win, true)
  end
  if S.bar_buf and vim.api.nvim_buf_is_valid(S.bar_buf) then
    vim.api.nvim_buf_delete(S.bar_buf, { force = true })
  end
  S.bar_win, S.bar_buf = nil, nil
  S.open, S.items      = false, {}

  -- Restore cursor
  if S.saved_guicursor then
    if S.cursor_hidden_escape then
      io.write("\27[?25h")
      io.flush()
    else
      vim.o.guicursor = S.saved_guicursor
    end
    S.saved_guicursor      = nil
    S.cursor_hidden_escape = false
  end

  if S.prev_win and vim.api.nvim_win_is_valid(S.prev_win) then
    vim.api.nvim_set_current_win(S.prev_win)
  end
end

function M.toggle(registry)
  if S.open then M.close() else M.open(registry) end
end

function M.setup(opts)
  if opts.border            ~= nil then cfg.border            = opts.border            end
  if opts.menubar_padding   ~= nil then cfg.menubar_padding   = opts.menubar_padding   end
  if opts.menubar_separator ~= nil then cfg.menubar_separator = opts.menubar_separator end
  local wb = opts.winblend
  if type(wb) == "number" then
    cfg.winblend_bar  = wb
    cfg.winblend_menu = wb
  elseif type(wb) == "table" then
    if wb.bar  ~= nil then cfg.winblend_bar  = wb.bar  end
    if wb.menu ~= nil then cfg.winblend_menu = wb.menu end
  end
  local user_km = opts.keymaps or {}
  if opts.disable_default_keymaps then
    cfg.keymaps = user_km
  else
    cfg.keymaps = vim.tbl_extend("force", vim.deepcopy(util.default_keymaps), user_km)
  end
end

return M
