local config = require("git.config").config
local utils = require "git.utils"

local M = {}

local win, buf

local function create_cmd_win()
  vim.api.nvim_command "new"
  win = vim.api.nvim_get_current_win()
  buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_set_option_value("buftype", "", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  if config.winbar then
    vim.api.nvim_set_option_value("winbar", "Git CMD", { scope = "local", win = win })
  end

  vim.api.nvim_set_option_value("wrap", false, { win = win })
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("list", false, { win = win })

  -- Keymaps
  local options = {
    noremap = true,
    silent = true,
    expr = false,
  }
  vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "<CMD>lua require('git.cmd').close()<CR>", options)
end

function M.close()
  if win then
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  win = nil

  if buf then
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  buf = nil
end

function M.cmd(...)
  local args = { ... }
  if #args == 0 then
    utils.log "Please provide a command"
    return
  end

  local cmd = "git"
  for _, arg in pairs(args) do
    cmd = cmd .. " " .. arg
  end

  -- Close existing terminal first
  M.close()
  create_cmd_win()
  vim.fn.termopen(cmd, {
    ["cwd"] = vim.fn.getcwd(),
  })
end

return M
