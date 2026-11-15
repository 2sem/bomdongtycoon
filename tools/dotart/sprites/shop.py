"""The three stall tiers, 144x64, front view. Each is authored as a back layer
(building + interior) and a front layer (counter + till) so staff can stand
between them; the plain `tierN` image is the two composited."""

from canvas import Sprite
from . import add

W, H = 144, 64

# Shared by every tier, so the scene needs one set of constants.
COUNTER_TOP = 46      # first row of the counter's top surface (rows 46..51)
COUNTER_FRONT = 52    # first row of the counter's front panel (rows 52..63)
DISH_X = (30, 63, 96)
DISH_Y = 50           # dish anchor row: bowl sits on the surface, 1 row of counter shows in front
COOK_X = (15, 48, 81)
CASHIER_X = 118
STAFF_Y = 49          # staff anchor row; the counter hides their legs (sprite rows 20+)
BAR_Y = 54            # an 8px progress bar fits rows 54..61 of the front panel


def counter(s, x0, x1, top, top_hi, top_lo, front, seam, base, seam_step=11):
    s.rect(x0, COUNTER_TOP, x1 - x0 + 1, 6, top)
    s.hline(x0, COUNTER_TOP, x1 - x0 + 1, top_hi)
    s.hline(x0, COUNTER_TOP + 5, x1 - x0 + 1, top_lo)
    s.rect(x0 + 2, COUNTER_FRONT, x1 - x0 - 3, 11, front)
    s.hline(x0 + 2, COUNTER_FRONT, x1 - x0 - 3, seam)
    if seam_step:
        for x in range(x0 + 2 + seam_step, x1 - 2, seam_step):
            s.vline(x, COUNTER_FRONT + 1, 10, seam)
    s.hline(x0 + 2, 62, x1 - x0 - 3, base)


def tier0():
    b, f = Sprite(W, H), Sprite(W, H)
    # interior: back tarp
    b.rect(7, 28, 130, 24, "orange_dark")
    for x in range(15, 136, 16):
        b.vline(x, 28, 24, "red_dark")
    b.rect(7, 28, 130, 2, "red_dark")
    b.rect(7, 42, 130, 10, "plum")
    b.dither(7, 40, 130, 2, "plum")
    # bare bulb with a dithered glow on the tarp
    b.vline(71, 28, 4, "ink")
    b.ellipse(71.5, 34, 6, 5, "orange", only={"orange_dark", "red_dark"})
    b.dither(64, 30, 15, 9, "gold", only={"orange"})
    b.rect(70, 32, 3, 4, "gold_light"), b.px(71, 33, "paper"), b.px(71, 31, "grey")
    # poles
    for x in (5, 137):
        b.rect(x, 24, 2, 40, "grey"), b.vline(x, 24, 40, "grey_light")
    # roof tarp: 12 rows, widening 1px per row from x16..127 to x4..139
    roof = Sprite(W, H)
    for i in range(13):
        roof.hline(16 - i, 10 + i, 112 + 2 * i, "orange")
    for i in range(13):
        roof.px(17 - i, 10 + i, "gold"), roof.px(18 - i, 10 + i, "gold")
    roof.hline(17, 10, 110, "gold")
    for k in range(1, 8):
        xt, xb = 16 + k * 14, 4 + k * 17
        roof.line(xt, 11, xb, 22, "orange_dark")
    # valance: 8px stripes, scalloped
    for x in range(4, 140):
        c = "orange" if ((x - 4) // 8) % 2 == 0 else "cream"
        roof.vline(x, 23, 4, c)
        if (x - 4) % 8 not in (0, 7):
            roof.px(x, 27, c)
    roof.hline(4, 23, 136, "orange_dark")
    roof.outline("ink")
    b.blit(roof, 0, 0)
    # name board propped on the ridge, on two short legs
    for x in (48, 94):
        b.rect(x, 9, 2, 10, "soil"), b.frame(x - 1, 8, 4, 12, "ink")
    b.blit(*board(0))

    counter(f, 4, 139, "grey_light", "paper", "grey", "orange", "orange_dark", "red_dark", 0)
    for x in range(6, 137):
        if (x - 6) % 8 >= 4:
            f.vline(x, 53, 7, "orange_dark")
    f.rect(6, 60, 131, 3, None)
    for x in range(6, 137):
        if (x - 6) % 8 not in (0, 7):
            f.px(x, 60, "orange" if (x - 6) % 8 < 4 else "orange_dark")
    for wx in (22, 121):
        f.ellipse(wx, 59.5, 4.5, 4.5, "ink")
        f.ellipse(wx, 59.5, 2.6, 2.6, "grey"), f.rect(wx - 1, 59, 2, 2, "grey_dark")
        f.px(wx - 2, 58, "grey_light")
    # cash tin
    f.rect(129, 41, 7, 5, "grey"), f.hline(129, 41, 7, "grey_light"), f.vline(135, 42, 4, "grey_dark")
    f.hline(130, 40, 5, "gold"), f.px(131, 39, "gold_light"), f.px(133, 39, "gold")
    f.outline("ink")
    return b, f


def tiled_roof():
    r = Sprite(W, H)
    for y in range(4, 18):
        x0 = 10 - (y - 4) * 10 // 13
        r.hline(x0, y, W - 2 * x0, "grey_dark")
    for y in range(4, 18):
        x0 = 10 - (y - 4) * 10 // 13
        for x in range(x0, W - x0):
            m = (x - 72) % 6
            if m == 0:
                r.px(x, y, "grey")
            elif m == 1:
                r.px(x, y, "plum")
        if y % 5 == 0:
            for x in range(x0, W - x0):
                if (x - 72) % 6 not in (0, 1):
                    r.px(x, y, "plum")
    r.rect(8, 1, 128, 3, "grey_dark"), r.hline(8, 1, 128, "grey"), r.hline(8, 3, 128, "plum")
    r.rect(5, 0, 4, 3, "grey_dark"), r.rect(135, 0, 4, 3, "grey_dark")
    r.px(5, 0, "grey"), r.px(135, 0, "grey")
    # eave: round tile ends
    for x in range(0, W):
        m = (x - 72) % 6
        r.vline(x, 18, 3, "grey" if m in (2, 3, 4, 5) else "plum")
        if m in (2, 5):
            r.px(x, 20, "plum")
        if m == 3:
            r.px(x, 18, "grey_light")
    r.outline("ink")
    return r


def name_board(w, h, fill="sand", edge="soil", hi="cream"):
    """Blank signboard, (w+2) x (h+2) with its outline. The scene writes the player's shop
    name on it, so nothing is drawn inside the frame."""
    s = Sprite(w + 2, h + 2)
    s.rect(1, 1, w, h, fill)
    s.frame(1, 1, w, h, edge)
    s.hline(2, 2, w - 2, hi)
    return s.outline("ink")


# Signboard per tier: (blit x, blit y, w, h, fill, edge, highlight). Widths are sized for the
# name, not the roof: 6 hangul at Galmuri9 (10 px each) is 60 px, at Galmuri11-Bold 72 px.
BOARDS = {
    0: (38, 2, 66, 13, "paper", "red_dark", "paper"),
    1: (36, 5, 70, 15, "sand", "soil", "cream"),
    2: (33, 0, 76, 19, "cream", "gold", "paper"),
}


def sign_area(tier):
    """(x, y, w, h) of the rows and columns free for text: inside the frame, below the highlight."""
    x, y, w, h = BOARDS[tier][:4]
    return x + 2, y + 3, w - 2, h - 3


def board(tier):
    x, y, w, h, fill, edge, hi = BOARDS[tier]
    return name_board(w, h, fill, edge, hi), x, y


def tier1():
    b, f = Sprite(W, H), Sprite(W, H)
    # interior
    b.rect(8, 26, 128, 26, "plum")
    b.rect(8, 26, 128, 2, "ink")
    b.rect(8, 40, 128, 12, "soil_dark")
    b.hline(8, 39, 128, "soil")
    for x in range(14, 136, 10):
        b.vline(x, 40, 12, "plum")
    # menu plaques above each dish spot (no text, just rule marks)
    for x in DISH_X:
        b.rect(x - 5, 29, 10, 7, "cream"), b.frame(x - 5, 29, 10, 7, "soil")
        b.hline(x - 3, 31, 6, "soil_light"), b.hline(x - 3, 33, 4, "soil_light")
    # noren
    for x0 in range(9, 135, 18):
        b.rect(x0, 26, 16, 5, "leaf_dark"), b.hline(x0, 30, 16, "leaf_deep")
        b.rect(x0 + 7, 27, 2, 2, "leaf_pale")
    # posts and beam
    for x in (2, 136):
        b.rect(x, 22, 6, 42, "soil"), b.vline(x, 22, 42, "soil_light"), b.vline(x + 5, 22, 42, "soil_dark")
    b.rect(2, 21, 140, 5, "soil"), b.hline(2, 21, 140, "soil_light"), b.hline(2, 25, 140, "soil_dark")
    frame = Sprite(W, H)
    for x in (2, 136):
        frame.rect(x, 22, 6, 42, "soil")
    frame.rect(2, 21, 140, 5, "soil")
    frame.outline("ink")
    for y in range(H):
        for x in range(W):
            if frame.g[y][x] == "ink":
                b.px(x, y, "ink")
    # paper lantern on the right post side
    b.rect(129, 29, 5, 7, "red"), b.vline(129, 30, 5, "pink"), b.hline(129, 29, 5, "red_dark")
    b.hline(129, 35, 5, "red_dark"), b.frame(128, 28, 7, 9, "ink"), b.vline(131, 26, 2, "ink")
    b.blit(tiled_roof(), 0, 0)
    b.blit(*board(1))

    counter(f, 3, 140, "sand", "cream", "soil_light", "soil", "soil_dark", "soil_dark")
    for x in range(5, 138, 11):
        f.vline(x + 1, 53, 9, "soil_light")
    # till
    f.rect(128, 39, 9, 7, "grey_dark"), f.hline(128, 39, 9, "grey"), f.rect(130, 41, 4, 2, "sky")
    f.px(135, 42, "gold"), f.px(135, 44, "red"), f.hline(130, 44, 3, "grey")
    f.outline("ink")
    return b, f


def tier2():
    b, f = Sprite(W, H), Sprite(W, H)
    # interior: tiled wall above, warm panel below
    b.rect(8, 30, 128, 22, "cream")
    for y in range(31, 41):
        for x in range(8, 136):
            if (x - 8) % 6 == 5 or (y - 31) % 5 == 4:
                b.px(x, y, "sand")
    b.rect(8, 41, 128, 11, "sand"), b.hline(8, 41, 128, "soil_light")
    b.rect(8, 30, 128, 1, "soil_light")
    # framed specials boards between the stations (no text)
    for x in (39, 72, 105):
        b.rect(x - 4, 32, 8, 6, "leaf_dark"), b.frame(x - 5, 31, 10, 8, "gold_dark")
        b.hline(x - 2, 34, 4, "leaf_pale"), b.hline(x - 2, 36, 3, "leaf_light")
    # pillars
    for x in (0, 136):
        b.rect(x, 22, 8, 42, "paper"), b.vline(x + 6, 22, 42, "grey_light")
        b.vline(x + 1, 22, 42, "cream"), b.rect(x, 60, 8, 4, "grey")
        b.frame(x, 22, 8, 42, "ink")
        b.rect(x + 3, 34, 2, 4, "gold"), b.px(x + 3, 34, "gold_light")
    # awning
    for x in range(0, W):
        c = "leaf" if (x // 8) % 2 == 0 else "paper"
        b.vline(x, 22, 7, c)
        b.px(x, 28, "leaf_dark" if c == "leaf" else "grey_light")
        if x % 8 not in (0, 7):
            b.px(x, 29, c), b.px(x, 30, "ink")
        else:
            b.px(x, 29, "ink")
    # fascia
    b.rect(0, 8, W, 14, "leaf_dark"), b.hline(0, 8, W, "leaf"), b.hline(0, 20, W, "gold")
    b.hline(0, 21, W, "leaf_deep"), b.hline(0, 7, W, "ink")
    b.vline(0, 8, 14, "ink"), b.vline(143, 8, 14, "ink")
    for x in (14, 30, 110, 126):
        b.rect(x, 12, 4, 5, "leaf"), b.px(x, 12, "leaf_light")
    b.blit(*board(2))

    counter(f, 2, 141, "paper", "paper", "grey_light", "leaf_dark", "leaf_deep", "leaf_deep", 0)
    f.hline(4, 54, 136, "gold")
    f.hline(4, 61, 136, "leaf_deep")
    # tablet till
    f.rect(128, 37, 9, 7, "navy"), f.rect(129, 38, 7, 5, "sky"), f.px(130, 39, "paper")
    f.rect(131, 44, 3, 2, "grey_dark")
    f.outline("ink")
    return b, f


def composite(layers):
    s = Sprite(W, H)
    for layer in layers:
        s.blit(layer, 0, 0)
    return s


SLOTS = {
    "dish_anchor_1": (DISH_X[0], DISH_Y), "dish_anchor_2": (DISH_X[1], DISH_Y),
    "dish_anchor_3": (DISH_X[2], DISH_Y),
    "cook_anchor_1": (COOK_X[0], STAFF_Y), "cook_anchor_2": (COOK_X[1], STAFF_Y),
    "cook_anchor_3": (COOK_X[2], STAFF_Y),
    "cashier_anchor": (CASHIER_X, STAFF_Y),
    "counter_top_rows": (COUNTER_TOP, COUNTER_FRONT - 1),
    "counter_front_rows": (COUNTER_FRONT, 63),
    "progress_bar_top_row": BAR_Y,
}
TIERS = {0: tier0(), 1: tier1(), 2: tier2()}
NAMES = {0: "포장마차", 1: "봄동 식당", 2: "봄동 전문점"}
for n, (back, front) in TIERS.items():
    add("shop", f"tier{n}", composite([back, front]), anchor=(0, 63), slots=SLOTS,
        note=NAMES[n] + ". whole stall in one image (use this if staff are drawn on top)")
    add("shop", f"tier{n}_back", back, anchor=(0, 63),
        note="building + interior only; draw first")
    add("shop", f"tier{n}_front", front, anchor=(0, 63),
        note="counter + till only, same 144x64 frame; draw over the staff so it hides their legs")
