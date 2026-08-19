/* Gloamrift · animated abyss backdrop (canvas) */
(function (root) {
  "use strict";

  function start(canvas, opts) {
    opts = opts || {};
    var theme = opts.theme || "title"; // title | forge | archive
    var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    var ctx = canvas.getContext("2d");
    var w = 0, h = 0, t0 = performance.now(), raf = 0, running = true;

    var palettes = {
      title:   { sky0: "#05040a", sky1: "#120c14", sky2: "#2a1810", rift: "#e2a24a", rift2: "#6a3ad8", ash: "#c9a078" },
      forge:   { sky0: "#0a0608", sky1: "#1a0e0c", sky2: "#3a2014", rift: "#ff8a4a", rift2: "#a03020", ash: "#e0a070" },
      archive: { sky0: "#04060a", sky1: "#0c1218", sky2: "#1a2430", rift: "#7aa8d8", rift2: "#4a3a88", ash: "#9ab0c4" }
    };
    var pal = palettes[theme] || palettes.title;

    var stars = [], ash = [], sparks = [], fog = [];

    function resize() {
      var dpr = Math.min(window.devicePixelRatio || 1, 2);
      w = canvas.clientWidth;
      h = canvas.clientHeight;
      canvas.width = Math.floor(w * dpr);
      canvas.height = Math.floor(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    function seed() {
      stars = []; ash = []; sparks = []; fog = [];
      var i;
      for (i = 0; i < 90; i++) {
        stars.push({
          x: Math.random(), y: Math.random() * 0.62,
          r: Math.random() * 1.2 + 0.3,
          a: Math.random() * 0.55 + 0.15,
          tw: Math.random() * 3 + 1
        });
      }
      for (i = 0; i < (reduce ? 24 : 110); i++) {
        ash.push({
          x: Math.random(), y: Math.random(),
          s: Math.random() * 1.8 + 0.4,
          v: Math.random() * 0.035 + 0.01,
          drift: (Math.random() - 0.5) * 0.02,
          a: Math.random() * 0.45 + 0.12
        });
      }
      var riftX = theme === "forge" ? 0.22 : theme === "archive" ? 0.78 : 0.5;
      for (i = 0; i < (reduce ? 8 : 36); i++) {
        sparks.push({
          x: riftX + (Math.random() - 0.5) * 0.08,
          y: Math.random() * 0.7 + 0.15,
          v: Math.random() * 0.06 + 0.02,
          life: Math.random(),
          hue: Math.random()
        });
      }
      for (i = 0; i < 5; i++) {
        fog.push({
          y: 0.45 + i * 0.1,
          x: Math.random(),
          w: 0.7 + Math.random() * 0.5,
          a: 0.04 + i * 0.015,
          v: (i % 2 ? 1 : -1) * (0.008 + i * 0.002)
        });
      }
    }

    function riftPath(time) {
      var cx = w * (theme === "forge" ? 0.22 : theme === "archive" ? 0.78 : 0.5);
      var top = h * 0.08, bot = h * 0.78;
      var wob = reduce ? 0 : Math.sin(time * 0.6) * 3;
      ctx.beginPath();
      ctx.moveTo(cx - 7 + wob, top);
      var steps = 18;
      for (var i = 1; i <= steps; i++) {
        var p = i / steps;
        var jx = Math.sin(p * 14 + time * 0.4) * (6 + p * 8);
        ctx.lineTo(cx - 4 + jx * (i % 2 ? 1 : -0.6) + wob * (1 - p), top + (bot - top) * p);
      }
      for (i = steps; i >= 0; i--) {
        var p2 = i / steps;
        var jx2 = Math.sin(p2 * 14 + time * 0.4 + 1.7) * (5 + p2 * 7);
        ctx.lineTo(cx + 4 + jx2 * (i % 2 ? -1 : 0.5) + wob * (1 - p2), top + (bot - top) * p2);
      }
      ctx.closePath();
      return { cx: cx, top: top, bot: bot };
    }

    function drawBridge(time) {
      var ground = h * 0.78;
      ctx.fillStyle = "#07060a";
      ctx.beginPath();
      ctx.moveTo(0, h);
      ctx.lineTo(0, ground + 20);
      ctx.quadraticCurveTo(w * 0.18, ground - 40, w * 0.32, ground + 8);
      ctx.lineTo(w * 0.42, ground + 18);
      ctx.lineTo(w * 0.58, ground + 18);
      ctx.lineTo(w * 0.68, ground + 8);
      ctx.quadraticCurveTo(w * 0.82, ground - 36, w, ground + 24);
      ctx.lineTo(w, h);
      ctx.closePath();
      ctx.fill();

      // broken span
      ctx.strokeStyle = "rgba(176,141,79,0.28)";
      ctx.lineWidth = 2;
      var yb = ground - 8 + (reduce ? 0 : Math.sin(time * 0.5) * 1.2);
      ctx.beginPath();
      ctx.moveTo(w * 0.12, yb + 22);
      ctx.lineTo(w * 0.38, yb);
      ctx.lineTo(w * 0.44, yb + 6);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(w * 0.56, yb + 6);
      ctx.lineTo(w * 0.62, yb);
      ctx.lineTo(w * 0.88, yb + 20);
      ctx.stroke();

      // piers
      ctx.fillStyle = "#0c0a10";
      [[0.22, 38], [0.78, 34]].forEach(function (p) {
        ctx.fillRect(w * p[0] - 10, yb, 20, h - yb);
        ctx.fillStyle = "rgba(176,141,79,0.12)";
        ctx.fillRect(w * p[0] - 12, yb - 6, 24, 8);
        ctx.fillStyle = "#0c0a10";
      });
    }

    function draw(now) {
      if (!running) return;
      var time = (now - t0) / 1000;
      var palNow = pal;
      ctx.clearRect(0, 0, w, h);

      var g = ctx.createLinearGradient(0, 0, 0, h);
      g.addColorStop(0, palNow.sky0);
      g.addColorStop(0.45, palNow.sky1);
      g.addColorStop(0.72, palNow.sky2);
      g.addColorStop(1, "#050408");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, w, h);

      // horizon ember
      var hg = ctx.createRadialGradient(w * 0.5, h * 0.76, 10, w * 0.5, h * 0.76, w * 0.55);
      hg.addColorStop(0, theme === "archive" ? "rgba(80,110,150,0.18)" : "rgba(180,80,30,0.22)");
      hg.addColorStop(1, "rgba(0,0,0,0)");
      ctx.fillStyle = hg;
      ctx.fillRect(0, h * 0.4, w, h * 0.6);

      stars.forEach(function (s) {
        var a = s.a * (0.55 + 0.45 * Math.sin(time * s.tw + s.x * 12));
        ctx.fillStyle = "rgba(232,220,190," + a + ")";
        ctx.beginPath();
        ctx.arc(s.x * w, s.y * h, s.r, 0, Math.PI * 2);
        ctx.fill();
      });

      var rift = riftPath(time);
      var pulse = 0.55 + 0.45 * Math.sin(time * 1.1);
      var rg = ctx.createRadialGradient(rift.cx, h * 0.42, 8, rift.cx, h * 0.48, h * 0.55);
      rg.addColorStop(0, "rgba(226,162,74," + (0.22 * pulse) + ")");
      rg.addColorStop(0.35, "rgba(106,58,216," + (0.10 * pulse) + ")");
      rg.addColorStop(1, "rgba(0,0,0,0)");
      ctx.fillStyle = rg;
      ctx.fillRect(0, 0, w, h);

      ctx.save();
      ctx.shadowColor = palNow.rift;
      ctx.shadowBlur = 28 + pulse * 18;
      ctx.fillStyle = palNow.rift;
      ctx.globalAlpha = 0.55 + pulse * 0.25;
      ctx.fill();
      ctx.restore();

      ctx.save();
      riftPath(time);
      ctx.globalCompositeOperation = "lighter";
      var ig = ctx.createLinearGradient(rift.cx, rift.top, rift.cx, rift.bot);
      ig.addColorStop(0, "rgba(255,240,200,0.0)");
      ig.addColorStop(0.35, palNow.rift);
      ig.addColorStop(0.7, palNow.rift2);
      ig.addColorStop(1, "rgba(0,0,0,0)");
      ctx.fillStyle = ig;
      ctx.globalAlpha = 0.85;
      ctx.fill();
      ctx.restore();

      sparks.forEach(function (s) {
        if (!reduce) {
          s.y -= s.v * 0.012;
          s.life -= 0.006;
          if (s.y < 0.12 || s.life <= 0) {
            s.y = 0.72; s.life = 1;
            s.x = 0.5 + (Math.random() - 0.5) * 0.06;
            if (theme === "forge") s.x = 0.22 + (Math.random() - 0.5) * 0.06;
            if (theme === "archive") s.x = 0.78 + (Math.random() - 0.5) * 0.06;
          }
        }
        ctx.globalAlpha = Math.max(0, s.life) * 0.7;
        ctx.fillStyle = s.hue > 0.5 ? palNow.rift : "#fff4d0";
        ctx.beginPath();
        ctx.arc(s.x * w, s.y * h, 1.4, 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1;
      });

      fog.forEach(function (f) {
        if (!reduce) f.x += f.v * 0.15;
        if (f.x > 1.4) f.x = -0.4;
        if (f.x < -0.4) f.x = 1.4;
        var fg = ctx.createRadialGradient(f.x * w, f.y * h, 10, f.x * w, f.y * h, w * f.w * 0.5);
        fg.addColorStop(0, "rgba(40,36,48," + f.a + ")");
        fg.addColorStop(1, "rgba(0,0,0,0)");
        ctx.fillStyle = fg;
        ctx.fillRect(0, f.y * h - 80, w, 160);
      });

      ash.forEach(function (p) {
        if (!reduce) {
          p.y -= p.v * 0.25;
          p.x += p.drift * 0.2 + Math.sin(time + p.y * 8) * 0.0008;
          if (p.y < -0.02) { p.y = 1.02; p.x = Math.random(); }
        }
        ctx.globalAlpha = p.a;
        ctx.fillStyle = palNow.ash;
        ctx.fillRect(p.x * w, p.y * h, p.s, p.s * 1.6);
        ctx.globalAlpha = 1;
      });

      drawBridge(time);

      // vignette
      var vg = ctx.createRadialGradient(w * 0.5, h * 0.45, h * 0.2, w * 0.5, h * 0.5, h * 0.78);
      vg.addColorStop(0, "rgba(0,0,0,0)");
      vg.addColorStop(1, "rgba(0,0,0,0.55)");
      ctx.fillStyle = vg;
      ctx.fillRect(0, 0, w, h);

      raf = requestAnimationFrame(draw);
    }

    function onResize() { resize(); }

    resize();
    seed();
    window.addEventListener("resize", onResize);
    raf = requestAnimationFrame(draw);

    return {
      stop: function () {
        running = false;
        cancelAnimationFrame(raf);
        window.removeEventListener("resize", onResize);
      }
    };
  }

  function attach(selector, opts) {
    var el = typeof selector === "string" ? document.querySelector(selector) : selector;
    if (!el) return null;
    return start(el, opts);
  }

  root.GloamAtmosphere = { start: start, attach: attach };
})(window);
