"""Render every sprite into the asset catalog, plus the review sheets.

    python3 tools/dotart/build.py            # everything
    python3 tools/dotart/build.py --no-install   # review images only, catalog untouched
"""

import argparse
import json
import os
import shutil
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "isorender"))

import sprites  # noqa: E402
from canvas import Sprite  # noqa: E402
from palette import PALETTE, SKY, TINT, rgb_hex  # noqa: E402

DOT = os.path.join(REPO, "Resources", "Assets.xcassets", "Dot")
OUT = os.path.join(HERE, "out")
FOLDER = {"ground": "Ground", "backdrop": "Backdrop", "shop": "Shop", "dish": "Dish",
          "farm": "Farm", "char": "Char", "fx": "Fx", "ui": "Ui"}
FOLDER_JSON = {"info": {"author": "xcode", "version": 1}}


def write_json(path, data):
    with open(path, "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


def install(assets):
    # Dot/ is owned by this script; wiping it is how renamed sprites disappear.
    if os.path.isdir(DOT):
        shutil.rmtree(DOT)
    os.makedirs(DOT)
    write_json(os.path.join(DOT, "Contents.json"), FOLDER_JSON)
    count = 0
    for a in assets:
        group_dir = os.path.join(DOT, FOLDER[a.group])
        if not os.path.isdir(group_dir):
            os.makedirs(group_dir)
            write_json(os.path.join(group_dir, "Contents.json"), FOLDER_JSON)
        for name, spr in a.image_names():
            d = os.path.join(group_dir, f"{name}.imageset")
            os.makedirs(d)
            spr.to_image().save(os.path.join(d, f"{name}.png"))
            write_json(os.path.join(d, "Contents.json"), {
                "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}],
                "info": {"author": "xcode", "version": 1},
            })
            count += 1
    from install import clear_asset_catalog_cache
    cleared = clear_asset_catalog_cache(os.path.expanduser("~/Library/Developer/Xcode/DerivedData"))
    print(f"installed {count} imagesets into {os.path.relpath(DOT, REPO)}; "
          f"cleared {len(cleared)} cached asset-catalog artifact(s)")
    return count


def checker(w, h, cell=12):
    img = Image.new("RGBA", (w, h), (128, 128, 128, 255))
    d = ImageDraw.Draw(img)
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            if (x // cell + y // cell) % 2:
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=(112, 112, 112, 255))
    return img


def contact_sheet(assets, scale=6, width=1960):
    pad, label_h, header_h = 10, 14, 26
    placements, x, y, row_h = [], pad, pad, 0
    for group in sprites.GROUP_ORDER:
        if x > pad:
            y += row_h + pad
        placements.append(("header", group, pad, y))
        x, y, row_h = pad, y + header_h, 0
        for a in [a for a in assets if a.group == group]:
            for name, spr in a.image_names():
                w = max(spr.w * scale, len(f"{name} {spr.w}x{spr.h}") * 6 + 6)
                if x + w + pad > width:
                    x, y, row_h = pad, y + row_h + pad, 0
                placements.append(("sprite", (name, spr), x, y))
                x += w + pad
                row_h = max(row_h, spr.h * scale + label_h)
    sheet = checker(width, y + row_h + pad)
    d = ImageDraw.Draw(sheet)
    for kind, item, px, py in placements:
        if kind == "header":
            d.rectangle([0, py, width, py + header_h - 6], fill=(43, 27, 46, 255))
            d.text((px, py + 4), item.upper(), fill=(255, 250, 240, 255))
        else:
            name, spr = item
            img = spr.to_image().resize((spr.w * scale, spr.h * scale), Image.NEAREST)
            sheet.alpha_composite(img, (px, py))
            d.text((px, py + spr.h * scale + 2), f"{name} {spr.w}x{spr.h}", fill=(255, 255, 255, 255))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "contact_sheet.png"))


class Scene:
    """Composes sprites by anchor, the way the SpriteKit scene will."""

    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def put(self, group, name, x, y, frame=None, flip=False):
        """x, y is where the sprite's anchor pixel lands."""
        asset = next(a for a in sprites.ASSETS if a.group == group and a.name == name)
        spr = sprites.find(group, name, frame)
        ax, ay = asset.anchor if asset.anchor else (0, 0)
        if flip:
            spr, ax = spr.flip_h(), spr.w - 1 - ax
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        layer.paste(spr.to_image(), (x - ax, y - ay))
        self.img.alpha_composite(layer)

    def tiles(self, group, names, x0, y0, cols, rows, seed=0):
        for r in range(rows):
            for c in range(cols):
                name, frame = names[(c * 7 + r * 13 + seed + (c * r) % 3) % len(names)]
                spr = sprites.find(group, name, frame)
                self.img.alpha_composite(spr.to_image(), (x0 + c * 16, y0 + r * 16))


BACKDROP, STREET, SHOP, YARD, FARM = 0, 56, 88, 152, 176
GRASS = [("grass", 0), ("grass", 1), ("grass", 2), ("grass", 0), ("grass", 1), ("grass", 2),
         ("grass", 0), ("grass_flower", 0), ("grass", 2), ("grass", 1), ("grass", 0),
         ("grass", 2), ("grass", 1), ("grass_flower", 1), ("grass", 0), ("grass", 1), ("grass", 2)]


def mock(tier, location, phase, customers, staff, plots, crate, night_stars=False):
    from sprites import shop
    s = Scene(144, 312)
    if phase in ("noon", "morning"):
        s.put("backdrop", "sun", 118, 12)
        s.put("backdrop", "cloud", 30, 14, 0), s.put("backdrop", "cloud", 92, 26, 1)
    else:
        s.put("backdrop", "sun" if phase == "dusk" else "moon", 22, 30)
        s.put("backdrop", "cloud", 104, 12, 1)
    s.put("backdrop", location, 0, 55)
    street = {"alley": [("street_alley", None)], "market": [("street_market", None)],
              "gangnam": [("street_gangnam", None)]}[location]
    s.tiles("ground", street, 0, STREET, 9, 2)
    if location == "gangnam":
        for c in (0, 1):
            for r in (0, 1):
                s.put("ground", "street_gangnam_crosswalk", 8 + c * 16, STREET + r * 16)

    s.tiles("ground", GRASS, 0, SHOP, 9, 14, seed=2)
    s.tiles("ground", [("path", None)], 0, YARD + 4, 9, 1)

    queue_y = STREET + 29
    dishes = ["geotjeori", "kimchi", "bibimbap"]
    for i, (who, pose, want) in enumerate(customers):
        x = 40 + i * 26
        s.put("fx", "shadow", x, queue_y)
        s.put("char", who, x, queue_y, pose)
        if want is not None:
            s.put("fx", "bubble", x, queue_y - 24)
            s.put("dish", dishes[want], x - 10 + 3 + 8, queue_y - 24 - 21 + 2 + 15)
    s.put("char", "kid_boy", 134, queue_y - 3, "walk_side_0")

    oy = SHOP
    s.put("shop", f"tier{tier}_back", 0, oy + 63)
    for i, x in enumerate(shop.COOK_X + (shop.CASHIER_X,)):
        if staff[i]:
            s.put("char", staff[i][0], x, oy + shop.STAFF_Y, staff[i][1])
    s.put("shop", f"tier{tier}_front", 0, oy + 63)
    for i, x in enumerate(shop.DISH_X):
        if i == 1 and tier == 1:
            s.put("dish", "pot", x, oy + shop.DISH_Y, 0)
        else:
            s.put("dish", dishes[i] if i <= tier or tier == 1 else "empty_bowl", x, oy + shop.DISH_Y)
        bar = sprites.find("ui", "bar_frame").to_image()
        bx = x - 10
        frame = Image.new("RGBA", (20, 8))
        frame.paste(bar.crop((0, 0, 3, 8)), (0, 0)), frame.paste(bar.crop((13, 0, 16, 8)), (17, 0))
        for k in range(3, 17):
            frame.paste(bar.crop((8, 0, 9, 8)), (k, 0))
        s.img.alpha_composite(frame, (bx, oy + shop.BAR_Y))
        fill = sprites.find("ui", "bar_fill").to_image().resize((4 + i * 5, 4), Image.NEAREST)
        s.img.alpha_composite(fill, (bx + 2, oy + shop.BAR_Y + 2))

    s.put("farm", "warehouse_crate", 22, YARD + 21, crate)
    s.put("ground", "bush", 132, YARD + 6), s.put("ground", "bush", 116, YARD + 22)

    for i, (name, frame) in enumerate(plots):
        s.put("farm", name, 12 + (i % 5) * 24 + 12, FARM + 2 + (i // 5) * 24 + 23, frame)
    s.put("fx", "shadow", 60, FARM + 70)
    s.put("char", "farmer", 60, FARM + 70, "work_1")
    s.put("ground", "tree", 20, 308), s.put("ground", "bush", 52, 300)
    s.put("ground", "tree", 126, 296)
    for c in range(4):
        s.put("ground", "fence_h", 48 + c * 16, 290)
    s.put("fx", "sparkle", 110, FARM + 30, 2)
    s.put("fx", "coin", 60, STREET + 2, 0), s.put("fx", "heart", 27, STREET + 8)

    # the tint multiplies world sprites only; the sky fill is its own colour
    from PIL import ImageChops
    world = ImageChops.multiply(s.img, Image.new("RGBA", s.img.size, rgb_hex(TINT[phase]) + (255,)))
    img = Image.new("RGBA", s.img.size, rgb_hex(SKY[phase]) + (255,))
    img.alpha_composite(world)
    return img.resize((144 * 4, 312 * 4), Image.NEAREST)


def mocks():
    plots_a = [("plot_ready", 0), ("plot_growing", None), ("plot_golden", 0), ("plot_sprout", None),
               ("plot_ready", 1), ("plot_seeded", None), ("plot_ready", 0), ("plot_empty", None),
               ("plot_growing", None), ("plot_sprout", None)]
    plots_b = plots_a[:4] + [("plot_locked", None)]
    main = mock(1, "market", "noon",
                [("woman", "idle_down", 0), ("elder_man", "idle_down", 1), ("gourmet", "idle_down", 2)],
                [("imo", "work_0"), ("chef", "work_1"), ("alba", "idle_down"), ("veteran_alba", "idle_down")],
                plots_a, "half")
    main.save(os.path.join(OUT, "mock_screen.png"))
    mock(0, "alley", "noon",
         [("kid_girl", "idle_down", 0), ("man", "idle_down", 0), ("elder_woman", "idle_down", None)],
         [("alba", "work_0"), None, None, None], plots_b, "empty"
         ).save(os.path.join(OUT, "mock_tier0_alley.png"))
    mock(2, "gangnam", "noon",
         [("gourmet", "idle_down", 2), ("woman", "idle_down", 1), ("man", "idle_down", 0)],
         [("chef", "work_0"), ("veteran_alba", "work_1"), ("imo", "tired"), ("alba", "idle_down")],
         plots_a, "full").save(os.path.join(OUT, "mock_tier2_gangnam.png"))
    mock(1, "market", "dusk",
         [("man", "idle_down", 1), ("kid_girl", "idle_down", 0), ("elder_woman", "idle_down", 2)],
         [("imo", "work_0"), ("chef", "work_1"), ("alba", "tired"), ("veteran_alba", "idle_down")],
         plots_a, "full").save(os.path.join(OUT, "mock_dusk.png"))


def app_icon():
    from sprites.ui import mascot
    import math
    s = Sprite(64, 64, "gold_light")
    # flat sunburst: 12 wedges, no gradient
    for y in range(64):
        for x in range(64):
            a = math.atan2(y - 30.5, x - 31.5)
            if int((a + math.pi) / (2 * math.pi) * 24) % 2 == 0:
                s.px(x, y, "leaf_pale")
    s.ellipse(32, 66, 44, 16, "leaf_light")
    s.ellipse(32, 68, 44, 14, "meadow")
    m = mascot(50, 40, 64)
    s.ellipse(33, 53, 22, 4, "meadow_dark", only={"meadow", "leaf_light"})
    s.blit(m, 0, -1)
    for x, y in ((8, 10), (55, 14), (52, 50)):
        s.px(x, y, "paper")
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            s.px(x + dx, y + dy, "paper")
    img = s.to_image().convert("RGB").resize((1024, 1024), Image.NEAREST)
    img.save(os.path.join(OUT, "appicon_1024.png"))


LAUNCH = os.path.join(REPO, "Resources", "Assets.xcassets", "Launch")
LAUNCH_TITLES = {None: "봄동 타이쿤", "en": "Bomdong Tycoon"}   # None = every other language
LAUNCH_PT = {"LaunchLogo": 4, "LaunchTitle": 2}                # points per art pixel


def launch_title(text):
    """The splash title: Galmuri11-Bold on its 12 px grid, paper with a 1 px ink drop."""
    from PIL import ImageFont
    font = ImageFont.truetype(os.path.join(REPO, "Resources", "Fonts", "Galmuri11-Bold.ttf"), 12)
    x0, y0, x1, y1 = font.getbbox(text)
    img = Image.new("RGBA", (x1 - x0, y1 - y0 + 1), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text((-x0, -y0 + 1), text, font=font, fill="#" + PALETTE["ink"])
    d.text((-x0, -y0), text, font=font, fill="#" + PALETTE["paper"])
    return img


def launch(assets):
    """Logo and title for LaunchScreen.storyboard and SplashView, which must look identical.

    A storyboard image view cannot ask for nearest-neighbour scaling or a bundled font, so both
    are baked here at 2x and 3x with every art pixel already a whole block of device pixels."""
    if os.path.isdir(LAUNCH):
        shutil.rmtree(LAUNCH)
    os.makedirs(LAUNCH)
    write_json(os.path.join(LAUNCH, "Contents.json"), FOLDER_JSON)
    logo = next(a for a in assets if a.group == "ui" and a.name == "logo").frames[0][1].to_image()
    sets = {"LaunchLogo": {None: logo},
            "LaunchTitle": {loc: launch_title(t) for loc, t in LAUNCH_TITLES.items()}}
    for name, by_locale in sets.items():
        d = os.path.join(LAUNCH, f"{name}.imageset")
        os.makedirs(d)
        images = []
        for loc, img in by_locale.items():
            for scale in (2, 3):
                k = LAUNCH_PT[name] * scale
                fn = f"{name}{'_' + loc if loc else ''}@{scale}x.png"
                img.resize((img.width * k, img.height * k), Image.NEAREST).save(os.path.join(d, fn))
                entry = {"filename": fn, "idiom": "universal", "scale": f"{scale}x"}
                if loc:
                    entry["locale"] = loc
                images.append(entry)
        data = {"images": images, "info": {"author": "xcode", "version": 1}}
        if len(by_locale) > 1:
            data["properties"] = {"localizable": True}
        write_json(os.path.join(d, "Contents.json"), data)
        pt = LAUNCH_PT[name]
        print(f"{name}: " + ", ".join(f"{loc or 'base'} {i.width * pt}x{i.height * pt} pt"
                                      for loc, i in by_locale.items()))


def manifest(assets):
    from sfx import SOUNDS
    L = ["# Dot sprite manifest", "",
         "Generated by `tools/dotart/build.py` — do not edit by hand.", "",
         "- Image name = `dot_<group>_<name>[_<frame>]`, in `Resources/Assets.xcassets/Dot/<Group>/` "
         "(folders are not namespaced). One art pixel = one PNG pixel, 1x universal; always "
         "`filteringMode = .nearest`.",
         "- **Anchor** is the art pixel (x right, y down, top-left origin) that sits on the ground "
         "point. **anchorPoint** is the same thing in SpriteKit units (origin bottom-left): "
         "x = (ax + 0.5) / w, y = 1 - (ay + 1) / h.",
         "- Light is top-left; outlines are `ink` (#%s), never black." % PALETTE["ink"], ""]
    for group in sprites.GROUP_ORDER:
        L += [f"## {group}", "", "| Asset | Size | Anchor px | anchorPoint | Frames (in order) | s/frame | Notes |",
              "|---|---|---|---|---|---|---|"]
        for a in [a for a in assets if a.group == group]:
            spr = a.frames[0][1]
            assert all(f.w == spr.w and f.h == spr.h for _, f in a.frames), a.name
            if a.anchor:
                ax, ay = a.anchor
                ap = f"({(ax + 0.5) / spr.w:.3f}, {1 - (ay + 1) / spr.h:.3f})"
                anchor = f"({ax}, {ay})"
            else:
                anchor, ap = "—", "tile: (0, 0)"
            frames = "—" if a.frames[0][0] is None else ", ".join(f"`_{sfx}`" for sfx, _ in a.frames)
            kind = {"anim": "loop: ", "variants": "variants: ", "poses": "poses: ", "single": ""}[a.kind]
            L.append(f"| `dot_{a.group}_{a.name}` | {spr.w}×{spr.h} | {anchor} | {ap} | {kind}{frames} | "
                     f"{a.duration if a.duration else '—'} | {a.note} |")
        L.append("")
    from sprites import shop
    L += ["## Shop slots (identical for tier0 / tier1 / tier2)", "",
          "Pixel coordinates inside the 144×64 shop image, top-left origin. Place each sprite so its "
          "own anchor pixel lands on the slot.", "",
          "| Slot | x | y | What goes there |", "|---|---|---|---|"]
    for i, x in enumerate(shop.DISH_X):
        L.append(f"| dish {i + 1} (menu {i}) | {x} | {shop.DISH_Y} | `dot_dish_*` (anchor 8,15) — counter top is empty here |")
    for i, x in enumerate(shop.COOK_X):
        L.append(f"| cook {i + 1} | {x} | {shop.STAFF_Y} | staff `dot_char_*` (anchor 8,23), between `_back` and `_front` |")
    L += [f"| cashier | {shop.CASHIER_X} | {shop.STAFF_Y} | staff sprite; the till is drawn at x 128–137 on the counter |",
          f"| counter top surface | 4–139 | {shop.COUNTER_TOP}–{shop.COUNTER_FRONT - 1} | rows of the top surface |",
          f"| counter front panel | 6–137 | {shop.COUNTER_FRONT}–63 | plain; progress bars / stock counts go here |",
          f"| progress bar | dish x − 10 | {shop.BAR_Y} | 20×8 `dot_ui_bar_frame` under each dish |", "",
          "## Shop name board (differs per tier)", "",
          "The blank signboard on the roof. The scene draws the player's shop name inside the text "
          "area: the board's interior, clear of its frame and top highlight.", "",
          "| Tier | text area x | text area y | w | h |", "|---|---|---|---|---|"]
    for n in sorted(shop.BOARDS):
        x, y, w, h = shop.sign_area(n)
        L.append(f"| {n} | {x}–{x + w - 1} | {y}–{y + h - 1} | {w} | {h} |")
    L += ["",
          "Draw order: `tierN_back` → staff → `tierN_front` → dishes → bars. With that order the "
          "counter hides staff legs (sprite rows 20–23) and their heads clear the roof.", "",
          "Customers queue on the street band above the shop: anchor y = street top + 29 "
          "(3 px above the shop image's top edge), x = 40, 66, 92 in the mock; the order bubble's tail "
          "tip goes 24 px above the feet (just over the hair).", "",
          "## Screen bands used by mock_screen.png (art px, top-left origin, 144 wide)", "",
          "| Band | y | Notes |", "|---|---|---|",
          "| backdrop | 0–55 | sky fill + `dot_backdrop_<location>` |",
          "| street | 56–87 | 9×2 street tiles |",
          "| shop | 88–151 | shop image origin (0, 88) |",
          "| yard | 152–175 | grass, path strip rows 156–171, crate anchor (22, 173) |",
          "| farm | 176–247 | plot cell i at x = 12 + 24·(i mod 5), y = 178 + 24·(i div 5) |",
          "| grass | 248– | filler |", "",
          "## Palette", "", "| Name | Hex |", "|---|---|"]
    L += [f"| {k} | #{v} |" for k, v in PALETTE.items()]
    L += ["", "## Sky fill and world tint per day phase", "",
          "The sky is a flat fill behind the backdrop; the tint is a multiply colour for every world "
          "sprite (`color` + `colorBlendFactor = 1`). Interpolate between phases.", "",
          "| Phase | Sky | Tint |", "|---|---|---|"]
    L += [f"| {k} | #{SKY[k]} | #{TINT[k]} |" for k in SKY]
    L += ["", "## SFX (`Resources/Sounds/`, mono 22050 Hz 16-bit)", "", "| File | Length (s) | Use |",
          "|---|---|---|"]
    L += [f"| `{name}.wav` | {dur:.2f} | {use} |" for name, dur, use in SOUNDS]
    L.append("")
    with open(os.path.join(HERE, "MANIFEST.md"), "w") as fh:
        fh.write("\n".join(L))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-install", action="store_true")
    args = ap.parse_args()
    assets = sprites.load_all()
    names = [n for a in assets for n, _ in a.image_names()]
    assert len(names) == len(set(names)), "duplicate image name"
    os.makedirs(OUT, exist_ok=True)
    contact_sheet(assets)
    mocks()
    app_icon()
    manifest(assets)
    if not args.no_install:
        launch(assets)
        install(assets)
    print(f"{len(assets)} assets, {len(names)} images; review sheets in {os.path.relpath(OUT, REPO)}")


if __name__ == "__main__":
    main()
