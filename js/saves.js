/* Gloamrift · local archive (3 slots) + boot payload
   Saves live in localStorage. Navigating between pages also carries a
   #saves= payload so file:// origins (Chrome) can still share slots. */
(function (root) {
  "use strict";
  var KEY = "gloamrift-saves-v1";
  var BOOT = "gloamrift-boot";
  var VERSION = 1;
  var SLOTS = 3;
  var cachedBoot = null;

  function empty() {
    var slots = [];
    for (var i = 0; i < SLOTS; i++) slots.push(null);
    return { v: VERSION, slots: slots, stash: [] };
  }

  function loadAll() {
    try {
      var raw = localStorage.getItem(KEY);
      if (!raw) return empty();
      var data = JSON.parse(raw);
      if (!data || data.v !== VERSION || !Array.isArray(data.slots)) return empty();
      while (data.slots.length < SLOTS) data.slots.push(null);
      if (!Array.isArray(data.stash)) data.stash = [];
      return scrub(data);
    } catch (e) {
      return empty();
    }
  }

  function saveAll(data) {
    localStorage.setItem(KEY, JSON.stringify(data));
  }

  var CLASSES = { warrior: 1, mage: 1, archer: 1 };

  function isValid(s) {
    if (!s || typeof s !== "object") return false;
    if (s.v !== VERSION) return false;
    if (!CLASSES[s.cls]) return false;
    if (typeof s.name !== "string" || !s.name.trim()) return false;
    if (!isFinite(+s.lvl) || +s.lvl < 1) return false;
    if (!s.base || typeof s.base !== "object") return false;
    return true;
  }

  function scrub(data) {
    var dirty = false;
    if (!data.slots) return data;
    for (var i = 0; i < data.slots.length; i++) {
      if (data.slots[i] && !isValid(data.slots[i])) {
        data.slots[i] = null;
        dirty = true;
      }
    }
    if (dirty) saveAll(data);
    return data;
  }

  function b64(str) {
    return btoa(unescape(encodeURIComponent(str)));
  }
  function unb64(s) {
    return decodeURIComponent(escape(atob(s.replace(/-/g, "+").replace(/_/g, "/"))));
  }

  function pageName(file) {
    return file || (location.pathname.split("/").pop() || "index.html");
  }

  function savesHash() {
    return "#saves=" + encodeURIComponent(JSON.stringify(loadAll()));
  }

  function ingest() {
    try {
      var hash = (location.hash || "").replace(/^#/, "");
      if (hash) {
        var sp = new URLSearchParams(hash);
        var raw = sp.get("saves");
        if (raw) {
          var data = JSON.parse(decodeURIComponent(raw));
          if (data && data.v === VERSION && Array.isArray(data.slots)) {
            while (data.slots.length < SLOTS) data.slots.push(null);
            if (!Array.isArray(data.stash)) data.stash = (loadAll().stash || []).slice();
            saveAll(data);
            scrub(data);
          }
        }
      }
    } catch (e) {}
    try {
      var q = new URLSearchParams(location.search);
      if (q.get("mode")) {
        cachedBoot = {
          mode: q.get("mode"),
          slot: +(q.get("slot") || 0),
          name: q.get("name") || "",
          cls: q.get("cls") || ""
        };
      }
    } catch (e) {}
    if (!cachedBoot) {
      try {
        var rawBoot = sessionStorage.getItem(BOOT);
        if (rawBoot) cachedBoot = JSON.parse(rawBoot);
      } catch (e) {}
    }
    try {
      if (location.hash || location.search) {
        history.replaceState(null, "", location.pathname);
      }
    } catch (e) {}
  }

  ingest();

  var api = {
    SLOTS: SLOTS,
    VERSION: VERSION,
    loadAll: loadAll,
    getSlots: function () { return loadAll().slots; },
    getSlot: function (i) {
      return loadAll().slots[i] || null;
    },
    writeSlot: function (i, payload) {
      if (i < 0 || i >= SLOTS) return false;
      payload = payload || {};
      payload.v = VERSION;
      payload.t = Date.now();
      payload.slot = i;
      if (!isValid(payload)) return false;
      var data = loadAll();
      data.slots[i] = payload;
      saveAll(data);
      return true;
    },
    deleteSlot: function (i) {
      var data = loadAll();
      data.slots[i] = null;
      saveAll(data);
    },
    latestSlotIndex: function () {
      var slots = loadAll().slots;
      var best = -1, t = 0;
      for (var i = 0; i < slots.length; i++) {
        if (slots[i] && slots[i].t > t) { t = slots[i].t; best = i; }
      }
      return best;
    },
    occupiedCount: function () {
      return loadAll().slots.filter(Boolean).length;
    },
    setBoot: function (obj) {
      cachedBoot = obj;
      try { sessionStorage.setItem(BOOT, JSON.stringify(obj)); } catch (e) {}
    },
    getBoot: function () { return cachedBoot; },
    clearBoot: function () {
      cachedBoot = null;
      try { sessionStorage.removeItem(BOOT); } catch (e) {}
    },
    hrefToGame: function (boot) {
      this.setBoot(boot);
      var q = new URLSearchParams();
      q.set("mode", boot.mode);
      q.set("slot", String(boot.slot | 0));
      if (boot.name) q.set("name", boot.name);
      if (boot.cls) q.set("cls", boot.cls);
      return "shadow-depths.html?" + q.toString() + savesHash();
    },
    hrefTo: function (file) {
      return pageName(file) + savesHash();
    },
    isValid: isValid,
    exportSlot: function (i) {
      var s = this.getSlot(i);
      if (!s) return "";
      return "----- GLOAMRIFT ARCHIVE -----\nGLOAM1." + b64(JSON.stringify(s)) + "\n----- END -----";
    },
    parseImport: function (text) {
      text = (text || "").trim();
      if (!text) return { ok: false, err: "没有文字。" };
      var raw = null;
      var m = text.match(/GLOAM1\.([A-Za-z0-9+/=_-]+)/);
      if (m) {
        try { raw = unb64(m[1]); } catch (e) { return { ok: false, err: "卷宗无法解码。" }; }
      } else if (text.charAt(0) === "{") {
        raw = text;
      } else {
        return { ok: false, err: "无法识别这段文字。需要以 GLOAM1. 开头的卷宗。" };
      }
      try {
        var data = JSON.parse(raw);
        if (data && Array.isArray(data.slots)) {
          return { ok: true, kind: "store", data: data };
        }
        if (isValid(data) || (data && data.cls && data.v == null)) {
          if (data.v == null) data.v = VERSION;
          if (!isValid(data)) return { ok: false, err: "卷宗版本或内容无效。" };
          return { ok: true, kind: "slot", data: data };
        }
        return { ok: false, err: "卷宗版本不匹配，已丢弃。" };
      } catch (e) {
        return { ok: false, err: "卷宗已损坏。" };
      }
    },
    importSlot: function (i, data) {
      return this.writeSlot(i, data);
    },
    firstEmptySlot: function () {
      var slots = loadAll().slots;
      for (var i = 0; i < slots.length; i++) if (!slots[i]) return i;
      return -1;
    },
    STASH: 40,
    getStash: function () {
      var data = loadAll();
      if (!Array.isArray(data.stash)) data.stash = [];
      var items = data.stash.filter(function (it) { return it && typeof it === "object"; }).slice(0, 40);
      if (items.length !== data.stash.length) {
        data.stash = items;
        saveAll(data);
      }
      return items;
    },
    setStash: function (items) {
      var data = loadAll();
      data.stash = (items || []).filter(function (it) { return it && typeof it === "object"; }).slice(0, 40);
      saveAll(data);
    },
    classLabel: function (cls) {
      return ({ warrior: "战士", mage: "法师", archer: "弓箭手" })[cls] || cls;
    },
    classEn: function (cls) {
      return ({ warrior: "Ashen Warden", mage: "Rift Scholar", archer: "Eastwatch Ranger" })[cls] || cls;
    },
    formatTime: function (t) {
      if (!t) return "—";
      var d = new Date(t);
      var p = function (n) { return n < 10 ? "0" + n : "" + n; };
      return d.getFullYear() + "." + p(d.getMonth() + 1) + "." + p(d.getDate()) +
        "  " + p(d.getHours()) + ":" + p(d.getMinutes());
    }
  };

  root.GloamSave = api;
})(window);
