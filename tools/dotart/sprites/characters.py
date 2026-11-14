"""Chibi people, 16x24. One procedural body; every person is a spec (a palette
swap plus a hair/hat choice), so the cast cannot drift apart stylistically."""

from canvas import Sprite
from palette import LIGHT, SHADE
from . import add

# Head fill is 10 px wide x 10 tall; x range per row.
HEAD = [(5, 10), (4, 11), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (4, 11), (5, 10)]

CUSTOMER_POSES = ["idle_down", "walk_down_0", "walk_down_1", "walk_side_0", "walk_side_1",
                  "walk_up_0", "walk_up_1"]
STAFF_POSES = ["idle_down", "work_0", "work_1", "tired"]


def _facing(pose):
    if "side" in pose:
        return "side"
    return "up" if "up" in pose else "down"


def _head(s, spec, hy, facing, tired):
    skin, hair = spec["skin"], spec["hair"]
    style = spec.get("style", "short")
    inside = set()
    for r, (a, b) in enumerate(HEAD):
        s.hline(a, hy + r, b - a + 1, skin)
        inside |= {(x, r) for x in range(a, b + 1)}

    def hp(x, r, c=hair, force=False):
        if force or (x, r) in inside:
            s.px(x, hy + r, c)

    def rows(r0, r1, x0=3, x1=12, c=hair, force=False):
        for r in range(r0, r1 + 1):
            for x in range(x0, x1 + 1):
                hp(x, r, c, force)

    bald = style == "bald"
    if facing == "up":
        if bald:
            rows(3, 7)
            rows(3, 3, 6, 9, skin)
        else:
            rows(0, 8)
    elif facing == "side":
        if bald:
            rows(2, 6, 9, 12)
        else:
            rows(0, 3)
            rows(4, 9, 8, 12)
            rows(4, 4, 5, 7)
            if style in ("long", "pigtails", "perm", "bun"):
                rows(5, 5, 6, 7)
        hp(8, 6, "skin_shade")
    else:
        if bald:
            rows(2, 5, 3, 4)
            rows(2, 5, 11, 12)
        else:
            rows(0, 3)
            rows(4, 5, 3, 3)
            rows(4, 5, 12, 12)
            if style == "short":
                rows(4, 4, 4, 5)
                rows(4, 4, 10, 11)
            elif style == "part":
                rows(4, 4, 4, 4)
                rows(4, 4, 8, 11)
            else:
                rows(4, 4)
                rows(5, 5, 4, 4)
                rows(5, 5, 11, 11)
                rows(6, 8, 3, 3)
                rows(6, 8, 12, 12)

    light = LIGHT.get(hair, hair)
    if not bald:
        hp(5, 1, light), hp(6, 1, light), hp(4, 2, light)

    if style == "long":
        for r in range(9, 13):
            hp(3, r, hair, True), hp(12, r, hair, True)
        hp(4, 9, hair, True), hp(11, 9, hair, True)
        if facing == "side":
            rows(10, 12, 10, 11, hair, True)
    if style == "pigtails" and facing != "side":
        tie = spec.get("tie", "red")
        for x0 in (1, 13):
            s.rect(x0, hy + 4, 2, 4, hair)
        hp(2, 4, tie, True), hp(13, 4, tie, True)
    if style == "pigtails" and facing == "side":
        s.rect(12, hy + 4, 2, 4, hair)
        hp(12, 4, spec.get("tie", "red"), True)
    if style == "bun":
        s.rect(6, hy - 2, 4, 2, hair)
        s.px(6, hy - 2, light)
    if style == "perm":
        s.hline(4, hy - 1, 8, hair)
        s.rect(2, hy, 12, 5, hair)
        if facing == "down":
            s.rect(4, hy + 4, 8, 1, skin)
            s.rect(2, hy + 5, 2, 2, hair), s.rect(12, hy + 5, 2, 2, hair)
        else:
            s.rect(2, hy + 5, 2, 2, hair), s.rect(12, hy + 5, 2, 2, hair)
        for x, r in ((4, 0), (7, -1), (10, 0), (3, 2), (6, 1), (9, 2), (12, 1), (5, 3), (11, 3)):
            if facing != "down" or r < 4:
                s.px(x, hy + r, light)

    hat = spec.get("hat")
    if hat == "cap":
        c = spec.get("hat_colour", "red")
        rows(0, 3, c=c)
        hp(5, 1, LIGHT[c]), hp(6, 1, LIGHT[c])
        if facing == "down":
            s.hline(3, hy + 4, 10, SHADE[c])
        elif facing == "side":
            s.hline(1, hy + 4, 8, SHADE[c])
        else:
            s.hline(3, hy + 3, 10, SHADE[c])
    elif hat == "chef":
        s.rect(3, hy - 2, 10, 2, "paper")
        s.hline(4, hy - 3, 8, "paper")
        s.hline(4, hy, 8, "paper")
        s.rect(4, hy + 1, 8, 2, "paper")
        s.hline(4, hy + 2, 8, "grey_light")
        s.px(12, hy - 1, "grey_light"), s.px(11, hy, "grey_light")
        s.px(7, hy - 1, "grey_light"), s.px(10, hy - 2, "grey_light")
    elif hat == "straw":
        s.rect(5, hy - 2, 6, 4, "gold_light")
        s.hline(6, hy - 2, 2, "paper")
        s.hline(5, hy + 1, 6, "red")
        s.rect(1, hy + 2, 14, 2, "gold")
        s.hline(1, hy + 2, 13, "gold_light")
        s.hline(2, hy + 3, 12, "gold_dark")
        s.px(10, hy - 1, "gold"), s.px(10, hy, "gold")
    elif hat == "beret":
        c = spec.get("hat_colour", "red")
        s.hline(6, hy - 1, 6, c)
        s.hline(3, hy, 10, c)
        s.rect(2, hy + 1, 11, 2, c)
        s.hline(3, hy + 3, 9, SHADE[c])
        s.px(8, hy - 2, SHADE[c])
        s.px(5, hy, LIGHT[c]), s.px(4, hy + 1, LIGHT[c])
        s.px(12, hy + 2, SHADE[c])
    elif hat == "headband":
        c = spec.get("hat_colour", "red")
        rows(2, 2, c=c)
        if facing != "up":
            s.px(13, hy + 2, c), s.px(13, hy + 3, c), s.px(14, hy + 4, c)
        else:
            s.px(7, hy + 3, c), s.px(8, hy + 4, c)

    if facing == "down":
        if tired:
            s.hline(4, hy + 7, 2, "ink"), s.hline(10, hy + 7, 2, "ink")
            s.px(7, hy + 8, "plum"), s.px(8, hy + 8, "plum")
        else:
            for x in (5, 10):
                s.px(x, hy + 6, "ink"), s.px(x, hy + 7, "ink")
            s.px(4, hy + 8, "pink"), s.px(11, hy + 8, "pink")
            if not spec.get("moustache"):
                s.px(7, hy + 8, "skin_shade"), s.px(8, hy + 8, "skin_shade")
        if spec.get("moustache"):
            s.hline(6, hy + 8, 4, spec["moustache"])
    elif facing == "side":
        s.px(4, hy + 6, "ink"), s.px(4, hy + 7, "ink")
        s.px(5, hy + 8, "pink")
        if spec.get("moustache"):
            s.hline(3, hy + 8, 3, spec["moustache"])


def draw(spec, pose):
    s = Sprite(16, 24)
    facing = _facing(pose)
    small = spec.get("small", False)
    tired = pose == "tired"
    hy = 5 if small else 3
    T = 4 if small else 6
    ty = hy + 10
    ly = ty + T  # always 19: feet land on y=22 for every build
    skin, shirt = spec["skin"], spec["shirt"]
    pants, shoes = spec.get("pants", "navy"), spec.get("shoes", "soil_dark")
    skirt = spec.get("skirt")
    sleeve = shirt if spec.get("sleeve", "long") == "long" else skin
    leg = skin if skirt else pants

    lift = None
    if pose.endswith("_0") and "walk" in pose:
        lift = "L"
    elif pose.endswith("_1") and "walk" in pose:
        lift = "R"

    if facing == "side":
        if lift == "L":
            s.hline(6, ly, 4, leg)
            s.rect(5, ly + 1, 2, 2, leg), s.rect(9, ly + 1, 2, 2, leg)
            s.hline(4, ly + 3, 3, shoes), s.hline(8, ly + 3, 3, shoes)
        else:
            s.rect(7, ly, 2, 3, leg)
            s.hline(6, ly + 3, 3, shoes)
        s.rect(6, ty, 4, T, shirt)
        s.vline(9, ty, T, SHADE[shirt])
        if skirt:
            s.rect(5, ly - 2, 6, 3, skirt)
            s.vline(10, ly - 2, 3, SHADE[skirt])
        if spec.get("apron"):
            s.rect(6, ty + 1, 1, T, spec["apron"])
        arm = SHADE[shirt]
        if lift == "L":
            s.px(6, ty + 1, arm), s.px(5, ty + 2, arm if sleeve == shirt else skin)
            s.px(4, ty + 3, skin)
        else:
            s.vline(7, ty + 1, T - 3, arm)
            s.px(7, ty + T - 2, skin)
    else:
        s.hline(5, ly, 6, leg if not skirt else skirt)
        for side, x in (("L", 5), ("R", 9)):
            # a lifted foot comes up 2px: 1px does not survive a x2 screen scale
            n = 0 if lift == side else 2
            s.rect(x, ly + 1, 2, n, leg)
            s.hline(x, ly + 1 + n, 2, shoes)
        s.rect(5, ty, 6, T, shirt)
        s.vline(10, ty, T, SHADE[shirt])
        if skirt:
            s.rect(4, ly - 2, 8, 3, skirt)
            s.vline(11, ly - 2, 3, SHADE[skirt])
            s.hline(5, ly - 2, 6, skirt)

        apron = spec.get("apron")
        if apron and facing == "down":
            s.rect(6, ty + 1, 4, T, apron)
            s.px(6, ty, apron), s.px(9, ty, apron)
            s.vline(9, ty + 1, T, SHADE[apron])
            for dx, dy, c in spec.get("apron_dots", []):
                if dy < T:
                    s.px(6 + dx, ty + 1 + dy, c)
        elif apron:
            s.px(6, ty, apron), s.px(9, ty, apron)
            s.hline(5, ty + T - 3, 6, apron)
        if spec.get("buttons") and facing == "down":
            s.px(7, ty + 2, spec["buttons"]), s.px(7, ty + 4, spec["buttons"])

        # arms: (x, sleeve rows, hand row)
        drop = 1 if tired else 0
        hand_l = ty + T - 2 + drop - (1 if lift == "R" else 0)
        hand_r = ty + T - 2 + drop - (1 if lift == "L" else 0)
        s.vline(4, ty, hand_l - ty, shirt)
        if sleeve != shirt:
            s.vline(4, ty + 2, hand_l - ty - 2, skin)
        s.px(4, hand_l, skin)
        tool = spec.get("tool")
        if pose == "work_0":
            s.px(11, ty, SHADE[shirt]), s.px(12, ty, SHADE[shirt])
            s.px(13, ty - 1, skin)
            _tool(s, tool, 13, ty - 1, up=True)
        elif pose == "work_1":
            s.px(11, ty, SHADE[shirt]), s.px(11, ty + 1, SHADE[shirt])
            s.px(12, ty + 2, SHADE[shirt] if sleeve == shirt else skin)
            s.px(13, ty + 3, skin)
            _tool(s, tool, 13, ty + 3, up=False)
            s.px(4, hand_l, None), s.px(3, hand_l - 1, skin)
        else:
            s.vline(11, ty, hand_r - ty, SHADE[shirt])
            if sleeve != shirt:
                s.vline(11, ty + 2, hand_r - ty - 2, "skin_shade")
            s.px(11, hand_r, skin)

    scarf = spec.get("scarf")
    hd = 2 if tired else 0
    _head(s, spec, hy + hd, facing, tired)
    if scarf:
        if facing == "side":
            s.hline(6, ty, 4, scarf)
            s.px(10, ty, scarf), s.px(11, ty + 1, SHADE[scarf])
        else:
            s.hline(5, ty + hd, 6, scarf)
            s.px(10, ty + hd, SHADE[scarf])
            if facing == "down":
                s.vline(6, ty + 1 + hd, 2, scarf)
    if spec.get("pin") and facing == "down":
        s.px(9, ty + 2, spec["pin"]), s.px(8, ty + 3, spec["pin"])
        s.px(9, ty + 3, "gold_light"), s.px(10, ty + 3, spec["pin"]), s.px(9, ty + 4, spec["pin"])
    if tired:
        s.px(14, hy + 4, "sky"), s.px(14, hy + 5, "sky")
    s.outline("ink")
    return s


def _tool(s, tool, hx, hy, up):
    if tool == "ladle":
        if up:
            s.vline(hx, hy - 3, 3, "grey")
            s.rect(hx, hy - 5, 2, 2, "grey_light")
        else:
            s.vline(hx + 1, hy - 1, 3, "grey")
            s.rect(hx, hy + 2, 2, 2, "grey_light")
    elif tool == "hoe":
        if up:
            s.vline(hx, hy - 8, 12, "soil_light")
            s.px(hx, hy, "skin")
            s.hline(hx, hy - 9, 2, "grey_light"), s.px(hx + 1, hy - 8, "grey")
        else:
            s.vline(hx, hy - 6, 10, "soil_light")
            s.px(hx, hy, "skin")
            s.hline(hx, hy + 4, 2, "grey_light"), s.px(hx + 1, hy + 5, "grey")
    elif tool == "tray":
        y = hy - 1 if up else hy + 1
        s.hline(hx - 1, y, 3, "grey_light")


SKIN = "skin"
CUSTOMERS = {
    "man": dict(skin=SKIN, hair="ink", style="part", shirt="blue", pants="navy"),
    "woman": dict(skin=SKIN, hair="soil_dark", style="long", shirt="pink", skirt="red",
                  shoes="red_dark"),
    "kid_boy": dict(skin=SKIN, hair="soil_dark", style="short", hat="cap", hat_colour="red",
                    shirt="gold", pants="soil", small=True, sleeve="short"),
    "kid_girl": dict(skin=SKIN, hair="soil", style="pigtails", tie="red", shirt="sky",
                     skirt="blue", small=True, shoes="red_dark"),
    "elder_man": dict(skin=SKIN, hair="grey_light", style="bald", shirt="mauve",
                      pants="grey_dark", moustache="grey_light"),
    "elder_woman": dict(skin=SKIN, hair="grey_light", style="perm", shirt="leaf_dark",
                        skirt="plum", shoes="plum"),
    "gourmet": dict(skin=SKIN, hair="ink", style="short", hat="beret", hat_colour="red",
                    shirt="navy", pants="grey_dark", scarf="gold", pin="gold",
                    moustache="soil_dark", shoes="plum"),
}
STAFF = {
    "alba": dict(skin=SKIN, hair="soil", style="short", shirt="paper", pants="navy",
                 apron="leaf", sleeve="short", tool="ladle"),
    "imo": dict(skin=SKIN, hair="plum", style="perm", shirt="pink", pants="mauve",
                apron="cream", apron_dots=[(0, 1, "red"), (2, 0, "leaf"), (1, 3, "red"),
                                           (3, 2, "red"), (2, 5, "leaf"), (0, 4, "leaf")],
                tool="ladle"),
    "chef": dict(skin=SKIN, hair="ink", style="short", hat="chef", shirt="paper",
                 pants="grey_dark", scarf="red", buttons="grey", tool="ladle"),
    "farmer": dict(skin=SKIN, hair="soil_dark", style="short", hat="straw", shirt="cream",
                   pants="blue", apron="blue", shoes="soil_dark", tool="hoe"),
    "veteran_alba": dict(skin=SKIN, hair="ink", style="part", hat="headband",
                         hat_colour="red", shirt="grey_dark", pants="ink", apron="leaf_dark",
                         sleeve="short", tool="ladle"),
}

# Bottom-centre: feet are on row 22, the ink under them is row 23.
ANCHOR = (8, 23)

for name, spec in CUSTOMERS.items():
    add("char", name, [(p, draw(spec, p)) for p in CUSTOMER_POSES], anchor=ANCHOR,
        duration=0.18, kind="poses",
        note="walk_* are 2-frame loops; walk_side faces left, flip x for right")
for name, spec in STAFF.items():
    add("char", name, [(p, draw(spec, p)) for p in STAFF_POSES], anchor=ANCHOR,
        duration=0.3, kind="poses", note="work_0/1 loop while busy; tired replaces idle")
