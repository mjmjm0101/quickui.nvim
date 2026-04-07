--- Context menu for snacks.nvim explorer.
---
--- Setup: register this as a custom action in your Snacks.explorer config,
--- then map a key to it inside the explorer window.
---
---   require("snacks").setup({
---     explorer = {
---       actions = {
---         context_menu = function(picker, item)
---           if not item then return end
---           require("quickui").context_normal(
---             require("quickui-sample.context.snacks_explorer"),
---             {
---               path   = item.file,
---               -- item.is_dir may vary by snacks.nvim version;
---               -- fallback: vim.fn.isdirectory(item.file) == 1
---               is_dir = item.is_dir or vim.fn.isdirectory(item.file) == 1,
---             }
---           )
---         end,
---       },
---       keys = {
---         ["<Tab>"] = "context_menu",
---       },
---     },
---   })
---
--- The `path` and `is_dir` fields are passed via the `data` argument and are
--- available as `opt.path` and `opt.is_dir` in all cmd and conditions functions.

return {
    items = function(opt)
        local path   = opt.path or ""
        local is_dir = opt.is_dir or false
        local name   = vim.fn.fnamemodify(path, ":t")

        return {
            -- ── Open ─────────────────────────────────────────────────────────
            { name = string.format("&Open  %s", name),
              cmd = function() vim.cmd("e " .. vim.fn.fnameescape(path)) end,
              conditions = not is_dir },
            { name = "Open in &Split",
              cmd = function() vim.cmd("sp " .. vim.fn.fnameescape(path)) end,
              conditions = not is_dir },
            { name = "Open in &VSplit",
              cmd = function() vim.cmd("vsp " .. vim.fn.fnameescape(path)) end,
              conditions = not is_dir },
            { name = "Open in &Tab",
              cmd = function() vim.cmd("tabedit " .. vim.fn.fnameescape(path)) end,
              conditions = not is_dir },

            { name = "separator", conditions = not is_dir },

            -- ── New ──────────────────────────────────────────────────────────
            { name = "&New File...",
              cmd = function()
                  local dir = is_dir and path or vim.fn.fnamemodify(path, ":h")
                  vim.ui.input({ prompt = "New file: ", default = dir .. "/" }, function(input)
                      if input and input ~= "" then
                          vim.fn.mkdir(vim.fn.fnamemodify(input, ":h"), "p")
                          vim.cmd("e " .. vim.fn.fnameescape(input))
                          vim.cmd("w")
                      end
                  end)
              end },
            { name = "New &Directory...",
              cmd = function()
                  local dir = is_dir and path or vim.fn.fnamemodify(path, ":h")
                  vim.ui.input({ prompt = "New directory: ", default = dir .. "/" }, function(input)
                      if input and input ~= "" then
                          vim.fn.mkdir(input, "p")
                          vim.notify("Created: " .. input)
                      end
                  end)
              end },

            { name = "separator" },

            -- ── Rename / Delete ───────────────────────────────────────────────
            { name = "&Rename...",
              cmd = function()
                  vim.ui.input({ prompt = "Rename to: ", default = path }, function(input)
                      if input and input ~= "" and input ~= path then
                          vim.fn.rename(path, input)
                          vim.notify("Renamed → " .. vim.fn.fnamemodify(input, ":t"))
                      end
                  end)
              end },
            { name = "&Delete",
              cmd = function()
                  vim.ui.select({ "Yes", "No" },
                      { prompt = "Delete " .. name .. "?" },
                      function(choice)
                          if choice == "Yes" then
                              if is_dir then
                                  vim.fn.delete(path, "rf")
                              else
                                  vim.fn.delete(path)
                              end
                              vim.notify("Deleted: " .. name, vim.log.levels.WARN)
                          end
                      end)
              end,
              hl = "DiagnosticError" },

            { name = "separator" },

            -- ── Copy path ────────────────────────────────────────────────────
            { name = "Copy &Path",
              cmd = function()
                  vim.fn.setreg("+", path)
                  vim.notify("Copied: " .. path)
              end },
            { name = "Copy &Name",
              cmd = function()
                  vim.fn.setreg("+", name)
                  vim.notify("Copied: " .. name)
              end },
            { name = "Copy &Relative Path",
              cmd = function()
                  local rel = vim.fn.fnamemodify(path, ":.")
                  vim.fn.setreg("+", rel)
                  vim.notify("Copied: " .. rel)
              end },
        }
    end,
}
