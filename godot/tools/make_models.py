#!/usr/bin/env python3
"""Copy GLBs into godot/models/src and emit one .tscn per model.

Run from repo:  python3 godot/tools/make_models.py
Wrappers instance the GLB so you can swap a model by editing its tscn.
Procedural placeholders (box people, loot, trees, houses) are also tscn.
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUB = ROOT / "public" / "assets"
DST = ROOT / "godot" / "models"
SRC = DST / "src"
MANIFEST = PUB / "assets.json"


def col(h: int, a: float = 1.0) -> str:
    r = ((h >> 16) & 255) / 255.0
    g = ((h >> 8) & 255) / 255.0
    b = (h & 255) / 255.0
    return f"Color({r:.5f}, {g:.5f}, {b:.5f}, {a:.5f})"


def xf(x=0.0, y=0.0, z=0.0, sx=1.0, sy=1.0, sz=1.0) -> str:
    return (
        f"Transform3D({sx:.5f}, 0, 0, 0, {sy:.5f}, 0, 0, 0, {sz:.5f}, "
        f"{x:.5f}, {y:.5f}, {z:.5f})"
    )


class Scene:
    def __init__(self, name: str):
        self.name = name
        self.subs: list[str] = []
        self.nodes: list[str] = []
        self.ext: list[str] = []
        self._i = 0

    def sid(self, prefix: str) -> str:
        self._i += 1
        return f"{prefix}_{self._i}"

    def add_ext(self, typ: str, path: str) -> str:
        i = len(self.ext) + 1
        eid = f"{i}_src"
        self.ext.append(f'[ext_resource type="{typ}" path="{path}" id="{eid}"]')
        return eid

    def sub(self, typ: str, body: str) -> str:
        i = self.sid(typ.replace("3D", "").replace("Mesh", "M"))
        self.subs.append(f'[sub_resource type="{typ}" id="{i}"]\n{body}')
        return i

    def box_mesh(self, size) -> str:
        return self.sub("BoxMesh", f"size = Vector3({size[0]}, {size[1]}, {size[2]})")

    def sph_mesh(self, r: float, h: float, seg=8, rings=4) -> str:
        return self.sub(
            "SphereMesh",
            f"radius = {r}\nheight = {h}\nradial_segments = {seg}\nrings = {rings}",
        )

    def cyl_mesh(self, top: float, bot: float, h: float, seg=8) -> str:
        return self.sub(
            "CylinderMesh",
            f"top_radius = {top}\nbottom_radius = {bot}\nheight = {h}\nradial_segments = {seg}",
        )

    def mat(self, hex_color: int, unshaded=False, emit=0.0, alpha=1.0) -> str:
        lines = [f"albedo_color = {col(hex_color, alpha)}"]
        if unshaded:
            lines.append("shading_mode = 0")
        if alpha < 1:
            lines.append("transparency = 1")
        if emit:
            lines.append("emission_enabled = true")
            lines.append(f"emission = {col(hex_color)}")
            lines.append(f"emission_energy_multiplier = {emit}")
        return self.sub("StandardMaterial3D", "\n".join(lines))

    def mesh_node(self, name: str, parent: str, mesh_id: str, mat_id: str, transform: str):
        p = "." if parent == self.name else parent
        self.nodes.append(
            f'[node name="{name}" type="MeshInstance3D" parent="{p}"]\n'
            f"transform = {transform}\n"
            f'mesh = SubResource("{mesh_id}")\n'
            f'material_override = SubResource("{mat_id}")'
        )

    def box(self, name: str, parent: str, size, pos, hex_color: int, rot_x=0.0, rot_z=0.0, emit=0.0):
        mid = self.box_mesh(size)
        mat = self.mat(hex_color, emit=emit)
        # rotation via basis: skip complex euler, use extra MeshInstance rotation property
        xf_s = xf(pos[0], pos[1], pos[2])
        p = "." if parent == self.name else parent
        extra = ""
        if rot_x or rot_z:
            extra = f"\nrotation = Vector3({rot_x}, 0, {rot_z})"
        self.nodes.append(
            f'[node name="{name}" type="MeshInstance3D" parent="{p}"]\n'
            f"transform = {xf_s}{extra}\n"
            f'mesh = SubResource("{mid}")\n'
            f'material_override = SubResource("{mat}")'
        )

    def write(self, path: Path):
        load_steps = 1 + len(self.ext) + len(self.subs)
        parts = [f"[gd_scene load_steps={load_steps} format=3]", ""]
        parts.extend(self.ext)
        if self.ext:
            parts.append("")
        for s in self.subs:
            parts.append(s)
            parts.append("")
        parts.append(f'[node name="{self.name}" type="Node3D"]')
        parts.append("")
        parts.extend(n + "\n" for n in self.nodes)
        path.write_text("\n".join(parts).rstrip() + "\n")


def copy_glbs() -> list[tuple[str, Path, Path]]:
    SRC.mkdir(parents=True, exist_ok=True)
    out = []
    for folder in ("models", "props"):
        d = PUB / folder
        if not d.is_dir():
            continue
        for glb in sorted(d.glob("*.glb")):
            dest = SRC / glb.name
            shutil.copy2(glb, dest)
            out.append((glb.stem, glb, dest))
    return out


def wrap_glb(stem: str, scale: float, y_off: float):
    sc = Scene(stem)
    eid = sc.add_ext("PackedScene", f"res://models/src/{stem}.glb")
    sc.nodes.append(
        f'[node name="Model" parent="." instance=ExtResource("{eid}")]\n'
        f"transform = {xf(0, y_off, 0, scale, scale, scale)}"
    )
    sc.write(DST / f"{stem}.tscn")


def make_fallback_human():
    sc = Scene("fallback_human")
    parts = [
        ("Body", (0.72, 0.86, 0.44), (0, 1.16, 0), 0x6B3230),
        ("Head", (0.46, 0.44, 0.44), (0, 1.79, 0), 0xC39A72),
        ("ArmL", (0.22, 0.72, 0.24), (-0.5, 1.2, 0), 0xC39A72),
        ("ArmR", (0.22, 0.72, 0.24), (0.5, 1.2, 0), 0xC39A72),
        ("LegL", (0.26, 0.74, 0.28), (-0.19, 0.37, 0), 0x35302C),
        ("LegR", (0.26, 0.74, 0.28), (0.19, 0.37, 0), 0x35302C),
    ]
    for n, size, pos, h in parts:
        sc.box(n, sc.name, size, pos, h)
    mid = sc.sph_mesh(0.55, 0.04, 12, 4)
    mat = sc.mat(0x000000, alpha=0.4)
    sc.mesh_node("Shadow", sc.name, mid, mat, xf(0, 0.02, 0))
    sc.write(DST / "fallback_human.tscn")


def make_fallback_beast():
    sc = Scene("fallback_beast")
    sc.box("Body", sc.name, (1.15, 0.6, 0.6), (0, 0.78, 0), 0x6A6258)
    sc.box("Head", sc.name, (0.46, 0.4, 0.52), (0, 0.92, 0.78), 0x8A8278)
    for i, p in enumerate([(-0.34, 0.35, 0.34), (0.34, 0.35, 0.34), (-0.34, 0.35, -0.34), (0.34, 0.35, -0.34)]):
        sc.box(f"Leg{i}", sc.name, (0.19, 0.62, 0.2), p, 0x4A443C)
    mid = sc.sph_mesh(0.55, 0.04, 12, 4)
    mat = sc.mat(0x000000, alpha=0.4)
    sc.mesh_node("Shadow", sc.name, mid, mat, xf(0, 0.02, 0))
    sc.write(DST / "fallback_beast.tscn")


def make_fallback_box():
    sc = Scene("fallback_box")
    sc.box("Box", sc.name, (0.85, 0.55, 0.7), (0, 0.28, 0), 0xB8943A)
    sc.write(DST / "fallback_box.tscn")


def make_fx():
    sc = Scene("fx_loot_gold")
    mid = sc.sph_mesh(0.2, 0.4, 7, 5)
    mat = sc.mat(0xF5C451, unshaded=True, emit=0.4)
    for i, p in enumerate([(-0.12, 0.22, 0.05), (0.1, 0.26, -0.08), (0.0, 0.2, 0.12)]):
        sc.mesh_node(f"Coin{i}", sc.name, mid, mat, xf(*p))
    sc.write(DST / "fx_loot_gold.tscn")

    sc = Scene("fx_loot_potion")
    mid = sc.cyl_mesh(0.13, 0.17, 0.4, 7)
    mat = sc.mat(0xD8342A, unshaded=True)
    sc.mesh_node("Bottle", sc.name, mid, mat, xf(0, 0.22, 0))
    sc.write(DST / "fx_loot_potion.tscn")

    sc = Scene("fx_loot_item")
    mid = sc.box_mesh((0.34, 0.34, 0.34))
    mat = sc.mat(0xC8C0AD, unshaded=True, emit=0.35)
    sc.mesh_node("Cube", sc.name, mid, mat, xf(0, 0.32, 0))
    bid = sc.cyl_mesh(0.06, 0.06, 2.4, 8)
    bmat = sc.mat(0xC8C0AD, unshaded=True, alpha=0.35)
    sc.mesh_node("Beam", sc.name, bid, bmat, xf(0, 1.3, 0))
    sc.nodes.append(
        '[node name="Light" type="OmniLight3D" parent="."]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)\n"
        f"light_color = {col(0xC8C0AD)}\n"
        "light_energy = 0.9\n"
        "omni_range = 4.5"
    )
    sc.write(DST / "fx_loot_item.tscn")

    sc = Scene("fx_proj_orb")
    mid = sc.sph_mesh(0.24, 0.48, 12, 6)
    mat = sc.mat(0xFF6A2A, unshaded=True, emit=1.0)
    sc.mesh_node("Ball", sc.name, mid, mat, xf())
    sc.nodes.append(
        '[node name="Light" type="OmniLight3D" parent="."]\n'
        f"light_color = {col(0xFF6A2A)}\n"
        "light_energy = 1.0\n"
        "omni_range = 7.0"
    )
    sc.write(DST / "fx_proj_orb.tscn")

    sc = Scene("fx_proj_arrow")
    mid = sc.box_mesh((0.07, 0.07, 0.9))
    mat = sc.mat(0xFFE6A0, unshaded=True, emit=1.0)
    sc.mesh_node("Shaft", sc.name, mid, mat, xf())
    sc.write(DST / "fx_proj_arrow.tscn")

    sc = Scene("fx_mark")
    mid = sc.cyl_mesh(0.9, 0.9, 0.12, 16)
    mat = sc.mat(0xD8C15C, unshaded=True, emit=0.8, alpha=0.55)
    sc.mesh_node("Disc", sc.name, mid, mat, xf(0, 0.08, 0))
    sc.write(DST / "fx_mark.tscn")


def make_world():
    # unit house, footprint 4 x 4
    bw, bd = 4.0, 4.0
    sc = Scene("world_house")
    boxes = [
        ("Plinth", (bw + 0.4, 0.38, bd + 0.4), (0, 0.19, 0), 0x6A6258, 0, 0),
        ("Walls", (bw, 2.85, bd), (0, 1.78, 0), 0x8A7A62, 0, 0),
        ("BeamN", (bw + 0.06, 0.14, 0.16), (0, 2.35, bd / 2 + 0.03), 0x4A3424, 0, 0),
        ("BeamS", (bw + 0.06, 0.14, 0.16), (0, 2.35, -bd / 2 - 0.03), 0x4A3424, 0, 0),
        ("BeamW", (0.16, 0.14, bd + 0.06), (-bw / 2 - 0.03, 2.35, 0), 0x4A3424, 0, 0),
        ("BeamE", (0.16, 0.14, bd + 0.06), (bw / 2 + 0.03, 2.35, 0), 0x4A3424, 0, 0),
        ("RoofA", (bw + 0.95, 0.16, (bd + 0.55) * 0.58), (0, 3.72, -(bd + 0.55) * 0.22), 0x5A2A22, 0.52, 0),
        ("RoofB", (bw + 0.95, 0.16, (bd + 0.55) * 0.58), (0, 3.72, (bd + 0.55) * 0.22), 0x5A2A22, -0.52, 0),
        ("Ridge", (bw + 1.05, 0.1, 0.14), (0, 4.22, 0), 0x4A3424, 0, 0),
        ("Chimney", (0.5, 1.45, 0.5), (bw * 0.26, 4.55, -bd * 0.18), 0x5A4A40, 0, 0),
        ("ChimCap", (0.62, 0.12, 0.62), (bw * 0.26, 5.3, -bd * 0.18), 0x3A322C, 0, 0),
        ("Step", (1.7, 0.16, 0.55), (0, 0.1, bd / 2 + 0.28), 0x6A6258, 0, 0),
        ("DoorFrame", (1.25, 1.85, 0.12), (0, 1.05, bd / 2 + 0.05), 0x4A3424, 0, 0),
        ("Door", (0.92, 1.62, 0.1), (0, 0.98, bd / 2 + 0.12), 0x3A2416, 0, 0),
        ("Knob", (0.06, 0.06, 0.08), (0.32, 1.0, bd / 2 + 0.18), 0xC4A15A, 0, 0),
    ]
    for i, c in enumerate([(-1, -1), (1, -1), (-1, 1), (1, 1)]):
        boxes.append((
            f"Post{i}",
            (0.2, 3.05, 0.2),
            (c[0] * (bw / 2 - 0.08), 1.72, c[1] * (bd / 2 - 0.08)),
            0x4A3424, 0, 0,
        ))
    for i, ox in enumerate((-0.34, 0.34)):
        boxes.append((f"WinF{i}", (0.82, 0.82, 0.12), (ox * bw, 2.18, bd / 2 + 0.06), 0x4A3424, 0, 0))
        boxes.append((f"WinG{i}", (0.58, 0.58, 0.08), (ox * bw, 2.18, bd / 2 + 0.12), 0xFFD088, 0, 0))
    for n, size, pos, h, rx, _rz in boxes:
        sc.box(n, sc.name, size, pos, h, rot_x=rx, emit=0.35 if h == 0xFFD088 else 0.0)
    sc.write(DST / "world_house.tscn")

    sc = Scene("world_tree")
    t = sc.cyl_mesh(0.18, 0.32, 3.1, 7)
    tm = sc.mat(0x4A3520)
    sc.mesh_node("Trunk", sc.name, t, tm, xf(0, 1.55, 0))
    l1 = sc.cyl_mesh(0.0, 1.45, 2.6, 8)
    lm = sc.mat(0x285228)
    sc.mesh_node("Leaf1", sc.name, l1, lm, xf(0, 3.05, 0))
    l2 = sc.cyl_mesh(0.0, 1.05, 2.1, 8)
    sc.mesh_node("Leaf2", sc.name, l2, lm, xf(0, 4.15, 0))
    sc.write(DST / "world_tree.tscn")

    sc = Scene("world_bush")
    m = sc.sph_mesh(0.55, 1.1, 6, 4)
    mat = sc.mat(0x1E4720)
    sc.mesh_node("Bush", sc.name, m, mat, xf(0, 0.42, 0))
    sc.write(DST / "world_bush.tscn")

    sc = Scene("world_log")
    m = sc.cyl_mesh(0.16, 0.2, 2.8, 7)
    mat = sc.mat(0x3A2A18)
    sc.mesh_node("Log", sc.name, m, mat, xf(0, 0.18, 0))
    sc.nodes[-1] += "\nrotation = Vector3(0, 0, 1.5708)"
    sc.write(DST / "world_log.tscn")

    sc = Scene("world_rock")
    m = sc.sph_mesh(1.05, 2.1, 8, 4)
    mat = sc.mat(0x6B6150)
    sc.mesh_node("Rock", sc.name, m, mat, xf(0, 0.7, 0))
    sc.write(DST / "world_rock.tscn")

    sc = Scene("world_pebble")
    m = sc.sph_mesh(0.38, 0.76, 8, 4)
    mat = sc.mat(0x5C5448)
    sc.mesh_node("Pebble", sc.name, m, mat, xf(0, 0.16, 0))
    sc.write(DST / "world_pebble.tscn")

    sc = Scene("world_grass")
    m = sc.box_mesh((0.08, 0.55, 0.08))
    mat = sc.mat(0x615C33)
    sc.mesh_node("Blade", sc.name, m, mat, xf(0, 0.28, 0))
    sc.write(DST / "world_grass.tscn")

    sc = Scene("world_spire")
    m = sc.cyl_mesh(0.0, 1.05, 4.4, 6)
    mat = sc.mat(0x522618)
    sc.mesh_node("Spire", sc.name, m, mat, xf(0, 2.2, 0))
    sc.write(DST / "world_spire.tscn")

    sc = Scene("world_shard")
    m = sc.cyl_mesh(0.0, 0.45, 2.2, 5)
    mat = sc.mat(0x662E24)
    sc.mesh_node("Shard", sc.name, m, mat, xf(0, 1.1, 0))
    sc.write(DST / "world_shard.tscn")

    sc = Scene("world_glow")
    m = sc.cyl_mesh(1.6, 1.6, 0.04, 12)
    mat = sc.mat(0xFF591F, unshaded=True, emit=1.0, alpha=0.62)
    sc.mesh_node("Glow", sc.name, m, mat, xf(0, 0.05, 0))
    sc.write(DST / "world_glow.tscn")

    sc = Scene("world_icicle")
    a = sc.cyl_mesh(0.22, 0.38, 3.6, 7)
    am = sc.mat(0xC8D8E8)
    sc.mesh_node("Shaft", sc.name, a, am, xf(0, 1.8, 0))
    b = sc.cyl_mesh(0.0, 0.55, 1.1, 7)
    sc.mesh_node("Cap", sc.name, b, am, xf(0, 3.55, 0))
    c = sc.sph_mesh(0.7, 1.4, 8, 4)
    sc.mesh_node("Mound", sc.name, c, am, xf(0, 0.28, 0))
    sc.write(DST / "world_icicle.tscn")

    sc = Scene("world_wreck")
    m = sc.box_mesh((0.18, 1.8, 2.4))
    mat = sc.mat(0x514026)
    sc.mesh_node("Rib", sc.name, m, mat, xf(0, 0.9, 0))
    sc.write(DST / "world_wreck.tscn")

    sc = Scene("world_mast")
    m = sc.cyl_mesh(0.08, 0.12, 3.4, 6)
    mat = sc.mat(0x4A3A28)
    sc.mesh_node("Mast", sc.name, m, mat, xf(0, 1.6, 0))
    sc.write(DST / "world_mast.tscn")

    sc = Scene("world_wall")
    m = sc.box_mesh((2.0, 4.4, 2.0))
    mat = sc.mat(0x3A3630)
    sc.mesh_node("Wall", sc.name, m, mat, xf(0, 2.2, 0))
    sc.write(DST / "world_wall.tscn")

    sc = Scene("world_wall_cap")
    m = sc.box_mesh((2.12, 0.22, 2.12))
    mat = sc.mat(0x4A443C)
    sc.mesh_node("Cap", sc.name, m, mat, xf(0, 0.11, 0))
    sc.write(DST / "world_wall_cap.tscn")

    sc = Scene("world_column")
    m = sc.box_mesh((0.55, 5.2, 0.55))
    mat = sc.mat(0x2A2622)
    sc.mesh_node("Col", sc.name, m, mat, xf(0, 2.6, 0))
    sc.write(DST / "world_column.tscn")

    landmarks = {
        "world_landmark_waste": [
            ((2.4, 0.5, 2.4), (0, 0.25, 0), 0x6A6258, 0),
            ((1.8, 3.6, 1.8), (0, 2.1, 0), 0x5A5248, 0),
            ((1.2, 1.4, 0.4), (0.9, 3.9, 0), 0x4A443C, 0.4),
        ],
        "world_landmark_wood": [
            ((0.35, 1.1, 0.35), (3.2, 0.55, 0), 0x4A4034, 0),
            ((0.35, 1.1, 0.35), (1.6, 0.55, 2.77), 0x4A4034, 0),
            ((0.35, 1.1, 0.35), (-1.6, 0.55, 2.77), 0x4A4034, 0),
            ((0.35, 1.1, 0.35), (-3.2, 0.55, 0), 0x4A4034, 0),
            ((0.35, 1.1, 0.35), (-1.6, 0.55, -2.77), 0x4A4034, 0),
            ((0.35, 1.1, 0.35), (1.6, 0.55, -2.77), 0x4A4034, 0),
        ],
        "world_landmark_ash": [
            ((4.2, 0.5, 0.6), (0, 3.4, 0), 0x4A3028, 0),
            ((0.55, 3.4, 0.55), (-1.8, 1.7, 0), 0x3A2420, 0),
            ((0.55, 3.4, 0.55), (1.8, 1.7, 0), 0x3A2420, 0),
        ],
        "world_landmark_frost": [
            ((0.45, 4.2, 0.45), (0, 2.2, 0), 0xC8D8E8, 0.3),
            ((0.45, 4.6, 0.45), (2.2, 2.2, -1.4), 0xC8D8E8, 0.3),
            ((0.45, 5.0, 0.45), (4.4, 2.2, -2.8), 0xC8D8E8, 0.3),
        ],
        "world_landmark_shore": [
            ((5.5, 1.1, 1.8), (0, 0.7, 0), 0x3A2A1C, 0.18),
            ((0.16, 4.2, 0.16), (0, 2.0, 0), 0x4A3A28, 0.35),
        ],
        "world_landmark_sinkf": [
            ((1.1, 4.6, 1.1), (0, 2.3, 0), 0x3A3238, 0),
            ((2.2, 0.35, 2.2), (0, 4.7, 0), 0x2A2228, 0),
        ],
        "world_landmark_shaft": [
            ((0.4, 6.2, 0.4), (0, 3.1, 0), 0x6A5A50, 0),
            ((0.9, 0.22, 0.9), (0, 6.3, 0), 0x8A7A70, 0),
        ],
    }
    for name, boxes in landmarks.items():
        sc = Scene(name)
        for i, (size, pos, h, rz) in enumerate(boxes):
            sc.box(f"P{i}", sc.name, size, pos, h, rot_z=rz)
        sc.write(DST / f"{name}.tscn")

    for name, size, pos in (
        ("world_stash", (1.25, 0.7, 0.8), (0, 0.38, 0)),
        ("world_board", (0.12, 1.35, 1.55), (0.18, 1.45, 0)),
        ("world_waystone", (0.7, 2.4, 0.7), (0, 1.2, 0)),
    ):
        sc = Scene(name)
        sc.box("Mesh", sc.name, size, pos, 0xB08D4F)
        sc.write(DST / f"{name}.tscn")


def main():
    DST.mkdir(parents=True, exist_ok=True)
    meta = {}
    if MANIFEST.exists():
        meta = json.loads(MANIFEST.read_text())
    copied = copy_glbs()
    for stem, _src, _dest in copied:
        entry = meta.get(stem, {})
        wrap_glb(stem, float(entry.get("scale", 1.0)), float(entry.get("yOffset", 0.0)))
    make_fallback_human()
    make_fallback_beast()
    make_fallback_box()
    make_fx()
    make_world()
    n = len(list(DST.glob("*.tscn")))
    print(f"models: {len(copied)} glb copied, {n} tscn written → {DST}")


if __name__ == "__main__":
    main()
