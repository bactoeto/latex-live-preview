if vim.g.loaded_latex_live_preview then
  return
end
vim.g.loaded_latex_live_preview = true

-- Only the command is registered here; the module itself is loaded on first use.
local subcommands = { start = true, stop = true, toggle = true }

vim.api.nvim_create_user_command('LatexPreview', function(opts)
  local sub = opts.fargs[1]
  if not subcommands[sub] then
    vim.notify('latex-live-preview: expected start, stop or toggle', vim.log.levels.ERROR)
    return
  end
  require('latex-live-preview')[sub]()
end, {
  nargs = 1,
  complete = function() return { 'start', 'stop', 'toggle' } end,
  desc = 'LaTeX math preview',
})
