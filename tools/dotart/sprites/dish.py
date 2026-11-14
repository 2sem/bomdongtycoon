"""Dishes, 16x16. They must tell apart at a glance: geotjeori = green heap in a
cream bowl, kimchi = red stack on a flat plate, bibimbap = dark stone bowl with an egg."""

from canvas import Sprite
from . import add


def bowl(body="cream", rim="paper", inner="grey_light", shade="sand"):
    s = Sprite(16, 16)
    s.ellipse(8, 10, 6, 4.6, body)
    s.ellipse(9.5, 11.5, 4, 3, shade, only={body})
    s.rect(4, 14, 8, 1, shade)
    s.ellipse(8, 8, 7, 3, rim)
    s.ellipse(8, 8.2, 5.5, 2, inner)
    return s


def empty_bowl():
    s = bowl()
    s.hline(4, 7, 3, "grey")
    return s.outline("ink")


def geotjeori():
    s = bowl()
    s.ellipse(8, 6.5, 5.5, 3.4, "leaf")
    s.ellipse(6.5, 5.5, 3, 1.8, "leaf_light")
    for x, y in ((10, 7), (11, 8), (5, 8), (9, 9)):
        s.px(x, y, "leaf_dark")
    for x, y in ((7, 4), (5, 6)):
        s.px(x, y, "leaf_pale")
    for x, y in ((9, 5), (6, 7), (11, 6), (8, 8)):
        s.px(x, y, "red")
    s.px(8, 6, "paper"), s.px(4, 7, "paper")
    return s.outline("ink")


def kimchi():
    s = Sprite(16, 16)
    s.ellipse(8, 11.5, 7, 3, "paper")
    s.ellipse(8, 12, 5.5, 1.8, "grey_light")
    s.hline(4, 14, 8, "sand")
    s.rect(4, 6, 9, 6, "red")
    s.hline(5, 5, 7, "red")
    s.hline(5, 12, 7, "red_dark")
    for x in (6, 9):
        s.vline(x, 6, 6, "red_dark")
    s.hline(4, 6, 2, "orange"), s.hline(7, 5, 2, "orange"), s.hline(10, 6, 2, "orange")
    s.px(5, 9, "cream"), s.px(8, 8, "cream"), s.px(11, 9, "cream"), s.px(7, 10, "cream")
    s.vline(12, 7, 4, "red_dark")
    s.px(4, 5, "leaf"), s.px(3, 6, "leaf"), s.px(3, 7, "leaf_dark")
    return s.outline("ink")


def bibimbap():
    s = bowl(body="grey_dark", rim="grey", inner="plum", shade="plum")
    s.ellipse(8, 7.6, 6, 2.6, "cream")
    s.rect(2, 6, 4, 3, "leaf"), s.px(2, 6, None), s.px(3, 6, "leaf_light")
    s.rect(10, 6, 4, 3, "orange"), s.px(13, 6, None), s.px(11, 6, "gold")
    s.hline(5, 9, 6, "soil"), s.hline(6, 10, 4, "soil")
    s.hline(6, 5, 4, "cream")
    s.rect(6, 6, 4, 3, "paper")
    s.rect(7, 6, 2, 2, "gold"), s.px(7, 6, "gold_light")
    s.px(9, 8, "red"), s.px(5, 5, "red")
    s.ellipse(8, 8, 7, 3, "grey", only={None})
    s.hline(3, 11, 3, "grey")
    return s.outline("ink")


POT = Sprite.ascii("""
................
................
................
................
................
.....KKKKKK.....
...KKLLLLLLKK...
..KLWWLLLLLAAK..
.KKKKKKKKKKKKKK.
KAKLWLLLLLLAAKAK
KKKLWLLLLLLAAKKK
..KLWLLLLLLAAK..
..KLLLLLLLAAAK..
..KALLLLLAAAaK..
...KKKKKKKKKK...
................
""")


def pot(frame):
    s = POT.copy()
    s.rect(7, 4, 2, 1, "ink"), s.px(7, 4, "grey")
    wisps = [((4, 3), (4, 2), (5, 1), (11, 2), (11, 1), (10, 0)),
             ((5, 3), (4, 2), (4, 1), (10, 3), (11, 2), (11, 1), (8, 1), (8, 0))][frame]
    for x, y in wisps:
        s.px(x, y, "paper")
    return s


STOCK_PLATE = Sprite.ascii("""
.KKKKKKKK.
KWWWWWWWWK
KLWWWWWWLK
.KLLLLLLK.
..KKKKKK..
""")

# Bowl feet are on row 14, ink on row 15.
A = (8, 15)
add("dish", "empty_bowl", empty_bowl(), anchor=A, note="menu not cooked yet / out of stock")
add("dish", "geotjeori", geotjeori(), anchor=A, note="menu 0")
add("dish", "kimchi", kimchi(), anchor=A, note="menu 1")
add("dish", "bibimbap", bibimbap(), anchor=A, note="menu 2")
add("dish", "pot", [pot(0), pot(1)], anchor=A, duration=0.3, note="steam loop while cooking")
add("dish", "stock_plate", STOCK_PLATE, anchor=(5, 4), note="10x5 pip next to the stock count")
