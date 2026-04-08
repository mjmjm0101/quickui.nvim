local M = {}

--- Parse a menu item name string.
--- Handles: "&shortcut", "%{expr}", "separator"
---@param label string
---@return table { separator, display, shortcut, shortcut_col }
function M.parse_label(label)
  if not label or label == "separator" or label:match("^%-%-") then
    return { separator = true, display = "──" }
  end

  -- Evaluate %{expr} patterns (e.g. "Set Spell %{&spell?'Off':'On'}")
  local left = label:gsub("%%{([^}]+)}", function(expr)
    local ok, val = pcall(vim.fn.eval, expr)
    return ok and tostring(val) or ""
  end)

  -- Find & position before removing it
  local amp_pos = left:find("&%a")
  local display, shortcut, shortcut_col
  if amp_pos then
    local prefix = left:sub(1, amp_pos - 1)
    shortcut     = left:sub(amp_pos + 1, amp_pos + 1):lower()
    shortcut_col = vim.fn.strdisplaywidth(prefix)
    display      = prefix .. left:sub(amp_pos + 1)
  else
    display = left
  end

  return {
    separator    = false,
    display      = display,
    shortcut     = shortcut,
    shortcut_col = shortcut_col,
  }
end

--- Check item-level conditions. conditions can be: nil/true → show, false → hide, function(opt) → call.
function M.item_conditions(item, opt)
  local c = item.conditions
  if c == nil or c == true then return true end
  if c == false then return false end
  if type(c) == "function" then return c(opt) ~= false end
  return true
end

--- Check if a filetype filter matches the given filetype.
--- nil means always match.
function M.ft_match(ft, cur)
  if not ft then return true end
  for _, f in ipairs(vim.split(ft, ",")) do
    if vim.trim(f) == cur then return true end
  end
  return false
end

--- Resolve border option to a value accepted by nvim_open_win.
function M.resolve_border(border)
  if border == "none" then
    return "solid"
  elseif border == "dotted" then
    return { "┌", "╌", "┐", "╎", "┘", "╌", "└", "╎" }
  elseif border == "dashed" then
    return { "┌", "┄", "┐", "┆", "┘", "┄", "└", "┆" }
  else
    return border
  end
end

-- ── keymap helpers ───────────────────────────────────────────────────────────

--- Default keybinding configuration for all quickui windows.
--- Each value is a list of keys that trigger that action.
M.default_keymaps = {
  up        = { "k", "<Up>" },
  down      = { "j", "<Down>" },
  exec      = { "<CR>" },
  close     = { "<Esc>", "q" },
  submenu   = { "<Tab>", "<Right>" },  -- open submenu (popup / submenu)
  back      = { "<Left>", "<BS>", "<S-Tab>" }, -- close submenu and return to parent
  menu_prev = { "h" },                 -- bar: move to previous menu
  menu_next = { "l" },                 -- bar: move to next menu
  mouse     = { "<LeftMouse>" },
}

--- Merge user keymaps with defaults.
---@param opts table  { keymaps?, disable_default_keymaps? }
---@return table
function M.resolve_keymaps(opts)
  local user_km = opts.keymaps or {}
  if opts.disable_default_keymaps then
    return user_km
  end
  return vim.tbl_extend("force", vim.deepcopy(M.default_keymaps), user_km)
end

--- Suppress all global keymaps in a buffer by mapping every common key to <Nop>.
--- Call this BEFORE setting plugin-specific keymaps so they will override.
function M.suppress_keys(buf)
  local opts = { buffer = buf, nowait = true, silent = true }
  -- Printable ASCII 32 (space) through 126 (~)
  for byte = 32, 126 do
    local ch = byte == 60 and "<lt>" or string.char(byte)  -- '<' needs <lt>
    pcall(vim.keymap.set, "n", ch, "<Nop>", opts)
  end
  -- Common special keys
  for _, k in ipairs({
    "<CR>", "<Esc>", "<Tab>", "<BS>", "<Del>",
    "<Up>", "<Down>", "<Left>", "<Right>",
    "<PageUp>", "<PageDown>", "<Home>", "<End>", "<Insert>",
    "<F1>", "<F2>", "<F3>", "<F4>", "<F5>", "<F6>",
    "<F7>", "<F8>", "<F9>", "<F10>", "<F11>", "<F12>",
    "<S-Tab>", "<LeftMouse>", "<RightMouse>", "<MiddleMouse>",
  }) do
    pcall(vim.keymap.set, "n", k, "<Nop>", opts)
  end
end

--- Build a set of single-char reserved keys from given keymap actions.
--- Used to prevent item shortcuts from conflicting with navigation keys.
function M.reserved_keys(km, action_names)
  local r = {}
  for _, action in ipairs(action_names) do
    for _, key in ipairs(km[action] or {}) do
      if #key == 1 then r[key] = true end
    end
  end
  return r
end

--- Execute a command: string → vim.cmd, function → call with opt
---@param cmd string|function
---@param opt table|nil  Context passed to function commands (filetype, cwd, item)
function M.exec(cmd, opt)
  if type(cmd) == "function" then
    cmd(opt)
  elseif type(cmd) == "string" and cmd ~= "" then
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes(cmd, true, false, true), "n")
  end
end

return M
