'use strict';
/*
 * lib/updates.js
 * Rôle : vAvA depuis GitHub. Installation (première fois) et mises à jour, comme un gestionnaire de paquets :
 *        - Vérification : dernier commit de la branche suivie (ou dernière release), à intervalle et à la demande ;
 *          commits arrivés depuis la version installée et parties touchées (modules, core, Chancellerie).
 *        - Mise à jour sans casser : sauvegarde de la base, joueurs prévenus, arrêt propre, sauvegarde des ressources
 *          touchées, fusion qui garde les réglages modifiés, relance, puis contrôle : toutes les ressources lancées
 *          avant (et prévues au server.cfg) doivent l'être après, sans arrêt imprévu. Sinon, retour à la version
 *          précédente et relance.
 *        - La Chancellerie elle-même : vérifiée avant d'être remplacée ; elle redémarre (code 75, demarrer.bat la
 *          relance) et poursuit le contrôle du serveur au démarrage suivant.
 *        Une copie suivie par git (développement) n'est jamais écrasée.
 */

const EventEmitter = require('events');
const fs = require('fs');
const path = require('path');
const backups = require('./backups');
const bridge = require('./bridge');
const config = require('./config');
const dl = require('./download');
const installer = require('./installer');
const jobs = require('./jobs');
const journal = require('./journal');
const resources = require('./resources');
const servercfg = require('./servercfg');
const status = require('./status');
const { STATES } = require('./process');

const FIRST_CHECK_MS = 30000;
const RUNNING_TIMEOUT_MS = 180000;
const RESOURCES_TIMEOUT_MS = 90000;
const STABLE_MS = 15000;
const POLL_MS = 2000;
const DELAYS = [0, 1, 5, 10];
const COMMITS_SHOWN = 30;
// code de sortie qui demande à demarrer.bat de relancer la Chancellerie
const RESTART_CODE = 75;

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const firstLine = (text) => String(text || '').split('\n')[0].slice(0, 200);

/** Partie du dépôt touchée par un fichier : nom d'un module ou d'un exemple, vAvA_core, chancellerie, ou null (docs). */
function partOf(file) {
  const [head, second] = file.split('/');
  if (head === 'chancellerie') return 'chancellerie';
  if (head === 'modules' || head === 'examples') return second || null;
  if (['docs', '.github'].includes(head) || head.startsWith('.')) return null;
  return installer.CORE;
}

class Updates extends EventEmitter {
  /** @param {import('./process').ServerProcess} server */
  constructor(server) {
    super();
    this.server = server;
    this.last = null;
    this.timer = null;
    this.checking = null;
  }

  settings() {
    return config.get().updates;
  }

  api(route) {
    return `${this.settings().api}/repos/${this.settings().repo}${route}`;
  }

  /** Dernière version publiée : { ref, label, date, message }. */
  async remoteHead() {
    const settings = this.settings();
    if (settings.channel === 'releases') {
      const release = await dl.getJson(this.api('/releases/latest'));
      return { ref: release.tag_name, label: release.tag_name, date: release.published_at, message: firstLine(release.name || release.body) };
    }
    const commit = await dl.getJson(this.api(`/commits/${encodeURIComponent(settings.branch)}`));
    return { ref: commit.sha, label: commit.sha.slice(0, 7), date: commit.commit.committer.date, message: firstLine(commit.commit.message) };
  }

  /** Commits et parties touchées entre deux versions (ou les derniers commits, sans version installée connue). */
  async changesSince(base, head) {
    const commit = (c) => ({ ref: c.sha.slice(0, 7), message: firstLine(c.commit.message), author: c.commit.author ? c.commit.author.name : '', date: c.commit.author ? c.commit.author.date : null });
    if (!base) {
      const recent = await dl.getJson(this.api(`/commits?sha=${encodeURIComponent(head)}&per_page=${COMMITS_SHOWN}`));
      return { commits: recent.map(commit), parts: null };
    }
    try {
      const compare = await dl.getJson(this.api(`/compare/${encodeURIComponent(base)}...${encodeURIComponent(head)}`));
      const parts = [...new Set((compare.files || []).map((f) => partOf(f.filename)).filter(Boolean))].sort();
      return { commits: (compare.commits || []).map(commit).reverse().slice(0, COMMITS_SHOWN), parts, total: compare.total_commits };
    } catch (error) {
      // version installée disparue du dépôt (historique réécrit) : la liste reste vide, la mise à jour reste possible
      return { commits: [], parts: null };
    }
  }

  /** Vérifie s'il existe une nouvelle version ; le résultat est gardé et annoncé. */
  async check() {
    if (this.checking) return this.checking;
    this.checking = (async () => {
      const installed = installer.state();
      const current = installed.source;
      try {
        const latest = await this.remoteHead();
        const available = !current || current.ref !== latest.ref;
        const changes = available ? await this.changesSince(current && current.ref, latest.ref) : { commits: [], parts: [] };
        this.last = { checkedAt: Date.now(), current, latest, available, ...changes, error: null };
      } catch (error) {
        this.last = { checkedAt: Date.now(), current, latest: this.last ? this.last.latest : null, available: this.last ? this.last.available : false, commits: [], parts: null, error: error.code || 'network' };
      } finally {
        this.checking = null;
      }
      this.emit('check', this.last);
      return this.last;
    })();
    return this.checking;
  }

  start() {
    const every = Math.max(10, Number(this.settings().checkEveryMin) || 60) * 60000;
    setTimeout(() => {
      if (this.settings().autoCheck) this.check();
    }, FIRST_CHECK_MS);
    this.timer = setInterval(() => {
      if (this.settings().autoCheck) this.check();
    }, every);
  }

  stop() {
    clearInterval(this.timer);
    this.timer = null;
  }

  /** Copie de développement (git) : rien ne s'y écrit. */
  blocked() {
    const settings = config.get();
    const dirs = [config.HOME];
    if (settings.serverDataPath) {
      const installed = installer.state();
      for (const name of Object.keys(installed.resources)) dirs.push(path.join(settings.serverDataPath, 'resources', installed.resources[name].folder));
      const core = resources.scan(settings.serverDataPath, { details: true }).find((r) => r.name === installer.CORE);
      if (core) dirs.push(path.join(settings.serverDataPath, 'resources', core.folder));
    }
    return dirs.filter((dir) => fs.existsSync(dir) && installer.inGitCheckout(dir));
  }

  view() {
    const installed = installer.state();
    return {
      check: this.last,
      settings: this.settings(),
      installed: { source: installed.source, oxmysql: installed.oxmysql, fxserver: installed.fxserver, panel: config.VERSION, pending: Boolean(installed.pending) },
      blocked: this.blocked(),
      job: jobs.current(),
      delays: DELAYS,
    };
  }

  // Contrôle de santé ---------------------------------------------------------------------------------------------------

  /**
   * Le serveur est-il reparti entier ? En marche, sans arrêt imprévu, avec toutes les ressources attendues lancées.
   * @returns {Promise<{ ok: boolean, detail?: string }>}
   */
  async healthy(expected, job) {
    const server = this.server;
    const runningUntil = Date.now() + RUNNING_TIMEOUT_MS;
    while (server.state !== STATES.RUNNING) {
      if (server.state === STATES.CRASHED || (server.state === STATES.STOPPED && !server.child)) return { ok: false, detail: 'FXServer s\'est arrêté pendant son démarrage' };
      if (Date.now() > runningUntil) return { ok: false, detail: 'FXServer n\'a pas fini de démarrer à temps' };
      await delay(POLL_MS / 2);
    }
    const startedAt = server.startedAt;
    const gone = () => server.state !== STATES.RUNNING || server.startedAt !== startedAt;
    job.say(`Serveur en marche ; contrôle des ressources (${expected.length})…`);
    const endpoint = servercfg.endpoint();
    let missing = expected;
    const resourcesUntil = Date.now() + RESOURCES_TIMEOUT_MS;
    while (Date.now() < resourcesUntil) {
      if (gone()) return { ok: false, detail: 'FXServer s\'est arrêté après son démarrage' };
      status.reset();
      const started = endpoint ? await status.started(endpoint) : null;
      if (started) {
        missing = expected.filter((name) => !started.includes(name));
        if (!missing.length) break;
      }
      await delay(POLL_MS);
    }
    if (missing.length) return { ok: false, detail: `ressources non lancées : ${missing.join(', ')}` };
    job.say('Toutes les ressources tournent ; quelques secondes de surveillance…');
    await delay(STABLE_MS);
    if (gone()) return { ok: false, detail: 'FXServer s\'est arrêté juste après son démarrage' };
    return { ok: true };
  }

  /** Ressources à retrouver après la mise à jour : lancées avant, et prévues au server.cfg. */
  expected(startedBefore) {
    let text = '';
    try {
      text = fs.readFileSync(config.cfgPath(), 'utf8');
    } catch (error) {
      text = '';
    }
    const names = startedBefore || [installer.CORE];
    return names.filter((name) => servercfg.isAutostart(text, name));
  }

  /** Échec du contrôle : version précédente remise, serveur relancé ; lève toujours l'erreur de l'échec. */
  async rollback(job, backupId, expected, actor, detail) {
    job.stepTo('rollback', `Contrôle échoué (${detail}) : retour à la version précédente…`);
    await this.server.stop(actor);
    installer.restoreResources(backupId);
    journal.record(actor, 'update_rolled_back', { raison: detail.slice(0, 200) });
    const start = this.server.start(actor);
    const again = start.ok ? await this.healthy(expected, job) : { ok: false };
    throw dl.failure('update_rolled_back', `${detail}. La version précédente est remise${again.ok ? ' et le serveur tourne.' : ', mais le serveur ne repart pas non plus : voyez la console.'}`);
  }

  /** Sauvegarde de la base avant de toucher à quoi que ce soit ; l'échec arrête la mise à jour. */
  async backupDatabase(job, actor) {
    if (!backups.db.status().tool) {
      job.say('mysqldump est introuvable : la base n\'est pas sauvegardée (réglable dans la page Sauvegardes).');
      return;
    }
    job.stepTo('database', 'Sauvegarde de la base de données…');
    const finished = new Promise((resolve) => {
      const listener = (state) => {
        if (state.running) return;
        backups.db.events.removeListener('change', listener);
        resolve(state);
      };
      backups.db.events.on('change', listener);
    });
    const started = backups.db.create(actor);
    if (!started.ok) throw dl.failure(started.error, 'sauvegarde de la base impossible');
    const state = await finished;
    if (!state.last || !state.last.ok) throw dl.failure('backup_failed', `sauvegarde de la base échouée : ${state.last ? state.last.detail : ''}`);
    job.say(`Base sauvegardée : ${state.last.name}.`);
  }

  // Mise à jour ---------------------------------------------------------------------------------------------------------

  /**
   * Lance la mise à jour vers la dernière version.
   * @param {{ backupDb: boolean, delayMin: number }} options
   */
  apply(actor, options) {
    if (!DELAYS.includes(options.delayMin)) return { ok: false, error: 'invalid' };
    if (!config.get().serverDataPath) return { ok: false, error: 'paths_missing' };
    return jobs.run('update', actor, (job) => this.perform(job, actor, options));
  }

  async perform(job, actor, options) {
    const server = this.server;
    const serverDataPath = config.get().serverDataPath;
    job.stepTo('check', 'Recherche de la dernière version…');
    const head = await this.remoteHead();
    job.stepTo('download', `Téléchargement de vAvA ${head.label} (${head.message})…`);
    const root = await installer.fetchSource(this.settings(), head.ref, job);
    job.stepTo('plan', 'Comparaison avec ce qui est installé…');
    const plans = installer.planResources(root, serverDataPath);
    const touched = plans.filter((p) => installer.changes(p.plan));
    const panelSource = installer.layout(root).panel;
    const panel = installer.planPanel(panelSource);
    const panelChanges = panel && !panel.empty;
    const guarded = [...touched.map((p) => p.target), ...(panelChanges ? [config.HOME] : [])].filter((dir) => fs.existsSync(dir) && installer.inGitCheckout(dir));
    if (guarded.length) throw dl.failure('git_checkout', `copie suivie par git, mise à jour refusée (utilisez git pull) : ${guarded.join(', ')}`);
    if (!touched.length && !panelChanges) {
      installer.applyResources(plans, serverDataPath, head);
      if (panelSource) installer.recordPanel(panelSource, head.ref);
      installer.cleanStaging();
      this.check();
      return { summary: `déjà à jour (${head.label})` };
    }
    job.say(`À mettre à jour : ${[...touched.map((p) => p.name), ...(panelChanges ? ['Chancellerie'] : [])].join(', ')}.`);
    if (panelChanges) {
      // avant de toucher au serveur : une Chancellerie qui ne se charge pas est refusée, rien n'est changé
      job.stepTo('panel', 'Vérification de la nouvelle Chancellerie…');
      try {
        await installer.verifyPanel(panelSource);
      } catch (error) {
        throw dl.failure('panel_invalid', `elle ne se charge pas (${error.detail || error.message}) ; rien n'a été changé`);
      }
    }

    if (options.backupDb) await this.backupDatabase(job, actor);

    const wasRunning = server.child !== null && (server.state === STATES.RUNNING || server.state === STATES.STARTING);
    let startedBefore = null;
    if (wasRunning) {
      const endpoint = servercfg.endpoint();
      startedBefore = endpoint ? await status.started(endpoint) : null;
      if (options.delayMin > 0) {
        job.stepTo('warn', `Joueurs prévenus : redémarrage dans ${options.delayMin} min.`);
        const words = `${options.delayMin} minute${options.delayMin > 1 ? 's' : ''}`;
        await bridge.proclaim(endpoint, `Le royaume se met à jour : le serveur redémarre dans ${words}. Mettez vos affaires en sûreté.`);
        await delay(options.delayMin * 60000);
      }
      job.stepTo('stop', 'Arrêt du serveur (personnages sauvegardés)…');
      await server.stop(actor);
    }
    job.stepTo('backup', 'Sauvegarde des ressources touchées…');
    const backupId = installer.backupResources(plans);
    job.stepTo('apply', 'Écriture de la nouvelle version…');
    const report = installer.applyResources(plans, serverDataPath, head);
    if (report.sideNew.length) job.say(`Réglages modifiés gardés ; nouvelle version posée à côté (.nouveau) : ${report.sideNew.join(', ')}`);
    if (report.sideLocal.length) job.say(`Fichiers modifiés remplacés ; ancienne version gardée à côté (.local) : ${report.sideLocal.join(', ')}`);
    if (report.added.length) job.say(`Nouveaux modules : ${report.added.join(', ')} (à activer dans la page Ressources).`);
    const expected = this.expected(startedBefore);
    const summary = `${head.label} : ${[...report.changed, ...report.added, ...(panelChanges ? ['Chancellerie'] : [])].join(', ') || 'rien'}`;

    if (panelChanges) {
      job.stepTo('panel', 'Écriture de la nouvelle Chancellerie…');
      installer.applyPanel(panelSource, panel, head.ref);
      const installed = installer.state();
      installed.pending = { backupId, expected, wasRunning, actor, summary };
      installer.saveState(installed);
      job.say('La Chancellerie redémarre dans sa nouvelle version ; le contrôle du serveur suivra.');
      setTimeout(() => this.emit('restart-panel'), 1500);
      return { summary, report, restartPanel: true };
    }

    if (wasRunning) {
      job.stepTo('start', 'Relance du serveur…');
      const start = server.start(actor);
      const health = start.ok ? await this.healthy(expected, job) : { ok: false, detail: start.error };
      if (!health.ok) await this.rollback(job, backupId, expected, actor, health.detail);
    } else {
      job.say('Le serveur était arrêté : il prendra la nouvelle version à son prochain démarrage.');
    }
    installer.cleanStaging();
    this.check();
    return { summary, report };
  }

  /** Au démarrage : poursuit une mise à jour interrompue par le redémarrage de la Chancellerie. */
  resume() {
    if (installer.confirmPanel()) journal.record(journal.SYSTEM, 'panel_updated', { version: config.VERSION });
    // la nouvelle version n'a pas démarré : demarrer.bat a remis celle-ci
    const reverted = installer.panelReverted();
    if (reverted) journal.record(journal.SYSTEM, 'panel_reverted', { version: config.VERSION });
    const installed = installer.state();
    const pending = installed.pending;
    if (!pending) return;
    jobs.run('update', pending.actor, async (job) => {
      job.stepTo('verify', reverted
        ? `La nouvelle Chancellerie n'a pas démarré : la ${config.VERSION} a été remise. Contrôle du serveur…`
        : `La Chancellerie ${config.VERSION} a redémarré ; contrôle du serveur…`);
      if (pending.wasRunning) {
        if (!this.server.child) this.server.start(pending.actor);
        const health = await this.healthy(pending.expected, job);
        if (!health.ok) await this.rollback(job, pending.backupId, pending.expected, pending.actor, health.detail);
      }
      const done = installer.state();
      done.pending = null;
      installer.saveState(done);
      installer.cleanStaging();
      this.check();
      if (reverted) throw dl.failure('panel_reverted', `la nouvelle Chancellerie s'est arrêtée au démarrage ; la ${config.VERSION} est remise, le serveur tourne avec les ressources à jour`);
      return { summary: pending.summary };
    });
  }

  // Installation --------------------------------------------------------------------------------------------------------

  /**
   * Première installation : FXServer (nouveau serveur), oxmysql et vAvA.
   * @param {{ mode: 'new'|'existing', base?: string, serverDataPath?: string, fxserverPath?: string }} options
   */
  install(actor, options) {
    return jobs.run('install', actor, async (job) => {
      let serverDataPath = options.serverDataPath;
      let fxserverPath = options.fxserverPath;
      if (options.mode === 'new') {
        serverDataPath = path.join(options.base, 'server-data');
        fs.mkdirSync(path.join(serverDataPath, 'resources'), { recursive: true });
        job.stepTo('fxserver', `Dossier du serveur : ${options.base}`);
        fxserverPath = await installer.installFxserver(path.join(options.base, 'server'), job);
      }
      job.stepTo('oxmysql', 'oxmysql (accès à la base de données)…');
      await installer.installOxmysql(serverDataPath, job);
      job.stepTo('download', 'Recherche de la dernière version de vAvA…');
      const head = await this.remoteHead();
      job.say(`Téléchargement de vAvA ${head.label} (${head.message})…`);
      const root = await installer.fetchSource(this.settings(), head.ref, job);
      job.stepTo('apply', 'Installation des ressources de vAvA…');
      const plans = installer.planResources(root, serverDataPath);
      const guarded = plans.filter((p) => installer.changes(p.plan) && fs.existsSync(p.target) && installer.inGitCheckout(p.target)).map((p) => p.target);
      if (guarded.length) throw dl.failure('git_checkout', `copie suivie par git, rien n'est écrit (utilisez git pull) : ${guarded.join(', ')}`);
      if (plans.some((p) => installer.changes(p.plan) && !p.isNew)) installer.backupResources(plans);
      const report = installer.applyResources(plans, serverDataPath, head);
      installer.recordPanel(installer.layout(root).panel, head.ref);
      if (report.sideNew.length) job.say(`Réglages existants gardés ; nouvelle version posée à côté (.nouveau) : ${report.sideNew.join(', ')}`);
      config.update({ serverDataPath, fxserverPath });
      installer.cleanStaging();
      this.check();
      job.say('Installation terminée : la suite de l\'assistant écrit le server.cfg.');
      return { summary: `vAvA ${head.label}`, serverDataPath, fxserverPath, report };
    });
  }
}

module.exports = { Updates, RESTART_CODE, DELAYS };
