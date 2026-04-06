--- quickui.nvim sample configuration
--- Usage: add the following to your init.lua or plugin spec
---
---   require("quickui-sample")
---
--- Make sure quickui.nvim is loaded first.

local quickui = require("quickui")
local m = "quickui-sample.menus"

quickui.setup({
    keymap = "<Space>",
    border = "single",
    winblend = { bar = 0, menu = 10 },
    menubar_padding = 2,
    menubar_separator = "│",

    highlights = {
        accent            = "#89b4fa",
        rtxt              = "#6c7086",
        menu              = { bg = "#1e1e2e", fg = "#cdd6f4" },
        menu_sel          = { bg = "#45475a", fg = "#cdd6f4" },
        menu_border       = { fg = "#89b4fa" },
        menubar           = { bg = "#181825", fg = "#cdd6f4" },
        menubar_sel       = { bg = "#313244", fg = "#89b4fa" },
        menubar_separator = { fg = "#45475a", bg = "#181825" },
    },

    menus = {
        require(m .. ".file"),
        require(m .. ".edit"),
        require(m .. ".view"),
        require(m .. ".tools"),
        require(m .. ".git"),
        require(m .. ".help"),
    },
})

-- Context menu (Tab in normal mode)
local ctx = require("quickui-sample.context")
vim.keymap.set("n", "<Tab>", function()
    quickui.context_open(ctx)
end, { noremap = true, silent = true, desc = "Open context menu" })
