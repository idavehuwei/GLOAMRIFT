#!/usr/bin/env node
// 把 KayKit 角色 GLB（76 段动画）削成游戏用的 4 段，并改名 idle/run/attack/die。
// KayKit 是 CC0，纯 glTF（无 meshopt），three r128 可直接加载。
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { NodeIO } from "@gltf-transform/core";
import { prune, dedup } from "@gltf-transform/functions";
const MODELS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "public", "assets", "models");
const io = new NodeIO();

// 每个职业：运行时名 → KayKit clip 名
const MAP = {
  char_warrior: { idle: "Idle", run: "Running_A", attack: "1H_Melee_Attack_Chop", die: "Death_A" },
  char_mage:    { idle: "Idle", run: "Running_A", attack: "Spellcast_Shoot",       die: "Death_A" },
  char_archer:  { idle: "Idle", run: "Running_A", attack: "1H_Ranged_Shoot",       die: "Death_A" },
  // 怪物（KayKit 同套骨骼/动画名）
  mob_skeleton: { idle: "Idle", run: "Running_A", attack: "1H_Melee_Attack_Chop", die: "Death_A" },
  mob_ghoul:    { idle: "Idle", run: "Running_A", attack: "1H_Melee_Attack_Chop", die: "Death_A" },
  mob_bandit:   { idle: "Idle", run: "Running_A", attack: "1H_Melee_Attack_Chop", die: "Death_A" },
  mob_skelrogue:{ idle: "Idle", run: "Running_A", attack: "1H_Ranged_Shoot",      die: "Death_A" },
  boss_sekhra:  { idle: "Idle", run: "Running_A", attack: "Spellcast_Shoot",       die: "Death_A" },
  npc_rogue:    { idle: "Idle", run: "Running_A", attack: "1H_Melee_Attack_Chop", die: "Death_A" },
};

for (const [id, wanted] of Object.entries(MAP)) {
  const file = path.join(MODELS, id + ".glb");
  if (!fs.existsSync(file)) { console.warn("missing", file); continue; }
  const before = (fs.statSync(file).size / 1048576).toFixed(2);
  const doc = await io.read(file);
  const root = doc.getRoot();
  const byName = new Map(root.listAnimations().map(a => [a.getName(), a]));
  // 幂等：已经削过（有 idle 且动画很少）就跳过，避免二次运行把已改名的 clip 全删了
  if (byName.has("idle") && root.listAnimations().length <= 6) { console.log(`${id}  skip (already stripped)`); continue; }
  const keep = new Set();
  for (const [runtimeName, clip] of Object.entries(wanted)) {
    const anim = byName.get(clip);
    if (anim) { anim.setName(runtimeName); keep.add(anim); }
    else console.warn(`  ${id}: clip 缺失 ${clip}`);
  }
  // 删掉其余动画
  for (const a of root.listAnimations()) if (!keep.has(a)) a.dispose();
  await doc.transform(prune(), dedup());
  await io.write(file, doc);
  const after = (fs.statSync(file).size / 1048576).toFixed(2);
  const names = doc.getRoot().listAnimations().map(a => a.getName()).join(", ");
  console.log(`${id}  ${before} → ${after} MB  clips: ${names}`);
}
let total = 0;
for (const f of fs.readdirSync(MODELS)) if (f.endsWith(".glb")) total += fs.statSync(path.join(MODELS, f)).size;
console.log(`total: ${(total / 1048576).toFixed(2)} MB`);
