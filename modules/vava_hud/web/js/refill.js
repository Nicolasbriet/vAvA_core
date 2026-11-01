'use strict';
/*
 * web/js/refill.js
 * Rôle : remontée d'une jauge (T-114), sans DOM : palier d'une valeur, remontée relue (bornes garanties par le Lua,
 *        client/gauges.lua), plan de la remontée : départ différé d'au moins 600 ms (la baisse se peint d'abord),
 *        durée d'une transition linéaire jusqu'au plein, instants où l'anneau franchit `critical` puis `low` et fin ;
 *        médaillons laissés en place quand l'ordre change (un nœud sorti du document perdrait sa transition).
 * Dépendances : aucune ; window.HudRefill dans la page, module.exports sous node (web/dev/essais.js)
 */

const HudRefill = (() => {
  const MIN_DELAY_MS = 600;
  const MAX_TIMER_MS = 2147483647;
  const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
  const num = (v) => typeof v === 'number' && Number.isFinite(v);

  function level(value, low, critical) {
    if (value <= critical) return 'critical';
    if (value <= low) return 'low';
    return 'ok';
  }

  function read(raw, value) {
    if (!isObject(raw) || !num(raw.perSecond) || !num(raw.delayMs) || !num(value) || value >= 1) return null;
    if (raw.perSecond <= 0 || raw.delayMs < 0) return null;
    return { perSecond: raw.perSecond, delayMs: raw.delayMs };
  }

  // étapes : { at (ms après le message), value, level } ; la dernière est le plein
  function plan(value, raw, low, critical) {
    const refill = read(raw, value);
    if (!refill) return null;
    const from = Math.max(0, value);
    const startMs = Math.max(Math.round(refill.delayMs), MIN_DELAY_MS);
    const durationMs = Math.max(1, Math.round(((1 - from) / refill.perSecond) * 1000));
    // au-delà, setTimeout partirait aussitôt
    if (startMs + durationMs > MAX_TIMER_MS) return null;
    const steps = [];
    for (const mark of [critical, low]) {
      if (from > mark || mark >= 1 || steps.some((s) => s.value === mark)) continue;
      steps.push({ at: startMs + Math.ceil(((mark - from) / refill.perSecond) * 1000), value: mark, level: level(mark + 1e-9, low, critical) });
    }
    steps.push({ at: startMs + durationMs, value: 1, level: level(1, low, critical) });
    return { from, startMs, durationMs, steps };
  }

  // ordre des médaillons : indices d'une plus longue suite croissante de `positions` (place actuelle, -1 : nouveau),
  // ceux qui peuvent rester en place
  function steady(positions) {
    const len = [];
    const prev = [];
    let best = -1;
    positions.forEach((p, i) => {
      len[i] = p < 0 ? 0 : 1;
      prev[i] = -1;
      if (p < 0) return;
      for (let j = 0; j < i; j += 1) {
        if (positions[j] >= 0 && positions[j] < p && len[j] + 1 > len[i]) { len[i] = len[j] + 1; prev[i] = j; }
      }
      if (best < 0 || len[i] > len[best]) best = i;
    });
    const out = [];
    for (let i = best; i >= 0; i = prev[i]) out.unshift(i);
    return out;
  }

  return { level, read, plan, steady };
})();

if (typeof module === 'object' && module && module.exports) module.exports = HudRefill;
