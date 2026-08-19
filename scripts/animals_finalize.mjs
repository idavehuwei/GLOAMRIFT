#!/usr/bin/env node
// Quaternius Animated Animal Pack（~/Downloads/glTF 2）→ 兽形怪物 GLB。
// 动物动作名不同：run 用 Gallop，attack 用 Attack / Attack_Headbutt。
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import { NodeIO } from "@gltf-transform/core";
import { prune, dedup } from "@gltf-transform/functions";
const SRC = path.join(os.homedir(), "Downloads", "glTF 2");
const MODELS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "public", "assets", "models");
const io = new NodeIO();

// 目标资产 → [源文件, 攻击动作候选]
const JOBS = [
  ["mob_wolf",  "Wolf",  ["Attack"]],
  ["mob_boar",  "Bull",  ["Attack_Headbutt", "Attack_Kick"]],
  ["mob_husky", "Husky", ["Attack"]],
  ["mob_fox",   "Fox",   ["Attack"]],
  ["mob_stag",  "Stag",  ["Attack_Headbutt", "Attack_Kick"]],
];
const first = (byName, names) => names.find(n => byName.has(n));

for (const [asset, src, atkList] of JOBS) {
  const srcFile = path.join(SRC, src + ".gltf");
  if (!fs.existsSync(srcFile)) { console.warn("missing", srcFile); continue; }
  const doc = await io.read(srcFile);
  const root = doc.getRoot();
  const byName = new Map(root.listAnimations().map(a => [a.getName(), a]));
  const want = {
    idle: first(byName, ["Idle", "Idle_2"]),
    run: first(byName, ["Gallop", "Walk"]),
    attack: first(byName, [...atkList, "Attack"]),
    die: first(byName, ["Death"]),
  };
  const keep = new Set();
  for (const [rt, cn] of Object.entries(want)) {
    const a = cn && byName.get(cn);
    if (a) { a.setName(rt); keep.add(a); } else console.warn(`  ${asset}: no ${rt}`);
  }
  for (const a of root.listAnimations()) if (!keep.has(a)) a.dispose();
  await doc.transform(prune(), dedup());
  const out = path.join(MODELS, asset + ".glb");
  await io.write(out, doc);
  // 量一下包围盒高度，方便定 scale
  const b = fs.readFileSync(out); const j = JSON.parse(b.slice(20, 20 + b.readUInt32LE(12)).toString());
  let lo = 1e9, hi = -1e9;
  for (const m of j.meshes || []) for (const p of m.primitives || []) { const ac = j.accessors[p.attributes.POSITION]; if (ac?.min) { lo = Math.min(lo, ac.min[1]); hi = Math.max(hi, ac.max[1]); } }
  console.log(`${asset.padEnd(11)} <- ${src.padEnd(6)} ${(fs.statSync(out).size / 1048576).toFixed(2)}MB h=${(hi - lo).toFixed(2)} clips:[${doc.getRoot().listAnimations().map(a => a.getName()).join(",")}]`);
}
