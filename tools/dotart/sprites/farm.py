"""Farm plots are 24x24 cells; the bed leaves a grass margin so a 5-column grid
reads as separate beds."""

from canvas import Sprite
from . import add
from .cabbage import GOLDEN, GREEN, rosette


def bed():
    s = Sprite(24, 24)
    s.rect(3, 4, 18, 18, "soil")
    s.rect(1, 6, 22, 14, "soil")
    s.rect(2, 5, 20, 16, "soil")
    # furrows: a broken lit ridge over a shadow line, every 4 rows; broken so the
    # bed reads as turned earth and not as planks
    for i, y in enumerate((7, 11, 15, 19)):
        s.hline(3, y, 18, "soil_dark")
        for x in range(3 + (i % 2) * 3, 20, 6):
            s.hline(x, y - 1, 3, "soil_light")
    s.outline("soil_dark")
    s.hline(4, 4, 16, "soil_light")
    return s


SPROUT = Sprite.ascii("""
.KK...KK.
KlpK.KllK
KgllKlggK
.KKgggKK.
...KGK...
....K....
""")


def plot(crop=None, cx=12, cy=13):
    s = bed()
    if crop:
        s.blit(crop, cx - crop.w // 2, cy - crop.h // 2)
    return s


def seeded():
    s = bed()
    for x, y in ((7, 9), (15, 9), (11, 13), (7, 17), (15, 17)):
        s.hline(x, y, 3, "soil_dark"), s.hline(x, y - 1, 3, "soil_light")
        s.px(x + 1, y - 1, "cream")
    return s


def sway(spr, rows=5):
    out = Sprite(spr.w, spr.h)
    for y in range(spr.h):
        for x in range(spr.w):
            c = spr.g[y][x]
            if c:
                out.px(x + (1 if y < rows else 0), y, c)
    return out


def sparkle(s, x, y, big):
    s.px(x, y, "paper")
    if big:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            s.px(x + dx, y + dy, "paper")
    return s


READY = rosette(18, 13, GREEN, 6, 4)
GOLD = rosette(18, 13, GOLDEN, 6, 4)
GROWING = rosette(10, 8, GREEN, 6, 4)


def locked():
    s = Sprite(24, 24)
    for x in range(2, 22, 4):
        s.hline(x, 4, 2, "meadow_dark"), s.hline(x, 21, 2, "meadow_dark")
    for y in range(6, 21, 4):
        s.vline(1, y, 2, "meadow_dark"), s.vline(22, y, 2, "meadow_dark")
    sign = Sprite.ascii("""
.KKKKKKKKKK.
KCCCCCCCCCSK
KCSSSggSSSbK
KCSSSggSSSbK
KCSggggggSbK
KCSggggggSbK
KCSSSggSSSbK
KCSSSggSSSbK
KSbbbbbbbbbK
.KKKKBDKKKK.
....KBDK....
....KBDK....
....KBDK....
....KKKK....
""")
    return s.blit(sign, 6, 6)


def crate(fill):
    s = Sprite(32, 24)
    s.rect(1, 6, 30, 6, "soil")           # rim, seen from above
    s.rect(3, 7, 26, 5, "soil_dark")      # inside
    s.hline(3, 7, 26, "plum")
    s.hline(1, 6, 30, "sand"), s.vline(1, 6, 6, "sand")
    small = rosette(10, 7, GREEN, 6, 4)
    if fill == "half":
        s.blit(small, 3, 5), s.blit(small, 17, 5), s.blit(small, 10, 6)
    elif fill == "full":
        for x, y in ((3, 2), (17, 2), (10, 0), (1, 5), (19, 5), (10, 5)):
            s.blit(small, x, y)
    s.rect(1, 12, 30, 11, "soil_light")   # front
    for y in (12, 16, 20):
        s.hline(1, y, 30, "sand")
        s.hline(1, y + 3, 30, "soil")
    for x in (1, 28):
        s.rect(x, 12, 3, 11, "soil")
        s.vline(x, 12, 11, "soil_light")
    for x in (8, 15, 22):
        s.px(x, 14, "soil"), s.px(x + 1, 18, "soil"), s.px(x - 1, 21, "soil")
    s.vline(30, 6, 17, "soil_dark")
    s.outline("ink")
    return s


add("farm", "plot_empty", bed(), anchor=(12, 23), note="tilled bed; every plot_* shares this base")
add("farm", "plot_seeded", seeded(), anchor=(12, 23))
add("farm", "plot_sprout", plot(SPROUT, 12, 13), anchor=(12, 23))
add("farm", "plot_growing", plot(GROWING), anchor=(12, 23))
add("farm", "plot_ready", [plot(READY), plot(sway(READY))], anchor=(12, 23), duration=0.6,
    note="gentle sway loop")
_g0 = sparkle(sparkle(plot(GOLD), 5, 7, True), 19, 17, False)
_g1 = sparkle(sparkle(plot(sway(GOLD)), 5, 7, False), 19, 17, True)
add("farm", "plot_golden", [_g0, _g1], anchor=(12, 23), duration=0.35, note="sway + sparkle loop")
add("farm", "plot_locked", locked(), anchor=(12, 23), note="add-plot sign; tap target is the cell")
add("farm", "cabbage_item", rosette(10, 9, GREEN, 6, 4).padded(12, 12, 0, 0), anchor=(6, 6),
    note="fly-to-crate icon; anchor centre")
add("farm", "cabbage_golden_item", rosette(10, 9, GOLDEN, 6, 4).padded(12, 12, 0, 0), anchor=(6, 6))
add("farm", "warehouse_crate", [("empty", crate("empty")), ("half", crate("half")),
                                ("full", crate("full"))], anchor=(16, 23), kind="variants",
    note="empty: 0, half: >0, full: >= 80% of capacity")
