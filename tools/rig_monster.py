#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rig a hy-3d static LowPoly GLB into a skinned + animated monster GLB.

Pipeline (matches the project's proven nearest-bone skinning approach):
 1. import GLB, apply transforms
 2. build a generic biped armature sized to the mesh bbox
 3. nearest-bone rigid skinning (each vertex -> nearest bone head, weight 1.0)
 4. author 4 NLA clips: idle / run / attack / die
 5. export GLB with skins + Y-up + animations

Usage (Blender headless):
  Blender --background --python rig_monster.py -- <in.glb> <out.glb>
"""
import bpy
import sys
import math


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def main():
    argv = sys.argv
    # Blender puts its own args before '--', our args after
    if "--" in argv:
        post = argv[argv.index("--") + 1:]
    else:
        post = argv[1:]
    src, dst = post[0], post[1]

    clear_scene()
    bpy.ops.import_scene.gltf(filepath=src)

    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    if not meshes:
        print("NO MESH in", src)
        return

    # Apply transforms so local == world
    for m in meshes:
        bpy.context.view_layer.objects.active = m
        m.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        m.select_set(False)

    # Combined bbox
    minx = miny = minz = 1e9
    maxx = maxy = maxz = -1e9
    for m in meshes:
        for v in m.data.vertices:
            p = m.matrix_world @ v.co
            minx = min(minx, p.x); maxx = max(maxx, p.x)
            miny = min(miny, p.y); maxy = max(maxy, p.y)
            minz = min(minz, p.z); maxz = max(maxz, p.z)
    W = maxx - minx
    H = maxy - miny
    D = maxz - minz
    cx = (minx + maxx) / 2.0
    cz = (minz + maxz) / 2.0

    # Recenter horizontally around origin
    for m in meshes:
        m.location.x -= cx
        m.location.z -= cz

    # ---- Armature ----
    arm = bpy.data.armatures.new('Arm')
    arm_obj = bpy.data.objects.new('Armature', arm)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj

    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones

    def add(name, head, tail, parent=None):
        b = eb.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = eb[parent]
        return b

    hips_y = 0.50 * H
    spine_y = 0.62 * H
    chest_y = 0.72 * H
    neck_y = ter_y = 0.82 * H
    head_y = 0.90 * H
    sh_y = 0.70 * H
    el_y = 0.55 * H
    hip_y = 0.50 * H
    kn_y = 0.25 * H
    halfW = 0.32 * W
    legW = 0.20 * W

    add('hips',  (0, hips_y, 0),       (0, hips_y + 0.06, 0))
    add('spine', (0, spine_y, 0),      (0, spine_y + 0.06, 0), 'hips')
    add('chest', (0, chest_y, 0),      (0, chest_y + 0.06, 0), 'spine')
    add('neck',  (0, neck_y, 0),       (0, neck_y + 0.04, 0), 'chest')
    add('head',  (0, head_y, 0),       (0, head_y + 0.14, 0), 'neck')
    add('shL', (-halfW, sh_y, 0),  (-halfW * 1.3, sh_y - 0.03, 0), 'chest')
    add('elL', (-halfW * 1.3, el_y, 0), (-halfW * 1.5, el_y - 0.06, 0), 'shL')
    add('shR', ( halfW, sh_y, 0),  ( halfW * 1.3, sh_y - 0.03, 0), 'chest')
    add('elR', ( halfW * 1.3, el_y, 0), ( halfW * 1.5, el_y - 0.06, 0), 'shR')
    add('hipL', (-legW, hip_y, 0),  (-legW * 1.1, hip_y - 0.06, 0), 'hips')
    add('knL',  (-legW * 1.1, kn_y, 0), (-legW * 1.15, kn_y - 0.06, 0), 'hipL')
    add('hipR', ( legW, hip_y, 0),  ( legW * 1.1, hip_y - 0.06, 0), 'hips')
    add('knR',  ( legW * 1.1, kn_y, 0), ( legW * 1.15, kn_y - 0.06, 0), 'hipR')

    bpy.ops.object.mode_set(mode='OBJECT')

    bone_heads = {name: arm_obj.matrix_world @ b.head for name, b in [(b.name, b) for b in arm.bones]}

    # ---- Nearest-bone skinning ----
    for m in meshes:
        for name in bone_heads:
            if name not in m.vertex_groups:
                m.vertex_groups.new(name=name)
        for vi, v in enumerate(m.data.vertices):
            p = m.matrix_world @ v.co
            best = None
            bestd = 1e18
            for name, h in bone_heads.items():
                d = (p - h).length_squared
                if d < bestd:
                    bestd = d
                    best = name
            m.vertex_groups[best].add([vi], 1.0, 'REPLACE')
        mod = m.modifiers.new('Armature', 'ARMATURE')
        mod.object = arm_obj

    # ---- Animations ----
    bpy.context.view_layer.objects.active = arm_obj
    if arm_obj.animation_data is None:
        arm_obj.animation_data_create()
    pb = arm_obj.pose.bones
    scene = bpy.context.scene
    scene.render.fps = 30

    def rot(bone, xyz):
        pb[bone].rotation_mode = 'XYZ'
        pb[bone].rotation_euler = xyz

    def kf_rot(bone, frame):
        pb[bone].keyframe_insert("rotation_euler", frame=frame)

    def kf_loc(bone, frame):
        pb[bone].keyframe_insert("location", frame=frame)

    actions = []

    # idle (loop ~30f)
    a = bpy.data.actions.new("idle")
    arm_obj.animation_data.action = a
    rot('chest', (0, 0, 0)); kf_rot('chest', 1)
    rot('head', (0, 0, 0)); kf_rot('head', 1)
    rot('shL', (0, 0, 0)); kf_rot('shL', 1)
    rot('shR', (0, 0, 0)); kf_rot('shR', 1)
    rot('chest', (0.05, 0, 0)); rot('head', (0.03, 0, 0)); rot('shL', (0, 0, 0.03)); rot('shR', (0, 0, -0.03))
    kf_rot('chest', 15); kf_rot('head', 15); kf_rot('shL', 15); kf_rot('shR', 15)
    rot('chest', (0, 0, 0)); rot('head', (0, 0, 0)); rot('shL', (0, 0, 0)); rot('shR', (0, 0, 0))
    kf_rot('chest', 30); kf_rot('head', 30); kf_rot('shL', 30); kf_rot('shR', 30)
    actions.append(a)

    # run (loop ~18f)
    a = bpy.data.actions.new("run")
    arm_obj.animation_data.action = a
    # neutral
    for b in ['hipL', 'knL', 'hipR', 'knR', 'shL', 'shR', 'chest']:
        rot(b, (0, 0, 0)); kf_rot(b, 1)
    # phase A: left forward, right back
    rot('hipL', (0.6, 0, 0)); rot('knL', (-0.4, 0, 0)); rot('hipR', (-0.4, 0, 0)); rot('shL', (0.3, 0, 0)); rot('shR', (-0.3, 0, 0))
    kf_rot('hipL', 6); kf_rot('knL', 6); kf_rot('hipR', 6); kf_rot('shL', 6); kf_rot('shR', 6)
    # phase B: opposite
    rot('hipL', (-0.4, 0, 0)); rot('knL', (0.0, 0, 0)); rot('hipR', (0.6, 0, 0)); rot('knR', (-0.4, 0, 0)); rot('shL', (-0.3, 0, 0)); rot('shR', (0.3, 0, 0))
    kf_rot('hipL', 12); kf_rot('knL', 12); kf_rot('hipR', 12); kf_rot('knR', 12); kf_rot('shL', 12); kf_rot('shR', 12)
    # back to neutral
    for b in ['hipL', 'knL', 'hipR', 'knR', 'shL', 'shR']:
        rot(b, (0, 0, 0)); kf_rot(b, 18)
    actions.append(a)

    # attack (non-loop ~16f)  -- right arm overhead slam
    a = bpy.data.actions.new("attack")
    arm_obj.animation_data.action = a
    rot('shR', (0, 0, 0)); rot('elR', (0, 0, 0)); rot('chest', (0, 0, 0)); kf_rot('shR', 1); kf_rot('elR', 1); kf_rot('chest', 1)
    rot('shR', (-1.2, 0, 0)); rot('elR', (-0.7, 0, 0)); kf_rot('shR', 5); kf_rot('elR', 5)
    rot('shR', (0.9, 0, 0)); rot('elR', (0.5, 0, 0)); rot('chest', (0.2, 0, 0)); kf_rot('shR', 10); kf_rot('elR', 10); kf_rot('chest', 10)
    rot('shR', (0, 0, 0)); rot('elR', (0, 0, 0)); rot('chest', (0, 0, 0)); kf_rot('shR', 16); kf_rot('elR', 16); kf_rot('chest', 16)
    actions.append(a)

    # die (non-loop ~40f) -- collapse forward
    a = bpy.data.actions.new("die")
    arm_obj.animation_data.action = a
    pb['hips'].location = (0, 0, 0); kf_loc('hips', 1); rot('hips', (0, 0, 0)); kf_rot('hips', 1); rot('chest', (0, 0, 0)); kf_rot('chest', 1)
    rot('hips', (0.8, 0, 0)); rot('chest', (0.4, 0, 0)); kf_rot('hips', 20); kf_rot('chest', 20)
    pb['hips'].location = (0, -0.30, 0); kf_loc('hips', 40)
    rot('hips', (1.4, 0, 0)); rot('chest', (0.9, 0, 0)); kf_rot('hips', 40); kf_rot('chest', 40)
    actions.append(a)

    # ---- NLA tracks (so exporter emits named animations) ----
    arm_obj.animation_data.action = None
    for a in actions:
        track = arm_obj.animation_data.nla_tracks.new()
        track.name = a.name
        track.strips.new(a.name, 1, a)

    # ---- Export ----
    bpy.ops.export_scene.gltf(
        filepath=dst,
        export_format='GLB',
        export_skins=True,
        export_yup=True,
        export_animations=True,
        export_animation_mode='NLA_TRACKS',
    )
    print("RIGGED_AND_EXPORTED", dst)


if __name__ == "__main__":
    main()
