/*
 * vava_loading/web/js/text.js
 * Rôle : logique pure des textes : découpe d'un conseil en morceaux de texte et touches ([[F1]] → cartouche, construit
 *        ensuite par le DOM, jamais par du HTML), remplacement des {champs}, ordre de rotation des extraits et des
 *        conseils (mélangé, sans répétition, jamais deux fois le même de suite d'un tour à l'autre).
 *        Aucun accès au DOM : essayé par web/dev/essais.js (navigateur et node).
 * Dépendances : aucune
 */
(function (root) {
  'use strict';

  var VavaLoading = root.VavaLoading = root.VavaLoading || {};

  var MAX_KEYS = 3;       // touches par conseil
  var MAX_KEY_BYTES = 12; // octets d'une touche (UTF-8)

  /** Longueur UTF-8 d'une chaîne, en octets. */
  function utf8Length(str) {
    var bytes = 0;
    for (var i = 0; i < str.length; i++) {
      var code = str.charCodeAt(i);
      if (code < 0x80) bytes += 1;
      else if (code < 0x800) bytes += 2;
      else if (code >= 0xd800 && code <= 0xdbff) { bytes += 4; i++; } // paire de substitution : un seul point de code
      else bytes += 3;
    }
    return bytes;
  }

  /** Ajoute du texte à la liste, collé au morceau de texte précédent s'il y en a un. */
  function pushText(parts, text) {
    if (text === '') return;
    var last = parts[parts.length - 1];
    if (last && last.text !== undefined) last.text += text;
    else parts.push({ text: text });
  }

  /**
   * Découpe `str` en morceaux { text } et { key }. Une touche est `[[X]]` avec X de 1 à 12 octets, sans crochet ; au
   * plus 3 par texte. Tout le reste (crochets non fermés, 4e touche, touche trop longue ou vide) reste du texte brut.
   * @param {string} str
   * @return {Array<{text: string}|{key: string}>}
   */
  function splitKeys(str) {
    var parts = [];
    if (typeof str !== 'string') return parts;
    var keys = 0, from = 0;
    while (from < str.length) {
      var open = str.indexOf('[[', from);
      if (open < 0) break;
      var close = str.indexOf(']]', open + 2);
      if (close < 0) break;
      var key = str.slice(open + 2, close);
      var valid = keys < MAX_KEYS && key.length > 0 && utf8Length(key) <= MAX_KEY_BYTES && !/[[\]]/.test(key);
      pushText(parts, str.slice(from, open));
      if (valid) { parts.push({ key: key }); keys++; }
      else pushText(parts, str.slice(open, close + 2));
      from = close + 2;
    }
    pushText(parts, str.slice(from));
    return parts;
  }

  /**
   * Remplace chaque `{nom}` de `template` par `values[nom]` (champ absent : laissé tel quel).
   * @param {string} template
   * @param {Object<string, string|number>} values
   * @return {string}
   */
  function format(template, values) {
    return String(template).replace(/\{([a-z]+)\}/gi, function (all, name) {
      return Object.prototype.hasOwnProperty.call(values || {}, name) ? String(values[name]) : all;
    });
  }

  /**
   * Permutation de 0..n-1 (mélange de Fisher-Yates), dont le premier élément n'est pas `avoid` quand n > 1.
   * @param {number} n
   * @param {number|null} avoid  dernier élément du tour précédent (ou null)
   * @param {function(): number} [random]  tirage dans [0, 1) (Math.random par défaut)
   * @return {number[]}
   */
  function order(n, avoid, random) {
    random = random || Math.random;
    var list = [];
    for (var i = 0; i < n; i++) list.push(i);
    for (var j = n - 1; j > 0; j--) {
      var k = Math.floor(random() * (j + 1));
      if (k > j) k = j;
      var tmp = list[j]; list[j] = list[k]; list[k] = tmp;
    }
    if (n > 1 && list[0] === avoid) {
      var swap = 1 + Math.floor(random() * (n - 1));
      if (swap > n - 1) swap = n - 1;
      list[0] = list[swap]; list[swap] = avoid;
    }
    return list;
  }

  /**
   * Suite infinie d'indices de 0..n-1 : chaque tour est une permutation complète, et le premier d'un tour n'est jamais
   * le dernier du précédent. n = 0 → toujours -1 ; n = 1 → toujours 0.
   * @param {number} n
   * @param {function(): number} [random]
   * @return {function(): number}  rend l'indice suivant
   */
  function cycle(n, random) {
    var round = [], pos = 0, last = null;
    return function next() {
      if (n <= 0) return -1;
      if (pos >= round.length) { round = order(n, last, random); pos = 0; }
      last = round[pos++];
      return last;
    };
  }

  VavaLoading.text = { splitKeys: splitKeys, format: format, order: order, cycle: cycle, utf8Length: utf8Length };

  if (typeof module === 'object' && module.exports) module.exports = VavaLoading.text;
})(typeof window !== 'undefined' ? window : globalThis);
