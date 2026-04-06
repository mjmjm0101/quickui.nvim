return {
    name     = "&View",
    priority = 300,
    items = {
        { name = "&Line Numbers",    cmd = function() vim.wo.number = not vim.wo.number end,
          rtxt = "%{&number?'on':'off'}" },
        { name = "&Relative Numbers",cmd = function() vim.wo.relativenumber = not vim.wo.relativenumber end,
          rtxt = "%{&relativenumber?'on':'off'}" },
        { name = "&Word Wrap",       cmd = function()
            vim.wo.wrap = not vim.wo.wrap
          end,
          rtxt = "%{&wrap?'on':'off'}" },
        { name = "separator" },
        { name = "&Splits",          items = {
            { name = "Split &Horizontal",  cmd = ":sp<CR>",   rtxt = "Ctrl-W s" },
            { name = "Split &Vertical",    cmd = ":vsp<CR>",  rtxt = "Ctrl-W v" },
            { name = "&Close Split",       cmd = ":q<CR>",    rtxt = "Ctrl-W q" },
            { name = "separator" },
            { name = "Move &Left",         cmd = "<C-w>H" },
            { name = "Move &Right",        cmd = "<C-w>L" },
        }},
        { name = "separator" },
        { name = "&Spell Check",     cmd = function()
            vim.wo.spell = not vim.wo.spell
          end,
          rtxt = "%{&spell?'on':'off'}" },
        { name = "Show &Whitespace", cmd = function()
            vim.wo.list = not vim.wo.list
          end,
          rtxt = "%{&list?'on':'off'}" },
    },
}
