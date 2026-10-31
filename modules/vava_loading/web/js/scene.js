/*
 * vava_loading/web/js/scene.js
 * Rôle : la scène derrière les textes : ambiances d'Eldoria (T-152) en fondu enchaîné sur deux calques, braises et
 *        étincelles sur un canvas. Fond de repli : le dégradé de .scene, tant qu'aucune ambiance n'est affichée.
 * Coût : un seul setTimeout à la fois pour les ambiances ; fondu et dérive en CSS ; image suivante décodée seulement
 *        après l'affichage de la courante ; braises à 30 i/s au plus ; en `basse`, plus rien d'animé par le script.
 * Dépendances : js/config.js (réglages passés à create), js/quality.js (cadence : due), js/ambiances.js
 */
(function (root) {
  'use strict';

  var VavaLoading = root.VavaLoading = root.VavaLoading || {};

  var TAU = Math.PI * 2;
  var MAX_SPARKS = 600;
  var STEP_MS = 1000 / 60;     // pas de la maquette, pensée à 60 images/s
  var FX_MAX_GAP_MS = 100;     // au-delà (page figée par le chargement), les braises ne sautent pas plus loin
  var PARALLAX_X = 24, PARALLAX_Y = 10; // px de glissement des ambiances, souris d'un bord à l'autre
  var PARALLAX_EVERY_MS = 50;  // cible posée au plus à cette fréquence (transition CSS)
  var due = VavaLoading.quality.due, A = VavaLoading.ambiances;

  function rand(a, b) { return a + Math.random() * (b - a); }
  function now() { return performance.now(); }

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

  function empty(el) { while (el.firstChild) el.removeChild(el.firstChild); }

  /**
   * Ambiances : le calque qui entre passe au-dessus (.top) et s'éclaire (.on) ; l'autre reste plein dessous pendant le
   * fondu (aucun creux de lumière), puis est vidé. Une image n'est montrée qu'une fois décodée.
   * levelFlags() : drapeaux du niveau en cours (drift) ; reducedMotion : jamais de dérive.
   */
  function ambiances(el, raw, levelFlags, reducedMotion) {
    var set = A.settings(raw), st = A.initial(set.files.length);
    var layers = [], front = -1, timer = 0, gen = 0, ready = null, count = 0;
    var running = false, revealedAt = -1, shownAt = 0, fadeEnd = null;
    for (var k = 0; k < 2; k++) {
      var layer = document.createElement('div');
      layer.className = 'amb';
      el.appendChild(layer);
      layers.push(layer);
    }
    el.style.setProperty('--amb-fade', set.fadeMs + 'ms');
    el.style.setProperty('--amb-life', (set.showMs + set.fadeMs) + 'ms');

    // le seul minuteur des ambiances
    function later(fn, ms) {
      clearTimeout(timer);
      timer = setTimeout(function () { timer = 0; fn(); }, Math.max(0, ms));
    }

    // charge et décode l'image i ; en erreur : sautée, la suivante est essayée
    function load(i) {
      var g = gen, img = new Image(), settled = false;
      function done(ok) {
        if (settled) return;
        settled = true;
        img.onload = img.onerror = null;
        if (g !== gen) return; // arrêté entre-temps
        if (ok && img.naturalWidth > 0) { ready = { i: i, img: img }; schedule(); }
        else { st = A.failed(st, i); loadNext(); }
      }
      img.alt = ''; img.decoding = 'async'; img.draggable = false;
      img.onerror = function () { done(false); };
      if (typeof img.decode === 'function') {
        img.src = set.files[i];
        img.decode().then(function () { done(true); }, function () { done(false); });
      } else {
        img.onload = function () { done(true); };
        img.src = set.files[i];
      }
    }

    // plus aucune autre image possible : la boucle s'arrête, l'image à l'écran (ou le fond de repli) reste
    function loadNext() {
      if (!running || ready) return;
      var i = A.pick(st);
      if (i >= 0) load(i);
    }

    // la première aussitôt ; les suivantes showMs après la précédente (la première comptée depuis le rideau)
    function schedule() {
      if (!running || !ready || timer || fadeEnd) return;
      if (st.current < 0) { show(); return; }
      if (revealedAt < 0) return; // reveal() reprendra
      later(show, Math.max(shownAt, revealedAt) + set.showMs - now());
    }

    function show() {
      var r = ready, back = layers[front === 0 ? 1 : 0], top = front >= 0 ? layers[front] : null;
      ready = null;
      if (!r) return;
      empty(back);
      if (A.driftOn(levelFlags(), reducedMotion, set.driftPct)) {
        var d = A.drift(count, set.driftPct);
        r.img.style.setProperty('--s0', String(d.s0)); r.img.style.setProperty('--s1', String(d.s1));
        r.img.style.setProperty('--x0', d.x0 + '%'); r.img.style.setProperty('--x1', d.x1 + '%');
        r.img.style.setProperty('--y0', d.y0 + '%'); r.img.style.setProperty('--y1', d.y1 + '%');
        r.img.className = 'drift';
      }
      back.appendChild(r.img);
      if (top) top.classList.remove('top'); // reste plein dessous pendant le fondu
      back.classList.add('top', 'on');
      front = back === layers[0] ? 0 : 1;
      st = A.shown(st, r.i); count++; shownAt = now();
      el.setAttribute('data-ambiance', set.order[r.i]);
      fadeEnd = function () {
        fadeEnd = null;
        if (top) { top.classList.remove('on'); empty(top); }
        loadNext();
      };
      later(fadeEnd, set.fadeMs);
    }

    return {
      start: function () {
        if (running) return;
        running = true;
        loadNext();
      },
      reveal: function () {
        revealedAt = now();
        schedule();
      },
      stop: function () { // l'image à l'écran reste
        running = false; gen++; ready = null;
        clearTimeout(timer); timer = 0;
        if (fadeEnd) { var end = fadeEnd; end(); } // fondu en cours : terminé tout de suite
      },
      next: function () { // hors jeu : la suivante tout de suite si elle est prête
        if (!running || !ready || fadeEnd || st.current < 0) return;
        clearTimeout(timer); timer = 0;
        show();
      },
      name: function () { return st.current >= 0 ? set.order[st.current] : ''; },
    };
  }

  /**
   * Crée la scène.
   * @param {{fx: HTMLCanvasElement, ambiancesEl: HTMLElement, ambiances: Object, reducedMotion: boolean,
   *          effects: Object, level: string, onDraw?: function(number)}} opts  onDraw(now) : après chaque image
   */
  function create(opts) {
    var fx = opts.fx, effects = opts.effects, fctx = fx.getContext('2d'), stage = opts.ambiancesEl;
    var level = opts.level, lv = effects.levels[level];
    var W = 0, H = 0, DPR = 1;
    var embers = [], sparks = [], emberSprite = null, sparkSprite = null;
    var mouse = { x: 0, y: 0, tx: 0, ty: 0 }, parallaxAt = 0;
    var last = 0, raf = 0, running = false;
    var meter = { start: 0, frames: 0, fps: 0 };
    var resizeTimer = 0;
    var amb = ambiances(stage, opts.ambiances, function () { return lv; }, !!opts.reducedMotion);

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
      W = fx.clientWidth; H = fx.clientHeight;
      fx.width = Math.max(1, Math.round(W * DPR)); fx.height = Math.max(1, Math.round(H * DPR));
      if (!emberSprite) {
        emberSprite = glowSprite('208,138,60', 64);
        sparkSprite = glowSprite('255,150,60', 64);
      }
      embers = []; buildEmbers();
      sparks = [];
    }

    // braises et étincelles : couche du dessus ; elles suivent la souris (parallaxe, lissée ici)
    function drawFx(f) {
      var ctx = fctx, i;
      if (lv.parallax) {
        var ease = 1 - Math.pow(0.96, f);
        mouse.x += (mouse.tx - mouse.x) * ease; mouse.y += (mouse.ty - mouse.y) * ease;
      } else { mouse.x = 0; mouse.y = 0; }
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

    function frame(t) {
      raf = 0;
      if (!running) return;
      raf = requestAnimationFrame(frame);
      if (!due(last, t, effects.fpsMax)) return; // braises : 30 images/s au plus
      var dt = last ? Math.min(t - last, FX_MAX_GAP_MS) : STEP_MS;
      last = t;
      drawFx(dt / STEP_MS);
      if (t - meter.start >= 1000) {
        meter.fps = meter.frames * 1000 / (t - meter.start);
        meter.start = t; meter.frames = 0;
      }
      meter.frames++;
      if (opts.onDraw) opts.onDraw(t);
    }

    function startLoop() {
      if (running) return;
      running = true; last = 0;
      meter.start = now(); meter.frames = 0;
      raf = requestAnimationFrame(frame);
    }

    function stopLoop() {
      running = false;
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
    }

    /** Niveau basse : braises et étincelles effacées, canvas rendu à 1 pixel, plus aucune image animée. */
    function quiet() {
      stopLoop();
      sparks = []; embers = [];
      fctx.setTransform(1, 0, 0, 1, 0, 0); fctx.clearRect(0, 0, fx.width, fx.height);
      fx.width = 1; fx.height = 1; // mémoire rendue
      meter.fps = 0;
    }

    function parallax(nx, ny) {
      stage.style.transform = lv.parallax
        ? 'translate3d(' + (-nx * PARALLAX_X).toFixed(1) + 'px,' + (-ny * PARALLAX_Y).toFixed(1) + 'px,0)'
        : '';
    }

    function onResize() {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function () { if (level !== 'basse') build(); }, 200);
    }

    return {
      /** Démarre les braises (sauf en basse) et les ambiances (la première s'affiche dès qu'elle est décodée). */
      start: function () {
        window.removeEventListener('resize', onResize);
        window.addEventListener('resize', onResize);
        if (level === 'basse') quiet(); else { build(); startLoop(); }
        amb.start();
      },
      /** Rideau levé : la tenue de la première ambiance part d'ici. */
      reveal: function () { amb.reveal(); },
      /** Arrête braises et ambiances (éclair terminé) ; la dernière image reste. */
      stop: function () {
        stopLoop();
        amb.stop();
        window.removeEventListener('resize', onResize);
        clearTimeout(resizeTimer);
      },
      /** Change de niveau (dégradation) sans repartir de zéro. */
      setLevel: function (name) {
        if (!effects.levels[name] || name === level) return;
        level = name; lv = effects.levels[name];
        if (!lv.parallax) parallax(0, 0);
        if (level === 'basse') quiet(); else buildEmbers();
      },
      /** Gerbe d'étincelles en (x, y), coordonnées de la scène. */
      burst: function (x, y, n, power) {
        if (!running || !n) return;
        for (var i = 0; i < n && sparks.length < MAX_SPARKS; i++) {
          var a = rand(0, TAU), v = rand(0.5, 1) * power;
          sparks.push({ x: x, y: y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - power * 0.4, life: 1, r: rand(0.6, 2.2) });
        }
      },
      /** Position de la souris, de -0.5 à 0.5 sur chaque axe (parallaxe des braises et des ambiances). */
      pointer: function (nx, ny) {
        mouse.tx = nx; mouse.ty = ny;
        var t = now();
        if (lv.parallax && t - parallaxAt >= PARALLAX_EVERY_MS) { parallaxAt = t; parallax(nx, ny); }
      },
      /** Cadence mesurée des braises (images par seconde ; 0 en basse). */
      fps: function () { return running ? meter.fps : 0; },
      /** Nom de l'ambiance à l'écran ('' tant qu'aucune). */
      ambiance: function () { return amb.name(); },
      /** Hors jeu : ambiance suivante tout de suite (si elle est déjà décodée). */
      nextAmbiance: function () { amb.next(); },
      level: function () { return level; },
    };
  }

  VavaLoading.scene = { create: create };
})(window);
