"""Ground tiles (no outline: they are surface, not props) and outlined scenery."""

import random

from canvas import Sprite
from . import add


def _grass(seed, flowers=None):
    r = random.Random(seed)
    s = Sprite(16, 16, "meadow")
    for _ in range(5):
        x, y = r.randrange(1, 14), r.randrange(1, 14)
        s.px(x, y, "meadow_dark"), s.px(x + 1, y - 1, "meadow_dark"), s.px(x + 2, y, "meadow_dark")
    for _ in range(4):
        x, y = r.randrange(16), r.randrange(16)
        s.px(x, y, "leaf_light")
    for i in range(flowers or 0):
        x, y = r.randrange(2, 13), r.randrange(2, 13)
        petal = ("paper", "pink", "gold_light")[(seed + i) % 3]
        s.px(x, y - 1, petal), s.px(x - 1, y, petal), s.px(x + 1, y, petal), s.px(x, y + 1, petal)
        s.px(x, y, "gold")
    return s


def _path():
    r = random.Random(7)
    s = Sprite(16, 16, "sand")
    for _ in range(9):
        s.px(r.randrange(16), r.randrange(16), "soil_light")
    for _ in range(5):
        x, y = r.randrange(15), r.randrange(16)
        s.hline(x, y, 2, "cream")
    return s


def _cobble():
    s = Sprite(16, 16, "grey_light")
    for row in range(4):
        y = row * 4
        s.hline(0, y + 3, 16, "grey")
        off = 0 if row % 2 == 0 else 4
        for x in (off, off + 8):
            s.vline(x % 16, y, 3, "grey")
    for x, y in ((2, 0), (10, 0), (6, 4), (14, 4), (2, 8), (10, 8), (6, 12)):
        s.hline(x, y, 3, "paper")
    for x, y in ((12, 1), (1, 5), (13, 9), (9, 13)):
        s.rect(x, y, 2, 1, "cream")
    return s


def _paving():
    s = Sprite(16, 16, "sand")
    for o in (0, 8):
        s.hline(0, o + 7, 16, "soil_light")
        s.vline(o + 7, 0, 16, "soil_light")
        s.hline(o, o, 6, "cream")
    s.px(3, 4, "soil_light"), s.px(12, 11, "soil_light"), s.px(2, 12, "cream")
    return s


def _asphalt(crosswalk=False):
    r = random.Random(3)
    s = Sprite(16, 16, "grey_dark")
    for _ in range(10):
        s.px(r.randrange(16), r.randrange(16), "grey")
    for _ in range(6):
        s.px(r.randrange(16), r.randrange(16), "plum")
    if crosswalk:
        # two bars per tile so a 32px street band shows four stripes
        for y in (1, 9):
            s.rect(0, y, 16, 5, "paper")
            s.hline(0, y + 4, 16, "grey_light")
            s.px(3, y + 2, "grey_light"), s.px(11, y + 1, "grey_light")
    return s


def _fence():
    s = Sprite(16, 16)
    s.rect(0, 6, 16, 2, "sand"), s.rect(0, 11, 16, 2, "sand")
    s.hline(0, 7, 16, "soil_light"), s.hline(0, 12, 16, "soil_light")
    for x in (2, 10):
        s.rect(x, 3, 4, 12, "sand")
        s.vline(x + 3, 3, 12, "soil_light")
        s.hline(x + 1, 2, 2, "sand")
        s.vline(x, 4, 10, "cream")
    s.outline("ink")
    # the rails run off both edges so the fence tiles; outline() closed them
    for y in (6, 7, 11, 12):
        s.px(0, y, "sand" if y in (6, 11) else "soil_light")
        s.px(15, y, "sand" if y in (6, 11) else "soil_light")
    return s


def foliage(w, h, blobs, trunk=None):
    s = Sprite(w, h)
    if trunk:
        x, y, tw, th = trunk
        s.rect(x, y, tw, th, "soil")
        s.vline(x, y, th, "soil_light")
        s.vline(x + tw - 1, y, th, "soil_dark")
        s.hline(x - 1, y + th - 1, tw + 2, "soil")
    for cx, cy, r in blobs:
        s.ellipse(cx, cy, r, r * 0.85, "leaf_dark")
    for cx, cy, r in blobs:
        s.ellipse(cx - 1, cy - 1.2, r - 1.6, (r - 1.6) * 0.85, "leaf")
    for cx, cy, r in blobs:
        s.ellipse(cx - r * 0.35, cy - r * 0.4, r * 0.38, r * 0.3, "leaf_light")
    for cx, cy, r in blobs:
        s.px(int(cx + r * 0.3), int(cy + r * 0.45), "leaf_deep")
        s.px(int(cx + r * 0.3) - 1, int(cy + r * 0.45) + 1, "leaf_deep")
    s.outline("ink")
    return s


add("ground", "grass", [_grass(1), _grass(2), _grass(5)], kind="variants",
    note="tile freely; pick a variant per cell")
add("ground", "grass_flower", [_grass(11, 2), _grass(12, 3)], kind="variants")
add("ground", "path", _path(), note="yard dirt; tiles in both axes")
add("ground", "street_alley", _cobble(), note="tiles in both axes; street band = 2 rows")
add("ground", "street_market", _paving())
add("ground", "street_gangnam", _asphalt())
add("ground", "street_gangnam_crosswalk", _asphalt(True),
    note="use for a 2-3 tile wide crossing in the gangnam street")
add("ground", "fence_h", _fence(), anchor=(8, 15), note="tiles horizontally")
add("ground", "bush", foliage(16, 16, [(5.5, 9.5, 4.5), (10.5, 9, 4.5), (8, 6.5, 4.5)]),
    anchor=(8, 15))
add("ground", "tree", foliage(32, 40, [(10, 17, 8), (22, 17, 8), (16, 10, 9), (16, 21, 8)],
                              trunk=(14, 26, 5, 12)), anchor=(16, 39))
