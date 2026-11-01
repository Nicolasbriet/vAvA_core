'use strict';
/*
 * web/js/numbers.js
 * Rôle : chiffres des coups (T-155), sans DOM : messages relus (types, classes permises), plus anciens retirés quand
 *        un chiffre de trop arrive (le Lua les oublie sans message), position en transform. Bornes, mots et débit :
 *        garantis par le Lua (client/numbers.lua), seul émetteur.
 * Dépendances : aucune ; window.HudNumbers dans la page, module.exports sous node (web/dev/essais.js)
 */

const HudNumbers = (() => {
  const CLASSES = ['dealt', 'taken', 'small', 'big', 'huge', 'word'];
  const DEFAULTS = Object.freeze({ durationMs: 900, riseVh: 5, followMs: 100, maxAlive: 10 });
  const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
  const num = (v) => typeof v === 'number' && Number.isFinite(v);
  const round3 = (v) => Math.round(v * 1000) / 1000;

  function rules(raw) {
    const out = { ...DEFAULTS };
    if (isObject(raw)) for (const key of Object.keys(DEFAULTS)) if (num(raw[key])) out[key] = raw[key];
    return out;
  }

  function read(raw) {
    if (!isObject(raw) || !Number.isSafeInteger(raw.id) || !num(raw.x) || !num(raw.y)) return null;
    if (typeof raw.text !== 'string' || typeof raw.cls !== 'string') return null;
    return { id: raw.id, x: raw.x, y: raw.y, dx: num(raw.dx) ? raw.dx : 0, dy: num(raw.dy) ? raw.dy : 0,
      text: raw.text, sub: typeof raw.sub === 'string' ? raw.sub : null,
      cls: raw.cls.split(' ').filter((c) => CLASSES.includes(c)) };
  }

  function moves(raw) {
    return isObject(raw) && Array.isArray(raw.list) ? raw.list.filter((e) => isObject(e) && Number.isSafeInteger(e.id))
      .map((e) => ({ id: e.id, x: num(e.x) ? e.x : null, y: num(e.y) ? e.y : null, hidden: e.hidden === true })) : [];
  }

  function evict(order, max) {
    return order.slice(0, Math.max(0, order.length - max + 1));
  }

  function place(x, y, dx, dy) {
    return `translate3d(${round3(x * 100 + dx)}vw, ${round3(y * 100 + dy)}vh, 0)`;
  }

  return { DEFAULTS, rules, read, moves, evict, place };
})();

if (typeof module === 'object' && module && module.exports) module.exports = HudNumbers;
