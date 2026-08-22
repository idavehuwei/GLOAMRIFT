#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Ground a hy-3d static GLB so its base sits at y=0 (matches prop convention)."""
import bpy, sys, os

def ground(inp, outp):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=inp)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for m in meshes:
        bpy.context.view_layer.objects.active = m
        m.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        m.select_set(False)
    miny = 1e9
    for m in meshes:
        for v in m.data.vertices:
            p = m.matrix_world @ v.co
            miny = min(miny, p.y)
    # shift everything down so base at y=0
    dy = -miny
    for m in meshes:
        m.location.y += dy
    bpy.ops.export_scene.gltf(
        filepath=outp,
        export_format='GLB',
        export_yup=True,
    )
    print("GROUNDED", outp, "dy=%.3f" % dy)

def main():
    post = sys.argv[sys.argv.index("--") + 1:]
    # pairs: inp outp inp outp ...
    for i in range(0, len(post), 2):
        ground(post[i], post[i + 1])

if __name__ == "__main__":
    main()
