--- Internal floating window renderer used by context_normal / context_visual.
--- Not part of the public API.
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

---@param items       table         List of parsed items
---@param opts        table         Display options: { cursor?, row?, col? }
---@param opt         table|nil     Context passed to cmd functions (filetype, cwd, …)
---@param after_close function|nil  Called after the popup closes and focus is restored
function M.open(items, opts, opt, after_close)
  opts = opts or {}
  opt  = opt  or { filetype = vim.bo.filetype, cwd = vim.fn.getcwd() }

  local parsed = panel.parse_items(items, opt)
  if #parsed == 0 then return end

  local prev_win = vim.api.nvim_get_current_win()

  local anchor
  if opts.cursor then
    anchor = { cursor = true }
  else
    anchor = { row = opts.row, col = opts.col }
  end

  local ctl
  local function restore_all()
    if ctl then ctl.close_silent() end
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
    if after_close then after_close() end
  end

  ctl = panel.open(parsed, anchor, {
    border            = cfg.border,
    winblend          = cfg.winblend,
    zindex            = 250,
    keymaps           = cfg.keymaps,
    suppress_all_keys = cfg.suppress_all_keys,
    close_on_leave    = true,
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
