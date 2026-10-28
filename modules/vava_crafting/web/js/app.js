'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage : messages du jeu (invite, menu de station et sa mise à jour, résultat d'une pièce ou d'une
 *        réparation, boîte de baptême, erreurs et notifications), messages éphémères, clavier (Échap ferme la boîte de
 *        baptême puis le menu, seules vues qui prennent le focus).
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

  /** Résultat d'une pièce ou d'une réparation : message, puis boîte de baptême pour un chef-d'œuvre. */
  function crafted(payload) {
    const C = STRINGS.crafted;
    const menu = MenuView.current();
    const labels = menu && menu.rules && UI.list(menu.rules.tierLabels).length ? UI.list(menu.rules.tierLabels) : STRINGS.tiers;
    const tierLabel = labels[UI.clamp(Math.round(Number(payload.tier) || 1), 1, 5) - 1] || '';
    if (payload.kind === 'repair') toast(C.repaired(payload.label || ''), 'info');
    else if (payload.signed) toast(C.signed(payload.label || '', tierLabel, Math.round(Number(payload.quality) || 0)), 'info');
    else toast(C.simple(payload.label || '', Number(payload.quantity) || 1, tierLabel), 'info');
    if (payload.nameable && payload.instanceId) NamingView.show(payload);
  }

  Bridge.onMessage((action, payload) => {
    if (action === 'prompt') {
      if (payload.hidden) PromptView.hide(); else PromptView.show(payload);
    } else if (action === 'menu') {
      openMenu(payload);
    } else if (action === 'menuClose') {
      hideMenu();
    } else if (action === 'station') {
      MenuView.updateStation(payload);
    } else if (action === 'crafted') {
      crafted(payload);
    } else if (action === 'namingClose') {
      NamingView.hide();
    } else if (action === 'error') {
      toast(errorMessage(payload.code), 'warning');
    } else if (action === 'notify') {
      if (typeof payload.message === 'string') toast(payload.message, payload.kind);
    }
  });

  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    if (NamingView.isOpen()) {
      event.preventDefault();
      NamingView.later();
    } else if (MenuView.isOpen()) {
      event.preventDefault();
      closeMenu();
    }
  });

  return { toast, closeMenu };
})();
