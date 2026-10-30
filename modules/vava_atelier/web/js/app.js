'use strict';
/*
 * vava_atelier/web/js/app.js
 * Rôle : assemblage de la page : messages du Lua, écrans, contenus gardés par empreinte, Échap, confirmation de sortie ;
 *        cycle d'une fiche (enregistrer, essayer, publier, abandonner, retirer, reprendre, rétablir), historique,
 *        fiches retirées, changement venu d'ailleurs (entryChanged).
 * Dépendances : strings.js, bridge.js, format.js, lifecycle.js, components.js, widgets.js, form.js, view-*.js
 */

(() => {
  const { Toast, Confirm, Picker, Banner, Keys } = UI;
  const { str, list } = Format;
  const $ = (id) => document.getElementById(id);
  const app = $('app'), veil = $('veil'), frame = $('frame'), sheet = $('sheet'), sideBox = $('side'), sideSheet = $('side-sheet');
  const int = (value) => (Number.isInteger(value) && value >= 0 ? value : 0);

  const state = {
    closeKey: 'F9',
    home: { version: '', content: null, tags: {}, drafts: [], journal: [], rank: '' },
    descriptors: new Map(),
    labels: new Map(),
    screen: null, view: null, editor: '', descriptor: null, kind: null, entry: null, history: null, removed: null,
    list: { query: '', page: 1, seq: 0 },
    journal: { filter: '', next: 0, seq: 0 },
    banner: undefined,   // undefined : celui de départ ; null : caché
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
    Object.assign(state, { screen: null, view: null, entry: null, history: null, removed: null });
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
    Object.assign(state, { editor: '', descriptor: null, kind: null, history: null, removed: null });
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
      removed: () => openRemoved(),
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

  // Retirés du royaume

  function openRemoved() {
    const view = ListView.render({ descriptor: state.descriptor, kind: state.kind, removed: true }, {
      back, page: (n) => loadRemoved(n),
      openEntry: (id, title) => openHistory('removed', state.kind, id, title, null),
    });
    state.removed = { view, seq: 0 };
    mount('removed', view, 'frame');
    view.focus();
    loadRemoved(1);
  }

  async function loadRemoved(page) {
    const removed = state.removed, seq = ++removed.seq;
    const result = await Bridge.post('removed', { editor: state.editor, kind: state.kind.id, page });
    if (state.removed !== removed || seq !== removed.seq) return;
    if (result.ok) removed.view.setData(result.data); else removed.view.setError(result.error);
  }

  // Fiche

  const labelKey = (field, value) => (field.widget === 'item' ? `item|${value}` : `${state.editor}|${state.kind.id}|${field.id}|${value}`);
  const cleanItem = (item) => ({ value: item.value, label: str(item.label), image: str(item.image), provisional: item.provisional === true });
  const layoutOf = (kind) => (kind.layout === 'side' ? 'side' : 'page');
  const dirty = (entry) => entry.form.snapshot() !== entry.snapshot;

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

  function showEntry(editor, kind, id, data, mode) {
    let values = {}, warnings = [], compare = null, footer, title = str(kind.newLabel), tag = { label: STRINGS.entry.stateNew, tone: 'new' };
    if (data) {
      values = flatten(data.values);
      warnings = list(data.warnings).map((w) => (typeof w === 'string' ? w : str(w && w.field)));
      compare = data.compare || null;
      footer = list(data.footer);
      title = str(data.title) || id;
      tag = data.state && str(data.state.label) ? { label: data.state.label, tone: str(data.state.tone) || 'live' } : { label: STRINGS.entry.stateLive, tone: 'live' };
      for (const known of Format.fieldLabels((kind.form || {}).fields, values, data.labels)) state.labels.set(labelKey(known.field, known.value), known.item);
    } else footer = Lifecycle.newFooter(state.descriptor);
    const entry = {
      editor, kind, id, mode, footer, title, tone: tag.tone, busy: false,
      rev: int(data && data.rev), version: int(data && data.version), stale: Boolean(data && data.stale === true),
      holder: data && data.holder && typeof data.holder === 'object' ? data.holder : null,
    };
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
    const layout = layoutOf(kind);
    entry.view = EntryView.render({
      descriptor: state.descriptor, kind, layout, title, state: tag, line: data ? Lifecycle.stateLine(data) : '', stale: entry.stale,
      form: entry.form, compare, footer, readOnly: Lifecycle.readOnly(data, mode === 'version'), backLabel: mode === 'version' ? STRINGS.history.title : '',
    }, { back, run });
    entry.snapshot = entry.form.snapshot();
    state.entry = entry;
    mount('entry', entry.view, layout);
    entry.form.focusFirst();
  }

  async function openEntry(editor, kindId, id) {
    if (!(await useEditor(editor, kindId))) return false;
    const kind = state.kind;
    let data = null;
    if (id) {
      const result = await Bridge.post('read', { editor, kind: kind.id, id });
      if (!result.ok) { refused(result.error, editor); return false; }
      data = result.data;
    }
    showEntry(editor, kind, id || '', data, 'entry');
    return true;
  }

  async function reloadEntry(entry) {
    const done = await openEntry(entry.editor, entry.kind.id, entry.id);
    if (!done && !app.hidden && state.entry === entry) showList();
    return done;
  }

  /** Vrai si l'on peut quitter : rien de changé depuis l'ouverture (vérifiée ou non), ou « Quitter ». */
  async function leave(entry) {
    if (!entry || entry.mode !== 'entry' || !dirty(entry)) return true;
    return Confirm.ask(STRINGS.confirmLeave);
  }

  const keys = (entry) => ({ editor: entry.editor, kind: entry.kind.id, id: entry.id });
  const DIVERGED = new Set(['stale', 'draft_taken', 'not_holder', 'no_draft']);

  function refusedAt(code, editor) {
    if (code === 'stale') Toast.show(STRINGS.entryStale, 'error'); else refused(code, editor);
  }

  function entryRefused(entry, code) {
    if (!DIVERGED.has(code)) { refused(code, entry.editor); return; }
    const text = code === 'stale' ? STRINGS.entryStale : errorText(code);
    Toast.show(text, 'error');
    if (state.entry === entry) entry.view.setNotice(text, () => reloadEntry(entry));
  }

  function absorb(entry, data) {
    if (Number.isInteger(data.rev)) entry.rev = data.rev;
    if (data.state && str(data.state.label)) {
      entry.tone = str(data.state.tone) || 'live';
      entry.view.setState(data.state, str(data.state.line), entry.stale);
    }
    if (data.footer) {
      entry.footer = list(data.footer);
      entry.view.setFooter(entry.footer);
    }
  }

  function showErrors(entry, errors, lead) {
    const all = list(errors).map((e) => (typeof e === 'string' ? { text: e } : e));
    entry.form.showErrors(lead ? [{ text: lead }].concat(all) : all);
    entry.form.focusFirstError();
  }

  function written(entry, result, lead) {
    if (state.entry !== entry) return false;
    if (!result.ok) { entryRefused(entry, result.error); return false; }
    if (result.data.done === true || (result.data.done === undefined && result.data.errors === undefined)) return true;
    showErrors(entry, result.data.errors, lead);
    return false;
  }

  async function work(id, task) {
    const entry = state.entry;
    if (!entry || entry.busy) return;
    entry.busy = true;
    entry.view.setBusy(true, id);
    try { await task(entry); } finally {
      entry.busy = false;
      if (state.entry === entry) entry.view.setBusy(false, id);
    }
  }

  async function checkEntry(entry) {
    entry.view.hideOk();
    if (!entry.form.validate()) { entry.form.focusFirstError(); return; }
    const result = await Bridge.post('check', { ...keys(entry), values: entry.form.packet() });
    if (state.entry !== entry) return;
    if (!result.ok) { refused(result.error, entry.editor); return; }
    if (result.data.valid === true) {
      entry.form.clear();
      entry.view.flashOk();
      if (result.data.compare) entry.view.setCompare(result.data.compare);
    } else showErrors(entry, result.data.errors);
  }

  async function saveEntry(entry, quiet) {
    if (!entry.form.validate()) { entry.form.focusFirstError(); return false; }
    const result = await Bridge.post('save', { ...keys(entry), rev: entry.rev, values: entry.form.packet() });
    if (!written(entry, result)) return false;
    const data = result.data;
    if (str(data.id)) entry.id = data.id;
    entry.snapshot = entry.form.snapshot();
    absorb(entry, data);
    if (str(data.title)) entry.view.setTitle(data.title);
    const warnings = list(data.warnings);
    if (warnings.length > 0) showErrors(entry, warnings, STRINGS.warningsSaved);
    else {
      entry.form.clear();
      if (!quiet) Toast.show(STRINGS.saved, 'success');
    }
    return true;
  }

  const saved = async (entry) => (entry.id === '' || dirty(entry) ? saveEntry(entry, true) : true);

  async function trial(entry) {
    if (!(await saved(entry))) return;
    const result = await Bridge.post('trial', { ...keys(entry), rev: entry.rev });
    if (written(entry, result, STRINGS.invalid)) absorb(entry, result.data);
  }

  async function endTrial(entry) {
    const result = await Bridge.post('endTrial', keys(entry));
    if (written(entry, result)) absorb(entry, result.data);
  }

  async function publish(entry) {
    if (!(await saved(entry))) return;
    const removal = entry.tone === 'removal', texts = state.descriptor.texts || {};
    const preview = await Bridge.post('preview', { ...keys(entry), what: 'publish', ref: entry.rev });
    if (state.entry !== entry) return;
    if (!preview.ok) { entryRefused(entry, preview.error); return; }
    const p = preview.data;
    const go = await Confirm.ask(Lifecycle.confirmOf('publish', p, {
      label: Lifecycle.label(entry.footer, 'publish', str(texts.publish)), removal, publishHint: str(texts.publishHint), fields: (entry.kind.form || {}).fields,
    }));
    if (p.valid !== true) { if (state.entry === entry) showErrors(entry, p.errors); return; }
    if (!go || state.entry !== entry) return;
    const result = await Bridge.post('publish', { ...keys(entry), rev: entry.rev, token: str(p.token) });
    if (!written(entry, result)) return;
    if (removal) { Toast.show(STRINGS.removalDone, 'success'); showList(); return; }
    Object.assign(entry, { rev: 0, stale: false });
    entry.form.clear();
    absorb(entry, result.data);
  }

  async function discard(entry) {
    if (entry.tone !== 'removal' && !(await Confirm.ask(STRINGS.confirm.discard))) return;
    const result = await Bridge.post('discard', { ...keys(entry), rev: entry.rev });
    await afterRemoval(entry, result);
  }

  async function retire(entry) {
    if (!(await Confirm.ask(Lifecycle.confirmRetire(entry.kind)))) return;
    await afterRemoval(entry, await Bridge.post('retire', keys(entry)));
  }

  async function afterRemoval(entry, result) {
    if (state.entry !== entry) return;
    if (result.ok && result.data.gone === true) showList();
    else if (written(entry, result)) await reloadEntry(entry);
  }

  async function take(entry) {
    if (!(await Confirm.ask(Lifecycle.confirmTake(str(entry.holder && entry.holder.label))))) return;
    const result = await Bridge.post('take', { ...keys(entry), rev: entry.rev });
    if (!written(entry, result)) return;
    entry.holder = null;
    absorb(entry, result.data);
    entry.view.setReadOnly(entry.tone === 'removal');
  }

  const RUN = {
    check: checkEntry, save: (entry) => saveEntry(entry, false), trial, endTrial, publish, discard, retire, take,
    restore: (entry) => restoreVersion(entry.version),
  };

  function run(id) {
    const entry = state.entry;
    if (!entry) return;
    if (id === 'history') { if (entry.id) openHistory('entry', entry.kind, entry.id, entry.form.title() || entry.title, entry); return undefined; }
    return RUN[id] ? work(id, RUN[id]) : undefined;
  }

  // Historique et versions

  function openHistory(from, kind, id, title, parked) {
    const history = { editor: state.editor, kind, id, title, from, parked, seq: 0, layout: layoutOf(kind) };
    history.view = HistoryView.render({ descriptor: state.descriptor, layout: history.layout, title }, {
      back, view: (n) => openVersion(n), restore: (n) => restoreVersion(n), older: () => loadHistory(false),
    });
    state.history = history;
    mount('history', history.view, history.layout);
    history.view.focus();
    loadHistory(true);
  }

  async function loadHistory(reset) {
    const history = state.history, seq = ++history.seq;
    history.view.setLoading(true);
    const result = await Bridge.post('history', { editor: history.editor, kind: history.kind.id, id: history.id, before: reset ? 0 : history.view.oldest() });
    if (state.history !== history || seq !== history.seq) return;
    history.view.setLoading(false);
    if (result.ok) history.view.add(result.data, reset); else history.view.setError(result.error);
  }

  async function openVersion(version) {
    const history = state.history;
    const result = await Bridge.post('version', { editor: history.editor, kind: history.kind.id, id: history.id, version });
    if (state.history !== history || state.screen !== 'history') return;
    if (!result.ok) { refused(result.error, history.editor); return; }
    showEntry(history.editor, history.kind, history.id, result.data, 'version');
    state.entry.version = int(result.data.version) || version;
  }

  async function restoreVersion(version) {
    const history = state.history;
    if (!history || !version) return;
    const at = { editor: history.editor, kind: history.kind.id, id: history.id };
    const preview = await Bridge.post('preview', { ...at, what: 'restore', ref: version });
    if (state.history !== history) return;
    if (!preview.ok) { refusedAt(preview.error, at.editor); return; }
    const p = preview.data;
    const go = await Confirm.ask(Lifecycle.confirmOf('restore', p, { version, fields: (history.kind.form || {}).fields }));
    if (!go || p.valid !== true || state.history !== history) return;
    const result = await Bridge.post('restore', { ...at, version, token: str(p.token) });
    if (state.history !== history) return;
    if (!result.ok) { refusedAt(result.error, at.editor); return; }
    if (result.data.done !== true) { Toast.show(Lifecycle.errorLines(result.data.errors, [])[0] || errorText('default'), 'error'); return; }
    history.parked = null;
    await openEntry(at.editor, at.kind, at.id);
  }

  // Changement venu d'ailleurs

  function changedElsewhere(entry) {
    if (dirty(entry) || entry.busy) entry.view.setNotice(STRINGS.changed.dirty, () => reloadEntry(entry));
    else reloadEntry(entry).then((done) => { if (done) Toast.show(STRINGS.changed.live); });
  }

  function onChanged(payload) {
    const parked = state.history && state.history.parked;
    if (parked && Lifecycle.changed(parked, payload, false) !== 'none') parked.outdated = true;
    if (state.screen === 'entry' && Lifecycle.changed(state.entry, payload, false) !== 'none') changedElsewhere(state.entry);
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
    const { screen, entry, history } = state;
    if (screen === 'entry' && entry.mode === 'version' && history) {
      mount('history', history.view, history.layout);
      history.view.focus();
    } else if (screen === 'entry') {
      if (await leave(entry)) showList();
    } else if (screen === 'history') {
      const parked = history.parked;
      if (history.from === 'entry' && parked) {
        state.history = null;
        state.entry = parked;
        mount('entry', parked.view, history.layout);
        if (parked.outdated) { parked.outdated = false; changedElsewhere(parked); }
      } else if (history.from === 'removed' && state.removed) {
        state.history = null;
        mount('removed', state.removed.view, 'frame');
        state.removed.view.focus();
      } else showList();
    } else if (screen === 'removed') showList();
    else if (screen === 'list' || screen === 'journal') goHome(true);
    else if (screen === 'home' && !state.view.clearSearch()) requestClose();
  }

  async function requestClose() {
    if (!(await leave(state.entry)) || !(await leave(state.history && state.history.parked))) return;
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

  const sideShown = () => !sideBox.hidden && (state.screen === 'entry' || state.screen === 'history');
  const ON_EDITOR = new Set(['list', 'entry', 'history', 'removed']);

  Bridge.onMessage((action, payload) => {
    if (action === 'open') onOpen(payload);
    else if (action === 'close') hide();
    else if (action === 'notify') { if (str(payload.text)) Toast.show(payload.text, str(payload.kind) || 'info'); }
    else if (action === 'entryChanged') { if (!app.hidden) onChanged(payload); }
    else if (action === 'editorGone') {
      const editor = str(payload.editor);
      state.descriptors.delete(editor);
      if (!app.hidden && editor && state.editor === editor && ON_EDITOR.has(state.screen)) {
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
  if (!Bridge.inGame) window.Atelier = { state, openEditor, openEntry, openJournal, openRemoved, openHistory, run, back, check: () => run('check') };
})();
