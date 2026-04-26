local M = {}

-- Default highlight links
local defaults = {
  menubar           = { link = "StatusLine" },
  menubar_sel       = { link = "PmenuSel" },
  menubar_separator = { link = "NonText" },
  menubar_indicator = { link = "WarningMsg" },
  menu              = { link = "Normal" },
  menu_border       = { link = "FloatBorder" },
  menu_sel          = { link = "PmenuSel" },
  accent            = { link = "Special" },
  rtxt              = { link = "Special" },
  key               = { link = "Special" },
}

-- Map from option key to highlight group name
local hl_names = {
  menubar           = "QuickUIMenubar",
  menubar_sel       = "QuickUIMenubarSel",
  menubar_separator = "QuickUIMenubarSeparator",
  menubar_indicator = "QuickUIMenubarIndicator",
  menu              = "QuickUIMenu",
  menu_border       = "QuickUIMenuBorder",
  menu_sel          = "QuickUIMenuSel",
  accent            = "QuickUIMenuAccent",
  rtxt              = "QuickUIMenuRtxt",
  key               = "QuickUIMenuKey",
}

--- Setup highlight groups.
--- @param overrides table|nil
---   accent      string          e.g. "#89b4fa"  (fg color only)
---   rtxt        string          e.g. "#a6e3a1"  (fg color only)
---   key         string          e.g. "#f9e2af"  (fg color only)
---   others      table           nvim_set_hl-compatible table ({ bg=, fg=, link=, ... })
function M.setup(overrides)
  overrides = overrides or {}

  -- accent/rtxt/key accept a plain color string as shorthand for { fg = color }
  if type(overrides.accent) == "string" then
    overrides.accent = { fg = overrides.accent }
  end
  if type(overrides.rtxt) == "string" then
    overrides.rtxt = { fg = overrides.rtxt }
  end
  if type(overrides.key) == "string" then
    overrides.key = { fg = overrides.key }
  end

  -- Visual selection overlay used by context_visual()
  vim.api.nvim_set_hl(0, "QuickUIVisualSel", { default = true, link = "Visual" })

  -- Cursor highlight used by the bar window to keep the cursor invisible
  vim.api.nvim_set_hl(0, "QuickUIBarCursor", { default = true, blend = 100, nocombine = true })

  for key, name in pairs(hl_names) do
    local spec = vim.tbl_extend("force", { default = true }, defaults[key], overrides[key] or {})
    -- If user provides color attrs, remove the default link so it doesn't conflict
    if overrides[key] and not overrides[key].link then
      spec.link = nil
    end
    vim.api.nvim_set_hl(0, name, spec)
  end
end

return M