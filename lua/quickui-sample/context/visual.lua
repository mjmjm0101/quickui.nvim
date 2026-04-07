--- Visual-mode context menu sample.
--- Called via context_visual(); opt.selection is populated automatically.
---
--- String cmd values run in normal mode after the menu closes.
--- Use the "gv" prefix to re-enter the visual selection before operating on it
--- (e.g. "gvU" uppercases the selection, "gv>" indents it).

return {
    items = function(opt)
        local sel     = opt.selection
        local preview = sel and sel.text:sub(1, 28):gsub("\n", "↵") or ""

        return {
            -- ── Selection preview (non-executable) ───────────────────────────
            { name = string.format('"%s"', preview),
              cmd = "",  hl = "Comment" },

            { name = "separator" },

            -- ── Case ─────────────────────────────────────────────────────────
            { name = "&Uppercase",         cmd = "gvU" },
            { name = "&Lowercase",         cmd = "gvu" },
            { name = "&Toggle Case",       cmd = "gv~" },

            { name = "separator" },

            -- ── Clipboard ────────────────────────────────────────────────────
            -- gv reselects the last visual region, then "+y yanks to clipboard
            { name = "Yank to &Clipboard", cmd = '"+gvy' },
            { name = "&Delete",            cmd = "gvd",  hl = "DiagnosticWarn" },

            { name = "separator" },

            -- ── Indent ───────────────────────────────────────────────────────
            { name = "&Indent",            cmd = "gv>" },
            { name = "De&dent",            cmd = "gv<" },

            { name = "separator" },

            -- ── Line-wise only ───────────────────────────────────────────────
            { name = "&Sort Lines",        cmd = "gv:sort<CR>",
              conditions = function(o) return o.selection and o.selection.mode == "V" end },
            { name = "Sort Lines (&Reverse)", cmd = "gv:sort!<CR>",
              conditions = function(o) return o.selection and o.selection.mode == "V" end },

            { name = "separator",
              conditions = function(o) return o.selection and o.selection.mode == "V" end },

            -- ── LSP (range) ──────────────────────────────────────────────────
            -- '< / '> marks remain valid after the menu closes
            { name = "&Format Selection",  cmd = function()
                local s = vim.fn.getpos("'<")
                local e = vim.fn.getpos("'>")
                vim.lsp.buf.format({ async = true, range = {
                    ["start"] = { s[2], s[3] - 1 },
                    ["end"]   = { e[2], e[3] },
                } })
              end },
            { name = "Code &Action",       cmd = function() vim.lsp.buf.code_action() end,
              hl = "DiagnosticInfo" },
        }
    end,
}
