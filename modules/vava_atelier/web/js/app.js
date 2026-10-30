'use strict';
/*
 * vava_atelier/web/js/app.js
 * Rôle : assemblage de la page : messages du Lua, écrans, contenus gardés par empreinte, Échap, confirmation de sortie.
 * Dépendances : strings.js, bridge.js, format.js, components.js, widgets.js, form.js, view-*.js
 */

(() => {
  const { Toast, Confirm, Picker, Banner, Keys } = UI;
  const { str, list } = Format;
  const $ = (id) => document.getElementById(id);
  const app = $('app'), veil = $('veil'), frame = $('frame'), sheet = $('sheet'), sideBox = $('side'), sideSheet = $('side-sheet');

  const state = {
    closeKey: 'F9',
    home: { version: '', content: null, tags: {}, drafts: [], journal: [], rank: '' },
    descriptors: new Map(),
    labels: new Map(),
    screen: null, view: null, editor: '', descriptor: null, kind: null, entry: null,
    list: { query: '', page: 1, seq: 0 },
    journal: { filter: '', next: 0, seq: 0 },
    banner: undefined,   // undefined : par défaut ; null : caché
    keys: [],
  };

  function mount(screen, view, layout) {
    Picker.close(false);
    const side = layout === 'side';
    veil.hidden = side;
    frame.hidden = side;
    sideBox.hidden = !side;
    (side ? sheet : sideSheet).replaceChildren();
    (side ? sideSheet : sheet).replaceChildren(view.el);
    if (side) sideChrome(); else { Banner.hide(); Keys.hide(); }
    state.screen = screen;
    state.view = view;
    if (screen !== 'entry') state.entry = null;
  }

  function sideChrome() {
    const banner = state.banner || {};
    if (state.banner === null) Banner.hide();
    else Banner.show(str(banner.title) || str(state.descriptor && state.descriptor.label), str(banner.line) || STRINGS.modeEdit, back);
    if (state.keys.length > 0) Keys.show(state.keys); else Keys.hide();
  }

  function hide() {
    Picker.close(false);
    if (Confirm.isOpen()) Confirm.cancel();
    app.hidden = true;
    Object.assign(state, { screen: null, view: null, entry: null });
    sheet.replaceChildren();
    sideSheet.replaceChildren();
    Banner.hide();
    Keys.hide();
  }

  function refused(code, editor) {
    Toast.show(errorText(code), 'error');
    if (code === 'unknown_editor' && editor) {
      state.descriptors.delete(editor);
      if (state.screen !== 'home') goHome(true);
    }
  }

  // Accueil

  function absorbHome(data) {
    const version = str(data.version);
    if (data.content && typeof data.content === 'object') Object.assign(state.home, { content: data.content, version });
    state.home.tags = data.tags && typeof data.tags === 'object' && !Array.isArray(data.tags) ? data.tags : {};
    state.home.drafts = list(data.drafts);
    state.home.journal = list(data.journal);
    if (typeof data.rank === 'string') state.home.rank = data.rank;
    return state.home.content !== null && state.home.version === version;
  }

  /** Secours : le Lua oublie ses versions et tout est redemandé. */
  async function resyncHome() {
    Bridge.post('stale');
    const result = await Bridge.post('home', { version: '' });
    return result.ok && absorbHome(result.data);
  }

  function renderHome() {
    Object.assign(state, { editor: '', descriptor: null, kind: null });
    const view = HomeView.render(state.home, homeActions);
    mount('home', view, 'frame');
    view.focus();
  }

  async function goHome(refresh) {
    if (refresh) {
      const result = await Bridge.post('home', { version: state.home.version });
      if (result.ok ? !absorbHome(result.data) : result.error === 'stale') await resyncHome();
    }
    if (!app.hidden) renderHome();
  }

  const homeActions = {
    openEditor: (editor) => openEditor(editor),
    openEntry: (editor, kind, id) => openEntry(editor, kind, id),
    openHit: (hit) => (str(hit.id) ? openEntry(hit.editor, hit.kind, hit.id) : openEditor(hit.editor, str(hit.kind))),
    openJournal: () => openJournal(''),
    close: () => requestClose(),
    search: (text) => Bridge.post('search', { text }),
  };

  // Ateliers

  function takeDescriptor(editor, data) {
    if (data.descriptor && typeof data.descriptor === 'object') state.descriptors.set(editor, { version: str(data.version), descriptor: data.descriptor });
    const cached = state.descriptors.get(editor);
    return cached && cached.version === str(data.version) ? cached.descriptor : null;
  }

  async function descriptorOf(editor) {
    for (let attempt = 0; attempt < 2; attempt += 1) {
      if (attempt > 0) Bridge.post('stale');
      const result = await Bridge.post('editor', { editor });
      if (!result.ok && result.error === 'stale' && attempt === 0) continue;
      if (!result.ok) return { error: result.error };
      const descriptor = takeDescriptor(editor, result.data);
      if (descriptor) return { descriptor };
    }
    return { error: 'invalid_response' };
  }

  async function useEditor(editor, kindId) {
    if (!str(editor)) return false;
    let descriptor = state.editor === editor ? state.descriptor : null;
    if (!descriptor) {
      const got = await descriptorOf(editor);
      if (got.error) { refused(got.error, editor); return false; }
      descriptor = got.descriptor;
    }
    const kinds = list(descriptor.kinds).filter((k) => k && typeof k.id === 'string');
    const kind = kindId ? kinds.find((k) => k.id === kindId) : kinds[0];
    if (!kind) { refused('unknown_kind'); return false; }
    if (state.editor !== editor || !state.kind || state.kind.id !== kind.id) state.list = { query: '', page: 1, seq: state.list.seq + 1 };
    Object.assign(state, { editor, descriptor, kind });
    return true;
  }

  async function openEditor(editor, kindId) {
    if (await useEditor(editor, kindId)) showList();
  }

  // Liste

  function showList() {
    const view = ListView.render({ descriptor: state.descriptor, kind: state.kind, query: state.list.query }, {
      back: () => goHome(true),
      selectKind: (id) => openEditor(state.editor, id),
      filter: (text) => { Object.assign(state.list, { query: text, page: 1 }); loadList(); },
      page: (n) => { state.list.page = n; loadList(); },
      openEntry: (id) => openEntry(state.editor, state.kind.id, id),
      create: () => openEntry(state.editor, state.kind.id, ''),
    });
    mount('list', view, 'frame');
    view.focus();
    loadList();
  }

  async function loadList() {
    const seq = ++state.list.seq, view = state.view, editor = state.editor;
    const result = await Bridge.post('list', { editor, kind: state.kind.id, page: state.list.page, query: state.list.query });
    if (seq !== state.list.seq || state.view !== view) return;
    if (result.ok) { view.setData(result.data); return; }
    view.setError(result.error);
    if (result.error === 'unknown_editor') refused(result.error, editor);
  }

  // Fiche

  const labelKey = (field, value) => (field.widget === 'item' ? `item|${value}` : `${state.editor}|${state.kind.id}|${field.id}|${value}`);
  const cleanItem = (item) => ({ value: item.value, label: str(item.label), image: str(item.image), provisional: item.provisional === true });

  async function lookup(field, query, page) {
    const result = await Bridge.post('options', { editor: state.editor, kind: state.kind.id, field: field.id, query: Format.query(query), page: page || 1 });
    if (!result.ok) return { error: result.error };
    const items = list(result.data.items).filter((i) => i && typeof i.value === 'string').map(cleanItem);
    for (const item of items) state.labels.set(labelKey(field, item.value), item);
    return { items, more: result.data.more === true };
  }

  function flatten(values) {
    const out = {};
    for (const map of ['n', 's', 'b']) {
      const part = values && values[map];
      if (part && typeof part === 'object' && !Array.isArray(part)) Object.assign(out, part);
    }
    return out;
  }

  async function openEntry(editor, kindId, id) {
    if (!(await useEditor(editor, kindId))) return;
    const kind = state.kind;
    let values = {}, warnings = [], compare = null, footer = [], title = str(kind.newLabel), tag = { label: STRINGS.entry.stateNew, tone: 'new' };
    if (id) {
      const result = await Bridge.post('read', { editor, kind: kind.id, id });
      if (!result.ok) { refused(result.error, editor); return; }
      const data = result.data;
      values = flatten(data.values);
      warnings = list(data.warnings).map((w) => (typeof w === 'string' ? w : str(w && w.field)));
      compare = data.compare || null;
      footer = list(data.footer);
      title = str(data.title) || id;
      tag = data.state && str(data.state.label) ? { label: data.state.label, tone: str(data.state.tone) || 'live' } : { label: STRINGS.entry.stateLive, tone: 'live' };
      for (const known of Format.fieldLabels((kind.form || {}).fields, values, data.labels)) state.labels.set(labelKey(known.field, known.value), known.item);
    }
    const entry = { editor, kind, id: id || '', checking: false };
    entry.form = Form.build(kind, values, {
      warnings: new Set(warnings),
      changed: (fieldId) => {
        if (!entry.view) return;
        entry.view.hideOk();
        if (fieldId === entry.form.titleField) entry.view.setTitle(entry.form.title());
      },
      lookup,
      known: (field, value) => state.labels.get(labelKey(field, value)) || null,
      remember: (field, item) => state.labels.set(labelKey(field, item.value), cleanItem(item)),
    });
    const layout = kind.layout === 'side' ? 'side' : 'page';
    entry.view = EntryView.render({ descriptor: state.descriptor, kind, layout, title, state: tag, form: entry.form, compare, footer }, { back, check });
    entry.snapshot = entry.form.snapshot();
    state.entry = entry;
    mount('entry', entry.view, layout);
    entry.form.focusFirst();
  }

  /** Vrai si l'on peut quitter : rien de changé depuis l'ouverture (vérifiée ou non), ou « Quitter ». */
  async function leaveEntry() {
    if (!state.entry || state.entry.form.snapshot() === state.entry.snapshot) return true;
    return Confirm.ask(STRINGS.confirmLeave);
  }

  async function check() {
    const entry = state.entry;
    if (!entry || entry.checking) return;
    entry.view.hideOk();
    if (!entry.form.validate()) { entry.form.focusFirstError(); return; }
    entry.checking = true;
    entry.view.setChecking(true);
    const values = entry.form.packet();
    const result = await Bridge.post('check', { editor: entry.editor, kind: entry.kind.id, id: entry.id, values });
    entry.checking = false;
    if (state.entry !== entry) return;
    entry.view.setChecking(false);
    if (!result.ok) { refused(result.error, entry.editor); return; }
    if (result.data.valid === true) {
      entry.form.clear();
      entry.view.flashOk();
      if (result.data.compare) entry.view.setCompare(result.data.compare);
    } else {
      entry.form.showErrors(result.data.errors);
      entry.form.focusFirstError();
    }
  }

  // Journal

  function openJournal(filter) {
    Object.assign(state, { editor: '', descriptor: null, kind: null });
    state.journal = { filter, next: 0, seq: state.journal.seq + 1 };
    const editors = list((state.home.content || {}).cards).filter((c) => c && c.upcoming !== true && typeof c.editor === 'string').map((c) => ({ editor: c.editor, label: str(c.label) }));
    const view = JournalView.render({ editors, filter }, { back: () => goHome(true), filter: (editor) => openJournal(editor), older: () => loadJournal(false) });
    mount('journal', view, 'frame');
    view.focus();
    loadJournal(true);
  }

  async function loadJournal(reset) {
    const journal = state.journal, view = state.view, seq = ++journal.seq;
    view.setLoading(true);
    const result = await Bridge.post('journal', { before: reset ? 0 : journal.next, editor: journal.filter });
    if (seq !== journal.seq || state.view !== view) return;
    view.setLoading(false);
    if (!result.ok) { view.setError(result.error); return; }
    journal.next = Number.isInteger(result.data.next) ? result.data.next : 0;
    view.add(result.data, reset);
  }

  // Navigation et fermeture

  async function back() {
    if (state.screen === 'entry') {
      if (await leaveEntry()) showList();
    } else if (state.screen === 'list' || state.screen === 'journal') goHome(true);
    else if (state.screen === 'home' && !state.view.clearSearch()) requestClose();
  }

  async function requestClose() {
    if (state.screen === 'entry' && !(await leaveEntry())) return;
    hide();
    Bridge.post('close');
  }

  function isCloseKey(event) {
    const key = str(state.closeKey).toLowerCase();
    if (!key || event.key.toLowerCase() !== key) return false;
    return key.length > 1 || !['INPUT', 'TEXTAREA'].includes(event.target && event.target.tagName);
  }

  document.addEventListener('keydown', (event) => {
    if (app.hidden) return;
    if (Confirm.isOpen()) {
      if (event.key === 'Escape') { event.preventDefault(); Confirm.cancel(); }
      return;
    }
    if (isCloseKey(event)) { event.preventDefault(); requestClose(); return; }
    if (event.key !== 'Escape') return;
    event.preventDefault();
    if (Picker.isOpen()) Picker.close(true); else back();
  });

  // Messages du Lua

  async function onOpen(payload) {
    if (str(payload.closeKey)) state.closeKey = payload.closeKey;
    if (!absorbHome(payload) && !(await resyncHome())) {
      Toast.show(errorText('invalid_response'), 'error');
      Bridge.post('close');
      return;
    }
    Object.assign(state, { banner: undefined, keys: [] });
    app.hidden = false;
    renderHome();
  }

  const sideShown = () => state.screen === 'entry' && !sideBox.hidden;

  Bridge.onMessage((action, payload) => {
    if (action === 'open') onOpen(payload);
    else if (action === 'close') hide();
    else if (action === 'notify') { if (str(payload.text)) Toast.show(payload.text, str(payload.kind) || 'info'); }
    else if (action === 'editorGone') {
      const editor = str(payload.editor);
      state.descriptors.delete(editor);
      if (!app.hidden && editor && state.editor === editor && (state.screen === 'list' || state.screen === 'entry')) {
        goHome(true);
        Toast.show(STRINGS.editorGone);
      }
    } else if (action === 'mode') {
      if (Object.prototype.hasOwnProperty.call(payload, 'banner')) state.banner = payload.banner && typeof payload.banner === 'object' ? payload.banner : null;
      if (sideShown()) sideChrome();
    } else if (action === 'keys') {
      state.keys = list(payload.keys);
      if (sideShown()) sideChrome();
    }
  });

  // hors jeu seulement : web/dev/devmock.js pilote les écrans d'ici
  if (!Bridge.inGame) window.Atelier = { state, openEditor, openEntry, openJournal, check, back };
})();
