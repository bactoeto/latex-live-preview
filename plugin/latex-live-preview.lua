if vim.g.loaded_latex_live_preview then
  return
end
vim.g.loaded_latex_live_preview = true

require('latex-live-preview').setup()
