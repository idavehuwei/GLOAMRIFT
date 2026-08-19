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
    return { v: VERSION, slots: slots };
  }

  function loadAll() {
    try {
      var raw = localStorage.getItem(KEY);
      if (!raw) return empty();
      var data = JSON.parse(raw);
      if (!data || data.v !== VERSION || !Array.isArray(data.slots)) return empty();
      while (data.slots.length < SLOTS) data.slots.push(null);
      return data;
    } catch (e) {
      return empty();
    }
  }

  function saveAll(data) {
    localStorage.setItem(KEY, JSON.stringify(data));
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
          if (data && data.v === VERSION && Array.isArray(data.slots)) saveAll(data);
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
      var data = loadAll();
      payload = payload || {};
      payload.v = VERSION;
      payload.t = Date.now();
      payload.slot = i;
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
