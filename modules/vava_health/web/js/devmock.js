'use strict';
/*
 * web/js/devmock.js
 * Rôle : états simulés quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans
 *        lancer le jeu. Inactif en jeu. Paramètre d'URL : ?state=downed | ready | patient | holding | assist.
 */

(() => {
  if (typeof GetParentResourceName === 'function') return;
  window.addEventListener('DOMContentLoaded', () => {
    document.body.classList.add('dev');
    const state = new URLSearchParams(window.location.search).get('state') || 'downed';
    const post = (action, payload) => window.postMessage({ action, payload }, '*');
    post('init', { giveUpKey: 'E' });
    if (state === 'assist') {
      post('channel', { role: 'helper', state: 'start', durationMs: 8000 });
      return;
    }
    const ready = state === 'ready' || state === 'holding';
    post('downed', { giveUpInMs: ready ? 0 : 161000, autoInMs: ready ? 418000 : 581000 });
    if (state === 'patient') post('channel', { role: 'patient', state: 'start', durationMs: 8000 });
    if (state === 'holding') post('hold', { active: true, durationMs: 3000 });
  });
})();
