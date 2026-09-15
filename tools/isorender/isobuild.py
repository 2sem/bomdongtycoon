"""Blender-side building blocks for asset modules.

Asset modules describe *what* a piece is — where its footprint sits on the
grid, how tall it stands, which flat texture panel goes on which face. They
never touch the camera, the lights, or the pixel scale; `rig.py` owns those so
that every asset in the set is rendered under identical conditions.
"""

import os

import bmesh
import bpy

from isogrid import world_point

TEXTURE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "textures")


# --- Materials --------------------------------------------------------------


def _set_principled(bsdf, base_color_node=None, rgba=(0.72, 0.53, 0.34, 1.0)):
    """Flat, matte shading: the render's light direction should be the only
    thing shaping a face, so kill specular and go fully rough."""
    if base_color_node is not None:
        bsdf.id_data.links.new(base_color_node.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 1.0
    for specular in ("Specular IOR Level", "Specular"):  # renamed in Blender 4.x
        if specular in bsdf.inputs:
            bsdf.inputs[specular].default_value = 0.0
            break


def flat_material(name, texture=None, rgba=(0.72, 0.53, 0.34, 1.0)):
    """A matte material, optionally driven by a flat texture panel.

    `texture` is a file name inside `tools/isorender/textures/`. A missing
    file is not an error — the material falls back to `rgba`, so the rig and
    an asset's geometry can be verified before its art exists.
    """
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    bsdf = nodes["Principled BSDF"]

    image_node = None
    if texture:
        path = os.path.join(TEXTURE_DIR, texture)
        if os.path.exists(path):
            image_node = nodes.new("ShaderNodeTexImage")
            image_node.image = bpy.data.images.load(path)
            image_node.image.colorspace_settings.name = "sRGB"
            image_node.extension = "REPEAT"
            image_node.location = (-400, 0)
        else:
            print(f"[isorender] texture not found, using flat color: {path}")

    _set_principled(bsdf, image_node, rgba)
    return material


# --- Geometry ---------------------------------------------------------------


def _mesh_object(name, verts, faces, uvs, materials, material_indices):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    flat_uvs = [uv for face_uvs in uvs for uv in face_uvs]
    for loop_index, uv in enumerate(flat_uvs):
        uv_layer.data[loop_index].uv = uv

    for material in materials:
        mesh.materials.append(material)
    for polygon, material_index in zip(mesh.polygons, material_indices):
        polygon.material_index = material_index

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _perpendicular_toward(start, end, target):
    """The horizontal unit normal of edge `start`->`end` that points at
    `target` — i.e. "which way is inward" for a wall on a cell edge."""
    ex, ey = end[0] - start[0], end[1] - start[1]
    length = (ex * ex + ey * ey) ** 0.5
    nx, ny = -ey / length, ex / length
    mid = ((start[0] + end[0]) / 2.0, (start[1] + end[1]) / 2.0)
    if nx * (target[0] - mid[0]) + ny * (target[1] - mid[1]) < 0:
        nx, ny = -nx, -ny
    return nx, ny


def _box(start, end, inner_start, inner_end, z0, z1, uv_span, top_uv):
    """One solid slab between two heights, as `(verts, faces, uvs)` with the
    outer face first. `uv_span` is the `(v0, v1)` slice of the panel texture
    this slab shows, so a stack of them reads as one continuous wall."""
    verts = [
        world_point(*start, z0),  # 0
        world_point(*end, z0),  # 1
        world_point(*end, z1),  # 2
        world_point(*start, z1),  # 3
        world_point(*inner_start, z0),  # 4
        world_point(*inner_end, z0),  # 5
        world_point(*inner_end, z1),  # 6
        world_point(*inner_start, z1),  # 7
    ]
    faces = [
        (0, 1, 2, 3),  # outer face — the one the panel texture is for
        (5, 4, 7, 6),  # inner face (never seen, kept so the slab is solid)
        (3, 2, 6, 7),  # top
        (1, 5, 6, 2),  # end cap at `end`
        (4, 0, 3, 7),  # end cap at `start`
        (4, 5, 1, 0),  # bottom
    ]
    v0, v1 = uv_span
    outer = [(0.0, v0), (1.0, v0), (1.0, v1), (0.0, v1)]
    trim = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    u0, tv0, u1, tv1 = top_uv
    top = [(u0, tv0), (u1, tv0), (u1, tv1), (u0, tv1)]
    return verts, faces, [outer, trim, top, trim, trim, trim]


def wall(
    name,
    start,
    end,
    height,
    thickness,
    face_material,
    trim_material=None,
    inward_toward=(0.0, 0.0),
    plank_count=1,
    plank_gap=0.0,
    plank_step=0.0,
    texture_planks=0,
    uv_inset=0.012,
    top_material=None,
    top_uv=(0.05, 0.36, 0.45, 0.44),
):
    """A wall standing on the grid edge `start` -> `end`.

    `start`/`end` are grid coordinates (see `isogrid.DIAMOND_VERTICES`),
    `height` and `thickness` are in world units (1 unit = one cell edge).
    `thickness` extrudes *away* from the camera-facing side, toward
    `inward_toward` (the cell center by default), which is what gives the
    piece its visible end-cap sliver and top edge.

    `plank_count` builds the wall as that many stacked slabs instead of one
    slab. That is not decoration: it is what puts an ink seam between planks
    and a stepped end cap on the wall's visible end, the way the shipped art
    reads. `plank_gap` is the recess between them and `plank_step` staggers
    their depth so the cap steps in and out.

    `texture_planks` says how many planks the face panel itself depicts. Set
    it and each slab maps to one whole plank band of that panel — a different
    band per slab, so they vary — instead of to its own slice of it. Without
    it, a panel that already draws seams doubles up with the geometry's own.
    Leave it 0 for a plain grain panel. `uv_inset` keeps a band clear of the
    painted seam at its edges.

    The wall's top edge takes `top_material` (the face panel by default),
    windowed to `top_uv` — a seam-free patch of it. Tiling a seamed panel
    across that thin strip instead would read as a row of notches. The end
    caps keep `trim_material`, where a repeat per plank is wanted: that is
    what makes the stepped end read as stacked timber.

    The object's `["markers"]` are the four corners of the visible outer face
    in grid space, ready for `rig.py` to project to pixels.
    """
    nx, ny = _perpendicular_toward(start, end, inward_toward)

    def offset(point, distance):
        return (point[0] + nx * distance, point[1] + ny * distance)

    verts, faces, uvs = [], [], []
    plank_height = height / plank_count
    for index in range(plank_count):
        z0 = index * plank_height
        z1 = z0 + plank_height - (plank_gap if index < plank_count - 1 else 0.0)
        depth = thickness + (plank_step if index % 2 else 0.0)
        if texture_planks:
            #: Map this slab onto one whole plank of the panel — a different
            #: one per slab so they vary — rather than onto its own slice of
            #: the panel, which would put the panel's painted seams on top of
            #: the geometry's own.
            band = 1.0 / texture_planks
            v0 = (index % texture_planks) * band + uv_inset
            uv_span = (v0, v0 + band - 2 * uv_inset)
        else:
            uv_span = (z0 / height, z1 / height)
        slab_verts, slab_faces, slab_uvs = _box(
            start,
            end,
            offset(start, depth),
            offset(end, depth),
            z0,
            z1,
            uv_span,
            top_uv,
        )
        base = len(verts)
        verts.extend(slab_verts)
        faces.extend(tuple(i + base for i in face) for face in slab_faces)
        uvs.extend(slab_uvs)

    materials = [face_material]

    def slot(material):
        material = material or face_material
        if material not in materials:
            materials.append(material)
        return materials.index(material)

    trim_index = slot(trim_material)
    top_index = slot(top_material)
    # outer, inner, top, cap at `end`, cap at `start`, bottom
    material_indices = [0, trim_index, top_index, trim_index, trim_index, trim_index] * plank_count

    obj = _mesh_object(name, verts, faces, uvs, materials, material_indices)
    obj["markers"] = {
        "face_bottom_start": (start[0], start[1], 0.0),
        "face_bottom_end": (end[0], end[1], 0.0),
        "face_top_start": (start[0], start[1], height),
        "face_top_end": (end[0], end[1], height),
    }
    return obj


def prop_table(
    name,
    center,
    width,
    depth,
    height,
    top_thickness,
    leg_thickness,
    leg_inset,
    top_material,
    leg_material,
):
    """A free-standing prop: a flat top slab on four legs, footprint centered
    at grid point `center` with its sides parallel to the col/row axes — like
    `plane()`, not a wall's edge-perpendicular extrusion.

    `width` runs along the col axis, `depth` along the row axis (independent,
    since a table is longer one way). `height` is the standing height (top of
    the slab); `top_thickness` is the slab's own thickness, so the legs run
    from the ground up to `height - top_thickness`. `leg_thickness` is each
    leg's square cross-section; `leg_inset` pulls all four legs in from the
    footprint edges so the top overhangs slightly, the way real furniture
    does.

    Two material slots, not one: `top_material` for the top face (a worktop
    panel differs from the apron/legs), `leg_material` for everything else —
    the underside of the top and all four legs — via `flat_material()`, same
    as `wall()`'s trim.

    Markers: `base_center` at `(col, row, 0.0)` — the ground-contact anchor —
    plus the footprint's four base corners (`base_corner_north/east/south/west`,
    named the same way `isogrid.DIAMOND_VERTICES` names a cell's own corners —
    "nw/ne/sw/se" would be misleading on a 45deg-yawed grid, since a cell's
    own "west" vertex is not screen-northwest) so clearance against the cell
    edge can be read off the numbers instead of eyeballed, and `top_center`
    at `(col, row, height)` for whatever stands on the table next.
    """
    ccol, crow = center
    half_w, half_d = width / 2.0, depth / 2.0
    leg_z1 = height - top_thickness

    verts, faces, uvs = [], [], []
    materials = [leg_material, top_material]
    LEG, TOP = 0, 1
    material_indices = []

    def add(part_verts, part_faces, part_uvs, part_material_indices):
        base = len(verts)
        verts.extend(part_verts)
        faces.extend(tuple(i + base for i in face) for face in part_faces)
        uvs.extend(part_uvs)
        material_indices.extend(part_material_indices)

    # --- Top slab: a thin box, top face gets `top_material`, everything else
    # (underside, sides) gets `leg_material` like a wall's trim/end-cap.
    top_corners = [
        (ccol - half_w, crow - half_d),
        (ccol + half_w, crow - half_d),
        (ccol + half_w, crow + half_d),
        (ccol - half_w, crow + half_d),
    ]
    top_verts = [world_point(col, row, leg_z1) for col, row in top_corners]
    top_verts += [world_point(col, row, height) for col, row in top_corners]
    top_faces = [
        (0, 1, 2, 3),  # bottom (underside)
        (7, 6, 5, 4),  # top face
        (0, 4, 5, 1),  # side south
        (1, 5, 6, 2),  # side east
        (2, 6, 7, 3),  # side north
        (3, 7, 4, 0),  # side west
    ]
    square = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    top_uvs = [square, square, square, square, square, square]
    add(top_verts, top_faces, top_uvs, [LEG, TOP, LEG, LEG, LEG, LEG])

    # --- Four legs: thin prisms from the ground to the underside of the top,
    # inset from the footprint edges so the top overhangs like real furniture.
    leg_centers = [
        (ccol - half_w + leg_inset, crow - half_d + leg_inset),
        (ccol + half_w - leg_inset, crow - half_d + leg_inset),
        (ccol + half_w - leg_inset, crow + half_d - leg_inset),
        (ccol - half_w + leg_inset, crow + half_d - leg_inset),
    ]
    leg_half = leg_thickness / 2.0
    for leg_col, leg_row in leg_centers:
        corners = [
            (leg_col - leg_half, leg_row - leg_half),
            (leg_col + leg_half, leg_row - leg_half),
            (leg_col + leg_half, leg_row + leg_half),
            (leg_col - leg_half, leg_row + leg_half),
        ]
        leg_verts = [world_point(col, row, 0.0) for col, row in corners]
        leg_verts += [world_point(col, row, leg_z1) for col, row in corners]
        leg_faces = [
            (0, 1, 2, 3),  # bottom
            (7, 6, 5, 4),  # top (unseen, under the slab)
            (0, 4, 5, 1),
            (1, 5, 6, 2),
            (2, 6, 7, 3),
            (3, 7, 4, 0),
        ]
        leg_uvs = [square] * 6
        add(leg_verts, leg_faces, leg_uvs, [LEG] * 6)

    obj = _mesh_object(name, verts, faces, uvs, materials, material_indices)
    #: Five separate boxes (top slab + 4 legs) hand-assembled from raw face
    #: tuples, unlike `_box()`'s single hand-verified winding — recompute
    #: outward normals rather than trust it by inspection. Scoped to this
    #: object only; `_mesh_object` (shared with `wall()`/`plane()`) is
    #: untouched.
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    #: Same (col-, row-) / (col+, row-) / (col+, row+) / (col-, row+) winding
    #: as `top_corners`, named the way `isogrid.DIAMOND_VERTICES` names the
    #: same four combinations for a cell's own corners.
    corner_names = ["north", "east", "south", "west"]
    obj["markers"] = {
        "base_center": (ccol, crow, 0.0),
        "top_center": (ccol, crow, height),
        **{
            f"base_corner_{corner_names[i]}": (col, row, 0.0)
            for i, (col, row) in enumerate(top_corners)
        },
    }
    return obj


def box(
    name,
    center,
    width,
    depth,
    height,
    face_material,
    trim_material,
    top_material,
    base_z=0.0,
):
    """A solid, closed box — a cash counter, a crate, a plinth — where
    `wall()` gives an open slab on a cell edge and `prop_table()` gives an
    open frame of legs, this gives four solid sides plus a top and a bottom,
    the way a counter's front and sides must read as one closed volume with
    no register-height gap underneath.

    Footprint centered at grid point `center` with its sides parallel to
    the col/row axes, like `prop_table()` and `plane()`, not a wall's
    edge-perpendicular extrusion. `width` runs along the col axis, `depth`
    along the row axis — same convention as `prop_table()`. `height` is the
    box's own standing height; `base_z` lifts the whole box so it can start
    above the ground (a register sitting on a counter's top, say) and
    defaults to flush with it.

    Three material slots, the same split as `wall()`'s face/trim: all four
    sides take `face_material`, the top takes `top_material`, and the
    underside — never seen, kept only so the box is solid — takes
    `trim_material`.

    Markers: `base_center`/`top_center` on the vertical axis through
    `center`, plus the footprint's four base corners
    (`base_corner_north/east/south/west`, `prop_table()`'s naming and
    winding) at `base_z` — not always 0.0 — so a spec can read clearance
    against a neighbouring piece off plain numbers instead of eyeballing it.
    """
    ccol, crow = center
    half_w, half_d = width / 2.0, depth / 2.0
    top_z = base_z + height

    corners = [
        (ccol - half_w, crow - half_d),
        (ccol + half_w, crow - half_d),
        (ccol + half_w, crow + half_d),
        (ccol - half_w, crow + half_d),
    ]
    verts = [world_point(col, row, base_z) for col, row in corners]
    verts += [world_point(col, row, top_z) for col, row in corners]
    faces = [
        (3, 2, 1, 0),  # bottom
        (4, 5, 6, 7),  # top
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),  # sides
    ]
    square = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    materials = [trim_material, top_material, face_material]
    TRIM, TOP, FACE = 0, 1, 2
    material_indices = [TRIM, TOP, FACE, FACE, FACE, FACE]

    obj = _mesh_object(name, verts, faces, [square] * 6, materials, material_indices)

    #: Hand-assembled from raw face tuples, same as `prop_table()`'s
    #: multi-part mesh and unlike `_box()`'s single hand-verified winding —
    #: recompute outward normals rather than trust it by inspection.
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    #: Same winding and naming as `prop_table()`'s footprint-corner markers.
    corner_names = ["north", "east", "south", "west"]
    obj["markers"] = {
        "base_center": (ccol, crow, base_z),
        "top_center": (ccol, crow, top_z),
        **{
            f"base_corner_{corner_names[i]}": (col, row, base_z)
            for i, (col, row) in enumerate(corners)
        },
    }
    return obj


def plane(name, material, size=1.0, center=(0.0, 0.0), height=0.0):
    """A flat `size` x `size` cell-aligned quad — one grid diamond when
    `size` is 1. Used by the calibration asset."""
    half = size / 2.0
    corners = [
        (center[0] - half, center[1] - half),
        (center[0] + half, center[1] - half),
        (center[0] + half, center[1] + half),
        (center[0] - half, center[1] + half),
    ]
    verts = [world_point(col, row, height) for col, row in corners]
    uvs = [[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]]
    obj = _mesh_object(name, verts, [(0, 1, 2, 3)], uvs, [material], [0])
    obj["markers"] = {
        f"corner_{i}": (col, row, height) for i, (col, row) in enumerate(corners)
    }
    return obj


def emission_material(name, rgba=(1.0, 1.0, 1.0, 1.0)):
    """Unlit white — for calibration, where lighting would only add noise to
    a measurement."""
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = rgba
    output = nodes.new("ShaderNodeOutputMaterial")
    material.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    return material
