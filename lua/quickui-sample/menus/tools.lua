return {
    name     = "&Tools",
    priority = 400,
    items = {
        -- key only: "<C-f>" shown as right-aligned hint
        { name = "&Format Buffer",   cmd = function() vim.lsp.buf.format({ async = true }) end,
          key = "<C-f>" },
        { name = "&Lint",            cmd = ":make<CR>" },
        { name = "separator" },
        { name = "&LSP",             items = {
            -- key only: shown as hint and active inside the submenu
            { name = "&Code Action",      cmd = function() vim.lsp.buf.code_action() end,    key = "<C-a>" },
            { name = "&Rename Symbol",    cmd = function() vim.lsp.buf.rename() end,         key = "<C-r>" },
            -- rtxt overrides key display
            { name = "Go to &Definition", cmd = function() vim.lsp.buf.definition() end,     key = "<C-]>", rtxt = "gd" },
            { name = "Find &References",  cmd = function() vim.lsp.buf.references() end,     rtxt = "gr" },
            { name = "separator" },
            { name = "Restart &LSP",      cmd = function() vim.cmd("LspRestart") end },
        }},
        { name = "separator" },
        { name = "&Terminal",        cmd = ":terminal<CR>",  key = "<C-t>" },
        -- rtxt="" suppresses display; <C-m> is still active
        { name = "Run &Make",        cmd = ":make<CR>",      key = "<C-m>", rtxt = "" },
        { name = "separator" },
        { name = "Reload &Config",   cmd = function()
            vim.cmd("source $MYVIMRC")
            vim.notify("Config reloaded", vim.log.levels.INFO)
          end },
    },
}
