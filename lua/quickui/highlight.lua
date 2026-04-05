local M = {}

-- Default highlight links
local defaults = {
  menubar           = { link = "StatusLine" },
  menubar_sel       = { link = "PmenuSel" },
  menubar_separator = { link = "NonText" },
  menu              = { link = "Normal" },
  menu_border       = { link = "FloatBorder" },
  menu_sel          = { link = "PmenuSel" },
  accent            = { link = "Special" },
  rtxt              = { link = "Special" },
}

-- Map from option key to highlight group name
local hl_names = {
  menubar           = "QuickUIMenubar",
  menubar_sel       = "QuickUIMenubarSel",
  menubar_separator = "QuickUIMenubarSeparator",
  menu              = "QuickUIMenu",
  menu_border       = "QuickUIMenuBorder",
  menu_sel          = "QuickUIMenuSel",
  accent            = "QuickUIMenuAccent",
  rtxt              = "QuickUIMenuRtxt",
}

--- Setup highlight groups.
--- @param overrides table|nil
---   accent      string          e.g. "#89b4fa"  (fg color only)
---   rtxt        string          e.g. "#a6e3a1"  (fg color only)
---   others      table           nvim_set_hl-compatible table ({ bg=, fg=, link=, ... })
function M.setup(overrides)
  overrides = overrides or {}

  -- accent/rtxt accept a plain color string as shorthand for { fg = color }
  if type(overrides.accent) == "string" then
    overrides.accent = { fg = overrides.accent }
  end
  if type(overrides.rtxt) == "string" then
    overrides.rtxt = { fg = overrides.rtxt }
  end

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