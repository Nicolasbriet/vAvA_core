'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage : messages du jeu, recherche, onglets et chapitres, sélection (souris et clavier), signets,
 *        lancement d'une ligne composée, réglage « rester ouvert », fermeture, chapitre demandé à l'ouverture
 *        (export openAt du client, 1.4.0).
 */

(() => {
  const app = document.getElementById('app');
  // Chapitre demandé à l'ouverture (export openAt, 1.4.0), appliqué une fois un contenu chargé, puis oublié.
  let pendingFocus = null;

  function selectRow(id, focusForm) {
    Model.select(id);
    View.renderSelection();
    if (focusForm && !View.focusFirstField()) View.focusSearch(false);
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
    selectRow(order[next].id, false);
  }

  View.init(app);
  const refs = View.refs();

  refs.search.addEventListener('input', () => {
    Model.setQuery(refs.search.value);
    View.renderIndex();
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
      return;
    }
    const chapter = event.target.closest('.chapter');
    if (chapter) {
      Model.setChapter(chapter.dataset.chapter);
      View.render();
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
    if (rowNode) {
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

  /** Ouvre le chapitre demandé s'il existe (onglet des commandes, recherche vidée) ; un chapitre inconnu laisse le
   *  livre à son index, sans message. Les pages de lecture (T-023) qui vivraient ailleurs que dans les chapitres
   *  étendent cette seule fonction. */
  function applyFocus() {
    const id = pendingFocus;
    pendingFocus = null;
    if (!id || !Model.state.chapters.some((chapter) => chapter.id === id)) return;
    Model.setTab('commands');
    Model.setQuery('');
    refs.search.value = '';
    Model.setChapter(id);
    View.render();
  }

  /** La page n'a pas le contenu de la version annoncée (cas de secours, jamais attendu). Sans aucun contenu, elle
   *  le redemande aussitôt (second appel au serveur, compté par le débit de l'ouverture) ; avec un contenu plus ancien,
   *  elle le montre et fait seulement oublier les versions au client : la prochaine ouverture renverra tout, sans
   *  appel de plus. */
  async function resync() {
    if (Model.state.version !== null) {
      Bridge.post('stale');
      applyFocus();
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
    applyFocus();
  }

  Bridge.onMessage((action, payload) => {
    if (action === 'open') {
      pendingFocus = typeof payload.focus === 'string' && payload.focus ? payload.focus : null;
      Forms.clearCache();
      Model.load(payload);
      View.render();
      app.hidden = false;
      View.focusSearch(true);
      if (Model.state.version !== payload.version) resync();
      else applyFocus();
    } else if (action === 'notify') {
      View.toast(payload.message, payload.kind);
    } else if (action === 'close') {
      pendingFocus = null;
      app.hidden = true;
    }
  });
})();
