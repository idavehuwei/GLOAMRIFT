#!/usr/bin/env node
"use strict";
const { spawn } = require("child_process");
const { chromium } = require("playwright-core");
const path = require("path");
const http = require("http");

const ROOT = path.join(__dirname, "..");
const PORT = 8765;
const BASE = "http://127.0.0.1:" + PORT;
let passed = 0, failed = 0;
function ok(name, cond, extra) {
  if (cond) { passed++; console.log("  ok  " + name); }
  else { failed++; console.log("  FAIL  " + name + (extra ? "  :: " + extra : "")); }
}

function waitServer() {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error("server start timeout")), 8000);
    const tick = () => {
      http.get(BASE + "/index.html", (res) => { clearTimeout(t); res.resume(); resolve(); })
        .on("error", () => setTimeout(tick, 80));
    };
    setTimeout(tick, 120);
  });
}

(async () => {
  const server = spawn("python3", ["-m", "http.server", String(PORT), "--bind", "127.0.0.1"], {
    cwd: ROOT, stdio: ["ignore", "ignore", "ignore"]
  });
  try {
    await waitServer();
    const browser = await chromium.launch({
      executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      headless: true
    });
    const page = await browser.newPage();
    page.setDefaultTimeout(25000);
    const errors = [];
    page.on("pageerror", (e) => errors.push(String(e)));

    console.log("\n[e2e save / load / continue]");

    await page.goto(BASE + "/index.html", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#btn-continue");
    ok("title: continue disabled when empty", await page.$eval("#btn-continue", el => el.disabled) === true);

    await page.click('a[href="create.html"]');
    await page.waitForSelector(".classcard");
    await page.click(".classcard");
    await page.fill("#name", "TestWarden");
    await page.waitForFunction(() => !document.getElementById("begin").classList.contains("dis"));
    await Promise.all([
      page.waitForURL(/shadow-depths\.html/),
      page.click("#begin")
    ]);

    await page.waitForFunction(() => {
      const v = document.getElementById("veil");
      const n = document.getElementById("pname");
      return v && v.classList.contains("off") && n && n.textContent === "TestWarden";
    });
    ok("new game: name on HUD", true);
    ok("new game: no pageerror", errors.length === 0, errors.join(" | "));

    const save = await page.evaluate(() => {
      const raw = localStorage.getItem("gloamrift-saves-v1");
      return raw ? JSON.parse(raw) : null;
    });
    ok("new game: store written", !!(save && save.slots && save.slots[0]));
    ok("new game: slot name/class/level", !!(save && save.slots[0] && save.slots[0].name === "TestWarden" && save.slots[0].cls === "warrior" && save.slots[0].lvl === 1));
    ok("new game: lastArea town", !!(save && save.slots[0] && save.slots[0].lastArea === "town"));
    ok("new game: has starting weapon", !!(save && save.slots[0] && save.slots[0].equip && save.slots[0].equip.weapon));
    ok("new game: daily bounties rolled", !!(save && save.slots[0] && Array.isArray(save.slots[0].bountyList) && save.slots[0].bountyList.length === 5));
    await page.waitForFunction(() => {
      const texts = [...document.querySelectorAll(".wlabel")].map(el => el.textContent || "");
      return texts.some(t => t.indexOf("银行") >= 0) &&
        texts.some(t => t.indexOf("悬赏板") >= 0) &&
        texts.some(t => t.indexOf("传送石碑") >= 0) &&
        texts.some(t => t.indexOf("赌徒") >= 0);
    });
    ok("town: south service labels visible", true);
    await page.evaluate(() => {
      window.GloamSave.setStash([{
        id: 77, type: "ring", name: "共享戒", glyph: "💍", rarity: 1,
        ilvl: 1, dmgMin: 0, dmgMax: 0, armor: 0, affixes: []
      }]);
    });
    const stash0 = await page.evaluate(() => window.GloamSave.getStash());
    ok("stash: wrote shared ring", !!(stash0 && stash0[0] && stash0[0].name === "共享戒"));
    const gold0 = save && save.slots[0] && save.slots[0].gold;

    await page.evaluate(() => { document.getElementById("menubtn").click(); });
    await page.waitForSelector("#pause.on");
    ok("pause menu opens", true);
    await Promise.all([
      page.waitForURL(/index\.html/),
      page.click("#pause-title")
    ]);

    await page.waitForSelector("#btn-continue:not([disabled])");
    const hint = await page.$eval("#cont-hint", el => el.textContent);
    ok("title: continue enabled after save", hint.indexOf("TestWarden") >= 0);

    await Promise.all([
      page.waitForURL(/shadow-depths\.html/),
      page.click("#btn-continue")
    ]);
    await page.waitForFunction(() => {
      const n = document.getElementById("pname");
      const v = document.getElementById("veil");
      return n && n.textContent === "TestWarden" && v && v.classList.contains("off");
    });
    ok("continue: HUD restored", true);
    const lvlLine = await page.$eval("#plvl", el => el.textContent);
    ok("continue: class line", lvlLine.indexOf("战士") >= 0 && lvlLine.indexOf("等级 1") >= 0);
    const stash1 = await page.evaluate(() => window.GloamSave.getStash());
    ok("stash: survives continue", !!(stash1 && stash1[0] && stash1[0].name === "共享戒"));

    await page.evaluate(() => { document.getElementById("menubtn").click(); });
    await page.click("#pause-export");
    await page.waitForSelector("#xfer.on");
    const exported = await page.$eval("#xfer-box", el => el.value);
    ok("export: GLOAM1 payload", /GLOAM1\.[A-Za-z0-9+/=]+/.test(exported));
    await page.click("#xfer-close");
    await Promise.all([
      page.waitForURL(/index\.html/),
      page.click("#pause-title")
    ]);

    await page.click('a[href="load.html"]');
    await page.waitForSelector(".save .nm");
    const loadName = await page.$eval(".save .nm", el => el.textContent);
    ok("load page shows character", loadName === "TestWarden");

    await Promise.all([
      page.waitForURL(/shadow-depths\.html/),
      page.click(".save")
    ]);
    await page.waitForFunction(() => document.getElementById("pname") && document.getElementById("pname").textContent === "TestWarden");
    ok("load page: enters game", true);

    console.log("\n[e2e smith reforge / sockets]");
    const smithOrig = await page.evaluate(() => {
      const P = window.__GLOAMTEST.P;
      return {gold:P.gold, bag:JSON.parse(JSON.stringify(P.bag)), equip:JSON.parse(JSON.stringify(P.equip))};
    });
    const smithUi = await page.evaluate(() => {
      const T = window.__GLOAMTEST;
      T.openNPC("kaden");
      const npc = document.getElementById("npc");
      const ref = document.getElementById("reforgebox");
      const sock = document.getElementById("socketbox");
      return {
        smith: npc && npc.classList.contains("smith"),
        reforge: ref ? ref.textContent : "",
        socket: sock ? sock.textContent : ""
      };
    });
    ok("smith: kaden panel widens", !!(smithUi && smithUi.smith));
    ok("smith: common gear cannot reforge", !!(smithUi && smithUi.reforge.indexOf("没有带词缀") >= 0));
    ok("smith: common gear cannot socket", !!(smithUi && smithUi.socket.indexOf("稀有以上") >= 0));

    const smithFlow = await page.evaluate(() => {
      const T = window.__GLOAMTEST;
      const rare = T.rollItem(8, true);
      rare.type = "weapon"; rare.cls = "warrior"; rare.rarity = 3; T.rollAffixes(rare);
      T.P.equip.weapon = rare;
      const rune = T.rollRune();
      rune.k = "dmg"; rune.v = 6; rune.runeId = "rune_ember"; rune.name = "余烬符文";
      T.P.bag.push(rune);
      T.P.gold = 50000;
      const gold0 = T.P.gold;
      const aff0 = JSON.stringify(rare.affixes);
      T.doReforge("eweapon");
      const afterRef = T.gearAt("eweapon");
      const gold1 = T.P.gold;
      T.doPunch("eweapon");
      const dmg0 = T.pStats().dmgMax;
      T.doSocketIn("eweapon", 0, 0);
      const sock = T.gearAt("eweapon") && T.gearAt("eweapon").sockets && T.gearAt("eweapon").sockets[0];
      const inlaid = !!(sock && sock.k === "dmg" && sock.v === 6);
      const dmg1 = T.pStats().dmgMax;
      const bagAfterIn = T.P.bag.filter(x => x && x.type === "rune").length;
      const punched = !!(T.gearAt("eweapon") && T.gearAt("eweapon").sockets && T.gearAt("eweapon").sockets.length === 1);
      T.doSocketOut("eweapon");
      const afterOut = T.gearAt("eweapon");
      const bagAfterOut = T.P.bag.filter(x => x && x.type === "rune").length;
      const old = T.rollItem(5, true);
      delete old.sockets; delete old.reforged;
      T.ensureGear(old);
      T.openNPC("kaden");
      return {
        hook: !!(T.openNPC && T.doReforge),
        reforged: afterRef && afterRef.reforged === 1,
        affChanged: JSON.stringify(afterRef && afterRef.affixes) !== aff0,
        goldDown: gold1 < gold0,
        punched,
        inlaid,
        dmgUp: dmg1 > dmg0,
        runeGone: bagAfterIn === 0,
        extracted: bagAfterOut === 1 && afterOut && afterOut.sockets && afterOut.sockets[0] === null,
        oldSave: Array.isArray(old.sockets) && old.reforged === 0,
        uiPunch: !!document.querySelector("[data-punch]"),
        uiReforge: !!document.querySelector("[data-reforge]")
      };
    });
    ok("smith: test hook present", !!(smithFlow && smithFlow.hook));
    ok("smith: reforge increments count", !!(smithFlow && smithFlow.reforged));
    ok("smith: reforge rerolls affixes", !!(smithFlow && smithFlow.affChanged));
    ok("smith: reforge spends gold", !!(smithFlow && smithFlow.goldDown));
    ok("smith: punch opens a hole", !!(smithFlow && smithFlow.punched));
    ok("smith: rune sockets into hole", !!(smithFlow && smithFlow.inlaid));
    ok("smith: socketed rune affects pStats", !!(smithFlow && smithFlow.dmgUp));
    ok("smith: inlay removes rune from bag", !!(smithFlow && smithFlow.runeGone));
    ok("smith: extract restores rune and empty hole", !!(smithFlow && smithFlow.extracted));
    ok("smith: old save missing sockets hydrates", !!(smithFlow && smithFlow.oldSave));
    ok("smith: punch control visible on rare", !!(smithFlow && smithFlow.uiPunch));
    ok("smith: reforge control visible", !!(smithFlow && smithFlow.uiReforge));

    await page.evaluate((orig) => {
      const P = window.__GLOAMTEST.P;
      P.gold = orig.gold;
      P.bag.splice(0, P.bag.length);
      orig.bag.forEach(it => P.bag.push(it));
      Object.keys(P.equip).forEach(k => { P.equip[k] = orig.equip[k] || null; });
    }, smithOrig);

    console.log("\n[e2e achievements]");
    const ach = await page.evaluate(() => {
      const T = window.__GLOAMTEST;
      const before = Object.keys(T.P.ach || {}).length;
      T.P.kills = Math.max(T.P.kills || 0, 1);
      T.achCheck();
      T.togglePanel("ach", true);
      const toast = document.getElementById("achtoast");
      const list = document.getElementById("achlist");
      const tab = [...document.querySelectorAll("#tabs .tab")].some(t => (t.textContent || "").indexOf("功绩") >= 0);
      const ser = T.P.ach && T.P.ach.kill1;
      return {
        hook: !!(T.ACH && T.achCheck && T.ACH.length >= 20),
        unlocked: !!T.P.ach.kill1,
        grew: Object.keys(T.P.ach).length > before,
        toast: !!(toast && toast.classList.contains("on") && document.getElementById("achtoast-n").textContent.indexOf("第一滴血") >= 0),
        panel: !!(document.getElementById("ach") && document.getElementById("ach").classList.contains("on")),
        listed: !!(list && list.textContent.indexOf("第一滴血") >= 0),
        tab,
        gold: T.P.gold,
        silentOld: (function(){
          T.P.kills = 100;
          const name = document.getElementById("achtoast-n").textContent;
          T.achCheck(true);
          return !!T.P.ach.kill100 && document.getElementById("achtoast-n").textContent === name;
        })()
      };
    });
    ok("ach: test hook and catalog", !!(ach && ach.hook));
    ok("ach: first kill unlocks 第一滴血", !!(ach && ach.unlocked && ach.grew));
    ok("ach: toast shows name", !!(ach && ach.toast));
    ok("ach: panel lists unlocked feat", !!(ach && ach.panel && ach.listed));
    ok("ach: HUD tab 功绩 Y", !!(ach && ach.tab));
    ok("ach: silent check grants without extra toast flash", !!(ach && ach.silentOld));

    await page.evaluate(() => {
      const T = window.__GLOAMTEST;
      T.togglePanel("ach", false);
      T.P.kills = 0;
      delete T.P.ach.kill1;
      delete T.P.ach.kill100;
    });

    await page.goto(BASE + "/index.html");
    await page.evaluate(() => {
      const raw = JSON.parse(localStorage.getItem("gloamrift-saves-v1"));
      raw.v = 99;
      localStorage.setItem("gloamrift-saves-v1", JSON.stringify(raw));
    });
    await page.reload({ waitUntil: "domcontentloaded" });
    ok("bad store version: continue disabled", await page.$eval("#btn-continue", el => el.disabled) === true);

    await page.evaluate(() => {
      localStorage.setItem("gloamrift-saves-v1", JSON.stringify({
        v: 1,
        slots: [{ v: 1, name: "Broken", cls: "nope", lvl: 3, base: {} }, null, null]
      }));
    });
    await page.goto(BASE + "/load.html", { waitUntil: "domcontentloaded" });
    const emptyLabel = await page.$eval(".save .nm", el => el.textContent);
    ok("invalid class slot scrubbed to empty", emptyLabel.indexOf("空槽") >= 0);

    await page.evaluate((text) => {
      document.getElementById("import-text").value = text;
    }, exported);
    await page.click("#import-go");
    await page.waitForFunction(() => {
      const n = document.querySelector(".save .nm");
      return n && n.textContent === "TestWarden";
    });
    ok("import text restores character", true);

    await Promise.all([
      page.waitForURL(/shadow-depths\.html/),
      page.click(".save")
    ]);
    await page.waitForFunction(() => document.getElementById("veil") && document.getElementById("veil").classList.contains("off"));
    await page.evaluate(() => { document.getElementById("menubtn").click(); });
    page.once("dialog", d => d.accept());
    await Promise.all([
      page.waitForURL(/create\.html/),
      page.click("#pause-restart")
    ]);
    ok("restart: back to create hall", true);
    await page.goto(BASE + "/index.html");
    ok("restart: slot burned, continue disabled", await page.$eval("#btn-continue", el => el.disabled) === true);

    ok("gold at creation is number", typeof gold0 === "number" && gold0 >= 0);
    ok("e2e pageerror still empty", errors.length === 0, errors.join(" | "));

    await browser.close();
  } finally {
    server.kill("SIGTERM");
  }
  console.log("\n" + passed + " passed, " + failed + " failed");
  process.exit(failed ? 1 : 0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
