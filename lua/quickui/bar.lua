--- Menubar: a title strip at the top of the editor showing menu titles,
--- plus a dropdown that opens below the selected title.
--- Supports nested submenus (parent stays visible while submenu is open).
local M = {}
local util  = require("quickui.util")
local panel = require("quickui.menu_panel")

local cfg = {
  border                    = "single",
  winblend_bar              = 0,
  winblend_menu             = 40,
  menubar_padding           = 1,
  menubar_separator         = "│",
  menubar_indicator_left    = "<",
  menubar_indicator_right   = ">",
  keymaps                   = vim.deepcopy(util.default_keymaps),
  suppress_all_keys         = true,
  toggle_key                = "<Space>",
  menubar_restore           = true,
}

local ns_bar = vim.api.nvim_create_namespace("quickui_bar")
local ns_sc  = vim.api.nvim_create_namespace("quickui_shortcut")
local ns_sep = vim.api.nvim_create_namespace("quickui_separator")
local ns_ind = vim.api.nvim_create_namespace("quickui_indicator")

-- ── state ─────────────────────────────────────────────────────────────────────
local S = {
  open       = false,
  menu_idx   = 1,
  view_start = 1,
  prev_win   = nil,
  bar_win    = nil,
  bar_buf    = nil,
  drop_panel = nil,
  menus        = {},
  menu_cols    = {},
  last_visible = 0,
  saved        = { menu_name = nil, view_start = 1 },
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

-- ── menubar rendering ─────────────────────────────────────────────────────────

local function render_bar()
  if not (S.bar_buf and vim.api.nvim_buf_is_valid(S.bar_buf)) then return end

  local pad_n   = cfg.menubar_padding
  local pad     = string.rep(" ", pad_n)
  local sep     = cfg.menubar_separator
  local sep_bw  = #sep
  local sep_dw  = sep ~= "" and vim.fn.strdisplaywidth(sep) or 0
  local ind_ldw = vim.fn.strdisplaywidth(cfg.menubar_indicator_left)
  local ind_rdw = vim.fn.strdisplaywidth(cfg.menubar_indicator_right)
  local w       = vim.o.columns

  -- Byte width and display width of each menu entry (" title ")
  local m_bw = {}
  local m_dw = {}
  for i, m in ipairs(S.menus) do
    local t = display_title(m)
    m_bw[i] = pad_n + #t + pad_n
    m_dw[i] = pad_n + vim.fn.strdisplaywidth(t) + pad_n
  end

  -- Clamp view_start to [1, menu_idx] so left-scroll happens automatically
  S.view_start = math.max(1, math.min(S.view_start, S.menu_idx))

  -- Returns the last visible menu index when starting from `from` with `avail` display cols
  local function last_idx(from, avail)
    local used = 0
    local last = from - 1
    for i = from, #S.menus do
      local extra = i > from and sep_dw or 0
      if used + extra + m_dw[i] > avail then break end
      used = used + extra + m_dw[i]
      last = i
    end
    return last
  end

  -- Advance view_start right until menu_idx is in the visible window
  while S.view_start < S.menu_idx do
    local ldw  = S.view_start > 1 and ind_ldw or 0
    if S.menu_idx <= last_idx(S.view_start, w - ldw - ind_rdw) then break end
    S.view_start = S.view_start + 1
  end

  -- Two-pass: determine whether a right indicator is needed
  local has_left  = S.view_start > 1
  local ldw       = has_left and ind_ldw or 0
  local last_v    = last_idx(S.view_start, w - ldw - ind_rdw)
  local has_right = last_v < #S.menus
  if not has_right then
    last_v = last_idx(S.view_start, w - ldw)
  end

  -- Build display line
  -- d_cols tracks byte offsets (for extmarks); d_dcols tracks display columns
  -- (for dropdown positioning and mouse hit-testing, which are cell-based).
  local ind_l   = cfg.menubar_indicator_left
  local ind_r   = cfg.menubar_indicator_right
  local line    = has_left and ind_l or ""
  local line_dw = has_left and ind_ldw or 0
  local d_cols  = {}
  local d_dcols = {}
  local sep_pos = {}

  for i = S.view_start, last_v do
    if i > S.view_start and sep ~= "" then
      table.insert(sep_pos, { col = #line, len = sep_bw })
      line    = line .. sep
      line_dw = line_dw + sep_dw
    end
    d_cols[i]  = #line
    d_dcols[i] = line_dw
    line    = line .. pad .. display_title(S.menus[i]) .. pad
    line_dw = line_dw + m_dw[i]
  end

  if has_right then
    if line_dw < w - ind_rdw then line = line .. string.rep(" ", w - ind_rdw - line_dw) end
    line = line .. ind_r
  else
    if line_dw < w then line = line .. string.rep(" ", w - line_dw) end
  end

  vim.bo[S.bar_buf].modifiable = true
  vim.api.nvim_buf_set_lines(S.bar_buf, 0, -1, false, { line })
  vim.bo[S.bar_buf].modifiable = false
  S.menu_cols    = d_dcols
  S.last_visible = last_v

  -- Highlight: selected item
  vim.api.nvim_buf_clear_namespace(S.bar_buf, ns_bar, 0, -1)
  local sel_c = d_cols[S.menu_idx]
  if sel_c then
    vim.api.nvim_buf_set_extmark(S.bar_buf, ns_bar, 0, sel_c, {
      end_col  = sel_c + m_bw[S.menu_idx],
      hl_group = "QuickUIMenubarSel",
      priority = 100,
    })
  end

  -- Highlight: separators
  vim.api.nvim_buf_clear_namespace(S.bar_buf, ns_sep, 0, -1)
  for _, s in ipairs(sep_pos) do
    vim.api.nvim_buf_set_extmark(S.bar_buf, ns_sep, 0, s.col, {
      end_col  = s.col + s.len,
      hl_group = "QuickUIMenubarSeparator",
      priority = 100,
    })
  end

  -- Highlight: shortcut chars
  vim.api.nvim_buf_clear_namespace(S.bar_buf, ns_sc, 0, -1)
  for i = S.view_start, last_v do
    local m = S.menus[i]
    local amp_pos = m.name:find("&%a")
    if amp_pos then
      local col = d_cols[i] + pad_n + (amp_pos - 1)
      vim.api.nvim_buf_set_extmark(S.bar_buf, ns_sc, 0, col, {
        end_col  = col + 1,
        hl_group = "QuickUIMenuAccent",
        hl_mode  = "combine",
        priority = 200,
      })
    end
  end

  -- Highlight: scroll indicators
  vim.api.nvim_buf_clear_namespace(S.bar_buf, ns_ind, 0, -1)
  if has_left then
    local ind_lbw = #cfg.menubar_indicator_left
    vim.api.nvim_buf_set_extmark(S.bar_buf, ns_ind, 0, 0, {
      end_col  = ind_lbw,
      hl_group = "QuickUIMenubarIndicator",
      priority = 300,
    })
  end
  if has_right then
    local ind_rbw = #cfg.menubar_indicator_right
    vim.api.nvim_buf_set_extmark(S.bar_buf, ns_ind, 0, #line - ind_rbw, {
      end_col  = #line,
      hl_group = "QuickUIMenubarIndicator",
      priority = 300,
    })
  end
end

-- ── dropdown ──────────────────────────────────────────────────────────────────

local function close_drop()
  local p = S.drop_panel
  S.drop_panel = nil
  if p then p.close_silent() end
end

-- Handle a click on the bar at display column c (0-based).
local function handle_bar_click(c)
  local ind_ldw = vim.fn.strdisplaywidth(cfg.menubar_indicator_left)
  local ind_rdw = vim.fn.strdisplaywidth(cfg.menubar_indicator_right)
  if S.view_start > 1 and c < ind_ldw then
    S.menu_idx = S.view_start - 1; M.move_menu(0); return
  end
  if S.last_visible < #S.menus and c >= vim.o.columns - ind_rdw then
    S.menu_idx = S.last_visible + 1; M.move_menu(0); return
  end
  for i = S.last_visible, S.view_start, -1 do
    if c >= S.menu_cols[i] then S.menu_idx = i; M.move_menu(0); return end
  end
end

local function open_drop()
  close_drop()

  local menu      = S.menus[S.menu_idx]
  local opt       = { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local raw_items = type(menu.items) == "function" and menu.items(opt) or menu.items
  local items     = panel.parse_items(raw_items, opt)
  if #items == 0 then
    vim.notify("quickui: no items to display in menu '" .. (menu.name or "") .. "'", vim.log.levels.WARN)
    return
  end

  local km = cfg.keymaps

  -- bar nav keymaps applied to every panel in the hierarchy (dropdown + all submenus)
  local function bind_bar_nav(buf)
    local function kmap(key, fn)
      vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
    end
    local function bind(keys, fn)
      for _, k in ipairs(keys or {}) do kmap(k, fn) end
    end
    bind(km.menu_prev, function() M.move_menu(-1) end)
    bind(km.menu_next, function() M.move_menu(1)  end)
    kmap(cfg.toggle_key, M.close)
  end

  S.drop_panel = panel.open(items, { row = 1, col = S.menu_cols[S.menu_idx] or 0 }, {
    border            = cfg.border,
    winblend          = cfg.winblend_menu,
    zindex            = 201,
    keymaps           = km,
    suppress_all_keys = cfg.suppress_all_keys,
    esc_closes_all    = true,
  }, opt, {
    on_exec        = M.close,
    on_close       = M.close,
    on_mouse_other = function(winid)
      if winid == S.bar_win then
        local mpos = vim.fn.getmousepos()
        if not mpos.wincol then return end
        handle_bar_click(mpos.wincol - 1)
      else
        M.close()
      end
    end,
    on_no_submenu = function() M.move_menu(1) end,
    on_nav_prev   = function() M.move_menu(-1) end,
    bind_extra    = bind_bar_nav,
  })

  -- keymaps bound only to the top-level dropdown buffer
  local buf = S.drop_panel.buf
  if buf then
    local function kmap(key, fn)
      vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
    end
    -- Shortcut keys: jump directly to a menu by letter
    local sc_reserved = util.reserved_keys(km, { "up", "down", "exec", "close", "submenu", "back", "menu_prev", "menu_next", "nav_prev", "nav_next" })
    for i, m in ipairs(S.menus) do
      local sc = m.name:match("&(%a)")
      if sc then
        sc = sc:lower()
        if not sc_reserved[sc] then
          kmap(sc, function() S.menu_idx = i; render_bar(); open_drop() end)
        end
      end
    end
  end
end

-- ── navigation ────────────────────────────────────────────────────────────────

function M.move_item(dir)
  if S.drop_panel then S.drop_panel.move(dir) end
end

function M.move_menu(dir)
  S.menu_idx = ((S.menu_idx - 1 + dir) % #S.menus) + 1
  render_bar()
  open_drop()
end

function M.exec_item()
  if S.drop_panel then S.drop_panel.exec() end
end

-- ── open / close / toggle ─────────────────────────────────────────────────────

function M.open(registry)
  S.prev_win = vim.api.nvim_get_current_win()
  S.menus    = visible_menus(registry)
  S.open     = true

  if cfg.menubar_restore and S.saved.menu_name then
    local found = 1
    for i, m in ipairs(S.menus) do
      if m.name == S.saved.menu_name then found = i; break end
    end
    S.menu_idx   = found
    S.view_start = S.saved.view_start
  else
    S.menu_idx   = 1
    S.view_start = 1
  end

  if #S.menus == 0 then
    vim.notify("quickui: no menus to display", vim.log.levels.WARN)
    return
  end

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
    focusable = true,
    zindex    = 200,
  })
  S.bar_win = win
  vim.wo[win].winhighlight = "Normal:QuickUIMenubar,Cursor:QuickUIBarCursor"
  vim.wo[win].winblend     = cfg.winblend_bar

  -- Key bindings for the bar window
  if cfg.suppress_all_keys then util.suppress_keys(buf) end
  local function kmap(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
  end
  kmap("<LeftMouse>", function()
    local mpos = vim.fn.getmousepos()
    if mpos.winid ~= S.bar_win then return end
    handle_bar_click(mpos.wincol - 1)
  end)
  kmap(cfg.toggle_key, M.close)
  for _, k in ipairs(cfg.keymaps.close or {}) do kmap(k, M.close) end

  render_bar()
  open_drop()
end

function M.close()
  if cfg.menubar_restore and S.menus[S.menu_idx] then
    S.saved.menu_name  = S.menus[S.menu_idx].name
    S.saved.view_start = S.view_start
  end

  close_drop()

  if S.bar_win and vim.api.nvim_win_is_valid(S.bar_win) then
    vim.api.nvim_win_close(S.bar_win, true)
  end
  if S.bar_buf and vim.api.nvim_buf_is_valid(S.bar_buf) then
    vim.api.nvim_buf_delete(S.bar_buf, { force = true })
  end
  S.bar_win, S.bar_buf = nil, nil
  S.open               = false

  if S.prev_win and vim.api.nvim_win_is_valid(S.prev_win) then
    vim.api.nvim_set_current_win(S.prev_win)
  end
end

function M.toggle(registry)
  if S.open then M.close() else M.open(registry) end
end

function M.setup(opts)
  if opts.border                  ~= nil then cfg.border                  = opts.border                  end
  if opts.menubar_padding         ~= nil then cfg.menubar_padding         = opts.menubar_padding         end
  if opts.menubar_separator       ~= nil then cfg.menubar_separator       = opts.menubar_separator       end
  if opts.menubar_indicator_left  ~= nil then cfg.menubar_indicator_left  = opts.menubar_indicator_left  end
  if opts.menubar_indicator_right ~= nil then cfg.menubar_indicator_right = opts.menubar_indicator_right end
  local wb = opts.winblend
  if type(wb) == "number" then
    cfg.winblend_bar  = wb
    cfg.winblend_menu = wb
  elseif type(wb) == "table" then
    if wb.bar  ~= nil then cfg.winblend_bar  = wb.bar  end
    if wb.menu ~= nil then cfg.winblend_menu = wb.menu end
  end
  cfg.keymaps = util.resolve_keymaps(opts)
  if opts.suppress_all_keys ~= nil then cfg.suppress_all_keys = opts.suppress_all_keys end
  if opts.keymap             ~= nil then cfg.toggle_key        = opts.keymap             end
  if opts.menubar_restore     ~= nil then cfg.menubar_restore    = opts.menubar_restore     end
end

return M
