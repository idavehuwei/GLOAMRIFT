#!/usr/bin/env node
// Blender 导出的小生物 GLB（/tmp/blend_export）→ 游戏怪物，改名 idle/run/attack/die。
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { NodeIO } from "@gltf-transform/core";
import { prune, dedup } from "@gltf-transform/functions";
const SRC = "/tmp/blend_export";
const MODELS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "public", "assets", "models");
const io = new NodeIO();

// 资产 → [源, {idle,run,attack,die}]
const JOBS = [
  ["mob_spider", "Spider", { idle: "Spider_Idle", run: "Spider_Walk", attack: "Spider_Attack", die: "Spider_Death" }],
  ["mob_rat",    "Rat",    { idle: "Rat_Idle",    run: "Rat_Run",     attack: "Rat_Attack",    die: "Rat_Death" }],
  ["mob_snake",  "Snake",  { idle: "Snake_Idle",  run: "Snake_Walk",  attack: "Snake_Attack",  die: "Snake_Death" }],
  ["mob_frog",   "Frog",   { idle: "Frog_Idle",   run: "Frog_Jump",   attack: "Frog_Attack",   die: "Frog_Death" }],
  ["mob_wasp",   "Wasp",   { idle: "Wasp_Flying", run: "Wasp_Flying", attack: "Wasp_Attack",   die: "Wasp_Death" }],
];

for (const [asset, src, want] of JOBS) {
  const srcFile = path.join(SRC, src + ".glb");
  if (!fs.existsSync(srcFile)) { console.warn("missing", srcFile); continue; }
  const doc = await io.read(srcFile);
  const root = doc.getRoot();
  const byName = new Map(root.listAnimations().map(a => [a.getName(), a]));
  const keep = new Set();
  // wasp 的 idle 与 run 同一条 clip，只能保留一份并改名 idle；run 再复制一份
  for (const [rt, cn] of Object.entries(want)) {
    const a = byName.get(cn);
    if (!a) { console.warn(`  ${asset}: no ${rt} (${cn})`); continue; }
    if (keep.has(a)) { const c = a.clone(); c.setName(rt); keep.add(c); }
    else { a.setName(rt); keep.add(a); }
  }
  for (const a of root.listAnimations()) if (!keep.has(a)) a.dispose();
  await doc.transform(prune(), dedup());
  const out = path.join(MODELS, asset + ".glb");
  await io.write(out, doc);
  const b = fs.readFileSync(out); const j = JSON.parse(b.slice(20, 20 + b.readUInt32LE(12)).toString());
  let lo = 1e9, hi = -1e9;
  for (const m of j.meshes || []) for (const p of m.primitives || []) { const ac = j.accessors[p.attributes.POSITION]; if (ac?.min) { lo = Math.min(lo, ac.min[1]); hi = Math.max(hi, ac.max[1]); } }
  console.log(`${asset.padEnd(11)} <- ${src.padEnd(6)} ${(fs.statSync(out).size / 1048576).toFixed(2)}MB h=${(hi - lo).toFixed(2)} clips:[${doc.getRoot().listAnimations().map(a => a.getName()).join(",")}]`);
}
