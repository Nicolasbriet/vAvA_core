/*
 * vava_loading/web/js/scene.js
 * Rôle : le paysage de nuit peint par le code (dessin et couleurs de la maquette docs/maquettes/Chargement.html) : quatre
 *        plans de crêtes et de forêts, château aux fenêtres qui vacillent, étoiles, lune, étoile filante, brume ; sur un
 *        second canvas, les braises qui montent et les gerbes d'étincelles. Le ciel est le dégradé CSS du fond de .scene.
 * Coût (spec T-020 § 8.3) : 30 images/s au plus (une image sautée si la précédente a moins de 33 ms) ; canvas à 1 pixel
 *        par point ; lune et halo, brume et lueurs peints une fois en petits sprites posés par drawImage ; étoiles en 8
 *        paliers d'éclat ; calques des crêtes rognés à leur hauteur utile ; niveau `basse` : paysage peint une fois (et
 *        à chaque redimensionnement), calques libérés, plus aucune image animée.
 * Dépendances : js/config.js (réglages passés à create)
 */
(function (root) {
  'use strict';

  var VavaLoading = root.VavaLoading = root.VavaLoading || {};

  var TAU = Math.PI * 2;
  var STAR_BUCKETS = 8;
  var MAX_SPARKS = 600;
  var COMET_PER_SECOND = 0.15; // chance qu'une étoile filante parte, par seconde (≈ une toutes les 7 s)

  function rand(a, b) { return a + Math.random() * (b - a); }

  // Bruit 1D lissé (somme de six sinusoïdes à phases tirées) : des crêtes qui ne se répètent pas.
  function ridgeFn(seed, rough) {
    var p = [];
    for (var i = 0; i < 6; i++) {
      p.push({ f: (i + 1) * 0.0013 * (1 + seed * 0.13) * Math.pow(1.9, i), a: Math.pow(0.52, i), ph: rand(0, 6.28) });
    }
    return function (x) {
      var v = 0;
      for (var k = 0; k < p.length; k++) v += Math.sin(x * p[k].f + p[k].ph) * p[k].a * (k > 2 ? rough : 1);
      return v;
    };
  }

  // Plans du paysage, du plus lointain au plus proche (maquette).
  var LAYERS = [
    { seed: 1, base: 0.60, amp: 0.13, rough: 0.6, c1: '#2a2230', c2: '#17131b', rim: 'rgba(220,192,138,0.22)', depth: 0.15 },
    { seed: 2, base: 0.70, amp: 0.10, rough: 0.8, c1: '#1c1720', c2: '#120e12', rim: 'rgba(220,192,138,0.12)', depth: 0.35,
      castle: true },
    { seed: 3, base: 0.80, amp: 0.07, rough: 1.0, c1: '#120e0e', c2: '#0b0808', depth: 0.6, trees: 0.8 },
    { seed: 4, base: 0.92, amp: 0.05, rough: 1.2, c1: '#070504', c2: '#050303', depth: 1.0, trees: 1.5 },
  ];

  // Corps du château : [x relatif, largeur, hauteur, toit].
  var CASTLE = [
    [-150, 34, 120, 'cone'], [-110, 120, 70, 'crenel'], [-60, 46, 175, 'cone'], [-14, 90, 110, 'crenel'],
    [20, 30, 230, 'spire'], [60, 70, 90, 'crenel'], [118, 40, 150, 'cone'], [150, 80, 60, 'crenel'], [215, 26, 95, 'cone'],
  ];

  function canvas(w, h) {
    var c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(w)); c.height = Math.max(1, Math.round(h));
    return c;
  }

  /** Sprite de dégradé radial (couleur « r,g,b » pleine au centre, transparente au bord), peint une fois. */
  function glowSprite(rgb, size) {
    var c = canvas(size, size), g = c.getContext('2d'), r = size / 2;
    var grad = g.createRadialGradient(r, r, 0, r, r, r);
    grad.addColorStop(0, 'rgba(' + rgb + ',1)');
    grad.addColorStop(1, 'rgba(' + rgb + ',0)');
    g.fillStyle = grad; g.fillRect(0, 0, size, size);
    return c;
  }

  /**
   * Crée le peintre de la scène.
   * @param {{world: HTMLCanvasElement, fx: HTMLCanvasElement, effects: Object, level: string,
   *          onDraw?: function(number)}} opts  onDraw(now) : appelé après chaque image dessinée (mesure de cadence)
   */
  function create(opts) {
    var world = opts.world, fx = opts.fx, effects = opts.effects;
    var wctx = world.getContext('2d'), fctx = fx.getContext('2d');
    var level = opts.level, lv = effects.levels[level];
    var W = 0, H = 0, DPR = 1;
    var layers = [], windows = [], buckets = [], fogs = [], embers = [], sparks = [], comet = null;
    var moon = null, fogSprite = null, emberSprite = null, sparkSprite = null;
    var mouse = { x: 0, y: 0, tx: 0, ty: 0 };
    var t0 = performance.now(), last = 0, raf = 0, running = false, painted = false;
    var meter = { start: 0, frames: 0, fps: 0 };
    var resizeTimer = 0;

    // ------------------------------------------------------------------ calques peints une fois

    function paintLayer(opt) {
      var lw = Math.ceil(W * 1.16), f = ridgeFn(opt.seed, opt.rough), top = [], minTop = H, x, y;
      for (x = 0; x <= lw; x += 4) {
        y = H * opt.base - f(x) * H * opt.amp;
        top.push(y); if (y < minTop) minTop = y;
      }
      var s = Math.min(W, H) / 900;
      var margin = Math.max(opt.trees ? 34 * opt.trees + 6 : 2, opt.castle ? 300 * s + 12 : 0);
      var y0 = Math.max(0, Math.floor(minTop - margin)), lh = H - y0; // rogné : de la plus haute crête au bas
      var c = canvas(lw * DPR, lh * DPR), g = c.getContext('2d');
      g.setTransform(DPR, 0, 0, DPR, 0, -y0 * DPR);
      g.beginPath(); g.moveTo(0, H);
      for (var i = 0; i < top.length; i++) g.lineTo(i * 4, top[i]);
      g.lineTo(lw, H); g.closePath();
      var grad = g.createLinearGradient(0, H * (opt.base - opt.amp), 0, H);
      grad.addColorStop(0, opt.c1); grad.addColorStop(1, opt.c2);
      g.fillStyle = grad; g.fill();
      if (opt.rim) { // lisière éclairée par la lune
        g.strokeStyle = opt.rim; g.lineWidth = 1; g.beginPath();
        for (var j = 0; j < top.length; j++) { if (j === 0) g.moveTo(0, top[0]); else g.lineTo(j * 4, top[j]); }
        g.stroke();
      }
      if (opt.trees) paintTrees(g, top, lw, opt);
      if (opt.castle) paintCastle(g, top, lw, opt, s);
      return { canvas: c, depth: opt.depth, w: lw, h: lh, y0: y0 };
    }

    function paintTrees(g, top, lw, opt) {
      g.fillStyle = opt.c1;
      for (var x = 0; x < lw; x += rand(5, 11)) {
        var y = top[Math.min(top.length - 1, Math.floor(x / 4))], h = rand(14, 34) * opt.trees;
        g.beginPath(); g.moveTo(x - h * 0.22, y + 4); g.lineTo(x, y - h); g.lineTo(x + h * 0.22, y + 4); g.closePath(); g.fill();
      }
    }

    function paintCastle(g, top, lw, opt, s) {
      var cx = lw * 0.64, gy = top[Math.floor(cx / 4)] + 6;
      g.fillStyle = opt.c1;
      windows = [];
      CASTLE.forEach(function (p) {
        var x = cx + p[0] * s, w = p[1] * s, h = p[2] * s, y = gy - h;
        g.fillRect(x - w / 2, y, w, h + 10);
        if (p[3] === 'cone' || p[3] === 'spire') {
          var rh = (p[3] === 'spire' ? 1.6 : 0.9) * w;
          g.beginPath(); g.moveTo(x - w / 2 - 3 * s, y); g.lineTo(x, y - rh); g.lineTo(x + w / 2 + 3 * s, y); g.closePath(); g.fill();
          if (p[3] === 'spire') { g.fillRect(x - 0.6, y - rh - 14 * s, 1.2, 14 * s); g.fillRect(x, y - rh - 14 * s, 9 * s, 5 * s); }
        } else {
          for (var k = -w / 2; k < w / 2 - 4 * s; k += 9 * s) g.fillRect(x + k, y - 6 * s, 5 * s, 6 * s);
        }
        // fenêtres : gardées pour vaciller à chaque image (coordonnées du calque avant rognage)
        var rows = Math.max(1, Math.floor(h / (34 * s)));
        for (var r = 0; r < rows; r++) {
          if (Math.random() < 0.55) {
            windows.push({ x: x + rand(-w / 3, w / 3), y: y + 18 * s + r * 30 * s, w: 3.2 * s + 1, h: 6 * s + 2,
              ph: rand(0, 6.28), sp: rand(1.5, 4), dim: Math.random() < 0.25 });
          }
        }
      });
    }

    function paintMoon() {
      var mr = Math.min(W, H) * 0.055, R = Math.ceil(mr * 7) + 1;
      var c = canvas(R * 2, R * 2), g = c.getContext('2d');
      var halo = g.createRadialGradient(R, R, mr * 0.8, R, R, mr * 7);
      halo.addColorStop(0, 'rgba(247,231,189,0.28)'); halo.addColorStop(1, 'rgba(247,231,189,0)');
      g.fillStyle = halo; g.beginPath(); g.arc(R, R, mr * 7, 0, TAU); g.fill();
      var disc = g.createRadialGradient(R - mr * 0.3, R - mr * 0.3, mr * 0.1, R, R, mr);
      disc.addColorStop(0, '#fff6dc'); disc.addColorStop(1, '#d9c393');
      g.fillStyle = disc; g.beginPath(); g.arc(R, R, mr, 0, TAU); g.fill();
      g.fillStyle = 'rgba(150,120,80,0.18)';
      g.beginPath(); g.arc(R + mr * 0.25, R - mr * 0.1, mr * 0.22, 0, TAU); g.arc(R - mr * 0.3, R + mr * 0.3, mr * 0.14, 0, TAU); g.fill();
      return { canvas: c, r: R };
    }

    // ------------------------------------------------------------------ éléments animés

    function buildStars() {
      var n = Math.min(lv.stars, Math.round(W * H / 4200));
      buckets = [];
      for (var b = 0; b < STAR_BUCKETS; b++) buckets.push({ ph: rand(0, 6.28), sp: rand(0.6, 2.2), stars: [] });
      for (var i = 0; i < n; i++) {
        buckets[i % STAR_BUCKETS].stars.push({ x: Math.random(), y: Math.pow(Math.random(), 1.6) * 0.62, r: rand(0.3, 1.3) });
      }
    }
    function buildFogs() {
      fogs = [];
      for (var j = 0; j < lv.fogs; j++) {
        fogs.push({ x: rand(0, W), y: H * rand(0.6, 0.9), r: rand(220, 420), v: rand(0.04, 0.16) * (Math.random() < 0.5 ? 1 : -1),
          a: rand(0.03, 0.07) });
      }
    }
    function newEmber(anywhere) {
      return { x: rand(0, W), y: anywhere ? rand(0, H) : H + 10, r: rand(0.6, 2), vy: rand(0.2, 0.6), sw: rand(0, 6.28), life: rand(0.4, 1) };
    }
    function emberCount() { return Math.round(Math.min(lv.embers, W * H / 16000)); }
    function buildEmbers() {
      var m = emberCount();
      if (embers.length > m) embers.length = m;
      while (embers.length < m) embers.push(newEmber(true));
    }

    function build() {
      DPR = Math.min(window.devicePixelRatio || 1, effects.maxPixelRatio || 1);
      W = world.clientWidth; H = world.clientHeight;
      [world, fx].forEach(function (c) { c.width = Math.max(1, Math.round(W * DPR)); c.height = Math.max(1, Math.round(H * DPR)); });
      layers = LAYERS.map(paintLayer);
      moon = paintMoon();
      if (!fogSprite) {
        fogSprite = glowSprite('190,175,160', 256);
        emberSprite = glowSprite('208,138,60', 64);
        sparkSprite = glowSprite('255,150,60', 64);
      }
      buildStars(); buildFogs();
      embers = []; buildEmbers();
      sparks = []; comet = null;
    }

    // ------------------------------------------------------------------ dessin

    // freeze : dernière image avant de passer en basse (caméra et souris gardées là où elles sont, sans saut)
    function drawWorld(t, f, freeze) {
      var ctx = wctx, i, k;
      if (lv.parallax) {
        var ease = 1 - Math.pow(0.96, f);
        mouse.x += (mouse.tx - mouse.x) * ease; mouse.y += (mouse.ty - mouse.y) * ease;
      } else if (!freeze) { mouse.x = 0; mouse.y = 0; }
      // caméra : avance lente sur une minute
      var camera = lv.camera || freeze;
      var push = camera ? 1.02 + 0.05 * (0.5 - 0.5 * Math.cos(Math.min(1, t / 60) * Math.PI)) : 1.02;
      var sway = camera ? Math.sin(t * 0.03) * 10 : 0;
      ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
      ctx.clearRect(0, 0, W, H); // le ciel est le fond CSS de .scene
      ctx.save();
      ctx.translate(W / 2, H * 0.62); ctx.scale(push, push); ctx.translate(-W / 2, -H * 0.62);

      // étoiles : 8 paliers d'éclat, une couleur, une opacité par palier
      ctx.fillStyle = 'rgb(240,228,205)';
      var sx = -mouse.x * 4, sy = -mouse.y * 3;
      for (k = 0; k < buckets.length; k++) {
        var b = buckets[k];
        ctx.globalAlpha = 0.8 * (0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t * b.sp + b.ph)));
        for (i = 0; i < b.stars.length; i++) {
          var s = b.stars[i];
          ctx.fillRect(s.x * W + sx, s.y * H + sy, s.r, s.r);
        }
      }
      ctx.globalAlpha = 1;

      // lune et son halo (sprite)
      ctx.drawImage(moon.canvas, W * 0.74 - mouse.x * 8 - moon.r, H * 0.2 - mouse.y * 6 - moon.r);

      // étoile filante, de loin en loin (haute seulement)
      if (lv.comet && f > 0) {
        if (!comet && Math.random() < COMET_PER_SECOND * f / 60) {
          comet = { x: rand(W * 0.1, W * 0.6), y: rand(H * 0.05, H * 0.25), vx: rand(7, 11), vy: rand(2, 4), life: 1 };
        }
        if (comet) {
          var cg = ctx.createLinearGradient(comet.x, comet.y, comet.x - comet.vx * 14, comet.y - comet.vy * 14);
          cg.addColorStop(0, 'rgba(255,245,220,' + comet.life + ')'); cg.addColorStop(1, 'rgba(255,245,220,0)');
          ctx.strokeStyle = cg; ctx.lineWidth = 1.4; ctx.beginPath();
          ctx.moveTo(comet.x, comet.y); ctx.lineTo(comet.x - comet.vx * 14, comet.y - comet.vy * 14); ctx.stroke();
          comet.x += comet.vx * f; comet.y += comet.vy * f; comet.life -= 0.02 * f;
          if (comet.life <= 0) comet = null;
        }
      }

      // plans, du plus lointain au plus proche, brume entre eux
      for (var l = 0; l < layers.length; l++) {
        var L = layers[l];
        var ox = -(L.w - W) / 2 - mouse.x * 30 * L.depth - sway * L.depth;
        var oy = -mouse.y * 12 * L.depth;
        ctx.drawImage(L.canvas, ox, oy + L.y0, L.w, L.h);
        if (l === 1) drawWindows(ctx, t, ox, oy);
        if (l < layers.length - 1) {
          for (var j = l; j < fogs.length; j += layers.length) {
            var fg = fogs[j];
            fg.x += fg.v * f;
            if (fg.x - fg.r > W) fg.x = -fg.r;
            if (fg.x + fg.r < 0) fg.x = W + fg.r;
            ctx.globalAlpha = fg.a;
            ctx.drawImage(fogSprite, fg.x - fg.r + ox * 0.2, fg.y - fg.r, fg.r * 2, fg.r * 2);
          }
          ctx.globalAlpha = 1;
        }
      }
      ctx.restore();
    }

    // fenêtres du château : la lumière des chandelles vacille (fixe en basse)
    function drawWindows(ctx, t, ox, oy) {
      for (var k = 0; k < windows.length; k++) {
        var w = windows[k];
        var fl = running ? 0.55 + 0.45 * Math.sin(t * w.sp + w.ph) * Math.sin(t * w.sp * 1.7) : 0.55;
        var al = w.dim ? 0.25 : 0.7 + 0.3 * fl;
        var wx = w.x + ox, wy = w.y + oy;
        ctx.fillStyle = 'rgba(255,179,92,' + (al * 0.18) + ')';
        ctx.fillRect(wx - 3, wy - 3, w.w + 6, w.h + 6);
        ctx.fillStyle = 'rgba(255,200,120,' + al + ')';
        ctx.fillRect(wx, wy, w.w, w.h);
      }
    }

    // braises et étincelles : couche du dessus, hors caméra
    function drawFx(f) {
      var ctx = fctx, i;
      ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
      ctx.clearRect(0, 0, W, H);
      if (!embers.length && !sparks.length) return;
      ctx.globalCompositeOperation = 'lighter';
      ctx.fillStyle = 'rgb(255,190,110)';
      for (i = 0; i < embers.length; i++) {
        var e = embers[i];
        e.y -= e.vy * f; e.sw += 0.012 * f;
        if (e.y < -10) { embers[i] = newEmber(false); continue; }
        var x = e.x + Math.sin(e.sw) * 16 - mouse.x * 40;
        var fade = Math.max(0, Math.min(1, e.y / H)) * e.life;
        ctx.globalAlpha = 0.1 * fade;
        ctx.drawImage(emberSprite, x - e.r * 4, e.y - e.r * 4, e.r * 8, e.r * 8);
        ctx.globalAlpha = 0.9 * fade;
        ctx.beginPath(); ctx.arc(x, e.y, e.r, 0, TAU); ctx.fill();
      }
      ctx.fillStyle = 'rgb(255,200,120)';
      var drag = Math.pow(0.985, f);
      for (var j = sparks.length - 1; j >= 0; j--) {
        var s = sparks[j];
        s.x += s.vx * f; s.y += s.vy * f; s.vy += 0.05 * f; s.vx *= drag; s.life -= 0.018 * f;
        if (s.life <= 0) { sparks.splice(j, 1); continue; }
        ctx.globalAlpha = s.life;
        ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, TAU); ctx.fill();
        ctx.globalAlpha = s.life * 0.15;
        ctx.drawImage(sparkSprite, s.x - s.r * 5, s.y - s.r * 5, s.r * 10, s.r * 10);
      }
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = 'source-over';
    }

    function frame(now) {
      raf = 0;
      if (!running) return;
      raf = requestAnimationFrame(frame);
      var gap = 1000 / (effects.fpsMax || 30) - 1;
      if (last && now - last < gap) return; // 30 images/s au plus
      var dt = last ? Math.min(now - last, 100) : 1000 / 60;
      last = now;
      var f = dt / (1000 / 60); // pas de la maquette, pensée à 60 images/s
      drawWorld((now - t0) / 1000, f);
      drawFx(f);
      if (now - meter.start >= 1000) { meter.fps = meter.frames * 1000 / (now - meter.start); meter.start = now; meter.frames = 0; }
      meter.frames++;
      if (opts.onDraw) opts.onDraw(now);
    }

    /** Niveau basse : une seule image du paysage, calques libérés, braises effacées. */
    function paintStatic(freezeAt) {
      sparks = []; embers = []; comet = null;
      if (freezeAt === undefined) mouse.x = mouse.y = 0;
      drawWorld(freezeAt || 0, 0, freezeAt !== undefined);
      fctx.setTransform(1, 0, 0, 1, 0, 0); fctx.clearRect(0, 0, fx.width, fx.height);
      fx.width = 1; fx.height = 1; // mémoire rendue
      layers = []; painted = true;
      meter.fps = 0;
    }

    function startLoop() {
      if (running) return;
      running = true; last = 0; meter.start = performance.now(); meter.frames = 0;
      raf = requestAnimationFrame(frame);
    }

    function stopLoop() {
      running = false;
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
    }

    function onResize() {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function () {
        build();
        if (level === 'basse') paintStatic();
      }, 200);
    }

    var api = {
      /** Construit les calques et démarre (ou peint une fois en basse). */
      start: function () {
        window.removeEventListener('resize', onResize);
        window.addEventListener('resize', onResize);
        t0 = performance.now();
        build();
        if (level === 'basse') paintStatic(); else { painted = false; startLoop(); }
      },
      /** Arrête l'animation (éclair terminé) ; le dernier dessin reste. */
      stop: function () {
        stopLoop();
        window.removeEventListener('resize', onResize);
        clearTimeout(resizeTimer);
      },
      /** Change de niveau (dégradation) sans repartir de zéro. */
      setLevel: function (name) {
        if (!effects.levels[name] || name === level) return;
        level = name; lv = effects.levels[name];
        buildStars();
        if (fogs.length > lv.fogs) fogs.length = lv.fogs;
        if (level === 'basse') {
          var wasRunning = running;
          stopLoop();
          if (!layers.length) build();
          paintStatic(wasRunning ? (performance.now() - t0) / 1000 : undefined);
        } else {
          buildEmbers();
          if (!lv.comet) comet = null;
        }
      },
      /** Gerbe d'étincelles en (x, y), coordonnées de la scène. */
      burst: function (x, y, n, power) {
        if (!running || !n) return;
        for (var i = 0; i < n && sparks.length < MAX_SPARKS; i++) {
          var a = rand(0, TAU), v = rand(0.5, 1) * power;
          sparks.push({ x: x, y: y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - power * 0.4, life: 1, r: rand(0.6, 2.2) });
        }
      },
      /** Position de la souris, de -0.5 à 0.5 sur chaque axe (parallaxe). */
      pointer: function (nx, ny) { mouse.tx = nx; mouse.ty = ny; },
      /** Cadence mesurée (images dessinées par seconde ; 0 en basse). */
      fps: function () { return running ? meter.fps : 0; },
      level: function () { return level; },
      painted: function () { return painted; },
    };
    return api;
  }

  VavaLoading.scene = { create: create };
})(window);
