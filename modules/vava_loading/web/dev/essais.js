/*
 * vava_loading/web/dev/essais.js
 * Rôle : essais des fonctions pures de la page (js/progress.js, js/quality.js : niveaux et cadence des braises,
 *        js/text.js, js/ambiances.js : réglages, ordre, images sautées, dérive) et forme de js/config.js et
 *        js/strings.js ; sous node, les fichiers des ambiances (WebP présents). Sans dépendance : `node modules/vava_loading/web/dev/essais.js` (code de sortie 1 au moindre
 *        échec), ou web/dev/essais.html ouvert dans un navigateur. Jamais livré.
 * Dépendances : js/config.js, js/strings.js, js/text.js, js/progress.js, js/quality.js, js/ambiances.js
 */
(function () {
  'use strict';

  var inNode = typeof module === 'object' && typeof require === 'function' && typeof window === 'undefined';
  var V;
  if (inNode) {
    require('../js/config.js'); require('../js/strings.js'); require('../js/text.js');
    require('../js/progress.js'); require('../js/quality.js'); require('../js/ambiances.js');
    V = globalThis.VavaLoading;
  } else V = window.VavaLoading;

  var progress = V.progress, quality = V.quality, text = V.text, cfg = V.config, S = V.strings, amb = V.ambiances;
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
  // Boucle de scene.js rejouée sur des horodatages d'images : une image des braises si due. Rend le nombre d'images
  // par seconde et le plus grand écart entre deux images. (Avant T-152, le paysage peint avait sa propre cadence,
  // worldDue : retirée avec lui ; les ambiances ne sont plus dessinées par le script.)
  function cadence(periodMs, seconds, jitterMs, fxFps) {
    var rnd = seeded(11), t = 1000, end = 1000 + seconds * 1000, last = 0, fx = 0, gap = 0;
    while (t < end) {
      t += periodMs + (jitterMs ? (rnd() - 0.5) * 2 * jitterMs : 0);
      if (!quality.due(last, t, fxFps)) continue;
      if (last) gap = Math.max(gap, t - last);
      last = t; fx++;
    }
    return { fx: fx / seconds, gap: gap };
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
  test('cadence à 60 Hz : braises à 30 i/s, une image sur deux', function () {
    var r = cadence(1000 / 60, 20, 0, 30);
    near(r.fx, 30, 0.2, 'braises');
    check(r.gap < 36, 'écart des braises ' + r.gap.toFixed(1) + ' ms');
  });
  test('cadence à 60 Hz, horloge qui vacille de 2 ms : braises à 30 i/s au plus, jamais un trou de trois images', function () {
    var r = cadence(1000 / 60, 20, 2, 30);
    check(r.fx <= 30 && r.fx >= 20, 'braises ' + r.fx);
    check(r.gap < 55, 'écart des braises ' + r.gap.toFixed(1) + ' ms');
  });
  test('cadence à 144 Hz : 30 i/s au plus', function () {
    var r = cadence(1000 / 144, 20, 0, 30);
    check(r.fx <= 30 && r.fx >= 27, 'braises ' + r.fx);
  });
  test('cadence : page lente (20 i/s) → braises à chaque image, sans plus', function () {
    near(cadence(50, 20, 0, 30).fx, 20, 0.5, 'braises');
  });
  test('basse est terminal', function () {
    var m = quality.meter('basse');
    check(quality.step(m, 100, OPTS) === m, 'mesure changée');
    eq(feed(quality.meter('moyenne'), 0, 20000, 80).level, 'basse');
    eq(quality.lower('basse'), 'basse');
  });

  out('ambiances');
  var ORDER = ['aube', 'brume_matin', 'hiver', 'crepuscule', 'nuit_etoilee', 'brume_nuit', 'orage'];
  // départ forcé : `start` tiré par un hasard injecté
  function from(start, count) { return function () { return (start + 0.5) / count; }; }
  /**
   * Boucle de scene.js rejouée sans DOM ni minuteur : à chaque tour, l'image choisie est chargée ; si elle est dans
   * `bad`, elle échoue (sautée), sinon elle est montrée. Rend les images montrées, les essais de chargement, et si la
   * boucle s'est arrêtée d'elle-même.
   */
  function play(count, start, bad, maxShown) {
    var s = amb.initial(count, from(start, count)), shown = [], tries = [], guard = 0;
    while (shown.length < maxShown && guard++ < 1000) {
      var i = amb.pick(s);
      if (i < 0) break;
      tries.push(i);
      if (bad.indexOf(i) >= 0) s = amb.failed(s, i);
      else { s = amb.shown(s, i); shown.push(i); }
    }
    return { shown: shown, tries: tries, stopped: amb.pick(s) < 0 };
  }
  test('réglages absents ou illisibles : les sept ambiances, 9 s, fondu de 3 s, dérive de 3 %', function () {
    [undefined, null, {}, 'x', 42, []].forEach(function (raw) {
      var r = amb.settings(raw);
      eq(r.order, ORDER, 'ordre'); eq(r.showMs, 9000, 'showMs'); eq(r.fadeMs, 3000, 'fadeMs'); eq(r.driftPct, 3, 'driftPct');
    });
  });
  test('réglages hors bornes ramenés à la borne, valeur non numérique → défaut', function () {
    var lo = amb.settings({ showMs: 100, fadeMs: 50, driftPct: -1 });
    eq([lo.showMs, lo.fadeMs, lo.driftPct], [3000, 300, 0], 'bornes basses');
    var hi = amb.settings({ showMs: 1e9, fadeMs: 99999, driftPct: 9 });
    eq([hi.showMs, hi.fadeMs, hi.driftPct], [60000, 6000, 5], 'bornes hautes');
    var bad = amb.settings({ showMs: NaN, fadeMs: '3000', driftPct: Infinity });
    eq([bad.showMs, bad.fadeMs, bad.driftPct], [9000, 3000, 3], 'pas des nombres finis');
    var odd = amb.settings({ showMs: 8999.6, fadeMs: 2999.4, driftPct: 2.44 });
    eq([odd.showMs, odd.fadeMs, odd.driftPct], [9000, 2999, 2.4], 'arrondis');
  });
  test('fondu jamais plus long que la moitié d\'une ambiance', function () {
    eq(amb.settings({ showMs: 3000, fadeMs: 6000 }).fadeMs, 1500);
    eq(amb.settings({ showMs: 5001, fadeMs: 3000 }).fadeMs, 2500);
    eq(amb.settings({ showMs: 9000, fadeMs: 3000 }).fadeMs, 3000);
  });
  test('ordre : noms simples seulement, sans doublon, 12 au plus ; fichiers toujours sous img/ambiances/', function () {
    var r = amb.settings({ order: ['hiver', '../secret', 'Orage', 'x.webp', 'nuit etoilee', 42, null, '', 'hiver', 'orage',
      'exemple:hote', 'a'.repeat(33), 'a'.repeat(32)] });
    eq(r.order, ['hiver', 'orage', 'a'.repeat(32)]);
    eq(r.files, ['img/ambiances/hiver.webp', 'img/ambiances/orage.webp', 'img/ambiances/' + 'a'.repeat(32) + '.webp']);
    var many = []; for (var i = 0; i < 20; i++) many.push('n' + i);
    eq(amb.settings({ order: many }).order.length, 12, '12 au plus');
    eq(amb.settings({ order: ['../x', 'A'] }).order, ORDER, 'aucun nom valable : les sept');
    eq(amb.settings({ order: 'aube' }).order, ORDER, 'pas une liste : les sept');
    amb.settings({ order: many.concat(ORDER) }).files.forEach(function (f) {
      check(/^img\/ambiances\/[a-z0-9_]{1,32}\.webp$/.test(f), f);
    });
  });
  test('départ tiré au hasard (injecté) : chaque ambiance peut ouvrir ; hasard hors de [0, 1[ → la première', function () {
    eq(amb.initial(7, function () { return 0; }).start, 0);
    eq(amb.initial(7, function () { return 0.5; }).start, 3);
    eq(amb.initial(7, function () { return 0.9999; }).start, 6);
    [1, -0.2, NaN, Infinity, '0.5', undefined].forEach(function (v) {
      eq(amb.initial(7, function () { return v; }).start, 0, String(v));
    });
    var seen = {}, rnd = seeded(5);
    for (var k = 0; k < 400; k++) seen[amb.initial(7, rnd).start] = true;
    eq(Object.keys(seen).length, 7, 'les sept départs atteints');
    eq(amb.initial(0).count, 0);
    eq(amb.pick(amb.initial(0)), -1, 'aucune image : rien à charger');
  });
  test('ordre à partir de chaque départ, puis rebouclage : aube → brume_matin → … → orage → aube', function () {
    for (var start = 0; start < 7; start++) {
      var r = play(7, start, [], 16), want = [];
      for (var k = 0; k < 16; k++) want.push((start + k) % 7);
      eq(r.shown, want, 'départ ' + ORDER[start]);
      eq(r.tries, want, 'une image chargée par ambiance, jamais deux d\'un coup');
    }
    eq(play(7, 4, [], 3).shown.map(function (i) { return ORDER[i]; }), ['nuit_etoilee', 'brume_nuit', 'orage']);
    eq(play(7, 6, [], 2).shown.map(function (i) { return ORDER[i]; }), ['orage', 'aube'], 'reboucle après l\'orage');
  });
  test('image en erreur : sautée, jamais redemandée, la suite continue', function () {
    var r = play(7, 1, [2], 13);
    eq(r.shown, [1, 3, 4, 5, 6, 0, 1, 3, 4, 5, 6, 0, 1]);
    eq(r.tries.filter(function (i) { return i === 2; }).length, 1, 'essayée une seule fois');
    var first = play(7, 0, [0, 1], 3);
    eq(first.shown, [2, 3, 4], 'départ en erreur : la suivante qui se charge');
  });
  test('toutes en erreur : rien de montré, sept essais puis arrêt (fond de repli)', function () {
    var r = play(7, 3, [0, 1, 2, 3, 4, 5, 6], 50);
    eq(r.shown, []); eq(r.tries.length, 7); eq(r.stopped, true);
  });
  test('une seule image lisible : montrée, puis la boucle s\'arrête sur elle (pas de fondu vers elle-même)', function () {
    var r = play(7, 5, [0, 1, 2, 3, 4, 6], 50);
    eq(r.shown, [5]); eq(r.stopped, true);
    check(r.tries.length <= 7, r.tries.length + ' essais');
    var one = play(1, 0, [], 50);
    eq(one.shown, [0]); eq(one.stopped, true);
  });
  test('failed et shown ne modifient pas l\'ancien état ; index hors de la liste → état rendu tel quel', function () {
    var a = amb.initial(7, from(2, 7)), copy = JSON.stringify(a);
    amb.failed(a, 2); amb.shown(a, 3);
    eq(JSON.stringify(a), copy);
    check(amb.failed(a, 7) === a && amb.failed(a, -1) === a && amb.shown(a, NaN) === a, 'hors de la liste');
  });
  test('dérive : jamais en basse, ni si le joueur demande moins d\'animations, ni à 0 %', function () {
    eq(amb.driftOn(cfg.effects.levels.haute, false, 3), true, 'haute');
    eq(amb.driftOn(cfg.effects.levels.moyenne, false, 3), true, 'moyenne');
    eq(amb.driftOn(cfg.effects.levels.basse, false, 3), false, 'basse');
    eq(amb.driftOn(cfg.effects.levels.haute, true, 3), false, 'moins d\'animations');
    eq(amb.driftOn(cfg.effects.levels.haute, false, 0), false, '0 %');
    eq(amb.driftOn(undefined, false, 3), false, 'niveau inconnu');
    // niveau de départ quand le joueur demande moins d'animations : basse, donc fondu seul
    eq(amb.driftOn(cfg.effects.levels[quality.initial({ level: 'auto', reducedMotion: true, cores: 16 })], false, 3), false);
  });
  test('dérive : sens alterné, zoom croissant, bord de l\'image jamais découvert (0 à 5 %)', function () {
    var a = amb.drift(0, 3), b = amb.drift(1, 3);
    eq([a.s0, a.s1], [1.03, 1.06]); check(a.x0 < 0 && a.x1 > 0, 'vers la droite'); check(b.x0 > 0 && b.x1 < 0, 'vers la gauche');
    eq(amb.drift(0, 0), { s0: 1, s1: 1, x0: 0, x1: 0, y0: 0, y1: 0 }, '0 % : immobile');
    eq(amb.drift(0, 50).s1, 1.1, 'amplitude bornée à 5 %');
    for (var p = 0; p <= 5; p += 0.5) {
      [0, 1].forEach(function (step) {
        var d = amb.drift(step, p);
        for (var u = 0; u <= 1.0001; u += 0.05) { // l'animation interpole zoom et glissement séparément
          var sc = d.s0 + (d.s1 - d.s0) * u, x = d.x0 + (d.x1 - d.x0) * u, y = d.y0 + (d.y1 - d.y0) * u;
          var margin = (sc - 1) / 2 * 100 + 1e-9;
          check(Math.abs(x) * sc <= margin && Math.abs(y) * sc <= margin, p + ' % à ' + u.toFixed(2) + ' : bord découvert');
        }
      });
    }
  });
  if (inNode) {
    test('les sept ambiances de config.js existent dans web/img/ambiances/, en WebP, 300 Ko au plus chacune', function () {
      var fs = require('fs'), path = require('path');
      amb.settings(cfg.ambiances).files.forEach(function (f) {
        var file = path.join(__dirname, '..', f), buf = fs.readFileSync(file);
        eq(buf.toString('latin1', 0, 4) + buf.toString('latin1', 8, 12), 'RIFFWEBP', f);
        check(buf.length <= 300 * 1024, f + ' : ' + buf.length + ' octets');
      });
    });
  }

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
      ['parallax', 'drift', 'grain', 'shine'].forEach(function (k) { eq(typeof lv[k], 'boolean', l + '.' + k); });
      ['embers', 'letterSparks', 'beaconSparks', 'finalSparks'].forEach(function (k) {
        check(Number.isInteger(lv[k]) && lv[k] >= 0, l + '.' + k);
      });
    });
    eq(cfg.effects.levels.basse.embers, 0);
    eq(cfg.effects.levels.basse.drift, false, 'basse : sans dérive');
    eq(cfg.effects.levels.basse.grain, false, 'basse : sans grain');
    eq(cfg.effects.levels.basse.shine, false, 'basse : sans reflet');
  });
  test('config : braises plafonnées à 30 i/s ; ambiances dans l\'ordre voulu, réglages déjà dans leurs bornes', function () {
    check(cfg.effects.fpsMax > 0 && cfg.effects.fpsMax <= 30, 'fpsMax');
    eq(cfg.ambiances.order, ORDER, 'ordre du porteur du projet');
    var r = amb.settings(cfg.ambiances);
    eq([r.order, r.showMs, r.fadeMs, r.driftPct], [cfg.ambiances.order, cfg.ambiances.showMs, cfg.ambiances.fadeMs,
      cfg.ambiances.driftPct], 'aucune valeur ramenée en silence');
    check(r.showMs >= 8000 && r.showMs <= 10000 && r.fadeMs >= 2500 && r.fadeMs <= 3500, '≈ 9 s, fondu ≈ 3 s');
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
