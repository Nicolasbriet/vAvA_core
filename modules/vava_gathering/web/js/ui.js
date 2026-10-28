'use strict';
/*
 * web/js/ui.js
 * Rôle : outils communs aux vues : création d'éléments (texte brut uniquement, jamais de HTML venu du jeu), boutons,
 *        légendes de touches, bornes.
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

  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));

  return { el, button, hint, clamp };
})();
