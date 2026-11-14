# dotart — the pixel-art pipeline

Every sprite in `Resources/Assets.xcassets/Dot/` and every `.wav` in `Resources/Sounds/` is
generated from the Python here. Nothing is drawn by hand in an editor, so the set can be
re-rendered whole when the palette changes. Needs Python 3 + Pillow only.

```sh
python3 tools/dotart/build.py               # sprites -> asset catalog, review sheets, MANIFEST.md
python3 tools/dotart/build.py --no-install  # review sheets + manifest only, catalog untouched
python3 tools/dotart/sfx.py                 # SFX -> Resources/Sounds/
```

`build.py` wipes and rewrites `Assets.xcassets/Dot/` and clears the cached asset-catalog build
output (replacing PNGs in place does not invalidate `Assets.car`). Look at
`out/contact_sheet.png` and `out/mock_screen.png` after every change; `out/` is git-ignored.
`out/appicon_1024.png` is produced but never installed.

## Files

| File | What |
|---|---|
| `palette.py` | the one palette, the ASCII legend, shade/light steps, sky + tint per day phase |
| `canvas.py` | `Sprite`: a grid of palette names with rect / ellipse / blit / flip / swap / outline |
| `sprites/*.py` | one module per group; each calls `add(group, name, frames, anchor=…)` |
| `sprites/cabbage.py` | the 봄동 rosette generator shared by crops, icons, signs, logo, app icon |
| `sprites/characters.py` | one procedural chibi body; each person is a spec dict |
| `MANIFEST.md` | generated: names, sizes, anchors, frames, shop slots — the contract with the scene code |

## Adding a sprite

1. In the module for its group, draw it — an ASCII grid (`Sprite.ascii`, one char per pixel,
   legend in `palette.py`) or the draw helpers. Only palette names are accepted.
2. Props and characters get `.outline("ink")`; ground tiles do not. Light comes from the top-left.
3. Register it: `add("fx", "name", sprite_or_list_of_frames, anchor=(x, y), duration=0.1)`.
   The image name becomes `dot_fx_name[_<frame>]`.
4. Run `build.py`, read the contact sheet and the mock, repeat.

A new person is a new entry in `CUSTOMERS` or `STAFF` in `characters.py` — a palette swap plus
a hair/hat choice, never a new body. A new group also needs a line in `FOLDER` in `build.py` and
`GROUP_ORDER` in `sprites/__init__.py`.
