# latex-live-preview

> **Everything in this repository is AI-generated and provided for reference only.**
>
> No human review, no warranty, no support. Use at your own risk.
>
> *Entirely AI-generated. Reference only.*

Preview the LaTeX math under your cursor in a browser. The plugin copies the
cursor line as written when it holds inline math — or the whole display block
when the cursor is inside one — writes it to a temporary Markdown file and lets
[live-preview.nvim](https://github.com/brianhuster/live-preview.nvim) render it
with KaTeX.

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

- **Inline math**: the whole cursor line is copied when it holds a `$...$`,
  surrounding text included; the preview is empty when the line has no inline
  math.
- **Display math**: when the cursor is anywhere inside `\begin{equation}` / `align` / `alignat` / `gather` / `multline` / `eqnarray` / `flalign` (with or without `*`), `\[...\]` or `$$...$$`, the whole block is used.
- Cursor moves and edits refresh after a 300 ms debounce; the browser re-renders in place without a full reload.
- Only commands invisible in a preview are removed: `\label`, `\ref`, `\eqref`, `\pageref`, `\autoref`, `\vref`, `\cref`, `\Cref` and `\cite` variants. The math itself is kept as written.

## Limitations

- Uses port `5500`, shared with `live-preview.nvim`: only one preview can run at a time.
- Live updates rely on `live-preview.nvim` internals (`connecting_clients`, `websocket.send_json`) and may break when that plugin changes.
- `multline`, `eqnarray` and `flalign` are passed through unchanged, so KaTeX reports `No such environment`.
- `\input` / `\include` files are not followed.
- Nested environments with the same name are not supported (invalid LaTeX anyway).
- The text around inline formulas is rendered as Markdown, so `_x_`, `*` and `#`
  in it are interpreted.
- A line holding both `$x$` and `$$y$$` previews the display block only.

## License

MIT
