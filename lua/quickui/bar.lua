--- Menubar: a non-focusable strip at the top of the editor showing menu titles,
--- plus a focusable dropdown that opens below the selected title.
--- Supports nested submenus (parent stays visible while submenu is open).
local M = {}
local util   = require("quickui.util")
local panel  = require("quickui.menu_panel")
local cursor = require("quickui.cursor")

local cfg = {
  border             = "single",
  winblend_bar       = 0,
  winblend_menu      = 40,
  menubar_padding    = 1,
  menubar_separator  = "│",
  keymaps            = vim.deepcopy(util.default_keymaps),
  suppress_all_keys  = true,
}

local ns_bar = vim.api.nvim_create_namespace("quickui_bar")
local ns_sc  = vim.api.nvim_create_namespace("quickui_shortcut")
local ns_sep = vim.api.nvim_create_namespace("quickui_separator")

-- ── state ─────────────────────────────────────────────────────────────────────
local S = {
  open       = false,
  menu_idx   = 1,
  prev_win   = nil,
  bar_win    = nil,
  bar_buf    = nil,
  drop_panel = nil,
  menus      = {},
  menu_cols  = {},
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

  local pad     = string.rep(" ", cfg.menubar_padding)
  local sep     = cfg.menubar_separator
  local line    = ""
  local cols    = {}
  local sep_positions = {}

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

  vim.api.nvim_buf_clear_namespace(S.bar_buf, ns_bar, 0, -1)
  local t = display_title(S.menus[S.menu_idx])
  local c = cols[S.menu_idx]
  local item_w = cfg.menubar_padding + #t + cfg.menubar_padding
  vim.api.nvim_buf_set_extmark(S.bar_buf, ns_bar, 0, c, {
    end_col  = c + item_w,
    hl_group = "QuickUIMenubarSel",
    priority = 100,
  })

  vim.api.nvim_buf_clear_namespace(S.bar_buf, ns_sep, 0, -1)
  for _, s in ipairs(sep_positions) do
    vim.api.nvim_buf_set_extmark(S.bar_buf, ns_sep, 0, s.col, {
      end_col  = s.col + s.len,
      hl_group = "QuickUIMenubarSeparator",
      priority = 100,
    })
  end

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

-- ── dropdown ──────────────────────────────────────────────────────────────────

local function close_drop()
  local p = S.drop_panel
  S.drop_panel = nil
  if p then p.close_silent() end
end

local function open_drop()
  close_drop()

  local menu      = S.menus[S.menu_idx]
  local opt       = { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }
  local raw_items = type(menu.items) == "function" and menu.items(opt) or menu.items
  local items     = panel.parse_items(raw_items, opt)
  if #items == 0 then return end

  local km = cfg.keymaps

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
        local c = mpos.wincol - 1
        for i = #S.menu_cols, 1, -1 do
          if c >= S.menu_cols[i] then S.menu_idx = i; M.move_menu(0); return end
        end
      else
        M.close()
      end
    end,
    on_no_submenu = function() M.move_menu(1) end,
  })

  -- bar-specific keymaps bound directly after panel creation
  local buf = S.drop_panel.buf
  if buf then
    local function kmap(key, fn)
      vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
    end
    local function bind(keys, fn)
      for _, k in ipairs(keys or {}) do kmap(k, fn) end
    end
    bind(km.menu_prev, function() M.move_menu(-1) end)
    bind(km.menu_next, function() M.move_menu(1)  end)
    local sc_reserved = util.reserved_keys(km, { "up", "down", "exec", "close", "submenu", "menu_prev", "menu_next" })
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
  S.menu_idx = 1
  S.open     = true

  cursor.hide()

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
  close_drop()

  if S.bar_win and vim.api.nvim_win_is_valid(S.bar_win) then
    vim.api.nvim_win_close(S.bar_win, true)
  end
  if S.bar_buf and vim.api.nvim_buf_is_valid(S.bar_buf) then
    vim.api.nvim_buf_delete(S.bar_buf, { force = true })
  end
  S.bar_win, S.bar_buf = nil, nil
  S.open               = false

  cursor.show()

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
  cfg.keymaps = util.resolve_keymaps(opts)
  if opts.suppress_all_keys ~= nil then cfg.suppress_all_keys = opts.suppress_all_keys end
end

return M
