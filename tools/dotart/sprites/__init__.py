"""Registry. Each sprite module calls add(); build.py reads ASSETS."""

from dataclasses import dataclass, field

ASSETS = []
GROUP_ORDER = ["ground", "backdrop", "shop", "dish", "farm", "char", "fx", "ui"]


@dataclass
class Asset:
    group: str
    name: str
    frames: list          # [(suffix or None, Sprite)]
    anchor: tuple = None  # (x, y) art pixel, top-left origin, that sits on the ground point
    duration: float = None
    kind: str = "single"  # single | anim | variants | poses
    note: str = ""
    slots: dict = field(default_factory=dict)

    def image_names(self):
        base = f"dot_{self.group}_{self.name}"
        return [(base if sfx is None else f"{base}_{sfx}", spr) for sfx, spr in self.frames]


def add(group, name, frames, anchor=None, duration=None, kind=None, note="", slots=None):
    if not isinstance(frames, list):
        frames = [(None, frames)]
    elif frames and not isinstance(frames[0], tuple):
        frames = [(str(i), f) for i, f in enumerate(frames)]
    if kind is None:
        kind = "single" if len(frames) == 1 else "anim"
    a = Asset(group, name, frames, anchor, duration, kind, note, slots or {})
    ASSETS.append(a)
    return a


def find(group, name, frame=None):
    for a in ASSETS:
        if a.group == group and a.name == name:
            for sfx, spr in a.frames:
                if frame is None or sfx == str(frame):
                    return spr
    raise KeyError((group, name, frame))


def load_all():
    from . import ground, backdrop, shop, dish, farm, characters, fx, ui  # noqa: F401
    return ASSETS
