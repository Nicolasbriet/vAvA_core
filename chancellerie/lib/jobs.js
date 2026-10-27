'use strict';
/*
 * lib/jobs.js
 * Rôle : l'opération longue en cours (installation, mise à jour), une seule à la fois : ses étapes, la progression
 *        d'un téléchargement, son journal, son issue. Chaque changement est annoncé (évènement « change », relayé aux
 *        navigateurs) ; pendant qu'elle tourne, démarrer, arrêter ou redémarrer le serveur à la main est refusé.
 */

const EventEmitter = require('events');
const journal = require('./journal');
const notices = require('./notices');

const LOG_KEPT = 200;
const emitter = new EventEmitter();
let current = null;
let last = null;

function view(job) {
  if (!job) return null;
  return {
    kind: job.kind, actor: job.actor, startedAt: job.startedAt, endedAt: job.endedAt, status: job.status, step: job.step,
    progress: job.progress, log: job.log.slice(-LOG_KEPT), error: job.error, result: job.result,
  };
}

function changed() {
  emitter.emit('change', view(current || last));
}

/**
 * Lance une opération ; `work(job)` est une fonction asynchrone qui renvoie son résultat ou lève une erreur.
 * @returns {{ ok: boolean, error?: string }}
 */
function run(kind, actor, work) {
  if (current) return { ok: false, error: 'job_running' };
  const job = {
    kind, actor, startedAt: Date.now(), endedAt: null, status: 'running', step: '', progress: null, log: [], error: null, result: null,
    /** Nouvelle étape (affichée et inscrite au journal de l'opération). */
    stepTo(step, text) {
      job.step = step;
      job.progress = null;
      job.say(text);
    },
    say(text) {
      if (!text) return;
      job.log.push({ at: Date.now(), text });
      if (job.log.length > LOG_KEPT * 2) job.log.splice(0, job.log.length - LOG_KEPT);
      changed();
    },
    /** Progression d'un téléchargement (annoncée au plus quelques fois par seconde par le téléchargement lui-même). */
    track(received, total) {
      job.progress = { received, total };
      changed();
    },
  };
  current = job;
  journal.record(actor, `${kind}_started`);
  changed();
  Promise.resolve()
    .then(() => work(job))
    .then((result) => {
      job.status = 'done';
      job.result = result || null;
      journal.record(actor, `${kind}_done`, result && result.summary ? { résumé: result.summary } : null);
      // une mise à jour qui part redémarrer la Chancellerie s'annoncera quand celle-ci aura fini le contrôle
      if (kind === 'update' && !(result && result.restartPanel)) notices.emit('update', { ok: true, summary: result && result.summary });
    })
    .catch((error) => {
      job.status = 'failed';
      job.error = { code: error.code || 'failed', detail: String(error.detail || error.message || '').slice(0, 500) };
      job.say(`Échec : ${job.error.detail}`);
      journal.record(actor, `${kind}_failed`, { erreur: job.error.detail.slice(0, 200) });
      if (kind === 'update') notices.emit('update', { ok: false, code: job.error.code });
    })
    .finally(() => {
      job.endedAt = Date.now();
      job.progress = null;
      last = job;
      current = null;
      changed();
    });
  return { ok: true };
}

module.exports = {
  run,
  busy: () => current !== null,
  current: () => view(current || last),
  on: (event, callback) => emitter.on(event, callback),
};
