'use strict';
/*
 * web/js/ui.js
 * Rôle : outils communs : textes et réglages reçus de la config, création d'éléments (texte brut uniquement, jamais
 *        de HTML venu du jeu), format « %s / %d » des textes Lua, longueur en signes (un « é » compte pour un).
 */

const UI = (() => {
  let texts = {};
  let settings = {};

  function setup(payload) {
    texts = payload.texts || {};
    settings = payload.settings || {};
  }

  /** Textes de l'interface (texts.ui de la config). */
  function t() {
    return texts;
  }

  function config() {
    return settings;
  }

  /** Remplace %s et %d dans l'ordre, comme string.format côté Lua. */
  function format(template, ...values) {
    let index = 0;
    return String(template || '').replace(/%[ds]/g, () => String(values[index++]));
  }

  /** Comme format, mais chaque valeur est un nœud (ou un texte) : le modèle reste du texte brut. */
  function compose(template, ...values) {
    const nodes = [];
    const parts = String(template || '').split(/%[ds]/);
    parts.forEach((part, index) => {
      if (part) nodes.push(document.createTextNode(part));
      if (index < parts.length - 1) {
        const value = values[index];
        nodes.push(value instanceof Node ? value : document.createTextNode(String(value ?? '')));
      }
    });
    return nodes;
  }

  function el(tag, className, text, children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    if (children) node.append(...children.filter(Boolean));
    return node;
  }

  /** Nombre de signes (points de code). */
  function length(value) {
    return Array.from(value || '').length;
  }

  return { setup, t, config, format, compose, el, length };
})();
