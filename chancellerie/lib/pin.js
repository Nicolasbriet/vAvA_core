'use strict';
/*
 * lib/pin.js
 * Rôle : code d'accès du premier lancement, comme celui de txAdmin : tant qu'aucun compte n'existe, la création
 *        du compte maître demande ce code, affiché dans la console de la Chancellerie (seule la personne qui a
 *        lancé le programme le voit). Un nouveau code est tiré après quelques erreurs.
 */

const crypto = require('crypto');

const DIGITS = 6;
const MAX_FAILURES = 5;

let current = null;
let failures = 0;
let announce = () => {};

function generate() {
  current = String(crypto.randomInt(0, 10 ** DIGITS)).padStart(DIGITS, '0');
  failures = 0;
  announce(current);
  return current;
}

module.exports = {
  DIGITS,
  generate,

  /** Fonction appelée à chaque nouveau code (affichage dans la console). */
  onChange(callback) {
    announce = callback;
  },

  active: () => current !== null,

  /** Vrai si le code est le bon ; espaces et tirets saisis sont ignorés. */
  check(value) {
    if (!current) return false;
    const given = Buffer.from(String(value || '').replace(/[\s-]/g, '').slice(0, DIGITS * 2));
    const expected = Buffer.from(current);
    const ok = given.length === expected.length && crypto.timingSafeEqual(given, expected);
    if (!ok) {
      failures += 1;
      if (failures >= MAX_FAILURES) generate();
    }
    return ok;
  },

  /** Le compte maître existe : plus aucun code n'ouvre quoi que ce soit. */
  clear() {
    current = null;
    failures = 0;
  },

  /** « 123 456 » */
  format: (pin) => `${pin.slice(0, DIGITS / 2)} ${pin.slice(DIGITS / 2)}`,
};
