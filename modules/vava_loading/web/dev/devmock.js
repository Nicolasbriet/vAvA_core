/*
 * vava_loading/web/dev/devmock.js
 * Rôle : progression simulée quand la page est ouverte dans un navigateur depuis le dépôt (protocole file:), pour voir
 *        chaque écran sans lancer le jeu. Rejoue des suites de messages du jeu et du client Lua par
 *        window.postMessage, et ajoute un panneau « Hors jeu » : scénario, rejouer l'ouverture, vitesse ×4, figer,
 *        étape suivante, passer à la sélection.
 *        Paramètres d'adresse : ?scenario=normal|rapide|lent|muet|sans-selection, ?niveau=haute|moyenne|basse,
 *        ?vitesse=4, ?ouverture=0, ?fps=1 (cadence et niveau à l'écran), ?journal=1 (journal de calibrage).
 *        Jamais livré (web/dev/ hors des files du manifeste), jamais chargé en jeu (la ligne hors jeu de index.html ne
 *        l'insère qu'en file:). Chargé après les fichiers purs et avant js/app.js : il règle la config avant le départ.
 * Dépendances : js/config.js, js/progress.js (window.VavaLoading)
 */
(function () {
  'use strict';

  if (location.protocol !== 'file:') return;

  var VavaLoading = window.VavaLoading;
  var cfg = VavaLoading.config;
  var params = new URLSearchParams(location.search);

  // ------------------------------------------------------------------ réglages avant le départ de la page

  var niveau = params.get('niveau');
  if (niveau && cfg.effects.levels[niveau]) cfg.effects.level = niveau;
  if (params.get('ouverture') === '0') cfg.opening.enabled = false;
  if (params.get('journal') === '1') cfg.debug.journal = true;
  var speed = Math.min(20, Math.max(0.25, Number(params.get('vitesse')) || 1));
  var showFps = params.get('fps') === '1';

  var SCENARIOS = {
    normal: 'normal (≈ 40 s)',
    rapide: 'rapide (≈ 8 s, reconnexion)',
    lent: 'lent (≈ 3 min, étape 3 longue)',
    muet: 'muet (seulement les messages du Lua)',
    'sans-selection': 'sans sélection (aucun passage)',
  };
  var scenario = SCENARIOS[params.get('scenario')] ? params.get('scenario') : 'normal';

  // ------------------------------------------------------------------ suites de messages

  /** Fonctions d'initialisation d'un type : début, ordre, appels un à un, fin. Rend l'instant de fin. */
  function initGroup(tl, t, type, count, ms) {
    tl.push([t, { eventName: 'startInitFunction', type: type }]);
    tl.push([t, { eventName: 'startInitFunctionOrder', type: type, order: 1, count: count }]);
    for (var i = 0; i < count; i++) {
      var at = t + i * ms / count;
      tl.push([at, { eventName: 'initFunctionInvoking', type: type, name: 'fonction_' + i, idx: i }]);
      tl.push([at + ms / count * 0.6, { eventName: 'initFunctionInvoked', type: type, name: 'fonction_' + i, idx: i }]);
    }
    tl.push([t + ms, { eventName: 'endInitFunction', type: type }]);
    return t + ms;
  }

  // Les messages du client Lua arrivent en chaîne JSON (SendLoadingScreenMessage), ceux du jeu en objet : la page lit
  // les deux.
  function lua(name, extra) {
    var msg = { eventName: 'vava_loading:' + name };
    for (var k in extra || {}) msg[k] = extra[k];
    return JSON.stringify(msg);
  }

  /** Suite complète ; `x` étire les durées, `filesMs` la durée des fichiers de données. */
  function full(x, filesMs, withHandoff) {
    var tl = [], t = 500 * x, i;
    t = initGroup(tl, t, 'INIT_BEFORE_MAP_LOADED', 12, 3000 * x);
    for (i = 0; i < 20; i++) tl.push([t + i * 300 * x, { eventName: 'performMapLoadFunction', idx: i }]);
    t += 6000 * x;
    tl.push([t, { eventName: 'startDataFileEntries', count: 380 }]);
    for (i = 0; i < 380; i++) {
      tl.push([t + (i + 1) * filesMs / 380, { eventName: 'onDataFileEntry', type: 'DLC_ITYP_REQUEST', isNew: true, name: 'fichier_' + i }]);
    }
    t += filesMs;
    tl.push([t + 100, { eventName: 'endDataFileEntries' }]);
    t = initGroup(tl, t + 200, 'INIT_AFTER_MAP_LOADED', 30, 6000 * x);
    tl.push([t + 300 * x, lua('resources')]);
    t = initGroup(tl, t + 600 * x, 'INIT_SESSION', 8, 5000 * x);
    var end = t;
    // avancement global du jeu, une fois par seconde (scénario)
    for (var s = 0; s * 1000 < end; s++) tl.push([s * 1000, { eventName: 'loadProgress', loadFraction: Math.min(1, s * 1000 / end) }]);
    // lignes de journal du jeu (jamais affichées) et messages forgés (ignorés par la page)
    for (var l = 0; l * 2500 < end; l++) tl.push([l * 2500 + 50, { eventName: 'onLogLine', message: 'Loading step ' + l }]);
    tl.push([4000 * x, { eventName: 'loadProgress', loadFraction: 7 }]);
    tl.push([5000 * x, { eventName: 'onDataFileEntry\u0000', name: 'balise forgée' }]);
    tl.push([end + 1000 * x, lua('waiting')]);
    if (withHandoff) tl.push([end + 4000 * x, lua('handoff', { ms: 1800 })]);
    return tl;
  }

  function build(name) {
    var tl;
    if (name === 'rapide') tl = full(0.2, 1500, true);
    else if (name === 'lent') tl = full(1.5, 120000, true);
    else if (name === 'muet') tl = [[2000, lua('resources')], [6000, lua('waiting')], [9000, lua('handoff', { ms: 1800 })]];
    else tl = full(1, 12000, name !== 'sans-selection');
    tl.sort(function (a, b) { return a[0] - b[0]; });
    // étape atteinte après chaque message (pour « étape suivante »)
    var state = VavaLoading.progress.initial();
    return tl.map(function (e) {
      state = VavaLoading.progress.reduce(state, e[1], cfg.stages);
      return { at: e[0], msg: e[1], stage: state.stage, done: state.done };
    });
  }

  // ------------------------------------------------------------------ lecture

  var timeline = [], index = 0, clock = 0, timer = 0, frozen = false, finished = false;

  function send(entry) { window.postMessage(entry.msg, '*'); }

  function schedule() {
    clearTimeout(timer);
    if (frozen || index >= timeline.length) { status(); return; }
    timer = setTimeout(play, Math.max(0, (timeline[index].at - clock) / speed));
  }
  function play() {
    clock = timeline[index].at;
    while (index < timeline.length && timeline[index].at <= clock) send(timeline[index++]);
    status();
    schedule();
  }
  function begin() {
    timeline = build(scenario); index = 0; clock = 0; finished = false;
    schedule();
  }
  function nextStage() {
    if (index >= timeline.length) return;
    var current = VavaLoading.app.stats().stage;
    while (index < timeline.length) {
      var entry = timeline[index++];
      send(entry);
      clock = entry.at;
      if (entry.stage > current || entry.done) break;
    }
    schedule();
  }
  function handoffNow() {
    clearTimeout(timer); index = timeline.length;
    window.postMessage(lua('handoff', { ms: 1800 }), '*');
    status();
  }

  // ------------------------------------------------------------------ panneau « Hors jeu »

  var css = document.createElement('style');
  css.textContent = [
    '.devmock { position: fixed; z-index: 20; right: 16px; top: 64px; display: flex; gap: 8px; align-items: center;',
    '  flex-wrap: wrap; justify-content: flex-end; max-width: 46rem; font: 0.8rem "EB Garamond", Georgia, serif;',
    '  color: #786c5c; background: rgba(7, 5, 4, 0.78); border: 1px dashed rgba(179, 148, 99, 0.28); padding: 8px 10px;',
    '  border-radius: 2px; }',
    '.devmock strong { font: 600 0.65rem Cinzel, Georgia, serif; letter-spacing: 0.18em; text-transform: uppercase; color: #d08a3c; }',
    '.devmock button, .devmock select { font: 600 0.85rem "EB Garamond", Georgia, serif; color: #a69881; background: #0c0a10;',
    '  border: 1px solid rgba(179, 148, 99, 0.28); border-radius: 2px; padding: 4px 9px; cursor: pointer; }',
    '.devmock button:hover { color: #ece1c8; border-color: #b39463; }',
    '.devmock button[aria-pressed="true"] { color: #dcc08a; border-color: #b39463; }',
    '.devmock .devmock-status { flex-basis: 100%; text-align: right; font-style: italic; }',
    '.devmock-closed { position: fixed; inset: 0; z-index: 19; display: flex; flex-direction: column; justify-content: center;',
    '  align-items: center; text-align: center;',
    '  font: italic 1.2rem "EB Garamond", Georgia, serif; color: #a69881; cursor: pointer; }',
    '.devmock-closed strong { display: block; font: 600 0.8rem Cinzel, Georgia, serif; letter-spacing: 0.24em;',
    '  text-transform: uppercase; color: #dcc08a; margin-bottom: 8px; font-style: normal; }',
  ].join('\n');
  document.head.appendChild(css);

  var panel = document.createElement('div');
  panel.className = 'devmock';
  panel.setAttribute('aria-label', 'Commandes hors jeu');
  var statusEl = document.createElement('span');

  function add(el) { panel.appendChild(el); return el; }
  function button(label, onClick, pressed) {
    var b = document.createElement('button');
    b.type = 'button'; b.textContent = label;
    if (pressed !== undefined) b.setAttribute('aria-pressed', String(pressed));
    b.addEventListener('click', function (e) { e.stopPropagation(); onClick(b); });
    return add(b);
  }

  var title = document.createElement('strong'); title.textContent = 'Hors jeu'; add(title);
  var select = document.createElement('select');
  Object.keys(SCENARIOS).forEach(function (key) {
    var o = document.createElement('option'); o.value = key; o.textContent = SCENARIOS[key];
    if (key === scenario) o.selected = true;
    select.appendChild(o);
  });
  select.addEventListener('change', function () { params.set('scenario', select.value); location.search = params.toString(); });
  add(select);
  button('Rejouer l’ouverture', function () { VavaLoading.app.replayOpening(); });
  button('Vitesse ×4', function (b) {
    speed = speed === 4 ? 1 : 4; b.setAttribute('aria-pressed', String(speed === 4)); schedule();
  }, speed === 4);
  button('Figer', function (b) {
    frozen = !frozen; b.setAttribute('aria-pressed', String(frozen)); b.textContent = frozen ? 'Reprendre' : 'Figer';
    schedule();
  }, false);
  button('Étape suivante', nextStage);
  button('Passer à la sélection', handoffNow);
  statusEl.className = 'devmock-status';
  add(statusEl);

  function status() {
    var stats = VavaLoading.app ? VavaLoading.app.stats() : null;
    var parts = [SCENARIOS[scenario], (clock / 1000).toFixed(1) + ' s'];
    if (frozen) parts.push('figé');
    if (index >= timeline.length && stats && stats.phase !== 'handoff' && stats.phase !== 'closed') {
      parts.push(scenario === 'sans-selection'
        ? 'aucun passage : en jeu, le filet de vava_loading (20 s) puis celui du core (30 s) fermeraient l’écran ; ici rien ne se ferme'
        : 'suite terminée');
    }
    if (showFps && stats) {
      parts.push((stats.fps ? stats.fps.toFixed(1) + ' im/s' : 'peint une fois') + ' · effets ' + stats.level);
    }
    if (stats) parts.push('feu ' + (stats.stage + 1) + ' · ' + stats.pct + ' %');
    statusEl.textContent = parts.join(' · ');
  }

  // Après l'éclair : la page est transparente, le jeu montrerait la sélection dessous ; ici une note, un clic rejoue.
  VavaLoading.onClosed = function () {
    finished = true;
    document.documentElement.style.background = '#1d1b20';
    var note = document.createElement('div');
    note.className = 'devmock-closed';
    var strong = document.createElement('strong'); strong.textContent = 'Registre des âmes';
    note.appendChild(strong);
    note.appendChild(document.createTextNode('En jeu, l’écran se ferme ici : la sélection du personnage est dessous. Cliquer pour tout rejouer.'));
    note.addEventListener('click', function () {
      note.remove();
      document.documentElement.style.background = '';
      VavaLoading.app.restart();
      begin();
    });
    document.body.appendChild(note);
    status();
  };

  window.addEventListener('load', function () {
    document.body.appendChild(panel);
    begin();
    // rafraîchit la ligne d'état (hors jeu seulement)
    setInterval(function () { if (!finished) status(); }, 500);
  });
})();
