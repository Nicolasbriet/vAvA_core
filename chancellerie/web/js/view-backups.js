'use strict';
/*
 * web/js/view-backups.js
 * Rôle : la page Sauvegardes. Base de données (droit « sauvegardes ») : sauvegarder maintenant, suivre la sauvegarde
 *        en cours (en direct), télécharger ou supprimer une sauvegarde, régler mysqldump, le nombre de sauvegardes
 *        gardées et les heures des sauvegardes planifiées. server.cfg (droit « configuration ») : relire une ancienne
 *        version (sans ses secrets) et la restaurer.
 */

const BackupsView = (() => {
  const B = STRINGS.backups;
  const TICK_MS = 1000;

  let sheet = null;
  let context = null;
  let refs = null;
  let db = null;
  let tickTimer = null;

  const integer = (value) => Math.floor(Number(value));
  const parseTimes = (text) => text.split(/[,;\s]+/).map((t) => t.trim()).filter(Boolean).map((t) => (/^\d:\d\d$/.test(t) ? `0${t}` : t));

  // Base de données -------------------------------------------------------------------------------------------------

  function dbStatusLines() {
    const status = db.status;
    const lines = [];
    if (status.running) {
      const elapsed = Date.now() - (context.status().skew || 0) - status.startedAt;
      lines.push(UI.el('p', 'backup-running', B.dbRunning(elapsed)));
    } else if (status.last) {
      const text = status.last.ok ? B.last(true, status.last.at) : `${B.last(false, status.last.at)} ${status.last.detail || ''}`;
      lines.push(UI.el('p', status.last.ok ? 'hint' : 'wizard-error', text));
    }
    lines.push(UI.el('p', status.tool ? 'hint' : 'wizard-error', status.tool ? B.tool(status.tool) : B.toolMissing));
    lines.push(UI.el('p', 'hint', db.nextAt ? B.next(db.nextAt) : B.noneScheduled));
    return lines;
  }

  function dbTable() {
    const list = UI.list(db.backups);
    if (!list.length) return UI.el('p', 'empty', B.empty);
    return UI.el('table', 'ledger', null, [
      UI.el('thead', null, null, [UI.el('tr', null, null, B.columns.map((c, i) => UI.el('th', i >= 2 ? 'cell-end' : null, c)))]),
      UI.el('tbody', null, null, list.map((backup) => {
        const link = UI.el('a', 'ink-button link-button', B.download);
        link.href = `/api/backups/db/download?name=${encodeURIComponent(backup.name)}`;
        link.download = backup.name;
        return UI.el('tr', null, null, [
          UI.el('td', 'mono-cell', backup.name),
          UI.el('td', 'cell-date', STRINGS.date(backup.at)),
          UI.el('td', 'cell-end', STRINGS.bytes(backup.size)),
          UI.el('td', 'cell-end', null, [UI.el('span', 'row-actions', null, [link, UI.button(B.remove, () => removeDb(backup), 'plain')])]),
        ]);
      })),
    ]);
  }

  function renderDb() {
    if (!refs || !db) return;
    refs.dbNow.disabled = db.status.running;
    refs.dbStatus.replaceChildren(...dbStatusLines());
    refs.dbList.replaceChildren(dbTable());
  }

  function dbSettings() {
    const grid = UI.el('div', 'form-grid');
    const dumpPath = UI.field({ name: 'dumpPath', label: B.dumpPath, value: db.status.toolConfigured ? db.status.tool : '', help: B.dumpPathHelp, wide: true, max: 400 });
    const keep = UI.field({ name: 'keep', label: B.keep, type: 'number', min: 1, max: 200, value: db.status.keep, help: B.keepHelp });
    const times = UI.field({ name: 'times', label: B.times, value: UI.list(db.times).join(', '), help: B.timesHelp, max: 120 });
    grid.append(dumpPath.node, keep.node, times.node);
    const save = UI.button(B.saveSettings, async () => {
      for (const made of [dumpPath, keep, times]) made.input.classList.remove('is-invalid');
      const result = await API.post('/api/backups/db/settings', {
        dumpPath: dumpPath.input.value.trim(), keep: integer(keep.input.value), times: parseTimes(times.input.value),
      });
      if (!result.ok && result.field) {
        const made = { dumpPath, keep, times }[result.field];
        if (made) made.input.classList.add('is-invalid');
      }
      if (UI.report(result, B.settingsSaved)) {
        db = result;
        times.input.value = UI.list(db.times).join(', ');
        renderDb();
      }
    }, 'seal');
    return UI.el('div', null, null, [UI.el('h3', 'section-title', B.settings), grid, UI.el('div', 'page-actions', null, [save])]);
  }

  async function createDb() {
    refs.dbNow.disabled = true;
    const result = await API.post('/api/backups/db/create');
    if (UI.report(result, B.dbStarted)) db = result;
    renderDb();
  }

  async function removeDb(backup) {
    if (!(await UI.confirm({ title: B.removeTitle, text: B.removeText(backup.name), confirm: B.remove }))) return;
    const result = await API.post('/api/backups/db/delete', { name: backup.name });
    if (UI.report(result, B.removed)) {
      db = result;
      renderDb();
    }
  }

  /** Liste et état relus, sans toucher aux réglages en cours de saisie. */
  async function refreshDb() {
    const result = await API.get('/api/backups/db');
    if (!sheet || !result.ok) return;
    db = result;
    renderDb();
  }

  async function loadDb() {
    const result = await API.get('/api/backups/db');
    if (!sheet) return;
    if (!result.ok) {
      refs.db.replaceChildren(UI.el('h3', 'section-title', B.dbTitle), UI.el('p', 'empty', STRINGS.error(result.error)));
      return;
    }
    db = result;
    refs.db.replaceChildren(
      UI.el('h3', 'section-title', B.dbTitle),
      UI.el('p', 'prose', B.dbIntro),
      refs.dbStatus,
      UI.el('div', 'page-actions', null, [refs.dbNow]),
      refs.dbList,
      UI.el('p', 'hint', B.restoreHint),
      dbSettings(),
    );
    renderDb();
  }

  // server.cfg ------------------------------------------------------------------------------------------------------

  async function viewCfg(backup) {
    const result = await API.get(`/api/backups/cfg/view?name=${encodeURIComponent(backup.name)}`);
    if (!UI.report(result)) return;
    await UI.reading({ title: B.viewTitle(backup.at), body: UI.el('pre', 'cfg-preview', result.text), confirm: B.close });
  }

  async function restoreCfg(backup) {
    if (!(await UI.confirm({ title: B.restoreTitle, text: B.restoreText, confirm: B.restore }))) return;
    const result = await API.post('/api/backups/cfg/restore', { name: backup.name });
    if (UI.report(result, result.restartNeeded ? B.restored : B.restoredStopped)) loadCfg();
  }

  async function loadCfg() {
    const result = await API.get('/api/backups/cfg');
    if (!sheet) return;
    const list = result.ok ? UI.list(result.backups) : [];
    const body = !result.ok ? UI.el('p', 'empty', STRINGS.error(result.error)) : !list.length ? UI.el('p', 'empty', B.cfgEmpty)
      : UI.el('table', 'ledger', null, [
        UI.el('thead', null, null, [UI.el('tr', null, null, B.cfgColumns.map((c, i) => UI.el('th', i >= 1 ? 'cell-end' : null, c)))]),
        UI.el('tbody', null, null, list.map((backup) => UI.el('tr', null, null, [
          UI.el('td', 'cell-date', STRINGS.date(backup.at)),
          UI.el('td', 'cell-end', STRINGS.bytes(backup.size)),
          UI.el('td', 'cell-end', null, [UI.el('span', 'row-actions', null, [
            UI.button(B.view, () => viewCfg(backup)),
            UI.button(B.restore, () => restoreCfg(backup), 'plain'),
          ])]),
        ]))),
      ]);
    refs.cfg.replaceChildren(UI.el('h3', 'section-title', B.cfgTitle), UI.el('p', 'prose', B.cfgIntro), body);
  }

  return {
    show(target, appContext) {
      sheet = target;
      context = appContext;
      refs = {
        db: UI.el('section', 'backup-section'),
        cfg: UI.el('section', 'backup-section'),
        dbStatus: UI.el('div'),
        dbList: UI.el('div'),
        dbNow: UI.button(B.dbNow, createDb, 'seal'),
      };
      const sections = [];
      if (context.can('backups')) sections.push(refs.db);
      if (context.can('config')) sections.push(refs.cfg);
      sheet.replaceChildren(UI.heading(B.title), ...(sections.length ? sections : [UI.el('p', 'empty', B.denied)]));
      if (context.can('backups')) loadDb();
      if (context.can('config')) loadCfg();
      // la durée de la sauvegarde en cours avance d'elle-même
      tickTimer = setInterval(() => {
        if (db && db.status.running) refs.dbStatus.replaceChildren(...dbStatusLines());
      }, TICK_MS);
    },

    hide() {
      clearInterval(tickTimer);
      tickTimer = null;
      sheet = null;
      refs = null;
      db = null;
    },

    /** Une sauvegarde de la base a commencé ou fini (flux d'évènements). */
    backup(status) {
      if (!sheet || !db) return;
      const finished = db.status.running && !status.running;
      db.status = status;
      if (finished && status.last) UI.slip(status.last.ok ? B.dbDone(status.last.name) : B.dbFailed(status.last.detail));
      if (finished) refreshDb();
      else renderDb();
    },
  };
})();
