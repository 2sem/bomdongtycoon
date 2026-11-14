"""A sprite is a grid of palette names (None = transparent). Nothing here can
produce a colour that is not in the palette, which is what keeps the set coherent."""

from PIL import Image

from palette import LEGEND, PALETTE, SHADE, rgba


class Sprite:
    def __init__(self, w, h, fill=None):
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]

    @classmethod
    def ascii(cls, art, legend=None):
        legend = {**LEGEND, **(legend or {})}
        rows = [r for r in art.strip("\n").split("\n")]
        w = max(len(r) for r in rows)
        s = cls(w, len(rows))
        for y, row in enumerate(rows):
            for x, ch in enumerate(row.ljust(w, ".")):
                if ch == " ":
                    ch = "."
                s.g[y][x] = legend[ch]
        return s

    def copy(self):
        s = Sprite(self.w, self.h)
        s.g = [row[:] for row in self.g]
        return s

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def get(self, x, y):
        return self.g[y][x] if self.inside(x, y) else None

    def px(self, x, y, c):
        if self.inside(x, y):
            assert c is None or c in PALETTE, c
            self.g[y][x] = c
        return self

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, c)
        return self

    def hline(self, x, y, n, c):
        return self.rect(x, y, n, 1, c)

    def vline(self, x, y, n, c):
        return self.rect(x, y, 1, n, c)

    def frame(self, x, y, w, h, c):
        self.hline(x, y, w, c).hline(x, y + h - 1, w, c)
        return self.vline(x, y, h, c).vline(x + w - 1, y, h, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.px(x0, y0, c)
            if x0 == x1 and y0 == y1:
                return self
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ellipse(self, cx, cy, rx, ry, c, only=None):
        """Filled, pixel centres tested against the ellipse; `only` restricts
        painting to pixels currently holding one of those colours."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    if only is None or self.get(x, y) in only:
                        self.px(x, y, c)
        return self

    def dither(self, x, y, w, h, c, phase=0, only=None):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if (xx + yy + phase) % 2 == 0:
                    if only is None or self.get(xx, yy) in only:
                        self.px(xx, yy, c)
        return self

    def blit(self, src, x, y):
        for yy in range(src.h):
            for xx in range(src.w):
                c = src.g[yy][xx]
                if c is not None:
                    self.px(x + xx, y + yy, c)
        return self

    def flip_h(self):
        s = self.copy()
        s.g = [row[::-1] for row in self.g]
        return s

    def swap(self, mapping):
        s = self.copy()
        s.g = [[mapping.get(c, c) for c in row] for row in self.g]
        return s

    def shade_where(self, test):
        """Darken one palette step wherever test(x, y) holds."""
        for y in range(self.h):
            for x in range(self.w):
                c = self.g[y][x]
                if c is not None and test(x, y):
                    self.g[y][x] = SHADE[c]
        return self

    def outline(self, c="ink", diagonal=False):
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            nb += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] is None and any(
                    self.get(x + dx, y + dy) is not None for dx, dy in nb
                ):
                    add.append((x, y))
        for x, y in add:
            self.g[y][x] = c
        return self

    def crop(self, x, y, w, h):
        s = Sprite(w, h)
        for yy in range(h):
            for xx in range(w):
                s.g[yy][xx] = self.get(x + xx, y + yy)
        return s

    def padded(self, w, h, ox=0, oy=0):
        return Sprite(w, h).blit(self, ox, oy)

    def bbox(self):
        xs = [x for y in range(self.h) for x in range(self.w) if self.g[y][x]]
        ys = [y for y in range(self.h) for x in range(self.w) if self.g[y][x]]
        return (min(xs), min(ys), max(xs), max(ys)) if xs else None

    def colours(self):
        return {c for row in self.g for c in row if c}

    def to_image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        px = img.load()
        for y in range(self.h):
            for x in range(self.w):
                c = self.g[y][x]
                if c is not None:
                    px[x, y] = rgba(c)
        return img


def tile(src, w, h):
    s = Sprite(w, h)
    for y in range(0, h, src.h):
        for x in range(0, w, src.w):
            s.blit(src, x, y)
    return s
