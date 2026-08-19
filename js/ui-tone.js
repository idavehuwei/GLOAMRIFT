/* Gloamrift · light UI tones for menu pages */
(function (root) {
  "use strict";
  var ctx = null, on = true;
  function ac() {
    if (!ctx) {
      try { ctx = new (window.AudioContext || window.webkitAudioContext)(); }
      catch (e) { on = false; }
    }
    return ctx;
  }
  function tone(f, d, type, v, s) {
    if (!on) return;
    var c = ac(); if (!c) return;
    if (c.state === "suspended") c.resume();
    var o = c.createOscillator(), g = c.createGain();
    o.type = type || "sine";
    o.frequency.setValueAtTime(f, c.currentTime);
    if (s) o.frequency.exponentialRampToValueAtTime(Math.max(30, s), c.currentTime + d);
    g.gain.setValueAtTime(0.0001, c.currentTime);
    g.gain.exponentialRampToValueAtTime(v || 0.06, c.currentTime + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + d);
    o.connect(g); g.connect(c.destination);
    o.start(); o.stop(c.currentTime + d + 0.02);
  }
  root.GloamTone = {
    hover: function () { tone(720, 0.05, "triangle", 0.03, 1100); },
    click: function () { tone(420, 0.09, "square", 0.045, 180); },
    confirm: function () {
      tone(330, 0.18, "sine", 0.06, 660);
      setTimeout(function () { tone(520, 0.28, "triangle", 0.05, 880); }, 90);
    },
    deny: function () { tone(180, 0.16, "sawtooth", 0.04, 70); }
  };
})(window);
