'use strict';
/*
 * web/js/model.js
 * Rôle : état du Codex côté interface : entrées visibles (une ligne par commande ou sous-commande), chapitres,
 *        commandes non décrites, préférences (signets, dernières pages, réglage), onglet, chapitre, recherche,
 *        ligne choisie. Le filtrage se fait ici, sans le serveur : la liste est déjà réduite à ce que le joueur
 *        peut voir.
 */

const Model = (() => {
  const state = {
    entries: [], byName: new Map(), chapters: [], undeclared: [], staff: false,
    prefs: { favorites: [], recent: [], keepOpen: true }, closeKey: 'F1',
    tab: 'commands', chapter: '', query: '', selected: null, rows: [],
  };

  /** msgpack transmet une liste vide comme un objet vide : toujours une vraie liste. */
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));

  /** Identifiant d'une ligne : commande + sous-commande ; « | » n'appartient pas aux identifiants du core. */
  const rowId = (name, action) => `${name}|${action || ''}`;

  function load(payload) {
    state.entries = list(payload.entries).map((entry) => ({
      ...entry,
      actions: entry.actions ? list(entry.actions).map((action) => ({ ...action, args: entry.actions && action.args ? list(action.args) : [] })) : null,
      args: entry.args ? list(entry.args) : [],
    }));
    state.byName = new Map(state.entries.map((entry) => [entry.name, entry]));
    state.chapters = list(payload.chapters);
    state.undeclared = list(payload.undeclared);
    state.staff = payload.staff === true;
    state.prefs = normalizePrefs(payload.prefs);
    if (payload.closeKey) state.closeKey = payload.closeKey;
    if (state.chapter && !state.chapters.some((chapter) => chapter.id === state.chapter)) state.chapter = '';
    rebuild();
  }

  function normalizePrefs(raw) {
    const prefs = raw && typeof raw === 'object' ? raw : {};
    return {
      favorites: list(prefs.favorites).filter((name) => typeof name === 'string'),
      recent: list(prefs.recent).filter((entry) => entry && typeof entry.name === 'string'),
      keepOpen: prefs.keepOpen !== false,
    };
  }

  /** Lignes d'une entrée : une par sous-commande (ou la commande seule). */
  function rowsOf(entry) {
    if (entry.actions) return entry.actions.map((action) => ({ id: rowId(entry.name, action.id), entry, action, args: action.args || [] }));
    return [{ id: rowId(entry.name, ''), entry, action: null, args: entry.args || [] }];
  }

  /** Ligne d'une commande non décrite : un seul argument libre. */
  function undeclaredRow(command) {
    const entry = {
      name: command.name, kind: 'command', module: command.module, chapter: STRINGS.sections.undeclared, label: command.name,
      scope: 'admin', runnable: true, undeclared: true, args: [{ name: STRINGS.detail.undeclaredArgs, type: 'text', rest: true, optional: true }],
    };
    return { id: rowId(command.name, ''), entry, action: null, args: entry.args, undeclared: true };
  }

  /** Syntaxe d'une ligne : « /recolte vitalite <zone> <vitalité> ». */
  function syntax(row) {
    const parts = [`/${row.entry.name}`];
    if (row.action && row.action.id) parts.push(row.action.id);
    for (const arg of row.args) parts.push(arg.optional ? `[${arg.name}]` : `<${arg.name}>`);
    return parts.join(' ');
  }

  /** Une ligne répond à la recherche par son nom, son libellé, son chapitre et, pour une sous-commande, son propre
   *  libellé et sa description ; la description générale de la commande ne vaut que pour sa forme nue. */
  function matches(row, needle) {
    const action = row.action;
    const parts = [row.entry.name, row.entry.label, row.entry.chapter];
    if (action) parts.push(action.id, action.label, action.description);
    if (!action || !action.id) parts.push(row.entry.description);
    return fold(parts.filter(Boolean).join(' ')).includes(needle);
  }

  /** Lignes affichables : touches pour l'onglet Touches, commandes sinon ; chapitre et recherche appliqués. */
  function rebuild() {
    const needle = fold(state.query.trim());
    const keysTab = state.tab === 'keys';
    const rows = [];
    for (const entry of state.entries) {
      const isKey = entry.kind === 'key';
      if (keysTab ? !(isKey || entry.key) : isKey) continue;
      if (state.chapter && entry.module !== state.chapter) continue;
      if (keysTab) {
        // une commande liée à une touche compte pour une seule touche, quelles que soient ses sous-commandes
        const row = { id: rowId(entry.name, '#touche'), entry, action: null, args: [], key: true };
        if (!needle || fold(`${entry.name} ${entry.label} ${entry.chapter} ${entry.keyLabel || entry.keyDisplay || entry.key}`).includes(needle)) rows.push(row);
        continue;
      }
      for (const row of rowsOf(entry)) {
        if (!needle || matches(row, needle)) rows.push(row);
      }
    }
    if (!keysTab && state.staff && !state.chapter) {
      for (const command of state.undeclared) {
        const row = undeclaredRow(command);
        if (!needle || fold(`${command.name} ${command.module}`).includes(needle)) rows.push(row);
      }
    }
    state.rows = rows;
    if (state.selected && !rows.some((row) => row.id === state.selected)) state.selected = null;
    return rows;
  }

  /** Sections de l'index : signets et dernières pages (sans recherche ni chapitre), puis les chapitres. */
  function sections() {
    const rows = state.rows;
    const out = [];
    const byId = new Map(rows.map((row) => [row.id, row]));
    const searching = state.query.trim().length > 0;
    if (searching) {
      out.push({ id: 'results', label: STRINGS.sections.results, rows });
      return out;
    }
    if (state.tab === 'commands' && !state.chapter) {
      const favorites = state.prefs.favorites.flatMap((name) => rows.filter((row) => row.entry.name === name));
      if (favorites.length > 0) out.push({ id: 'favorites', label: STRINGS.sections.favorites, rows: favorites });
      const recent = state.prefs.recent.map((entry) => byId.get(rowId(entry.name, entry.action)) || byId.get(rowId(entry.name, ''))).filter(Boolean);
      if (recent.length > 0) out.push({ id: 'recent', label: STRINGS.sections.recent, rows: recent });
    }
    const chapters = new Map();
    for (const row of rows) {
      const key = row.undeclared ? '\u0000undeclared' : row.entry.module;
      if (!chapters.has(key)) chapters.set(key, { id: row.undeclared ? 'undeclared' : row.entry.module, label: row.entry.chapter, rows: [], undeclared: row.undeclared });
      chapters.get(key).rows.push(row);
    }
    for (const section of chapters.values()) out.push(section);
    return out;
  }

  const row = (id) => state.rows.find((entry) => entry.id === id) || null;
  const isFavorite = (name) => state.prefs.favorites.includes(name);

  function setTab(tab) {
    if (state.tab === tab) return;
    state.tab = tab;
    state.selected = null;
    rebuild();
  }

  function setChapter(chapter) {
    state.chapter = chapter;
    rebuild();
  }

  function setQuery(query) {
    state.query = query;
    rebuild();
  }

  function select(id) {
    state.selected = id;
  }

  /** Ordre visuel des lignes (sections) pour la navigation au clavier ; une ligne présente dans plusieurs
   *  sections (signet et chapitre) n'est parcourue qu'une fois. */
  function visibleOrder() {
    const seen = new Set();
    return sections().flatMap((section) => section.rows).filter((row) => !seen.has(row.id) && seen.add(row.id));
  }

  return { state, list, load, rebuild, sections, syntax, row, rowId, isFavorite, setTab, setChapter, setQuery, select, visibleOrder, normalizePrefs };
})();
