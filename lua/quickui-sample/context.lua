--- Context menu sample — showcases submenus, per-item highlights, ft filters,
--- conditions, key keybindings, and right-aligned text.

return {
    items = function(opt)
        return {
            -- ── LSP ──────────────────────────────────────────────────────────
            { name = "&LSP Actions",     items = {
                -- key only: "<C-a>" shown as hint and active inside the submenu
                { name = "&Code Action",      cmd = function() vim.lsp.buf.code_action() end,
                  key = "<C-a>",  hl = "DiagnosticInfo" },
                -- rtxt overrides key display
                { name = "&Rename Symbol",    cmd = function() vim.lsp.buf.rename() end,
                  key = "<C-r>",  rtxt = "rn" },
                { name = "Go to &Definition", cmd = function() vim.lsp.buf.definition() end,
                  rtxt = "gd" },
                { name = "Find &References",  cmd = function() vim.lsp.buf.references() end,
                  rtxt = "gr" },
                { name = "separator" },
                { name = "&Hover Docs",       cmd = function() vim.lsp.buf.hover() end,
                  rtxt = "K" },
                { name = "&Signature Help",   cmd = function() vim.lsp.buf.signature_help() end },
            }},

            -- ── Format ───────────────────────────────────────────────────────
            -- key only: "<C-f>" shown as right-aligned hint
            { name = "&Format Buffer",   cmd = function() vim.lsp.buf.format({ async = true }) end,
              key = "<C-f>",  hl = "DiagnosticHint" },

            { name = "separator" },

            -- ── Diagnostics ──────────────────────────────────────────────────
            { name = "&Diagnostics",     items = {
                { name = "&Next Error",       cmd = function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR }) end,
                  hl = "DiagnosticError" },
                { name = "&Prev Error",       cmd = function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR }) end,
                  hl = "DiagnosticError" },
                { name = "separator" },
                { name = "Next &Warning",     cmd = function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN }) end,
                  hl = "DiagnosticWarn" },
                { name = "Prev W&arning",     cmd = function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN }) end,
                  hl = "DiagnosticWarn" },
                { name = "separator" },
                { name = "Show &Line Diag",   cmd = function() vim.diagnostic.open_float() end },
            }},

            { name = "separator" },

            -- ── Edit ─────────────────────────────────────────────────────────
            { name = "&Edit",            items = {
                -- rtxt overrides key display
                { name = "&Copy Line",        cmd = "yy",       key = "<C-c>", rtxt = "yy" },
                { name = "Copy &All",         cmd = ":%y+<CR>", rtxt = "%y+" },
                { name = "separator" },
                { name = "D&uplicate Line",   cmd = "yyp" },
                { name = "&Delete Line",      cmd = "dd",       rtxt = "dd" },
                { name = "separator" },
                { name = "&Indent",           cmd = ">>",       rtxt = ">>" },
                { name = "De&dent",           cmd = "<<",       rtxt = "<<" },
            }},
            -- rtxt="" suppresses display; <C-y> is still active
            { name = "&Yank to Clipboard",    cmd = '"+yy',  key = "<C-y>", rtxt = "" },
            -- key only: "<C-v>" shown as hint
            { name = "&Paste from Clipboard", cmd = '"+p',   key = "<C-v>" },

            { name = "separator" },

            -- ── Filetype-specific (Lua only) ──────────────────────────────
            { name = "Run &Lua File",    cmd = ":source %<CR>",
              ft = "lua",  hl = "DiagnosticHint" },
            { name = "Check &Syntax",    cmd = ":luafile %<CR>",
              ft = "lua" },

            -- ── Filetype-specific (Markdown only) ────────────────────────
            { name = "&Preview Markdown",cmd = function()
                vim.cmd("!open %")
              end,
              ft = "markdown",  hl = "DiagnosticInfo" },

            { name = "separator",
              conditions = function(opt)
                  return opt.filetype == "lua" or opt.filetype == "markdown"
              end },

            -- ── Danger zone ───────────────────────────────────────────────
            { name = "Danger &Zone",     items = {
                { name = "Close &Buffer",      cmd = ":bd<CR>",
                  hl = "DiagnosticWarn" },
                { name = "Close &All Buffers", cmd = ":%bd<CR>",
                  hl = "DiagnosticWarn" },
                { name = "separator" },
                { name = "Delete &File",       cmd = function()
                    local path = vim.fn.expand("%:p")
                    vim.cmd("bd!")
                    vim.fn.delete(path)
                    vim.notify("Deleted: " .. path, vim.log.levels.WARN)
                  end,
                  hl = "DiagnosticError" },
            }},
        }
    end,
}
