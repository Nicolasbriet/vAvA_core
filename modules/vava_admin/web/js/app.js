'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage du Registre : ouverture accordée par le jeu, signets (onglets) selon les droits, pages simples ou
 *        doubles, pagination, Échap (dialogue d'abord, puis fermeture), proclamation et bandeau d'observation vus
 *        hors du registre.
 */

(() => {
  const VIEWS = [PlayersView, ReportsView, BansView, LogsView, StaffView, ToolsView, AnnounceView];
  const app = document.getElementById('app');
  const ribbons = app.querySelector('.ribbons');
  const pages = app.querySelector('.pages');
  const left = app.querySelector('.page-left');
  const right = app.querySelector('.page-right');
  const proclamation = document.querySelector('.proclamation');
  const watch = document.querySelector('.watch');
  let proclamationTimer = null;
  let current = null;
  let ctx = null;

  app.querySelector('.book-title').textContent = STRINGS.title;
  const closeButton = app.querySelector('.book-close');
  closeButton.setAttribute('aria-label', STRINGS.close);
  closeButton.title = STRINGS.close;
  closeButton.addEventListener('click', () => close());
  UI.init(app);

  function pager(page, count, go) {
    const size = ctx.session.pageSize;
    return UI.el('nav', 'pager', null, [
      page > 0 ? UI.button(STRINGS.pages.previous, () => go(page - 1), 'plain') : UI.el('span'),
      UI.el('span', 'pager-page', STRINGS.pages.page(page + 1)),
      count >= size ? UI.button(STRINGS.pages.next, () => go(page + 1), 'plain') : UI.el('span'),
    ]);
  }

  async function goTo(id, options) {
    const view = VIEWS.find((v) => v.id === id && ctx.can(v.permission));
    if (!view) return;
    current = view;
    for (const ribbon of ribbons.children) ribbon.classList.toggle('is-active', ribbon.dataset.tab === id);
    pages.classList.toggle('is-single', Boolean(view.single));
    left.replaceChildren();
    right.replaceChildren();
    await view.show(ctx, options);
  }

  function buildRibbons() {
    const shown = VIEWS.filter((view) => ctx.can(view.permission));
    ribbons.replaceChildren(...shown.map((view, index) => {
      const ribbon = UI.el('button', `ribbon ribbon-${index % 4}`, STRINGS.tabs[view.id]);
      ribbon.type = 'button';
      ribbon.dataset.tab = view.id;
      ribbon.setAttribute('role', 'tab');
      ribbon.addEventListener('click', () => goTo(view.id));
      return ribbon;
    }));
    return shown;
  }

  function open(session) {
    const permissions = new Set(Array.isArray(session.permissions) ? session.permissions : Object.values(session.permissions || {}));
    ctx = {
      session, tools: session.tools || {}, left, right, single: left, pager, goTo,
      can: (permission) => permissions.has(permission),
    };
    app.querySelector('.seal-label').textContent = session.rank.label;
    const shown = buildRibbons();
    app.hidden = false;
    if (shown.length) goTo(current && shown.includes(current) ? current.id : shown[0].id);
  }

  function close() {
    UI.cancelDialog();
    app.hidden = true;
    Bridge.post('close');
  }

  function proclaim({ text, author, durationMs }) {
    proclamation.querySelector('.proclamation-title').textContent = STRINGS.announce.title;
    proclamation.querySelector('.proclamation-text').textContent = text;
    proclamation.querySelector('.proclamation-author').textContent = author || '';
    proclamation.hidden = false;
    proclamation.classList.remove('is-leaving');
    clearTimeout(proclamationTimer);
    proclamationTimer = setTimeout(() => {
      proclamation.classList.add('is-leaving');
      proclamationTimer = setTimeout(() => { proclamation.hidden = true; }, 400);
    }, durationMs || 9000);
  }

  Bridge.onMessage((action, payload) => {
    if (action === 'open') open(payload);
    else if (action === 'close') {
      UI.cancelDialog();
      app.hidden = true;
    } else if (action === 'announce') proclaim(payload);
    else if (action === 'spectate') {
      watch.hidden = !payload.active;
      if (payload.active) {
        watch.querySelector('.watch-label').textContent = STRINGS.watch(payload.label);
        watch.querySelector('.watch-key').textContent = payload.key || 'F10';
        if (ctx) ctx.tools.spectating = payload.label;
      } else if (ctx) ctx.tools.spectating = null;
    } else if (action === 'reportsChanged' && current === ReportsView && !app.hidden) goTo('reports');
  });

  // le registre a le focus : la touche d'ouverture du jeu ne lui parvient plus, Échap et F10 le ferment ici
  document.addEventListener('keydown', (event) => {
    if (app.hidden || (event.key !== 'Escape' && event.key !== 'F10')) return;
    event.preventDefault();
    if (event.key === 'Escape' && UI.isDialogOpen()) UI.cancelDialog();
    else close();
  });

  if (Bridge.inGame) Bridge.post('ready');
})();
