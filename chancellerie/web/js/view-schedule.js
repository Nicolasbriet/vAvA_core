'use strict';
/*
 * web/js/view-schedule.js
 * Rôle : la page Planification : le prochain redémarrage (avec le temps qui reste, et le bouton pour le sauter une
 *        fois ou le rétablir), puis les réglages : heures des redémarrages, délais des avertissements aux joueurs et
 *        leur message. Rappelle les heures des sauvegardes de la base, réglées dans la page Sauvegardes.
 */

const ScheduleView = (() => {
  const S = STRINGS.schedule;
  const TICK_MS = 1000;
  // la Chancellerie revoit ses échéances toutes les 10 secondes
  const RELOAD_AFTER_MS = 12000;

  let sheet = null;
  let context = null;
  let refs = null;
  let schedule = null;
  let tickTimer = null;
  let reloadTimer = null;

  const parseList = (text) => text.split(/[,;\s]+/).map((t) => t.trim()).filter(Boolean);
  const parseTimes = (text) => parseList(text).map((t) => (/^\d:\d\d$/.test(t) ? `0${t}` : t));
  const now = () => Date.now() - (context.status().skew || 0);

  function renderNext() {
    if (!refs || !schedule) return;
    if (schedule.restartAt === null) {
      refs.next.replaceChildren(UI.el('div', 'state-banner-text', null, [UI.el('span', 'state-banner-label', S.none)]));
      return;
    }
    const skipped = schedule.skipped;
    const toggle = UI.button(skipped ? S.unskip : S.skip, async () => {
      const result = await API.post('/api/schedule/skip', { skip: !skipped });
      if (UI.report(result, skipped ? S.unskippedDone : S.skippedDone)) {
        schedule = result.schedule;
        renderNext();
      }
    }, skipped ? 'green' : 'ink');
    toggle.disabled = !context.can('server');
    refs.countdown = UI.el('span', 'state-banner-detail');
    refs.next.replaceChildren(
      UI.el('div', 'state-banner-text', null, [
        UI.el('span', `state-banner-label${skipped ? ' is-struck' : ''}`, S.next(schedule.restartAt)),
        refs.countdown,
      ]),
      UI.el('div', 'state-banner-actions', null, [toggle]),
    );
    countdown();
  }

  /**
   * Temps restant, chaque seconde. L'échéance passée, la planification est relue une fois, le temps que la
   * Chancellerie ait calculé la suivante.
   */
  function countdown() {
    if (!refs || !refs.countdown || !schedule || schedule.restartAt === null) return;
    const left = schedule.restartAt - now();
    if (left < 0 && !reloadTimer) {
      reloadTimer = setTimeout(() => {
        reloadTimer = null;
        load();
      }, RELOAD_AFTER_MS);
    }
    refs.countdown.textContent = schedule.skipped ? S.skippedNote : S.nextIn(Math.max(0, left));
  }

  function renderForm() {
    const grid = UI.el('div', 'form-grid');
    const restarts = UI.field({ name: 'restarts', label: S.restarts, value: UI.list(schedule.restarts).join(', '), help: S.restartsHelp, max: 120 });
    const warnings = UI.field({ name: 'warnings', label: S.warnings, value: UI.list(schedule.warnings).join(', '), help: S.warningsHelp, max: 60 });
    const message = UI.field({ name: 'message', label: S.message, value: schedule.message, help: S.messageHelp, max: 200, wide: true });
    grid.append(restarts.node, warnings.node, message.node);
    const editable = context.can('server');
    for (const made of [restarts, warnings, message]) made.input.disabled = !editable;
    const save = UI.button(S.save, async () => {
      for (const made of [restarts, warnings, message]) made.input.classList.remove('is-invalid');
      const result = await API.post('/api/schedule/restarts', {
        restarts: parseTimes(restarts.input.value),
        warnings: parseList(warnings.input.value).map(Number),
        message: message.input.value,
      });
      if (!result.ok && result.field) {
        const made = { restarts, warnings, message }[result.field];
        if (made) made.input.classList.add('is-invalid');
      }
      if (UI.report(result, S.saved)) {
        schedule = result.schedule;
        restarts.input.value = UI.list(schedule.restarts).join(', ');
        warnings.input.value = UI.list(schedule.warnings).join(', ');
        renderNext();
      }
    }, 'seal');
    save.disabled = !editable;
    return [grid, UI.el('div', 'page-actions', null, [save]), editable ? null : UI.el('p', 'hint', S.denied)];
  }

  async function load() {
    const result = await API.get('/api/schedule');
    if (!sheet) return;
    if (!result.ok) {
      UI.report(result);
      return;
    }
    schedule = result.schedule;
    sheet.replaceChildren(
      UI.heading(S.title),
      UI.el('h3', 'section-title', S.restartsTitle),
      UI.el('p', 'prose', S.intro),
      refs.next,
      ...renderForm().filter(Boolean),
      UI.el('p', 'hint', S.backupsNote(UI.list(schedule.backups))),
    );
    renderNext();
  }

  return {
    show(target, appContext) {
      sheet = target;
      context = appContext;
      refs = { next: UI.el('div', 'state-banner schedule-banner') };
      sheet.replaceChildren(UI.heading(S.title));
      load();
      tickTimer = setInterval(countdown, TICK_MS);
    },

    hide() {
      clearInterval(tickTimer);
      clearTimeout(reloadTimer);
      tickTimer = null;
      reloadTimer = null;
      sheet = null;
      refs = null;
    },
  };
})();
