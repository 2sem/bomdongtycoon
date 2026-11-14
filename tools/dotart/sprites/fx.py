from canvas import Sprite
from . import add

C0 = Sprite.ascii("""
..KKKK..
.KyyYYK.
KyyYYYZK
KyYZZYZK
KyYZZYZK
KYYYYYZK
.KYZZZK.
..KKKK..
""")
C1 = Sprite.ascii("""
...KK...
..KyYK..
.KyYYZK.
.KyYZZK.
.KyYZZK.
.KYYYZK.
..KYZK..
...KK...
""")
C2 = Sprite.ascii("""
...KK...
..KyZK..
..KyZK..
..KyZK..
..KyZK..
..KYZK..
..KYZK..
...KK...
""")

SPARKLE = [Sprite.ascii(a) for a in ("""
.......
.......
...y...
..yWy..
...y...
.......
.......
""", """
.......
...y...
...W...
.yWWWy.
...W...
...y...
.......
""", """
...y...
...W...
..yWy..
yWWWWWy
..yWy..
...W...
...y...
""", """
.......
.y...y.
..W.W..
...y...
..W.W..
.y...y.
.......
""")]

HEART = Sprite.ascii("""
.KK.KK.
KkRKRRK
KRRRRRK
KRRRRrK
.KRRrK.
..KrK..
...K...
""")
ANGER = Sprite.ascii("""
..r.r..
..R.R..
rRR.RRr
.......
rRR.RRr
..R.R..
..r.r..
""")


def puff(frame):
    s = Sprite(12, 12)
    blobs = [[(6, 7, 3)],
             [(4, 7, 3), (8, 6, 3.2), (6, 4, 2.4)],
             [(2.5, 7, 1.6), (9.5, 5, 1.8), (6, 2.5, 1.4), (7, 9, 1.2)]][frame]
    for cx, cy, r in blobs:
        s.ellipse(cx, cy, r, r, "cream")
    for cx, cy, r in blobs:
        s.ellipse(cx - 0.5, cy - 0.6, r * 0.6, r * 0.55, "paper")
    if frame < 2:
        for cx, cy, r in blobs:
            s.px(int(cx + r * 0.5), int(cy + r * 0.5), "sand")
    return s


def bubble():
    # 22 wide: a 16x16 dish plus 2px of paper and the 1px ink each side
    s = Sprite(22, 22)
    s.rect(2, 1, 18, 18, "paper"), s.rect(1, 2, 20, 16, "paper")
    s.hline(2, 18, 18, "grey_light"), s.vline(20, 3, 15, "grey_light")
    s.px(9, 19, "paper"), s.px(10, 19, "paper"), s.px(11, 19, "paper"), s.px(10, 20, "paper")
    s.px(11, 20, "grey_light"), s.px(12, 19, "grey_light")
    return s.outline("ink")


ZZZ = Sprite.ascii("""
....WWWP
.....WP.
....WWWP
WWWW.PPP
..WP....
.WP.....
WWWW....
.PPPP...
""")

FLAME = Sprite.ascii("""
................
.......K........
......KRK.......
......KRRK......
.....KRORK..K...
....KRROORKKRK..
...KRROOORRRRK..
..KRROOYOORRRK..
..KRROYYYOORRK..
.KRROOYyYYOORK..
.KRROYYyyYOORK..
.KRROYyyyYOORK..
.KRROYyWyYORRK..
..KRROYyYOORK...
...KRROOOORK....
....KKKKKKK.....
""")
FLAME2 = Sprite.ascii("""
................
................
........K.......
...K...KRK......
..KRK..KRRK.....
..KRRKKRORK.....
..KRRRRROORK....
..KRRROOYORRK...
..KRROOYYYORRK..
..KROOYYyYOORK..
.KRROYyyYYOORK..
.KRROYyyyYORRK..
.KRROYyWyYORRK..
..KRROYyYOORK...
...KRROOOORK....
....KKKKKKK.....
""")


def shadow():
    s = Sprite(12, 4)
    s.rect(2, 0, 8, 4, "ink"), s.rect(0, 1, 12, 2, "ink")
    return s


add("fx", "coin", [C0, C1, C2, C1.flip_h()], anchor=(4, 4), duration=0.08,
    note="spin loop; anchor centre")
add("fx", "sparkle", SPARKLE, anchor=(3, 3), duration=0.09, note="play once or loop")
add("fx", "heart", HEART, anchor=(3, 3), note="happy customer")
add("fx", "anger", ANGER, anchor=(3, 3), note="customer gave up")
add("fx", "puff", [puff(0), puff(1), puff(2)], anchor=(6, 9), duration=0.08,
    note="dust, play once (plant / harvest)")
add("fx", "bubble", bubble(), anchor=(10, 21),
    note="order bubble; tail tip is the anchor; dish 16x16 goes at bubble px (3,2)",
    slots={"dish_origin_top_left": (3, 2)})
add("fx", "zzz", ZZZ, anchor=(0, 7), note="over a tired worker")
add("fx", "fever_flame", [FLAME, FLAME2], anchor=(8, 15), duration=0.12)
add("fx", "shadow", shadow(), anchor=(6, 2),
    note="optional ground shadow; draw under characters at alpha 0.25")
