"""Procedural flat panels for the three location backdrops and road tiles.

    python3 tools/isorender/textures/make_location_panels.py

Why this exists instead of a generator call: polli returned 401 (no API key)
on 2026-10-12, so the panels are drawn here with PIL. They still obey the
panel contract in `tools/isorender/README.md`: flat, head-on, evenly lit (no
baked shading), no ink outline, edge to edge, no text.

Authoring grid: each facade is drawn at 64 px per world unit of length (about
1 px per on-screen point at the size the game draws a cell edge) and upscaled
nearest-neighbour x8, which is where the chunky "dot" look comes from.

Facades are one cell edge long and wrap horizontally: every feature is
periodic in x with period 64, so adjacent modules butt together without a
visible break. The right-hand panel is the same family rolled by half a
module, so the left and right backdrops are not mirror-identical.
"""

import os
import random

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
UP = 8  # nearest-neighbour upscale


def clamp(v):
    return max(0, min(255, int(v)))


def jitter(rgb, amount, rng):
    d = rng.randint(-amount, amount)
    return tuple(clamp(c + d) for c in rgb)


def save(img, name, roll=0):
    if roll:
        img = Image.merge("RGB", [_roll(band, roll) for band in img.split()])
    big = img.resize((img.width * UP, img.height * UP), Image.NEAREST)
    big.save(os.path.join(HERE, name))
    print("wrote", name, big.size)


def _roll(band, dx):
    w, h = band.size
    dx %= w
    out = Image.new(band.mode, band.size)
    out.paste(band.crop((w - dx, 0, w, h)), (0, 0))
    out.paste(band.crop((0, 0, w - dx, h)), (dx, 0))
    return out


# --- Facades ----------------------------------------------------------------


def alley(height_units=1.6):
    """Quiet residential tenement: grey-brown brick, a rusty-red band, one
    curtained window, a drainpipe, concrete plinth and coping."""
    rng = random.Random(7)
    w, h = 64, round(64 * height_units)
    img = Image.new("RGB", (w, h), (96, 90, 84))
    d = ImageDraw.Draw(img)
    grey = [(142, 134, 126), (128, 120, 114), (150, 140, 128), (120, 114, 110)]
    rust = [(158, 82, 60), (142, 70, 52), (170, 96, 70)]
    top, bottom = 6, h - 10
    for r, y in enumerate(range(top, bottom, 4)):
        off = (r % 2) * 4
        for k in range(-1, 9):
            x = k * 8 + off
            band = 38 <= y <= 62
            palette = rust if (band and rng.random() < 0.8) else grey
            d.rectangle([x, y, x + 6, y + 2], fill=jitter(rng.choice(palette), 6, rng))
    # coping
    d.rectangle([0, 0, w - 1, 4], fill=(176, 170, 160))
    d.rectangle([0, 5, w - 1, 5], fill=(96, 90, 84))
    # plinth
    d.rectangle([0, bottom, w - 1, h - 1], fill=(122, 120, 114))
    for _ in range(14):
        x, y = rng.randrange(w), rng.randrange(bottom, h)
        d.point((x, y), fill=(104, 102, 98))
    # window: frame, glass, mullion, curtain, sill
    d.rectangle([20, 24, 43, 54], fill=(112, 74, 48))
    d.rectangle([22, 26, 41, 52], fill=(62, 78, 98))
    d.rectangle([22, 26, 31, 38], fill=(92, 112, 134))
    d.rectangle([31, 26, 32, 52], fill=(112, 74, 48))
    d.rectangle([22, 38, 41, 39], fill=(112, 74, 48))
    d.rectangle([33, 26, 41, 36], fill=(204, 192, 168))  # curtain
    d.rectangle([17, 55, 46, 57], fill=(166, 160, 148))  # sill
    # drainpipe on the module's right
    d.rectangle([52, 6, 54, bottom], fill=(66, 66, 72))
    for y in range(14, bottom, 24):
        d.rectangle([51, y, 55, y + 1], fill=(120, 120, 128))
    return img


def market(height_units=1.15):
    """Covered stall seen from behind: striped awning, plank back, crates,
    a cabbage heap, a leaf sign board (no text), a post on the seam."""
    rng = random.Random(11)
    w, h = 64, round(64 * height_units)
    img = Image.new("RGB", (w, h), (176, 120, 66))
    d = ImageDraw.Draw(img)
    # plank back
    for k in range(8):
        x = k * 8
        d.rectangle([x, 0, x + 7, h - 1], fill=jitter((178, 122, 68), 7, rng))
        d.rectangle([x, 0, x, h - 1], fill=(112, 72, 40))
    # awning: 8px stripes, scalloped lower edge
    awning_h = 26
    for k in range(8):
        x = k * 8
        col = (200, 56, 42) if k % 2 == 0 else (244, 214, 130)
        d.rectangle([x, 0, x + 7, awning_h], fill=col)
        d.rectangle([x, awning_h + 1, x + 7, awning_h + 2], fill=col)
        d.point((x, awning_h + 2), fill=(176, 120, 66))
        d.point((x + 7, awning_h + 2), fill=(176, 120, 66))
    d.rectangle([0, 0, w - 1, 1], fill=(120, 80, 46))  # top rail
    # sign board with a leaf motif
    d.rectangle([22, 32, 42, 44], fill=(110, 72, 40))
    d.rectangle([23, 33, 41, 43], fill=(244, 206, 80))
    d.rectangle([29, 36, 35, 40], fill=(70, 150, 70))
    d.rectangle([31, 34, 33, 42], fill=(70, 150, 70))
    # crate stack, left
    for (x, y) in [(5, 56), (5, 46), (15, 56)]:
        d.rectangle([x, y, x + 9, y + 9], fill=(196, 146, 84))
        d.rectangle([x, y, x + 9, y], fill=(122, 80, 44))
        d.rectangle([x, y + 9, x + 9, y + 9], fill=(122, 80, 44))
        d.rectangle([x, y, x, y + 9], fill=(122, 80, 44))
        d.rectangle([x + 9, y, x + 9, y + 9], fill=(122, 80, 44))
        d.line([(x + 1, y + 1), (x + 8, y + 8)], fill=(150, 104, 58))
    # cabbage heap, right
    for (cx, cy, r) in [(40, 64, 5), (49, 66, 5), (45, 58, 4), (55, 65, 4)]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(96, 164, 74))
        d.ellipse([cx - r + 2, cy - r + 1, cx + 1, cy], fill=(150, 206, 108))
    d.rectangle([0, h - 3, w - 1, h - 1], fill=(120, 80, 46))  # base board
    # post straddling the seam
    d.rectangle([0, 0, 1, h - 1], fill=(124, 84, 48))
    d.rectangle([w - 2, 0, w - 1, h - 1], fill=(124, 84, 48))
    return img


def gangnam(height_units=2.4):
    """Glass curtain wall: steel mullions, cyan panes with a diagonal
    reflection, a magenta neon band, a lit pale-stone storefront."""
    rng = random.Random(23)
    w, h = 64, round(64 * height_units)
    img = Image.new("RGB", (w, h), (74, 90, 116))
    d = ImageDraw.Draw(img)
    glass = [(96, 160, 198), (82, 144, 186), (112, 176, 210), (64, 116, 166)]
    storefront_top = h - 34
    for r, y in enumerate(range(6, storefront_top, 12)):
        for c in range(4):
            x = c * 16
            d.rectangle([x + 1, y + 1, x + 15, y + 11], fill=rng.choice(glass))
    # one global diagonal reflection, periodic in x (period 64)
    px = img.load()
    for y in range(6, storefront_top):
        for x in range(w):
            if 0 <= (x + y) % 64 < 6 and px[x, y] != (74, 90, 116):
                r, g, b = px[x, y]
                px[x, y] = (clamp(r + 70), clamp(g + 60), clamp(b + 40))
    # mullions
    for c in range(4):
        d.rectangle([c * 16, 6, c * 16, storefront_top], fill=(70, 84, 110))
    for y in range(6, storefront_top + 1, 12):
        d.rectangle([0, y, w - 1, y], fill=(70, 84, 110))
    # parapet cap
    d.rectangle([0, 0, w - 1, 5], fill=(150, 160, 176))
    d.rectangle([0, 5, w - 1, 5], fill=(70, 84, 110))
    # neon band
    ny = 84
    d.rectangle([0, ny, w - 1, ny + 3], fill=(236, 48, 160))
    d.rectangle([0, ny + 1, w - 1, ny + 2], fill=(255, 150, 214))
    # storefront
    d.rectangle([0, storefront_top, w - 1, h - 1], fill=(206, 210, 218))
    d.rectangle([3, storefront_top + 5, 28, h - 8], fill=(40, 62, 96))
    d.rectangle([4, storefront_top + 6, 27, h - 9], fill=(150, 214, 232))
    d.rectangle([35, storefront_top + 5, 60, h - 8], fill=(40, 62, 96))
    d.rectangle([36, storefront_top + 6, 59, h - 9], fill=(120, 190, 220))
    d.rectangle([0, storefront_top, w - 1, storefront_top + 1], fill=(236, 48, 160))
    d.rectangle([0, h - 6, w - 1, h - 1], fill=(170, 176, 188))
    return img


# --- Road tiles (one cell, top face) ----------------------------------------


def road_alley():
    """Cracked concrete with a drain grate and damp stains."""
    rng = random.Random(31)
    n = 128
    img = Image.new("RGB", (n, n), (150, 148, 142))
    d = ImageDraw.Draw(img)
    for y in range(0, n, 4):
        for x in range(0, n, 4):
            d.rectangle([x, y, x + 3, y + 3], fill=jitter((150, 148, 142), 7, rng))
    # slab joints
    for p in (0, 64):
        d.line([(p, 0), (p, n)], fill=(108, 106, 102), width=1)
        d.line([(0, p), (n, p)], fill=(108, 106, 102), width=1)
    # cracks
    for _ in range(5):
        x, y = rng.randrange(n), rng.randrange(n)
        for _ in range(14):
            nx, ny = x + rng.choice((-2, -1, 1, 2)), y + rng.choice((-1, 0, 1, 2))
            d.line([(x, y), (nx % n, ny % n)], fill=(94, 92, 90), width=1)
            x, y = nx % n, ny % n
    # stains
    for _ in range(6):
        cx, cy, r = rng.randrange(n), rng.randrange(n), rng.randint(5, 9)
        d.ellipse([cx - r, cy - r // 2, cx + r, cy + r // 2], fill=(130, 128, 124))
    # drain grate
    d.rectangle([84, 84, 108, 100], fill=(60, 60, 66))
    for x in range(86, 108, 4):
        d.rectangle([x, 86, x + 1, 98], fill=(110, 110, 118))
    d.rectangle([83, 83, 109, 83], fill=(88, 88, 94))
    return img


def road_market():
    """Worn flagstone with straw and a few leaves and crate chips."""
    rng = random.Random(41)
    n = 128
    img = Image.new("RGB", (n, n), (86, 66, 46))
    d = ImageDraw.Draw(img)
    stones = [(190, 160, 118), (176, 146, 104), (200, 172, 132), (164, 138, 100)]
    y = 0
    for rh in (24, 28, 24, 28, 24):
        widths = rng.choice(((24, 28, 26, 24, 26), (28, 24, 26, 26, 24), (26, 26, 24, 28, 24)))
        x = 0
        for rw in widths:
            d.rectangle([x + 1, y + 1, x + rw - 2, y + rh - 2], fill=jitter(rng.choice(stones), 6, rng))
            x += rw
        y += rh
    # straw
    for _ in range(26):
        x, y = rng.randrange(n), rng.randrange(n)
        dx = rng.choice((-6, -4, 4, 6))
        d.line([(x, y), (x + dx, y + rng.choice((-1, 0, 1)))], fill=(232, 200, 90), width=1)
    # cabbage leaves
    for _ in range(4):
        x, y = rng.randrange(8, n - 8), rng.randrange(8, n - 8)
        d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=(110, 170, 80))
        d.point((x, y), fill=(160, 210, 120))
    # crate chips
    for _ in range(3):
        x, y = rng.randrange(8, n - 12), rng.randrange(8, n - 8)
        d.rectangle([x, y, x + 7, y + 3], fill=(196, 140, 78))
        d.rectangle([x, y, x + 7, y], fill=(130, 88, 48))
    return img


def road_gangnam():
    """Pale paving slabs with grout, and a yellow lane stripe along x. Kept
    mid-light (not near white): the rig's key light lifts a top face, and a
    near-white panel clips to a flat white that loses the slab joints."""
    n = 128
    img = Image.new("RGB", (n, n), (150, 156, 168))
    d = ImageDraw.Draw(img)
    rng = random.Random(53)
    for y in range(0, n, 32):
        for x in range(0, n, 32):
            tone = rng.choice([(182, 188, 200), (174, 180, 193), (188, 194, 205)])
            d.rectangle([x + 1, y + 1, x + 30, y + 30], fill=tone)
    # lane stripe: solid edge lines + dashed centre, running along x
    d.rectangle([0, 50, n - 1, 53], fill=(242, 196, 40))
    d.rectangle([0, 74, n - 1, 77], fill=(242, 196, 40))
    for x in range(0, n, 32):
        d.rectangle([x + 4, 62, x + 19, 65], fill=(236, 238, 242))
    return img


def main():
    save(alley(1.6), "backdrop_alley_left.png")
    save(alley(1.6), "backdrop_alley_right.png", roll=32)
    save(market(1.15), "backdrop_market_left.png")
    save(market(1.15), "backdrop_market_right.png", roll=32)
    save(gangnam(2.4), "backdrop_gangnam_left.png")
    save(gangnam(2.4), "backdrop_gangnam_right.png", roll=32)
    save(road_alley(), "road_alley.png")
    save(road_market(), "road_market.png")
    save(road_gangnam(), "road_gangnam.png")


if __name__ == "__main__":
    main()
