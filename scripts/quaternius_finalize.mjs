#!/usr/bin/env node
// 从 Quaternius Ultimate Animated Character 包（用户下载在 ~/Downloads/glTF）挑角色，
// 削成 idle/run/attack/die 四段并转成自包含 .glb，放进游戏。
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import { NodeIO } from "@gltf-transform/core";
import { prune, dedup } from "@gltf-transform/functions";
const SRC = path.join(os.homedir(), "Downloads", "glTF");
const MODELS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "public", "assets", "models");
const io = new NodeIO();

// 目标资产 → [源文件, 攻击动作]
const JOBS = [
  ["npc_selin",  "Suit_Male",       "SwordSlash"],
  ["npc_mara",   "Witch",           "Shoot_OneHanded"],
  ["npc_kaden",  "Worker_Male",     "Punch"],
  ["npc_vaun",   "Cowboy_Male",     "Shoot_OneHanded"],
  ["npc_bridge", "OldClassy_Male",  "Punch"],
  ["mob_zombie", "Zombie_Male",     "Punch"],
  ["mob_goblin", "Goblin_Male",     "SwordSlash"],
  // 其它章节的守关 NPC（区域限定）
  ["npc_harun",  "Viking_Male",     "SwordSlash"],
  ["npc_wick",   "Pirate_Male",     "Shoot_OneHanded"],
  ["npc_quill",  "Casual_Male",     "Punch"],
  ["npc_nock",   "Soldier_Male",    "SwordSlash"],
  // 人形怪物
  ["mob_wizard",  "Wizard",           "Shoot_OneHanded"],  // 灰烬巫师 + 施法系首领
  ["mob_knight",  "Knight_Male",      "SwordSlash"],       // 霜铠骑士
  ["mob_ninja",   "Ninja_Male",       "SwordSlash"],       // 七影
  ["mob_drowned", "Zombie_Female",    "Punch"],            // 溺尸（与腐尸区分）
  ["mob_lord",    "Knight_Golden_Male","SwordSlash"],      // 恐惧领主（首领）
];
const pickAttack = (byName, pref) => [pref, "SwordSlash", "Punch", "Shoot_OneHanded"].find(n => byName.has(n));

for (const [asset, src, atk] of JOBS) {
  const srcFile = path.join(SRC, src + ".gltf");
  if (!fs.existsSync(srcFile)) { console.warn("missing source", srcFile); continue; }
  const doc = await io.read(srcFile);
  const root = doc.getRoot();
  const byName = new Map(root.listAnimations().map(a => [a.getName(), a]));
  const want = { idle: "Idle", run: "Run", attack: pickAttack(byName, atk), die: "Death" };
  const keep = new Set();
  for (const [rt, cn] of Object.entries(want)) {
    const a = cn && byName.get(cn);
    if (a) { a.setName(rt); keep.add(a); } else console.warn(`  ${asset}: no clip for ${rt} (${cn})`);
  }
  for (const a of root.listAnimations()) if (!keep.has(a)) a.dispose();
  await doc.transform(prune(), dedup());
  const out = path.join(MODELS, asset + ".glb");
  await io.write(out, doc);
  const clips = doc.getRoot().listAnimations().map(a => a.getName()).join(",");
  console.log(`${asset.padEnd(11)} <- ${src.padEnd(15)} ${(fs.statSync(out).size / 1048576).toFixed(2)}MB  [${clips}]`);
}
