"""The one palette. Every sprite pixel is one of these names."""

PALETTE = {
    "ink": "2b1b2e",
    "plum": "54304a",
    "mauve": "8f6384",
    "soil_dark": "5c3a30",
    "soil": "8a5a3c",
    "soil_light": "b98352",
    "sand": "dfb277",
    "cream": "f5e6c4",
    "paper": "fffaf0",
    "skin": "f4c9a0",
    "skin_shade": "d99873",
    "leaf_deep": "1f4d3b",
    "leaf_dark": "2f7d45",
    "leaf": "58b04a",
    "leaf_light": "a0d85c",
    "leaf_pale": "e0f4a4",
    "meadow": "86c562",
    "meadow_dark": "62a652",
    "gold": "f4b93a",
    "gold_light": "ffe680",
    "gold_dark": "c47a22",
    "orange": "f0803a",
    "orange_dark": "c25a2e",
    "red": "d94a40",
    "red_dark": "9e2c3c",
    "pink": "f5a3ad",
    "sky": "8fd3ee",
    "blue": "4487cc",
    "navy": "2f4278",
    "grey_light": "cfccd6",
    "grey": "9390a1",
    "grey_dark": "5d5870",
}

# One char per colour, shared by every ASCII grid in sprites/.
LEGEND = {
    ".": None,
    "K": "ink", "P": "plum", "M": "mauve",
    "D": "soil_dark", "B": "soil", "b": "soil_light", "S": "sand",
    "C": "cream", "W": "paper",
    "s": "skin", "h": "skin_shade",
    "E": "leaf_deep", "G": "leaf_dark", "g": "leaf", "l": "leaf_light", "p": "leaf_pale",
    "m": "meadow", "n": "meadow_dark",
    "Y": "gold", "y": "gold_light", "Z": "gold_dark",
    "O": "orange", "o": "orange_dark",
    "R": "red", "r": "red_dark", "k": "pink",
    "c": "sky", "U": "blue", "N": "navy",
    "L": "grey_light", "A": "grey", "a": "grey_dark",
}

# The colour one step toward shadow (light is top-left, so this goes bottom-right).
SHADE = {
    "paper": "grey_light", "cream": "sand", "sand": "soil_light", "soil_light": "soil",
    "soil": "soil_dark", "soil_dark": "plum", "plum": "ink", "mauve": "plum",
    "skin": "skin_shade", "skin_shade": "soil",
    "leaf_pale": "leaf_light", "leaf_light": "leaf", "leaf": "leaf_dark",
    "leaf_dark": "leaf_deep", "leaf_deep": "ink",
    "meadow": "meadow_dark", "meadow_dark": "leaf_dark",
    "gold_light": "gold", "gold": "gold_dark", "gold_dark": "soil",
    "orange": "orange_dark", "orange_dark": "red_dark",
    "red": "red_dark", "red_dark": "plum", "pink": "red",
    "sky": "blue", "blue": "navy", "navy": "ink",
    "grey_light": "grey", "grey": "grey_dark", "grey_dark": "plum", "ink": "ink",
}

LIGHT = {
    "ink": "plum", "plum": "mauve", "soil_dark": "soil", "soil": "soil_light",
    "soil_light": "sand", "sand": "cream", "cream": "paper", "grey_dark": "grey",
    "grey": "grey_light", "grey_light": "paper", "gold_dark": "gold", "gold": "gold_light",
    "leaf_deep": "leaf_dark", "leaf_dark": "leaf", "leaf": "leaf_light",
    "leaf_light": "leaf_pale", "red_dark": "red", "red": "pink", "navy": "blue",
    "blue": "sky", "orange_dark": "orange", "orange": "gold", "mauve": "pink",
    "meadow_dark": "meadow", "meadow": "leaf_light",
}

# Sky is a flat fill drawn by the scene behind the backdrop, so it is not part of
# the sprite palette. One colour per phase of the 4-minute day loop.
SKY = {
    "morning": "ffe2b8",
    "noon": "a9e1f6",
    "dusk": "f6a878",
    "night": "262a52",
}

# Multiply tint the scene applies to the whole world per phase (noon = identity).
TINT = {
    "morning": "fff2dc",
    "noon": "ffffff",
    "dusk": "ffc9a8",
    "night": "8d93c9",
}


def rgba(name):
    h = PALETTE[name]
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def rgb_hex(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
