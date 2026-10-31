'use strict';
/*
 * web/js/numbers.js
 * Rôle : règles pures des chiffres des coups (T-155), sans DOM : rythme (`init.numbers`) borné, messages `number` et
 *        `numbersMove` relus (une valeur inattendue devient une absence), filets de la page (maxAlive à l'écran,
 *        maxPerSecond), position en transform. Texte, mot, arrondi, cascade et réglage sont décidés en Lua.
 * Dépendances : aucune ; window.HudNumbers dans la page, module.exports sous node (web/dev/essais.js)
 */

const HudNumbers = (() => {
  const SIDES = ['dealt', 'taken'];
  const SIZES = ['small', 'big', 'huge'];
  const MAX_TEXT = 32;
  const MAX_MOVES = 30;
  const MAX_OFFSET = 20;   // cascade : vw de côté, vh de hauteur
  // config_client.lua (numbers) et bornes de son contrôle au démarrage
  const DEFAULTS = Object.freeze({ durationMs: 900, riseVh: 5, followMs: 100, maxAlive: 10, maxPerSecond: 16 });
  const BOUNDS = { durationMs: [400, 3000], riseVh: [0, 20], followMs: [50, 500], maxAlive: [1, 30], maxPerSecond: [1, 60] };

  const finite = (v) => typeof v === 'number' && Number.isFinite(v);
  const clamp = (v, min, max) => Math.min(max, Math.max(min, v));
  const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
  const round3 = (v) => Math.round(v * 1000) / 1000;
  const id = (v) => (Number.isSafeInteger(v) && v > 0 ? v : null);
  const coord = (v) => (finite(v) ? clamp(v, 0, 1) : null);
  const offset = (v) => (finite(v) ? clamp(v, -MAX_OFFSET, MAX_OFFSET) : 0);

  /** Rythme ; valeur absente ou hors bornes : celle de base. */
  function rules(raw) {
    const out = { ...DEFAULTS };
    for (const [key, [min, max]] of Object.entries(BOUNDS)) {
      const v = isObject(raw) ? raw[key] : undefined;
      if (finite(v) && v >= min && v <= max) out[key] = key === 'riseVh' ? v : Math.round(v);
    }
    return out;
  }

  /** Texte non vide, bords retirés, MAX_TEXT caractères au plus ; sinon null. */
  function text(v) {
    const clean = typeof v === 'string' ? v.trim() : '';
    return clean ? Array.from(clean).slice(0, MAX_TEXT).join('') : null;
  }

  /** Classes permises (chaîne ou liste) : un côté (exigé), une taille, `word` ; sinon null. */
  function classes(raw) {
    const tokens = typeof raw === 'string' ? raw.split(/\s+/) : Array.isArray(raw) ? raw : [];
    const side = tokens.find((t) => SIDES.includes(t));
    if (!side) return null;
    const size = tokens.find((t) => SIZES.includes(t));
    return [side, ...(size ? [size] : []), ...(tokens.includes('word') ? ['word'] : [])];
  }

  /** `number` relu : { id, x, y, dx, dy, text, sub, cls } ou null. */
  function read(raw) {
    if (!isObject(raw)) return null;
    const n = { id: id(raw.id), x: coord(raw.x), y: coord(raw.y), dx: offset(raw.dx), dy: offset(raw.dy),
      text: text(raw.text), sub: text(raw.sub), cls: classes(raw.cls) };
    return n.id === null || n.x === null || n.y === null || !n.text || !n.cls ? null : n;
  }

  /** `numbersMove` relu : [{ id, x, y, hidden }] ; position exigée sauf pour un chiffre caché. */
  function moves(raw) {
    const out = [];
    for (const e of isObject(raw) && Array.isArray(raw.list) ? raw.list.slice(0, MAX_MOVES) : []) {
      if (!isObject(e) || id(e.id) === null) continue;
      const m = { id: e.id, x: coord(e.x), y: coord(e.y), hidden: e.hidden === true };
      if (m.hidden || (m.x !== null && m.y !== null)) out.push(m);
    }
    return out;
  }

  /** Chiffres à retirer, les plus anciens d'abord (`order` : du plus ancien au plus récent), pour qu'un nouveau tienne. */
  function evict(order, max) {
    return order.slice(0, Math.max(0, order.length - (Number.isInteger(max) && max >= 1 ? max : 10) + 1));
  }

  /** Fenêtre d'une seconde : { ok, times } ; `times` purgé, `now` ajouté si admis. */
  function admit(times, now, max) {
    const kept = (Array.isArray(times) ? times : []).filter((t) => now - t < 1000);
    const ok = kept.length < (Number.isInteger(max) && max >= 1 ? max : 16);
    if (ok) kept.push(now);
    return { ok, times: kept };
  }

  /** Transform de l'ancre : position d'écran plus décalage de cascade (aucune propriété de mise en page). */
  function place(x, y, dx, dy) {
    return `translate3d(${round3(x * 100 + (dx || 0))}vw, ${round3(y * 100 + (dy || 0))}vh, 0)`;
  }

  return { DEFAULTS, rules, read, moves, classes, evict, admit, place };
})();

if (typeof module === 'object' && module && module.exports) module.exports = HudNumbers;
