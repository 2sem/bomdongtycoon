"""Chibi figure builder for the whole cast: customers, shop staff, field staff.

One body plan, many people. The head is ~40% of the figure, the body a smooth
bean on stub legs with mitten hands, and every form is a surface of revolution
(isobuild.lathe) shaded smooth. Faces are painted with geometry: two ink eyes,
two blush ovals, an optional mouth. Blush and mouth are `no_ink` so the outline
does not swallow them at ~50 pt.

Who is who is carried by silhouette first, colour second:

  customers  adult: short hair, tufts            plum shirt, dark brown trousers
             kid:   0.70 scale, big head, buns   hot pink shirt
             elder: 0.933 scale, grey hair+bun   deep teal shirt
  staff      cashier: navy cap + visor, cream apron, red shirt
             cook:    tall white toque, dark red apron, off-white shirt
             farmer:  wide straw brim, mustard shirt, blue trousers

Staff colours (white, navy, red, mustard, blue, straw) stay outside the
customers' plum/pink/teal family on purpose.

Frame: figure coordinates are (lat, fwd, z). lat is screen-right, fwd is
toward the camera, so a face placed on +fwd is drawn dead-on. Converted to
grid (col, row) in `grid()` and nowhere else. A customer's line of travel is
the grid row axis, which is why the walk pose swings limbs along (-R2, +R2).

Every dimension below is written for a scale-1 adult (total height ~0.61) and
multiplied by `scale` as it is placed, so a kid is the adult plan shrunk
rather than a separately tuned figure.
"""

import math

import isobuild

R2 = math.sqrt(0.5)


def grid(lat, fwd):
    """(lat, fwd) -> grid (col, row). Screen-right is +col/-row; the camera
    sits at +col/+row."""
    return ((lat + fwd) * R2, (-lat + fwd) * R2)


def along_row(d):
    """A displacement of `d` along the grid row axis, as (lat, fwd)."""
    return (-R2 * d, R2 * d)


SKIN = (0.85, 0.68, 0.53, 1.0)
INK = (0.07, 0.05, 0.05, 1.0)
BLUSH = (0.93, 0.50, 0.45, 1.0)
MOUTH = (0.55, 0.20, 0.18, 1.0)

# --- Cast palettes -----------------------------------------------------------

# Customers sit on mid green grass: shirts are saturated and darker or warmer
# than the grass, trousers a dark warm brown. No white cap (cook), navy cap
# (cashier) or straw brim (farmer), and no red/mustard/blue shirt (staff).
CUSTOMER_PANTS = (0.24, 0.17, 0.12, 1.0)
CUSTOMER_SHOE = (0.12, 0.09, 0.08, 1.0)
ADULT = dict(shirt=(0.45, 0.20, 0.52, 1.0), pants=CUSTOMER_PANTS,
             hair=(0.20, 0.12, 0.08, 1.0), shoe=CUSTOMER_SHOE, skin=SKIN)
KID = dict(shirt=(0.90, 0.36, 0.58, 1.0), pants=CUSTOMER_PANTS,
           hair=(0.30, 0.17, 0.10, 1.0), shoe=CUSTOMER_SHOE, skin=SKIN)
# Elder hair is mid grey, not white: lit from above a pale dome reads as the
# cook's toque at 1x (that was the original mix-up).
ELDER = dict(shirt=(0.12, 0.36, 0.46, 1.0), pants=CUSTOMER_PANTS,
             hair=(0.36, 0.36, 0.42, 1.0), shoe=CUSTOMER_SHOE, skin=SKIN)
CASHIER = dict(shirt=(0.66, 0.20, 0.20, 1.0), pants=(0.16, 0.18, 0.28, 1.0),
               hair=(0.10, 0.08, 0.07, 1.0), shoe=(0.10, 0.09, 0.10, 1.0), skin=SKIN,
               hat=(0.12, 0.14, 0.26, 1.0), apron=(0.84, 0.82, 0.74, 1.0))
COOK = dict(shirt=(0.80, 0.79, 0.75, 1.0), pants=(0.24, 0.24, 0.26, 1.0),
            hair=(0.25, 0.16, 0.10, 1.0), shoe=(0.10, 0.09, 0.10, 1.0), skin=SKIN,
            hat=(0.90, 0.90, 0.88, 1.0), apron=(0.55, 0.16, 0.14, 1.0))
FARMER = dict(shirt=(0.78, 0.60, 0.18, 1.0), pants=(0.22, 0.34, 0.56, 1.0),
              hair=(0.25, 0.16, 0.10, 1.0), shoe=(0.20, 0.14, 0.09, 1.0),
              skin=(0.80, 0.62, 0.46, 1.0), hat=(0.70, 0.54, 0.24, 1.0),
              hat_band=(0.45, 0.30, 0.18, 1.0))

# Held-tool colours carried over from the box-era specs.
METAL = (0.55, 0.58, 0.62, 1.0)
METAL_LIGHT = (0.62, 0.64, 0.68, 1.0)
METAL_DARK = (0.40, 0.40, 0.43, 1.0)
WOOD = (0.45, 0.30, 0.18, 1.0)


def mat(name, rgba):
    return isobuild.flat_material(name, texture=None, rgba=rgba)


class Fig:
    def __init__(self, role, scale=1.0):
        self.role = role
        self.s = scale
        self.seg = 14
        self.rings = 6
        self._n = 0
        self._mats = {}

    def m(self, rgba):
        if rgba not in self._mats:
            self._mats[rgba] = mat(f"{self.role}M{len(self._mats)}", rgba)
        return self._mats[rgba]

    def _name(self, what):
        self._n += 1
        return f"{self.role}{what}{self._n}"

    def P(self, lat, fwd, z):
        s = self.s
        return (lat * s, fwd * s, z * s)

    def ellipsoid(self, what, at, radii, rgba, no_ink=False, rings=None):
        """`at` and `radii` are scale-1; radii = (lat, fwd, z)."""
        s = self.s
        lat, fwd, z = self.P(*at)
        col, row = grid(lat, fwd)
        return isobuild.lathe(
            self._name(what), (col, row, z),
            isobuild.sphere_profile(radii[2] * s, rings or self.rings), self.m(rgba),
            segments=self.seg, scale=(radii[0] / radii[2], radii[1] / radii[2]),
            yaw_degrees=-45.0, smooth=True, no_ink=no_ink)

    def column(self, what, at, profile, rgba, scale=(1.0, 1.0)):
        """Tapered upright body: profile [(radius, z)] with z relative to `at`."""
        s = self.s
        lat, fwd, z = self.P(*at)
        col, row = grid(lat, fwd)
        prof = [(r * s, zz * s) for r, zz in profile]
        return isobuild.lathe(
            self._name(what), (col, row, z), prof, self.m(rgba),
            segments=self.seg, scale=scale, yaw_degrees=-45.0, smooth=True)

    def limb(self, what, p0, p1, radius, rgba):
        """Capsule from p0 to p1, both scale-1 (lat, fwd, z)."""
        a, b = self.P(*p0), self.P(*p1)
        d = [y - x for x, y in zip(a, b)]
        length = math.sqrt(sum(c * c for c in d))
        dcol, drow = grid(d[0], d[1])
        col, row = grid(a[0], a[1])
        return isobuild.lathe(
            self._name(what), (col, row, a[2]),
            isobuild.capsule_profile(radius * self.s, length, 2), self.m(rgba),
            segments=10, aim=(dcol, drow, d[2]), smooth=True)

    def box(self, what, center, w, d, h, z0, rgba):
        s = self.s
        m = self.m(rgba)
        isobuild.box(self._name(what), center=(center[0] * s, center[1] * s),
                     width=w * s, depth=d * s, height=h * s,
                     face_material=m, trim_material=m, top_material=m, base_z=z0 * s)

    def face(self, head_c, radii, k, mouth=True):
        """Eyes, blush, mouth sat on the head ellipsoid. `k` enlarges the
        features for a childlike face."""
        hl, hf, hz = head_c
        rl, rf, rz = radii

        def on_head(azd, eld, kk=1.0):
            a, e = math.radians(azd), math.radians(eld)
            return (hl + kk * rl * math.sin(a) * math.cos(e),
                    hf + kk * rf * math.cos(a) * math.cos(e),
                    hz + kk * rz * math.sin(e))

        eye_r, blush_r = 0.0185 * k, 0.024 * k
        for sgn in (-1, 1):
            self.ellipsoid("Eye", on_head(sgn * 29, -6, 0.955),
                           (eye_r * 0.9, eye_r * 0.55, eye_r * 1.35), INK, rings=4)
            self.ellipsoid("Blush", on_head(sgn * 50, -24, 0.97),
                           (blush_r, blush_r * 0.45, blush_r * 0.7), BLUSH,
                           no_ink=True, rings=4)
        if mouth:
            mr = 0.011 * k
            self.ellipsoid("Mouth", on_head(0.0, -34, 0.975),
                           (mr, mr * 0.4, mr * 0.45), MOUTH, no_ink=True, rings=4)


def markers(top, walk=False):
    if walk:
        half_w, row = 0.025, 0.095
        return {
            "base_center": (0.0, 0.0, 0.0), "top_center": (0.0, 0.0, top),
            "base_corner_north": (-half_w, -row, 0.0),
            "base_corner_east": (half_w, -row, 0.0),
            "base_corner_south": (half_w, row, 0.0),
            "base_corner_west": (-half_w, row, 0.0),
        }
    return {
        "base_center": (0.0, 0.0, 0.0), "top_center": (0.0, 0.0, top),
        "base_corner_north": (-0.05, -0.04, 0.0),
        "base_corner_east": (0.05, -0.04, 0.0),
        "base_corner_south": (0.05, 0.04, 0.0),
        "base_corner_west": (-0.05, 0.04, 0.0),
    }


# Body plan, scale 1.
HIP, SHOULDER_Z = 0.12, 0.33
HEAD_R = (0.122, 0.112, 0.118)
LEG_LAT, LEG_R = 0.045, 0.036
SHOULDER_LAT, ARM_R = 0.092, 0.030
TORSO = [(0.0, HIP - 0.005), (0.075, HIP + 0.02), (0.098, 0.20), (0.092, 0.27),
         (0.070, 0.335), (0.0, 0.355)]


def build(role, palette, scale=1.0, head_k=1.0, face_k=1.0, hair="short",
          hat=None, apron=False, pose="idle", tool=None):
    """One figure.

    hair: "short" | "buns" (kid) | "elder".
    hat:  None | "cap" | "toque" | "straw".
    pose: "idle" | "walk" | "work" (both hands forward on the held prop).
    tool: None | "register" | "pan" | "hoe" (only with pose "work").
    """
    f = Fig(role, scale)
    walking, working = pose == "walk", pose == "work"

    # head: `head_k` swells it for a childlike ratio; it still sits on the neck.
    hr = tuple(r * head_k for r in HEAD_R)
    head_c = (0.0, 0.0, 0.352 + hr[2])

    # legs and shoes
    for s in (-1, 1):
        if walking:
            d = 0.075 * (1 if s < 0 else -1)          # left leg forward
            dl, df = along_row(d)
            foot_z = 0.030 if d > 0 else 0.062
            foot = (s * LEG_LAT + dl, df, foot_z)
            hip = (s * LEG_LAT, 0.0, HIP + 0.02)
            f.limb("Leg", foot, hip, LEG_R, palette["pants"])
            f.ellipsoid("Shoe", (foot[0], foot[1] + 0.018, foot_z - 0.008),
                        (0.042, 0.062, 0.030), palette["shoe"], rings=4)
        else:
            f.limb("Leg", (s * LEG_LAT, 0.0, 0.03), (s * LEG_LAT, 0.0, HIP + 0.02),
                   LEG_R, palette["pants"])
            f.ellipsoid("Shoe", (s * LEG_LAT, 0.018, 0.022), (0.042, 0.062, 0.030),
                        palette["shoe"], rings=4)

    f.column("Torso", (0.0, 0.0, 0.0), TORSO, palette["shirt"], (1.0, 0.85))
    if apron:
        ap = [(0.0, HIP + 0.005), (0.050, HIP + 0.015), (0.066, 0.29), (0.062, 0.30),
              (0.0, 0.32)]
        f.column("Apron", (0.0, 0.068, 0.0), ap, palette["apron"], (1.0, 0.40))

    # arms
    for s in (-1, 1):
        sh = (s * SHOULDER_LAT, 0.0, SHOULDER_Z)
        if working:
            tcol, trow = s * 0.045 * R2, 0.22
            hand = ((tcol - trow) * R2, (tcol + trow) * R2, 0.395)
        elif walking:
            d = -0.065 * (1 if s < 0 else -1)          # opposite the same-side leg
            dl, df = along_row(d)
            hand = (s * (SHOULDER_LAT + 0.020) + dl, df, 0.235)
        else:
            hand = (s * (SHOULDER_LAT + 0.025), 0.01, SHOULDER_Z - 0.115)
        f.limb("Arm", sh, hand, ARM_R, palette["shirt"])
        f.ellipsoid("Hand", hand, (ARM_R * 1.12,) * 3, palette["skin"], rings=4)

    # head and face
    f.ellipsoid("Head", head_c, hr, palette["skin"], rings=f.rings + 1)
    f.face(head_c, hr, face_k)

    hl, hf, hz = head_c
    hair_r = hr[2] * 1.10
    hair_scale = (hr[0] / hr[2], hr[1] / hr[2])
    hair_rgba = palette["hair"]

    def shell(name, rgba, polar, tilt_fwd, lift=0.010, rings=5, radius=hair_r):
        acol, arow = grid(0.0, tilt_fwd)
        col, row = grid(0.0, -0.010 * f.s)
        return isobuild.lathe(
            f._name(name), (col, row, (hz + lift) * f.s),
            isobuild.dome_profile(radius * f.s, polar, rings), f.m(rgba),
            segments=f.seg, scale=hair_scale, yaw_degrees=-45.0,
            aim=(acol, arow, 1.0), smooth=True)

    if hat == "cap":
        # navy dome tipped back so the front rim rides high, plus a short visor
        col, row = grid(0.0, -0.012 * f.s)
        acol, arow = grid(0.0, -0.40)
        isobuild.lathe(f._name("Cap"), (col, row, (hz + 0.010) * f.s),
                       isobuild.dome_profile(hair_r * f.s, 92, 4), f.m(palette["hat"]),
                       segments=f.seg, scale=hair_scale, yaw_degrees=-45.0,
                       aim=(acol, arow, 1.0), smooth=True)
        f.ellipsoid("Brim", (0.0, hr[1] * 0.92, hz + 0.070),
                    (hr[0] * 0.80, 0.042, 0.012), palette["hat"], rings=4)
        f.ellipsoid("HairBack", (0.0, -0.045, hz - 0.012),
                    (hr[0] * 1.02, hr[1] * 0.75, hr[2] * 0.9), hair_rgba)
    elif hat == "toque":
        # puffed mushroom, a straight band below. Starts below the brow line of
        # the hair so it sits on the head instead of floating.
        prof = [(0.0, 0.545), (0.104, 0.548), (0.112, 0.575), (0.112, 0.625),
                (0.136, 0.655), (0.150, 0.690), (0.132, 0.722), (0.080, 0.738),
                (0.0, 0.742)]
        f.column("Toque", (0.0, 0.0, 0.0), prof, palette["hat"], (1.0, 0.92))
        for sgn in (-1, 1):
            f.ellipsoid("Tuft", (sgn * hr[0] * 0.98, -0.02, hz - 0.015),
                        (0.030, 0.045, 0.050), hair_rgba, rings=4)
    elif hat == "straw":
        # wide brim held clear of the eyes (they sit ~0.12 below it), shallow crown
        f.ellipsoid("Brim", (0.0, -0.035, hz + 0.082), (0.190, 0.150, 0.020), palette["hat"])
        f.ellipsoid("Crown", (0.0, -0.020, hz + 0.105), (0.098, 0.094, 0.070), palette["hat"])
        f.ellipsoid("Band", (0.0, -0.020, hz + 0.090), (0.105, 0.100, 0.022), palette["hat_band"],
                    rings=4)
        for sgn in (-1, 1):
            f.ellipsoid("Tuft", (sgn * hr[0] * 0.98, -0.02, hz - 0.015),
                        (0.030, 0.045, 0.050), hair_rgba, rings=4)
    else:
        if hair == "elder":
            shell("Hair", hair_rgba, 96, -0.36)
            for sgn in (-1, 1):
                f.ellipsoid("Tuft", (sgn * hr[0] * 1.02, -0.02, hz - 0.010),
                            (0.036, 0.052, 0.058), hair_rgba, rings=4)
            f.ellipsoid("Bun", (0.0, -0.070, hz + 0.090), (0.042, 0.040, 0.040),
                        hair_rgba, rings=4)
        else:
            shell("Hair", hair_rgba, 100, -0.36)
            for sgn in (-1, 1):
                f.ellipsoid("Tuft", (sgn * hr[0] * 0.98, -0.02, hz - 0.015),
                            (0.030, 0.045, 0.050), hair_rgba, rings=4)
            if hair == "buns":
                for sgn in (-1, 1):
                    f.ellipsoid("Bun", (sgn * 0.108, -0.005, hz + 0.100),
                                (0.052, 0.048, 0.052), hair_rgba, rings=4)

    # held props, grid (col, row) at the hands' meeting point
    if working and tool == "register":
        f.box("Register", (0.0, 0.26), 0.10, 0.08, 0.05, 0.36, METAL)
    elif working and tool == "pan":
        f.box("PanHandle", (0.0, 0.26), 0.04, 0.14, 0.03, 0.36, METAL_LIGHT)
        f.box("PanBody", (0.0, 0.34), 0.08, 0.08, 0.03, 0.36, METAL_DARK)
    elif working and tool == "hoe":
        f.box("HoeShaft", (0.0, 0.26), 0.025, 0.025, 0.52, 0.0, WOOD)
        f.box("HoeBlade", (0.0, 0.26), 0.10, 0.04, 0.04, 0.50, METAL_LIGHT)

    top = {"toque": 0.742, "straw": hz + 0.105 + 0.070}.get(hat)
    if top is None:
        top = hz + hr[2] * 1.12 + 0.012
    return markers(top * f.s, walk=walking)
