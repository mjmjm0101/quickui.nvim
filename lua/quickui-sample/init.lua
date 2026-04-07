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

-- Context menus (Tab in normal / visual mode)
local ctx_normal = require("quickui-sample.context.normal")
local ctx_visual = require("quickui-sample.context.visual")

vim.keymap.set("n", "<Tab>", function()
    quickui.context_normal(ctx_normal)
end, { noremap = true, silent = true, desc = "Open context menu" })
vim.keymap.set("x", "<Tab>", function()
    quickui.context_visual(ctx_visual)
end, { noremap = true, silent = true, desc = "Open context menu (visual)" })

-- Snacks explorer context menu (see context/snacks_explorer.lua for setup instructions)
