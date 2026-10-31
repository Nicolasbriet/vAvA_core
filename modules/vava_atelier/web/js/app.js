'use strict';
/*
 * vava_atelier/web/js/app.js — assemblage : messages du Lua, écrans, cycle d'une fiche, historique, sortie ; placement
 *   (T-102) : visée demandée au jeu, poses reçues, essai joué (bandeau seul)
 * Dépendances : strings.js, bridge.js, format.js, lifecycle.js, components.js, widgets.js, form.js, placing.js, view-*.js
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
    placing: { on: false, keys: [] },   // visée en cours (message `placing`), pour la fiche `key`
    lastMode: 'self',
    suspended: false, suspendedLine: '',  // essai joué : bandeau seul
  };

  const entryKey = (entry) => (entry ? `${entry.editor}|${entry.kind.id}|${entry.id}` : '');

  function mount(screen, view, layout) {
    Picker.close(false);
    const side = layout === 'side';
    veil.hidden = side;
    frame.hidden = side;
    sideBox.hidden = !side;
    (side ? sheet : sideSheet).replaceChildren();
    (side ? sideSheet : sheet).replaceChildren(view.el);
    state.screen = screen;
    state.view = view;
    if (state.placing.on && (screen !== 'entry' || entryKey(state.entry) !== state.placing.key)) {
      state.placing = { on: false, keys: [] };
      Bridge.post('placeStop');
    }
    if (screen !== 'entry') state.entry = null;
    chrome();
  }

  /** Bandeau, barre des touches et mise en page : essai joué (bandeau seul), visée, volet, page. */
  function chrome() {
    const side = !sideBox.hidden, placing = state.placing.on && state.screen === 'entry';
    app.classList.toggle('placing', placing);
    app.classList.toggle('placing-page', placing && !side);
    app.classList.toggle('suspended', state.suspended);
    const banner = state.banner || {};
    const title = str(banner.title) || str(state.descriptor && state.descriptor.label);
    const keys = placing ? state.placing.keys : state.keys;
    if (state.suspended) Banner.show(title, state.suspendedLine, null);
    else if (placing) Banner.show(title, STRINGS.place.editLine, back);
    else if (side && state.banner !== null) Banner.show(title, str(banner.line) || STRINGS.modeEdit, back);
    else Banner.hide();
    if (!state.suspended && (side || placing) && keys.length > 0) Keys.show(keys); else Keys.hide();
  }

  function hide() {
    Picker.close(false);
    if (Confirm.isOpen()) Confirm.cancel();
    app.hidden = true;
    app.classList.remove('placing', 'placing-page', 'suspended');
    Object.assign(state, { screen: null, view: null, entry: null, history: null, removed: null, placing: { on: false, keys: [] }, suspended: false });
    sheet.replaceChildren();
    sideSheet.replaceChildren();
    Banner.hide();
    Keys.hide();
  }

  const DIVERGED = new Set(['stale', 'draft_taken', 'not_holder', 'no_draft']);

  function refused(result, editor, entry) {
    const code = result.error, text = errorText(code, result.text);
    Toast.show(text, 'error');
    if (entry && state.entry === entry && DIVERGED.has(code)) entry.view.setNotice(text, () => reloadEntry(entry));
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
      if (!result.ok) return result;
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
      if (got.error) { refused(got, editor); return false; }
      descriptor = got.descriptor;
    }
    const kinds = list(descriptor.kinds).filter((k) => k && typeof k.id === 'string');
    const kind = kindId ? kinds.find((k) => k.id === kindId) : kinds[0];
    if (!kind) { refused({ error: 'unknown_kind' }); return false; }
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

  /** Une page d'une liste : seule la dernière demande de `holder` compte, et seulement si `view` est à l'écran. */
  async function fetchPage(holder, name, args, view, done) {
    const seq = holder.seq = (holder.seq || 0) + 1;
    if (view.setLoading) view.setLoading(true);
    const result = await Bridge.post(name, args);
    if (seq !== holder.seq || state.view !== view) return null;
    if (view.setLoading) view.setLoading(false);
    if (result.ok) done(result.data); else view.setError(result.error, result.text);
    return result;
  }

  async function loadList() {
    const view = state.view, editor = state.editor;
    const result = await fetchPage(state.list, 'list', { editor, kind: state.kind.id, page: state.list.page, query: state.list.query }, view, (data) => view.setData(data));
    if (result && result.error === 'unknown_editor') refused(result, editor);
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

  function loadRemoved(page) {
    const { view } = state.removed;
    fetchPage(state.removed, 'removed', { editor: state.editor, kind: state.kind.id, page }, view, (data) => view.setData(data));
  }

  // Fiche

  const labelKey = (field, value, kind = state.kind.id) => (field.widget === 'item' ? `item|${value}` : `${state.editor}|${kind}|${field.id}|${value}`);
  const cleanItem = (item) => ({ value: item.value, label: str(item.label), image: str(item.image), provisional: item.provisional === true });
  const layoutOf = (kind) => (kind.layout === 'side' ? 'side' : 'page');
  const dirty = (entry) => entry.form.snapshot() !== entry.snapshot;

  async function lookup(field, query, page, kind = state.kind.id) {
    const result = await Bridge.post('options', { editor: state.editor, kind, field: field.id, query: Format.query(query), page: page || 1 });
    if (!result.ok) return result;
    const items = list(result.data.items).filter((i) => i && typeof i.value === 'string').map(cleanItem);
    for (const item of items) state.labels.set(labelKey(field, item.value, kind), item);
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
    entry.placer = mode === 'entry' ? placer(entry, data) : null;
    entry.form = Form.build(kind, values, {
      between: entry.placer && entry.placer.el,
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
      descriptor: state.descriptor, kind, layout, title, state: tag, line: str(data && data.state && data.state.line), stale: entry.stale,
      form: entry.form, compare, footer, readOnly: Lifecycle.readOnly(data, mode === 'version'), backLabel: mode === 'version' ? STRINGS.history.title : '',
    }, { back, run });
    entry.snapshot = entry.form.snapshot();
    state.entry = entry;
    mount('entry', entry.view, layout);
    steps(entry);
    entry.form.focusFirst();
    loadChildren(entry);
  }

  async function openEntry(editor, kindId, id) {
    if (!(await useEditor(editor, kindId))) return false;
    const kind = state.kind;
    let data = null;
    if (id) {
      const result = await Bridge.post('read', { editor, kind: kind.id, id });
      if (!result.ok) { refused(result, editor); return false; }
      data = result.data;
    }
    showEntry(editor, kind, id || '', data, 'entry');
    return true;
  }

  // Placement (T-102) : blocs de la fiche, visée demandée au jeu, enfants

  function placer(entry, data) {
    const kind = entry.kind;
    if (!Placing.placeable(kind)) return null;
    const child = Placing.childOf(state.descriptor, kind);
    const childKind = child ? child.id : kind.id;
    return Placing.build({ key: entry.editor, kind, child, place: data && data.place, distance: data && data.distance }, {
      start: (mode) => work('place', (e) => startPlacing(e, mode)),
      go: (row, at) => goTo(row.title, at),
      remove: (row, how) => work('remove', (e) => removeChild(e, child, row, how)),
      open: (row) => openChild(entry, row),
      changed: () => {
        if (state.placing.on && state.placing.mode === 'children') Bridge.post('templateChanged', { values: entry.placer.template(), ghost: entry.placer.ghost(), label: entry.placer.label() });
      },
      lookup: (field, query, page) => lookup(field, query, page, childKind),
      known: (field, value) => state.labels.get(labelKey(field, value, childKind)) || null,
      remember: (field, item) => state.labels.set(labelKey(field, item.value, childKind), cleanItem(item)),
    });
  }

  function steps(entry) {
    if (entry.placer) entry.view.setSteps(Placing.stepStates(list(entry.kind.steps).length, entry.placer.progress()));
  }

  /** Lieux de la fiche, de son parent et de ses enfants (le jeu garde la réponse pour la visée). */
  async function loadChildren(entry, force) {
    if (!entry.placer || !entry.id || !(force || entry.kind.parent || Placing.childOf(state.descriptor, entry.kind))) return;
    const result = await Bridge.post('children', { editor: entry.editor, kind: entry.kind.id, id: entry.id });
    if (state.entry !== entry) return;
    if (!result.ok) { entry.placer.failed(errorText(result.error, result.text)); return; }
    const self = result.data.self;
    if (self && typeof self === 'object') entry.placer.setPlace(self.place, typeof self.distance === 'number' ? self.distance : undefined);
    entry.placer.setRows(result.data.rows);
    steps(entry);
  }

  /** Fantôme de la fiche elle-même : la valeur de son champ `ghost.field`. */
  function selfGhost(entry) {
    const field = list((entry.kind.form || {}).fields).find((f) => f && entry.kind.ghost && f.id === entry.kind.ghost.field);
    if (!field) return null;
    const value = flatten(entry.form.packet())[field.id];
    return Placing.ghostOf(entry.kind, value, list(field.choices).find((o) => o && o.value === value) || state.labels.get(labelKey(field, value)));
  }

  async function startPlacing(entry, mode) {
    if (state.placing.on || !(await saved(entry))) return;   // fiche nouvelle ou modifiée : enregistrée d'abord
    const p = entry.placer;
    state.lastMode = mode;
    p.message(mode, '');
    const result = await Bridge.post('placeStart', Placing.startPayload({
      editor: entry.editor, kind: entry.kind, child: Placing.childOf(state.descriptor, entry.kind), id: entry.id, rev: entry.rev, mode,
      title: entry.form.title() || entry.title, template: p.template(), label: p.label(), ghost: mode === 'children' ? p.ghost() : selfGhost(entry),
    }));
    if (state.entry === entry && !result.ok) p.message(mode, errorText(result.error, result.text));
  }

  async function goTo(title, at) {
    const result = await Bridge.post('goTo', { x: at.x, y: at.y });
    Toast.show(result.ok ? STRINGS.place.marked(title) : errorText(result.error, result.text), result.ok ? 'success' : 'error');
  }

  /** Corbeille d'une ligne : brouillon jamais publié abandonné (révision relue), ou retrait préparé (T-101). */
  async function removeChild(entry, child, row, how) {
    const at = { editor: entry.editor, kind: row.kind, id: row.id };
    let result;
    if (how === 'discard') {
      if (!(await Confirm.ask(STRINGS.confirm.discard))) return;
      const read = await Bridge.post('read', at);
      result = read.ok ? await Bridge.post('discard', { ...at, rev: int(read.data.rev) }) : read;
    } else {
      if (!(await Confirm.ask(Lifecycle.confirmRetire(child)))) return;
      result = await Bridge.post('retire', at);
    }
    if (state.entry !== entry) return;
    if (!result.ok) { refused(result, entry.editor); return; }
    if (result.data.done === false) { Toast.show(Lifecycle.errorLines(result.data.errors, [])[0] || errorText('default'), 'error'); return; }
    if (result.data.gone === true) entry.placer.drop(row.id);
    await loadChildren(entry);
    if (state.entry !== entry || dirty(entry)) return;
    const fresh = await Bridge.post('read', keys(entry));   // pied et état de la fiche parent
    if (state.entry === entry && fresh.ok && !dirty(entry)) absorb(entry, fresh.data);
  }

  async function openChild(entry, row) {
    if (state.entry !== entry || !(await leave(entry))) return;
    if (await openEntry(entry.editor, row.kind, row.id)) state.entry.from = { kind: entry.kind.id, id: entry.id };
  }

  /** Retour d'une fiche enfant : sa fiche parent ; sinon la liste. */
  async function leaveTo(entry) {
    if (!(entry.from && await openEntry(entry.editor, entry.from.kind, entry.from.id)) && !app.hidden) showList();
  }

  let refreshTimer = 0;

  function onPlaced(p) {
    const entry = state.entry;
    if (!entry || !entry.placer || state.screen !== 'entry') return;
    const parent = p.parent && typeof p.parent === 'object' ? p.parent : null;
    const mine = state.placing.key === entryKey(entry) && state.placing.mode === 'children';
    if (str(p.kind) === entry.kind.id && str(p.id) === entry.id) {
      absorb(entry, p);
      entry.placer.setPlace(p.place, typeof p.distance === 'number' ? p.distance : null);
    } else if ((parent && str(parent.id) === entry.id) || mine) {
      if (parent && str(parent.id) === entry.id) absorb(entry, parent);
      entry.placer.upsert(p.row);
    } else return;
    entry.placer.message(state.lastMode, '');
    steps(entry);
  }

  function onUndone(p) {
    const entry = state.entry;
    if (!entry || !entry.placer || state.screen !== 'entry') return;
    if (str(p.kind) === entry.kind.id && str(p.id) === entry.id) {
      if (Number.isInteger(p.rev)) entry.rev = p.rev;
      if (p.place && typeof p.place === 'object') entry.placer.setPlace(p.place, null);
      else {
        clearTimeout(refreshTimer);   // lieu d'avant non fourni : relu une fois, après la dernière annulation
        refreshTimer = setTimeout(() => { if (state.entry === entry) loadChildren(entry, true); }, 800);
      }
    } else if (p.gone === true) entry.placer.drop(str(p.id));
    steps(entry);
  }

  function onSuspended(p) {
    state.suspended = p.on === true;
    const texts = (state.descriptor && state.descriptor.texts) || {};
    state.suspendedLine = str(p.line) || `${str(texts.trialLine) || STRINGS.place.trialLine} · ${STRINGS.place.back(state.closeKey)}`;
    if (state.suspended) { Picker.close(false); if (Confirm.isOpen()) Confirm.cancel(); }
    chrome();
  }

  async function reloadEntry(entry) {
    const done = await openEntry(entry.editor, entry.kind.id, entry.id);
    if (!done && !app.hidden && state.entry === entry) showList();
    return done;
  }

  async function leave(entry) {
    if (!entry || entry.mode !== 'entry' || !dirty(entry)) return true;
    return Confirm.ask(STRINGS.confirmLeave);
  }

  const keys = (entry) => ({ editor: entry.editor, kind: entry.kind.id, id: entry.id });

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
    if (!result.ok) { refused(result, entry.editor, entry); return false; }
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
    if (!result.ok) { refused(result, entry.editor); return; }
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
    if (!written(entry, result, STRINGS.invalid)) return;
    absorb(entry, result.data);
    if (state.descriptor && state.descriptor.trialPlay === true) Bridge.post('suspend');   // l'essai se joue en jeu (§ 8.4)
  }

  async function endTrial(entry) {
    const result = await Bridge.post('endTrial', keys(entry));
    if (written(entry, result)) absorb(entry, result.data);
  }

  /** Résumé, boîte, puis envoi avec le jeton lu ; null si « Rester ». Résumé à corriger : réponse `done = false`. */
  async function confirmed(at, what, ref, box, alive) {
    const preview = await Bridge.post('preview', { ...at, what, ref });
    if (!alive()) return null;
    if (!preview.ok) return preview;
    const p = preview.data;
    const go = await Confirm.ask(Lifecycle.confirmOf(what, p, box));
    if (p.valid !== true) return { ok: true, data: { done: false, errors: p.errors, shown: true } };
    if (!go || !alive()) return null;
    return Bridge.post(what, { ...at, [what === 'publish' ? 'rev' : 'version']: ref, token: str(p.token) });
  }

  async function publish(entry) {
    if (!(await saved(entry))) return;
    const removal = entry.tone === 'removal', texts = state.descriptor.texts || {};
    const result = await confirmed(keys(entry), 'publish', entry.rev, {
      label: Lifecycle.label(entry.footer, 'publish', str(texts.publish)), removal, publishHint: str(texts.publishHint), fields: (entry.kind.form || {}).fields,
    }, () => state.entry === entry);
    if (!result || !written(entry, result)) return;
    if (removal) { Toast.show(STRINGS.removalDone, 'success'); leaveTo(entry); return; }
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
    if (result.ok && result.data.gone === true) leaveTo(entry);
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

  function loadHistory(reset) {
    const { view } = state.history, h = state.history;
    fetchPage(h, 'history', { editor: h.editor, kind: h.kind.id, id: h.id, before: reset ? 0 : view.oldest() }, view, (data) => view.add(data, reset));
  }

  async function openVersion(version) {
    const history = state.history;
    const result = await Bridge.post('version', { editor: history.editor, kind: history.kind.id, id: history.id, version });
    if (state.history !== history || state.screen !== 'history') return;
    if (!result.ok) { refused(result, history.editor); return; }
    showEntry(history.editor, history.kind, history.id, result.data, 'version');
    state.entry.version = int(result.data.version) || version;
  }

  async function restoreVersion(version) {
    const history = state.history;
    if (!history || !version) return;
    const at = { editor: history.editor, kind: history.kind.id, id: history.id };
    const result = await confirmed(at, 'restore', version, { version, fields: (history.kind.form || {}).fields }, () => state.history === history);
    if (!result || state.history !== history || result.data && result.data.shown) return;
    if (!result.ok) { refused(result, at.editor); return; }
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

  function loadJournal(reset) {
    const journal = state.journal, view = state.view;
    fetchPage(journal, 'journal', { before: reset ? 0 : journal.next, editor: journal.filter }, view, (data) => {
      journal.next = Number.isInteger(data.next) ? data.next : 0;
      view.add(data, reset);
    });
  }

  // Navigation et fermeture

  async function back() {
    const { screen, entry, history } = state;
    if (screen === 'entry' && entry.mode === 'version' && history) {
      mount('history', history.view, history.layout);
      history.view.focus();
    } else if (screen === 'entry') {
      if (await leave(entry)) leaveTo(entry);
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
    if (app.hidden || state.placing.on || state.suspended) return;   // le jeu a la main (visée, essai joué)
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
    Object.assign(state, { banner: undefined, keys: [], placing: { on: false, keys: [] }, suspended: false });
    app.hidden = false;
    renderHome();
  }

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
      if (!app.hidden) chrome();
    } else if (action === 'keys') {
      state.keys = list(payload.keys);
      if (!app.hidden) chrome();
    } else if (action === 'placing') {
      state.placing = payload.on === true ? { on: true, mode: str(payload.mode), shape: str(payload.shape), keys: list(payload.keys), key: entryKey(state.entry) } : { on: false, keys: [] };
      if (!app.hidden) chrome();
    } else if (action === 'placed') onPlaced(payload);
    else if (action === 'placeRefused') { if (state.entry && state.entry.placer && str(payload.text)) state.entry.placer.message(state.lastMode, payload.text); }
    else if (action === 'undone') onUndone(payload);
    else if (action === 'suspended') onSuspended(payload);
  });

  if (!Bridge.inGame) window.Atelier = { state, openEditor, openEntry, openJournal, openRemoved, openHistory, run, back, check: () => run('check') };
})();
