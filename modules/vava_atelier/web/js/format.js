'use strict';
/*
 * vava_atelier/web/js/format.js
 * Rôle : fonctions pures d'affichage et de mise en forme : nombres à la française (virgule décimale), valeurs d'un
 *        curseur (« 24 m », « × 1,0 », « 70° »), durées (« 10 minutes », « 1 h 30 min », « 7 jours »), listes reçues
 *        du Lua (une liste vide arrive en objet), textes repliés pour la recherche, textes bornés en octets UTF-8 pour
 *        les schémas du serveur. Rien n'y touche au DOM.
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

  /** Texte replié pour la recherche : sans accents ni majuscules. */
  const fold = (text) => String(text || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

  /** Longueur en caractères (« é » = 1), comme le serveur la compte. */
  const chars = (text) => Array.from(String(text || '')).length;

  /** Coupe un texte à `max` octets UTF-8 sans couper un caractère (bornes `max` des schémas du serveur). */
  function clip(text, max) {
    let out = String(text || '');
    if (encoder.encode(out).length <= max) return out;
    const parts = Array.from(out);
    while (parts.length > 0 && encoder.encode(parts.join('')).length > max) parts.pop();
    return parts.join('');
  }

  /** Texte de recherche permis par le serveur (`^[^%c<>]*$`, 48 octets). */
  const query = (text) => clip(String(text || '').replace(/[\u0000-\u001f\u007f<>]/g, '').trim(), 48);

  /** Décimales d'un pas (0,1 → 1 ; 0,25 → 2). */
  function stepDecimals(step) {
    const text = String(step);
    const dot = text.indexOf('.');
    return dot === -1 ? 0 : Math.min(3, text.length - dot - 1);
  }

  /** Nombre à la française : virgule décimale, espace fine des milliers. */
  function number(value, decimals = 0) {
    if (!Number.isFinite(value)) return '—';
    return new Intl.NumberFormat('fr-FR', { minimumFractionDigits: decimals, maximumFractionDigits: decimals }).format(value);
  }

  /** Valeur ramenée sur un pas d'un curseur, dans ses bornes. */
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

  /** « 24 m », « 0,6 s », « × 1,0 », « 70° », « 50 % ». */
  function measure(field, value) {
    const decimals = Number.isInteger(field.decimals) ? field.decimals : stepDecimals(field.step);
    const prefix = str(field.prefix) ? `${field.prefix}${NBSP}` : '';
    const unit = str(field.unit);
    const suffix = unit === '' ? '' : (unit === '°' ? unit : `${NBSP}${unit}`);
    return `${prefix}${number(value, decimals)}${suffix}`;
  }

  /** Durée lue : un seul ordre de grandeur en toutes lettres, sinon abrégée (« 1 h 30 min »). */
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

  /** Unité de départ d'un champ de durée : la plus grande permise qui tombe juste, sinon la plus petite permise. */
  function durationUnit(units, seconds) {
    const allowed = UNIT_ORDER.filter((unit) => units.includes(unit));
    if (allowed.length === 0) return 's';
    for (const unit of allowed) {
      if (seconds > 0 && seconds % UNIT_SECONDS[unit] === 0) return unit;
    }
    return allowed[allowed.length - 1];
  }

  /** Nombre tapé à la française (« 1,5 ») ; NaN si ce n'en est pas un. */
  function parseAmount(text) {
    const clean = String(text || '').trim().replace(/\s/g, '').replace(',', '.');
    if (!/^\d+(\.\d+)?$/.test(clean)) return NaN;
    return Number(clean);
  }

  return { UNIT_SECONDS, UNIT_ORDER, list, str, fold, chars, clip, query, stepDecimals, number, snap, measure, duration, durationUnit, parseAmount };
})();
