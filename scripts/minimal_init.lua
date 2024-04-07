-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])
vim.cmd('set rtp+=deps/plenary.nvim')
vim.cmd('set rtp+=deps/harpoon')

-- Set up 'mini.test' only when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() == 0 then
  -- Add 'mini.nvim' to 'runtimepath' to be able to use 'mini.test'
  vim.cmd('set rtp+=deps/mini.nvim')

  -- Set up 'mini.test'
  require('mini.test').setup()
end
