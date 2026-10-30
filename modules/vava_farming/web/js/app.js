'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage : messages du jeu (invite, menu d'emplacement et sa mise à jour, résultat d'un geste, seau rempli,
 *        erreurs et notifications), messages éphémères, clavier (Échap ferme le menu, seule vue qui prend le focus).
 */

const App = (() => {
  const TOAST_MS = 3600;
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

  function openMenu(payload) {
    MenuView.show(payload);
    refs.hints.replaceChildren(...STRINGS.hints.map(UI.hint));
    refs.hints.hidden = false;
  }

  function hideMenu() {
    MenuView.hide();
    refs.hints.hidden = true;
  }

  /** Fermeture décidée par le joueur : le jeu rend la main. */
  function closeMenu() {
    if (!MenuView.isOpen()) return;
    hideMenu();
    Bridge.post('close');
  }

  /** Résultat d'un geste : { action, slot, item, label, quantity, tier, seeds }. */
  function result(payload) {
    const R = STRINGS.result;
    const menu = MenuView.current();
    const labels = menu && menu.rules && UI.list(menu.rules.tierLabels).length ? UI.list(menu.rules.tierLabels) : STRINGS.tiers;
    const action = payload.action;
    if (action === 'plant') toast(R.plant(payload.label || (payload.slot && payload.slot.cropLabel) || ''), 'info');
    else if (action === 'water') toast(R.water, 'info');
    else if (action === 'fertilize') toast(R.fertilize, 'info');
    else if (action === 'harvest') {
      const tierLabel = labels[UI.clamp(Math.round(Number(payload.tier) || 1), 1, 5) - 1] || '';
      let text = R.harvest(Number(payload.quantity) || 1, payload.label || payload.item || '', tierLabel);
      if (Number(payload.seeds) > 0) text += R.seeds(Number(payload.seeds));
      toast(text, 'info');
    } else if (action === 'clear') {
      if (payload.item && Number(payload.quantity) > 0) toast(R.clearWaste(Number(payload.quantity), payload.label || payload.item), 'info');
      else toast(R.clear, 'info');
    } else if (action === 'cover') toast(R.cover, 'info');
    if (payload.slot) MenuView.updateSlot(payload.slot);
  }

  Bridge.onMessage((action, payload) => {
    if (action === 'prompt') {
      if (payload.hidden) PromptView.hide(); else PromptView.show(payload);
    } else if (action === 'menu') {
      openMenu(payload);
    } else if (action === 'menuClose') {
      hideMenu();
    } else if (action === 'slot') {
      MenuView.updateSlot(payload);
    } else if (action === 'result') {
      result(payload);
    } else if (action === 'filled') {
      toast(STRINGS.result.filled(Number(payload.charges) || 0), 'info');
    } else if (action === 'error') {
      toast(errorMessage(payload.code), 'warning');
    } else if (action === 'notify') {
      if (typeof payload.message === 'string') toast(payload.message, payload.kind);
    }
  });

  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    if (MenuView.isOpen()) {
      event.preventDefault();
      closeMenu();
    }
  });

  return { toast, closeMenu };
})();
