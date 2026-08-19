#!/usr/bin/env node
// 资产收尾：idle 底模压缩（texture 512 + webp + meshopt）；动画 GLB 削成"只剩动画"。
// 需要生成流程跑完后再执行。
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { NodeIO } from "@gltf-transform/core";
import { prune, dedup } from "@gltf-transform/functions";
const pexec = promisify(execFile);
const MODELS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "public", "assets", "models");
const io = new NodeIO();

async function optimizeBase(file) {
  const raw = path.join(MODELS, "_opt_" + path.basename(file));
  fs.renameSync(file, raw);
  // 不用 meshopt：three r128 的 GLTFLoader 解不了 meshopt 压缩的“动画”访问器（idle 会读到 null）。
  // 改走 simplify（把 35 万三角降成低模，顺带贴合美术计划）+ webp 256，几何体存普通 float，r128 稳载。
  await pexec("npx", ["-y", "@gltf-transform/cli@latest", "optimize", raw, file,
    "--texture-compress", "webp", "--texture-size", "256", "--compress", "false",
    "--simplify", "true", "--simplify-ratio", "0.08", "--simplify-error", "0.004"],
    { maxBuffer: 64 * 1024 * 1024 });
  fs.unlinkSync(raw);
}
// 削成只剩骨骼节点 + 动画：去掉网格/材质/贴图/蒙皮
async function stripToAnim(file) {
  const doc = await io.read(file);
  const root = doc.getRoot();
  root.listNodes().forEach(n => n.setMesh(null));
  root.listSkins().forEach(s => s.dispose());
  root.listMeshes().forEach(m => m.dispose());
  root.listMaterials().forEach(m => m.dispose());
  root.listTextures().forEach(t => t.dispose());
  await doc.transform(prune(), dedup());
  await io.write(file, doc);
}

const mb = f => (fs.statSync(f).size / 1048576).toFixed(2);
for (const f of fs.readdirSync(MODELS)) {
  if (!f.endsWith(".glb") || f.startsWith("_")) continue;
  const full = path.join(MODELS, f);
  const isAnim = /_(run|attack|die)\.glb$/.test(f);
  try {
    if (isAnim) { const b = mb(full); await stripToAnim(full); console.log(`strip  ${f}  ${b} → ${mb(full)} MB`); }
    else { const b = mb(full); await optimizeBase(full); console.log(`optim  ${f}  ${b} → ${mb(full)} MB`); }
  } catch (e) { console.warn(`FAIL   ${f}: ${e.message}`); }
}
let total = 0;
for (const f of fs.readdirSync(MODELS)) if (f.endsWith(".glb") && !f.startsWith("_")) total += fs.statSync(path.join(MODELS, f)).size;
console.log(`total shipped models: ${(total / 1048576).toFixed(2)} MB`);
