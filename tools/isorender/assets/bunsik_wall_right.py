"""Tier-1 (bunsikjip) north-east wall: North -> East edge, camera-far like
`stall_curtain_right`, with a window centred on the one-cell segment (the game
repeats one sprite per cell) and one framing post on the east end."""

import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 2.0
LOOK_AT = (0.0, -0.5, 0.35)
OUTLINE_PX = 0.45   # same ink weight as wall_shop_left

HEIGHT = 0.709      # wall_shop_left's own numbers, reused verbatim
THICKNESS = 0.06
PLANK_COUNT = 5
PLANK_GAP = 0.0
PLANK_STEP = 0.006
TEXTURE_PLANKS = 11  # plank_wall.png draws 11 planks
POST = 0.07          # corner-post footprint (col and row)
POST_HEIGHT = HEIGHT + 0.02
#: A post stands POST_PROUD past the visible face, so it reads as a post
#: rather than a flush end.
POST_PROUD = 0.01

WINDOW_W = 0.36
WINDOW_H = 0.30
FRAME_BAR = 0.04       # frame bar width
FRAME_PROUD = 0.035    # frame stands this far off the visible face
PANE_PROUD = 0.015     # glass sits recessed inside the frame
PANE_RGBA = (0.30, 0.42, 0.50, 1.0)


def build():
    planks = isobuild.flat_material(
        "BunsikWallRightPlanks", texture="plank_wall.png", rgba=(0.72, 0.53, 0.34, 1.0)
    )
    trim = isobuild.flat_material(
        "BunsikWallRightTrim", texture="plank_end.png", rgba=(0.62, 0.44, 0.28, 1.0)
    )
    isobuild.wall(
        "BunsikWallRight",
        start=DIAMOND_VERTICES["north"],
        end=DIAMOND_VERTICES["east"],
        height=HEIGHT,
        thickness=THICKNESS,
        face_material=planks,
        trim_material=trim,
        inward_toward=(0.0, 0.0),
        plank_count=PLANK_COUNT,
        plank_gap=PLANK_GAP,
        plank_step=PLANK_STEP,
        texture_planks=TEXTURE_PLANKS,
    )
    isobuild.box(
        "BunsikWallRightPost0",
        center=(0.5 + POST_PROUD - POST / 2, -0.5 + THICKNESS + POST_PROUD - POST / 2),
        width=POST,
        depth=POST,
        height=POST_HEIGHT,
        face_material=trim,
        trim_material=trim,
        top_material=trim,
    )

    # Visible face of this camera-far wall is the offset side, row = -0.5 + THICKNESS.
    face_row = -0.5 + THICKNESS
    mid_z = HEIGHT / 2.0
    z_bottom = mid_z - WINDOW_H / 2.0
    glass = isobuild.flat_material("BunsikWindowGlass", rgba=PANE_RGBA)

    def part(name, col, width, z0, height, depth, material):
        isobuild.box(
            name,
            center=(col, face_row + depth / 2.0),
            width=width,
            depth=depth,
            height=height,
            face_material=material,
            trim_material=material,
            top_material=material,
            base_z=z0,
        )

    inner_h = WINDOW_H - 2 * FRAME_BAR
    inner_w = WINDOW_W - 2 * FRAME_BAR
    part("WindowPane", 0.0, inner_w + 0.01, z_bottom + FRAME_BAR - 0.005, inner_h + 0.01, PANE_PROUD, glass)
    part("WindowSill", 0.0, WINDOW_W, z_bottom, FRAME_BAR, FRAME_PROUD, trim)
    part("WindowHead", 0.0, WINDOW_W, z_bottom + WINDOW_H - FRAME_BAR, FRAME_BAR, FRAME_PROUD, trim)
    part("WindowJambL", -(WINDOW_W - FRAME_BAR) / 2.0, FRAME_BAR, z_bottom + FRAME_BAR, inner_h, FRAME_PROUD, trim)
    part("WindowJambR", (WINDOW_W - FRAME_BAR) / 2.0, FRAME_BAR, z_bottom + FRAME_BAR, inner_h, FRAME_PROUD, trim)
    return {}
