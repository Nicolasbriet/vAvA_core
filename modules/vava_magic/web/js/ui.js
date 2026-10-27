'use strict';
/*
 * web/js/ui.js
 * Rôle : outils communs aux vues : textes reçus de la config, création d'éléments (texte brut uniquement, jamais de
 *        HTML venu du jeu), format « %d / %s » des textes Lua, longueur en signes (un « é » compte pour un).
 */

const UI = (() => {
  let texts = {};

  function setTexts(value) {
    texts = value || {};
  }

  /** Textes d'une vue (texts.ui.<section> de la config). */
  function t(section) {
    return texts[section] || {};
  }

  /** Remplace %d, %s, %02d… dans l'ordre, comme string.format côté Lua. */
  function format(template, ...values) {
    let index = 0;
    return String(template || '').replace(/%0?\d*[ds]/g, (token) => {
      const value = values[index++];
      if (token === '%s' || token === '%d') return String(value);
      const width = Number(token.slice(2, -1)) || 0;
      return String(value).padStart(width, '0');
    });
  }

  function el(tag, className, text, children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    if (children) node.append(...children.filter(Boolean));
    return node;
  }

  /** Ajoute des enfants à un nœud, en ignorant ceux qui sont absents (élément facultatif). */
  function append(node, ...children) {
    node.append(...children.filter(Boolean));
    return node;
  }

  function button(label, className, onClick) {
    const node = el('button', className, label);
    node.type = 'button';
    node.addEventListener('click', onClick);
    return node;
  }

  /** Nombre de signes (points de code). */
  function length(value) {
    return Array.from(value || '').length;
  }

  /** Garde les `max` premiers signes. */
  function truncate(value, max) {
    const chars = Array.from(value || '');
    return chars.length > max ? chars.slice(0, max).join('') : value;
  }

  /** Lettrine enluminée suivie du reste du titre. */
  function title(text, className) {
    const value = String(text || '');
    const chars = Array.from(value);
    return el('h2', className || 'sheet-title', null, [el('span', 'lettrine', chars[0] || ''), document.createTextNode(chars.slice(1).join(''))]);
  }

  const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
  function roman(value) {
    return ROMAN[value - 1] || String(value);
  }

  return { setTexts, t, format, el, append, button, length, truncate, title, roman };
})();
