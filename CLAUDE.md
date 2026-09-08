# BomDong Tycoon

General working rules live in the user-level `~/.claude/CLAUDE.md`. This file covers only
what is specific to this project.

## The 2.5D design team

Sprite art here is not drawn — it is **rendered**. An image generator supplies flat, head-on
texture panels; a scripted orthographic camera in `tools/isorender/` supplies every bit of
geometry: projection, shear, vertical edges, foreshortening, light direction, ink outline and
pixel scale. That is why a set comes out coherent by construction instead of by correcting
each image afterwards. See `tools/isorender/README.md` for the derivation.

Four agents own that pipeline, defined in `.claude/agents/` (tracked — they are part of how
the project is built):

| Agent | Owns | Never |
|---|---|---|
| `2.5d-art-director` | Style bible, what pieces a set needs and their dimensions in grid units, judging the set at the size it is drawn | Generates textures, writes specs, edits rig scripts |
| `2.5d-texture-designer` | Flat head-on panels in `tools/isorender/textures/` — sourcing, prompting, grading, numeric validation | Anything isometric; baked shading, outline or perspective |
| `2.5d-asset-designer` | Specs in `tools/isorender/assets/`, the render, the measurement table | The camera, the lights, the outline |
| `2.5d-rig-engineer` | `tools/isorender/*.py` — camera math, lighting, shape vocabulary, calibration, `install.py` | Art judgements, palettes |

**Routing.** Any sprite work goes to `2.5d-art-director` — it briefs its own crew directly
(an explicit exception to the "subagents do not self-assign" rule, which still holds for
everyone else). The director hands back a PNG plus a plain-number measurement table; the
manager routes those to `ios-developer`, who writes the node constants. No agent in this team
writes Swift.

**The rule the split exists to protect:** tune the part, never the camera. A camera or lighting
change re-renders the whole set and is a `2.5d-rig-engineer` decision, never a fix for one asset.

## Rendering an asset

```sh
tools/isorender/render.sh calibrate                    # must print CALIBRATION PASS, run it first
tools/isorender/render.sh wall_shop_left 3             # render + trim + measurement table
tools/isorender/render.sh wall_shop_left 3 --install   # also drop it into the asset catalog
```

Needs Blender (`brew install --cask blender`). Renders land in `tools/isorender/out/`, which is
git-ignored — they are reproducible from the specs.

`~/.claude/skills/2.5d-game-asset-designer` is the **portable** copy of this pipeline, for other
projects. BomDong uses `tools/isorender/`; only `2.5d-rig-engineer` touches either, and fixes are
ported to both in the same task.

## Comments: two kinds, only one of them earns its length

Several files here run 50–65% comment lines. That is right for **art-derived code** — the wall
and tile nodes, `tools/isorender/` — because those comments record measurements you cannot get
back from the code: a sprite's face corners, that a source image was tilted ~46px over a 410px
run, why `HEIGHT` is 0.709. Delete them and the constants become unmaintainable numbers.

It is wrong for **structural code**, which has no measurements to record. Do not copy the
density just because neighbouring files have it — `ShopNode` was written at 50% and trimmed to
28% with nothing lost.

The test: **keep a comment only if deleting it would lose information the code does not already
carry.**

Worth writing, always:
- why a constant is *that* number, especially a measured one
- a non-obvious invariant, and what breaks without it (the z-scheme in `ShopNode` names the exact
  bug it prevents, because otherwise someone will "simplify" it back)
- a mapping that is hard to re-derive (which wall belongs on which tile edge)
- a known-bad thing deliberately left alone, so it is not "fixed" twice

Not worth writing:
- restating the line below it
- cross-reference chains ("see that function's doc comment") where the reader can read the symbol
- the same coordinate space explained in three places — say it once, well
- provenance narration about where a helper was copied from

## Gotcha: swapping art in the asset catalog

Replacing a PNG in place inside `Resources/Assets.xcassets` does **not** invalidate the
asset-catalog build step. `xcodebuild` succeeds and ships the previous `Assets.car` byte for
byte, so the simulator keeps showing the old art — which looks exactly like a successful swap.
Use `tools/isorender/install.py` (it clears the cached catalog output), or delete
`assetcatalog_output` in DerivedData yourself and confirm the `Assets.car` hash changed.
