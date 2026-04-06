return {
    name     = "&Edit",
    priority = 200,
    items = {
        { name = "&Undo",            cmd = "u",       rtxt = "u" },
        { name = "&Redo",            cmd = "<C-r>",   rtxt = "Ctrl-R" },
        { name = "separator" },
        { name = "Cu&t",             cmd = '"+d',     rtxt = "Ctrl-X" },
        { name = "&Copy",            cmd = '"+y',     rtxt = "Ctrl-C" },
        { name = "&Paste",           cmd = '"+p',     rtxt = "Ctrl-V" },
        { name = "Select &All",      cmd = "ggVG" },
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
