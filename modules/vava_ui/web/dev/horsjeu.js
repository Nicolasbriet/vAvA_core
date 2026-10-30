'use strict';
/*
 * vava_ui/web/dev/horsjeu.js
 * Rôle : hors jeu seulement (page ouverte dans un navigateur depuis le dépôt) : la feuille commune et les textures de
 *        vava_ui sont prises dans le dépôt au lieu de nui://vava_ui/, que le navigateur ne connaît pas. Jamais livré
 *        (absent des `files` de vava_ui), jamais chargé en jeu. Chargé par la ligne hors jeu des pages :
 *        <script>typeof GetParentResourceName === 'function' || document.write('…horsjeu.js…dev/devmock.js…');</script>
 *        Polices : leurs adresses sont relatives à vava_ui.css, lue désormais depuis le dépôt.
 */

(() => {
  if (typeof GetParentResourceName === 'function') return;
  const PREFIX = 'nui://vava_ui/';
  const ROOT = new URL('../../', document.currentScript.src).href; // …/modules/vava_ui/
  document.querySelectorAll(`link[rel="stylesheet"][href^="${PREFIX}"]`).forEach((link) => {
    link.href = ROOT + link.getAttribute('href').slice(PREFIX.length);
  });
  // mêmes jetons que web/css/vava_ui.css (tenus ensemble : tests/spec/ui_shared_spec.lua le vérifie)
  const TEXTURES = {
    '--ui-grain': 'web/img/grain.webp',
    '--ui-paper': 'web/img/paper.webp',
    '--ui-frame': 'web/img/frame.svg',
    '--ui-divider': 'web/img/divider.svg',
    '--ui-diamond': 'web/img/diamond.svg',
  };
  for (const [name, file] of Object.entries(TEXTURES)) {
    document.documentElement.style.setProperty(name, `url("${ROOT}${file}")`);
  }
})();
