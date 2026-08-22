#!/usr/bin/env python3
# tools/gen_weapons.py  —  Blender 5.2 headless 程序化生成 10 把低多边形 PBR 武器
# 用法: Blender --background --python tools/gen_weapons.py -- <OUTDIR>
# 约定: 握把底部位于原点 (0,0,0)，武器沿 Blender +Z 延伸；export_yup 后 Godot 中为 +Y 向上。
import sys, os, bpy

OUT = "/Users/weihu/AI/ShadowDepths/godot/models/src"
for i, a in enumerate(sys.argv):
    if a == "--" and i + 1 < len(sys.argv):
        OUT = sys.argv[i + 1]
os.makedirs(OUT, exist_ok=True)

# ---------- 材质库（PBR，无贴图，纯色 + metallic/roughness）----------
MATS = {}
def mat(name, hexcol, metallic=0.0, roughness=0.6, emissive=0x000000, emi=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = None
    for nn in m.node_tree.nodes:
        if nn.type == 'BSDF_PRINCIPLED':
            bsdf = nn
            break
    if bsdf is None:
        bsdf = m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    def setin(names, value):
        for nm in names:
            if nm in bsdf.inputs:
                bsdf.inputs[nm].default_value = value
                return
    setin(["Base Color"], (
        ((hexcol >> 16) & 255) / 255.0,
        ((hexcol >> 8) & 255) / 255.0,
        (hexcol & 255) / 255.0, 1.0))
    setin(["Metallic"], metallic)
    setin(["Roughness"], roughness)
    if emi > 0:
        setin(["Emission Color", "Emission"], (
            ((emissive >> 16) & 255) / 255.0,
            ((emissive >> 8) & 255) / 255.0,
            (emissive & 255) / 255.0, 1.0))
        setin(["Emission Strength", "Emission Strength"], emi)
    MATS[name] = m
    return m

mat("steel", 0xb8c0c8, 0.9, 0.35)
mat("darksteel", 0x6a7078, 0.9, 0.45)
mat("wood", 0x6b4a2a, 0.0, 0.85)
mat("gold", 0xd9b24a, 1.0, 0.3)
mat("leather", 0x5a3a22, 0.0, 0.8)
mat("gem", 0x6ad0ff, 0.1, 0.1, 0x3aa0ff, 1.4)
mat("bone", 0xe8e2cf, 0.0, 0.7)

# ---------- 基础体素构造 ----------
def box(w, h, d, pos, m):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = (w, h, d)
    o.location = pos
    o.data.materials.append(m)
    return o

def cyl(r, h, pos, m, seg=12, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=r, depth=h)
    o = bpy.context.object
    o.location = pos
    o.rotation_euler = rot
    o.data.materials.append(m)
    return o

def sph(r, pos, m, seg=10):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=2)
    o = bpy.context.object
    o.location = pos
    o.data.materials.append(m)
    return o

def cone(r, depth, pos, m, seg=8, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=r, radius2=0.0, depth=depth)
    o = bpy.context.object
    o.location = pos
    o.rotation_euler = rot
    o.data.materials.append(m)
    return o

def join_all(objs):
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return bpy.context.object

# ---------- 各武器构造（沿 +Z）----------
def build_sword():
    o = []
    o.append(sph(0.035, (0, 0, 0.0), MATS["gold"]))
    o.append(cyl(0.022, 0.18, (0, 0, 0.09), MATS["leather"]))
    o.append(box(0.26, 0.05, 0.04, (0, 0, 0.18), MATS["gold"]))
    o.append(box(0.05, 0.9, 0.016, (0, 0, 0.63), MATS["steel"]))
    o.append(cone(0.04, 0.14, (0, 0, 1.13), MATS["steel"], 4))
    return join_all(o)

def build_axe():
    o = []
    o.append(cyl(0.022, 0.22, (0, 0, 0.11), MATS["leather"]))
    o.append(box(0.05, 0.05, 0.06, (0, 0, 0.22), MATS["gold"]))
    o.append(box(0.14, 0.24, 0.05, (0.10, 0, 0.52), MATS["steel"]))
    o.append(box(0.05, 0.16, 0.05, (0.04, 0, 0.52), MATS["steel"]))
    o.append(cone(0.05, 0.1, (-0.06, 0, 0.52), MATS["steel"], 6, (1.5708, 0, 0)))
    return join_all(o)

def build_mace():
    import math
    o = []
    o.append(cyl(0.022, 0.2, (0, 0, 0.1), MATS["leather"]))
    o.append(cyl(0.025, 0.42, (0, 0, 0.41), MATS["wood"]))
    o.append(sph(0.12, (0, 0, 0.64), MATS["steel"], 12))
    for a in range(4):
        ang = a * math.pi / 2
        o.append(box(0.05, 0.05, 0.05, (0.12 * math.cos(ang), 0.12 * math.sin(ang), 0.64), MATS["steel"]))
    return join_all(o)

def build_spear():
    o = []
    o.append(cyl(0.03, 0.3, (0, 0, 0.15), MATS["leather"]))
    o.append(cyl(0.025, 1.6, (0, 0, 0.8), MATS["wood"]))
    o.append(cone(0.06, 0.28, (0, 0, 1.6), MATS["steel"], 6))
    return join_all(o)

def build_dagger():
    o = []
    o.append(sph(0.03, (0, 0, 0.0), MATS["gold"]))
    o.append(cyl(0.02, 0.14, (0, 0, 0.07), MATS["leather"]))
    o.append(box(0.18, 0.03, 0.035, (0, 0, 0.14), MATS["gold"]))
    o.append(box(0.035, 0.4, 0.012, (0, 0, 0.34), MATS["steel"]))
    o.append(cone(0.03, 0.12, (0, 0, 0.56), MATS["steel"], 4))
    return join_all(o)

def build_staff():
    o = []
    o.append(cyl(0.03, 1.5, (0, 0, 0.75), MATS["wood"]))
    o.append(sph(0.09, (0, 0, 1.55), MATS["gem"], 12))
    o.append(box(0.22, 0.04, 0.04, (0, 0, 1.42), MATS["gold"]))
    o.append(box(0.04, 0.18, 0.04, (0, 0, 1.4), MATS["gold"]))
    return join_all(o)

def build_bow():
    import math
    cu = bpy.data.curves.new("bow_curve", 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = 0.03
    cu.bevel_resolution = 2
    spl = cu.splines.new('POLY')
    pts = 16
    R = 0.42
    spl.points.add(pts)
    for i in range(pts + 1):
        t = math.pi * 0.92 * (i / pts) - math.pi * 0.46
        x = R * math.cos(t)
        z = R * math.sin(t) + 0.05
        spl.points[i].co = (x, 0, z, 1)
    ob = bpy.data.objects.new("bow_curve", cu)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target='MESH')
    ob.data.materials.append(MATS["wood"])
    string = box(0.01, 0.005, 0.86, (0, 0, 0.05), MATS["bone"])
    return join_all([ob, string])

def build_crossbow():
    o = []
    o.append(box(0.06, 0.5, 0.06, (0, 0, 0.25), MATS["wood"]))
    o.append(box(0.5, 0.05, 0.04, (0, 0, 0.42), MATS["steel"]))
    o.append(box(0.006, 0.5, 0.006, (0, 0, 0.42), MATS["bone"]))
    o.append(cyl(0.012, 0.4, (0, 0, 0.25), MATS["darksteel"], 8, (1.5708, 0, 0)))
    return join_all(o)

def build_book():
    o = []
    o.append(box(0.18, 0.26, 0.05, (0, 0, 0.13), MATS["leather"]))
    o.append(box(0.16, 0.24, 0.04, (0, 0, 0.135), MATS["bone"]))
    o.append(box(0.2, 0.03, 0.06, (0, 0, 0.13), MATS["gold"]))
    o.append(sph(0.03, (0.0, 0, 0.13), MATS["gem"], 8))
    return join_all(o)

def build_wand():
    o = []
    o.append(cyl(0.018, 0.6, (0, 0, 0.3), MATS["wood"]))
    o.append(box(0.05, 0.04, 0.05, (0, 0, 0.5), MATS["gold"]))
    o.append(sph(0.055, (0, 0, 0.62), MATS["gem"], 10))
    return join_all(o)

WEAPONS = {
    "wpn_sword": build_sword,
    "wpn_axe": build_axe,
    "wpn_mace": build_mace,
    "wpn_spear": build_spear,
    "wpn_dagger": build_dagger,
    "wpn_staff": build_staff,
    "wpn_bow": build_bow,
    "wpn_crossbow": build_crossbow,
    "wpn_book": build_book,
    "wpn_wand": build_wand,
}

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

for wid, builder in WEAPONS.items():
    clear_scene()
    obj = builder()
    obj.name = wid
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, wid + ".glb"),
        export_format='GLB',
        export_yup=True,
        export_materials='EXPORT',
    )
    print("WROTE", wid)

print("ALL_WEAPONS_DONE")
