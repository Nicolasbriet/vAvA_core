'use strict';
/*
 * web/js/murmurs.js
 * Rôle : murmures reçus, sans prendre la main du joueur : parchemin qui se déroule (nom du contact) ou lettres
 *        lumineuses (présence inconnue), effacé après le temps de lecture. Trois au plus à l'écran.
 */

const Murmurs = (() => {
  const root = document.getElementById('murmurs');
  const MAX_SHOWN = 3;
  const LEAVE_MS = 600;

  function show({ from, text, waypoint, ms }) {
    const texts = UI.t('murmur');
    const unknown = typeof from !== 'string' || from === '';
    const card = UI.el('article', `scroll${unknown ? ' is-unknown' : ''}`, null, [
      UI.el('header', 'scroll-from', unknown ? texts.unknown : UI.format(texts.from, from)),
      UI.el('p', 'scroll-text', text || ''),
      waypoint ? UI.el('footer', 'scroll-waypoint', texts.waypoint) : null,
    ]);
    root.prepend(card);
    while (root.children.length > MAX_SHOWN) root.lastElementChild.remove();
    setTimeout(() => {
      card.classList.add('is-leaving');
      setTimeout(() => card.remove(), LEAVE_MS);
    }, Math.max(1000, Number(ms) || 0));
  }

  return { show };
})();
