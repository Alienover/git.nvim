local M = {}

---@class Setting
---@field key string
---@field mode? string | table
---@field rhs function|string
---@field cmd? string
---@field cmd_opts? vim.api.keyset.user_command

--- @type table< string, Setting[] >
local settings = {
  blame = {
    {
      key = "blame",
      rhs = function()
        require("git.blame").open()
      end,
      cmd = "GitBlame",
      cmd_opts = { bang = true, nargs = "*" },
    },
  },
  browse = {
    {
      key = "browse",
      mode = "n",
      rhs = function(args)
        require("git.browse").open(args.args == "range")
      end,
      cmd = "GitBrowse",
      cmd_opts = { bang = true, nargs = "*" },
    },
    {
      key = "browse",
      mode = "x",
      rhs = ":<c-u> GitBrowse range<CR>",
    },
  },
  pull_request = {
    {
      key = "open_pull_request",
      rhs = function()
        require("git.browse").pull_request()
      end,
    },
    {
      key = "create_pull_request",
      rhs = function(args)
        require("git.browse").create_pull_request(args.fargs)
      end,
      cmd = "GitCreatePullRequest",
      cmd_opts = { bang = true, nargs = "*" },
    },
  },
  diff = {
    {
      key = "diff",
      rhs = function(args)
        require("git.diff").open(args.args)
      end,
      cmd = "GitDiff",
      cmd_opts = { bang = true, nargs = "*" },
    },
    {
      key = "diff_close",
      rhs = function()
        require("git.diff").close()
      end,
      cmd = "GitDiffClose",
      cmd_opts = { bang = true, nargs = "*" },
    },
  },
  revert = {
    {
      key = "revert",
      rhs = function()
        require("git.revert").open(false)
      end,
      cmd = "GitRevert",
      cmd_opts = { bang = true },
    },
    {
      key = "revert_file",
      rhs = function()
        require("git.revert").open(true)
      end,
      cmd = "GitRevertFile",
      cmd_opts = { bang = true },
    },
  },
  git = {
    {
      key = "git",
      rhs = function(args)
        require("git.cmd").cmd(unpack(args.fargs))
      end,
      cmd = "Git",
      cmd_opts = { bang = true, nargs = "*" },
    },
  },
}

local function initialize()
  local config = require("git.config").config

  for key, setting in pairs(settings) do
    local enabled = config.functions[key]

    if enabled == true then
      for _, feature in ipairs(setting) do
        local cmd, cmd_opts, rhs = feature.cmd, feature.cmd_opts, feature.rhs
        if cmd ~= nil then
          vim.api.nvim_create_user_command(cmd, rhs, cmd_opts or {})
        end

        local mapping = config.keymaps[feature.key]
        local mode = feature.mode or "n"
        if mapping ~= nil then
          vim.keymap.set(mode, mapping, cmd and string.format(":%s<CR>", cmd) or rhs, {
            noremap = true,
            silent = true,
            expr = false,
          })
        end
      end
    end
  end
end

function M.setup(cfg)
  require("git.config").setup(cfg)

  initialize()
end

return M
