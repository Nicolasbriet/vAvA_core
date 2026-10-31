'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage : messages du jeu, recherche, onglets et chapitres, sélection (souris et clavier), signets,
 *        lancement d'une ligne composée, réglage « rester ouvert », fermeture, chapitre demandé à l'ouverture
 *        (export openAt, 1.4.0). Onglet Lecture (1.5.0) : texte d'une page demandé seulement s'il n'est pas gardé à
 *        la même empreinte, liens, pages voisines ; openAt résout une page, un chapitre de lecture, puis un module.
 *        Mode panneau (1.7.0) : `dock` du message open, livre placé dans le rectangle de l'hôte (js/dock.js).
 * Dépendances : strings.js, bridge.js, model.js, reader.js, forms.js, view.js, dock.js
 */

(() => {
  const app = document.getElementById('app');
  // chapitre ou page demandé à l'ouverture (openAt), appliqué une fois le contenu chargé, puis oublié
  let pendingFocus = null;
  // jeton de la dernière page choisie : seule elle s'affiche
  let pageRequest = 0;
  const loader = CodexReader.createLoader({
    post: (id) => Bridge.post('page', { id }),
    wait: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
    wanted: (id) => !app.hidden && Model.state.tab === 'reading' && Model.state.page === id,
  });

  function selectRow(id, focusForm, delayed) {
    const page = Model.pageOfRow(id);
    if (page) {
      selectPage(page.id, delayed);
      return;
    }
    Model.select(id);
    View.renderSelection();
    if (focusForm && !View.focusFirstField()) View.focusSearch(false);
  }

  /** Ouvre une page (ligne rendue visible) : texte gardé, sinon demandé ; `delayed` (↑ ↓, pages voisines) : différé. */
  async function selectPage(id, delayed) {
    const state = Model.state;
    const page = state.pageById.get(id);
    if (!page) return;
    let full = false;
    if (state.tab !== 'reading') {
      Model.setTab('reading');
      full = true;
    }
    const rowId = Model.pageRowId(id);
    if (!Model.row(rowId) && state.query) {
      Model.setQuery('');
      refs.search.value = '';
      full = true;
    }
    if (!Model.row(rowId) && state.readingChapter) {
      Model.setChapter(page.chapter);
      full = true;
    }
    Model.choosePage(id);
    const body = CodexReader.cached(state.pageCache, id, page.hash);
    state.pageBody = body ? { id, hash: page.hash, body } : null;
    state.pageStatus = body ? 'idle' : 'loading';
    if (full) View.render();
    else View.renderSelection();
    if (body) return;

    const token = ++pageRequest;
    const result = await loader.load(id, delayed);
    const current = token === pageRequest && state.page === id;
    if (result && result.skipped) {
      // plus voulue (autre page, livre fermé, autre onglet) : redemandée au retour par ensurePage
      if (current) state.pageStatus = 'idle';
      return;
    }
    const answer = CodexReader.readAnswer(result, id);
    if (answer) CodexReader.store(state.pageCache, id, answer.hash, answer.body);
    if (!current) return;
    state.pageBody = answer ? { id, hash: answer.hash, body: answer.body } : null;
    state.pageStatus = answer ? 'idle' : 'error';
    if (app.hidden) return;
    if (state.tab === 'reading') View.renderDetail();
    if (!answer) View.toast(errorMessage(result && result.ok ? 'client_error' : result && result.error), 'danger');
  }

  // onglet Lecture affiché : une page choisie (la première sinon), son texte là ou redemandé si son empreinte a changé
  function ensurePage() {
    const state = Model.state;
    if (state.tab !== 'reading' || state.pageStatus === 'loading') return;
    if (!state.page || !state.pageById.has(state.page)) {
      const first = Model.visibleOrder()[0] || (state.reading && state.reading.pages[0] ? { page: state.reading.pages[0] } : null);
      if (first) selectPage(first.page.id);
      return;
    }
    const page = state.pageById.get(state.page);
    const shown = state.pageBody;
    if (state.pageStatus === 'error' || !shown || shown.id !== page.id || shown.hash !== page.hash) selectPage(page.id);
  }

  // lien vers une commande : onglet Commandes, filtres vidés, sa ligne choisie (sinon la première de la commande)
  function openCommand(name, action) {
    if (!Model.state.byName.has(name)) return;
    Model.setTab('commands');
    Model.setChapter('');
    Model.setQuery('');
    refs.search.value = '';
    const row = Model.row(Model.rowId(name, action)) || Model.visibleOrder().find((candidate) => candidate.entry.name === name);
    View.render();
    if (row) selectRow(row.id, true);
  }

  /** Lance la ligne composée de la ligne choisie, si elle est complète. */
  async function run() {
    const row = View.currentRow();
    if (!row || !row.entry.runnable) return;
    const composed = View.updateLine();
    if (!composed || composed.missing) return;
    const result = await Bridge.post('run', { name: row.entry.name, action: row.action ? row.action.id || '' : '', line: composed.line, ui: row.entry.ui === true });
    if (!result.ok) {
      View.toast(errorMessage(result.error), 'danger');
      return;
    }
    // la commande vient d'être lancée : en tête des dernières pages, sans attendre le serveur
    const recent = Model.state.prefs.recent.filter((entry) => entry.name !== row.entry.name || (entry.action || '') !== (row.action ? row.action.id || '' : ''));
    recent.unshift({ name: row.entry.name, action: row.action ? row.action.id || undefined : undefined, at: Math.floor(Date.now() / 1000) });
    Model.state.prefs.recent = recent.slice(0, Model.state.recentMax);
    if (result.closed) {
      app.hidden = true;
    } else {
      View.toast(STRINGS.ran(composed.line));
      View.renderIndex();
    }
  }

  async function toggleFavorite(name, on) {
    const result = await Bridge.post('favorite', { name, on });
    if (!result.ok) {
      View.toast(errorMessage(result.error), 'danger');
      return;
    }
    Model.state.prefs.favorites = Model.list(result.favorites);
    View.renderRibbons();
    View.renderIndex();
    View.renderDetail();
  }

  async function setKeepOpen(value) {
    const result = await Bridge.post('keepOpen', { value });
    if (!result.ok) {
      View.toast(errorMessage(result.error), 'danger');
      View.renderSettings();
      return;
    }
    Model.state.prefs.keepOpen = result.keepOpen !== false;
  }

  function close() {
    pendingFocus = null;
    app.hidden = true;
    Bridge.post('close');
  }

  /** Déplace la sélection dans l'ordre visuel de l'index. */
  function move(delta) {
    const order = Model.visibleOrder();
    if (order.length === 0) return;
    const index = order.findIndex((row) => row.id === Model.state.selected);
    const next = index === -1 ? (delta > 0 ? 0 : order.length - 1) : Math.min(order.length - 1, Math.max(0, index + delta));
    selectRow(order[next].id, false, true);
  }

  View.init(app);
  const refs = View.refs();

  refs.search.addEventListener('input', () => {
    Model.setQuery(refs.search.value);
    View.renderIndex();
    // onglet Lecture : la recherche filtre le sommaire, la page lue reste à l'écran
    if (Model.state.tab === 'reading') return;
    // première ligne des résultats choisie d'office : Entrée la lance ou ouvre son formulaire
    const order = Model.visibleOrder();
    if (Model.state.query.trim() && order.length > 0 && !order.some((row) => row.id === Model.state.selected)) {
      Model.select(order[0].id);
      View.renderSelection();
    } else {
      View.renderDetail();
    }
  });

  app.addEventListener('click', (event) => {
    const tab = event.target.closest('.tab');
    if (tab) {
      Model.setTab(tab.dataset.tab);
      View.render();
      View.focusSearch(true);
      ensurePage();
      return;
    }
    const chapter = event.target.closest('.chapter');
    if (chapter) {
      Model.setChapter(chapter.dataset.chapter);
      View.render();
      // onglet Lecture : un chapitre de la tranche ouvre sa première page (« Tout » garde la page lue)
      if (Model.state.tab === 'reading') {
        const first = chapter.dataset.chapter ? Model.visibleOrder()[0] : null;
        if (first) selectPage(first.page.id);
        else ensurePage();
      }
      return;
    }
    const pageLink = event.target.closest('[data-page]');
    if (pageLink) {
      selectPage(pageLink.dataset.page, pageLink.classList.contains('reader-nav'));
      return;
    }
    const command = event.target.closest('[data-command]');
    if (command) {
      openCommand(command.dataset.command, command.dataset.action || '');
      return;
    }
    const ribbon = event.target.closest('.ribbon');
    if (ribbon) {
      const entry = Model.state.byName.get(ribbon.dataset.name);
      if (!entry) return;
      if (entry.kind === 'key' && Model.state.tab !== 'keys') Model.setTab('keys');
      if (entry.kind !== 'key' && Model.state.tab !== 'commands') Model.setTab('commands');
      Model.setChapter('');
      Model.setQuery('');
      refs.search.value = '';
      const row = Model.visibleOrder().find((candidate) => candidate.entry.name === entry.name);
      View.render();
      if (row) selectRow(row.id, true);
      return;
    }
    const rowNode = event.target.closest('.row');
    if (rowNode) {
      selectRow(rowNode.dataset.row, true);
      return;
    }
    const favorite = event.target.closest('[data-favorite]');
    if (favorite) {
      toggleFavorite(favorite.dataset.favorite, favorite.dataset.on !== '1');
      return;
    }
    if (event.target.closest('[data-run]')) run();
  });

  app.addEventListener('dblclick', (event) => {
    const rowNode = event.target.closest('.row');
    if (rowNode && !Model.pageOfRow(rowNode.dataset.row)) {
      selectRow(rowNode.dataset.row, false);
      run();
    }
  });

  app.addEventListener('change', (event) => {
    if (event.target.dataset && event.target.dataset.setting === 'keepOpen') setKeepOpen(event.target.checked);
  });

  document.addEventListener('keydown', (event) => {
    if (app.hidden) return;
    const target = event.target;
    const inSearch = target === refs.search;
    const inField = Boolean(target.closest && target.closest('.form'));
    if (event.key === 'Escape') {
      event.preventDefault();
      if (inField) { View.focusSearch(false); return; }
      if (inSearch && refs.search.value) {
        refs.search.value = '';
        Model.setQuery('');
        View.render();
        return;
      }
      close();
      return;
    }
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      if (inField && target.tagName === 'INPUT' && (target.type === 'range' || target.type === 'number')) return;
      event.preventDefault();
      move(event.key === 'ArrowDown' ? 1 : -1);
      return;
    }
    if (event.key === 'Enter') {
      if (target.closest && target.closest('.picker-menu')) return;
      if (Model.state.tab === 'reading') {
        // rien à lancer dans l'onglet Lecture ; un lien ou un bouton de la page reste activable au clavier
        if (!(target.tagName === 'BUTTON' && target.closest('.page-right'))) event.preventDefault();
        return;
      }
      event.preventDefault();
      if (inField) { run(); return; }
      const row = View.currentRow();
      if (!row) return;
      if (row.entry.kind === 'key') return;
      if (row.args.length > 0 && !inField) { View.focusFirstField(); return; }
      run();
      return;
    }
    if (!inSearch && !inField && event.key.length === 1 && !event.ctrlKey && !event.altKey && !event.metaKey) {
      // taper n'importe où revient à chercher
      View.focusSearch(false);
    }
  });

  /** openAt : page, chapitre de lecture (première page ; T-022), puis module ; vrai si quelque chose s'est ouvert. */
  function applyFocus() {
    const target = CodexReader.focusTarget(pendingFocus, Model.state.reading, Model.state.chapters);
    pendingFocus = null;
    if (!target) return false;
    Model.setTab(target.tab);
    Model.setQuery('');
    refs.search.value = '';
    Model.setChapter(target.chapter);
    View.render();
    if (target.tab === 'reading') {
      if (target.page) selectPage(target.page);
      else ensurePage();
    }
    return true;
  }

  /** Secours : sans contenu, le redemande ; avec un contenu ancien, fait oublier les versions au client. */
  async function resync() {
    if (Model.state.version !== null) {
      Bridge.post('stale');
      if (!applyFocus()) ensurePage();
      return;
    }
    const result = await Bridge.post('refresh');
    if (!result.ok || !result.payload) {
      pendingFocus = null;
      View.toast(errorMessage(result.error), 'danger');
      return;
    }
    Model.load(result.payload);
    View.render();
    if (!applyFocus()) ensurePage();
  }

  Bridge.onMessage((action, payload) => {
    if (action === 'open') {
      pendingFocus = typeof payload.focus === 'string' && payload.focus ? payload.focus : null;
      Forms.clearCache();
      Model.load(payload);
      CodexDock.apply(app, CodexDock.rect(payload.dock));
      View.render();
      app.hidden = false;
      View.focusSearch(true);
      if (Model.state.version !== payload.version) resync();
      else if (!applyFocus()) ensurePage();
    } else if (action === 'notify') {
      View.toast(payload.message, payload.kind);
    } else if (action === 'close') {
      pendingFocus = null;
      app.hidden = true;
    }
  });
})();
