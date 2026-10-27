'use strict';
/*
 * web/js/view-dashboard.js
 * Rôle : le tableau de bord : état du serveur avec ses commandes (démarrer, arrêter, redémarrer), chiffres
 *        (joueurs, durée, arrêts imprévus ; charge de FXServer, réseau, prochain redémarrage planifié), joueurs
 *        connectés et dernières inscriptions du journal. L'état et les relevés arrivent en direct ; la liste des
 *        joueurs et le journal sont relus à intervalle tant que la page est affichée.
 */

const DashboardView = (() => {
  const D = STRINGS.dashboard;
  const S = STRINGS.server;
  const PLAYERS_MS = 10000;
  const TICK_MS = 1000;
  const JOURNAL_SHOWN = 12;

  let sheet = null;
  let refs = null;
  let context = null;
  let details = null;
  let journal = [];
  let latest = null;
  let pollTimer = null;
  let tickTimer = null;

  async function act(action) {
    if (action !== 'start') {
      const confirmed = await UI.confirm(action === 'stop'
        ? { title: S.stopTitle, text: S.stopText, confirm: S.stop }
        : { title: S.restartTitle, text: S.restartText, confirm: S.restart });
      if (!confirmed) return;
    }
    const messages = { start: S.starting, stop: S.stopping, restart: S.restarting };
    UI.report(await API.post(`/api/server/${action}`), messages[action]);
  }

  function actionButtons(status) {
    if (!context.can('server') || !context.setupDone()) return [];
    const { state } = status;
    if (state === 'stopping') {
      const waiting = UI.button(S.stop, null, 'seal');
      waiting.disabled = true;
      return [waiting];
    }
    const buttons = [];
    if (state === 'stopped' || state === 'crashed') buttons.push(UI.button(S.start, () => act('start'), 'green'));
    if (state === 'starting' || state === 'running') buttons.push(UI.button(S.restart, () => act('restart')));
    if (state !== 'stopped') buttons.push(UI.button(S.stop, () => act('stop'), 'seal'));
    return buttons;
  }

  function fact(label, value, small) {
    return UI.el('div', 'fact', null, [UI.el('dt', null, label), UI.el('dd', null, value, small ? [document.createTextNode(' '), UI.el('small', null, small)] : null)]);
  }

  function renderBanner(status) {
    refs.banner.className = `state-banner is-${status.state}`;
    refs.bannerLabel.textContent = STRINGS.states[status.state];
    refs.bannerDetail.textContent = STRINGS.describe(status, context.setupDone());
    refs.actions.replaceChildren(...actionButtons(status));
  }

  function renderFacts(status) {
    const running = status.state === 'running';
    const players = details && Array.isArray(details.players) ? details.players.length : null;
    const now = Date.now() - (status.skew || 0);
    refs.facts.replaceChildren(
      fact(D.players, running && players !== null ? String(players) : '—', details && details.maxClients ? `/ ${details.maxClients}` : null),
      fact(D.uptime, running && status.startedAt ? STRINGS.duration(now - status.startedAt) : '—'),
      fact(D.crashes, String(status.crashes || 0), D.crashesHelp),
      fact(D.port, details && details.port ? String(details.port) : '—'),
    );
  }

  /** Mise à jour de vAvA disponible, ou installation / mise à jour en cours. */
  function renderNotice() {
    const text = details && details.job ? D.updateRunning : details && details.update ? D.updateAvailable(details.update.label, details.update.commits) : null;
    if (!text) {
      refs.notice.replaceChildren();
      return;
    }
    refs.notice.replaceChildren(UI.el('div', 'state-banner update-banner', null, [
      UI.el('div', 'state-banner-text', null, [UI.el('span', 'state-banner-detail update-notice', text)]),
      UI.el('div', 'state-banner-actions', null, [UI.button(D.updateSee, () => context.navigate('mises-a-jour'))]),
    ]));
  }

  /** Charge du serveur (dernier relevé) et prochain redémarrage planifié. */
  function renderLoad() {
    const sample = latest || (details && details.metrics) || {};
    const schedule = details && details.schedule;
    const now = Date.now() - (context.status().skew || 0);
    let next = D.noRestart;
    let nextSmall = null;
    if (schedule && schedule.restartAt) {
      next = STRINGS.time(schedule.restartAt);
      nextSmall = schedule.skipped ? D.skipped : D.in(Math.max(0, schedule.restartAt - now));
    }
    refs.load.replaceChildren(
      fact(D.fxCpu, STRINGS.percent(sample.fxCpu)),
      fact(D.fxMem, STRINGS.bytes(sample.fxMem)),
      fact(D.network, sample.rx === null || sample.rx === undefined ? '—' : `${STRINGS.bitrate(sample.rx)} / ${STRINGS.bitrate(sample.tx)}`),
      fact(D.nextRestart, next, nextSmall),
    );
  }

  function renderPlayers(status) {
    const body = [];
    if (status.state !== 'running') body.push(UI.el('p', 'empty', D.offline));
    else if (!details || !Array.isArray(details.players)) body.push(UI.el('p', 'empty', D.playersUnknown));
    else if (!details.players.length) body.push(UI.el('p', 'empty', D.noPlayers));
    else {
      const rows = details.players.map((player) => UI.el('tr', null, null, [
        UI.el('td', 'cell-number', String(player.id)), UI.el('td', 'cell-strong', player.name), UI.el('td', 'cell-end', D.ms(player.ping)),
      ]));
      body.push(UI.el('table', 'ledger', null, [
        UI.el('thead', null, null, [UI.el('tr', null, null, [UI.el('th', null, D.id), UI.el('th', null, D.name), UI.el('th', 'cell-end', D.ping)])]),
        UI.el('tbody', null, null, rows),
      ]));
    }
    refs.players.replaceChildren(UI.el('h3', 'section-title', D.playersTitle), ...body);
  }

  function renderJournal() {
    const body = journal.length ? [UI.el('table', 'ledger', null, [UI.el('tbody', null, null, journal.slice(0, JOURNAL_SHOWN).map((entry) => {
      // la commande telle quelle ; sinon les précisions de l'inscription (ressource, fichier, heures…)
      const details = entry.details || {};
      const detail = details.command || Object.values(details).filter((v) => v !== null && v !== '').join(' · ');
      return UI.el('tr', null, null, [
        UI.el('td', 'cell-date', STRINGS.date(entry.at)),
        UI.el('td', null, null, [UI.el('span', 'cell-strong', STRINGS.actions[entry.action] || entry.action), detail ? UI.el('div', 'cell-sub mono', detail) : null]),
        UI.el('td', 'cell-sub cell-end', entry.actor),
      ]);
    }))])] : [UI.el('p', 'empty', D.noJournal)];
    refs.journal.replaceChildren(UI.el('h3', 'section-title', D.journalTitle), ...body);
  }

  function renderSetup() {
    return UI.el('div', 'state-banner', null, [
      UI.el('div', 'state-banner-text', null, [UI.el('span', 'state-banner-label', D.setupTitle), UI.el('span', 'state-banner-detail', D.setupText)]),
      context.can('config') ? UI.button(D.setupButton, () => context.navigate('configuration'), 'seal') : null,
    ]);
  }

  async function refresh() {
    const [server, entries] = await Promise.all([API.get('/api/server'), API.get('/api/journal')]);
    if (!sheet) return;
    if (server.ok) details = server;
    if (entries.ok) journal = entries.entries;
    context.setServerName(details ? details.hostname : '');
    const status = context.status();
    renderFacts(status);
    renderLoad();
    renderNotice();
    renderPlayers(status);
    renderJournal();
  }

  function stopTimers() {
    clearInterval(pollTimer);
    clearInterval(tickTimer);
    pollTimer = null;
    tickTimer = null;
  }

  return {
    /** @param {HTMLElement} target  @param {object} appContext  fonctions de l'application (état, droits, navigation) */
    show(target, appContext) {
      sheet = target;
      context = appContext;
      const status = context.status();
      refs = {
        banner: UI.el('div', 'state-banner'),
        bannerLabel: UI.el('span', 'state-banner-label'),
        bannerDetail: UI.el('span', 'state-banner-detail'),
        actions: UI.el('div', 'state-banner-actions'),
        facts: UI.el('dl', 'facts'),
        load: UI.el('dl', 'facts facts-load'),
        notice: UI.el('div', 'dashboard-notice'),
        players: UI.el('div'),
        journal: UI.el('div'),
      };
      refs.banner.append(UI.el('span', 'state-seal'), UI.el('div', 'state-banner-text', null, [refs.bannerLabel, refs.bannerDetail]), refs.actions);
      sheet.replaceChildren(
        UI.heading(D.title),
        context.setupDone() ? refs.banner : renderSetup(),
        refs.notice,
        refs.facts,
        refs.load,
        UI.el('div', 'columns', null, [refs.players, refs.journal]),
      );
      latest = null;
      renderBanner(status);
      renderFacts(status);
      renderLoad();
      renderPlayers(status);
      renderJournal();
      refresh();
      pollTimer = setInterval(refresh, PLAYERS_MS);
      tickTimer = setInterval(() => {
        const current = context.status();
        refs.bannerDetail.textContent = STRINGS.describe(current, context.setupDone());
        if (current.state === 'running') renderFacts(current);
        renderLoad();
      }, TICK_MS);
    },

    /** Une mise à jour est apparue, ou une opération a commencé ou fini. */
    updates() {
      if (sheet) refresh();
    },

    job(job) {
      if (sheet && job && job.status !== 'running') refresh();
      else if (sheet && details && !details.job) refresh();
    },

    /** Nouveau relevé des performances. */
    metrics(sample) {
      if (!sheet) return;
      latest = sample;
      renderLoad();
    },

    hide() {
      stopTimers();
      sheet = null;
    },

    /** Nouvel état du serveur. */
    update(status) {
      if (!sheet) return;
      renderBanner(status);
      renderFacts(status);
      renderPlayers(status);
      refresh();
    },
  };
})();
