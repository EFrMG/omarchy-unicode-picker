# Unicode Picker

An [Omarchy](https://omarchy.org/) shell plugin that searches, copies, and types any Unicode character.

It ships the (almost) full Unicode dataset comprised of ~47,000 code points: symbols, punctuation, arrows, box drawing, math operators, scripts, and emoji; with a name / keyword index, so you can find a character by typing what it is called.

It's a fullscreen overlay in the same style as Omarchy's built-in emoji picker, keyboard-first with `CTRL + {h,j,k,l}` support and mouse as a fallback.

## Install

```sh
omarchy plugin add https://github.com/EFrMG/omarchy-unicode-picker --enable
```

### Bind a key to it

In your Omarchy Hyprland Lua configuration:

```lua
bind("SUPER + SHIFT + CTRL + E", "Unicode picker", exec_cmd("omarchy-shell shell toggle omarchy-unicode-picker"))
```

## Use

- Start typing to filter by character name or `u+XXXX` code point.
- `←`/`→` (or `Ctrl+H`/`Ctrl+L`) move the selection one cell; `↑`/`↓` (or `Ctrl+J`/`Ctrl+K`) move a row; `PageUp`/`PageDown` jump a page.
- `Enter` (or a click) copies the selected character to the clipboard and types it into whatever was focused before you opened the picker.
- `Escape` clears the current search, or closes the picker if the search is already empty.

## Remove

```sh
omarchy plugin remove omarchy-unicode-picker
```

## Data

`unicode.json` is a static, pre-generated `[{ "e": "<char>", "k": "<name and code point, lowercase>" }, ...]` array built by `generate-unicode.py` from Python's `unicodedata`. It covers every named, assigned code point except for:

- CJK (and CJK compatibility) ideographs: tens of thousands of entries with no meaningful English keyword to search by.
- Invisible and combining characters: Unicode categories `Cf`, `Zs`, `Zl`, `Zp`, `Mn`, `Mc`, `Me`. Characters you can't see or usefully render as a single grid cell.

Regenerate it after a `unicodedata` version bump (newer Unicode standard) with:

```sh
python3 generate-unicode.py
```

Filtering is a plain substring match over each entry's keyword string, done in `UnicodeSearch.js`. Results are capped at 1000 rows; the same cap Omarchy's built-in emoji picker uses, since populating the grid's list model is a per-row cost that is not free even when off screen. Search narrows well under that in practice; it mostly matters for browsing with an empty query, which shows the first 1000 entries in code-point order rather than the full set.

## License

[MIT](LICENSE)
