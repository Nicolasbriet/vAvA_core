'use strict';
/*
 * web/js/icons.js
 * Rôle : icônes SVG en ligne (trait 1,6 px, couleur héritée). Aucune ressource externe.
 */

const ICONS = (() => {
  const svg = (paths) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${paths}</svg>`;
  return Object.freeze({
    identity: svg('<circle cx="12" cy="8" r="3.6"/><path d="M4.5 20.5c0-4.1 3.4-6.6 7.5-6.6s7.5 2.5 7.5 6.6"/>'),
    heritage: svg('<circle cx="8" cy="8.5" r="2.8"/><circle cx="16" cy="8.5" r="2.8"/><path d="M2.8 19.5c0-3.1 2.4-5.1 5.2-5.1s5.2 2 5.2 5.1M10.8 19.5c0-3.1 2.4-5.1 5.2-5.1s5.2 2 5.2 5.1"/>'),
    face: svg('<path d="M12 3.2c3.9 0 6.6 3 6.6 7.4 0 5-3.2 10.2-6.6 10.2S5.4 15.6 5.4 10.6c0-4.4 2.7-7.4 6.6-7.4z"/><path d="M9.3 10.4h.01M14.7 10.4h.01M10 15.4c1.2.8 2.8.8 4 0"/>'),
    hair: svg('<circle cx="6.5" cy="17.5" r="2.6"/><circle cx="17.5" cy="17.5" r="2.6"/><path d="M8.4 15.6 18.5 4M15.6 15.6 5.5 4"/>'),
    skin: svg('<path d="M12 3.3c3.6 4.4 6 7.7 6 10.9a6 6 0 0 1-12 0c0-3.2 2.4-6.5 6-10.9z"/><path d="M9.2 14.6a2.9 2.9 0 0 0 2.4 2.6"/>'),
    makeup: svg('<path d="M14.6 3.8 20.2 9.4 11.8 17.8H6.2v-5.6z"/><path d="M6.2 17.8 3.4 20.6M10 10.6l3.4 3.4"/>'),
    outfit: svg('<path d="M8.4 3.4 4 6.4l2 4.2 2.1-1v11h7.8v-11l2.1 1 2-4.2-4.4-3c-.6 1.8-2 3-3.6 3s-3-1.2-3.6-3z"/>'),
    random: svg('<rect x="4" y="4" width="16" height="16" rx="2.6"/><path d="M8.8 8.8h.01M15.2 15.2h.01M15.2 8.8h.01M8.8 15.2h.01M12 12h.01"/>'),
    reset: svg('<path d="M4.6 10.2a7.6 7.6 0 1 1 1.9 6.9"/><path d="M4.4 4.6v5.8h5.8"/>'),
    trash: svg('<path d="M4.5 7h15M10 11v6M14 11v6M6.4 7l.9 13h9.4l.9-13M9.4 7V4.2h5.2V7"/>'),
    plus: svg('<path d="M12 5v14M5 12h14"/>'),
    close: svg('<path d="M6 6l12 12M18 6 6 18"/>'),
    left: svg('<path d="M14.5 6 8.5 12l6 6"/>'),
    right: svg('<path d="M9.5 6l6 6-6 6"/>'),
    rotate: svg('<path d="M4 12a8 8 0 0 1 13.7-5.6L20 8.6"/><path d="M20 4v4.6h-4.6"/><path d="M20 12a8 8 0 0 1-13.7 5.6L4 15.4"/><path d="M4 20v-4.6h4.6"/>'),
    check: svg('<path d="M5 12.5 10 17.5 19 7"/>'),
  });
})();
