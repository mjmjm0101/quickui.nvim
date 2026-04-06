--- Centralised cursor-visibility manager for quickui.nvim.
--- All cursor hide/show operations go through this module.
local M = {
  hidden  = false,
  saved   = nil,
  enabled = true,
}

function M.setup(opts)
  opts = opts or {}
  M.enabled = opts.hide_cursor ~= false  -- default: true

  if not M.enabled then return end

  vim.api.nvim_set_hl(0, "QuickUICursorHidden", { blend = 100, nocombine = true })

  vim.api.nvim_create_autocmd({ "BufLeave", "VimLeavePre" }, {
    group    = vim.api.nvim_create_augroup("quickui_cursor", { clear = true }),
    callback = function() M.show() end,
  })
end

function M.hide()
  if not M.enabled or M.hidden then return end
  M.saved  = vim.o.guicursor
  vim.o.guicursor = "a:block-QuickUICursorHidden/lCursor"
  M.hidden = true
end

function M.show()
  if not M.hidden then return end
  vim.o.guicursor = M.saved
  M.hidden = false
end

return M
