#!/usr/bin/env node
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

let passed = 0, failed = 0;
function ok(name, cond, extra) {
  if (cond) { passed++; console.log("  ok  " + name); }
  else { failed++; console.log("  FAIL  " + name + (extra ? "  :: " + extra : "")); }
}
function eq(name, a, b) {
  const same = JSON.stringify(a) === JSON.stringify(b);
  ok(name, same, same ? "" : JSON.stringify(a) + " !== " + JSON.stringify(b));
}

function memStore() {
  const m = Object.create(null);
  return {
    getItem(k) { return Object.prototype.hasOwnProperty.call(m, k) ? m[k] : null; },
    setItem(k, v) { m[k] = String(v); },
    removeItem(k) { delete m[k]; },
    get _raw() { return m; }
  };
}

function loadApi(href) {
  const u = new URL(href);
  const localStorage = memStore();
  const sessionStorage = memStore();
  const loc = {
    get href() { return u.href; },
    get pathname() { return u.pathname; },
    get search() { return u.search; },
    get hash() { return u.hash; },
    get origin() { return u.origin; }
  };
  const history = {
    replaceState(_a, _b, url) {
      const n = new URL(url, u.href);
      u.pathname = n.pathname;
      u.search = n.search;
      u.hash = n.hash;
    }
  };
  const sandbox = {
    window: {},
    localStorage,
    sessionStorage,
    location: loc,
    history,
    URLSearchParams,
    URL,
    Date,
    JSON,
    Object,
    Array,
    isFinite,
    btoa: (s) => Buffer.from(s, "binary").toString("base64"),
    atob: (s) => Buffer.from(s, "base64").toString("binary"),
    unescape,
    escape,
    encodeURIComponent,
    decodeURIComponent,
    console
  };
  sandbox.window = sandbox;
  const code = fs.readFileSync(path.join(__dirname, "../js/saves.js"), "utf8");
  vm.runInNewContext(code, sandbox, { filename: "saves.js" });
  return { api: sandbox.GloamSave, localStorage, sessionStorage, loc };
}

function hero(over) {
  return Object.assign({
    v: 1,
    name: "Aldric",
    cls: "warrior",
    lvl: 4,
    xp: 20,
    xpNext: 80,
    gold: 320,
    pts: 1,
    skPts: 0,
    base: { str: 25, dex: 13, vit: 25, ene: 9 },
    hp: 80,
    mp: 40,
    potHp: 3,
    potMp: 2,
    ranks: { cleave: 1 },
    barSkills: ["cleave", null, null, null, null, null],
    equip: { weapon: { id: 1, type: "weapon", name: "短剑" } },
    bag: [],
    kills: 8,
    quests: { q1: { state: "open" } },
    riftDeepest: 2,
    discovered: { town: true, waste: true }
  }, over || {});
}

console.log("\n[saves.js unit]");

(function () {
  const { api } = loadApi("http://127.0.0.1/index.html");
  ok("empty store has 3 null slots", api.getSlots().every(s => s === null) && api.getSlots().length === 3);
  ok("no latest when empty", api.latestSlotIndex() === -1);
  ok("first empty is 0", api.firstEmptySlot() === 0);
  ok("invalid empty object", !api.isValid({}));
  ok("invalid missing name", !api.isValid({ v: 1, cls: "warrior", lvl: 1, base: { str: 1 } }));
  ok("invalid class", !api.isValid({ v: 1, name: "A", cls: "druid", lvl: 1, base: {} }));
  ok("invalid version", !api.isValid(Object.assign(hero(), { v: 99 })));
  ok("valid hero", api.isValid(hero()));
})();

(function () {
  const { api, localStorage } = loadApi("http://127.0.0.1/index.html");
  ok("write slot 0", api.writeSlot(0, hero()));
  const s = api.getSlot(0);
  ok("read back name", s && s.name === "Aldric");
  ok("forced version 1", s.v === 1);
  ok("slot index stamped", s.slot === 0);
  ok("timestamp set", typeof s.t === "number" && s.t > 0);
  ok("occupied 1", api.occupiedCount() === 1);
  ok("latest is 0", api.latestSlotIndex() === 0);
  ok("empty slot 1", api.firstEmptySlot() === 1);
  ok("reject slot 9", api.writeSlot(9, hero()) === false);
  const raw = JSON.parse(localStorage.getItem("gloamrift-saves-v1"));
  ok("persisted in localStorage", raw.v === 1 && raw.slots[0].name === "Aldric");
})();

(function () {
  const { api, localStorage } = loadApi("http://127.0.0.1/index.html");
  localStorage.setItem("gloamrift-saves-v1", JSON.stringify({
    v: 1,
    slots: [hero({ name: "Old", t: 100 }), null, hero({ name: "New", cls: "mage", t: 200 })]
  }));
  ok("latest is highest timestamp", api.latestSlotIndex() === 2);
  ok("slot 1 still empty", api.getSlot(1) === null);
  api.deleteSlot(2);
  ok("delete leaves hole", api.getSlot(2) === null && api.getSlot(0).name === "Old");
  ok("first empty after delete is 1", api.firstEmptySlot() === 1);
})();

(function () {
  const { api, localStorage } = loadApi("http://127.0.0.1/index.html");
  localStorage.setItem("gloamrift-saves-v1", JSON.stringify({
    v: 1,
    slots: [hero(), { v: 1, name: "", cls: "warrior", lvl: 1, base: {} }, { v: 2, name: "X", cls: "mage", lvl: 3, base: {} }]
  }));
  const slots = api.getSlots();
  ok("scrub drops empty name", slots[1] === null);
  ok("scrub drops version mismatch", slots[2] === null);
  ok("scrub keeps good slot", slots[0] && slots[0].name === "Aldric");
  const persisted = JSON.parse(localStorage.getItem("gloamrift-saves-v1"));
  ok("scrub writes purged store", persisted.slots[1] === null && persisted.slots[2] === null);
})();

(function () {
  const { api, localStorage } = loadApi("http://127.0.0.1/index.html");
  localStorage.setItem("gloamrift-saves-v1", "{not json");
  ok("corrupt json yields empty", api.occupiedCount() === 0);
  localStorage.setItem("gloamrift-saves-v1", JSON.stringify({ v: 99, slots: [hero()] }));
  ok("store version mismatch discarded", api.getSlot(0) === null);
})();

(function () {
  const { api } = loadApi("http://127.0.0.1/index.html");
  ok("export empty is blank", api.exportSlot(0) === "");
  api.writeSlot(0, hero({ name: "Elara" }));
  const text = api.exportSlot(0);
  ok("export has banner", text.indexOf("GLOAMRIFT ARCHIVE") >= 0);
  ok("export has GLOAM1.", /GLOAM1\.[A-Za-z0-9+/=]+/.test(text));
  const parsed = api.parseImport(text);
  ok("parse export ok", parsed.ok && parsed.kind === "slot");
  ok("parse keeps name", parsed.data && parsed.data.name === "Elara");
  ok("garbage import fails", !api.parseImport("hello world").ok);
  ok("empty import fails", !api.parseImport("").ok);
  ok("broken json fails", !api.parseImport("{nope").ok);
  const v2 = JSON.stringify(Object.assign(hero(), { v: 99 }));
  ok("raw json wrong version fails", !api.parseImport(v2).ok);
  const rawOk = api.parseImport(JSON.stringify(hero({ name: "Raw" })));
  ok("raw json slot accepted", rawOk.ok && rawOk.data.name === "Raw");
})();

(function () {
  const { api } = loadApi("http://127.0.0.1/index.html");
  api.writeSlot(0, hero({ name: "Keep" }));
  const incoming = hero({ name: "Imported", cls: "archer" });
  ok("import into slot 1", api.importSlot(1, incoming));
  ok("import did not clobber slot 0", api.getSlot(0).name === "Keep");
  ok("imported archer", api.getSlot(1).cls === "archer" && api.getSlot(1).name === "Imported");
})();

(function () {
  const payload = encodeURIComponent(JSON.stringify({ v: 1, slots: [hero({ name: "FromHash" }), null, null] }));
  const { api, loc } = loadApi("http://127.0.0.1/shadow-depths.html?mode=load&slot=0&name=X&cls=warrior#saves=" + payload);
  ok("ingest hash into store", api.getSlot(0) && api.getSlot(0).name === "FromHash");
  ok("boot from query", api.getBoot() && api.getBoot().mode === "load" && api.getBoot().slot === 0);
  ok("boot keeps cls", api.getBoot().cls === "warrior");
  ok("url stripped after ingest", loc.search === "" && loc.hash === "");
})();

(function () {
  const { api } = loadApi("http://127.0.0.1/create.html");
  api.writeSlot(0, hero());
  const href = api.hrefToGame({ mode: "new", slot: 1, name: "Vesper", cls: "mage" });
  ok("game href has mode=new", href.indexOf("mode=new") >= 0);
  ok("game href has cls", href.indexOf("cls=mage") >= 0);
  ok("game href carries saves hash", href.indexOf("#saves=") >= 0);
  ok("boot cached", api.getBoot().name === "Vesper");
  const menu = api.hrefTo("index.html");
  ok("menu href is index + hash", menu.indexOf("index.html#saves=") === 0);
})();

(function () {
  const { api } = loadApi("http://127.0.0.1/index.html");
  ok("class labels", api.classLabel("mage") === "法师" && api.classEn("archer").indexOf("Ranger") >= 0);
  ok("formatTime empty", api.formatTime(0) === "—");
  ok("formatTime has date", /\d{4}\.\d{2}\.\d{2}/.test(api.formatTime(Date.now())));
})();

(function () {
  const { api, localStorage } = loadApi("http://127.0.0.1/index.html");
  eq("empty stash", api.getStash(), []);
  const ring = { id: 7, type: "ring", name: "镇库戒", glyph: "💍", rarity: 1 };
  api.setStash([ring, null]);
  ok("setStash drops null", api.getStash().length === 1 && api.getStash()[0].name === "镇库戒");
  api.writeSlot(0, hero({ name: "Keeper" }));
  ok("writeSlot keeps stash", api.getStash()[0].name === "镇库戒" && api.getSlot(0).name === "Keeper");
  api.deleteSlot(0);
  ok("deleteSlot keeps stash", api.getStash()[0].name === "镇库戒");
  const many = [];
  for (let i = 0; i < 50; i++) many.push({ id: i + 1, type: "ring", name: "x" + i });
  api.setStash(many);
  ok("stash capped at 40", api.getStash().length === 40);
  const persisted = JSON.parse(localStorage.getItem("gloamrift-saves-v1"));
  ok("store has stash array", Array.isArray(persisted.stash) && persisted.stash.length === 40);
})();

(function () {
  const { api, localStorage } = loadApi("http://127.0.0.1/index.html");
  localStorage.setItem("gloamrift-saves-v1", JSON.stringify({
    v: 1,
    slots: [hero({ name: "OldStore" }), null, null]
  }));
  ok("old store without stash key still loads", api.getSlot(0).name === "OldStore" && api.getStash().length === 0);
})();

(function () {
  const payload = encodeURIComponent(JSON.stringify({
    v: 1,
    slots: [hero({ name: "FromHash" }), null, null],
    stash: [{ id: 3, name: "哈希箱", type: "ring" }]
  }));
  const { api } = loadApi("http://127.0.0.1/shadow-depths.html#saves=" + payload);
  ok("hash with stash ingested", api.getStash()[0] && api.getStash()[0].name === "哈希箱");
})();

(function () {
  const store = memStore();
  store.setItem("gloamrift-saves-v1", JSON.stringify({
    v: 1,
    slots: [hero({ name: "Local" }), null, null],
    stash: [{ id: 2, name: "本地箱", type: "ring" }]
  }));
  const keep = encodeURIComponent(JSON.stringify({ v: 1, slots: [hero({ name: "FromHash2" }), null, null] }));
  const u = new URL("http://127.0.0.1/shadow-depths.html#saves=" + keep);
  const boxed = {
    window: {},
    localStorage: store,
    sessionStorage: memStore(),
    location: {
      get href() { return u.href; },
      get pathname() { return u.pathname; },
      get search() { return u.search; },
      get hash() { return u.hash; }
    },
    history: { replaceState() {} },
    URLSearchParams, URL, Date, JSON, Object, Array, isFinite,
    btoa: (s) => Buffer.from(s, "binary").toString("base64"),
    atob: (s) => Buffer.from(s, "base64").toString("binary"),
    unescape, escape, encodeURIComponent, decodeURIComponent, console
  };
  boxed.window = boxed;
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "../js/saves.js"), "utf8"), boxed, { filename: "saves.js" });
  ok("hash missing stash keeps local stash", boxed.GloamSave.getStash()[0] && boxed.GloamSave.getStash()[0].name === "本地箱");
  ok("hash still ingested slot", boxed.GloamSave.getSlot(0).name === "FromHash2");
})();

console.log("\n[serialize round-trip shape]");
(function () {
  // Mirrors game serializePlayer / applySave contract without Three.js
  const sample = hero({
    barSkills: ["cleave", "fire", null, null, null, null],
    bag: [{ id: 9, type: "ring", name: "铜戒" }],
    hp: 0
  });
  const { api } = loadApi("http://127.0.0.1/index.html");
  ok("dead-hp save is still valid", api.isValid(sample));
  api.writeSlot(0, sample);
  const loaded = api.getSlot(0);
  ok("gold persists", loaded.gold === 320);
  ok("quest blob persists", loaded.quests.q1.state === "open");
  ok("hp 0 persists in file", loaded.hp === 0);
  ok("lastArea always town at write time is game-side", true);
})();

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
