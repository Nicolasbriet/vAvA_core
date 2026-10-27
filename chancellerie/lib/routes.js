'use strict';
/*
 * lib/routes.js
 * Rôle : l'API de la Chancellerie. Chaque route déclare si elle demande une connexion, et quel droit (du panneau,
 *        compte maître, rang du Conseil). Toute requête qui modifie quelque chose doit venir de la Chancellerie
 *        elle-même (en-tête et origine) ; les connexions et le code d'accès sont limités en débit. Les évènements
 *        du pont du serveur de jeu n'ont ni session ni cookie : la machine et la clé du lancement. Les secrets du
 *        server.cfg ne sortent jamais : l'interface sait seulement s'ils sont renseignés. Comptes et royaume :
 *        lib/routes-accounts.js et lib/routes-game.js.
 */

const fs = require('fs');
const path = require('path');
const accounts = require('./accounts');
const bridge = require('./bridge');
const config = require('./config');
const dbprobe = require('./dbprobe');
const events = require('./events');
const journal = require('./journal');
const pin = require('./pin');
const resources = require('./resources');
const security = require('./security');
const servercfg = require('./servercfg');
const sessions = require('./sessions');
const status = require('./status');
const { sendJson, readJson } = require('./http');
const { redact, STATES } = require('./process');
const { register: registerAccounts } = require('./routes-accounts');
const { register: registerGame } = require('./routes-game');

const COMMAND_MAX = 500;
const PATH_MAX = 400;
const JOURNAL_COUNT = 50;
const CONTROL_CHARS = /[\x00-\x1f\x7f]/;
// fermer le serveur par la console sauterait la sauvegarde des personnages : c'est le rôle du bouton Arrêter
const QUIT_COMMAND = /^\s*(quit|exit)\b/i;
const EXECUTABLES = process.platform === 'win32' ? ['fxserver.exe'] : ['run.sh', 'fxserver'];
const HOST_PATTERN = /^[A-Za-z0-9.-]{1,253}$/;

const limits = {
  api: security.limiter(120, 30),
  auth: security.limiter(5, 1 / 20),
  probe: security.limiter(5, 1 / 5),
  command: security.limiter(10, 2),
  game: security.limiter(30, 10),
  // caméras : un mur 4 × 4 en ouvre seize d'un coup (demande et réponse pour chacune)
  camera: security.limiter(60, 20),
  // son propre mot de passe : l'ancien se devine à ce rythme-là au plus
  password: security.limiter(5, 1 / 20),
};

let creatingMaster = false;
let cfgCache = { file: '', mtime: 0, values: null };

/** Ce que l'interface peut savoir du server.cfg (sans les secrets), relu seulement s'il a changé. */
function cfgValues() {
  const file = config.cfgPath();
  let mtime = 0;
  try {
    mtime = fs.statSync(file).mtimeMs;
  } catch (error) {
    return null;
  }
  if (cfgCache.file !== file || cfgCache.mtime !== mtime) cfgCache = { file, mtime, values: servercfg.read(file).values };
  return cfgCache.values;
}

function cookie(token, maxAge) {
  const parts = [`${sessions.COOKIE}=${token}`, 'HttpOnly', 'SameSite=Strict', 'Path=/', `Max-Age=${maxAge}`];
  if (config.get().http.secureCookies) parts.push('Secure');
  return parts.join('; ');
}

const ok = (body = {}, headers) => ({ status: 200, body: { ok: true, ...body }, headers });
const fail = (status, error, extra = {}) => ({ status, body: { ok: false, error, ...extra } });

/** Nom saisi à la connexion, réduit à ce qu'un identifiant peut contenir (journal). */
const cleanName = (name) => String(name || '').replace(/[^A-Za-z0-9_.-]/g, '').slice(0, 32);

function isFile(file) {
  try {
    return fs.statSync(file).isFile();
  } catch (error) {
    return false;
  }
}

function isDirectory(dir) {
  try {
    return fs.statSync(dir).isDirectory();
  } catch (error) {
    return false;
  }
}

/** Exécutable de serveur accepté : FXServer lui-même (et, pour les tests, un faux serveur en JavaScript). */
function acceptedExecutable(file) {
  const name = path.basename(file).toLowerCase();
  return EXECUTABLES.includes(name) || (process.env.CHANCELLERIE_TEST === '1' && name.endsWith('.js'));
}

/** Ressources cochées par défaut sur un serveur neuf : celles de vAvA présentes, dans leur ordre. */
function defaultSelection(found) {
  const names = new Set(found.map((resource) => resource.name));
  return resources.KNOWN_ORDER.filter((name) => names.has(name));
}

/**
 * @param {import('./process').ServerProcess} server
 */
function createRouter(server) {
  const table = new Map();
  const route = (method, pathname, options, handler) => table.set(`${method} ${pathname}`, { ...options, handler });

  function assistantView() {
    const settings = config.get();
    const serverDataPath = settings.serverDataPath || config.guessServerDataPath();
    const view = {
      setupDone: settings.setupDone,
      running: server.child !== null,
      paths: { serverDataPath, fxserverPath: settings.fxserverPath || config.guessFxserverPath(serverDataPath), saved: Boolean(settings.serverDataPath && settings.fxserverPath) },
      cfg: null, cfgExists: false, hasLicenseKey: false, hasDbPassword: false, resources: [], knownOrder: resources.KNOWN_ORDER,
    };
    if (!view.paths.saved) return view;
    const current = servercfg.read(config.cfgPath());
    const found = resources.scan(settings.serverDataPath);
    const names = new Set(found.map((resource) => resource.name));
    // ressources demandées par le fichier mais introuvables : montrées pour pouvoir les retirer
    const missing = current.values.resources.filter((name) => !names.has(name)).map((name) => ({ name, category: '', description: '', missing: true }));
    return {
      ...view,
      cfg: { ...current.values, resources: current.exists ? current.values.resources : defaultSelection(found) },
      cfgExists: current.exists,
      hasLicenseKey: Boolean(current.secrets.licenseKey),
      hasDbPassword: Boolean(current.secrets.dbPassword),
      resources: [...found, ...missing],
    };
  }

  async function serverView() {
    const values = cfgValues();
    const settings = config.get();
    const running = server.state === STATES.RUNNING;
    const players = running && values ? await status.players({ bind: values.bind, port: values.port }) : null;
    return {
      ...server.status(),
      setupDone: settings.setupDone,
      hostname: values ? values.hostname : '',
      maxClients: values ? values.maxClients : 0,
      port: values ? values.port : 0,
      players,
    };
  }

  // Accès ----------------------------------------------------------------------------------------------------------

  route('GET', '/api/state', {}, (ctx) => ok({
    phase: accounts.count() === 0 ? 'pin' : ctx.account ? 'ready' : 'login',
    account: ctx.account,
    setupDone: config.get().setupDone,
    version: config.VERSION,
    pinDigits: pin.DIGITS,
  }));

  route('POST', '/api/setup/master', { limit: 'auth' }, async (ctx) => {
    if (accounts.count() > 0 || creatingMaster) return fail(409, 'already_done');
    if (!pin.check(ctx.body.pin)) return fail(403, 'bad_pin');
    creatingMaster = true;
    try {
      const result = await accounts.create(ctx.body.name, ctx.body.password, { master: true });
      if (!result.ok) return fail(400, result.error);
      pin.clear();
      journal.record(result.account.name, 'master_created');
      const token = sessions.create(result.account.name);
      return ok({ account: result.account }, { 'Set-Cookie': cookie(token, sessions.MAX_AGE_S) });
    } finally {
      creatingMaster = false;
    }
  });

  route('POST', '/api/login', { limit: 'auth' }, async (ctx) => {
    const account = await accounts.verify(ctx.body.name, ctx.body.password);
    if (!account) {
      journal.record(cleanName(ctx.body.name) || '?', 'login_failed');
      return fail(401, 'bad_credentials');
    }
    journal.record(account.name, 'login');
    const token = sessions.create(account.name);
    return ok({ account }, { 'Set-Cookie': cookie(token, sessions.MAX_AGE_S) });
  });

  route('POST', '/api/logout', { auth: true }, (ctx) => {
    sessions.destroy(ctx.token);
    events.closeSession(ctx.token);
    journal.record(ctx.account.name, 'logout');
    return ok({}, { 'Set-Cookie': cookie('', 0) });
  });

  // Assistant ------------------------------------------------------------------------------------------------------

  route('GET', '/api/assistant', { auth: true, permission: 'config' }, () => ok(assistantView()));

  route('POST', '/api/assistant/paths', { auth: true, permission: 'config' }, (ctx) => {
    const { serverDataPath, fxserverPath } = ctx.body;
    if (server.child) return fail(409, 'server_running');
    if (typeof serverDataPath !== 'string' || serverDataPath.length > PATH_MAX || !path.isAbsolute(serverDataPath)
      || !isDirectory(path.join(serverDataPath, 'resources'))) return fail(400, 'server_folder_invalid', { field: 'serverDataPath' });
    if (typeof fxserverPath !== 'string' || fxserverPath.length > PATH_MAX || !path.isAbsolute(fxserverPath)
      || !isFile(fxserverPath) || !acceptedExecutable(fxserverPath)) return fail(400, 'fxserver_invalid', { field: 'fxserverPath' });
    config.update({ serverDataPath: path.resolve(serverDataPath), fxserverPath: path.resolve(fxserverPath) });
    journal.record(ctx.account.name, 'paths', { serverDataPath: path.resolve(serverDataPath) });
    return ok(assistantView());
  });

  route('POST', '/api/assistant/dbcheck', { auth: true, permission: 'config', limit: 'probe' }, async (ctx) => {
    const { host, port } = ctx.body;
    if (typeof host !== 'string' || !HOST_PATTERN.test(host) || !Number.isInteger(port) || port < 1 || port > 65535) return fail(400, 'invalid');
    const result = await dbprobe.probe(host, port);
    return result.ok ? ok({ version: result.version }) : fail(200, result.error);
  });

  route('POST', '/api/assistant/save', { auth: true, permission: 'config' }, (ctx) => {
    const settings = config.get();
    if (!settings.serverDataPath || !settings.fxserverPath) return fail(409, 'paths_missing');
    const file = config.cfgPath();
    const previous = servercfg.read(file);
    const known = new Set([...resources.scan(settings.serverDataPath).map((r) => r.name), ...previous.values.resources]);
    const result = servercfg.validate(ctx.body.form, previous.secrets, known);
    if (!result.ok) return fail(400, result.error, { field: result.field });
    result.values.resources = resources.order(result.values.resources);
    const backup = servercfg.write(file, servercfg.generate(result.values, result.secrets));
    config.update({ setupDone: true });
    journal.record(ctx.account.name, 'cfg_written', { backup });
    let started = false;
    if (ctx.body.start === true && !server.child && ctx.account.permissions.includes('server')) {
      started = server.start(ctx.account.name).ok;
    }
    return ok({ backup, started, restartNeeded: server.child !== null && !started });
  });

  // Serveur --------------------------------------------------------------------------------------------------------

  route('GET', '/api/server', { auth: true }, async () => ok(await serverView()));

  route('POST', '/api/server/start', { auth: true, permission: 'server' }, (ctx) => {
    const result = server.start(ctx.account.name);
    status.reset();
    return result.ok ? ok() : fail(409, result.error);
  });

  route('POST', '/api/server/stop', { auth: true, permission: 'server' }, (ctx) => {
    if (!server.child && server.state !== STATES.CRASHED) return fail(409, 'not_running');
    // l'arrêt prend jusqu'à quelques dizaines de secondes : l'interface le suit par le flux d'évènements
    server.stop(ctx.account.name).catch((error) => server.system(`Arrêt : ${error.message}`));
    status.reset();
    return ok();
  });

  route('POST', '/api/server/restart', { auth: true, permission: 'server' }, (ctx) => {
    const problem = server.checkSetup();
    if (problem) return fail(409, problem);
    server.restart(ctx.account.name).catch((error) => server.system(`Redémarrage : ${error.message}`));
    status.reset();
    return ok();
  });

  // Console --------------------------------------------------------------------------------------------------------

  route('GET', '/api/events', { auth: true, stream: true }, (ctx) => {
    const canReadConsole = ctx.account.permissions.includes('console');
    if (!events.open(ctx.req, ctx.res, ctx.token, ctx.account.name, canReadConsole, server)) return fail(429, 'too_many_streams');
    return null;
  });

  route('POST', '/api/console/command', { auth: true, permission: 'console', limit: 'command', limitBy: 'token' }, (ctx) => {
    const command = ctx.body.command;
    if (typeof command !== 'string' || !command.trim() || command.length > COMMAND_MAX || CONTROL_CHARS.test(command)) return fail(400, 'invalid');
    if (QUIT_COMMAND.test(command)) return fail(400, 'use_stop_button');
    const result = server.command(command.trim(), ctx.account.name);
    if (!result.ok) return fail(409, result.error);
    journal.record(ctx.account.name, 'command', { command: redact(command.trim()) });
    return ok();
  });

  route('GET', '/api/journal', { auth: true }, () => ok({ entries: journal.latest(JOURNAL_COUNT) }));

  // Comptes et royaume ---------------------------------------------------------------------------------------------

  const endpoint = () => {
    const values = cfgValues();
    return values ? { bind: values.bind, port: values.port } : null;
  };
  registerAccounts(route, { ok, fail });
  registerGame(route, { ok, fail, endpoint, server });

  // Aiguillage -----------------------------------------------------------------------------------------------------

  async function bodyOf(req, res) {
    if (req.method !== 'POST') return {};
    const parsed = await readJson(req);
    if (parsed.error) {
      sendJson(res, parsed.error === 'too_large' ? 413 : 400, { ok: false, error: parsed.error });
      return null;
    }
    return parsed.value;
  }

  return async function handleApi(req, res, pathname) {
    const ip = req.socket.remoteAddress || '';
    const spec = table.get(`${req.method} ${pathname}`);
    // le pont du serveur de jeu : ni session ni cookie, mais la machine et la clé du lancement
    if (spec && spec.bridge) {
      if (!bridge.verify(req)) return sendJson(res, 403, { ok: false, error: 'forbidden' });
      const body = await bodyOf(req, res);
      if (!body) return undefined;
      const result = await spec.handler({ req, res, body });
      return sendJson(res, result.status, result.body);
    }
    if (!limits.api(ip)) return sendJson(res, 429, { ok: false, error: 'rate_limited' });
    if (!spec) return sendJson(res, 404, { ok: false, error: 'not_found' });
    if (req.method !== 'GET' && !security.sameOrigin(req)) return sendJson(res, 403, { ok: false, error: 'csrf' });
    const token = security.parseCookies(req.headers.cookie)[sessions.COOKIE];
    // un flux ouvert ne prolonge pas la session : seules les vraies actions le font
    const session = spec.stream ? sessions.peek(token) : sessions.get(token);
    const account = session ? accounts.get(session.name) : null;
    if (session && !account) sessions.destroy(token);
    if (spec.auth && !account) return sendJson(res, 401, { ok: false, error: 'not_logged_in' });
    if (spec.permission && !account.permissions.includes(spec.permission)) return sendJson(res, 403, { ok: false, error: 'forbidden' });
    if (spec.master && !account.master) return sendJson(res, 403, { ok: false, error: 'forbidden' });
    if (spec.rank && !account.rank) return sendJson(res, 403, { ok: false, error: 'no_rank' });
    if (spec.limit && !limits[spec.limit](spec.limitBy === 'token' ? token : ip)) return sendJson(res, 429, { ok: false, error: 'rate_limited' });
    const body = await bodyOf(req, res);
    if (!body) return undefined;
    const result = await spec.handler({ req, res, ip, token, account, body });
    if (result) sendJson(res, result.status, result.body, result.headers);
    return undefined;
  };
}

module.exports = { createRouter };
