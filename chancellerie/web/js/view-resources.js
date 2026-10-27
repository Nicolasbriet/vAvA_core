'use strict';
/*
 * web/js/view-resources.js
 * Rôle : la page Ressources, comme celle de txAdmin : les ressources du dossier resources (par catégorie), avec leur
 *        version et leur auteur, leur état sur le serveur en marche (lancée ou arrêtée) et leurs commandes (démarrer,
 *        redémarrer, arrêter), et leur lancement au démarrage (ligne ensure du server.cfg). Recherche par nom ;
 *        « Relire le dossier » fait découvrir au serveur les ressources ajoutées. Arrêter ou redémarrer une ressource
 *        qui porte le serveur demande confirmation.
 */

const ResourcesView = (() => {
  const R = STRINGS.resources;
  const AFTER_ACTION_MS = 1500;
  // ressources dont l'arrêt emporte le serveur ou la Chancellerie elle-même
  const CRITICAL = new Set(['oxmysql', 'vAvA_core', 'vava_admin', 'vava_chancellerie']);

  let sheet = null;
  let context = null;
  let view = null;
  let filter = '';
  let refs = null;
  let refreshTimer = null;

  function later() {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(load, AFTER_ACTION_MS);
  }

  async function act(resource, action) {
    if ((action === 'stop' || action === 'restart') && CRITICAL.has(resource.name)) {
      const confirmed = await UI.confirm({ title: R.criticalTitle(R.actions[action], resource.name), text: R.criticalText, confirm: R.actions[action] });
      if (!confirmed) return;
    }
    if (UI.report(await API.post('/api/resources/action', { name: resource.name, action }), R.done[action])) later();
  }

  async function toggleAutostart(resource, input) {
    input.disabled = true;
    const enabled = input.checked;
    const result = await API.post('/api/resources/autostart', { name: resource.name, enabled });
    input.disabled = false;
    if (!UI.report(result, enabled ? R.autostartOn(resource.name) : R.autostartOff(resource.name))) input.checked = !enabled;
    else resource.autostart = enabled;
  }

  function stateTag(resource) {
    if (resource.started === null) return UI.el('span', 'cell-sub', R.unknown);
    return UI.el('span', `tag ${resource.started ? 'tag-live' : 'tag-off'}`, resource.started ? R.started : R.stopped);
  }

  function actionsOf(resource) {
    if (!context.can('server') || !view.running) return [];
    const buttons = resource.started
      ? [UI.button(R.actions.restart, () => act(resource, 'restart')), UI.button(R.actions.stop, () => act(resource, 'stop'), 'plain')]
      : [UI.button(R.actions.start, () => act(resource, 'ensure'), 'green')];
    return [UI.el('span', 'row-actions', null, buttons)];
  }

  function autostartCell(resource) {
    if (resource.outside) return UI.el('td', 'cell-sub', R.unknown);
    const input = UI.el('input');
    input.type = 'checkbox';
    input.checked = resource.autostart;
    input.disabled = !context.can('config') || !view.cfgExists;
    input.setAttribute('aria-label', `${R.columns[2]} : ${resource.name}`);
    input.addEventListener('change', () => toggleAutostart(resource, input));
    return UI.el('td', 'cell-check', null, [input]);
  }

  function row(resource) {
    const meta = R.meta(resource.version, resource.author);
    return UI.el('tr', null, null, [
      UI.el('td', null, null, [
        UI.el('span', 'resource-name', resource.name),
        meta ? UI.el('span', 'cell-sub resource-meta', meta) : null,
        resource.description ? UI.el('div', 'cell-sub', resource.description) : null,
      ]),
      UI.el('td', null, null, [stateTag(resource)]),
      autostartCell(resource),
      UI.el('td', 'cell-end', null, actionsOf(resource)),
    ]);
  }

  function renderList() {
    const needle = filter.trim().toLowerCase();
    const shown = view.resources.filter((r) => !needle || r.name.toLowerCase().includes(needle) || r.category.toLowerCase().includes(needle));
    if (!view.resources.length) {
      refs.list.replaceChildren(UI.el('p', 'empty', R.empty));
      return;
    }
    if (!shown.length) {
      refs.list.replaceChildren(UI.el('p', 'empty', R.noMatch));
      return;
    }
    // catégories dans l'ordre alphabétique, « sans catégorie » d'abord, ressources hors dossier à la fin
    const groups = new Map();
    for (const resource of shown) {
      const key = resource.outside ? R.outside : resource.category || R.uncategorized;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(resource);
    }
    const order = [...groups.keys()].sort((a, b) => {
      const weight = (key) => (key === R.uncategorized ? 0 : key === R.outside ? 2 : 1);
      return weight(a) - weight(b) || a.localeCompare(b);
    });
    const known = view.knownOrder || [];
    const rank = (name) => (known.includes(name) ? known.indexOf(name) : known.length);
    const bodies = [];
    for (const key of order) {
      const title = UI.el('th', null, key);
      title.colSpan = R.columns.length;
      bodies.push(UI.el('tbody', null, null, [
        UI.el('tr', 'ledger-group', null, [title]),
        ...groups.get(key).sort((a, b) => rank(a.name) - rank(b.name) || a.name.localeCompare(b.name)).map(row),
      ]));
    }
    refs.list.replaceChildren(UI.el('table', 'ledger', null, [
      UI.el('thead', null, null, [UI.el('tr', null, null, R.columns.map((c, i) => UI.el('th', i === 3 ? 'cell-end' : null, c)))]),
      ...bodies,
    ]));
  }

  function render() {
    const total = view.resources.length;
    const started = view.live ? view.resources.filter((r) => r.started).length : null;
    refs.count.textContent = R.count(total, started);
    const notes = [];
    if (!view.running) notes.push(R.offline);
    else if (!view.live) notes.push(R.notLive);
    if (!view.cfgExists) notes.push(R.noCfg);
    refs.notes.replaceChildren(...notes.map((text) => UI.el('p', 'hint', text)));
    refs.refresh.disabled = !view.running || !context.can('server');
    renderList();
  }

  async function load() {
    const result = await API.get('/api/resources');
    if (!sheet) return;
    if (!result.ok) {
      UI.report(result);
      return;
    }
    view = result;
    view.resources = UI.list(result.resources);
    render();
  }

  return {
    show(target, appContext) {
      sheet = target;
      context = appContext;
      const search = UI.el('input', 'field-input field-inline resource-search');
      search.type = 'search';
      search.placeholder = R.filter;
      search.value = filter;
      search.setAttribute('aria-label', R.filter);
      search.addEventListener('input', () => {
        filter = search.value;
        if (view) renderList();
      });
      refs = {
        count: UI.el('span', 'page-aside'),
        notes: UI.el('div'),
        list: UI.el('div'),
        refresh: UI.button(R.refresh, async () => {
          if (UI.report(await API.post('/api/resources/refresh'), R.refreshed)) later();
        }),
      };
      const heading = UI.heading(R.title);
      heading.append(refs.count);
      sheet.replaceChildren(heading, UI.el('div', 'perf-bar', null, [search, UI.el('span', 'spacer'), refs.refresh]), refs.notes, refs.list);
      load();
    },

    hide() {
      clearTimeout(refreshTimer);
      sheet = null;
      refs = null;
      view = null;
    },

    /** Le serveur a changé d'état : les ressources lancées aussi. */
    update() {
      if (sheet) later();
    },
  };
})();
