"""봄동 is a flat, open rosette, not a round head. One generator draws it at every
size (crop, item icon, sign emblem, logo, app icon) so they are the same plant."""

import math

from canvas import Sprite

GREEN = dict(rim="leaf_deep", outer="leaf_dark", outer_hi="leaf", rib="leaf_light",
             inner="leaf", inner_hi="leaf_light", core="leaf_light", heart="leaf_pale",
             dot="gold_light")
GOLDEN = dict(rim="soil", outer="gold_dark", outer_hi="gold", rib="gold_light",
              inner="gold", inner_hi="gold_light", core="gold_light", heart="paper",
              dot="paper")


def rosette(w, h, pal=GREEN, outer_n=8, inner_n=5, spin=0.0, outline=True, ribs=None):
    """Fill is w x h; with outline the sprite is (w+2) x (h+2).

    Leaves are radial ellipses computed in un-squashed (circular) space and
    squashed by h/w, so the notches between leaf tips survive the 3/4 view."""
    s = Sprite(w + 2, h + 2)
    cx, cy = 1 + w / 2, 1 + h / 2
    R, k = w / 2, h / w

    def ring(n, rc, a, b, base, hi, rim, rib, phase, rib_to):
        order = sorted(range(n), key=lambda i: math.sin(phase + spin + 2 * math.pi * i / n))
        for i in order:
            th = phase + spin + 2 * math.pi * i / n
            ct, st = math.cos(th), math.sin(th)
            body, edge = [], []
            for y in range(s.h):
                for x in range(s.w):
                    X, Y = x + 0.5 - cx, (y + 0.5 - cy) / k
                    u, v = X * ct + Y * st, -X * st + Y * ct
                    d = ((u - rc) / a) ** 2 + (v / b) ** 2
                    if d <= 1.0:
                        body.append((x, y, u, v))
                    elif ((u - rc) / (a + 1.1)) ** 2 + (v / (b + 1.1)) ** 2 <= 1.0:
                        edge.append((x, y))
            for x, y in edge:
                if s.get(x, y) is not None:
                    s.px(x, y, rim)
            for x, y, u, v in body:
                s.px(x, y, base if u > rc + split * a else hi)
        if rib:
            for i in range(n):
                th = phase + spin + 2 * math.pi * i / n
                ct, st = math.cos(th), math.sin(th)
                s.line(int(cx + 0.45 * rc * ct), int(cy + 0.45 * rc * st * k),
                       int(cx + rib_to * ct), int(cy + rib_to * st * k), rib)

    if ribs is None:
        ribs = w >= 24
    split = 0.1 if w >= 16 else 0.35
    ring(outer_n, 0.62 * R, 0.38 * R, 0.37 * R, pal["outer"], pal["outer_hi"], pal["rim"],
         pal["rib"] if ribs else None, -math.pi / 2 + 0.15, 0.8 * R)
    ring(inner_n, 0.33 * R, 0.27 * R, 0.25 * R, pal["inner"], pal["inner_hi"], pal["outer"],
         None, -math.pi / 2 + 0.6, 0)
    s.ellipse(cx, cy, 0.2 * R, 0.2 * R * k + 0.2, pal["core"])
    s.ellipse(cx - 0.2, cy - 0.2, 0.12 * R, 0.12 * R * k, pal["heart"])
    if w >= 14:
        s.px(int(cx - 0.5), int(cy - 0.5), pal["dot"])
    if outline:
        s.outline("ink")
    return s


def face(s, cx, cy, big=False):
    """Mascot face, drawn over the pale heart."""
    if big:
        for ex in (cx - 5, cx + 4):
            s.rect(ex, cy - 2, 2, 3, "ink")
            s.px(ex, cy - 2, "paper")
        s.hline(cx - 8, cy + 2, 2, "pink"), s.hline(cx + 6, cy + 2, 2, "pink")
        s.px(cx - 2, cy + 2, "ink"), s.hline(cx - 1, cy + 3, 2, "ink"), s.px(cx + 1, cy + 2, "ink")
    else:
        s.vline(cx - 2, cy - 1, 2, "ink"), s.vline(cx + 1, cy - 1, 2, "ink")
        s.px(cx - 3, cy + 1, "pink"), s.px(cx + 2, cy + 1, "pink")
    return s
