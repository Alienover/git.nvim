local M = {}

M.config = {}

local default_keymaps_cfg = {
  blame = "<Leader>gb",
  browse = "<Leader>go",
  open_pull_request = "<Leader>gp",
  create_pull_request = "<Leader>gn",
  diff = "<Leader>gd",
  diff_close = "<Leader>gD",
  revert = "<Leader>gr",
  revert_file = "<Leader>gR",
}

local default_cfg = {
  default_mappings = true,
  keymaps = {
    quit_blame = "q",
    blame_commit = "<CR>",
  },
  target_branch = "master",
  private_gitlabs = {},
  winbar = false,
  functions = {
    git = true, -- :Git, run git command
    blame = true, -- :GitBlame, blame the current file
    browse = true, -- :GitBrowse, view the current file on browser
    pull_request = true, -- create/view pull_request
    diff = true, -- :GitDiff, toggle diff view
    revert = true, -- :GitRevert
  },
}

function M.is_private_gitlab(host)
  for _, v in ipairs(M.config.private_gitlabs) do
    if value == str then
      return true
    end
  end
  return false
end

function M.setup(cfg)
  if cfg == nil then
    cfg = {}
  end

  for k, v in pairs(default_cfg) do
    if cfg[k] ~= nil then
      if type(v) == "table" then
        M.config[k] = vim.tbl_extend("force", v, cfg[k])
      else
        M.config[k] = cfg[k]
      end
    else
      M.config[k] = default_cfg[k]
    end
  end

  if M.config.default_mappings then
    for k, v in pairs(default_keymaps_cfg) do
      if M.config.keymaps[k] == nil then
        M.config.keymaps[k] = v
      end
    end
  end
end

return M
