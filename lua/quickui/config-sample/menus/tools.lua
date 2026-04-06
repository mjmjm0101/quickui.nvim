return {
    name     = "&Tools",
    priority = 400,
    items = {
        { name = "&Format Buffer",   cmd = function() vim.lsp.buf.format({ async = true }) end },
        { name = "&Lint",            cmd = ":make<CR>" },
        { name = "separator" },
        { name = "&LSP",             items = {
            { name = "&Code Action",     cmd = function() vim.lsp.buf.code_action() end,    rtxt = "ca" },
            { name = "&Rename Symbol",   cmd = function() vim.lsp.buf.rename() end,         rtxt = "rn" },
            { name = "Go to &Definition",cmd = function() vim.lsp.buf.definition() end,     rtxt = "gd" },
            { name = "Find &References", cmd = function() vim.lsp.buf.references() end,     rtxt = "gr" },
            { name = "separator" },
            { name = "Restart &LSP",    cmd = function() vim.cmd("LspRestart") end },
        }},
        { name = "separator" },
        { name = "&Terminal",        cmd = ":terminal<CR>" },
        { name = "Run &Make",        cmd = ":make<CR>",  rtxt = ":make" },
        { name = "separator" },
        { name = "Reload &Config",   cmd = function()
            vim.cmd("source $MYVIMRC")
            vim.notify("Config reloaded", vim.log.levels.INFO)
          end },
    },
}
