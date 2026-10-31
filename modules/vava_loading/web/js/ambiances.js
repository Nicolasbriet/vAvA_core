/*
 * vava_loading/web/js/ambiances.js
 * Rôle : logique pure des ambiances d'Eldoria (T-152) : réglages bornés, ordre (première au hasard, puis la suite,
 *        en boucle), image en erreur sautée, arrêt quand plus rien d'autre ne peut venir, dérive.
 *        Sans DOM ni minuteur : essayé par web/dev/essais.js ; js/scene.js s'en sert.
 * Dépendances : aucune
 */
(function (root) {
  'use strict';

  var VavaLoading = root.VavaLoading = root.VavaLoading || {};

  var FOLDER = 'img/ambiances/'; // seul dossier lu
  var EXT = '.webp';
  var NAME = /^[a-z0-9_]{1,32}$/;
  var MAX_NAMES = 12;
  var DEFAULT_ORDER = ['aube', 'brume_matin', 'hiver', 'crepuscule', 'nuit_etoilee', 'brume_nuit', 'orage'];
  // hors bornes → borne la plus proche ; pas un nombre fini → fallback
  var LIMITS = {
    showMs: { min: 3000, max: 60000, fallback: 9000 },
    fadeMs: { min: 300, max: 6000, fallback: 3000 },
    driftPct: { min: 0, max: 5, fallback: 3 },
  };

  function bound(value, limit) {
    if (typeof value !== 'number' || !isFinite(value)) return limit.fallback;
    return Math.min(limit.max, Math.max(limit.min, value));
  }

  /**
   * Réglages bornés (config.ambiances). Ordre : noms simples sans doublon, 12 au plus ; aucun nom valable → les sept.
   * Fondu jamais plus long que la moitié d'une ambiance.
   */
  function settings(raw) {
    raw = raw && typeof raw === 'object' ? raw : {};
    var order = [];
    if (Array.isArray(raw.order)) {
      for (var i = 0; i < raw.order.length && order.length < MAX_NAMES; i++) {
        var name = raw.order[i];
        if (typeof name === 'string' && NAME.test(name) && order.indexOf(name) < 0) order.push(name);
      }
    }
    if (!order.length) order = DEFAULT_ORDER.slice();
    var showMs = Math.round(bound(raw.showMs, LIMITS.showMs));
    var fadeMs = Math.min(Math.round(bound(raw.fadeMs, LIMITS.fadeMs)), Math.floor(showMs / 2));
    var driftPct = Math.round(bound(raw.driftPct, LIMITS.driftPct) * 10) / 10;
    return {
      order: order,
      files: order.map(function (n) { return FOLDER + n + EXT; }),
      showMs: showMs, fadeMs: fadeMs, driftPct: driftPct,
    };
  }

  /** État de départ : la première tirée par rnd (Math.random ; hors de [0, 1[ → 0) ; rien de montré (current -1). */
  function initial(count, rnd) {
    var n = typeof count === 'number' && count > 0 ? Math.floor(count) : 0;
    var r = (rnd || Math.random)();
    if (!(typeof r === 'number' && r >= 0 && r < 1)) r = 0;
    var failed = [];
    for (var i = 0; i < n; i++) failed.push(false);
    var start = n ? Math.min(n - 1, Math.floor(r * n)) : 0;
    return { count: n, start: start, next: start, current: -1, failed: failed };
  }

  function copy(s) {
    return { count: s.count, start: s.start, next: s.next, current: s.current, failed: s.failed.slice() };
  }

  /** Image à charger ensuite : la première de la suite, ni en erreur ni à l'écran ; -1 s'il n'y en a plus. */
  function pick(s) {
    for (var k = 0; k < s.count; k++) {
      var i = (s.next + k) % s.count;
      if (!s.failed[i] && i !== s.current) return i;
    }
    return -1;
  }

  /** Image i en erreur : jamais redemandée ; la suite reprend après elle. */
  function failed(s, i) {
    if (!(i >= 0 && i < s.count)) return s;
    var n = copy(s);
    n.failed[i] = true;
    n.next = (i + 1) % s.count;
    return n;
  }

  /** Image i affichée : la suivante est celle d'après. */
  function shown(s, i) {
    if (!(i >= 0 && i < s.count)) return s;
    var n = copy(s);
    n.current = i;
    n.next = (i + 1) % s.count;
    return n;
  }

  /** Dérive permise : drapeau drift du niveau (coupé en basse), ni moins d'animations demandé, ni 0 %. */
  function driftOn(levelFlags, reducedMotion, driftPct) {
    return !!(levelFlags && levelFlags.drift) && !reducedMotion && typeof driftPct === 'number' && driftPct > 0;
  }

  /**
   * Dérive de la step-ième image (sens alterné) : zoom de 1 + d à 1 + 2d, glissement de pct/3 % en largeur et pct/6 %
   * en hauteur, toujours sous la moitié du surplus du zoom : le bord de l'image n'apparaît jamais.
   */
  function drift(step, pct) {
    var p = bound(pct, { min: 0, max: LIMITS.driftPct.max, fallback: 0 });
    var dir = step % 2 === 0 ? 1 : -1;
    var r = function (v) { return Math.round(v * 1000) / 1000 || 0; };
    return { s0: r(1 + p / 100), s1: r(1 + 2 * p / 100), x0: r(-dir * p / 3), x1: r(dir * p / 3), y0: r(p / 6), y1: r(-p / 6) };
  }

  VavaLoading.ambiances = {
    FOLDER: FOLDER, DEFAULT_ORDER: DEFAULT_ORDER, LIMITS: LIMITS,
    settings: settings, initial: initial, pick: pick, failed: failed, shown: shown, driftOn: driftOn, drift: drift,
  };

  if (typeof module === 'object' && module.exports) module.exports = VavaLoading.ambiances;
})(typeof window !== 'undefined' ? window : globalThis);
