'use strict';
/*
 * vava_pause/web/js/app.js
 * Rôle : état de la bannière, messages du jeu (open, data, downed, refused, close, nav, codexClosed, native), rappels
 *        NUI (ready, close, rubric, codex, map, gameSettings, keyBindings, sheet, setting, resetSettings, council,
 *        leave), déroulé et repli (classes CSS, une minuterie unique au repli, aucune boucle). Ce que le jeu envoie est
 *        relu par PauseModel avant d'être gardé ; le brouillon du message au Conseil reste dans la page jusqu'à
 *        l'envoi.
 * Dépendances : strings.js, bridge.js, model.js, views.js, nav.js
 */

(() => {
  const S = STRINGS;
  const M = PauseModel;
  const app = document.getElementById('app');
  const refs = PauseViews.init(app);
  const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
  const bool = (value) => value === true;

  const state = {
    downed: false, rubric: 'personnage', previous: 'personnage', tab: 'interface', expanded: false, dialog: false,
    leaving: false, gamepad: false, closeKey: 'Échap',
    local: {}, data: null, dataStatus: 'loading', guild: null, royal: null, rankInks: null,
    settings: { defs: [], values: {} }, settingsNote: '', keyLabels: {},
    resources: { codex: true, sheet: true, voice: true, council: true },
    codex: 'idle', codexEnded: false,
    council: { kind: 'question', text: '', withPosition: true, sending: false, error: '', request: null },
    councilOpen: true,
  };
  let foldTimer = null;
  let noteTimer = null;
  let foldMs = 180;

  // Rendu ------------------------------------------------------------------------------------------------

  function councilOpen() {
    return state.resources.council !== false && !(state.data && state.data.council === false) && !state.councilDown;
  }

  function renderPanel() {
    state.councilOpen = councilOpen();
    PauseNav.keep(() => {
      PauseViews.renderNav(state);
      PauseViews.renderPanel(state);
    });
  }

  function renderAll() {
    state.councilOpen = councilOpen();
    PauseNav.keep(() => {
      PauseViews.renderBanner(state);
      PauseViews.renderPanel(state);
      PauseViews.renderPlaque(state);
      PauseViews.renderDialog(state);
    });
  }

  function applyScale() {
    const def = state.settings.defs.find((entry) => entry.key === 'ui.scale');
    const value = def ? M.settingValue(def, state.settings.values) : 100;
    document.documentElement.style.setProperty('--scale', String(M.scale(value)));
  }

  // Déroulé et repli ---------------------------------------------------------------------------------------

  function setMotion(ms) {
    const roll = M.rollMs(ms);
    app.classList.toggle('no-motion', roll === 0);
    app.style.setProperty('--roll', `${roll}ms`);
    app.style.setProperty('--panel', `${Math.round(roll * 0.8)}ms`);
    app.style.setProperty('--panel-delay', `${Math.round(roll * 0.32)}ms`);
    foldMs = Math.min(180, roll);
    app.style.setProperty('--fold', `${foldMs}ms`);
  }

  function show() {
    clearTimeout(foldTimer);
    app.classList.remove('is-open', 'is-closing', 'is-native', 'is-codex');
    app.hidden = false;
    void app.offsetWidth;   // état de départ appliqué avant que la transition ne parte
    app.classList.add('is-open');
  }

  function fold() {
    if (app.hidden) return;
    clearTimeout(foldTimer);
    app.classList.add('is-closing');
    app.classList.remove('is-open');
    PauseViews.status('');
    const done = () => {
      app.hidden = true;
      app.classList.remove('is-closing', 'is-codex', 'is-native');
      state.dialog = false;
      state.leaving = false;
      PauseViews.renderDialog(state);
    };
    if (foldMs > 0) foldTimer = setTimeout(done, foldMs);
    else done();
  }

  function close() {
    fold();
    Bridge.post('close');
  }

  // Données reçues -----------------------------------------------------------------------------------------

  function readLocal(raw) {
    const local = isObject(raw) ? raw : {};
    const voice = isObject(local.voice) ? local.voice : null;
    return {
      name: typeof local.name === 'string' ? local.name.slice(0, 64) : '',
      health: local.health, hunger: local.hunger, thirst: local.thirst,
      plaque: isObject(local.plaque) ? local.plaque : {},
      voice: voice && typeof voice.label === 'string' ? { label: voice.label, distance: voice.distance } : null,
    };
  }

  function applyData(raw) {
    if (raw === false || (isObject(raw) && raw.unavailable === true)) {
      if (state.dataStatus !== 'ready') state.dataStatus = 'failed';
      return;
    }
    if (!isObject(raw)) return;
    const keys = Array.isArray(raw.keys) ? raw.keys : state.data && Array.isArray(state.data.keys) ? state.data.keys : null;
    state.data = { skills: M.skills(raw.skills), keys, people: raw.people, plaque: raw.plaque, council: raw.council };
    state.guild = M.guild(raw.guild);
    state.council.request = isObject(raw.request) ? raw.request : null;
    state.dataStatus = 'ready';
    if (typeof raw.downed === 'boolean') setDowned(raw.downed);
  }

  function setDowned(downed) {
    if (state.downed === downed) return;
    state.downed = downed;
    if (downed) {
      state.rubric = null;
      state.codex = 'idle';
    } else if (!state.rubric) state.rubric = M.startRubric(state.previous, false);
  }

  function open(payload) {
    state.downed = bool(payload.downed);
    state.local = readLocal(payload.local);
    state.data = null;
    state.guild = null;
    state.dataStatus = 'loading';
    state.royal = isObject(payload.royal) ? payload.royal : null;
    state.rankInks = isObject(payload.rankInks) ? payload.rankInks : null;
    const settings = isObject(payload.settings) ? payload.settings : {};
    state.settings = { defs: M.settingDefs(settings.defs), values: isObject(settings.values) ? { ...settings.values } : {} };
    state.settingsNote = '';
    state.keyLabels = isObject(payload.keyLabels) ? payload.keyLabels : {};
    const resources = isObject(payload.resources) ? payload.resources : {};
    for (const name of ['codex', 'sheet', 'voice', 'council']) state.resources[name] = resources[name] !== false;
    state.closeKey = typeof payload.closeKey === 'string' && payload.closeKey ? payload.closeKey.slice(0, 16) : 'Échap';
    state.gamepad = bool(payload.gamepad);
    state.rubric = M.startRubric(payload.rubric, state.downed);
    if (state.rubric) state.previous = state.rubric;
    state.codex = 'idle';
    state.expanded = false;
    state.dialog = false;
    state.leaving = false;
    state.councilDown = false;
    state.council.sending = false;
    state.council.error = '';
    if (payload.data !== undefined && payload.data !== null) applyData(payload.data);
    setMotion(payload.rollMs);
    applyScale();
    show();
    renderAll();
    PauseNav.toRubrics(state.rubric || 'reprendre');
  }

  // Actions de la page ------------------------------------------------------------------------------------

  function select(id) {
    if (!M.PANELS.includes(id) || state.downed) return;
    if (state.rubric !== id) {
      state.rubric = id;
      state.previous = id;
      state.expanded = false;
      state.council.error = '';
      Bridge.post('rubric', { id });
    }
    renderPanel();
  }

  async function openCodex() {
    if (state.downed) return;
    state.rubric = 'codex';
    state.codexEnded = false;
    if (!state.resources.codex) {
      state.codex = 'closed';
      renderPanel();
      return;
    }
    state.codex = 'opening';
    renderPanel();
    Bridge.post('rubric', { id: 'codex' });
    const result = await Bridge.post('codex');
    if (state.rubric !== 'codex' || state.codex !== 'opening') return;
    if (result.ok && !state.codexEnded) state.codex = 'docked';
    else if (result.ok) {
      backFromCodex(state.previous);
      return;
    } else state.codex = 'closed';
    renderPanel();
    if (state.codex === 'closed') PauseNav.toRubrics('codex');
  }

  function backFromCodex(rubric) {
    state.codex = 'idle';
    state.rubric = M.PANELS.includes(rubric) ? rubric : state.previous;
    app.classList.remove('is-codex');
    renderPanel();
    PauseNav.toRubrics(state.rubric);
  }

  async function plain(name) {
    const result = await Bridge.post(name);
    if (!result.ok) PauseViews.status(S.errors.default);
  }

  function openDialog() {
    state.dialog = true;
    state.leaving = false;
    renderAll();
    const stay = refs.dialog.querySelector('[data-act="stay"]');
    if (stay) stay.focus();
  }

  function stay() {
    state.dialog = false;
    renderAll();
    PauseNav.toRubrics('quitter');
  }

  async function leave(mode) {
    if (state.leaving || (mode !== 'disconnect' && mode !== 'quit')) return;
    state.leaving = true;
    PauseViews.renderDialog(state);
    const result = await Bridge.post('leave', { mode });
    if (!result.ok) {
      state.leaving = false;
      PauseViews.renderDialog(state);
      const stayButton = refs.dialog.querySelector('[data-act="stay"]');
      if (stayButton) stayButton.focus();
      PauseViews.status(S.errors.default);
    }
  }

  /** Entrée de la bannière choisie ; `enter` (clavier, manette) : le focus passe dans le panneau. */
  function activate(id, enter) {
    if (id === 'reprendre') close();
    else if (id === 'codex') openCodex();
    else if (id === 'parametres') plain('gameSettings');
    else if (id === 'quitter') openDialog();
    else if (M.PANELS.includes(id)) {
      select(id);
      if (enter) PauseNav.enterPanel();
    }
  }

  function note(message) {
    clearTimeout(noteTimer);
    state.settingsNote = message;
    if (message) noteTimer = setTimeout(() => { state.settingsNote = ''; if (state.rubric === 'reglages') renderPanel(); }, 3000);
  }

  async function changeSetting(key, index) {
    const def = state.settings.defs.find((entry) => entry.key === key);
    if (!def) return;
    const before = M.settingValue(def, state.settings.values);
    const value = def.kind === 'lever' ? !before : def.choices[Number(index)];
    if (value === undefined || value === before) return;
    state.settings.values[key] = value;
    if (key === 'ui.scale') applyScale();
    renderPanel();
    const result = await Bridge.post('setting', { key, value });
    if (result.ok) {
      if (result.value !== undefined && (def.kind === 'lever' ? typeof result.value === 'boolean' : def.choices.includes(result.value))) {
        state.settings.values[key] = result.value;
      }
    } else {
      state.settings.values[key] = before;
      note(S.reglages.refused);
    }
    if (key === 'ui.scale') applyScale();
    if (state.rubric === 'reglages') renderPanel();
  }

  async function resetSettings() {
    const result = await Bridge.post('resetSettings');
    if (result.ok && isObject(result.values)) state.settings.values = { ...result.values };
    else if (result.ok) state.settings.values = {};
    else note(S.reglages.refused);
    applyScale();
    if (state.rubric === 'reglages') renderPanel();
  }

  function switchTab(next) {
    if (state.rubric !== 'reglages') return;
    const index = M.TABS.indexOf(state.tab);
    const tab = typeof next === 'number' ? M.TABS[(index + next + M.TABS.length) % M.TABS.length] : next;
    if (!M.TABS.includes(tab) || tab === state.tab) return;
    const fromRibbon = document.activeElement && document.activeElement.classList.contains('ribbon');
    state.tab = tab;
    renderPanel();
    if (fromRibbon) {
      const ribbon = refs.leaf.querySelector(`.ribbon[data-tab="${tab}"]`);
      if (ribbon) ribbon.focus();
    }
  }

  async function send() {
    const council = state.council;
    if (council.sending || !state.councilOpen) return;
    const check = M.councilCheck(council.kind, council.text);
    if (check) {
      council.error = M.councilError(check);
      renderPanel();
      return;
    }
    council.sending = true;
    council.error = '';
    renderPanel();
    const result = await Bridge.post('council', {
      kind: council.kind, text: council.text, withPosition: M.positionForced(council.kind) || council.withPosition,
    });
    council.sending = false;
    if (result.ok) {
      council.request = isObject(result.request) ? result.request : { state: 'sent', age: 0 };
      council.text = '';
    } else {
      council.error = M.councilError(result.error, result.wait);
      if (result.error === 'council_unavailable') state.councilDown = true;
    }
    if (state.rubric === 'conseil') renderPanel();
  }

  const handlers = {
    close, stay, entry: (node) => activate(node.dataset.id, false), sheet: () => plain('sheet'), map: () => plain('map'),
    gameSettings: () => plain('gameSettings'), keyBindings: () => plain('keyBindings'),
    expand: () => { state.expanded = !state.expanded; renderPanel(); },
    setting: (node) => changeSetting(node.dataset.key, node.dataset.index), reset: resetSettings,
    tab: (node) => switchTab(node.dataset.tab),
    kind: (node) => { if (M.KINDS.includes(node.dataset.kind)) { state.council.kind = node.dataset.kind; state.council.error = ''; renderPanel(); } },
    position: () => { state.council.withPosition = !state.council.withPosition; renderPanel(); },
    send, leave: (node) => leave(node.dataset.mode),
  };

  app.addEventListener('click', (event) => {
    const node = event.target.closest('[data-act]');
    if (!node || node.disabled || !app.contains(node)) return;
    const handler = handlers[node.dataset.act];
    if (handler) handler(node);
  });

  app.addEventListener('input', (event) => {
    const area = event.target;
    if (area.dataset.ref !== 'text') return;
    if (M.bytes(area.value) > M.MAX_TEXT) area.value = M.clipBytes(area.value, M.MAX_TEXT);
    state.council.text = area.value;
    PauseViews.updateCount(state);
  });

  PauseNav.init({
    app, refs, isDialog: () => state.dialog,
    actions: {
      close, stay, activate, tab: switchTab,
      preview: (id) => { if (M.PANELS.includes(id) && state.codex !== 'opening') select(id); },
      gamepad: (on) => {
        if (state.gamepad === on) return;
        state.gamepad = on;
        refs.foot.textContent = on ? S.footGamepad : S.foot(state.closeKey);
      },
    },
  });

  // Messages du jeu ---------------------------------------------------------------------------------------

  Bridge.onMessage((action, payload) => {
    if (action === 'open') open(payload);
    else if (action === 'data') {
      applyData(payload);
      if (!app.hidden) renderAll();
    } else if (action === 'downed') {
      setDowned(bool(payload.downed));
      if (!app.hidden) {
        renderAll();
        if (!app.contains(document.activeElement)) PauseNav.toRubrics(state.rubric || 'reprendre');
      }
    } else if (action === 'refused' || action === 'close') fold();
    else if (action === 'nav') {
      if (typeof payload.dir === 'string') PauseNav.dir(payload.dir);
    } else if (action === 'codexClosed') {
      if (state.codex === 'opening') state.codexEnded = true;
      else if (state.codex === 'docked') backFromCodex(payload.rubric);
    } else if (action === 'native') {
      app.classList.toggle('is-native', bool(payload.hidden));
      if (!payload.hidden && !app.hidden) PauseNav.toRubrics(state.rubric || 'reprendre');
    }
  });

  Bridge.post('ready');
})();
