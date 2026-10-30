'use strict';
/*
 * vava_atelier/web/js/format.js
 * Rôle : fonctions pures (aucun DOM) : nombres et durées à la française, listes du Lua, textes, étiquettes, libellés.
 * Dépendances : strings.js
 */

const Format = (() => {
  const UNIT_SECONDS = Object.freeze({ s: 1, min: 60, h: 3600, j: 86400 });
  const UNIT_ORDER = ['j', 'h', 'min', 's'];
  const NBSP = '\u00a0';
  const encoder = new TextEncoder();

  /** Une liste vide transmise par msgpack devient un objet vide : toujours une vraie liste. */
  const list = (value) => (Array.isArray(value) ? value : (value && typeof value === 'object' ? Object.values(value) : []));

  const str = (value) => (typeof value === 'string' ? value : '');

  const fold = (text) => String(text || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

  const chars = (text) => Array.from(String(text || '')).length;

  function clip(text, max) {
    let out = String(text || '');
    if (encoder.encode(out).length <= max) return out;
    const parts = Array.from(out);
    while (parts.length > 0 && encoder.encode(parts.join('')).length > max) parts.pop();
    return parts.join('');
  }

  const query = (text) => clip(String(text || '').replace(/[\u0000-\u001f\u007f<>]/g, '').trim(), 48);

  function stepDecimals(step) {
    const text = String(step);
    const dot = text.indexOf('.');
    return dot === -1 ? 0 : Math.min(3, text.length - dot - 1);
  }

  function number(value, decimals = 0) {
    if (!Number.isFinite(value)) return '—';
    return new Intl.NumberFormat('fr-FR', { minimumFractionDigits: decimals, maximumFractionDigits: decimals }).format(value);
  }

  function snap(field, value) {
    const min = Number(field.min), max = Number(field.max), step = Number(field.step) > 0 ? Number(field.step) : 1;
    let v = Number(value);
    if (!Number.isFinite(v)) v = min;
    v = Math.min(max, Math.max(min, v));
    v = min + Math.round((v - min) / step) * step;
    v = Number(v.toFixed(9));
    if (field.integer === true) v = Math.round(v);
    return Math.min(max, Math.max(min, v));
  }

  function measure(field, value) {
    const decimals = Number.isInteger(field.decimals) ? field.decimals : stepDecimals(field.step);
    const prefix = str(field.prefix) ? `${field.prefix}${NBSP}` : '';
    const unit = str(field.unit);
    const suffix = unit === '' ? '' : (unit === '°' ? unit : `${NBSP}${unit}`);
    return `${prefix}${number(value, decimals)}${suffix}`;
  }

  function duration(seconds) {
    let rest = Math.max(0, Math.round(Number(seconds) || 0));
    const parts = [];
    for (const unit of UNIT_ORDER) {
      const amount = Math.floor(rest / UNIT_SECONDS[unit]);
      if (amount > 0) parts.push([unit, amount]);
      rest -= amount * UNIT_SECONDS[unit];
    }
    if (parts.length === 0) return `0${NBSP}${STRINGS.duration.long.s[0]}`;
    if (parts.length === 1) {
      const [unit, amount] = parts[0];
      const words = STRINGS.duration.long[unit];
      return `${number(amount)}${NBSP}${amount > 1 ? words[1] : words[0]}`;
    }
    return parts.map(([unit, amount]) => `${number(amount)}${NBSP}${STRINGS.duration.short[unit]}`).join(' ');
  }

  function durationUnit(units, seconds) {
    const allowed = UNIT_ORDER.filter((unit) => units.includes(unit));
    if (allowed.length === 0) return 's';
    for (const unit of allowed) {
      if (seconds > 0 && seconds % UNIT_SECONDS[unit] === 0) return unit;
    }
    return allowed[allowed.length - 1];
  }

  function parseAmount(text) {
    const clean = String(text || '').trim().replace(/\s/g, '').replace(',', '.');
    if (!/^\d+(\.\d+)?$/.test(clean)) return NaN;
    return Number(clean);
  }

  const own = (map, key) => Boolean(map) && typeof map === 'object' && !Array.isArray(map) && Object.prototype.hasOwnProperty.call(map, key);
  const TONES = new Set(['count', 'upcoming', 'trial', 'draft']);

  function cardTag(card, tags) {
    if (card.upcoming === true) return { text: STRINGS.upcoming, tone: 'upcoming' };
    const got = own(tags, card.editor) ? tags[card.editor] : null;
    const text = got && typeof got === 'object' ? str(got.text) : '';
    return text ? { text, tone: TONES.has(got.tone) ? got.tone : 'count' } : null;
  }

  function fieldLabels(fields, values, labels) {
    const out = [];
    for (const field of list(fields)) {
      const got = field && own(labels, field.id) ? labels[field.id] : null;
      const value = got ? values[field.id] : '';
      if (typeof value !== 'string' || value === '' || typeof got !== 'object' || !str(got.label)) continue;
      out.push({ field, value, item: { value, label: got.label, image: str(got.image), provisional: got.provisional === true } });
    }
    return out;
  }

  return { UNIT_SECONDS, UNIT_ORDER, list, str, fold, chars, clip, query, stepDecimals, number, snap, measure, duration, durationUnit, parseAmount, cardTag, fieldLabels };
})();
