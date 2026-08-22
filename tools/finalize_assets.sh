#!/bin/bash
# Finalize hy-3d output into game-ready GLBs.
# Monsters: rig + animate (idle/run/attack/die). Buildings: copy as static.
set -e
BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
ROOT=/Users/weihu/AI/ShadowDepths
OUT=$ROOT/tools/hy3d_out
SRC=$ROOT/godot/models/src
RIG=$ROOT/tools/rig_monster.py

for m in golem treant wraith; do
  IN="$OUT/${m}_lowpoly.glb"
  if [ -f "$IN" ]; then
    echo "=== rig monster: $m ==="
    "$BLENDER" --background --python "$RIG" -- "$IN" "$SRC/mob_${m}.glb" 2>&1 | tail -3
  else
    echo "MISSING $IN"
  fi
done

for b in world_tower world_shrine; do
  IN="$OUT/${b}_lowpoly.glb"
  if [ -f "$IN" ]; then
    cp "$IN" "$SRC/${b}.glb"
    echo "copied building: $b"
  else
    echo "MISSING $IN"
  fi
done

echo "=== validate ==="
python3 "$ROOT/tools/validate_glb.py"
