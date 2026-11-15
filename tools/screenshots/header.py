#!/usr/bin/env python3
"""App Store header images: a panorama of the three locations with the title in the sky.

    python3 tools/screenshots/header.py   # -> fastlane/header/<locale>_<w>x<h>.png

App Store Connect accepts 5244x2950 and 3840x1646. Both are drawn from the dot-art sprites at
an integer scale, so nothing is resampled.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "dotart"))
import sprites  # noqa: E402
from build import GRASS, Scene  # noqa: E402
from palette import PALETTE, SKY, rgb_hex  # noqa: E402
from sprites import shop  # noqa: E402

OUT = ROOT / "fastlane" / "header"
FONT = ROOT / "Resources" / "Fonts" / "Galmuri11-Bold.ttf"

# (output size, device pixels per art pixel). The art canvas is the size divided by the scale,
# rounded up; the last partial art pixel is cropped off the right and bottom edges.
SIZES = [((3840, 1646), 6), ((5244, 2950), 10)]
TITLES = {"ko": "봄동 타이쿤", "en-US": "Bomdong Tycoon"}
# One signboard name per shop tier; the game writes the player's own shop name there.
SIGNS = {"ko": ["봄동 포차", "봄동 식당", "봄동 전문점"], "en-US": ["Food Cart", "Diner", "Specialty"]}

SECTION = 144                      # one backdrop / one shop, in art px
BACKDROP_H, STREET_H, SHOP_H, YARD_H = 56, 32, 64, 30
LOCATIONS = ["alley", "market", "gangnam"]
STAFF = [
    [("alba", "work_0"), None, None, None],
    [("imo", "work_0"), ("chef", "work_1"), None, ("alba", "idle_down")],
    [("chef", "work_0"), ("veteran_alba", "work_1"), ("imo", "work_0"), ("alba", "idle_down")],
]
DISHES = ["geotjeori", "kimchi", "bibimbap"]
# (who, pose, x within the section, dish wanted or None)
CUSTOMERS = [
    [("kid_girl", "idle_down", 34, 0), ("elder_woman", "idle_down", 100, None)],
    [("woman", "idle_down", 30, 0), ("elder_man", "idle_down", 66, 1), ("man", "walk_side_0", 118, None)],
    [("gourmet", "idle_down", 40, 2), ("woman", "idle_down", 74, 1), ("man", "idle_down", 108, 0)],
]
PLOTS = [("plot_ready", 0), ("plot_golden", 0), ("plot_growing", None),
         ("plot_sprout", None), ("plot_ready", 1), ("plot_ready", 0)]

# The video (header_video.py) draws this same scene once per frame. Every cycle below is a
# whole number of 30 fps frames and divides LOOP, so the last frame runs into the first.
LOOP = 720                         # 24 s
WORK, WALK, SPIN = 9, 6, 3         # frames per pose: 0.3 s, 0.2 s, 0.1 s
SWAY = {"plot_ready": 18, "plot_golden": 10}
CLOUD_PERIOD = 224                 # clouds repeat at this spacing and drift exactly one spacing per loop
# (who, heading right, frame it enters, feet row below the street's top edge). 1 px per frame is
# the game's 30 px/s walk; the 672 px from one off-screen edge to the other fit inside one loop.
WALKERS = [("man", False, 0, 21), ("woman", False, 430, 22), ("kid_boy", True, 200, 24)]
COIN_POP = 240                     # each till pops a coin this often, a third of a cycle apart


def step(f, hold, count, first=0):
    """The frame of a `count`-pose loop at video frame f; the still (f is None) shows `first`."""
    return first if f is None else (first + f // hold) % count


def world(width, height, f=None):
    """The art-pixel scene: sky, skyline, street, one shop per location, yard.

    f is the video frame; None draws the still.
    """
    scene = Scene(width, height)
    x0 = (width - SECTION * 3) // 2
    street = height - YARD_H - SHOP_H - STREET_H
    shop_top = street + STREET_H

    scene.put("backdrop", "sun", width - 40, 26)
    if f is None:
        scene.put("backdrop", "cloud", 34, 22, 0)
        scene.put("backdrop", "cloud", width - 92, 46, 1)
        scene.put("backdrop", "cloud", 96, 52, 1)
    else:
        drift = CLOUD_PERIOD * f // LOOP
        for k in range(width // CLOUD_PERIOD + 2):
            scene.put("backdrop", "cloud", 34 + k * CLOUD_PERIOD - drift, 22, 0)
            scene.put("backdrop", "cloud", 146 + k * CLOUD_PERIOD - drift, 48, 1)

    # Sections run alley -> market -> gangnam; the outer two repeat to the canvas edges.
    for i in range(-2, 5):
        location = LOCATIONS[min(max(i, 0), 2)]
        x = x0 + i * SECTION
        if x >= width or x + SECTION <= 0:
            continue
        scene.put("backdrop", location, x, street - 1)
        scene.tiles("ground", [(f"street_{location}", None)], x, street, 9, 2)
    scene.tiles("ground", GRASS, x0 % 16 - 16, shop_top, width // 16 + 2, (height - shop_top) // 16 + 1, seed=2)

    feet = street + 29
    if f is not None:
        # Passers-by cross behind the queue, edge to edge.
        for who, right, enters, row in WALKERS:
            walked = (f - enters) % LOOP
            wx = walked - 16 if right else width + 16 - walked
            scene.put("fx", "shadow", wx, street + row)
            scene.put("char", who, wx, street + row, f"walk_side_{step(walked, WALK, 2)}", flip=right)
    for i in range(3):
        x = x0 + i * SECTION
        for c, (who, pose, dx, want) in enumerate(CUSTOMERS[i]):
            if f is not None and pose.startswith("walk"):
                continue           # the still's one walker is a passer-by in the video
            scene.put("fx", "shadow", x + dx, feet)
            scene.put("char", who, x + dx, feet, pose)
            if want is not None:
                bob = 0 if f is None else step(f + (i * 2 + c) * 7, 18, 2)
                scene.put("fx", "bubble", x + dx, feet - 24 - bob)
                scene.put("dish", DISHES[want], x + dx + 1, feet - 28 - bob)

        scene.put("shop", f"tier{i}_back", x, shop_top + SHOP_H - 1)
        for staff, sx in zip(STAFF[i], shop.COOK_X + (shop.CASHIER_X,)):
            if staff:
                pose = staff[1]
                if pose.startswith("work_"):
                    pose = f"work_{step(f, WORK, 2, int(pose[-1]))}"
                scene.put("char", staff[0], x + sx, shop_top + shop.STAFF_Y, pose)
        scene.put("shop", f"tier{i}_front", x, shop_top + SHOP_H - 1)
        for d, dish_x in enumerate(shop.DISH_X):
            scene.put("dish", DISHES[d] if d <= i else "empty_bowl", x + dish_x, shop_top + shop.DISH_Y)
        if f is not None:
            pop = (f - i * COIN_POP // 3) % COIN_POP
            if pop < 30:
                # 12 px right of the cashier is the till in all three tiers.
                scene.put("fx", "coin", x + shop.CASHIER_X + 12, shop_top + shop.STAFF_Y - 14 - pop // 2,
                          step(pop, SPIN, 4))

    # Yard on both sides of the shops: a field when there is room, trees and bushes always.
    side = x0
    for left in (True, False):
        edge = 0 if left else x0 + SECTION * 3
        if side >= 96:
            px = edge + (side - 72) // 2
            for p, (name, frame) in enumerate(PLOTS):
                if name in SWAY:
                    frame = step(f, SWAY[name], 2, frame)
                scene.put("farm", name, px + (p % 3) * 24 + 12, shop_top + 30 + (p // 3) * 24 + 23, frame)
            scene.put("fx", "shadow", px + 36, shop_top + 28)
            scene.put("char", "farmer", px + 36, shop_top + 28, f"work_{step(f, WORK, 2, 1)}")
        scene.put("ground", "tree", edge + (10 if left else side - 12), height - 4)
        scene.put("ground", "bush", edge + (side - 14 if left else 12), height - 6)
    for c in range(3 * SECTION // 16):
        scene.put("ground", "fence_h", x0 + c * 16 + 8, height - 2)
    scene.put("fx", "coin", x0 + SECTION + 52, street + 6, step(f, SPIN, 4))
    scene.put("fx", "sparkle", x0 + SECTION * 2 + 124, street - 30, step(f, SPIN, 4, 2))

    image = Image.new("RGBA", scene.img.size, rgb_hex(SKY["noon"]) + (255,))
    image.alpha_composite(scene.img)
    return image, street - BACKDROP_H, x0, shop_top


def signs(image, names, scale, x0, shop_top):
    """Shop names on the three roof signboards, inside each tier's text area."""
    draw = ImageDraw.Draw(image)
    for tier, name in enumerate(names):
        x, y, w, h = shop.sign_area(tier)
        # Tier 0's board is 10 rows tall: Galmuri9 (10 px em) fits, Galmuri11 (12 px em) does not.
        face, em = ("Galmuri9.ttf", 10) if tier == 0 else ("Galmuri11-Bold.ttf", 12)
        font = ImageFont.truetype(str(FONT.parent / face), em * scale)
        left, top, right, bottom = draw.textbbox((0, 0), name, font=font)
        cx = (x0 + tier * SECTION + x) * scale + (w * scale - (right - left)) // 2 - left
        cy = (shop_top + y) * scale + (h * scale - (bottom - top)) // 2 - top
        draw.text((cx, cy), name, font=font, fill=rgb_hex(PALETTE["ink"]))


def title(image, text, scale, sky_height):
    """Mascot logo and title, centred in the sky above the skyline."""
    logo = sprites.find("ui", "logo").to_image()
    logo = logo.resize((logo.width * scale, logo.height * scale), Image.NEAREST)
    # Galmuri11 sits on a 12 px em: 36 art px is its 3x size.
    font = ImageFont.truetype(str(FONT), 36 * scale)
    draw = ImageDraw.Draw(image)
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    gap = 8 * scale
    total = logo.width + gap + (right - left)
    x = (image.width - total) // 2
    centre = (sky_height * scale) // 2 + 6 * scale
    image.alpha_composite(logo, (x, centre - logo.height // 2))
    tx = x + logo.width + gap - left
    ty = centre - (top + bottom) // 2
    ink, paper = rgb_hex(PALETTE["ink"]), rgb_hex(PALETTE["paper"])
    step = scale * 2
    for dx in (-step, 0, step):
        for dy in (-step, 0, step, step * 2):
            draw.text((tx + dx, ty + dy), text, font=font, fill=ink)
    draw.text((tx, ty), text, font=font, fill=paper)


def main():
    sprites.load_all()
    OUT.mkdir(parents=True, exist_ok=True)
    for (width, height), scale in SIZES:
        art, sky_height, x0, shop_top = world(-(-width // scale), -(-height // scale))
        big = art.resize((art.width * scale, art.height * scale), Image.NEAREST).crop((0, 0, width, height))
        for locale, text in TITLES.items():
            image = big.copy()
            title(image, text, scale, sky_height)
            signs(image, SIGNS[locale], scale, x0, shop_top)
            path = OUT / f"{locale}_{width}x{height}.png"
            image.convert("RGB").save(path, optimize=True)
            print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
