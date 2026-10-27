'use strict';
/*
 * web/js/job.js
 * Rôle : l'avancée d'une opération longue (installation, mise à jour), telle que la Chancellerie l'annonce en direct :
 *        état, étape en cours, barre de téléchargement, dernières lignes de son journal, issue (réussite, échec, retour
 *        à la version précédente).
 */

const JOB = (() => {
  const J = STRINGS.job;
  const LOG_SHOWN = 10;

  function progressBar(progress) {
    const fill = UI.el('span', 'job-bar-fill');
    const ratio = progress.total ? Math.min(1, progress.received / progress.total) : null;
    if (ratio === null) fill.classList.add('is-unknown');
    else fill.style.width = `${(ratio * 100).toFixed(1)}%`;
    return UI.el('div', 'job-progress', null, [
      UI.el('div', 'job-bar', null, [fill]),
      UI.el('span', 'cell-sub', progress.total ? J.of(STRINGS.bytes(progress.received), STRINGS.bytes(progress.total)) : STRINGS.bytes(progress.received)),
    ]);
  }

  /** Bloc d'une opération (ou null s'il n'y en a pas). */
  function node(job) {
    if (!job) return null;
    const state = job.status === 'running' ? 'running' : job.status === 'done' ? 'done' : job.error && job.error.code === 'update_rolled_back' ? 'rolled' : 'failed';
    const head = UI.el('div', 'job-head', null, [
      UI.el('span', `tag job-tag is-${state}`, J.states[state]),
      UI.el('span', 'job-title', J.kinds[job.kind] || job.kind),
      UI.el('span', 'cell-sub', `${J.by(job.actor)} · ${STRINGS.date(job.startedAt)}`),
    ]);
    const parts = [head];
    if (job.progress) parts.push(progressBar(job.progress));
    if (state === 'failed' || state === 'rolled') parts.push(UI.el('p', 'wizard-error', `${J.errors[job.error.code] || ''} ${job.error.detail}`.trim()));
    if (state === 'done' && job.result && job.result.summary) parts.push(UI.el('p', 'job-result', J.done(job.result.summary)));
    const lines = (job.log || []).slice(-LOG_SHOWN);
    if (lines.length) {
      parts.push(UI.el('ol', 'job-log', null, lines.map((line) => UI.el('li', null, null, [
        UI.el('span', 'cell-date', STRINGS.clock(line.at)), UI.el('span', null, line.text),
      ]))));
    }
    return UI.el('section', `job is-${state}`, null, parts);
  }

  return { node };
})();
