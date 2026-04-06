return {
    name     = "&Edit",
    priority = 200,
    items = {
        -- key only: "<C-z>" shown as right-aligned hint
        { name = "&Undo",            cmd = "u",            key = "<C-z>" },
        -- rtxt overrides key display
        { name = "&Redo",            cmd = "<C-r>",        key = "<C-r>", rtxt = "Ctrl-R" },
        { name = "separator" },
        { name = "Cu&t",             cmd = '"+d',          key = "<C-x>" },
        { name = "&Copy",            cmd = '"+y',          key = "<C-c>" },
        { name = "&Paste",           cmd = '"+p',          key = "<C-v>" },
        -- rtxt="" suppresses display; <C-a> is still active
        { name = "Select &All",      cmd = "ggVG",         key = "<C-a>", rtxt = "" },
        { name = "separator" },
        { name = "&Find",            items = {
            { name = "&Search...",          cmd = "/",         rtxt = "/" },
            { name = "Search &Word",        cmd = "*",         rtxt = "*" },
            { name = "&Replace...",         cmd = ":%s/",      rtxt = ":s" },
            { name = "Find in &Files",      cmd = ":grep ",    rtxt = "gr" },
        }},
        { name = "separator" },
        { name = "Toggle &Comment",  cmd = "gcc" },
        { name = "&Join Lines",      cmd = "J" },
    },
}
