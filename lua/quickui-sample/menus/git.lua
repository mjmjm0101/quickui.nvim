return {
    name     = "&Git",
    priority = 500,
    items = {
        { name = "&Status",          cmd = ":!git status<CR>" },
        { name = "&Diff",            cmd = ":!git diff<CR>" },
        { name = "separator" },
        { name = "&Stage",           items = {
            { name = "Stage &Current File", cmd = function()
                vim.cmd("!git add " .. vim.fn.expand("%"))
              end },
            { name = "Stage &All",          cmd = ":!git add -A<CR>" },
            { name = "&Unstage All",        cmd = ":!git reset HEAD<CR>" },
        }},
        { name = "&Commit...",       cmd = function()
            vim.ui.input({ prompt = "Commit message: " }, function(msg)
                if msg and msg ~= "" then
                    vim.cmd("!git commit -m " .. vim.fn.shellescape(msg))
                end
            end)
          end },
        { name = "separator" },
        { name = "&Push",            cmd = ":!git push<CR>",  rtxt = "push" },
        { name = "Pu&ll",            cmd = ":!git pull<CR>",  rtxt = "pull" },
        { name = "separator" },
        { name = "&Log",             cmd = ":!git log --oneline -20<CR>" },
        { name = "S&tash",           items = {
            { name = "Stash &Push",  cmd = ":!git stash push<CR>" },
            { name = "Stash &Pop",   cmd = ":!git stash pop<CR>" },
            { name = "Stash &List",  cmd = ":!git stash list<CR>" },
        }},
    },
}
