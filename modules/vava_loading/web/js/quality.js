/*
 * vava_loading/web/js/quality.js
 * Rôle : logique pure du niveau d'effets (spec T-020 § 8.3) : niveau de départ (réglage, moins d'animations demandé,
 *        nombre de cœurs) et dégradation en cours de route d'après l'intervalle entre les images déjà dessinées.
 *        Jamais de remontée : pas d'oscillation pendant les à-coups du chargement ; `basse` est terminal.
 *        Aucun minuteur : la page appelle step() à chaque image dessinée.
 * Dépendances : aucune
 */
(function (root) {
  'use strict';

  var VavaLoading = root.VavaLoading = root.VavaLoading || {};

  var LEVELS = ['haute', 'moyenne', 'basse'];
  var PAUSE_MS = 1000; // intervalle plus long : page en pause (ou figée par le chargement), ignoré

  /**
   * Niveau de départ.
   * @param {{level?: string, reducedMotion?: boolean, cores?: number}} env
   * @return {string} 'haute' | 'moyenne' | 'basse'
   */
  function initial(env) {
    env = env || {};
    if (env.level !== 'auto' && LEVELS.indexOf(env.level) >= 0) return env.level;
    if (env.reducedMotion) return 'basse';
    if (typeof env.cores === 'number' && env.cores > 0 && env.cores <= 2) return 'moyenne';
    return 'haute';
  }

  /** Niveau juste en dessous (basse reste basse). */
  function lower(level) {
    var i = LEVELS.indexOf(level);
    return i < 0 ? 'basse' : LEVELS[Math.min(LEVELS.length - 1, i + 1)];
  }

  /** Mesure de départ pour `level`. */
  function meter(level) {
    return { level: level, last: null, start: null, sum: 0, frames: 0, bad: 0 };
  }

  /**
   * Mesure après une image dessinée à l'instant `now` (ms) ; rend une nouvelle mesure (l'ancienne n'est pas modifiée),
   * dont `level` a baissé d'un cran après `badWindows` fenêtres lentes de suite.
   * @param {Object} m  mesure (meter)
   * @param {number} now
   * @param {{minFps: number, windowMs: number, badWindows: number}} opts
   * @return {Object}
   */
  function step(m, now, opts) {
    if (m.level === 'basse' || typeof now !== 'number' || !isFinite(now)) return m;
    var next = { level: m.level, last: now, start: m.start, sum: m.sum, frames: m.frames, bad: m.bad };
    if (m.last === null) { next.start = now; return next; }
    var dt = now - m.last;
    if (dt < 0) return m;
    if (dt > PAUSE_MS) { next.start += dt; return next; } // la pause ne compte pas dans la fenêtre
    next.sum += dt; next.frames += 1;
    if (now - next.start >= opts.windowMs) {
      var slow = next.frames > 0 && next.sum / next.frames > 1000 / opts.minFps;
      next.bad = slow ? next.bad + 1 : 0;
      next.start = now; next.sum = 0; next.frames = 0;
      if (next.bad >= opts.badWindows) { next.level = lower(next.level); next.bad = 0; }
    }
    return next;
  }

  VavaLoading.quality = { LEVELS: LEVELS, initial: initial, lower: lower, meter: meter, step: step };

  if (typeof module === 'object' && module.exports) module.exports = VavaLoading.quality;
})(typeof window !== 'undefined' ? window : globalThis);
