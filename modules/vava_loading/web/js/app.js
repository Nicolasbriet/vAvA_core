/*
 * vava_loading/web/js/app.js
 * Rôle : la page de l'écran de chargement : textes (strings.js), ouverture (filet, lettres qui s'embrasent, rideau ;
 *        passable d'un clic, d'Espace ou d'Entrée), sceau, extraits et conseils en rotation, six feux allumés par la
 *        progression réelle (messages reçus → progress.js), niveau d'effets (quality.js) et sa dégradation, éclair
 *        de passage à la sélection puis fondu, musique facultative (bouton caché sans piste), journal de calibrage.
 *        Messages reçus : ceux du jeu et du client Lua de vava_loading (progress.js, liste blanche) ; aucune chaîne
 *        venue d'un message n'est affichée. La page ne demande rien au jeu : le client Lua la ferme.
 *        Tout texte est posé par textContent ; les touches des conseils deviennent des éléments kbd construits par le
 *        DOM.
 * Dépendances : js/config.js, js/strings.js, js/text.js, js/progress.js, js/quality.js, js/scene.js
 */
(function () {
  'use strict';

  var VavaLoading = window.VavaLoading;
  var cfg = VavaLoading.config, S = VavaLoading.strings;
  var text = VavaLoading.text, progress = VavaLoading.progress, quality = VavaLoading.quality;

  var $ = function (id) { return document.getElementById(id); };
  var sceneEl = $('scene'), titleEl = $('title'), pathEl = $('path'), handoffEl = $('handoff');
  var reducedMotion = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  var startedAt = performance.now();

  // Musique : seulement un fichier OGG du dossier audio/ de la ressource (nom simple, aucune adresse).
  var MUSIC_FILE = /^[a-z0-9_-]{1,40}\.ogg$/;
  var MUSIC_KEY = 'vava_loading:music';
  var WAVE_OFF = 'M11.5 5.5 14.5 10.5M14.5 5.5 11.5 10.5';
  var WAVE_ON = 'M11 6c1 .8 1 3.2 0 4M13 4.5c2 1.6 2 5.4 0 7';

  // ------------------------------------------------------------------ minuteurs (tous annulables d'un coup)

  var timers = [], openingTimers = [];
  function later(fn, ms, list) {
    list = list || timers;
    var id = setTimeout(function () {
      var i = list.indexOf(id);
      if (i >= 0) list.splice(i, 1);
      fn();
    }, ms);
    list.push(id);
    return id;
  }
  function clearList(list) { while (list.length) clearTimeout(list.pop()); }

  // ------------------------------------------------------------------ niveau d'effets

  var level = quality.initial({ level: cfg.effects.level, reducedMotion: reducedMotion, cores: navigator.hardwareConcurrency });
  var meter = quality.meter(level);
  var measureFrom = Infinity; // mesure commencée measureDelayMs après la levée du rideau

  function effects() { return cfg.effects.levels[level]; }

  /** Niveau posé sur la scène : data-level, et classes no-grain, no-shine d'après les drapeaux du niveau. */
  function showLevel() {
    sceneEl.setAttribute('data-level', level);
    sceneEl.classList.toggle('no-grain', !effects().grain);
    sceneEl.classList.toggle('no-shine', !effects().shine);
  }

  function setLevel(name) {
    if (name === level) return;
    level = name;
    showLevel();
    painter.setLevel(level);
  }

  var painter = VavaLoading.scene.create({
    world: $('world'), fx: $('fx'), effects: cfg.effects, level: level,
    onDraw: function (now) {
      if (now < measureFrom) return;
      meter = quality.step(meter, now, cfg.effects);
      if (meter.level !== level) setLevel(meter.level);
    },
  });
  showLevel();

  /** Gerbe d'étincelles au centre d'un élément (coordonnées de la scène). */
  function burstAt(el, n, power, dy) {
    if (!n) return;
    var r = el.getBoundingClientRect(), sr = sceneEl.getBoundingClientRect();
    painter.burst(r.left - sr.left + r.width / 2, r.top - sr.top + (dy === undefined ? r.height * 0.55 : dy), n, power);
  }

  // ------------------------------------------------------------------ textes fixes, titre, sceau

  Array.prototype.forEach.call(document.querySelectorAll('[data-text]'), function (el) {
    var value = S[el.getAttribute('data-text')];
    el.textContent = typeof value === 'string' ? value : '';
  });
  pathEl.setAttribute('aria-label', S.progressLabel);
  titleEl.setAttribute('aria-label', S.title);
  $('runes').textContent = S.sigil + ' ' + S.sigil; // le cercle est plus long qu'une phrase : le surplus est rogné

  var letters = [];
  Array.prototype.forEach.call(String(S.title), function (ch) {
    var span = document.createElement('span');
    span.className = 'l';
    span.textContent = ch === ' ' ? ' ' : ch;
    span.setAttribute('aria-hidden', 'true');
    titleEl.appendChild(span);
    letters.push(span);
  });
  var shine = document.createElement('span');
  shine.className = 'shine';
  shine.textContent = S.title;
  shine.setAttribute('aria-hidden', 'true');
  titleEl.appendChild(shine);

  // ------------------------------------------------------------------ feux de veille

  var beacons = [];
  cfg.stages.forEach(function (at, i) {
    var b = document.createElement('div');
    b.className = 'beacon';
    b.style.left = (i === 0 ? 1.5 : at) + '%'; // le premier ne sort pas du bord
    var flame = document.createElement('div'); flame.className = 'flame';
    var bowl = document.createElement('div'); bowl.className = 'bowl';
    b.appendChild(flame); b.appendChild(bowl);
    pathEl.appendChild(b);
    beacons.push(b);
  });

  // ------------------------------------------------------------------ progression

  var state = progress.initial();
  var phase = 'opening';   // opening → revealed → handoff → closed
  var litShown = -1;       // dernier feu allumé à l'écran (les gerbes ne partent qu'une fois)
  var shown = {};          // dernières valeurs écrites dans le DOM

  function put(id, value) {
    if (shown[id] === value) return;
    shown[id] = value;
    $(id).textContent = value;
  }

  function lightBeacons(stage, stagger) {
    beacons.forEach(function (b, i) { b.classList.toggle('current', i === stage && !state.done); });
    var from = litShown + 1;
    for (var i = from; i <= stage; i++) {
      (function (b, delay) {
        var light = function () {
          b.classList.add('lit');
          burstAt(b, effects().beaconSparks, 2.6, 12);
        };
        if (delay > 0) later(light, delay); else light();
      })(beacons[i], stagger ? (i - from) * cfg.opening.beaconStepMs : 0);
    }
    if (stage > litShown) litShown = stage;
  }

  function render() {
    var k = state.stage, pct = state.pct, stage = S.stages[k] || { text: '', detail: '' };
    if (shown.fill !== pct) {
      shown.fill = pct;
      $('fill').style.transform = 'scaleX(' + pct / 100 + ')'; // composé, sans relayout
      pathEl.setAttribute('aria-valuenow', String(pct));
    }
    put('pct', text.format(S.percent, { pct: pct }));
    put('stage', stage.text);
    var detail = stage.detail;
    if (k === 2 && state.files.total > 0) {
      detail += ' · ' + text.format(S.files, { done: state.files.done, total: state.files.total });
    }
    put('detail', detail);
    put('step', text.format(S.step, { n: k + 1, total: beacons.length }));
    if (phase !== 'opening') lightBeacons(k, false);
  }

  // ------------------------------------------------------------------ journal de calibrage (config.debug.journal)

  var journal = null;
  if (cfg.debug.journal) {
    journal = { rows: {}, order: [], stages: [], ignored: 0, dirty: false, el: document.createElement('aside') };
    journal.el.className = 'journal';
    var h = document.createElement('h2'); h.textContent = S.journalTitle;
    journal.list = document.createElement('ol');
    journal.foot = document.createElement('p');
    journal.el.appendChild(h); journal.el.appendChild(journal.list); journal.el.appendChild(journal.foot);
    sceneEl.appendChild(journal.el);
  }
  function seconds(ms) { return (ms / 1000).toFixed(2); }
  function note(msg) {
    if (!journal) return;
    var now = performance.now() - startedAt;
    if (msg) {
      // seuls des noms de la liste blanche et des types de l'énumération (contrôlés par progress.read)
      var key = msg.eventName + (msg.type ? ' ' + msg.type : '');
      var row = journal.rows[key];
      if (!row) { row = journal.rows[key] = { count: 0, first: now, last: now }; journal.order.push(key); }
      row.count++; row.last = now;
    } else journal.ignored++;
    if (!journal.dirty) { journal.dirty = true; setTimeout(drawJournal, 250); } // hors de timers : vit après le passage
  }
  function noteStage(stage) {
    if (journal && journal.stages[stage] === undefined) journal.stages[stage] = performance.now() - startedAt;
  }
  function drawJournal() {
    journal.dirty = false;
    var list = journal.list;
    while (list.firstChild) list.removeChild(list.firstChild);
    journal.stages.forEach(function (at, i) {
      var li = document.createElement('li');
      li.textContent = text.format(S.journalStage, { n: i + 1, t: seconds(at) });
      list.appendChild(li);
    });
    journal.order.forEach(function (key) {
      var row = journal.rows[key], li = document.createElement('li');
      li.textContent = text.format(S.journalRow,
        { name: key, count: row.count, first: seconds(row.first), last: seconds(row.last) });
      list.appendChild(li);
    });
    journal.foot.textContent = text.format(S.journalFoot, { pct: state.pct, ignored: journal.ignored, level: level });
  }

  // ------------------------------------------------------------------ messages reçus

  function receive(data) {
    var msg = progress.read(data);
    note(msg);
    if (!msg) return;
    var next = progress.reduce(state, msg, cfg.stages);
    if (next !== state) {
      state = next;
      noteStage(state.stage);
      render();
    }
    if (msg.eventName === 'vava_loading:handoff') handoff(msg.ms);
  }
  window.addEventListener('message', function (event) { receive(event.data); });

  // ------------------------------------------------------------------ extraits et conseils

  var nextQuote = text.cycle(S.quotes.length), nextTip = text.cycle(S.tips.length);
  var quoteEl = $('quote'), tipEl = $('tip');

  function setQuote() { var i = nextQuote(); quoteEl.textContent = i >= 0 ? S.quotes[i] : ''; }
  function setTip() {
    var i = nextTip();
    while (tipEl.firstChild) tipEl.removeChild(tipEl.firstChild);
    if (i < 0) return;
    text.splitKeys(S.tips[i]).forEach(function (part) {
      if (part.key !== undefined) {
        var kbd = document.createElement('kbd');
        kbd.textContent = part.key;
        tipEl.appendChild(kbd);
      } else tipEl.appendChild(document.createTextNode(part.text));
    });
  }
  function rotate(el, set, every) {
    later(function () {
      el.classList.add('out');
      later(function () {
        set();
        el.classList.remove('out');
        rotate(el, set, every);
      }, reducedMotion ? 0 : cfg.rotation.fadeMs);
    }, every);
  }
  function startRotation() {
    setQuote(); setTip();
    rotate(quoteEl, setQuote, cfg.rotation.quoteMs);
    rotate(tipEl, setTip, cfg.rotation.tipMs);
  }

  // ------------------------------------------------------------------ ouverture

  function reveal() {
    if (phase !== 'opening') return;
    phase = 'revealed';
    clearList(openingTimers);
    painter.showWorld(); // paysage peint avant que le rideau commence à se lever
    sceneEl.classList.add('drawn', 'revealed');
    measureFrom = performance.now() + cfg.effects.measureDelayMs;
    lightBeacons(state.stage, true); // feux atteints pendant l'ouverture : allumés un à un
    if (music.wanted) music.play();
  }

  /** Passe l'ouverture : tout apparaît aussitôt. */
  function skip() {
    if (phase !== 'opening') return;
    clearList(openingTimers);
    sceneEl.classList.add('quick');
    letters.forEach(function (l) { l.classList.add('lit', 'now'); });
    reveal();
  }

  function opening() {
    var o = cfg.opening;
    if (!o.enabled || reducedMotion) {
      // sans ouverture, ou moins d'animations demandé : un fondu de reducedMs, sans étincelles
      sceneEl.classList.add('quick', 'drawn');
      letters.forEach(function (l) { l.classList.add('lit', 'now'); });
      reveal();
      return;
    }
    later(function () { sceneEl.classList.add('drawn'); }, o.lineMs, openingTimers);
    letters.forEach(function (l, i) {
      later(function () {
        l.classList.add('lit');
        burstAt(l, effects().letterSparks, 3.2);
      }, o.firstLetterMs + i * o.letterStepMs, openingTimers);
    });
    later(reveal, o.firstLetterMs + letters.length * o.letterStepMs + o.revealAfterMs, openingTimers);
  }

  // clic n'importe où, Espace ou Entrée pendant l'ouverture
  document.addEventListener('pointerdown', function () { if (phase === 'opening') skip(); });
  $('skip').addEventListener('click', skip);
  document.addEventListener('keydown', function (e) {
    if (phase === 'opening' && (e.key === ' ' || e.key === 'Enter')) { e.preventDefault(); skip(); }
  });
  sceneEl.addEventListener('pointermove', function (e) {
    var r = sceneEl.getBoundingClientRect();
    painter.pointer((e.clientX - r.left) / r.width - 0.5, (e.clientY - r.top) / r.height - 0.5);
  });

  // ------------------------------------------------------------------ passage à la sélection

  /**
   * Séquence du § 8.1 de la spec, à l'échelle de `ms` (1 800 par défaut) : 100 % et gerbes sur les feux, éclair à
   * 400/1800 (montée 700/1800), page transparente à 1100/1800 (600/1800) ; le client Lua ferme l'écran à `ms`.
   */
  function handoff(ms) {
    if (phase === 'handoff' || phase === 'closed') return;
    if (phase === 'opening') skip();
    phase = 'handoff';
    clearList(timers); // rotation arrêtée
    beacons.forEach(function (b) { b.classList.add('lit'); b.classList.remove('current'); });
    litShown = beacons.length - 1;
    render();
    beacons.forEach(function (b, i) {
      later(function () { burstAt(b, effects().finalSparks, 3.4, 12); }, i * 90);
    });
    var at = function (part) { return Math.round(ms * part / 1800); };
    sceneEl.style.setProperty('--flash-ms', at(700) + 'ms');
    sceneEl.style.setProperty('--leave-ms', at(600) + 'ms');
    later(function () { handoffEl.classList.add('on'); }, at(400));
    later(function () { sceneEl.classList.add('leaving'); }, at(1100));
    later(function () {
      phase = 'closed';
      painter.stop();
      music.stop();
      if (typeof VavaLoading.onClosed === 'function') VavaLoading.onClosed(); // hors jeu (dev/devmock.js)
    }, ms);
    music.fadeOut(at(1100));
  }

  // ------------------------------------------------------------------ musique (décision 4 : aucune piste en 1.0.0)

  var music = (function () {
    var button = $('music'), label = $('music-label'), wave = $('music-wave');
    var file = cfg.music.file, audio = null, fadeTimer = 0;
    var api = { wanted: false, play: function () {}, stop: function () {}, fadeOut: function () {} };
    if (!file || !MUSIC_FILE.test(file)) return api; // bouton caché

    function saved() { try { return window.localStorage.getItem(MUSIC_KEY) === 'on'; } catch (e) { return false; } }
    function save(on) { try { window.localStorage.setItem(MUSIC_KEY, on ? 'on' : 'off'); } catch (e) { /* non gardé */ } }
    function show(on) {
      button.setAttribute('aria-pressed', String(on));
      label.textContent = on ? S.musicOn : S.musicOff;
      wave.setAttribute('d', on ? WAVE_ON : WAVE_OFF);
    }
    // volume amené vers `target` en ms (pas de 100 ms, seulement pendant un fondu)
    function fade(target, ms, done) {
      clearTimeout(fadeTimer);
      if (!audio) return;
      var steps = Math.max(1, Math.round(ms / 100)), from = audio.volume, n = 0;
      (function tick() {
        n++;
        audio.volume = Math.max(0, Math.min(1, from + (target - from) * n / steps));
        if (n < steps) fadeTimer = setTimeout(tick, 100); else if (done) done();
      })();
    }
    api.play = function () {
      if (!audio) { audio = new Audio('audio/' + file); audio.loop = true; audio.volume = 0; }
      var p = audio.play();
      if (p && p.catch) p.catch(function () { api.wanted = false; show(false); });
      fade(cfg.music.volume, cfg.music.fadeMs);
    };
    api.stop = function () { clearTimeout(fadeTimer); if (audio) audio.pause(); };
    api.fadeOut = function (ms) { fade(0, ms, function () { if (audio) audio.pause(); }); };

    api.wanted = saved();
    show(api.wanted);
    button.hidden = false;
    button.addEventListener('click', function () {
      api.wanted = !api.wanted;
      save(api.wanted); show(api.wanted);
      if (api.wanted) api.play(); else fade(0, cfg.music.fadeMs, function () { if (audio) audio.pause(); });
    });
    return api;
  })();

  // ------------------------------------------------------------------ départ

  function start() {
    render();
    startRotation();
    painter.start();
    var go = function () { if (!go.done) { go.done = true; if (phase === 'opening') opening(); } };
    // les lettres sont mesurées pour les étincelles : polices chargées d'abord (fichiers locaux), 1,5 s au plus
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(go);
    later(go, 1500, openingTimers);
  }

  // Commandes hors jeu (dev/devmock.js) ; en jeu, personne ne les appelle.
  VavaLoading.app = {
    receive: receive,
    skip: skip,
    stats: function () {
      return { fps: painter.fps(), worldFps: painter.worldFps(), level: level, stage: state.stage, pct: state.pct, phase: phase };
    },
    /** Rejoue l'ouverture seule (la progression est gardée). */
    replayOpening: function () {
      if (phase !== 'opening' && phase !== 'revealed') return;
      clearList(openingTimers);
      phase = 'opening'; measureFrom = Infinity;
      painter.hideWorld();
      sceneEl.classList.remove('revealed', 'drawn', 'quick');
      letters.forEach(function (l) { l.classList.remove('lit', 'now'); });
      beacons.forEach(function (b) { b.classList.remove('lit', 'current'); });
      litShown = -1;
      opening();
    },
    /** Remet tout à zéro (après le passage, pour rejouer un scénario). */
    restart: function () {
      clearList(timers); clearList(openingTimers);
      painter.stop();
      state = progress.initial(); shown = {}; litShown = -1; phase = 'opening'; measureFrom = Infinity;
      sceneEl.classList.remove('revealed', 'drawn', 'quick', 'leaving');
      handoffEl.classList.remove('on');
      letters.forEach(function (l) { l.classList.remove('lit', 'now'); });
      beacons.forEach(function (b) { b.classList.remove('lit', 'current'); });
      if (journal) { journal.rows = {}; journal.order = []; journal.stages = []; journal.ignored = 0; journal.dirty = false; }
      startedAt = performance.now();
      start();
    },
  };

  noteStage(0);
  start();
})();
