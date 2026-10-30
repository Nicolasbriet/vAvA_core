/*
 * vava_loading/web/js/quality.js
 * Rôle : logique pure du niveau d'effets (spec T-020 § 8.3) : niveau de départ (réglage, moins d'animations demandé,
 *        nombre de cœurs) et dégradation en cours de route d'après l'intervalle entre les images déjà dessinées.
 *        Jamais de remontée : pas d'oscillation pendant les à-coups du chargement ; `basse` est terminal.
 *        Aucun minuteur : la page appelle step() à chaque image dessinée. Cadence des canvas (due) : paysage et braises
 *        n'ont pas le même plafond.
 * Dépendances : aucune
 */
(function (root) {
  'use strict';

  var VavaLoading = root.VavaLoading = root.VavaLoading || {};

  var LEVELS = ['haute', 'moyenne', 'basse'];
  var PAUSE_MS = 1000; // intervalle plus long : page en pause (ou figée par le chargement), ignoré
  var MODEST_CORES = 4; // jusque-là : `moyenne` d'office (le jeu charge sur les mêmes cœurs)
  var SLACK_MS = 1;     // marge par défaut sous l'intervalle visé : à 60 Hz, 30 i/s = une image sur deux

  /**
   * Niveau de départ.
   * @param {{level?: string, reducedMotion?: boolean, cores?: number}} env
   * @return {string} 'haute' | 'moyenne' | 'basse'
   */
  function initial(env) {
    env = env || {};
    if (env.level !== 'auto' && LEVELS.indexOf(env.level) >= 0) return env.level;
    if (env.reducedMotion) return 'basse';
    if (typeof env.cores === 'number' && env.cores > 0 && env.cores <= MODEST_CORES) return 'moyenne';
    return 'haute';
  }

  /**
   * Image à dessiner à l'instant `now` ? `last` : instant de la précédente (0 ou absent : aucune, donc oui) ; `fps` :
   * plafond (absent, nul ou invalide : 30) ; `slack` : marge en ms sous l'intervalle visé (1 par défaut), contre la
   * gigue des images. Ne compte que l'intervalle : le pas de l'animation suit le temps écoulé.
   * @param {number} last
   * @param {number} now
   * @param {number} fps
   * @param {number=} slack
   * @return {boolean}
   */
  function due(last, now, fps, slack) {
    if (!last) return true;
    var cap = typeof fps === 'number' && isFinite(fps) && fps > 0 ? fps : 30;
    var margin = typeof slack === 'number' && isFinite(slack) && slack >= 0 ? slack : SLACK_MS;
    return now - last >= 1000 / cap - margin;
  }

  /**
   * Image du paysage due à l'instant `now` ? Il n'est repeint que sur une image des braises : plafond `worldFps`, jamais
   * au-dessus de `fxFps` ; marge d'un quart d'intervalle des braises (à 30 et 15 i/s : une image des braises sur deux,
   * même si l'horloge des images vacille de quelques ms).
   * @param {number} last  instant de la dernière image du paysage (0 : aucune)
   * @param {number} now
   * @param {number} worldFps
   * @param {number} fxFps
   * @return {boolean}
   */
  function worldDue(last, now, worldFps, fxFps) {
    var fx = typeof fxFps === 'number' && isFinite(fxFps) && fxFps > 0 ? fxFps : 30;
    var world = typeof worldFps === 'number' && isFinite(worldFps) && worldFps > 0 ? Math.min(worldFps, fx) : fx;
    return due(last, now, world, 250 / fx);
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

  VavaLoading.quality = { LEVELS: LEVELS, initial: initial, due: due, worldDue: worldDue, lower: lower, meter: meter, step: step };

  if (typeof module === 'object' && module.exports) module.exports = VavaLoading.quality;
})(typeof window !== 'undefined' ? window : globalThis);
