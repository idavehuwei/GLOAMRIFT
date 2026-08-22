#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validate the finalized game GLBs: monsters must be skinned + have 4 anims."""
import json
import struct
import os

SRC = "/Users/weihu/AI/ShadowDepths/godot/models/src"
MON = ["golem", "treant", "wraith"]
BLD = ["world_tower", "world_shrine"]


def glb_json(path):
    with open(path, "rb") as f:
        if f.read(4) != b"glTF":
            return None
        f.read(4)
        f.read(4)
        clen = struct.unpack("<I", f.read(4))[0]
        f.read(4)
        return json.loads(f.read(clen).decode("utf-8"))


ok = True
for m in MON:
    p = f"{SRC}/mob_{m}.glb"
    if not os.path.exists(p):
        print(f"[FAIL] mob_{m}.glb missing")
        ok = False
        continue
    j = glb_json(p)
    if j is None:
        print(f"[FAIL] mob_{m}.glb not glTF")
        ok = False
        continue
    anims = [a.get("name", "") for a in j.get("animations", [])]
    skins = len(j.get("skins", []))
    bones = len([n for n in j.get("nodes", [])])
    need = {"idle", "run", "attack", "die"}
    have = set(a.lower() for a in anims)
    miss = need - have
    status = "OK" if (skins >= 1 and not miss) else "FAIL"
    if status == "FAIL":
        ok = False
    print(f"[{status}] mob_{m}: skins={skins} anims={anims} missing={sorted(miss)}")

for b in BLD:
    p = f"{SRC}/{b}.glb"
    if not os.path.exists(p):
        print(f"[FAIL] {b}.glb missing")
        ok = False
        continue
    j = glb_json(p)
    meshes = len(j.get("meshes", [])) if j else 0
    print(f"[OK] {b}: meshes={meshes}")

print("ALL_OK" if ok else "HAS_FAILURES")
