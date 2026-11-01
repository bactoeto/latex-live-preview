--- latex-live-preview: preview the LaTeX math under the cursor in a browser
--- Requires live-preview.nvim for Markdown + KaTeX rendering.
--- The whole cursor line is kept when it holds inline math ($..$); when the
--- cursor is inside a display block (env / \[..\] / $$..$$) the whole block is used.
--- The result is written to a temporary Markdown file and rendered by live-preview.nvim.
--- API: require('latex-live-preview').toggle() / start() / stop() / is_running()
--- The :LatexPreview command is declared in plugin/latex-live-preview.lua
--- (start / stop / toggle) and loads this module on first use.

local M = {}

M.config = {
  preview_file = vim.fn.stdpath('cache') .. '/latex_formula_preview.md',
  debounce_ms = 300,
}

-- Display math environments (names KaTeX knows plus common LaTeX aliases)
local MATH_ENVS = {}
for env in ([[equation equation* align align* alignat alignat* gather gather*
multline multline* eqnarray eqnarray* flalign flalign* displaymath math]]):gmatch('%S+') do
  MATH_ENVS[env] = true
end

-- Reference commands that are invisible in a preview and unknown to KaTeX
local REF_CMDS = { 'label', 'eqref', 'pageref', 'autoref', 'vref', 'cref', 'Cref', 'ref' }

local uv = vim.uv or vim.loop
local timer = uv.new_timer()
local started, inited = false, false

local function fail(msg)
  vim.notify('latex-live-preview: ' .. msg, vim.log.levels.ERROR)
  return false
end

-- ---------- extraction ----------

--- Number of consecutive backslashes before pos
local function backslashes(s, pos)
  local n, i = 0, pos - 1
  while i >= 1 and s:sub(i, i) == '\\' do
    n, i = n + 1, i - 1
  end
  return n
end

--- An unescaped % starts a comment
local function strip_comment(line)
  for i = 1, #line do
    if line:sub(i, i) == '%' and backslashes(line, i) % 2 == 0 then
      return line:sub(1, i - 1)
    end
  end
  return line
end

--- Find an unescaped needle
local function find_unescaped(s, needle, init)
  local i = init
  while true do
    local p = s:find(needle, i, true)
    if not p or backslashes(s, p) % 2 == 0 then
      return p
    end
    i = p + 1
  end
end

local function trim(s)
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Drop reference commands that are invisible in a preview: \label{} \ref{} \cite{} ...
function M._sanitize(text)
  local out = text
  for _, cmd in ipairs(REF_CMDS) do
    out = out:gsub('\\' .. cmd .. '%s*%b{}', '')
  end
  return (out:gsub('\\cite%a*%s*%b[]%s*%b{}', ''):gsub('\\cite%a*%s*%b{}', ''))
end

--- Display math block; nil when empty
local function display(body)
  body = trim(M._sanitize(body))
  return body ~= '' and ('$$\n' .. body .. '\n$$') or nil
end

--- Extract the preview blocks under the cursor: the display block overlapping
--- the cursor line, or else the whole cursor line when it holds inline math.
--- @param lines string[] buffer lines
--- @param lnum number cursor line (1-based)
--- @return { content: string, blocks: string[] }
function M._extract_at(lines, lnum)
  local text = table.concat(vim.tbl_map(strip_comment, lines), '\n')

  -- Character range of the cursor line: [start, line_end]
  local start = 1
  for _ = 1, lnum - 1 do
    start = (text:find('\n', start, true) or #text) + 1
  end
  local line_end = (text:find('\n', start, true) or #text + 1) - 1

  local blocks, inline = {}, false
  local function add(block)
    if block then blocks[#blocks + 1] = block end
  end

  local p = 1
  while p <= line_end do
    local c, nxt = text:sub(p, p), text:sub(p + 1, p + 1)
    local close
    if (c == '$' and nxt == '$') or (c == '\\' and nxt == '[') then
      close = find_unescaped(text, c == '$' and '$$' or '\\]', p + 2)
      if close then
        -- The block overlaps the cursor line
        if start <= close + 2 then
          add(display(text:sub(p + 2, close - 1)))
        end
        p = close + 2
      else
        p = p + 2
      end
    elseif c == '\\' and (nxt == '$' or nxt == '\\') then
      p = p + 2
    elseif c == '$' then
      close = find_unescaped(text, '$', p + 1)
      if close then
        -- Inline math overlapping the cursor line: keep the whole line later
        if start <= close then
          inline = true
        end
        p = close + 1
      else
        p = p + 1
      end
    elseif c == '\\' then
      local env = text:match('^\\begin%s*{([%a%*]+)}', p)
      local ee = env and MATH_ENVS[env] and select(2, text:find('\\end%s*{' .. vim.pesc(env) .. '}', p))
      if ee then
        if start <= ee then
          add(display(text:sub(p, ee)))
        end
        p = ee + 1
      else
        p = p + 1
      end
    else
      p = p + 1
    end
  end
  -- A display block wins; otherwise copy the cursor line as written
  if #blocks == 0 and inline then
    local line_text = trim(M._sanitize(text:sub(start, line_end)))
    if line_text ~= '' then blocks[#blocks + 1] = line_text end
  end

  local content = '# LaTeX Math Preview\n'
  if #blocks > 0 then
    content = content .. '\n' .. table.concat(blocks, '\n\n') .. '\n'
  end
  return { content = content, blocks = blocks }
end

-- ---------- server control ----------

local function preview_running()
  local ok, lp = pcall(require, 'livepreview')
  return ok and lp.is_running()
end

local function current_content()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return M._extract_at(vim.api.nvim_buf_get_lines(0, 0, -1, false), lnum).content
end

local function write_preview(content)
  vim.fn.mkdir(vim.fn.fnamemodify(M.config.preview_file, ':h'), 'p')
  vim.fn.writefile(vim.split(content, '\n', { plain = true }), M.config.preview_file)
end

--- Push new content to connected browsers (in-place re-render)
local function broadcast(content)
  local ok, server = pcall(require, 'livepreview.server')
  if not ok or type(server.connecting_clients) ~= 'table' then
    vim.notify_once(
      'latex-live-preview: live-preview.nvim internals changed, live updates unavailable (refresh the browser manually)',
      vim.log.levels.WARN
    )
    return
  end
  local msg = { type = 'update', filepath = M.config.preview_file, content = content }
  for _, client in ipairs(server.connecting_clients) do
    pcall(server.websocket.send_json, client, msg)
  end
end

local function update()
  if not started or vim.bo.filetype ~= 'tex' then
    return
  end
  if not preview_running() then
    started = false
    return
  end
  local content = current_content()
  local ok, err = pcall(write_preview, content)
  if not ok then
    return fail('failed to write the preview file: ' .. tostring(err))
  end
  broadcast(content)
end

local function schedule()
  if not started then
    return
  end
  timer:stop()
  timer:start(M.config.debounce_ms, 0, vim.schedule_wrap(update))
end

--- Autocommands are only needed once the preview is started
local function init()
  if inited then
    return
  end
  inited = true

  local group = vim.api.nvim_create_augroup('LatexLivePreview', { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'InsertLeave', 'CursorMoved', 'CursorMovedI' }, {
    group = group,
    pattern = '*.tex',
    callback = schedule,
  })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = '*.tex',
    callback = function() if started then update() end end,
  })
end

function M.is_running()
  return started and preview_running()
end

function M.start()
  init()
  if M.is_running() then
    return true
  end
  if vim.bo.filetype ~= 'tex' then return fail('enable the preview from a tex buffer') end

  -- Port 5500 allows a single instance: close the running one and wait for the port
  if preview_running() then
    pcall(vim.cmd, 'LivePreview close')
    vim.wait(300, function() return not preview_running() end, 10)
  end

  local content = current_content()
  local ok, err = pcall(write_preview, content)
  if not ok then return fail('failed to write the preview file: ' .. tostring(err)) end

  local ok_cfg, lp_config = pcall(require, 'livepreview.config')
  if not ok_cfg then return fail('live-preview.nvim not found') end

  -- The preview file lives outside cwd, so the server must use its directory as webroot
  local old_root = lp_config.config.dynamic_root
  lp_config.config.dynamic_root = true
  ok, err = pcall(vim.cmd, 'LivePreview start ' .. vim.fn.fnameescape(M.config.preview_file))
  lp_config.config.dynamic_root = old_root
  if not ok then return fail('failed to start the preview: ' .. tostring(err)) end

  -- The plugin only warns when the port is taken; verify we are really listening
  local ok_srv, srv = pcall(function()
    return require('livepreview').serverObj.server
  end)
  if not ok_srv or not srv or not srv:getsockname() then
    return fail('port 5500 is taken by another process, preview not started')
  end

  started = true
  return true
end

function M.stop()
  timer:stop()
  started = false
  pcall(vim.cmd, 'LivePreview close')
end

function M.toggle()
  if M.is_running() then
    M.stop()
    return false
  end
  return M.start()
end

--- Override the default configuration. Initialization happens automatically.
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

return M
