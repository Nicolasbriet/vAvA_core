'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage : ouverture et fermeture du livre, onglets, rendu de l'onglet courant (une vue redessine sa page
 *        entière : les changements sont rares), messages du jeu (fiche, compétence modifiée, proposition, mentorat,
 *        savoir, leçon, notification), relecture de la fiche quand le serveur annonce un changement, messages
 *        éphémères, clavier (Échap et la touche du livre ferment).
 */

const App = (() => {
  const TOAST_MS = 3600;
  const app = document.getElementById('app');
  const refs = {
    title: app.querySelector('.book-title'),
    tabs: app.querySelector('.tabs'),
    close: app.querySelector('.book-close'),
    pages: app.querySelector('.pages'),
    hints: app.querySelector('.hints'),
    toast: app.querySelector('.toast'),
  };
  const VIEWS = { competences: SkillsView, mentorat: MentoringView, savoirs: KnowledgeView, penurie: ShortagesView };
  let cleanup = null;
  let toastTimer = null;

  function finish() {
    if (cleanup) {
      const done = cleanup;
      cleanup = null;
      done();
    }
  }

  function renderTabs() {
    refs.tabs.replaceChildren(...STRINGS.tabs.map(([id, label]) => {
      const tab = UI.button(label, `tab${Model.state.tab === id ? ' is-selected' : ''}`, () => show(id));
      tab.setAttribute('role', 'tab');
      tab.setAttribute('aria-selected', String(Model.state.tab === id));
      return tab;
    }));
  }

  /** Redessine l'onglet courant. */
  function render() {
    if (!Model.state.sheet) return;
    finish();
    refs.pages.replaceChildren();
    refs.pages.classList.remove('is-single');
    const view = VIEWS[Model.state.tab] || SkillsView;
    const result = view.render(refs.pages);
    cleanup = typeof result === 'function' ? result : null;
    renderTabs();
  }

  function show(tab) {
    if (!VIEWS[tab]) return;
    Model.state.tab = tab;
    render();
  }

  function toast(message, kind) {
    refs.toast.textContent = message;
    refs.toast.dataset.kind = kind || 'info';
    refs.toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { refs.toast.hidden = true; }, TOAST_MS);
  }

  /** Relit la fiche au serveur (mentorat, savoir ou leçon changés) et redessine. */
  async function refresh() {
    const result = await Bridge.post('refresh', {});
    if (result.ok && result.sheet) {
      Model.load(result.sheet);
      render();
    } else if (!result.ok) {
      toast(errorMessage(result.error), 'warning');
    }
  }

  function open(sheet) {
    Model.load(sheet);
    app.hidden = false;
    render();
  }

  function hide() {
    finish();
    app.hidden = true;
    refs.toast.hidden = true;
    MentoringView.reset();
    Model.state.lineages.clear();
  }

  /** Fermeture décidée par le joueur : le jeu rend la main. */
  function close() {
    if (app.hidden) return;
    hide();
    Bridge.post('close');
  }

  refs.title.textContent = STRINGS.title;
  refs.close.setAttribute('aria-label', STRINGS.close);
  refs.close.title = STRINGS.close;
  refs.close.addEventListener('click', close);
  refs.hints.replaceChildren(...STRINGS.hints.map(UI.hint));

  Bridge.onMessage((action, payload) => {
    if (action === 'open') {
      open(payload);
    } else if (app.hidden) {
      // livre fermé : rien à redessiner ; la fiche est relue à la prochaine ouverture
    } else if (action === 'skill') {
      Model.updateSkill(payload.skill, payload.budget);
      if (Model.state.tab === 'competences' || Model.state.tab === 'mentorat') render();
    } else if (action === 'proposal') {
      Model.addProposal(payload);
      if (Model.state.tab === 'mentorat') render();
    } else if (action === 'mentorship' || action === 'recipe' || action === 'lesson') {
      refresh();
    } else if (action === 'notify') {
      if (typeof payload.message === 'string') toast(payload.message, payload.kind);
    } else if (action === 'close') {
      hide();
    }
  });

  document.addEventListener('keydown', (event) => {
    if (app.hidden) return;
    const typing = event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement;
    if (event.key === 'Escape') {
      event.preventDefault();
      close();
      return;
    }
    if (!typing && event.key.toLowerCase() === String(Model.state.closeKey).toLowerCase()) close();
  });

  return { render, show, toast, refresh };
})();
