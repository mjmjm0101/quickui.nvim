return {
    name     = "&File",
    priority = 100,
    items = {
        { name = "&New File",        cmd = ":enew<CR>",             rtxt = "n" },
        { name = "&Open...",         cmd = ":e ",                   rtxt = "o" },
        { name = "Open &Recent",     items = {
            { name = "~/.config/nvim/init.lua", cmd = ":e ~/.config/nvim/init.lua<CR>" },
            { name = "~/.zshrc",                cmd = ":e ~/.zshrc<CR>" },
            { name = "~/.gitconfig",            cmd = ":e ~/.gitconfig<CR>" },
        }},
        { name = "separator" },
        { name = "&Save",            cmd = ":w<CR>",                rtxt = "Ctrl-S" },
        { name = "Save &As...",      cmd = ":saveas ",              rtxt = "Ctrl-Shift-S" },
        { name = "Save A&ll",        cmd = ":wa<CR>" },
        { name = "separator" },
        { name = "&Close",           cmd = ":bd<CR>",               rtxt = "Ctrl-W" },
        { name = "&Quit",            cmd = ":qa<CR>",               rtxt = "q" },
    },
}
