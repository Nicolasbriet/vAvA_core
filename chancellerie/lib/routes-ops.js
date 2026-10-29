'use strict';
/*
 * lib/routes-ops.js
 * Rôle : l'exploitation du serveur. Performances (historiques et relevé courant) pour tout compte connecté ;
 *        ressources (état en direct, démarrer, arrêter, redémarrer, relire le dossier) au droit « serveur », leur
 *        lancement au démarrage au droit « configuration » ; éditeur du server.cfg brut (secrets masqués, révision
 *        vérifiée) et sauvegardes du server.cfg au droit « configuration » ; sauvegardes de la base au droit
 *        « sauvegardes » ; redémarrages planifiés au droit « serveur ». Tout changement est inscrit au journal.
 */

const fs = require('fs');
const backups = require('./backups');
const config = require('./config');
const events = require('./events');
const jobs = require('./jobs');
const journal = require('./journal');
const resources = require('./resources');
const servercfg = require('./servercfg');
const status = require('./status');
const { cores, scope } = require('./metrics');
const { STATES } = require('./process');
const { validateRestarts, validateBackupTimes } = require('./scheduler');

const RESOURCE_ACTIONS = new Set(['start', 'stop', 'restart', 'ensure']);
// une ressource ajoutée au dossier n'est connue de FXServer qu'après « refresh »
const NEEDS_REFRESH = new Set(['start', 'restart', 'ensure']);
const CFG_MAX = 48 * 1024;
const PATH_MAX = 400;

/** Paramètre d'adresse (?name=…). */
function query(req, name) {
  try {
    return new URL(req.url, 'http://chancellerie').searchParams.get(name) || '';
  } catch (error) {
    return '';
  }
}

/**
 * @param {Function} route
 * @param {{ ok: Function, fail: Function, server: import('./process').ServerProcess,
 *   metrics: import('./metrics').Metrics, scheduler: import('./scheduler').Scheduler }} deps
 */
function register(route, { ok, fail, server, metrics, scheduler }) {
  metrics.on('sample', (sample) => events.broadcast('metrics', sample));
  backups.db.events.on('change', (state) => events.broadcast('backup', state));

  // Performances ---------------------------------------------------------------------------------------------------

  route('GET', '/api/metrics', { auth: true }, (ctx) => ok({
    ...metrics.history(query(ctx.req, 'range') === 'day' ? 'day' : 'hour'),
    cores: Math.round(cores() * 100) / 100,
    scope: scope(),
    latest: metrics.latest(),
  }));

  // Ressources -----------------------------------------------------------------------------------------------------

  async function resourceView() {
    const settings = config.get();
    const found = settings.serverDataPath ? resources.scan(settings.serverDataPath, { details: true }) : [];
    const running = server.state === STATES.RUNNING || server.state === STATES.STARTING;
    const endpoint = servercfg.endpoint();
    const started = running && endpoint ? await status.started(endpoint) : null;
    const startedSet = new Set(started || []);
    let cfgText = '';
    try {
      cfgText = fs.readFileSync(config.cfgPath(), 'utf8');
    } catch (error) {
      cfgText = '';
    }
    const names = new Set(found.map((r) => r.name));
    // lancées par FXServer sans être dans le dossier (ressources du système de FXServer, de txAdmin…)
    const outside = [...startedSet].filter((name) => !names.has(name)).map((name) => ({
      name, category: '', description: '', version: '', author: '', folder: '', outside: true,
    }));
    return {
      running,
      live: started !== null,
      cfgExists: Boolean(cfgText),
      resources: [...found, ...outside].map((resource) => ({
        ...resource,
        started: started === null ? null : startedSet.has(resource.name),
        autostart: servercfg.isAutostart(cfgText, resource.name),
      })),
      knownOrder: resources.KNOWN_ORDER,
    };
  }

  route('GET', '/api/resources', { auth: true }, async () => ok(await resourceView()));

  route('POST', '/api/resources/action', { auth: true, permission: 'server', limit: 'command', limitBy: 'token' }, async (ctx) => {
    const { name, action } = ctx.body;
    if (!RESOURCE_ACTIONS.has(action) || typeof name !== 'string' || !servercfg.RESOURCE_PATTERN.test(name)) return fail(400, 'invalid');
    if (jobs.busy()) return fail(409, 'job_running');
    if (!server.child) return fail(409, 'not_running');
    const view = await resourceView();
    if (!view.resources.some((r) => r.name === name)) return fail(400, 'unknown_resource');
    if (NEEDS_REFRESH.has(action)) server.command('refresh', ctx.account.name);
    const result = server.command(`${action} ${name}`, ctx.account.name);
    if (!result.ok) return fail(409, result.error);
    status.reset();
    journal.record(ctx.account.name, 'resource_action', { ressource: name, action });
    return ok();
  });

  route('POST', '/api/resources/refresh', { auth: true, permission: 'server', limit: 'command', limitBy: 'token' }, (ctx) => {
    const result = server.command('refresh', ctx.account.name);
    if (!result.ok) return fail(409, result.error);
    journal.record(ctx.account.name, 'resource_refresh');
    return ok();
  });

  route('POST', '/api/resources/autostart', { auth: true, permission: 'config' }, (ctx) => {
    const { name, enabled } = ctx.body;
    if (typeof name !== 'string' || !servercfg.RESOURCE_PATTERN.test(name) || typeof enabled !== 'boolean') return fail(400, 'invalid');
    const file = config.cfgPath();
    if (!file || !fs.existsSync(file)) return fail(409, 'cfg_missing');
    const settings = config.get();
    if (enabled && !resources.scan(settings.serverDataPath).some((r) => r.name === name)) return fail(400, 'unknown_resource');
    const text = fs.readFileSync(file, 'utf8');
    const next = servercfg.setAutostart(text, name, enabled, resources.rank);
    if (next === text) return ok({ backup: null });
    const backup = servercfg.write(file, next);
    journal.record(ctx.account.name, 'autostart', { ressource: name, actif: enabled ? 'oui' : 'non' });
    return ok({ backup });
  });

  // server.cfg brut ------------------------------------------------------------------------------------------------

  route('GET', '/api/cfg', { auth: true, permission: 'config' }, () => {
    const file = config.cfgPath();
    if (!file) return fail(409, 'paths_missing');
    let text = '';
    let exists = true;
    try {
      text = fs.readFileSync(file, 'utf8');
    } catch (error) {
      exists = false;
    }
    const masked = servercfg.mask(text);
    return ok({ exists, text: masked.text, revision: exists ? servercfg.revision(text) : '', secrets: masked.secrets.length, file: config.get().cfgFile });
  });

  route('POST', '/api/cfg/save', { auth: true, permission: 'config' }, (ctx) => {
    const { text, revision } = ctx.body;
    if (typeof text !== 'string' || text.length > CFG_MAX || text.includes('\0') || typeof revision !== 'string') return fail(400, 'invalid');
    const file = config.cfgPath();
    if (!file) return fail(409, 'paths_missing');
    let previous = '';
    try {
      previous = fs.readFileSync(file, 'utf8');
    } catch (error) {
      previous = '';
    }
    // le fichier a changé depuis son ouverture dans l'éditeur (assistant, autre onglet, à la main)
    if ((previous ? servercfg.revision(previous) : '') !== revision) return fail(409, 'cfg_changed');
    const restored = servercfg.unmask(text, servercfg.mask(previous).secrets);
    if (restored === null) return fail(400, 'unknown_secret');
    const backup = servercfg.write(file, restored);
    journal.record(ctx.account.name, 'cfg_edited', { backup });
    return ok({ backup, revision: servercfg.revision(restored), restartNeeded: server.child !== null });
  });

  // Sauvegardes du server.cfg --------------------------------------------------------------------------------------

  route('GET', '/api/backups/cfg', { auth: true, permission: 'config' }, () => ok({ backups: backups.cfg.list() }));

  route('GET', '/api/backups/cfg/view', { auth: true, permission: 'config' }, (ctx) => {
    const text = backups.cfg.view(query(ctx.req, 'name'));
    return text === null ? fail(404, 'unknown_backup') : ok({ text });
  });

  route('POST', '/api/backups/cfg/restore', { auth: true, permission: 'config' }, (ctx) => {
    const result = backups.cfg.restore(ctx.body.name);
    if (!result.ok) return fail(400, result.error);
    journal.record(ctx.account.name, 'cfg_restored', { fichier: ctx.body.name, backup: result.backup });
    return ok({ backup: result.backup, restartNeeded: server.child !== null });
  });

  // Sauvegardes de la base -----------------------------------------------------------------------------------------

  const dbView = () => ({ backups: backups.db.list(), status: backups.db.status(), times: config.get().schedule.backups, nextAt: scheduler.backupAt });

  route('GET', '/api/backups/db', { auth: true, permission: 'backups' }, () => ok(dbView()));

  route('POST', '/api/backups/db/create', { auth: true, permission: 'backups' }, (ctx) => {
    const result = backups.db.create(ctx.account.name);
    return result.ok ? ok(dbView()) : fail(409, result.error);
  });

  route('POST', '/api/backups/db/delete', { auth: true, permission: 'backups' }, (ctx) => {
    const result = backups.db.remove(ctx.body.name);
    if (!result.ok) return fail(400, result.error);
    journal.record(ctx.account.name, 'backup_deleted', { fichier: ctx.body.name });
    return ok(dbView());
  });

  route('POST', '/api/backups/db/settings', { auth: true, permission: 'backups' }, (ctx) => {
    const { dumpPath, keep, times } = ctx.body;
    if (typeof dumpPath !== 'string' || dumpPath.length > PATH_MAX) return fail(400, 'invalid', { field: 'dumpPath' });
    if (dumpPath && !backups.db.acceptedTool(dumpPath)) return fail(400, 'dump_tool_invalid', { field: 'dumpPath' });
    if (!Number.isInteger(keep) || keep < backups.db.KEEP_MIN || keep > backups.db.KEEP_MAX) return fail(400, 'invalid', { field: 'keep' });
    const cleanTimes = validateBackupTimes(times);
    if (!cleanTimes) return fail(400, 'invalid', { field: 'times' });
    config.update({ backups: { dumpPath, keep } });
    scheduler.setBackups(cleanTimes, ctx.account.name);
    journal.record(ctx.account.name, 'backup_settings', { garder: keep, outil: dumpPath || 'automatique' });
    return ok(dbView());
  });

  // téléchargement : le fichier part tel quel, en pièce jointe (lien ouvert par le navigateur, cookie de session)
  route('GET', '/api/backups/db/download', { auth: true, permission: 'backups' }, (ctx) => {
    const name = query(ctx.req, 'name');
    const file = backups.db.file(name);
    if (!file) return fail(404, 'unknown_backup');
    journal.record(ctx.account.name, 'backup_downloaded', { fichier: name });
    ctx.res.writeHead(200, {
      'Content-Type': 'application/gzip',
      'Content-Length': fs.statSync(file).size,
      'Content-Disposition': `attachment; filename="${name}"`,
      'Cache-Control': 'no-store',
    });
    fs.createReadStream(file).on('error', () => ctx.res.destroy()).pipe(ctx.res);
    return null;
  });

  // Planification --------------------------------------------------------------------------------------------------

  route('GET', '/api/schedule', { auth: true }, () => ok({ schedule: scheduler.status() }));

  route('POST', '/api/schedule/restarts', { auth: true, permission: 'server' }, (ctx) => {
    const result = validateRestarts(ctx.body);
    if (result.error) return fail(400, result.error, { field: result.field });
    return ok({ schedule: scheduler.setRestarts(result.value, ctx.account.name) });
  });

  route('POST', '/api/schedule/skip', { auth: true, permission: 'server' }, (ctx) => {
    if (typeof ctx.body.skip !== 'boolean') return fail(400, 'invalid');
    const result = scheduler.skipNext(ctx.body.skip, ctx.account.name);
    return result.ok ? ok({ schedule: result.status }) : fail(409, result.error);
  });
}

module.exports = { register };
