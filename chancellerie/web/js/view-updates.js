'use strict';
/*
 * web/js/view-updates.js
 * Rôle : la page Mises à jour : ce qui est installé (vAvA, Chancellerie, oxmysql, FXServer), la dernière version sur
 *        GitHub avec les changements arrivés depuis et les parties touchées, l'opération en cours suivie en direct, et
 *        pour le compte maître : appliquer la mise à jour (sauvegarde de la base, joueurs prévenus) et régler le suivi
 *        (commits ou releases, vérification horaire, application au redémarrage planifié).
 */

const UpdatesView = (() => {
  const U = STRINGS.updates;

  let sheet = null;
  let context = null;
  let refs = null;
  let data = null;

  const isMaster = () => Boolean(context.account() && context.account().master);
  const running = () => Boolean(data && data.job && data.job.status === 'running');

  function fact(label, value, small) {
    return UI.el('div', 'fact', null, [UI.el('dt', null, label), UI.el('dd', 'fact-text', value, small ? [UI.el('small', null, ` ${small}`)] : null)]);
  }

  function renderInstalled() {
    const installed = data.installed;
    const source = installed.source;
    refs.installed.replaceChildren(
      UI.el('h3', 'section-title', U.installedTitle),
      UI.el('dl', 'facts facts-wide', null, [
        fact(U.vava, source ? source.label : U.unknown, source && source.date ? STRINGS.date(source.date) : null),
        fact(U.panel, installed.panel),
        fact(U.oxmysql, installed.oxmysql ? installed.oxmysql.version : U.none),
        fact(U.fxserver, installed.fxserver ? U.build(installed.fxserver.build) : U.none),
      ]),
      source && source.message ? UI.el('p', 'hint', U.version(source.label, source.message)) : null,
    );
  }

  function commitList(commits) {
    return UI.el('ol', 'commits', null, commits.map((commit) => UI.el('li', null, null, [
      UI.el('span', 'mono-cell commit-ref', commit.ref),
      UI.el('span', 'commit-message', commit.message),
      UI.el('span', 'cell-sub', [commit.author, commit.date ? STRINGS.date(commit.date) : ''].filter(Boolean).join(' · ')),
    ])));
  }

  async function apply() {
    const wasRunning = context.status().state === 'running';
    const values = await UI.form({
      title: U.applyTitle, text: U.applyText, confirm: U.apply,
      fields: [
        { name: 'backupDb', label: '', type: 'checks', options: [{ value: 'yes', label: U.backupDb, checked: true }] },
        { name: 'delayMin', label: U.delay, type: 'stamps', value: wasRunning ? 5 : 0, options: data.delays.map((d) => ({ value: d, label: U.delays[d] })) },
      ],
    });
    if (!values) return;
    const result = await API.post('/api/updates/apply', { backupDb: values.backupDb.includes('yes'), delayMin: values.delayMin });
    if (UI.report(result, U.started)) {
      data.job = result.job;
      render();
    }
  }

  async function check() {
    refs.checkButton.disabled = true;
    refs.checkButton.textContent = U.checking;
    const result = await API.post('/api/updates/check');
    if (!sheet) return;
    if (UI.report(result)) data = result;
    render();
  }

  function renderLatest() {
    const status = data.check;
    const parts = [UI.el('h3', 'section-title', U.latestTitle), UI.el('p', 'hint', U.repo(data.settings.repo, data.settings.branch))];
    refs.checkButton = UI.button(U.check, check);
    refs.checkButton.disabled = running();
    const applyButton = UI.button(U.apply, apply, 'green');
    applyButton.disabled = !isMaster() || running() || data.blocked.length > 0 || !status || !status.available;
    if (!status) {
      parts.push(UI.el('p', 'empty', U.notChecked));
    } else {
      if (status.error) parts.push(UI.el('p', 'wizard-error', `${U.checkFailed} ${STRINGS.job.errors[status.error] || status.error}`));
      if (status.available && status.latest) {
        parts.push(UI.el('div', 'state-banner update-banner', null, [
          UI.el('div', 'state-banner-text', null, [
            UI.el('span', 'state-banner-label', U.available(status.latest.label)),
            UI.el('span', 'state-banner-detail', `${status.latest.message}${status.latest.date ? ` · ${STRINGS.date(status.latest.date)}` : ''}`),
          ]),
          UI.el('div', 'state-banner-actions', null, [applyButton]),
        ]));
        if (!status.current) parts.push(UI.el('p', 'hint', U.unknownInstalled));
        if (status.parts && status.parts.length) {
          parts.push(UI.el('p', 'update-parts', null, [
            UI.el('span', 'field-label', U.parts),
            ...status.parts.map((part) => UI.el('span', 'tag', part === 'chancellerie' ? U.partPanel : part)),
          ]));
        }
        const commits = UI.list(status.commits);
        if (commits.length) parts.push(UI.el('h3', 'section-title', U.commitsTitle(status.total || commits.length)), commitList(commits));
      } else if (!status.error) {
        parts.push(UI.el('p', 'update-ok', U.upToDate));
      }
      parts.push(UI.el('p', 'cell-sub', U.checkedAt(status.checkedAt)));
    }
    if (data.blocked.length) parts.push(UI.el('p', 'wizard-error', `${U.blocked} ${data.blocked.join(', ')}`));
    else if (!isMaster()) parts.push(UI.el('p', 'hint', U.masterOnly));
    parts.push(UI.el('div', 'page-actions', null, [refs.checkButton]));
    parts.push(UI.el('p', 'hint', U.keptNote));
    refs.latest.replaceChildren(...parts);
  }

  function renderJob() {
    refs.job.replaceChildren(...(data.job ? [UI.el('h3', 'section-title', U.jobTitle), JOB.node(data.job)] : []));
  }

  function renderSettings() {
    if (!isMaster()) {
      refs.settings.replaceChildren();
      return;
    }
    const s = data.settings;
    const channel = UI.field({ name: 'channel', label: U.channel, type: 'select', options: U.channels });
    channel.input.value = s.channel;
    const autoCheck = UI.choice(U.autoCheck, s.autoCheck);
    const atRestart = UI.choice(U.applyAtRestart, s.applyAtRestart, U.applyAtRestartHelp);
    const save = UI.button(U.saveSettings, async () => {
      const result = await API.post('/api/updates/settings', { channel: channel.input.value, autoCheck: autoCheck.input.checked, applyAtRestart: atRestart.input.checked });
      if (UI.report(result, U.settingsSaved)) {
        data = result;
        render();
      }
    }, 'seal');
    refs.settings.replaceChildren(
      UI.el('h3', 'section-title', U.settings),
      UI.el('div', 'form-grid', null, [channel.node, autoCheck.node, atRestart.node]),
      UI.el('div', 'page-actions', null, [save]),
    );
  }

  function render() {
    if (!sheet || !data) return;
    renderInstalled();
    renderLatest();
    renderJob();
    renderSettings();
  }

  async function load() {
    const result = await API.get('/api/updates');
    if (!sheet) return;
    if (!result.ok) {
      UI.report(result);
      return;
    }
    data = result;
    render();
  }

  return {
    show(target, appContext) {
      sheet = target;
      context = appContext;
      refs = { installed: UI.el('section'), latest: UI.el('section', 'update-section'), job: UI.el('section', 'update-section'), settings: UI.el('section', 'update-section') };
      sheet.replaceChildren(UI.heading(U.title), refs.installed, refs.job, refs.latest, refs.settings);
      load();
    },

    hide() {
      sheet = null;
      refs = null;
      data = null;
    },

    /** Avancée d'une opération longue. */
    job(job) {
      if (!sheet || !data) return;
      const finished = running() && job && job.status !== 'running';
      data.job = job;
      if (finished) load();
      else {
        renderJob();
        if (refs.checkButton) refs.checkButton.disabled = running();
      }
    },

    /** Nouvelle vérification (faite par la Chancellerie elle-même). */
    updates(view) {
      if (!sheet || !view || !view.check) return;
      data = view;
      render();
    },
  };
})();
