--- Shared floating window used by both context_open() and listbox_open().
local M = {}
local util  = require("quickui.util")
local panel = require("quickui.menu_panel")

local cfg = {
  border            = "single",
  winblend          = 40,
  keymaps           = vim.deepcopy(util.default_keymaps),
  suppress_all_keys = true,
}

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
  local parsed = panel.parse_items(items, opt)
  if #parsed == 0 then return end

  local prev_win = vim.api.nvim_get_current_win()

  local anchor
  if opts.cursor then
    anchor = { cursor = true }
  else
    anchor = { row = opts.row, col = opts.col }
  end

  local title_w = opts.title and (vim.fn.strdisplaywidth(opts.title) + 4) or 0

  local ctl
  local function restore_all()
    if ctl then ctl.close_silent() end
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
  end

  ctl = panel.open(parsed, anchor, {
    border            = cfg.border,
    winblend          = cfg.winblend,
    zindex            = 250,
    keymaps           = cfg.keymaps,
    suppress_all_keys = cfg.suppress_all_keys,
    title             = opts.title,
    close_on_leave    = true,
    min_width         = math.max(opts.width or 0, title_w),
  }, opt, {
    on_exec  = restore_all,
    on_close = restore_all,
  })
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
  cfg.keymaps = util.resolve_keymaps(opts)
  if opts.suppress_all_keys ~= nil then cfg.suppress_all_keys = opts.suppress_all_keys end
end

return M
