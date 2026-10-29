if vim.g.loaded_latex_live_preview then
  return
end
vim.g.loaded_latex_live_preview = true

-- Only the commands are registered here; the module itself is loaded on first use.
for _, name in ipairs({ 'Start', 'Stop', 'Toggle' }) do
  vim.api.nvim_create_user_command('LatexPreview' .. name, function()
    require('latex-live-preview')[name:lower()]()
  end, { desc = name .. ' LaTeX math preview' })
end
