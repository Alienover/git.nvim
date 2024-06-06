local config = require("git.config").config
local utils = require "git.utils"
local git = require "git.utils.git"

local M = {}

local function blame_line_chars()
  return vim.fn.strlen(vim.fn.getline ".")
end

--- @param current_win integer
--- @param next_win integer
local function on_quit(current_win, next_win)
  if current_win ~= nil and vim.api.nvim_win_is_valid(current_win) then
    vim.api.nvim_win_close(current_win, true)
  end

  if next_win ~= nil and vim.api.nvim_win_is_valid(next_win) then
    vim.api.nvim_set_current_win(next_win)
  end
end

local function create_blame_win()
  vim.api.nvim_command "leftabove vnew"
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "git.nvim", { buf = buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
  if config.winbar then
    vim.api.nvim_set_option_value("winbar", "Git Blame", { scope = "local", win = win })
  end

  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
  vim.api.nvim_set_option_value("foldenable", false, { win = win })
  vim.api.nvim_set_option_value("foldenable", false, { win = win })
  vim.api.nvim_set_option_value("winfixwidth", true, { win = win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })

  return win, buf
end

local Context = {}

function Context:new()
  --- @class Context
  local state = {
    --- @type integer?
    --- Window ID where trigger the blame command
    starting_win = vim.api.nvim_get_current_win(),
    --- @type integer?
    --- Buffer ID where trigger the blame command
    starting_buf = vim.api.nvim_get_current_buf(),
    --- @table
    --- Window options which would be reset after the blame command is executed
    starting_win_opts = {
      --- @type boolean
      wrap = nil,
    },

    --- @type integer?
    --- Window ID for the blame content window
    blame_win = nil,
    --- @type integer?
    --- Buffer ID for the blame content buffer
    blame_buf = nil,

    --- @type integer?
    --- Window ID for the commit detail window
    commit_win = nil,
    --- @type integer?
    --- Buffer ID for the commit detail buffer
    commit_buf = nil,

    --- @type string
    --- Root path for the current git repository
    git_root = "",
    --- @type string
    --- Relative path of the current buffer
    relative_path = "",
    --- @type string
    --- File name of the current buffer
    file_name = "",

    --- @table
    events = {
      --- @type integer?
      --- ID for the window enter event
      win_enter = nil,
    },
  }

  for _, win_opt in ipairs { "wrap" } do
    state.starting_win_opts[win_opt] = vim.api.nvim_get_option_value(win_opt, { win = state.starting_win })
  end

  setmetatable(state, self)

  self.__index = self

  return state
end

--- @param lines string[]
function Context:set_blame_context(lines)
  local blame_win, blame_buf = create_blame_win()

  self.blame_win = blame_win
  self.blame_buf = blame_buf

  vim.api.nvim_buf_set_lines(blame_buf, 0, -1, true, lines)
  vim.api.nvim_win_set_width(blame_win, blame_line_chars() + 1)
  vim.api.nvim_set_option_value("modifiable", false, { buf = blame_buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = blame_buf })
end

--- @param commit_hash string
---@param lines string[]
function Context:set_commit_context(commit_hash, lines)
  local commit_win, commit_buf = create_blame_win()

  self.commit_win = commit_win
  self.commit_buf = commit_buf

  vim.api.nvim_buf_set_lines(commit_buf, 0, -1, true, lines)
  vim.api.nvim_buf_set_name(commit_buf, commit_hash)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = commit_buf })
  vim.api.nvim_set_option_value("bufhidden", "delete", { buf = commit_buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = commit_buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = commit_buf })

  vim.api.nvim_win_set_width(commit_win, 80)
  vim.api.nvim_set_option_value("cursorbind", false, { win = commit_win })
  vim.api.nvim_set_option_value("scrollbind", false, { win = commit_win })
end

--- @param git_root string
function Context:set_git_context(git_root)
  self.git_root = git_root
  self.relative_path = vim.fn.fnamemodify(vim.fn.expand "%", ":~:.")
  self.file_name = vim.fn.fnamemodify(vim.fn.expand "%:t", ":~:.")
end

function Context:set_win_listener()
  self.events.win_enter = vim.api.nvim_create_autocmd("WinEnter", {
    group = vim.api.nvim_create_augroup("BlameWinListener", { clear = true }),
    callback = function()
      vim.defer_fn(function()
        local focused_buf = vim.api.nvim_get_current_buf()

        if focused_buf == self.commit_buf then
          -- skip
        elseif focused_buf == self.blame_buf then
          on_quit(self.commit_win, self.blame_win)
        else
          local focused_win = vim.api.nvim_get_current_win()

          self:on_blame_quit(focused_win)
        end
      end, 100)
    end,
  })
end

function Context:clear_listeners()
  for _, event_id in pairs(self.events) do
    if event_id ~= nil then
      pcall(vim.api.nvim_del_autocmd, event_id)
    end
  end
end

--- @param next_win integer
function Context:on_blame_quit(next_win)
  vim.api.nvim_set_option_value("scrollbind", false, { win = self.starting_win })
  vim.api.nvim_set_option_value("cursorbind", false, { win = self.starting_win })
  vim.api.nvim_set_option_value("wrap", self.starting_win_opts.wrap, { win = self.starting_win })

  on_quit(self.commit_win, next_win)
  on_quit(self.blame_win, next_win)

  self:clear_listeners()
end

local function blame_syntax()
  local seen = {}
  local hash_colors = {}
  for lnum = 1, vim.fn.line "$" do
    local orig_hash = vim.fn.matchstr(vim.fn.getline(lnum), [[^\^\=[*?]*\zs\x\{6\}]])
    local hash = orig_hash
    hash = vim.fn.substitute(hash, [[\(\x\)\x]], [[\=submatch(1).printf("%x", 15-str2nr(submatch(1),16))]], "g")
    hash = vim.fn.substitute(hash, [[\(\x\x\)]], [[\=printf("%02x", str2nr(submatch(1),16)*3/4+32)]], "g")
    if hash ~= "" and orig_hash ~= "000000" and seen[hash] == nil then
      seen[hash] = 1
      local colors = vim.fn.map(vim.fn.matchlist(orig_hash, [[\(\x\)\x\(\x\)\x\(\x\)\x]]), "str2nr(v:val,16)")
      local r = colors[2]
      local g = colors[3]
      local b = colors[4]
      local color = 16 + (r + 1) / 3 * 36 + (g + 1) / 3 * 6 + (b + 1) / 3
      if color == 16 then
        color = 235
      elseif color == 231 then
        color = 255
      end

      hash_colors[hash] = " ctermfg=" .. tostring(color)
      local pattern = vim.fn.substitute(orig_hash, [[^\(\x\)\x\(\x\)\x\(\x\)\x$]], [[\1\\x\2\\x\3\\x]], "") .. [[*\>]]
      vim.cmd("syn match GitNvimBlameHash" .. hash .. [[       "\%(^\^\=[*?]*\)\@<=]] .. pattern .. [[" skipwhite]])
    end

    for hash_value, cterm in pairs(hash_colors) do
      if cterm ~= nil or vim.fn.has "gui_running" or vim.fn.hash "termguicolors" and vim.wo.termguicolors then
        vim.cmd("hi GitNvimBlameHash" .. hash_value .. " guifg=#" .. hash_value .. cterm)
      else
        vim.cmd("hi link GitNvimBlameHash" .. hash_value .. " Identifier")
      end
    end
  end
end

--- @param ctx Context
local function on_blame_done(ctx, lines)
  ctx:set_win_listener()

  local current_top = vim.fn.line "w0" + vim.api.nvim_get_option_value("scrolloff", { win = ctx.starting_win })
  local current_pos = vim.fn.line "."

  ctx:set_blame_context(lines)

  vim.cmd("execute " .. tostring(current_top))
  vim.cmd "normal! zt"
  vim.cmd("execute " .. tostring(current_pos))

  -- We should call cursorbind, scrollbind here to avoid unexpected behavior
  vim.api.nvim_set_option_value("cursorbind", true, { win = ctx.blame_win })
  vim.api.nvim_set_option_value("scrollbind", true, { win = ctx.blame_win })

  vim.api.nvim_set_option_value("scrollbind", true, { win = ctx.starting_win })
  vim.api.nvim_set_option_value("cursorbind", true, { win = ctx.starting_win })
  -- Disable wrap
  vim.api.nvim_set_option_value("wrap", false, { win = ctx.starting_win })

  -- Keymaps
  local options = {
    noremap = true,
    silent = true,
    expr = false,
    buffer = ctx.blame_buf,
  }

  vim.keymap.set("n", config.keymaps.quit_blame, function()
    ctx:on_blame_quit(ctx.starting_win)
  end, options)

  vim.keymap.set("n", config.keymaps.blame_commit, function()
    M.blame_commit(ctx)
  end, options)

  blame_syntax()
end

--- @param ctx Context
--- @param commit_hash string
--- @param lines string[]
local function on_blame_commit_done(ctx, commit_hash, lines)
  -- TODO: Find a better way to handle this case
  local idx = 1
  while idx <= #lines and not utils.starts_with(lines[idx], "diff") do
    idx = idx + 1
  end
  table.insert(lines, idx, "")

  ctx:set_commit_context(commit_hash, lines)

  vim.keymap.set("n", config.keymaps.quit_blame, function()
    on_quit(ctx.commit_win, ctx.blame_win)
  end, { noremap = true, silent = true, buffer = ctx.commit_buf })

  if vim.fn.search([[^diff .* b/\M]] .. vim.fn.escape(ctx.relative_path, "\\") .. "$", "W") == 0 then
    vim.fn.search([[^diff .* b/.*]] .. ctx.file_name .. "$", "W")
  end
end

--- @param ctx Context
function M.blame_commit(ctx)
  local line = vim.fn.getline "."
  local commit = vim.fn.matchstr(line, [[^\^\=[?*]*\zs\x\+]])
  if string.match(commit, "^0+$") then
    utils.log "Not Committed Yet"
    return
  end

  local commit_hash =
    git.run_git_cmd("git -C " .. ctx.git_root .. " --literal-pathspecs rev-parse --verify " .. commit .. " --")
  if commit_hash == nil then
    utils.log "Commit hash not found"
    return
  end

  commit_hash = string.gsub(commit_hash, "\n", "")
  local diff_cmd = "git -C "
    .. ctx.git_root
    .. " --literal-pathspecs --no-pager show --no-color "
    .. commit_hash
    .. " -- "
    .. vim.api.nvim_buf_get_name(ctx.starting_buf)

  local lines = {}
  local function on_event(_, data, event)
    -- TODO: Handle error data
    if event == "stdout" or event == "stderr" then
      data = utils.handle_job_data(data)
      if not data then
        return
      end

      for i = 1, #data do
        if data[i] ~= "" then
          table.insert(lines, data[i])
        end
      end
    end

    if event == "exit" then
      on_blame_commit_done(ctx, commit_hash, lines)
    end
  end

  vim.fn.jobstart(diff_cmd, {
    on_stderr = on_event,
    on_stdout = on_event,
    on_exit = on_event,
    stdout_buffered = true,
    stderr_buffered = true,
  })
end

function M.blame()
  local ctx = Context:new()

  local fpath = utils.escape_parentheses(vim.api.nvim_buf_get_name(0))
  if fpath == "" or fpath == nil then
    return
  end

  local git_root = git.get_git_repo()
  if git_root == "" then
    return
  end

  ctx:set_git_context(git_root)

  local blame_cmd = "git -C "
    .. git_root
    .. " --literal-pathspecs --no-pager -c blame.coloring=none -c blame.blankBoundary=false blame --show-number -- "
    .. fpath

  local lines = {}
  local has_error = false

  local function on_event(_, data, event)
    if event == "stdout" then
      data = utils.handle_job_data(data)
      if not data then
        return
      end

      for i = 1, #data do
        if data[i] ~= "" then
          local commit = vim.fn.matchstr(data[i], [[^\^\=[?*]*\zs\x\+]])
          local commit_info = data[i]:match "%((.-)%)"
          commit_info = string.match(commit_info, "(.-)%s(%S+)$")
          table.insert(lines, commit .. " " .. commit_info)
        end
      end
    elseif event == "stderr" then
      data = utils.handle_job_data(data)
      if not data then
        return
      end

      has_error = true
      local error_message = ""
      for _, line in ipairs(data) do
        error_message = error_message .. line
      end
      utils.log("Failed to open git blame window: " .. error_message)
    elseif event == "exit" then
      if not has_error then
        on_blame_done(ctx, lines)
      end
    end
  end

  vim.fn.jobstart(blame_cmd, {
    on_stderr = on_event,
    on_stdout = on_event,
    on_exit = on_event,
    stdout_buffered = true,
    stderr_buffered = true,
  })
end

return M
