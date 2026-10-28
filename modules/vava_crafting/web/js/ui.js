'use strict';
/*
 * web/js/ui.js
 * Rôle : outils communs aux vues : création d'éléments (texte brut uniquement, jamais de HTML venu du jeu), boutons,
 *        légendes de touches, listes (msgpack transmet une liste vide comme un objet vide), pastille de palier, bornes.
 */

const UI = (() => {
  function el(tag, className, text, children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    if (children) node.append(...children.filter(Boolean));
    return node;
  }

  function button(label, className, onClick) {
    const node = el('button', className, label);
    node.type = 'button';
    if (onClick) node.addEventListener('click', onClick);
    return node;
  }

  /** Touche et action : « [Échap] fermer ». */
  function hint([key, label]) {
    const node = el('span', 'hint');
    node.append(el('kbd', null, key), label);
    return node;
  }

  /** Toujours une vraie liste (une table Lua vide arrive parfois en objet vide). */
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));

  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));

  /** Pastille d'un palier (teinte par palier, comme l'inventaire). */
  function tier(value, labels, className) {
    const index = clamp(Math.round(Number(value) || 1), 1, 5);
    const node = el('span', `tier${className ? ` ${className}` : ''}`, labels[index - 1] || String(index));
    node.dataset.tier = String(index);
    return node;
  }

  return { el, button, hint, list, clamp, tier };
})();
