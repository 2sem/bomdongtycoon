"""Shared peg-doll builder for the shop and field staff figures.

Same box body plan, scale (head top at z 0.60, hair cap to 0.61) and ink
weight as `customer_adult_idle.py`, so staff stand in the same world as
customers. They must read as *different people*, and faces are not painted,
so the difference is carried by silhouette and colour:

  * a hat customers never wear (cook toque, cashier visor, straw brim),
  * a front apron box proud of the torso,
  * uniform colours outside the customers' teal/brown family,
  * a working pose: both arms thrust forward along the row axis and a held
    tool, against the idle pose's arms at the sides.

Specs call `build_staff(...)`; this file owns no camera or light.
"""

import isobuild


def _mat(name, rgba):
    return isobuild.flat_material(name, texture=None, rgba=rgba)


def _box(name, center, w, d, h, z0, mat):
    isobuild.box(name, center=center, width=w, depth=d, height=h,
                 face_material=mat, trim_material=mat, top_material=mat, base_z=z0)


def build_staff(role, shirt, pants, skin, hair, working, hat=None, apron=None, tool=None):
    """hat {rgba,w,d,h,z0,brim=(w,d,h,z0,rgba)|None}; apron {rgba,h,z0};
    tool {rgba,center,w,d,h,z0,extra=[same keys]}."""
    shirt_m, pants_m = _mat(f"{role}Shirt", shirt), _mat(f"{role}Pants", pants)
    skin_m, hair_m = _mat(f"{role}Skin", skin), _mat(f"{role}Hair", hair)

    _box(f"{role}Legs", (0.0, 0.0), 0.10, 0.08, 0.24, 0.0, pants_m)
    _box(f"{role}Torso", (0.0, 0.0), 0.16, 0.10, 0.18, 0.24, shirt_m)

    for side, sx in (("L", -0.115), ("R", 0.115)):
        if working:
            _box(f"{role}Arm{side}", (sx, 0.10), 0.07, 0.26, 0.10, 0.29, shirt_m)
        else:
            _box(f"{role}Arm{side}", (sx, 0.0), 0.07, 0.12, 0.16, 0.25, shirt_m)

    _box(f"{role}Head", (0.0, 0.0), 0.14, 0.12, 0.18, 0.42, skin_m)
    if hat is None:
        _box(f"{role}Hair", (0.0, 0.0), 0.15, 0.13, 0.08, 0.53, hair_m)
    else:
        _box(f"{role}Hair", (0.0, 0.0), 0.15, 0.13, 0.05, 0.53, hair_m)
        _box(f"{role}HatTop", (0.0, 0.0), hat["w"], hat["d"], hat["h"], hat["z0"],
             _mat(f"{role}Hat", hat["rgba"]))
        if hat.get("brim"):
            bw, bd, bh, bz, brgba = hat["brim"]
            _box(f"{role}HatBrim", (0.0, 0.0), bw, bd, bh, bz, _mat(f"{role}Brim", brgba))

    if apron:
        _box(f"{role}Apron", (0.0, 0.065), 0.14, 0.04, apron["h"], apron["z0"],
             _mat(f"{role}ApronM", apron["rgba"]))

    if tool:
        for i, part in enumerate([tool] + tool.get("extra", [])):
            _box(f"{role}Tool{i}", part["center"], part["w"], part["d"], part["h"],
                 part["z0"], _mat(f"{role}ToolM{i}", part["rgba"]))

    top = 0.61
    if hat:
        top = max(top, hat["z0"] + hat["h"])
        if hat.get("brim"):
            top = max(top, hat["brim"][3] + hat["brim"][2])
    return {
        "base_center": (0.0, 0.0, 0.0),
        "top_center": (0.0, 0.0, top),
        "base_corner_north": (-0.05, -0.04, 0.0),
        "base_corner_east": (0.05, -0.04, 0.0),
        "base_corner_south": (0.05, 0.04, 0.0),
        "base_corner_west": (-0.05, 0.04, 0.0),
    }


SKIN = (0.85, 0.68, 0.53, 1.0)
CASHIER = dict(
    shirt=(0.66, 0.20, 0.20, 1.0), pants=(0.16, 0.18, 0.28, 1.0), skin=SKIN,
    hair=(0.10, 0.08, 0.07, 1.0),
    hat=dict(rgba=(0.12, 0.14, 0.26, 1.0), w=0.15, d=0.13, h=0.04, z0=0.58,
             brim=(0.15, 0.20, 0.025, 0.58, (0.12, 0.14, 0.26, 1.0))),
    apron=dict(rgba=(0.84, 0.82, 0.74, 1.0), h=0.14, z0=0.24))
COOK = dict(
    shirt=(0.80, 0.79, 0.75, 1.0), pants=(0.24, 0.24, 0.26, 1.0), skin=SKIN,
    hair=(0.25, 0.16, 0.10, 1.0),
    hat=dict(rgba=(0.88, 0.88, 0.86, 1.0), w=0.15, d=0.13, h=0.13, z0=0.58),
    apron=dict(rgba=(0.55, 0.16, 0.14, 1.0), h=0.20, z0=0.12))
FARMER = dict(
    shirt=(0.78, 0.60, 0.18, 1.0), pants=(0.22, 0.34, 0.56, 1.0),
    skin=(0.80, 0.62, 0.46, 1.0), hair=(0.25, 0.16, 0.10, 1.0),
    hat=dict(rgba=(0.78, 0.65, 0.34, 1.0), w=0.11, d=0.10, h=0.06, z0=0.60,
             brim=(0.26, 0.24, 0.025, 0.58, (0.78, 0.65, 0.34, 1.0))))
