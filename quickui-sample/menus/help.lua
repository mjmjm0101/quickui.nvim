return {
    name     = "&@Help",
    priority = 10000,
    items = {
        { name = "quickui &Keymaps",  cmd = ":help quickui-keybindings<CR>" },
        { name = "quickui &Options",  cmd = ":help quickui-options<CR>" },
        { name = "separator" },
        { name = "&Neovim Help",      cmd = ":help<CR>",           rtxt = ":h" },
        { name = "Neovim &Changelog", cmd = ":help nvim-changelog<CR>" },
        { name = "separator" },
        { name = "&About quickui.nvim", cmd = function()
            vim.notify(
                "quickui.nvim\ngithub.com/mjmjm0101/quickui.nvim",
                vim.log.levels.INFO,
                { title = "About" }
            )
          end },
    },
}
