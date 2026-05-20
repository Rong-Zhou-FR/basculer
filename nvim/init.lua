-- Set <space> as the leader key
-- See `:help mapleader`
-- NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '

-- [[ Setting options ]] See `:h vim.o`
-- NOTE: You can change these options as you wish!
-- For more options, you can see `:help option-list`
-- To see documentation for an option, you can use `:h 'optionname'`, for example `:h 'number'`
-- (Note the single quotes)

-- Print the line number in front of each line
vim.o.number = true

-- Use relative line numbers, so that it is easier to jump with j, k. This will affect the 'number'
-- option above, see `:h number_relativenumber`
vim.o.relativenumber = true

-- Sync clipboard between OS and Neovim. Schedule the setting after `UiEnter` because it can
-- increase startup-time. Remove this option if you want your OS clipboard to remain independent.
-- See `:help 'clipboard'`
vim.api.nvim_create_autocmd('UIEnter', {
  callback = function()
    vim.o.clipboard = 'unnamedplus'
  end,
})

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Highlight the line where the cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- Show <tab> and trailing spaces
vim.o.list = true

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s) See `:help 'confirm'`
vim.o.confirm = true

-- [[ Set up keymaps ]] See `:h vim.keymap.set()`, `:h mapping`, `:h keycodes`

-- Use <Esc> to exit terminal mode
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>')

-- Map <A-j>, <A-k>, <A-h>, <A-l> to navigate between windows in any modes
vim.keymap.set({ 't', 'i' }, '<A-h>', '<C-\\><C-n><C-w>h')
vim.keymap.set({ 't', 'i' }, '<A-j>', '<C-\\><C-n><C-w>j')
vim.keymap.set({ 't', 'i' }, '<A-k>', '<C-\\><C-n><C-w>k')
vim.keymap.set({ 't', 'i' }, '<A-l>', '<C-\\><C-n><C-w>l')
vim.keymap.set({ 'n' }, '<A-h>', '<C-w>h')
vim.keymap.set({ 'n' }, '<A-j>', '<C-w>j')
vim.keymap.set({ 'n' }, '<A-k>', '<C-w>k')
vim.keymap.set({ 'n' }, '<A-l>', '<C-w>l')

-- [[ Basic Autocommands ]].
-- See `:h lua-guide-autocommands`, `:h autocmd`, `:h nvim_create_autocmd()`

-- Highlight when yanking (copying) text.
-- Try it with `yap` in normal mode. See `:h vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  callback = function()
    vim.hl.on_yank()
  end,
})

-- [[ Create user commands ]]
-- See `:h nvim_create_user_command()` and `:h user-commands`

-- Create a command `:GitBlameLine` that print the git blame for the current line
vim.api.nvim_create_user_command('GitBlameLine', function()
  local line_number = vim.fn.line('.') -- Get the current line number. See `:h line()`
  local filename = vim.api.nvim_buf_get_name(0)
  print(vim.fn.system({ 'git', 'blame', '-L', line_number .. ',+1', filename }))
end, { desc = 'Print the git blame for the current line' })

-- [[ Add optional packages ]]
-- Nvim comes bundled with a set of packages that are not enabled by
-- default. You can enable any of them by using the `:packadd` command.

-- For example, to add the "nohlsearch" package to automatically turn off search highlighting after
-- 'updatetime' and when going to insert mode
vim.cmd('packadd! nohlsearch')

-- use 2 space for tab
-- Force override after filetype plugins
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.expandtab = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "arduino", "ino" },
  callback = function()
    vim.opt_local.formatoptions:remove({ "r", "o" })
  end,
})

vim.filetype.add({
  extension = {
    enc = "enc",
  },
})

vim.api.nvim_create_user_command("EncPreprocess", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")

  -- Convert display math \[...\] -> $$...$$
  text = text:gsub("\\%[(.-)\\%]", "$$%1$$")

  -- Convert inline math \(...\) -> $...$
  text = text:gsub("\\%((.-)\\%)", "$%1$")

  -- Rewrite CDN paths
  text = text:gsub(
    "/home/rongzhou/kodo/ronzz%-CDN%-2/",
    "https://raw.githubusercontent.com/Ron-RONZZ-org/ronzz-CDN-2/refs/heads/main/"
  )
  text = text:gsub(
    "%./kodo/ronzz%-CDN%-2/",
    "https://raw.githubusercontent.com/Ron-RONZZ-org/ronzz-CDN-2/refs/heads/main/"
  )
  text = text:gsub(
    "%.%./kodo/ronzz%-CDN%-2/",
    "https://raw.githubusercontent.com/Ron-RONZZ-org/ronzz-CDN-2/refs/heads/main/"
  )  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.cmd("update")
  vim.fn.setreg("+", vim.fn.expand("%:p")) -- copy file basename to clipboard: use %:t for base name, %:p for full path
end, {})

vim.api.nvim_create_user_command("EP", function()
  vim.cmd("EncPreprocess")
end, {})

-- Load Lazy.nvim
vim.opt.rtp:prepend("~/.local/share/nvim/lazy/lazy.nvim")

require("lazy").setup({
  -- Comment.nvim plugin
  {
    "numToStr/Comment.nvim",
    opts = {},
  },
})

vim.opt.undofile = true

-- Smart shfmt format on save, maintaing cursor position
vim.api.nvim_create_autocmd("BufWritePost", {  -- Note: Post, not Pre
  pattern = {"*.sh", "*.bash"},
  callback = function()
    local filename = vim.api.nvim_buf_get_name(0)
    local view = vim.fn.winsaveview()
    
    -- Format the file on disk after saving
    os.execute("shfmt -i 2 -w " .. vim.fn.shellescape(filename))
    
    -- Reload the formatted version silently
    vim.cmd("edit!")
    
    pcall(vim.fn.winrestview, view)
  end,
})

require('markdown').setup()
