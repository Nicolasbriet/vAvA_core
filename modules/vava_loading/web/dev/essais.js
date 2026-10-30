/*
 * vava_loading/web/dev/essais.js
 * Rôle : essais des fonctions pures de la page (js/progress.js, js/quality.js : niveaux et cadences, js/text.js) et forme de js/config.js et
 *        js/strings.js. Sans dépendance : `node modules/vava_loading/web/dev/essais.js` (code de sortie 1 au moindre
 *        échec), ou web/dev/essais.html ouvert dans un navigateur. Jamais livré.
 * Dépendances : js/config.js, js/strings.js, js/text.js, js/progress.js, js/quality.js
 */
(function () {
  'use strict';

  var inNode = typeof module === 'object' && typeof require === 'function' && typeof window === 'undefined';
  var V;
  if (inNode) {
    require('../js/config.js'); require('../js/strings.js'); require('../js/text.js');
    require('../js/progress.js'); require('../js/quality.js');
    V = globalThis.VavaLoading;
  } else V = window.VavaLoading;

  var progress = V.progress, quality = V.quality, text = V.text, cfg = V.config, S = V.strings;
  var FLOORS = [0, 12, 38, 72, 88, 97]; // seuils de la spec (les essais ne dépendent pas d'un recalibrage)

  var passed = 0, failed = 0, lines = [];
  function out(line) { lines.push(line); if (inNode) console.log(line); }
  function same(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
  function check(cond, what) { if (!cond) throw new Error(what); }
  function eq(actual, expected, what) {
    if (!same(actual, expected)) throw new Error((what || 'valeur') + ' : attendu ' + JSON.stringify(expected) + ', obtenu ' + JSON.stringify(actual));
  }
  function test(name, fn) {
    try { fn(); passed++; out('  ok    ' + name); } catch (e) { failed++; out('  ÉCHEC ' + name + ' — ' + e.message); }
  }
  function run(state, messages) {
    var pcts = [], stages = [];
    messages.forEach(function (m) { state = progress.reduce(state, m, FLOORS); pcts.push(state.pct); stages.push(state.stage); });
    return { state: state, pcts: pcts, stages: stages };
  }
  function nonDecreasing(list) { for (var i = 1; i < list.length; i++) if (list[i] < list[i - 1]) return false; return true; }
  // générateur pseudo-aléatoire reproductible
  function seeded(seed) { return function () { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; }; }

  function group(type, count) {
    var list = [{ eventName: 'startInitFunction', type: type }, { eventName: 'startInitFunctionOrder', type: type, order: 1, count: count }];
    for (var i = 0; i < count; i++) {
      list.push({ eventName: 'initFunctionInvoking', type: type, name: 'f', idx: i });
      list.push({ eventName: 'initFunctionInvoked', type: type, name: 'f', idx: i });
    }
    list.push({ eventName: 'endInitFunction', type: type });
    return list;
  }
  function normal(withHandoff) {
    var list = group('INIT_BEFORE_MAP_LOADED', 12), i;
    for (i = 0; i < 20; i++) list.push({ eventName: 'performMapLoadFunction', idx: i });
    list.push({ eventName: 'startDataFileEntries', count: 380 });
    for (i = 0; i < 380; i++) list.push({ eventName: 'onDataFileEntry', type: 'x', isNew: true, name: 'n' });
    list.push({ eventName: 'endDataFileEntries' });
    list = list.concat(group('INIT_AFTER_MAP_LOADED', 30));
    list.push({ eventName: 'vava_loading:resources' });
    list = list.concat(group('INIT_SESSION', 8));
    list.push({ eventName: 'vava_loading:waiting' });
    if (withHandoff) list.push(JSON.stringify({ eventName: 'vava_loading:handoff', ms: 1800 }));
    return list;
  }

  out('progress');
  var s0 = progress.initial();
  test('état de départ', function () {
    eq(s0, { stage: 0, orders: {}, files: { done: 0, total: 0 }, fraction: null, pct: 0, done: false });
  });
  test('message inconnu, type inconnu, count négatif ou NaN, loadFraction 1,5 : état inchangé', function () {
    [
      { eventName: 'inconnu' }, { eventName: 'startInitFunction', type: 'INIT_AUTRE' },
      { eventName: 'startInitFunctionOrder', type: 'INIT_SESSION', count: -1 },
      { eventName: 'startInitFunctionOrder', type: 'INIT_SESSION', count: NaN },
      { eventName: 'startDataFileEntries', count: Infinity }, { eventName: 'startDataFileEntries', count: '12' },
      { eventName: 'startDataFileEntries', count: 100001 }, { eventName: 'initFunctionInvoking', type: 'INIT_SESSION', idx: -3 },
      { eventName: 'loadProgress', loadFraction: 1.5 }, { eventName: 'loadProgress', loadFraction: -0.1 },
      { eventName: 'loadProgress' }, { eventName: 'onLogLine', message: 'x' },
      null, 42, '', '{', 'pas du json', [], { eventName: ['loadProgress'] }, { eventName: 'toString' },
      { eventName: '__proto__' }, { eventName: 'hasOwnProperty' },
    ].forEach(function (m, i) { check(progress.reduce(s0, m, FLOORS) === s0, 'message ' + i + ' a changé l\'état'); });
  });
  test('chaîne JSON acceptée, au plus 2 048 caractères', function () {
    eq(progress.read('{"eventName":"vava_loading:waiting"}'), { eventName: 'vava_loading:waiting' });
    var long = JSON.stringify({ eventName: 'vava_loading:waiting', pad: new Array(2100).join('x') });
    eq(progress.read(long), null, 'chaîne trop longue');
  });
  test('read ne garde aucune chaîne venue du message', function () {
    eq(progress.read({ eventName: 'onDataFileEntry', type: 'x', isNew: true, name: '<img src=x>' }), { eventName: 'onDataFileEntry' });
    eq(progress.read({ eventName: 'initFunctionInvoking', type: 'INIT_SESSION', name: 'abc', idx: 2.7 }),
      { eventName: 'initFunctionInvoking', type: 'INIT_SESSION', idx: 2 });
  });
  test('read est idempotent', function () {
    var m = progress.read({ eventName: 'loadProgress', loadFraction: 0.5 });
    eq(progress.read(m), m);
  });
  test('handoff : durée bornée de 300 à 5 000, 1 800 si absente', function () {
    eq(progress.read({ eventName: 'vava_loading:handoff', ms: 50 }).ms, 300);
    eq(progress.read({ eventName: 'vava_loading:handoff', ms: 99999 }).ms, 5000);
    eq(progress.read({ eventName: 'vava_loading:handoff' }).ms, 1800);
    eq(progress.read({ eventName: 'vava_loading:handoff', ms: 1800 }).ms, 1800);
  });
  test('suite normale : étapes 0 à 5 dans l\'ordre, pourcentage jamais décroissant, 100 au passage', function () {
    var r = run(s0, normal(true));
    var seen = [0];
    r.stages.forEach(function (k) { if (k !== seen[seen.length - 1]) seen.push(k); });
    eq(seen, [0, 1, 2, 3, 4, 5], 'étapes');
    check(nonDecreasing(r.pcts), 'pourcentage décroissant');
    eq(r.pcts[r.pcts.length - 1], 100, 'fin');
    eq(r.pcts[r.pcts.length - 2], 97, 'attente de la sélection');
    check(r.state.done, 'done');
  });
  test('l\'ancien état n\'est jamais modifié', function () {
    var a = progress.reduce(s0, { eventName: 'startDataFileEntries', count: 10 }, FLOORS);
    var copy = JSON.stringify(a);
    progress.reduce(a, { eventName: 'onDataFileEntry' }, FLOORS);
    progress.reduce(a, { eventName: 'startInitFunctionOrder', type: 'INIT_SESSION', count: 4 }, FLOORS);
    eq(JSON.stringify(a), copy);
    eq(JSON.stringify(s0), JSON.stringify(progress.initial()));
  });
  test('messages dans le désordre : l\'étape ne recule pas', function () {
    var r = run(s0, group('INIT_SESSION', 4).concat([
      { eventName: 'startDataFileEntries', count: 10 }, { eventName: 'onDataFileEntry' },
      { eventName: 'performMapLoadFunction', idx: 1 }, { eventName: 'startInitFunction', type: 'INIT_BEFORE_MAP_LOADED' },
    ]));
    eq(r.stages[r.stages.length - 1], 5, 'INIT_SESSION terminé : feu 6');
    check(nonDecreasing(r.stages), 'étape décroissante');
    check(nonDecreasing(r.pcts), 'pourcentage décroissant');
  });
  test('loadProgress seul : borné à l\'étape en cours', function () {
    var a = progress.reduce(s0, { eventName: 'loadProgress', loadFraction: 0.9 }, FLOORS);
    eq(a.stage, 0); eq(a.pct, 11);
    var b = progress.reduce(progress.reduce(s0, { eventName: 'performMapLoadFunction', idx: 0 }, FLOORS),
      { eventName: 'loadProgress', loadFraction: 0.2 }, FLOORS);
    eq(b.pct, 19, 'floor(0,2 × 97) dans [12, 37]');
    var c = progress.reduce(b, { eventName: 'loadProgress', loadFraction: 0.05 }, FLOORS);
    eq(c.pct, 19, 'une fraction plus basse ne fait pas reculer');
  });
  test('muet : 0, 72 (resources), 97 (waiting), 100 (handoff)', function () {
    var r = run(s0, ['{"eventName":"vava_loading:resources"}', { eventName: 'vava_loading:waiting' },
      { eventName: 'vava_loading:handoff', ms: 1800 }]);
    eq([s0.pct].concat(r.pcts), [0, 72, 97, 100]);
  });
  test('fichiers 190 / 380 à l\'étape 3 : 38 + floor(0,5 × 33) = 54', function () {
    var list = [{ eventName: 'startDataFileEntries', count: 380 }];
    for (var i = 0; i < 190; i++) list.push({ eventName: 'onDataFileEntry' });
    var r = run(s0, list);
    eq(r.state.stage, 2); eq(r.state.files, { done: 190, total: 380 }); eq(r.state.pct, 54);
  });
  test('onDataFileEntry au-delà de count : done borné', function () {
    var list = [{ eventName: 'startDataFileEntries', count: 3 }];
    for (var i = 0; i < 9; i++) list.push({ eventName: 'onDataFileEntry' });
    var r = run(s0, list);
    eq(r.state.files, { done: 3, total: 3 }); eq(r.state.pct, 71);
  });
  test('fonctions d\'initialisation : idx / count dans l\'étape', function () {
    var r = run(s0, [{ eventName: 'startInitFunctionOrder', type: 'INIT_BEFORE_MAP_LOADED', order: 1, count: 10 },
      { eventName: 'initFunctionInvoked', type: 'INIT_BEFORE_MAP_LOADED', idx: 4 }]);
    eq(r.state.stage, 1); eq(r.state.pct, 12 + Math.floor(0.5 * 25));
  });
  test('après le passage, plus rien ne change', function () {
    var done = progress.reduce(s0, { eventName: 'vava_loading:handoff', ms: 1800 }, FLOORS);
    check(progress.reduce(done, { eventName: 'loadProgress', loadFraction: 0.1 }, FLOORS) === done, 'état changé');
    eq(done.pct, 100);
  });

  out('quality');
  var OPTS = { minFps: 20, windowMs: 2000, badWindows: 2 };
  function feed(m, from, to, dt) { for (var t = from; t <= to; t += dt) m = quality.step(m, t, OPTS); return m; }
  test('niveau de départ : réglage, moins d\'animations, cœurs', function () {
    eq(quality.initial({ level: 'moyenne', reducedMotion: true, cores: 16 }), 'moyenne', 'réglage forcé');
    eq(quality.initial({ level: 'basse' }), 'basse');
    eq(quality.initial({ level: 'auto', reducedMotion: true, cores: 16 }), 'basse', 'moins d\'animations');
    eq(quality.initial({ level: 'auto', cores: 2 }), 'moyenne', '2 cœurs');
    eq(quality.initial({ level: 'auto', cores: 1 }), 'moyenne', '1 cœur');
    eq(quality.initial({ level: 'auto', cores: 4 }), 'moyenne', '4 cœurs');
    eq(quality.initial({ level: 'auto', cores: 5 }), 'haute', '5 cœurs');
    eq(quality.initial({ level: 'auto', cores: 8 }), 'haute', '8 cœurs');
    eq(quality.initial({ level: 'auto', cores: 0 }), 'haute', '0 cœur : inconnu');
    eq(quality.initial({ level: 'auto' }), 'haute', 'cœurs inconnus');
    eq(quality.initial({ level: 'ultra', cores: 8 }), 'haute', 'réglage inconnu : auto');
  });
  test('cadence correcte : aucun changement', function () {
    eq(feed(quality.meter('haute'), 0, 20000, 33).level, 'haute');
  });
  test('2 fenêtres lentes de suite : un niveau de moins ; 1 seule : rien', function () {
    var one = feed(quality.meter('haute'), 0, 2100, 60);
    one = feed(one, 2160, 4300, 30);
    eq(one.level, 'haute', 'une seule fenêtre lente');
    eq(feed(quality.meter('haute'), 0, 4300, 60).level, 'moyenne', 'deux fenêtres lentes');
  });
  test('jamais de remontée', function () {
    var m = feed(quality.meter('haute'), 0, 4300, 60);
    eq(m.level, 'moyenne');
    m = feed(m, 4330, 60000, 16);
    eq(m.level, 'moyenne');
  });
  test('intervalles de plus d\'une seconde ignorés', function () {
    var m = quality.meter('haute'), t = 0;
    for (var i = 0; i < 20; i++) { t += 1500; m = quality.step(m, t, OPTS); }
    eq(m.level, 'haute');
    eq(m.frames, 0);
  });
  // Boucle de scene.js rejouée sur des horodatages d'images : braises si due, paysage si worldDue (sur une image des
  // braises seulement). Rend le nombre d'images de chacun et le plus grand écart entre deux images du paysage.
  function cadence(periodMs, seconds, jitterMs, fxFps, worldFps) {
    var rnd = seeded(11), t = 1000, end = 1000 + seconds * 1000, last = 0, lastWorld = 0, fx = 0, world = 0, gap = 0;
    while (t < end) {
      t += periodMs + (jitterMs ? (rnd() - 0.5) * 2 * jitterMs : 0);
      if (!quality.due(last, t, fxFps)) continue;
      last = t; fx++;
      if (quality.worldDue(lastWorld, t, worldFps, fxFps)) {
        if (lastWorld) gap = Math.max(gap, t - lastWorld);
        lastWorld = t; world++;
      }
    }
    return { fx: fx / seconds, world: world / seconds, gap: gap };
  }
  function near(actual, expected, tolerance, what) {
    check(Math.abs(actual - expected) <= tolerance, what + ' : attendu ' + expected + ' ± ' + tolerance + ', obtenu ' + actual.toFixed(2));
  }
  test('due : première image toujours, puis selon le plafond (30 par défaut), marge 1 ms ou donnée', function () {
    eq(quality.due(0, 5, 30), true, 'aucune image avant');
    eq(quality.due(1000, 1032.4, 30), true, '32,4 ms à 30 i/s');
    eq(quality.due(1000, 1016.7, 30), false, '16,7 ms à 30 i/s');
    eq(quality.due(1000, 1032.4, 0), true, 'plafond nul : 30');
    eq(quality.due(1000, 1032.4, NaN), true, 'plafond invalide : 30');
    eq(quality.due(1000, 1060, 15), false, '60 ms à 15 i/s');
    eq(quality.due(1000, 1060, 15, 8), true, '60 ms à 15 i/s, marge 8 ms');
  });
  test('cadence à 60 Hz : braises à 30 i/s, paysage à 15 i/s', function () {
    var r = cadence(1000 / 60, 20, 0, 30, 15);
    near(r.fx, 30, 0.2, 'braises');
    near(r.world, 15, 0.2, 'paysage');
    check(r.gap < 70, 'écart du paysage ' + r.gap.toFixed(1) + ' ms');
  });
  test('cadence à 60 Hz, horloge qui vacille de 2 ms : paysage sur une image des braises sur deux, jamais moins', function () {
    var r = cadence(1000 / 60, 20, 2, 30, 15);
    check(r.fx <= 30, 'braises ' + r.fx);
    near(r.world, r.fx / 2, 0.1, 'paysage');
    check(r.gap < 110, 'écart du paysage ' + r.gap.toFixed(1) + ' ms');
  });
  test('cadence à 144 Hz : 30 et 15 i/s au plus', function () {
    var r = cadence(1000 / 144, 20, 0, 30, 15);
    check(r.fx <= 30 && r.fx >= 27, 'braises ' + r.fx);
    check(r.world <= 15 && r.world >= 13.5, 'paysage ' + r.world);
  });
  test('cadence : page lente (braises à 20 i/s) → paysage à 10 i/s, jamais à chaque image', function () {
    var r = cadence(50, 20, 0, 30, 15);
    near(r.fx, 20, 0.5, 'braises');
    near(r.world, 10, 0.5, 'paysage');
  });
  test('cadence : paysage jamais au-dessus des braises ; réglage absent → celui des braises', function () {
    near(cadence(1000 / 60, 10, 0, 30, 60).world, 30, 1, 'paysage à 60 demandé');
    near(cadence(1000 / 60, 10, 0, 30, undefined).world, 30, 1, 'worldFpsMax absent');
  });
  test('basse est terminal', function () {
    var m = quality.meter('basse');
    check(quality.step(m, 100, OPTS) === m, 'mesure changée');
    eq(feed(quality.meter('moyenne'), 0, 20000, 80).level, 'basse');
    eq(quality.lower('basse'), 'basse');
  });

  out('text');
  test('splitKeys : touche puis texte', function () {
    eq(text.splitKeys('[[F1]] ouvre'), [{ key: 'F1' }, { text: ' ouvre' }]);
    eq(text.splitKeys('Sans touche.'), [{ text: 'Sans touche.' }]);
    eq(text.splitKeys('a [[I]] b [[Z]]'), [{ text: 'a ' }, { key: 'I' }, { text: ' b ' }, { key: 'Z' }]);
  });
  test('splitKeys : crochets non fermés → texte brut', function () {
    eq(text.splitKeys('[[F1 ouvre'), [{ text: '[[F1 ouvre' }]);
    eq(text.splitKeys('x [[F1]] y [[Z'), [{ text: 'x ' }, { key: 'F1' }, { text: ' y [[Z' }]);
  });
  test('splitKeys : 4e touche → texte brut', function () {
    eq(text.splitKeys('[[A]][[B]][[C]][[D]]'), [{ key: 'A' }, { key: 'B' }, { key: 'C' }, { text: '[[D]]' }]);
  });
  test('splitKeys : touche de 13 octets → texte brut ; 12 octets → touche', function () {
    eq(text.splitKeys('[[ABCDEFGHIJKLM]] x'), [{ text: '[[ABCDEFGHIJKLM]] x' }]);
    eq(text.splitKeys('[[ABCDEFGHIJKL]]'), [{ key: 'ABCDEFGHIJKL' }]);
    eq(text.splitKeys('[[ÉÉÉÉÉÉÉ]]'), [{ text: '[[ÉÉÉÉÉÉÉ]]' }], '7 × 2 octets');
    eq(text.splitKeys('[[]]'), [{ text: '[[]]' }], 'touche vide');
  });
  test('splitKeys : chaque conseil de strings.js donne au moins un morceau, au plus 3 touches', function () {
    S.tips.forEach(function (tip) {
      var parts = text.splitKeys(tip);
      check(parts.length > 0, tip);
      check(parts.filter(function (p) { return p.key !== undefined; }).length <= 3, tip);
    });
  });
  test('format', function () {
    eq(text.format('Étape {n} sur {total}', { n: 2, total: 6 }), 'Étape 2 sur 6');
    eq(text.format('{done} / {total} fichiers', { done: 0, total: 380 }), '0 / 380 fichiers');
    eq(text.format('{x}', {}), '{x}');
  });
  test('order : permutation complète', function () {
    var rnd = seeded(7);
    for (var n = 1; n <= 12; n++) {
      var p = text.order(n, null, rnd).slice().sort(function (a, b) { return a - b; });
      eq(p, Array.from({ length: n }, function (_, i) { return i; }), 'n = ' + n);
    }
  });
  test('cycle : chaque tour complet, jamais deux fois le même de suite (n > 1)', function () {
    [2, 3, 6, 8].forEach(function (n) {
      var next = text.cycle(n, seeded(n * 31)), prev = -1;
      for (var round = 0; round < 200; round++) {
        var seen = {};
        for (var i = 0; i < n; i++) {
          var v = next();
          check(v !== prev, 'n = ' + n + ' : ' + v + ' deux fois de suite');
          check(!seen[v], 'n = ' + n + ' : répété dans un tour');
          seen[v] = true; prev = v;
        }
      }
    });
  });
  test('cycle : n = 1 → toujours 0 ; n = 0 → -1', function () {
    var one = text.cycle(1);
    for (var i = 0; i < 5; i++) eq(one(), 0);
    eq(text.cycle(0)(), -1);
  });

  out('config et textes');
  test('config.stages : 6 entiers croissants de 0 à 99', function () {
    eq(cfg.stages.length, 6);
    eq(cfg.stages[0], 0);
    cfg.stages.forEach(function (v, i) {
      check(Number.isInteger(v) && v >= 0 && v <= 99, 'valeur ' + v);
      if (i > 0) check(v > cfg.stages[i - 1], 'non croissant');
    });
  });
  test('config : journal coupé, niveaux complets', function () {
    eq(cfg.debug.journal, false);
    ['haute', 'moyenne', 'basse'].forEach(function (l) {
      var lv = cfg.effects.levels[l];
      check(lv, l);
      ['parallax', 'camera', 'comet', 'grain', 'shine'].forEach(function (k) { eq(typeof lv[k], 'boolean', l + '.' + k); });
      check(Number.isInteger(lv.fogs) && lv.fogs >= 0, l + '.fogs');
    });
    eq(cfg.effects.levels.basse.embers, 0);
    eq(cfg.effects.levels.basse.grain, false, 'basse : sans grain');
    eq(cfg.effects.levels.basse.shine, false, 'basse : sans reflet');
  });
  test('config : paysage plafonné sous les braises', function () {
    check(cfg.effects.fpsMax > 0 && cfg.effects.fpsMax <= 30, 'fpsMax');
    check(cfg.effects.worldFpsMax > 0 && cfg.effects.worldFpsMax <= cfg.effects.fpsMax, 'worldFpsMax');
  });
  test('strings : 6 étapes, 6 à 40 extraits, 6 à 20 conseils, 240 octets au plus, aucun chevron', function () {
    eq(S.stages.length, 6);
    check(S.quotes.length >= 6 && S.quotes.length <= 40, 'extraits');
    check(S.tips.length >= 6 && S.tips.length <= 20, 'conseils');
    S.quotes.concat(S.tips).forEach(function (t) { check(text.utf8Length(t) <= 240, t); });
    (function walk(v) {
      if (typeof v === 'string') check(v.indexOf('<') < 0, v);
      else if (v && typeof v === 'object') Object.keys(v).forEach(function (k) { walk(v[k]); });
    })(S);
  });

  out('');
  out(passed + ' essais réussis, ' + failed + ' échec(s)');
  if (inNode) { if (failed > 0) process.exitCode = 1; }
  else {
    var pre = document.getElementById('sortie');
    if (pre) { pre.textContent = lines.join('\n'); pre.className = failed ? 'echec' : 'ok'; }
  }
})();
