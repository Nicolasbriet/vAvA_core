'use strict';
/*
 * web/js/model.js
 * Rôle : état du Codex côté interface : entrées visibles (une ligne par commande ou sous-commande), chapitres,
 *        commandes non décrites, préférences (signets, dernières pages, réglage), onglet, chapitre, recherche,
 *        ligne choisie. Le filtrage se fait ici, sans le serveur : la liste est déjà réduite à ce que le joueur
 *        peut voir. Le contenu et les préférences sont gardés d'une ouverture à l'autre : le serveur ne les renvoie
 *        que s'ils ont changé. Onglet Lecture (1.5.0) : index des pages (dans le contenu), chapitre de lecture, page
 *        choisie, pages gardées par empreinte (le texte d'une page ne vient qu'à la demande, voir app.js).
 * Dépendances : strings.js (STRINGS, fold), reader.js (CodexReader)
 */

const Model = (() => {
  const state = {
    entries: [], byName: new Map(), chapters: [], undeclared: [], staff: false,
    version: null,   // empreinte du contenu gardé, donnée par le serveur (null : aucun contenu reçu)
    prefs: { favorites: [], recent: [], keepOpen: true }, closeKey: 'F1',
    recentMax: 12,   // dernières pages gardées : `recent.max` de la config, reçu à l'ouverture
    tab: 'commands', chapter: '', query: '', selected: null, rows: [],
    // Lecture (1.5.0) : null tant que le serveur n'envoie pas d'index (pages de lecture fermées : pas d'onglet)
    reading: null, pageById: new Map(),
    readingChapter: '',   // chapitre de lecture choisi sur la tranche ('' : tout)
    page: null,           // page choisie (identifiant)
    pageCache: new Map(), // id → { hash, body } : pages reçues, gardées tant que leur empreinte ne change pas
    pageBody: null,       // page affichée : { id, hash, body }
    pageStatus: 'idle',   // idle | loading | error
  };

  const PAGE_ROW = '#page:';   // reader.js est chargé après ce fichier : rien de lui n'est lu avant l'ouverture
  /** Identifiant de la ligne d'une page : « # » n'appartient à aucun identifiant de page ni de commande. */
  const pageRowId = (id) => PAGE_ROW + id;

  /** msgpack transmet une liste vide comme un objet vide : toujours une vraie liste. */
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));

  /** Identifiant d'une ligne : commande + sous-commande ; « | » n'appartient pas aux identifiants du core. */
  const rowId = (name, action) => `${name}|${action || ''}`;

  /** Contenu visible (entrées, chapitres, non décrites, Conseil ?), gardé jusqu'au prochain envoi du serveur. */
  function setContent(content, version) {
    state.entries = list(content.entries).map((entry) => ({
      ...entry,
      actions: entry.actions ? list(entry.actions).map((action) => ({ ...action, args: entry.actions && action.args ? list(action.args) : [] })) : null,
      args: entry.args ? list(entry.args) : [],
    }));
    state.byName = new Map(state.entries.map((entry) => [entry.name, entry]));
    state.chapters = list(content.chapters);
    state.undeclared = list(content.undeclared);
    state.staff = content.staff === true;
    state.version = typeof version === 'string' ? version : null;
    state.reading = CodexReader.normalizeIndex(content.reading);
    state.pageById = new Map(state.reading ? state.reading.pages.map((page) => [page.id, page]) : []);
    CodexReader.prune(state.pageCache, state.pageById);
  }

  /** Message d'ouverture : `content` et `prefs` ne viennent que s'ils ont changé (sinon la page garde les siens) ;
   *  `keys` (touches du joueur, relues par le jeu à chaque ouverture), `closeKey` et `recentMax` viennent toujours. */
  function load(payload) {
    if (payload.content && typeof payload.content === 'object') setContent(payload.content, payload.version);
    if (payload.prefs && typeof payload.prefs === 'object') state.prefs = normalizePrefs(payload.prefs);
    const keys = payload.keys && typeof payload.keys === 'object' ? payload.keys : {};
    for (const entry of state.entries) {
      if (typeof keys[entry.name] === 'string') entry.keyLabel = keys[entry.name];
    }
    if (payload.closeKey) state.closeKey = payload.closeKey;
    if (Number.isInteger(payload.recentMax) && payload.recentMax > 0) state.recentMax = payload.recentMax;
    if (state.chapter && !state.chapters.some((chapter) => chapter.id === state.chapter)) state.chapter = '';
    const reading = state.reading;
    if (state.readingChapter && !(reading && reading.chapters.some((chapter) => chapter.id === state.readingChapter))) state.readingChapter = '';
    if (state.page && !state.pageById.has(state.page)) {
      state.page = null;
      state.pageBody = null;
      state.pageStatus = 'idle';
    }
    if (!reading && state.tab === 'reading') {
      state.tab = 'commands';
      state.selected = null;
    }
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

  /** Lignes de l'onglet Lecture : une par page, filtrées par chapitre de lecture et par la recherche (titre, résumé,
   *  nom du chapitre). */
  function readingRows(needle) {
    const reading = state.reading;
    if (!reading) return [];
    const labels = new Map(reading.chapters.map((chapter) => [chapter.id, chapter.label]));
    const rows = [];
    for (const page of reading.pages) {
      if (state.readingChapter && page.chapter !== state.readingChapter) continue;
      if (needle && !fold(`${page.title} ${page.summary} ${labels.get(page.chapter) || ''}`).includes(needle)) continue;
      rows.push({ id: pageRowId(page.id), page });
    }
    return rows;
  }

  /** Lignes affichables : pages pour l'onglet Lecture, touches pour l'onglet Touches, commandes sinon ; chapitre et
   *  recherche appliqués. */
  function rebuild() {
    const needle = fold(state.query.trim());
    if (state.tab === 'reading') {
      state.rows = readingRows(needle);
      if (state.selected && !state.rows.some((row) => row.id === state.selected)) state.selected = null;
      return state.rows;
    }
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
    if (state.tab === 'reading') {
      // une section par chapitre de lecture, dans l'ordre de l'index
      for (const chapter of state.reading ? state.reading.chapters : []) {
        const chapterRows = rows.filter((row) => row.page.chapter === chapter.id);
        if (chapterRows.length > 0) out.push({ id: chapter.id, label: chapter.label, rows: chapterRows, reading: true });
      }
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
    if (tab === 'reading' && !state.reading) return;
    state.tab = tab;
    state.selected = tab === 'reading' && state.page ? pageRowId(state.page) : null;
    rebuild();
  }

  /** Chapitre de la tranche : chapitre de lecture dans l'onglet Lecture, module sinon. */
  function setChapter(chapter) {
    if (state.tab === 'reading') state.readingChapter = chapter;
    else state.chapter = chapter;
    rebuild();
  }

  /** Page choisie (onglet Lecture) : sa ligne est sélectionnée si elle est visible. */
  function choosePage(id) {
    state.page = id;
    state.selected = pageRowId(id);
  }

  /** Page de lecture d'une ligne, ou null. */
  const pageOfRow = (id) => (typeof id === 'string' && id.startsWith(PAGE_ROW) ? state.pageById.get(id.slice(PAGE_ROW.length)) || null : null);

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

  return {
    state, list, load, rebuild, sections, syntax, row, rowId, pageRowId, pageOfRow, isFavorite, setTab, setChapter, setQuery, select, choosePage,
    visibleOrder, normalizePrefs,
  };
})();
