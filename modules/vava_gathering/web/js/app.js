'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage : messages du jeu (invite, ligne lancée, barre de tension et appuis, panneau des zones, erreurs
 *        et notifications), messages éphémères, clavier (Échap ferme le panneau des zones, seule vue qui prend le
 *        focus).
 */

const App = (() => {
  const TOAST_MS = 3400;
  const app = document.getElementById('app');
  const refs = { hints: document.getElementById('hints'), toast: app.querySelector('.toast') };
  let toastTimer = null;

  function toast(message, kind) {
    refs.toast.textContent = message;
    refs.toast.dataset.kind = kind || 'info';
    refs.toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { refs.toast.hidden = true; }, TOAST_MS);
  }

  function openZones(payload) {
    ZonesView.show(payload.zones);
    refs.hints.replaceChildren(...STRINGS.zones.hints.map(UI.hint));
    refs.hints.hidden = false;
  }

  function hideZones() {
    ZonesView.hide();
    refs.hints.hidden = true;
  }

  /** Fermeture décidée par le joueur : le jeu rend la main. */
  function closeZones() {
    if (!ZonesView.isOpen()) return;
    hideZones();
    Bridge.post('close');
  }

  Bridge.onMessage((action, payload) => {
    if (action === 'prompt') {
      if (payload.hidden) PromptView.hide(); else PromptView.show(payload);
    } else if (action === 'cast') {
      PromptView.castShow(payload);
    } else if (action === 'tension') {
      TensionView.start(payload);
    } else if (action === 'tensionHold') {
      TensionView.hold(payload.held);
    } else if (action === 'tensionStop') {
      TensionView.hide();
    } else if (action === 'zones') {
      openZones(payload);
    } else if (action === 'zonesClose') {
      hideZones();
    } else if (action === 'error') {
      toast(errorMessage(payload.code), 'warning');
    } else if (action === 'notify') {
      if (typeof payload.message === 'string') toast(payload.message, payload.kind);
    }
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && ZonesView.isOpen()) {
      event.preventDefault();
      closeZones();
    }
  });

  return { toast, closeZones };
})();
