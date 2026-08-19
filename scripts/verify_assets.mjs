#!/usr/bin/env node
// 无浏览器验证：解析 GLB 的 JSON 块（meshopt/webp 压缩不影响 JSON 块可读），检查
//  1) 每个 GLB 结构可解析
//  2) 每段动画的骨骼目标名都能在底模骨架里找到（否则运行时 AnimationMixer 绑不上，动作静止）
//  3) 三角面数 / 文件体积 / 合计
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MODELS = path.join(ROOT, "public", "assets", "models");
const MANIFEST = path.join(ROOT, "public", "assets", "assets.json");

function readGLBJson(file) {
  const buf = fs.readFileSync(file);
  if (buf.readUInt32LE(0) !== 0x46546c67) throw new Error("not a glTF binary");
  const jsonLen = buf.readUInt32LE(12);
  const json = JSON.parse(buf.slice(20, 20 + jsonLen).toString("utf8"));
  return json;
}
function nodeNames(j) { return (j.nodes || []).map(n => n.name).filter(Boolean); }
function triCount(j) {
  let tris = 0;
  for (const m of j.meshes || []) for (const p of m.primitives || []) {
    if (p.indices != null && j.accessors[p.indices]) tris += j.accessors[p.indices].count / 3;
  }
  return Math.round(tris);
}
function animTargetNodes(j) {
  const set = new Set();
  for (const a of j.animations || []) for (const c of a.channels || []) if (c.target && c.target.node != null) set.add(c.target.node);
  return [...set];
}
const mb = f => (fs.statSync(f).size / 1048576);

const manifest = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
let total = 0, problems = 0;
console.log("manifest chars:", Object.keys(manifest).join(", "));
for (const [id, entry] of Object.entries(manifest)) {
  console.log(`\n■ ${id}`);
  const baseFile = path.join(ROOT, "public", "assets", entry.path);
  let baseJson;
  try { baseJson = readGLBJson(baseFile); }
  catch (e) { console.log(`  ✗ base 无法解析: ${e.message}`); problems++; continue; }
  const baseNodes = nodeNames(baseJson);
  const baseNodeIdxNames = (baseJson.nodes || []).map(n => n.name || "");
  const sz = mb(baseFile); total += sz;
  const baseAnims = (baseJson.animations || []).length;
  console.log(`  ✓ base ${entry.path}  ${sz.toFixed(2)}MB  三角=${triCount(baseJson)}  骨骼节点=${baseNodes.length}  内置动画=${baseAnims}(idle)`);
  // 校验各动画文件的骨骼目标名 ⊆ 底模节点名
  for (const [name, rel] of Object.entries(entry.anims || {})) {
    const af = path.join(ROOT, "public", "assets", rel);
    let aj;
    try { aj = readGLBJson(af); } catch (e) { console.log(`  ✗ ${name}: 无法解析 ${e.message}`); problems++; continue; }
    const asz = mb(af); total += asz;
    const targetIdx = animTargetNodes(aj);
    const aNodeNames = (aj.nodes || []).map(n => n.name || "");
    const targetNames = targetIdx.map(i => aNodeNames[i]).filter(Boolean);
    const missing = targetNames.filter(nm => !baseNodes.includes(nm));
    const nAnim = (aj.animations || []).length;
    const ok = nAnim > 0 && missing.length === 0;
    if (!ok) problems++;
    console.log(`  ${ok ? "✓" : "✗"} ${name.padEnd(7)} ${rel}  ${(asz * 1024).toFixed(0)}KB  clip=${nAnim}  目标骨骼=${targetNames.length}  未匹配=${missing.length}${missing.length ? " → " + missing.slice(0, 4).join(",") : ""}`);
  }
}
// 也把清单外、models 里的散件列一下（不计入首屏 char 预算）
console.log(`\n合计（清单内 char 资产）: ${total.toFixed(2)} MB  ${total <= 3.5 ? "✓ 在 ≤3.5MB 预算内" : total <= 8 ? "△ 超骨架预算但在首屏 8MB 内" : "✗ 超首屏 8MB"}`);
console.log(problems ? `\n发现 ${problems} 处问题` : `\n全部通过：结构可解析、动画骨骼名与底模一致`);
process.exit(problems ? 1 : 0);
