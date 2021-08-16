local M = {}

local function blameLinechars()
  local chars = vim.fn.strlen(
    vim.fn.substitute(vim.fn.matchstr(vim.fn.getline ".", [[.\{-\}\s\+\d\+\ze)]]), [[\v\C.]], ".", "g")
  )
  if vim.fn.exists "*synconcealed" and vim.wo.conceallevel > 1 then
    for col = 1, chars do
      chars = chars - vim.fn.synconcealed(vim.fn.line ".", col)[0]
    end
  end

  return chars
end

local function create_blame_win()
  vim.api.nvim_command "topleft vnew"
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "git.nvim")
  vim.api.nvim_buf_set_option(buf, "buflisted", false)
  vim.api.nvim_win_set_option(win, "wrap", false)

  -- TODO: Rewrite in lua
  vim.cmd [[setlocal nonumber scrollbind nowrap foldcolumn=0 nofoldenable winfixwidth]]
  vim.cmd [[setlocal signcolumn=no]]

  return win
end

function M.blame()
  vim.cmd [[setlocal cursorbind]]
  local fpath = vim.fn.expand "%:p"
  local starting_win = vim.api.nvim_get_current_win()
  local current_pos = vim.api.nvim_win_get_cursor(starting_win)

  local blame_win = create_blame_win()

  -- TODO: Handle error + using job
  vim.api.nvim_command(
    "read!git --literal-pathspecs --no-pager -c blame.coloring=none -c blame.blankBoundary=false blame --show-number -- "
      .. fpath
  )
  vim.api.nvim_win_set_width(0, blameLinechars() + 1)

  -- Delete the empty first line
  -- FIXME: Find better solution to handle the empty line
  vim.cmd "normal gg"
  vim.cmd "normal dd"

  -- TODO: Restore these options when blame windown is closed
  vim.api.nvim_win_set_cursor(blame_win, current_pos)
  vim.api.nvim_win_set_option(blame_win, "cursorbind", true)
  vim.api.nvim_win_set_option(starting_win, "scrollbind", true)
end

return M