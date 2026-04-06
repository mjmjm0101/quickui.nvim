return {
    name     = "&File",
    priority = 100,
    items = {
        -- key only: "<C-n>" shown as right-aligned hint and active as in-menu binding
        { name = "&New File",        cmd = ":enew<CR>",    key = "<C-n>" },
        { name = "&Open...",         cmd = ":e ",          key = "<C-o>" },
        { name = "Open &Recent",     items = {
            { name = "~/.config/nvim/init.lua", cmd = ":e ~/.config/nvim/init.lua<CR>" },
            { name = "~/.zshrc",                cmd = ":e ~/.zshrc<CR>" },
            { name = "~/.gitconfig",            cmd = ":e ~/.gitconfig<CR>" },
        }},
        { name = "separator" },
        -- key only: "<C-s>" shown as right-aligned hint
        { name = "&Save",            cmd = ":w<CR>",       key = "<C-s>" },
        -- rtxt overrides key display; key still triggers the item
        { name = "Save &As...",      cmd = ":saveas ",     key = "<C-S-s>", rtxt = "Ctrl-Shift-S" },
        { name = "Save A&ll",        cmd = ":wa<CR>" },
        { name = "separator" },
        -- rtxt="" suppresses display; <C-w> is still active
        { name = "&Close",           cmd = ":bd<CR>",      key = "<C-w>", rtxt = "" },
        -- rtxt overrides key display
        { name = "&Quit",            cmd = ":qa<CR>",      key = "<C-q>", rtxt = "Ctrl-Q" },
    },
}
