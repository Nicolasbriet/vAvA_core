'use strict';
/*
 * lib/scheduler.js
 * Rôle : ce qui revient chaque jour à heure fixe (heure de la machine) : redémarrages du serveur et sauvegardes de
 *        la base. Avant un redémarrage, les joueurs sont prévenus par une proclamation du Registre du Conseil (au nom
 *        de la Chancellerie, inscrite au journal du Conseil), aux délais choisis ; le prochain redémarrage peut être
 *        sauté une fois. Un serveur arrêté n'est jamais lancé par un redémarrage planifié. Une échéance manquée de
 *        plus de quelques minutes (machine en veille) est passée, pas rattrapée. Si une mise à jour de vAvA attend et
 *        que c'est demandé, le redémarrage planifié l'applique.
 */

const backups = require('./backups');
const jobs = require('./jobs');
const notices = require('./notices');
const bridge = require('./bridge');
const config = require('./config');
const journal = require('./journal');
const servercfg = require('./servercfg');
const { STATES } = require('./process');

const TICK_MS = 10000;
const MISSED_MS = 5 * 60000;
const TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;
const TIMES_MAX = 12;
const WARNINGS_MAX = 6;
const WARNING_MAX_MIN = 60;
const MESSAGE_MAX = 200;

/** Prochaine échéance (ms) strictement après `from`, pour des heures « HH:MM » ; null s'il n'y en a aucune. */
function nextOccurrence(times, from) {
  let best = null;
  for (const time of times) {
    const match = TIME_PATTERN.exec(time);
    if (!match) continue;
    const date = new Date(from);
    date.setHours(Number(match[1]), Number(match[2]), 0, 0);
    if (date.getTime() <= from) date.setDate(date.getDate() + 1);
    if (best === null || date.getTime() < best) best = date.getTime();
  }
  return best;
}

/** Message d'avertissement : celui choisi ({minutes} remplacé), sinon la phrase par défaut. */
function warningText(template, minutes) {
  const words = `${minutes} minute${minutes > 1 ? 's' : ''}`;
  if (template) return template.split('{minutes}').join(String(minutes));
  return `Le royaume se refermera dans ${words} : le serveur redémarre. Mettez vos affaires en sûreté.`;
}

/**
 * Réglages reçus du navigateur, nettoyés ; renvoie { value } ou { error, field }.
 * @param {object} input  { restarts: string[], warnings: number[], message: string }
 */
function validateRestarts(input) {
  const body = input || {};
  if (!Array.isArray(body.restarts) || body.restarts.length > TIMES_MAX || body.restarts.some((t) => typeof t !== 'string' || !TIME_PATTERN.test(t))) {
    return { error: 'invalid', field: 'restarts' };
  }
  if (!Array.isArray(body.warnings) || body.warnings.length > WARNINGS_MAX
    || body.warnings.some((w) => !Number.isInteger(w) || w < 1 || w > WARNING_MAX_MIN)) return { error: 'invalid', field: 'warnings' };
  if (typeof body.message !== 'string' || body.message.length > MESSAGE_MAX || /[\r\n]/.test(body.message)) return { error: 'invalid', field: 'message' };
  return {
    value: {
      restarts: [...new Set(body.restarts)].sort(),
      warnings: [...new Set(body.warnings)].sort((a, b) => b - a),
      message: body.message.trim(),
    },
  };
}

function validateBackupTimes(times) {
  if (!Array.isArray(times) || times.length > TIMES_MAX || times.some((t) => typeof t !== 'string' || !TIME_PATTERN.test(t))) return null;
  return [...new Set(times)].sort();
}

class Scheduler {
  /**
   * @param {import('./process').ServerProcess} server
   * @param {import('./updates').Updates} [updates]
   */
  constructor(server, updates) {
    this.server = server;
    this.updates = updates || null;
    this.timer = null;
    this.restartAt = null;
    this.backupAt = null;
    this.warned = new Set();
  }

  settings() {
    return config.get().schedule;
  }

  /** Prochain redémarrage recalculé (réglages changés, ou échéance passée). */
  planRestart(from = Date.now()) {
    this.restartAt = nextOccurrence(this.settings().restarts, from);
    this.warned.clear();
  }

  planBackup(from = Date.now()) {
    this.backupAt = nextOccurrence(this.settings().backups, from);
  }

  start() {
    this.planRestart();
    this.planBackup();
    this.timer = setInterval(() => this.tick(), TICK_MS);
  }

  stop() {
    clearInterval(this.timer);
    this.timer = null;
  }

  skipped() {
    return this.restartAt !== null && this.settings().skip === this.restartAt;
  }

  status() {
    return { restartAt: this.restartAt, skipped: this.skipped(), backupAt: this.backupAt, ...this.settings() };
  }

  /** Change les réglages des redémarrages. */
  setRestarts(value, actor) {
    config.update({ schedule: { ...value, skip: null } });
    journal.record(actor, 'schedule_updated', { heures: value.restarts.join(', ') || '—' });
    this.planRestart();
    return this.status();
  }

  /** Change les heures des sauvegardes de la base. */
  setBackups(times, actor) {
    config.update({ schedule: { backups: times } });
    journal.record(actor, 'backup_schedule_updated', { heures: times.join(', ') || '—' });
    this.planBackup();
    return this.status();
  }

  /** Saute (ou rétablit) le prochain redémarrage. */
  skipNext(skip, actor) {
    if (this.restartAt === null) return { ok: false, error: 'no_restart_planned' };
    config.update({ schedule: { skip: skip ? this.restartAt : null } });
    journal.record(actor, skip ? 'restart_skipped' : 'restart_unskipped', { heure: new Date(this.restartAt).toLocaleString('fr-FR') });
    return { ok: true, status: this.status() };
  }

  async announce(minutes) {
    notices.emit('restart-warning', { minutes, at: this.restartAt });
    const result = await bridge.proclaim(servercfg.endpoint(), warningText(this.settings().message, minutes));
    this.server.system(result.ok
      ? `Redémarrage planifié dans ${minutes} min : les joueurs sont prévenus.`
      : `Redémarrage planifié dans ${minutes} min : les joueurs n'ont pas pu être prévenus (${result.error}).`);
  }

  /**
   * Redémarrage planifié : passé si une installation ou une mise à jour tourne ; remplacé par la mise à jour si
   * l'une attend et que c'est demandé (les joueurs ont déjà été prévenus).
   */
  restartNow() {
    if (jobs.busy()) {
      journal.record(journal.SYSTEM, 'scheduled_restart_skipped', { raison: 'opération en cours' });
      return;
    }
    const updates = this.updates;
    if (updates && config.get().updates.applyAtRestart && updates.last && updates.last.available && !updates.blocked().length) {
      journal.record(journal.SYSTEM, 'scheduled_update');
      updates.apply(journal.SYSTEM, { backupDb: true, delayMin: 0 });
      return;
    }
    journal.record(journal.SYSTEM, 'scheduled_restart');
    this.server.restart(journal.SYSTEM).catch((error) => this.server.system(`Redémarrage planifié : ${error.message}`));
  }

  tick() {
    const now = Date.now();
    const live = this.server.state === STATES.RUNNING;
    if (this.restartAt !== null) {
      if (now >= this.restartAt) {
        const due = this.restartAt;
        const skipped = this.skipped();
        this.planRestart(now);
        if (skipped) {
          config.update({ schedule: { skip: null } });
          journal.record(journal.SYSTEM, 'scheduled_restart_skipped');
        } else if (now - due <= MISSED_MS && (live || this.server.state === STATES.STARTING)) {
          this.restartNow();
        }
      } else if (live && !this.skipped()) {
        // un avertissement est donné dans la minute de son délai : jamais en retard de plus d'une minute
        for (const minutes of this.settings().warnings) {
          const at = this.restartAt - minutes * 60000;
          const key = `${this.restartAt}:${minutes}`;
          if (now >= at && now < at + 60000 && !this.warned.has(key)) {
            this.warned.add(key);
            this.announce(minutes);
          }
        }
      }
    }
    if (this.backupAt !== null && now >= this.backupAt) {
      const due = this.backupAt;
      this.planBackup(now);
      if (now - due <= MISSED_MS) {
        const result = backups.db.create(journal.SYSTEM);
        if (!result.ok) journal.record(journal.SYSTEM, 'backup_failed', { erreur: result.error });
      }
    }
  }
}

module.exports = { Scheduler, validateRestarts, validateBackupTimes, nextOccurrence, warningText };
