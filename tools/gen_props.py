#!/usr/bin/env python3
# tools/gen_props.py  —  Blender 5.2 headless 程序化生成替换低质占位 prop
# 用法: Blender --background --python tools/gen_props.py -- <OUTDIR>
# 目标: prop_rock1~5（碎石）、prop_column/prop_column2（石柱）、prop_carpet（地毯）
# 约定: 与地面接触的底部贴近 y≈0；沿用原占位整体尺度，避免已有世界摆放错位。
import sys, os, bpy, bmesh, math, random

OUT = "/Users/weihu/AI/ShadowDepths/godot/models/src"
for i, a in enumerate(sys.argv):
    if a == "--" and i + 1 < len(sys.argv):
        OUT = sys.argv[i + 1]
os.makedirs(OUT, exist_ok=True)

# 关键：清掉默认场景 Cube 与插件干扰，保证 active object 可控
bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------- 材质库（PBR，无贴图）----------
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

mat("stone_l", 0x9a9488, 0.0, 0.9)
mat("stone_d", 0x6f6b62, 0.0, 0.95)
mat("stone_m", 0x7e8a72, 0.0, 0.92)
mat("stone_pale", 0xaba496, 0.0, 0.88)
mat("fabric_red", 0x7a1f1f, 0.0, 0.85)
mat("fabric_dk", 0x491313, 0.0, 0.85)
mat("fabric_gold", 0xb8902f, 0.2, 0.6)

# ---------- 基础体素 ----------
def box(w, h, d, pos, m):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = (w, h, d)
    o.location = pos
    o.data.materials.append(m)
    return o

def cyl(r, h, pos, m, seg=16, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=r, depth=h)
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

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def ground_bottom(o, y0=0.0):
    # 烘焙变换使 local 顶点 = 世界位置，再按顶点 min y 用 object.location 接地
    # （导出器可靠尊重 object.location；bmesh 直接改顶点在 5.2 下不持久）
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    miny = min(v.co.y for v in bm.verts)
    bm.free()
    o.location.y = y0 - miny
    print("  ground miny=%.3f locY=%.3f" % (miny, o.location.y))

# ---------- 岩石：低多边形碎石 (flat shading) ----------
ROCKS = [
    ("prop_rock1", 0.55, 0x8c887e),
    ("prop_rock2", 0.50, 0x6f6b62),
    ("prop_rock3", 0.52, 0x7e8a72),
    ("prop_rock4", 0.48, 0x9a9488),
    ("prop_rock5", 0.36, 0x807868),
]
def build_rock(name, radius, tint):
    clear_scene()
    rnd = random.Random(hash(name) & 0xffff)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=radius)
    o = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for v in bm.verts:
        p = v.co
        n = (math.sin(p.x * 4.1 + radius * 10) * math.cos(p.z * 3.7)
             + math.sin(p.y * 5.3 + radius * 7)) / 3.0
        k = 1.0 + 0.42 * n + rnd.uniform(-0.12, 0.12)
        v.co = (p.x * k, p.y * k * 0.78, p.z * k)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    bpy.ops.object.shade_flat()
    o.scale = (1.0, rnd.uniform(0.72, 1.0), 1.0)
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
    o.data.materials.clear()
    o.data.materials.append(mat("rock_" + name, tint, 0.0, 0.95))
    o.name = name
    ground_bottom(o, -0.05)
    return o

# ---------- 石柱：基座 + 柱身 + 柱头 ----------
def build_column(name, round_col):
    clear_scene()
    V = (math.pi / 2, 0, 0)  # 圆柱立起（Blender 圆柱默认沿 Z，转 90° 沿 Y）
    if round_col:
        # 圆石柱：高 ~1.4，半径 0.5
        base = cyl(0.62, 0.16, (0, 0.08, 0), MATS["stone_l"], 18, V)
        shaft = cyl(0.5, 1.05, (0, 0.16 + 0.525, 0), MATS["stone_pale"], 18, V)
        cap = cyl(0.62, 0.16, (0, 0.16 + 1.05 + 0.08, 0), MATS["stone_l"], 18, V)
        ringb = cyl(0.66, 0.05, (0, 0.04, 0), MATS["stone_d"], 18, V)
        ringt = cyl(0.66, 0.05, (0, 0.16 + 1.05 + 0.12, 0), MATS["stone_d"], 18, V)
        o = join_all([base, shaft, cap, ringb, ringt])
    else:
        # 方形重柱：2×2，高 2.85
        base = box(2.0, 0.25, 2.0, (0, 0.125, 0), MATS["stone_l"])
        shaft = box(1.6, 2.4, 1.6, (0, 0.25 + 1.2, 0), MATS["stone_pale"])
        cap = box(2.0, 0.2, 2.0, (0, 0.25 + 2.4 + 0.1, 0), MATS["stone_l"])
        ringb = box(2.12, 0.07, 2.12, (0, 0.06, 0), MATS["stone_d"])
        ringt = box(2.12, 0.07, 2.12, (0, 0.25 + 2.4 + 0.14, 0), MATS["stone_d"])
        o = join_all([base, shaft, cap, ringb, ringt])
    o.name = name
    ground_bottom(o, 0.0)
    return o

# ---------- 地毯：织物红 + 暗纹边框 + 金色中饰 ----------
def build_carpet(name):
    clear_scene()
    main = box(2.1, 0.04, 5.35, (0, 0.02, 0), MATS["fabric_red"])
    border = box(1.86, 0.046, 5.1, (0, 0.023, 0), MATS["fabric_dk"])
    med = box(0.9, 0.05, 0.9, (0, 0.025, 0), MATS["fabric_gold"])
    band1 = box(1.86, 0.046, 0.5, (0, 0.023, 1.9), MATS["fabric_gold"])
    band2 = box(1.86, 0.046, 0.5, (0, 0.023, -1.9), MATS["fabric_gold"])
    o = join_all([main, border, med, band1, band2])
    o.name = name
    return o

def export(o):
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, o.name + ".glb"),
        export_format='GLB',
        export_yup=True,
        export_materials='EXPORT',
    )
    print("WROTE", o.name)

for name, radius, tint in ROCKS:
    export(build_rock(name, radius, tint))
export(build_column("prop_column", True))
export(build_column("prop_column2", False))
export(build_carpet("prop_carpet"))
print("ALL_PROPS_DONE")
