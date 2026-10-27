'use strict';
/*
 * lib/routes-updates.js
 * Rôle : installation et mises à jour. L'assistant (droit « configuration ») installe un nouveau serveur (FXServer,
 *        oxmysql, vAvA) ou complète un serveur existant, et crée la base de données ; l'avancée de l'opération arrive
 *        en direct (évènement « job »). Les mises à jour se vérifient pour tout compte connecté ; seul le compte maître
 *        les applique et règle leur suivi.
 */

const fs = require('fs');
const path = require('path');
const backups = require('./backups');
const config = require('./config');
const events = require('./events');
const installer = require('./installer');
const jobs = require('./jobs');
const servercfg = require('./servercfg');

const PATH_MAX = 300;
const HOST_PATTERN = /^[A-Za-z0-9.-]{1,253}$/;
const DATABASE_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;
const USER_PATTERN = /^[^\s"]{1,64}$/;
const CHANNELS = new Set(['commits', 'releases']);

/**
 * @param {Function} route
 * @param {{ ok: Function, fail: Function, server: import('./process').ServerProcess, updates: import('./updates').Updates }} deps
 */
function register(route, { ok, fail, server, updates }) {
  jobs.on('change', (job) => events.broadcast('job', job));
  updates.on('check', () => events.broadcast('update', updates.view()));

  route('GET', '/api/jobs/current', { auth: true }, () => ok({ job: jobs.current() }));

  // Installation ---------------------------------------------------------------------------------------------------

  route('GET', '/api/install/options', { auth: true, permission: 'config' }, async () => {
    let recommended = null;
    try {
      recommended = await installer.recommendedFxserver();
    } catch (error) {
      recommended = null;
    }
    return ok({ defaultBase: path.dirname(config.HOME), recommended, repo: config.get().updates.repo, platform: process.platform });
  });

  route('POST', '/api/install/start', { auth: true, permission: 'config' }, (ctx) => {
    const { mode, base } = ctx.body;
    if (server.child) return fail(409, 'server_running');
    if (mode === 'new') {
      if (typeof base !== 'string' || base.length > PATH_MAX || !path.isAbsolute(base)) return fail(400, 'invalid', { field: 'base' });
      const resolved = path.resolve(base);
      // jamais dans le dossier de la Chancellerie (une mise à jour de celle-ci l'emporterait)
      if (resolved === config.HOME || resolved.startsWith(config.HOME + path.sep)) return fail(400, 'base_inside_panel', { field: 'base' });
      try {
        fs.mkdirSync(resolved, { recursive: true });
      } catch (error) {
        return fail(400, 'base_unwritable', { field: 'base' });
      }
      const result = updates.install(ctx.account.name, { mode, base: resolved });
      return result.ok ? ok({ job: jobs.current() }) : fail(409, result.error);
    }
    if (mode === 'existing') {
      const settings = config.get();
      if (!settings.serverDataPath || !settings.fxserverPath) return fail(409, 'paths_missing');
      const result = updates.install(ctx.account.name, { mode, serverDataPath: settings.serverDataPath, fxserverPath: settings.fxserverPath });
      return result.ok ? ok({ job: jobs.current() }) : fail(409, result.error);
    }
    return fail(400, 'invalid');
  });

  route('POST', '/api/assistant/dbcreate', { auth: true, permission: 'config', limit: 'probe' }, async (ctx) => {
    const { host, port, user, password, database } = ctx.body;
    if (typeof host !== 'string' || !HOST_PATTERN.test(host) || !Number.isInteger(port) || port < 1 || port > 65535) return fail(400, 'invalid', { field: 'db.host' });
    if (typeof user !== 'string' || !USER_PATTERN.test(user)) return fail(400, 'invalid', { field: 'db.user' });
    if (typeof database !== 'string' || !DATABASE_PATTERN.test(database)) return fail(400, 'invalid', { field: 'db.database' });
    if (typeof password !== 'string' || password.length > 200) return fail(400, 'invalid', { field: 'db.password' });
    // champ laissé vide : le mot de passe déjà dans le server.cfg
    const current = servercfg.current();
    const secret = password || (current ? current.secrets.dbPassword : '');
    const result = await backups.createDatabase({ host, port, user, password: secret, database });
    return result.ok ? ok() : fail(200, result.error, { detail: result.detail });
  });

  // Mises à jour ---------------------------------------------------------------------------------------------------

  route('GET', '/api/updates', { auth: true }, () => ok(updates.view()));

  route('POST', '/api/updates/check', { auth: true, limit: 'probe' }, async () => {
    await updates.check();
    return ok(updates.view());
  });

  route('POST', '/api/updates/apply', { auth: true, master: true }, (ctx) => {
    const { backupDb, delayMin } = ctx.body;
    if (typeof backupDb !== 'boolean' || !Number.isInteger(delayMin)) return fail(400, 'invalid');
    if (updates.blocked().length) return fail(409, 'git_checkout');
    const result = updates.apply(ctx.account.name, { backupDb, delayMin });
    return result.ok ? ok({ job: jobs.current() }) : fail(409, result.error);
  });

  route('POST', '/api/updates/settings', { auth: true, master: true }, async (ctx) => {
    const { channel, autoCheck, applyAtRestart } = ctx.body;
    if (!CHANNELS.has(channel) || typeof autoCheck !== 'boolean' || typeof applyAtRestart !== 'boolean') return fail(400, 'invalid');
    const changedChannel = channel !== config.get().updates.channel;
    config.update({ updates: { channel, autoCheck, applyAtRestart } });
    // autre canal : autre « dernière version »
    if (changedChannel) await updates.check();
    return ok(updates.view());
  });
}

module.exports = { register };
