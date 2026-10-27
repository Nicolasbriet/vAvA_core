'use strict';
/*
 * web/js/view-wizard.js
 * Rôle : l'assistant de configuration, en six étapes : installation (nouveau serveur : la Chancellerie installe
 *        FXServer, oxmysql et vAvA dans le dossier choisi ; serveur en place : ses dossiers, et vAvA posé ou complété
 *        dedans), identité, licence et moteur, base de données (vérifiée, et créée au besoin), ressources, sceau
 *        (relecture puis écriture du server.cfg et lancement). L'installation se suit en direct. Les secrets déjà
 *        renseignés ne reviennent jamais : un champ laissé vide garde la valeur en place.
 */

const WizardView = (() => {
  const W = STRINGS.wizard;
  const STEP_OF_FIELD = {
    serverDataPath: 0, fxserverPath: 0, base: 0, hostname: 1, projectName: 1, projectDesc: 1, maxClients: 1,
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
  // installation : mode choisi, ce que la Chancellerie propose d'installer, opération suivie
  let mode = null;
  let install = null;
  let job = null;

  function formFromView(source) {
    const cfg = source.cfg || {};
    const db = cfg.db || {};
    return {
      serverDataPath: source.paths.serverDataPath || '', fxserverPath: source.paths.fxserverPath || '',
      // vAvA proposé à l'installation tant qu'il n'est pas dans le dossier resources
      base: form && form.base ? form.base : '',
      installVava: form ? form.installVava : !(source.resources || []).some((r) => r.name === 'vAvA_core'),
      hostname: cfg.hostname || '', projectName: cfg.projectName || '', projectDesc: cfg.projectDesc || '',
      maxClients: cfg.maxClients || 48, listed: cfg.listed !== false, licenseKey: '', bind: cfg.bind || '0.0.0.0',
      port: cfg.port || 30120, onesync: cfg.onesync || 'on', endpointPrivacy: cfg.endpointPrivacy !== false,
      db: { host: db.host || '127.0.0.1', port: db.port || 3306, user: db.user || 'root', database: db.database || 'vava', password: '' },
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
  const installing = () => Boolean(job && job.kind === 'install' && job.status === 'running');

  /** Recopie les champs de l'étape affichée dans le formulaire. */
  function collect() {
    const read = (name) => (inputs[name] ? inputs[name].value : undefined);
    const checked = (name) => (inputs[name] ? inputs[name].checked : undefined);
    if (step === 0) {
      if (inputs.base) form.base = read('base').trim();
      if (inputs.serverDataPath) form.serverDataPath = read('serverDataPath').trim();
      if (inputs.fxserverPath) form.fxserverPath = read('fxserverPath').trim();
      if (inputs.installVava) form.installVava = checked('installVava');
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

  // Installation ------------------------------------------------------------------------------------------------------

  function modeChoice() {
    const node = UI.el('div', 'stamps install-modes');
    node.setAttribute('role', 'radiogroup');
    for (const id of ['new', 'existing']) {
      const stamp = UI.button(W.modes[id], () => {
        collect();
        mode = id;
        render();
      });
      stamp.className = `stamp${id === mode ? ' is-selected' : ''}`;
      stamp.setAttribute('role', 'radio');
      stamp.setAttribute('aria-checked', String(id === mode));
      stamp.disabled = installing() || (view.running && id === 'new');
      node.append(stamp);
    }
    return node;
  }

  function renderNew(body) {
    body.append(UI.el('p', 'prose', W.newIntro));
    const grid = UI.el('div', 'form-grid');
    addField(grid, { name: 'base', label: W.base, value: form.base || (install ? install.defaultBase : ''), help: W.baseHelp, wide: true, max: 300 }).disabled = installing();
    body.append(grid);
    const fx = install && install.recommended ? W.fxBuild(install.recommended.build) : W.fxUnknown;
    body.append(UI.el('div', 'install-list', null, [
      UI.el('span', 'field-label', W.willInstall),
      UI.el('ul', null, null, [UI.el('li', null, fx), UI.el('li', null, W.oxmysqlItem), UI.el('li', null, W.vavaItem(install ? install.repo : 'GitHub'))]),
    ]));
    body.append(UI.el('p', 'hint', W.mariadbHint));
  }

  function renderExisting(body) {
    body.append(UI.el('p', 'prose', W.pathsIntro));
    const grid = UI.el('div', 'form-grid');
    const locked = (view.running && view.paths.saved) || installing();
    addField(grid, { name: 'serverDataPath', label: W.serverDataPath, value: form.serverDataPath, help: W.serverDataPathHelp, wide: true, max: 400 }).disabled = locked;
    addField(grid, { name: 'fxserverPath', label: W.fxserverPath, value: form.fxserverPath, help: W.fxserverPathHelp, wide: true, max: 400 }).disabled = locked;
    if (!view.running) addChoice(grid, 'installVava', W.installExisting, form.installVava, W.installExistingHelp);
    body.append(grid);
    if (view.running && view.paths.saved) body.append(UI.el('p', 'hint', W.pathsRunning));
    else if (view.paths.saved) body.append(UI.el('p', 'hint', view.cfgExists ? W.cfgFound : W.cfgNew));
  }

  function renderPaths(body) {
    body.append(modeChoice());
    if (mode === 'new') renderNew(body);
    else renderExisting(body);
    const box = UI.el('div', 'install-job');
    if (job && job.kind === 'install') box.append(JOB.node(job));
    body.append(box);
  }

  async function startInstall(chosen) {
    setBusy(true, W.installing);
    const payload = chosen === 'new' ? { mode: 'new', base: form.base } : { mode: 'existing' };
    const result = await API.post('/api/install/start', payload);
    if (!result.ok) {
      setBusy(false);
      render();
      showError(result);
      return;
    }
    job = result.job;
    render();
  }

  /** Installation terminée : la configuration reprend avec les dossiers posés par la Chancellerie. */
  async function afterInstall() {
    const result = await API.get('/api/assistant');
    if (!sheet || !result.ok) return;
    view = result;
    form = formFromView(result);
    mode = 'existing';
    step = 1;
    render();
  }

  // Base de données ---------------------------------------------------------------------------------------------------

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
    const show = (good, text) => {
      result.className = `probe-result ${good ? 'is-good' : 'is-bad'}`;
      result.textContent = text;
    };
    const probe = UI.button(W.dbCheck, async () => {
      probe.disabled = true;
      result.className = 'probe-result';
      result.textContent = W.dbChecking;
      const answer = await API.post('/api/assistant/dbcheck', { host: inputs['db.host'].value.trim(), port: integer(inputs['db.port'].value) });
      probe.disabled = false;
      show(answer.ok, answer.ok ? W.dbAnswer(answer.version) : STRINGS.error(answer.error));
    });
    const create = UI.button(W.dbCreate, async () => {
      create.disabled = true;
      result.className = 'probe-result';
      result.textContent = W.dbCreating;
      const database = inputs['db.database'].value.trim();
      const answer = await API.post('/api/assistant/dbcreate', {
        host: inputs['db.host'].value.trim(), port: integer(inputs['db.port'].value), user: inputs['db.user'].value.trim(),
        password: inputs['db.password'].value, database,
      });
      create.disabled = false;
      show(answer.ok, answer.ok ? W.dbCreated(database) : `${STRINGS.error(answer.error, answer.field)}${answer.detail ? ` ${answer.detail}` : ''}`);
    });
    body.append(UI.el('div', 'probe', null, [probe, create, result]));
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
    if (step === 0 && mode === 'new') {
      next = UI.button(installing() ? W.installing : W.install, () => move(1), 'green');
    } else if (step < LAST_STEP) {
      next = UI.button(installing() ? W.installing : W.next, () => move(1), 'seal');
    } else {
      const launch = canStart && !view.running;
      next = UI.button(launch ? W.seal : W.sealOnly, () => seal(launch), launch ? 'green' : 'seal');
    }
    next.disabled = installing();
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
    if (busy && label) {
      const main = sheet.querySelector('.wizard-actions .seal-button');
      if (main) main.textContent = label;
    }
  }

  /** Change d'étape ; quitter la première installe (nouveau serveur) ou enregistre les dossiers (serveur en place). */
  async function move(delta) {
    collect();
    if (step === 0 && delta > 0 && mode === 'new') {
      await startInstall('new');
      return;
    }
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
      if (form.installVava) {
        await startInstall('existing');
        return;
      }
    }
    step = Math.min(LAST_STEP, Math.max(0, step + delta));
    render();
  }

  async function seal(launch) {
    collect();
    setBusy(true);
    const { serverDataPath, fxserverPath, base, installVava, ...payload } = form;
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
      const [result, current] = await Promise.all([API.get('/api/assistant'), API.get('/api/jobs/current')]);
      if (!sheet) return;
      if (!result.ok) {
        UI.report(result);
        return;
      }
      view = result;
      form = null;
      form = formFromView(result);
      job = current.ok ? current.job : null;
      mode = installing() ? (job && job.kind === 'install' && !view.paths.saved ? 'new' : 'existing') : view.paths.saved || view.setupDone ? 'existing' : 'new';
      step = 0;
      render();
      // ce que la Chancellerie propose d'installer (Cfx.re interrogé : sans attendre)
      const proposed = await API.get('/api/install/options');
      if (!sheet || !proposed.ok) return;
      install = proposed;
      if (step === 0 && mode === 'new' && !installing()) {
        collect();
        render();
      }
    },

    hide() {
      sheet = null;
    },

    /** Avancée d'une opération longue (installation). */
    job(next) {
      if (!sheet || !next || next.kind !== 'install') return;
      const wasRunning = installing();
      job = next;
      if (step !== 0) return;
      if (wasRunning && next.status === 'done') {
        afterInstall();
        return;
      }
      if (wasRunning && next.status !== 'running') {
        render();
        showError({ error: 'install_failed' });
        return;
      }
      // pendant l'opération, seul le bloc d'avancée est redessiné (les champs restent tels quels)
      const box = sheet.querySelector('.install-job');
      if (box) box.replaceChildren(JOB.node(job));
    },
  };
})();
