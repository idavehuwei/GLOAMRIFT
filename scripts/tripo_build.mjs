#!/usr/bin/env node
// 幽影深渊 · 第一期骨架资产生成（Tripo3D）
// 流程：text_to_model → animate_rig → animate_retarget(idle/run/attack/die) → 下载 GLB
// 断点续跑：状态写入 scripts/tripo_state.json；重跑会复用已完成的 task_id。
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
const pexec = promisify(execFile);
// Node 的 fetch 不走 http_proxy，环境里所有出网都得经过代理 → 统一用 curl。
async function curlJSON(url, opts = {}) {
  const args = ["-s", "-m", "60", url];
  for (const [k, v] of Object.entries(opts.headers || {})) args.push("-H", `${k}: ${v}`);
  if (opts.method) args.push("-X", opts.method);
  if (opts.body) args.push("--data-binary", opts.body);
  const { stdout } = await pexec("curl", args, { maxBuffer: 64 * 1024 * 1024 });
  return JSON.parse(stdout);
}
async function curlDownload(url, dest) {
  await pexec("curl", ["-s", "-m", "300", "-o", dest, url], { maxBuffer: 8 * 1024 * 1024 });
}

const __dir = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dir, "..");
const MODELS = path.join(ROOT, "public", "assets", "models");
const STATE_FILE = path.join(__dir, "tripo_state.json");
const LOG_FILE = path.join(__dir, "tripo_build.log");
fs.mkdirSync(MODELS, { recursive: true });

const KEY = (() => {
  const km = fs.readFileSync(path.join(ROOT, "key.md"), "utf8");
  const m = km.match(/TRIPO3D_API_KEY="([^"]+)"/);
  if (!m) throw new Error("TRIPO3D_API_KEY not found in key.md");
  return m[1];
})();
const API = "https://api.tripo3d.ai/v2/openapi";
const H = { "Authorization": "Bearer " + KEY, "Content-Type": "application/json" };

function log(...a) {
  const line = `[${new Date().toISOString()}] ${a.join(" ")}`;
  console.log(line);
  fs.appendFileSync(LOG_FILE, line + "\n");
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
function loadState() { try { return JSON.parse(fs.readFileSync(STATE_FILE, "utf8")); } catch { return {}; } }
function saveState(s) { fs.writeFileSync(STATE_FILE, JSON.stringify(s, null, 2)); }

async function createTask(body) {
  const j = await curlJSON(API + "/task", { method: "POST", headers: H, body: JSON.stringify(body) });
  if (j.code !== 0) throw new Error("createTask failed: " + JSON.stringify(j));
  return j.data.task_id;
}
async function getTask(id) {
  const j = await curlJSON(API + "/task/" + id, { headers: H });
  if (j.code !== 0) throw new Error("getTask failed: " + JSON.stringify(j));
  return j.data;
}
async function waitTask(id, label) {
  let last = -1;
  for (;;) {
    const d = await getTask(id);
    if (d.progress !== last) { log(`  ${label} [${id.slice(0, 8)}] ${d.status} ${d.progress}%`); last = d.progress; }
    if (d.status === "success") return d;
    if (["failed", "banned", "expired", "cancelled", "unknown"].includes(d.status))
      throw new Error(`${label} ended: ${d.status} ${JSON.stringify(d.result || {})}`);
    await sleep(5000);
  }
}
function modelUrl(d) {
  const o = d.output || {};
  return o.model || o.pbr_model || o.base_model || (d.result && (d.result.model?.url || d.result.pbr_model?.url));
}
async function download(url, dest) {
  await curlDownload(url, dest);
  const sz = fs.statSync(dest).size;
  if (sz < 1000) throw new Error("download too small (" + sz + " bytes) " + url.slice(0, 80));
  log(`  saved ${path.basename(dest)} (${(sz / 1048576).toFixed(2)} MB)`);
  return sz;
}

// 角色定义：id、text prompt、attack 用的动画预设
const CHARS = [
  { id: "char_warrior", prompt: "full body A-pose stylized low-poly dark fantasy human warrior, heavy plate armor, hood, grim, game character, clean topology, symmetrical", attack: "preset:slash" },
  { id: "char_mage",    prompt: "full body A-pose stylized low-poly dark fantasy human mage, hooded robe, staff-less hands, arcane, game character, clean topology, symmetrical", attack: "preset:slash" },
  { id: "char_archer",  prompt: "full body A-pose stylized low-poly dark fantasy human archer ranger, leather armor, cloak, hood, game character, clean topology, symmetrical", attack: "preset:shoot" },
];
// 动画：运行时 clip 名 → Tripo 预设
const ANIM_PRESET = a => ({ idle: "preset:idle", run: "preset:run", die: "preset:hurt" }[a]);

async function ensureBase(st, ch) {
  st[ch.id] = st[ch.id] || {};
  const s = st[ch.id];
  if (!s.baseTask) { s.baseTask = await createTask({ type: "text_to_model", prompt: ch.prompt, model_version: "v2.5-20250123" }); saveState(st); }
  if (!s.baseDone) { await waitTask(s.baseTask, ch.id + " base"); s.baseDone = true; saveState(st); }
  return s;
}
async function ensureRig(st, ch) {
  const s = st[ch.id];
  if (!s.rigTask) {
    s.rigTask = await createTask({ type: "animate_rig", original_model_task_id: s.baseTask, out_format: "glb" });
    saveState(st);
  }
  if (!s.rigDone) { await waitTask(s.rigTask, ch.id + " rig"); s.rigDone = true; saveState(st); }
  return s;
}
async function ensureAnim(st, ch, clipName, preset) {
  const s = st[ch.id];
  s.anims = s.anims || {};
  const a = s.anims[clipName] = s.anims[clipName] || {};
  if (!a.task) {
    a.task = await createTask({ type: "animate_retarget", original_model_task_id: s.rigTask, animation: preset, out_format: "glb" });
    saveState(st);
  }
  if (!a.file) {
    const d = await waitTask(a.task, `${ch.id} ${clipName}`);
    const url = modelUrl(d);
    if (!url) throw new Error("no model url for " + clipName + " " + JSON.stringify(d.output));
    const fname = clipName === "idle" ? `${ch.id}.glb` : `${ch.id}_${clipName}.glb`;
    await download(url, path.join(MODELS, fname));
    a.file = fname; saveState(st);
  }
  return s;
}

async function buildChar(st, ch) {
  log(`=== ${ch.id} ===`);
  await ensureBase(st, ch);
  await ensureRig(st, ch);
  // idle 的输出既是骨架底模也带 idle 动作；其余只取动画 clip
  const clips = [["idle", "preset:idle"], ["run", "preset:run"], ["attack", ch.attack], ["die", "preset:hurt"]];
  for (const [name, preset] of clips) {
    try { await ensureAnim(st, ch, name, preset); }
    catch (e) { log(`  !! ${ch.id} ${name} skipped: ${e.message}`); }
  }
}

function writeManifest(st) {
  const manifest = {};
  for (const ch of CHARS) {
    const s = st[ch.id]; if (!s || !s.anims) continue;
    const anims = {};
    for (const k of ["run", "attack", "die"]) if (s.anims[k]?.file) anims[k] = "models/" + s.anims[k].file;
    if (!s.anims.idle?.file) continue;
    manifest[ch.id] = { path: "models/" + s.anims.idle.file, scale: 0.9, anims, idleFromBase: true };
  }
  const out = path.join(ROOT, "public", "assets", "assets.json");
  fs.writeFileSync(out, JSON.stringify(manifest, null, 2));
  log("manifest written: " + out + " (" + Object.keys(manifest).length + " chars)");
}

(async () => {
  // 复用已手动创建的 warrior base task（省 20 credit）
  const st = loadState();
  if (!st.char_warrior) st.char_warrior = { baseTask: "59e8c8d8-4c1f-45af-b55b-dbc94db90e6d" };
  saveState(st);
  for (const ch of CHARS) {
    try { await buildChar(st, ch); }
    catch (e) { log(`!!! ${ch.id} failed: ${e.message}`); }
  }
  writeManifest(st);
  log("ALL DONE");
})();
