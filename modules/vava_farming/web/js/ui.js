'use strict';
/*
 * web/js/ui.js
 * Rôle : outils communs aux vues : création d'éléments (texte brut uniquement, jamais de HTML venu du jeu), boutons,
 *        légendes de touches, listes (msgpack transmet une liste vide comme un objet vide), pastille de palier, jauge
 *        à seuil, bornes.
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

  /** Jauge 0–1 avec libellé, valeur, teinte (`kind`) et seuil optionnel (part 0–1) marqué d'un trait. */
  function gauge(label, ratio, valueText, kind, threshold) {
    const fill = el('span', `gauge-fill is-${kind || 'neutral'}`);
    fill.style.transform = `scaleX(${clamp(Number(ratio) || 0, 0, 1).toFixed(3)})`;
    const track = el('span', 'gauge-track', null, [fill]);
    if (typeof threshold === 'number') {
      const mark = el('span', 'gauge-threshold');
      mark.style.left = `${(clamp(threshold, 0, 1) * 100).toFixed(1)}%`;
      track.append(mark);
    }
    return el('div', 'gauge', null, [el('span', 'gauge-label', label), track, el('span', 'gauge-value', valueText)]);
  }

  return { el, button, hint, list, clamp, tier, gauge };
})();
