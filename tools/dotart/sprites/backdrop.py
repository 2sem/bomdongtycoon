"""Location skylines, 144x56, sky left transparent. Each tiles horizontally:
near buildings stop short of both edges, and the far layer, wires and base wall
are periodic in 144."""

from canvas import Sprite
from . import add

W, H = 144, 56
BASE = 50  # top of the base wall; everything stands on this row


def far_layer(s, heights, colour, window=None, step=12):
    for i, h in enumerate(heights):
        x = i * step
        s.rect(x, BASE - h, step, h, colour)
        if window:
            for wy in range(BASE - h + 3, BASE - 2, 4):
                for wx in range(x + 2, x + step - 2, 3):
                    if (wx * 7 + wy * 3) % 5 < 2:
                        s.px(wx, wy, window)


def base_wall(s, top, body, cap):
    s.rect(0, BASE, W, H - BASE, body)
    s.hline(0, BASE, W, cap)
    s.hline(0, H - 1, W, top)


def box(s, x, y, w, h, fill, edge="plum"):
    s.rect(x, y, w, h, fill)
    s.frame(x, y, w, h, edge)


def window(s, x, y, w=4, h=5, lit=False):
    s.rect(x, y, w, h, "gold_light" if lit else "navy")
    s.px(x, y, "paper" if lit else "sky")
    s.frame(x - 1, y - 1, w + 2, h + 2, "plum")


def wire(s, x0, x1, y, sag, colour="plum"):
    n = x1 - x0
    for i in range(n + 1):
        t = i / n
        s.px((x0 + i) % W, round(y + sag * 4 * t * (1 - t)), colour)


def house(s, x, w, h, wall, roof, flat=False):
    top = BASE - h
    box(s, x, top, w, h + 1, wall)
    s.vline(x + w - 2, top + 1, h - 1, {"cream": "sand", "paper": "grey_light",
                                       "sand": "soil_light", "pink": "mauve"}.get(wall, wall))
    if flat:
        s.rect(x - 1, top - 2, w + 2, 3, roof)
        s.frame(x - 1, top - 2, w + 2, 3, "plum")
        for rx in range(x + 1, x + w - 1, 3):
            s.vline(rx, top - 5, 3, "grey_dark")
        s.hline(x, top - 5, w, "grey_dark")
    else:
        for i in range(7):
            s.hline(x - 2 + (6 - i) // 2, top - 6 + i, w + 4 - 2 * ((6 - i) // 2), roof)
        s.hline(x + 1, top - 6, w - 2, "plum")
        s.hline(x - 2, top + 1, w + 4, "plum")
        for rx in range(x + 1, x + w, 4):
            s.vline(rx, top - 4, 4, "plum" if roof != "plum" else "ink")
        s.hline(x + 1, top - 5, w - 2, {"red_dark": "red", "navy": "blue", "soil_dark": "soil",
                                        "grey_dark": "grey", "orange_dark": "orange"}[roof])


def alley():
    s = Sprite(W, H)
    far_layer(s, [16, 22, 18, 26, 20, 15, 24, 19, 27, 17, 23, 14], "grey_light", "paper")
    house(s, 3, 26, 22, "cream", "red_dark")
    window(s, 7, 34), window(s, 20, 34)
    s.rect(13, 42, 5, 8, "soil"), s.frame(12, 41, 7, 10, "plum")
    house(s, 33, 20, 30, "sand", "grey_dark", flat=True)
    window(s, 37, 25, lit=True), window(s, 45, 25), window(s, 37, 36), window(s, 45, 36)
    # the blue rooftop water tank every Seoul alley has
    box(s, 38, 8, 9, 8, "blue"), s.vline(40, 9, 6, "sky"), s.hline(38, 8, 9, "plum")
    house(s, 58, 30, 20, "paper", "navy")
    window(s, 62, 36), window(s, 80, 36)
    s.rect(70, 41, 6, 9, "leaf_dark"), s.frame(69, 40, 8, 11, "plum"), s.px(74, 45, "gold")
    house(s, 93, 20, 27, "pink", "soil_dark")
    window(s, 97, 30), window(s, 105, 30, lit=True), window(s, 101, 40)
    house(s, 117, 24, 18, "cream", "orange_dark")
    window(s, 121, 38), window(s, 132, 38)
    # potted plants along the wall
    for x in (30, 55, 89, 114):
        s.rect(x, 46, 3, 4, "orange_dark"), s.rect(x - 1, 43, 5, 3, "leaf"), s.px(x, 43, "leaf_light")
    base_wall(s, "grey_dark", "grey", "grey_light")
    for x in range(0, W, 8):
        s.px(x + 3, 52, "grey_dark"), s.px(x + 7, 54, "grey_dark")
    # utility poles and sagging wires
    for px in (28, 90):
        s.rect(px, 6, 2, 44, "soil_dark"), s.vline(px, 6, 44, "soil")
        s.hline(px - 4, 9, 10, "soil_dark"), s.hline(px - 3, 13, 8, "soil_dark")
        s.rect(px + 2, 16, 3, 5, "grey"), s.frame(px + 2, 16, 3, 5, "plum")
    wire(s, 28, 90, 9, 3), wire(s, 90, 28 + W, 9, 3)
    # laundry line between two houses
    wire(s, 53, 93, 27, 2, "ink")
    for i, c in enumerate(("paper", "pink", "sky", "gold_light", "paper")):
        x = 58 + i * 7
        y = 28 + (1 if 1 <= i <= 3 else 0)
        s.rect(x, y, 4, 5 if i % 2 == 0 else 4, c)
        s.hline(x, y, 4, "plum")
    return s


def awning(s, x, y, w, a, b="paper"):
    for i in range(w):
        c = a if (i // 4) % 2 == 0 else b
        s.vline(x + i, y, 6, c)
        if i % 4 in (1, 2):
            s.px(x + i, y + 6, c)
    s.hline(x, y, w, "plum")
    s.hline(x, y + 7, w, "plum")
    for i in range(0, w, 4):
        s.px(x + i, y + 6, "plum"), s.px(x + i + 3, y + 6, "plum")


def stall(s, x, w, stripe, sign, goods):
    s.rect(x, 33, w, BASE - 33, "plum")
    s.rect(x, 33, w, 3, "ink")
    for i, c in enumerate(goods):
        gx = x + 2 + i * 6
        if gx + 4 < x + w:
            s.rect(gx, 44, 5, 6, "soil_light"), s.hline(gx, 44, 5, "sand")
            s.rect(gx, 41, 5, 3, c), s.px(gx + 1, 41, "paper")
    s.vline(x, 33, 17, "soil_dark"), s.vline(x + w - 1, 33, 17, "soil_dark")
    awning(s, x - 1, 27, w + 2, stripe)
    box(s, x + 3, 13, w - 6, 11, sign)
    s.rect(x + 5, 16, 3, 5, "paper"), s.rect(x + 10, 16, 4, 2, "paper")
    s.rect(x + 10, 19, 4, 2, "paper")
    if w > 26:
        s.rect(x + 16, 16, 3, 5, "paper")
    s.vline(x + 6, 24, 3, "soil_dark"), s.vline(x + w - 7, 24, 3, "soil_dark")


def market():
    s = Sprite(W, H)
    far_layer(s, [0, 26, 22, 0, 24, 30, 0, 23, 27, 0, 0, 28], "sand", "cream")
    stall(s, 3, 30, "red", "leaf_dark", ["orange", "leaf", "red", "gold", "leaf_light"])
    stall(s, 39, 26, "leaf", "red_dark", ["gold", "red", "leaf", "pink"])
    stall(s, 71, 32, "blue", "gold_dark", ["leaf_light", "orange", "paper", "red", "leaf"])
    stall(s, 109, 30, "gold", "navy", ["red", "leaf", "gold_light", "orange", "pink"])
    base_wall(s, "soil", "soil_light", "sand")
    # lantern string, periodic in 144
    wire(s, 0, 72, 4, 3, "ink"), wire(s, 72, 144, 4, 3, "ink")
    for i in range(12):
        x = 6 + i * 12
        t = (x % 72) / 72
        y = round(4 + 3 * 4 * t * (1 - t)) + 1
        c = "red" if i % 2 == 0 else "gold"
        s.rect(x - 1, y, 4, 4, c), s.frame(x - 2, y - 1, 6, 6, "plum")
        for cx, cy in ((x - 2, y - 1), (x + 3, y - 1), (x - 2, y + 4), (x + 3, y + 4)):
            s.px(cx, cy, None)
        s.px(x - 1, y, "pink" if c == "red" else "gold_light")
    return s


def tower(s, x, w, h, glass, frame_c, lit=3):
    top = BASE - h
    box(s, x, top, w, h + 1, glass)
    for wy in range(top + 2, BASE - 1, 3):
        s.hline(x + 1, wy, w - 2, frame_c)
    for wx in range(x + 3, x + w - 1, 4):
        s.vline(wx, top + 1, h - 1, frame_c)
    for wy in range(top + 3, BASE - 2, 3):
        for wx in range(x + 1, x + w - 2, 4):
            if (wx * 5 + wy * 7 + w) % 11 < lit:
                s.rect(wx, wy, 2, 2, "paper" if (wx + wy) % 2 else "gold_light")
    s.vline(x + 1, top + 1, h - 1, "paper" if glass == "sky" else "sky")
    s.frame(x, top, w, h + 1, "plum")


def billboard(s, x, y, w, h, bg, a, b):
    box(s, x, y, w, h, bg, "ink")
    s.ellipse(x + w * 0.3, y + h * 0.5, w * 0.16, h * 0.3, a)
    s.rect(x + w // 2 + 1, y + 2, w // 2 - 3, 2, b)
    s.rect(x + w // 2 + 1, y + 5, w // 2 - 5, 2, b)
    s.vline(x + 2, y + h, 3, "grey_dark"), s.vline(x + w - 3, y + h, 3, "grey_dark")


def gangnam():
    s = Sprite(W, H)
    far_layer(s, [30, 40, 34, 46, 28, 38, 44, 32, 48, 36, 42, 26], "grey_light", "paper")
    tower(s, 2, 22, 44, "blue", "navy")
    tower(s, 27, 18, 32, "sky", "blue", lit=2)
    tower(s, 48, 26, 50, "navy", "grey_dark", lit=4)
    s.vline(60, 0, 1, "red"), s.vline(60, 0, 1, "red")
    tower(s, 77, 20, 36, "sky", "blue", lit=2)
    tower(s, 100, 24, 46, "blue", "navy")
    tower(s, 127, 15, 28, "grey", "grey_dark", lit=4)
    billboard(s, 26, 6, 20, 10, "pink", "paper", "red")
    billboard(s, 77, 2, 20, 10, "gold", "leaf", "paper")
    billboard(s, 125, 10, 18, 9, "leaf_dark", "leaf_pale", "leaf_light")
    # street trees and hedge
    base_wall(s, "leaf_deep", "leaf_dark", "leaf")
    for x in (24, 74, 124):
        s.ellipse(x + 1.5, 44, 4.5, 4.5, "leaf_dark"), s.ellipse(x + 0.5, 43, 3, 3, "leaf")
        s.px(x - 1, 42, "leaf_light")
    for x in range(2, W, 6):
        s.px(x, 52, "leaf"), s.px(x + 3, 54, "leaf_deep")
    return s


def cloud(kind):
    s = Sprite(32, 12)
    blobs = ([(8, 8, 6, 3.5), (15, 6, 7, 5), (23, 8, 7, 3.5)] if kind == 0
             else [(7, 8, 5, 3), (13, 7, 5, 4), (20, 6, 6, 5), (26, 9, 5, 2.5)])
    for cx, cy, rx, ry in blobs:
        s.ellipse(cx, cy, rx, ry, "paper")
    s.rect(4, 9, 25, 2, "paper")
    for y in range(12):
        for x in range(32):
            if s.get(x, y) and s.get(x, y + 1) is None:
                s.px(x, y, "grey_light")
    return s


def sun():
    s = Sprite(16, 16)
    s.ellipse(8, 8, 5, 5, "gold_light")
    s.ellipse(8.6, 8.6, 4.4, 4.4, "gold", only={"gold_light"})
    s.ellipse(7.4, 7.4, 4, 4, "gold_light")
    s.px(6, 6, "paper"), s.px(7, 6, "paper"), s.px(6, 7, "paper")
    for x, y in ((8, 0), (7, 0), (8, 15), (7, 15), (0, 7), (0, 8), (15, 7), (15, 8),
                 (2, 2), (13, 2), (2, 13), (13, 13)):
        s.px(x, y, "gold")
    return s


def moon():
    s = Sprite(16, 16)
    s.ellipse(8, 8, 6, 6, "cream")
    s.ellipse(7.2, 7.2, 5, 5, "paper", only={"cream"})
    s.ellipse(11.5, 6, 4.6, 4.6, None)
    s.px(5, 9, "cream"), s.px(6, 11, "cream")
    return s


STAR = Sprite.ascii("""
.y.
yWy
.y.
""")
DROP = Sprite.ascii("""
.c
.c
cU
cU
U.
U.
""")
SPLASH = [Sprite.ascii("""
......
......
.c..c.
..cc..
"""), Sprite.ascii("""
c....c
......
.c..c.
......
""")]

N = "tiles horizontally; draw over a flat sky fill; bottom row meets the street band"
add("backdrop", "alley", alley(), anchor=(0, 55), note="골목. " + N)
add("backdrop", "market", market(), anchor=(0, 55), note="시장. " + N)
add("backdrop", "gangnam", gangnam(), anchor=(0, 55), note="강남. " + N)
add("backdrop", "cloud", [cloud(0), cloud(1)], kind="variants", anchor=(16, 6),
    note="drift slowly right to left")
add("backdrop", "sun", sun(), anchor=(8, 8))
add("backdrop", "moon", moon(), anchor=(8, 8))
add("backdrop", "star", STAR, anchor=(1, 1), note="night sky; blink by alpha")
add("backdrop", "raindrop", DROP, anchor=(0, 5), note="falls slightly leftward")
add("backdrop", "rain_splash", SPLASH, anchor=(3, 3), duration=0.08, note="play once on ground")

# Weather particles. Nearest-neighbour and unoutlined: at this size an outline would be the sprite.
SNOW = [Sprite.ascii(a) for a in ("""
WW
WW
""", """
.W.
WWW
.W.
""")]
LEAF_ART = """
..OO.
.OOOo
OOOo.
.oo..
"""
LEAVES = [Sprite.ascii(LEAF_ART).swap({"orange": o, "orange_dark": d})
          for o, d in (("orange", "orange_dark"), ("red", "red_dark"), ("gold", "gold_dark"))]
PETALS = [Sprite.ascii(a) for a in ("""
.kk
kkr
""", """
.Wk
kkk
""")]
add("backdrop", "snow_s", SNOW[0], anchor=(1, 1), note="weather particle, far flake; drifts down with sway")
add("backdrop", "snow_l", SNOW[1], anchor=(1, 1), note="weather particle, near flake; drifts down with sway")
add("backdrop", "leaf", LEAVES, kind="variants", anchor=(2, 2),
    note="weather particle; orange / red / gold, flip x while tumbling")
add("backdrop", "petal", PETALS, kind="variants", anchor=(1, 1), note="weather particle; floats down and sideways")
