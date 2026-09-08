"""Blender-side building blocks for asset modules.

Asset modules describe *what* a piece is — where its footprint sits on the
grid, how tall it stands, which flat texture panel goes on which face. They
never touch the camera, the lights, or the pixel scale; `rig.py` owns those so
that every asset in the set is rendered under identical conditions.
"""

import os

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


def wall(
    name,
    start,
    end,
    height,
    thickness,
    face_material,
    trim_material=None,
    inward_toward=(0.0, 0.0),
    uv_repeat=(1.0, 1.0),
):
    """A wall standing on the grid edge `start` -> `end`.

    `start`/`end` are grid coordinates (see `isogrid.DIAMOND_VERTICES`),
    `height` and `thickness` are in world units (1 unit = one cell edge).
    `thickness` extrudes *away* from the camera-facing side, toward
    `inward_toward` (the cell center by default), which is what gives the
    piece its visible end-cap sliver and top edge.

    The returned object's `["markers"]` are the four corners of the visible
    outer face, in grid space, ready for `rig.py` to project to pixels.
    """
    nx, ny = _perpendicular_toward(start, end, inward_toward)
    inner_start = (start[0] + nx * thickness, start[1] + ny * thickness)
    inner_end = (end[0] + nx * thickness, end[1] + ny * thickness)

    bottom_outer_a = world_point(*start, 0.0)
    bottom_outer_b = world_point(*end, 0.0)
    bottom_inner_a = world_point(*inner_start, 0.0)
    bottom_inner_b = world_point(*inner_end, 0.0)
    top_outer_a = world_point(*start, height)
    top_outer_b = world_point(*end, height)
    top_inner_a = world_point(*inner_start, height)
    top_inner_b = world_point(*inner_end, height)

    verts = [
        bottom_outer_a,  # 0
        bottom_outer_b,  # 1
        top_outer_b,  # 2
        top_outer_a,  # 3
        bottom_inner_a,  # 4
        bottom_inner_b,  # 5
        top_inner_b,  # 6
        top_inner_a,  # 7
    ]
    faces = [
        (0, 1, 2, 3),  # outer face — the one the panel texture is for
        (5, 4, 7, 6),  # inner face (never seen, kept so the box is solid)
        (3, 2, 6, 7),  # top
        (1, 5, 6, 2),  # end cap at `end`
        (4, 0, 3, 7),  # end cap at `start`
        (4, 5, 1, 0),  # bottom
    ]
    u, v = uv_repeat
    square = [(0.0, 0.0), (u, 0.0), (u, v), (0.0, v)]
    uvs = [square] * len(faces)

    materials = [face_material]
    trim = trim_material or face_material
    if trim is not face_material:
        materials.append(trim)
    trim_index = materials.index(trim)
    material_indices = [0, trim_index, trim_index, trim_index, trim_index, trim_index]

    obj = _mesh_object(name, verts, faces, uvs, materials, material_indices)
    obj["markers"] = {
        "face_bottom_start": (start[0], start[1], 0.0),
        "face_bottom_end": (end[0], end[1], 0.0),
        "face_top_start": (start[0], start[1], height),
        "face_top_end": (end[0], end[1], height),
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
