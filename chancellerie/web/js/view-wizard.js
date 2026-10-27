'use strict';
/*
 * web/js/view-wizard.js
 * Rôle : l'assistant de configuration, en six étapes : dossiers (serveur et FXServer.exe), identité, licence et
 *        moteur, base de données, ressources, sceau (relecture puis écriture du server.cfg et lancement). Les
 *        secrets déjà renseignés ne reviennent jamais : un champ laissé vide garde la valeur en place.
 */

const WizardView = (() => {
  const W = STRINGS.wizard;
  const STEP_OF_FIELD = {
    serverDataPath: 0, fxserverPath: 0, hostname: 1, projectName: 1, projectDesc: 1, maxClients: 1,
    licenseKey: 2, bind: 2, port: 2, onesync: 2, 'db.host': 3, 'db.port': 3, 'db.user': 3, 'db.password': 3, 'db.database': 3,
    resources: 4, extra: 4,
  };
  const LAST_STEP = W.steps.length - 1;

  let sheet = null;
  let view = null;
  let form = null;
  let step = 0;
  let inputs = {};
  let canStart = false;
  let onFinish = () => {};
  let pendingError = null;

  function formFromView(source) {
    const cfg = source.cfg || {};
    const db = cfg.db || {};
    return {
      serverDataPath: source.paths.serverDataPath || '', fxserverPath: source.paths.fxserverPath || '',
      hostname: cfg.hostname || '', projectName: cfg.projectName || '', projectDesc: cfg.projectDesc || '',
      maxClients: cfg.maxClients || 48, listed: cfg.listed !== false, licenseKey: '', bind: cfg.bind || '0.0.0.0',
      port: cfg.port || 30120, onesync: cfg.onesync || 'on', endpointPrivacy: cfg.endpointPrivacy !== false,
      db: { host: db.host || '127.0.0.1', port: db.port || 3306, user: db.user || 'root', database: db.database || '', password: '' },
      resources: [...(cfg.resources || [])], extra: cfg.extra || '',
    };
  }

  /** Ordre de démarrage, comme le fera la Chancellerie : vAvA d'abord, dans son ordre, puis le reste. */
  function ordered(names) {
    const known = view.knownOrder || [];
    const rank = (name) => (known.indexOf(name) === -1 ? known.length : known.indexOf(name));
    return names.map((name, index) => ({ name, index })).sort((a, b) => rank(a.name) - rank(b.name) || a.index - b.index).map((e) => e.name);
  }

  const integer = (value) => Math.floor(Number(value));

  /** Recopie les champs de l'étape affichée dans le formulaire. */
  function collect() {
    const read = (name) => (inputs[name] ? inputs[name].value : undefined);
    const checked = (name) => (inputs[name] ? inputs[name].checked : undefined);
    if (step === 0) {
      form.serverDataPath = read('serverDataPath').trim();
      form.fxserverPath = read('fxserverPath').trim();
    } else if (step === 1) {
      form.hostname = read('hostname');
      form.projectName = read('projectName');
      form.projectDesc = read('projectDesc');
      form.maxClients = integer(read('maxClients'));
      form.listed = checked('listed');
    } else if (step === 2) {
      form.licenseKey = read('licenseKey').trim();
      form.bind = read('bind').trim();
      form.port = integer(read('port'));
      form.onesync = read('onesync');
      form.endpointPrivacy = checked('endpointPrivacy');
    } else if (step === 3) {
      form.db = {
        host: read('db.host').trim(), port: integer(read('db.port')), user: read('db.user').trim(),
        database: read('db.database').trim(), password: read('db.password'),
      };
    } else if (step === 4) {
      form.extra = read('extra');
    }
  }

  function addField(container, def) {
    const made = UI.field(def);
    inputs[def.name] = made.input;
    container.append(made.node);
    return made.input;
  }

  function addChoice(container, name, label, checked, help) {
    const made = UI.choice(label, checked, help);
    inputs[name] = made.input;
    made.node.classList.add('is-wide');
    container.append(made.node);
  }

  function renderPaths(body) {
    body.append(UI.el('p', 'prose', W.pathsIntro));
    const grid = UI.el('div', 'form-grid');
    const locked = view.running && view.paths.saved;
    addField(grid, { name: 'serverDataPath', label: W.serverDataPath, value: form.serverDataPath, help: W.serverDataPathHelp, wide: true, max: 400 }).disabled = locked;
    addField(grid, { name: 'fxserverPath', label: W.fxserverPath, value: form.fxserverPath, help: W.fxserverPathHelp, wide: true, max: 400 }).disabled = locked;
    body.append(grid);
    if (locked) body.append(UI.el('p', 'hint', W.pathsRunning));
    else if (view.paths.saved) body.append(UI.el('p', 'hint', view.cfgExists ? W.cfgFound : W.cfgNew));
  }

  function renderIdentity(body) {
    body.append(UI.el('p', 'prose', W.identityIntro));
    const grid = UI.el('div', 'form-grid');
    addField(grid, { name: 'hostname', label: W.hostname, value: form.hostname, max: 80, wide: true });
    addField(grid, { name: 'projectName', label: W.projectName, value: form.projectName, max: 80, help: W.projectNameHelp });
    addField(grid, { name: 'maxClients', label: W.maxClients, type: 'number', min: 1, max: 2048, value: form.maxClients, help: W.maxClientsHelp });
    addField(grid, { name: 'projectDesc', label: W.projectDesc, value: form.projectDesc, max: 200, wide: true });
    addChoice(grid, 'listed', W.listed, form.listed, W.listedHelp);
    body.append(grid);
  }

  function renderLicense(body) {
    body.append(UI.el('p', 'prose', W.licenseIntro));
    const grid = UI.el('div', 'form-grid');
    addField(grid, {
      name: 'licenseKey', label: W.licenseKey, type: 'password', value: form.licenseKey, max: 210, wide: true, autocomplete: 'off',
      placeholder: W.licenseKeyPlaceholder, help: view.hasLicenseKey ? W.licenseKeySet : null,
    });
    addField(grid, { name: 'bind', label: W.bind, value: form.bind, max: 15, help: W.bindHelp });
    addField(grid, { name: 'port', label: W.port, type: 'number', min: 1024, max: 65535, value: form.port, help: W.portHelp });
    const onesync = addField(grid, { name: 'onesync', label: W.onesync, type: 'select', options: W.onesyncOptions });
    onesync.value = form.onesync;
    addChoice(grid, 'endpointPrivacy', W.endpointPrivacy, form.endpointPrivacy);
    body.append(grid);
  }

  function renderDatabase(body) {
    body.append(UI.el('p', 'prose', W.dbIntro));
    const grid = UI.el('div', 'form-grid');
    addField(grid, { name: 'db.host', label: W.dbHost, value: form.db.host, max: 253 });
    addField(grid, { name: 'db.port', label: W.dbPort, type: 'number', min: 1, max: 65535, value: form.db.port });
    addField(grid, { name: 'db.user', label: W.dbUser, value: form.db.user, max: 64, autocomplete: 'off' });
    addField(grid, {
      name: 'db.password', label: W.dbPassword, type: 'password', value: form.db.password, max: 200, autocomplete: 'new-password',
      help: view.hasDbPassword ? W.dbPasswordSet : null,
    });
    addField(grid, { name: 'db.database', label: W.dbDatabase, value: form.db.database, max: 64 });
    body.append(grid);
    const result = UI.el('span', 'probe-result');
    const probe = UI.button(W.dbCheck, async () => {
      probe.disabled = true;
      result.className = 'probe-result';
      result.textContent = W.dbChecking;
      const answer = await API.post('/api/assistant/dbcheck', { host: inputs['db.host'].value.trim(), port: integer(inputs['db.port'].value) });
      probe.disabled = false;
      result.className = `probe-result ${answer.ok ? 'is-good' : 'is-bad'}`;
      result.textContent = answer.ok ? W.dbAnswer(answer.version) : STRINGS.error(answer.error);
    });
    body.append(UI.el('div', 'probe', null, [probe, result]));
  }

  function renderResources(body) {
    body.append(UI.el('p', 'prose', W.resourcesIntro));
    if (!view.resources.length) body.append(UI.el('p', 'empty', W.resourcesEmpty));
    const selected = new Set(form.resources);
    const groups = new Map();
    // dans chaque catégorie, celles de vAvA dans leur ordre de démarrage, puis les autres par nom
    const known = view.knownOrder || [];
    const rank = (name) => (known.includes(name) ? known.indexOf(name) : known.length);
    const sorted = [...view.resources].sort((a, b) => rank(a.name) - rank(b.name) || a.name.localeCompare(b.name));
    for (const resource of sorted) {
      const key = resource.missing ? W.resourceMissing : resource.category || W.uncategorized;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(resource);
    }
    const list = UI.el('div', 'resource-list');
    for (const [group, items] of groups) {
      list.append(UI.el('p', 'resource-group', group));
      for (const resource of items) {
        const made = UI.choice('', selected.has(resource.name), resource.description || null);
        made.node.querySelector('.choice-label').append(UI.el('span', 'resource-name', resource.name));
        made.input.addEventListener('change', () => {
          if (made.input.checked && !form.resources.includes(resource.name)) form.resources.push(resource.name);
          if (!made.input.checked) form.resources = form.resources.filter((name) => name !== resource.name);
        });
        list.append(UI.el('div', `resource${resource.missing ? ' is-missing' : ''}`, null, [made.node]));
      }
    }
    body.append(list);
    const grid = UI.el('div', 'form-grid');
    addField(grid, { name: 'extra', label: W.extra, type: 'textarea', value: form.extra, max: 20000, help: W.extraHelp, wide: true });
    body.append(grid);
  }

  function renderSummary(body) {
    body.append(UI.el('p', 'prose', W.summaryIntro));
    const T = W.summary;
    const order = ordered(form.resources);
    const rows = [
      [T.folder, form.serverDataPath], [T.executable, form.fxserverPath], [T.hostname, form.hostname],
      [T.slots, String(form.maxClients)], [T.listing, form.listed ? W.listedYes : W.listedNo], [T.endpoint, `${form.bind}:${form.port}`],
      [T.onesync, W.onesyncOptions[form.onesync]], [T.license, form.licenseKey || view.hasLicenseKey ? W.licenseYes : W.licenseNo],
      [T.database, `${form.db.user}@${form.db.host}:${form.db.port}/${form.db.database}`],
      [T.password, form.db.password || view.hasDbPassword ? W.passwordYes : W.passwordNo],
    ];
    const summary = UI.el('dl', 'summary');
    for (const [label, value] of rows) summary.append(UI.el('dt', null, label), UI.el('dd', null, value));
    summary.append(UI.el('dt', null, T.resources), UI.el('dd', null, null, [
      UI.el('span', 'cell-sub', W.summaryResources(order.length)),
      UI.el('ol', 'order', null, order.map((name) => UI.el('li', null, name))),
    ]));
    body.append(summary);
  }

  const RENDERERS = [renderPaths, renderIdentity, renderLicense, renderDatabase, renderResources, renderSummary];

  function steps() {
    return UI.el('ol', 'steps', null, W.steps.map((label, index) => {
      const node = UI.el('li', `step${index < step ? ' is-done' : ''}${index === step ? ' is-current' : ''}`, label);
      if (index === step) node.setAttribute('aria-current', 'step');
      return node;
    }));
  }

  function render() {
    inputs = {};
    const body = UI.el('div', 'wizard-body');
    RENDERERS[step](body);
    const error = UI.el('p', 'wizard-error', null);
    error.hidden = true;
    const previous = step > 0 ? UI.button(W.previous, () => move(-1)) : null;
    let next;
    if (step < LAST_STEP) {
      next = UI.button(W.next, () => move(1), 'seal');
    } else {
      const launch = canStart && !view.running;
      next = UI.button(launch ? W.seal : W.sealOnly, () => seal(launch), launch ? 'green' : 'seal');
    }
    sheet.replaceChildren(UI.heading(W.title), steps(), body, error, UI.el('div', 'wizard-actions', null, [previous, UI.el('span', 'spacer'), next]));
    if (pendingError) {
      showError(pendingError);
      pendingError = null;
    }
    const first = body.querySelector('input:not([disabled]), select, textarea');
    if (first && !first.classList.contains('is-invalid')) first.focus();
  }

  function showError({ error, field }) {
    const node = sheet.querySelector('.wizard-error');
    node.textContent = STRINGS.error(error, field);
    node.hidden = false;
    if (field && inputs[field]) {
      inputs[field].classList.add('is-invalid');
      inputs[field].focus();
    }
  }

  function setBusy(busy, label) {
    for (const node of sheet.querySelectorAll('.wizard-actions button')) node.disabled = busy;
    if (busy && label) sheet.querySelector('.wizard-actions .seal-button').textContent = label;
  }

  /** Change d'étape ; quitter la première enregistre les dossiers et relit le serveur choisi. */
  async function move(delta) {
    collect();
    if (step === 0 && delta > 0 && !(view.running && view.paths.saved)) {
      setBusy(true, W.checking);
      const result = await API.post('/api/assistant/paths', { serverDataPath: form.serverDataPath, fxserverPath: form.fxserverPath });
      if (!result.ok) {
        setBusy(false);
        render();
        showError(result);
        return;
      }
      const changed = result.paths.serverDataPath !== view.paths.serverDataPath || !view.paths.saved || !view.cfg;
      view = result;
      if (changed) form = formFromView(result);
    }
    step = Math.min(LAST_STEP, Math.max(0, step + delta));
    render();
  }

  async function seal(launch) {
    collect();
    setBusy(true);
    const { serverDataPath, fxserverPath, ...payload } = form;
    const result = await API.post('/api/assistant/save', { form: payload, start: launch });
    if (!result.ok) {
      setBusy(false);
      if (result.field && STEP_OF_FIELD[result.field] !== undefined && STEP_OF_FIELD[result.field] !== step) {
        step = STEP_OF_FIELD[result.field];
        pendingError = result;
        render();
      } else {
        showError(result);
      }
      return;
    }
    UI.slip(result.restartNeeded ? W.savedRestart : W.saved);
    onFinish({ started: result.started });
  }

  return {
    /**
     * @param {HTMLElement} target
     * @param {{ canStart: boolean, onFinish: (result: { started: boolean }) => void }} options
     */
    async show(target, options) {
      sheet = target;
      canStart = options.canStart;
      onFinish = options.onFinish;
      sheet.replaceChildren(UI.heading(W.title));
      const result = await API.get('/api/assistant');
      if (!result.ok) {
        UI.report(result);
        return;
      }
      view = result;
      form = formFromView(result);
      step = 0;
      render();
    },
  };
})();
