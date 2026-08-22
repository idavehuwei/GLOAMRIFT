#!/usr/bin/env python3
"""Blender 5.2 headless GLB 优化器。

用法（由 Bash 以环境变量传参调用）：
  GLB_IN=/path/to/x.glb GLB_OUT=/path/to/x.glb TEX_TARGET=1024 DRACO=1 \
    /Applications/Blender.app/Contents/MacOS/Blender --background --python optimize_glb.py

流程：
  1. 导入 GLB（保留骨架/动画/材质）
  2. 每张纹理最长边 > TEX_TARGET 则等比缩到 TEX_TARGET，并重打包进 GLB
  3. 导出 GLB：Draco 网格压缩 + export_skins + export_yup + export_animations
"""
import os
import sys
import bpy

GLB_IN = os.environ.get("GLB_IN", "")
GLB_OUT = os.environ.get("GLB_OUT", GLB_IN)
TEX_TARGET = int(os.environ.get("TEX_TARGET", "1024"))
USE_DRACO = os.environ.get("DRACO", "0") == "1"  # 注意：Godot 4.7 GLB 导入器不支持 Draco，默认关闭

if not GLB_IN or not os.path.exists(GLB_IN):
    print(f"[optimize_glb] ERROR: GLB_IN missing or not found: {GLB_IN}")
    sys.exit(1)

# 1) 清场 + 导入
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for img in list(bpy.data.images):
    bpy.data.images.remove(img)
for mat in list(bpy.data.materials):
    bpy.data.materials.remove(mat)

print(f"[optimize_glb] importing {GLB_IN}")
bpy.ops.import_scene.gltf(filepath=GLB_IN)

# 2) 纹理降采样
resized = 0
for img in list(bpy.data.images):
    w, h = img.size
    if w <= 0 or h <= 0:
        continue
    longest = max(w, h)
    if longest <= TEX_TARGET:
        print(f"[optimize_glb]   keep img {img.name} {w}x{h} (<= {TEX_TARGET})")
        continue
    scale = TEX_TARGET / longest
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    print(f"[optimize_glb]   downsample img {img.name} {w}x{h} -> {nw}x{nh}")
    try:
        img.scale(nw, nh)
        # 重打包，使缩小后的像素嵌入 GLB
        if img.packed_file is None:
            img.pack()
        resized += 1
    except Exception as e:
        print(f"[optimize_glb]   WARN resize failed for {img.name}: {e}")

# 3) 导出
export_kwargs = dict(
    filepath=GLB_OUT,
    export_format='GLB',
    export_yup=True,
    export_skins=True,
    export_animations=True,
    export_materials='EXPORT',
    export_image_format='AUTO',
)
if USE_DRACO:
    export_kwargs["export_draco_mesh_compression_enable"] = True
    export_kwargs["export_draco_mesh_compression_level"] = 6

# 先导出到临时文件，避免“导入路径==导出路径”同文件覆盖导致的截断/损坏
import tempfile, os as _os
tmp_out = GLB_OUT + ".tmp.glb"
export_kwargs["filepath"] = tmp_out
print(f"[optimize_glb] exporting -> {tmp_out} (draco={USE_DRACO}, resized={resized})")
try:
    bpy.ops.export_scene.gltf(**export_kwargs)
except TypeError as e:
    # 某些 Blender 版本参数名不同，去掉可能不支持的项重试
    print(f"[optimize_glb] WARN first export failed ({e}), retrying without draco/anim extras")
    export_kwargs.pop("export_draco_mesh_compression_enable", None)
    export_kwargs.pop("export_draco_mesh_compression_level", None)
    bpy.ops.export_scene.gltf(**export_kwargs)
_os.replace(tmp_out, GLB_OUT)

# 输出前后体积供调用方读取
before = os.path.getsize(GLB_IN)
after = os.path.getsize(GLB_OUT) if os.path.exists(GLB_OUT) else -1
print(f"[optimize_glb] DONE in={before} out={after} reduced={(1-after/before)*100:.1f}%")
