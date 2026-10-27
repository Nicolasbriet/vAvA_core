'use strict';
/*
 * web/js/modal.js
 * Rôle : fenêtres qui prennent la main du joueur (une à la fois) : ouverture d'une vue avec ses données, fermeture
 *        par le jeu, par Échap ou par un bouton (le jeu est alors prévenu et rend la main).
 */

const Modal = (() => {
  const veil = document.getElementById('veil');
  const views = {};
  let current = null;
  // nettoyage rendu par la vue ouverte (compte à rebours…), appelé à sa fermeture
  let cleanup = null;

  /** Déclare une vue : `render(root, payload)` remplit sa section et peut rendre une fonction de nettoyage. */
  function register(name, render) {
    views[name] = { root: document.getElementById(`view-${name}`), render };
  }

  function hideAll() {
    if (cleanup) {
      const done = cleanup;
      cleanup = null;
      done();
    }
    for (const view of Object.values(views)) {
      view.root.hidden = true;
      view.root.replaceChildren();
    }
  }

  function open(name, payload) {
    const view = views[name];
    if (!view) return;
    hideAll();
    current = name;
    const result = view.render(view.root, payload || {});
    cleanup = typeof result === 'function' ? result : null;
    view.root.hidden = false;
    veil.hidden = false;
    const focus = view.root.querySelector('[data-autofocus]');
    if (focus) focus.focus();
  }

  /** Fermeture décidée par le jeu. */
  function close() {
    current = null;
    hideAll();
    veil.hidden = true;
  }

  /** Fermeture décidée par le joueur (Échap, bouton Fermer) : le jeu rend la main. */
  function dismiss() {
    if (!current) return;
    close();
    Bridge.post('close');
  }

  function name() {
    return current;
  }

  window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && current) {
      event.preventDefault();
      dismiss();
    }
  });

  return { register, open, close, dismiss, name };
})();
