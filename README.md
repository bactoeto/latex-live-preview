# latex-live-preview

> **Everything in this repository is AI-generated and provided for reference only.**
>
> No human review, no warranty, no support. Use at your own risk.
>
> *Entirely AI-generated. Reference only.*

Preview the LaTeX math under your cursor in a browser. The plugin extracts the inline formulas on the current line — or the whole display block when the cursor is inside one — writes them to a temporary Markdown file and lets [live-preview.nvim](https://github.com/brianhuster/live-preview.nvim) render it with KaTeX.

## Requirements

- Neovim >= 0.10
- [live-preview.nvim](https://github.com/brianhuster/live-preview.nvim)

## Install

```lua
-- nvim-pack
vim.pack.add({
  'https://github.com/brianhuster/live-preview.nvim',
  'https://github.com/bactoeto/latex-live-preview',
})
```

```lua
-- lazy.nvim
{
  'bactoeto/latex-live-preview',
  dependencies = { 'brianhuster/live-preview.nvim' },
}
```

The commands are available as soon as the plugin loads; the preview module itself
is only loaded the first time you use one of them. To change the defaults:

```lua
require('latex-live-preview').setup({
  -- preview_file = vim.fn.stdpath('cache') .. '/latex_formula_preview.md',
  -- debounce_ms = 300,
})
```

## Usage

| Command | Description |
| --- | --- |
| `:LatexPreview start` | Start the local server and open the browser |
| `:LatexPreview stop` | Stop the preview |
| `:LatexPreview toggle` | Toggle the preview |

```lua
vim.keymap.set('n', '<leader>pt', function()
  require('latex-live-preview').toggle()
end, { desc = 'LaTeX math preview' })
```

Lua API: `start()`, `stop()`, `toggle()` (returns the new state), `is_running()`.

## Behavior

- **Inline math**: every `$...$` on the cursor line; several formulas on the same line are joined into one line.
- **Display math**: when the cursor is anywhere inside `\begin{equation}` / `align` / `alignat` / `gather` / `multline` / `eqnarray` / `flalign` (with or without `*`), `\[...\]` or `$$...$$`, the whole block is used.
- Cursor moves and edits refresh after a 300 ms debounce; the browser re-renders in place without a full reload.
- Only commands invisible in a preview are removed: `\label`, `\ref`, `\eqref`, `\pageref`, `\autoref`, `\vref`, `\cref`, `\Cref` and `\cite` variants. The math itself is kept as written.

## Limitations

- Uses port `5500`, shared with `live-preview.nvim`: only one preview can run at a time.
- Live updates rely on `live-preview.nvim` internals (`connecting_clients`, `websocket.send_json`) and may break when that plugin changes.
- `multline`, `eqnarray` and `flalign` are passed through unchanged, so KaTeX reports `No such environment`.
- `\input` / `\include` files are not followed.
- Nested environments with the same name are not supported (invalid LaTeX anyway).

## License

MIT
