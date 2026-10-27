'use strict';
/*
 * index.js
 * Rôle : lancement de la Chancellerie, le panneau web du serveur vAvA (comme txAdmin). Ouvre l'interface sur
 *        http://127.0.0.1:40120, affiche le lien et, au premier lancement, le code d'accès qui permet de créer le
 *        compte maître. Une fois le serveur configuré, lance FXServer et le garde en vie ; relève ses performances
 *        et tient les échéances planifiées (redémarrages, sauvegardes). Ctrl+C (ou la fermeture de la fenêtre)
 *        arrête d'abord FXServer proprement.
 * Aucune dépendance : seulement les modules livrés avec Node.js.
 */

const config = require('./lib/config');
const accounts = require('./lib/accounts');
const bridge = require('./lib/bridge');
const events = require('./lib/events');
const journal = require('./lib/journal');
const pin = require('./lib/pin');
const { createServer } = require('./lib/http');
const { createRouter } = require('./lib/routes');
const { ServerProcess } = require('./lib/process');
const { Metrics } = require('./lib/metrics');
const { Scheduler } = require('./lib/scheduler');
const { Updates, RESTART_CODE } = require('./lib/updates');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const NODE_MAJOR_MIN = 18;
const RULE = '═'.repeat(62);
// fermeture de la fenêtre : Windows laisse une dizaine de secondes avant de tout couper
const CLOSE_SIGNALS = ['SIGHUP'];
const STOP_SIGNALS = ['SIGINT', 'SIGTERM', 'SIGBREAK'];

const colors = process.stdout.isTTY
  ? { brass: '\x1b[38;5;179m', bright: '\x1b[1;38;5;223m', dim: '\x1b[38;5;245m', red: '\x1b[38;5;167m', reset: '\x1b[0m' }
  : { brass: '', bright: '', dim: '', red: '', reset: '' };

function say(text = '') {
  process.stdout.write(`${text}\n`);
}

function panelUrl() {
  const { host, port } = config.get().http;
  const shown = host === '0.0.0.0' ? '127.0.0.1' : host;
  return `http://${shown}:${port}/`;
}

function banner() {
  const c = colors;
  say();
  say(`${c.brass}  ${RULE}${c.reset}`);
  say(`${c.bright}     La Chancellerie${c.reset}${c.dim}  ·  panneau du serveur vAvA  ·  v${config.VERSION}${c.reset}`);
  say(`${c.brass}  ${RULE}${c.reset}`);
  say(`     Ouvrez dans votre navigateur :  ${c.bright}${panelUrl()}${c.reset}`);
  if (config.get().http.host === '0.0.0.0') say(`${c.dim}     (accessible aussi depuis les autres machines, par l'adresse de celle-ci)${c.reset}`);
  else if (process.platform !== 'win32') {
    // serveur distant : le panneau n'écoute que la machine, on l'atteint par un tunnel SSH depuis son ordinateur
    const { port } = config.get().http;
    say(`${c.dim}     Depuis votre ordinateur : ssh -L ${port}:127.0.0.1:${port} utilisateur@adresse-du-serveur${c.reset}`);
    say(`${c.dim}     puis ouvrez http://127.0.0.1:${port}/ dans votre navigateur.${c.reset}`);
  }
  say();
}

function announcePin(code) {
  const c = colors;
  say(`${c.brass}  ── Premier lancement ──${c.reset}`);
  say(`     Code d'accès :  ${c.bright}${pin.format(code)}${c.reset}`);
  say(`${c.dim}     Il permet de créer le compte maître depuis le navigateur. Ne le communiquez pas.${c.reset}`);
  say();
}

async function main() {
  const major = Number(process.versions.node.split('.')[0]);
  if (major < NODE_MAJOR_MIN) {
    say(`${colors.red}La Chancellerie demande Node.js ${NODE_MAJOR_MIN} ou plus récent (installé : ${process.versions.node}).${colors.reset}`);
    process.exitCode = 1;
    return;
  }
  config.ensureData();
  // la clé du pont part avec FXServer à chaque lancement, et reste masquée dans sa console
  const server = new ServerProcess({ launchArgs: bridge.launchArgs, secrets: bridge.secrets });
  events.attach(server);
  if (await server.cleanupOrphan()) say(`${colors.dim}  Un FXServer resté ouvert après un arrêt brutal a été arrêté.${colors.reset}`);

  const metrics = new Metrics(server);
  const updates = new Updates(server);
  const scheduler = new Scheduler(server, updates);
  const settings = config.get();
  const web = createServer({ host: settings.http.host }, createRouter(server, { metrics, scheduler, updates }));
  web.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
      say(`${colors.red}Le port ${settings.http.port} est déjà pris : une autre Chancellerie (ou txAdmin) tourne-t-elle déjà ?${colors.reset}`);
    } else {
      say(`${colors.red}Le serveur web n'a pas pu démarrer : ${error.message}${colors.reset}`);
    }
    process.exit(1);
  });
  web.listen(settings.http.port, settings.http.host, () => {
    banner();
    if (accounts.count() === 0) {
      pin.onChange(announcePin);
      pin.generate();
    }
    journal.record(journal.SYSTEM, 'panel_started');
    metrics.start();
    scheduler.start();
    updates.start();
    if (settings.setupDone && settings.autoStart) {
      const result = server.start(journal.SYSTEM);
      if (!result.ok) say(`${colors.red}  FXServer n'a pas pu être lancé : ${result.error}. Voyez la Chancellerie.${colors.reset}`);
      else say(`${colors.dim}  FXServer est lancé. Sa console est dans la Chancellerie.${colors.reset}`);
    } else if (!settings.setupDone) {
      say(`${colors.dim}  Le serveur n'est pas encore configuré : tout se fait depuis le navigateur.${colors.reset}`);
    }
    // démarrée après une mise à jour d'elle-même : la mise à jour est confirmée, le contrôle du serveur se poursuit
    updates.resume();
  });

  let stopping = false;
  /** quick : délais raccourcis (fenêtre fermée) ; code : 75 pour que demarrer.bat relance (mise à jour). */
  async function shutdown(quick, code = 0) {
    if (stopping) {
      // second Ctrl+C : on n'attend plus
      say(`${colors.red}  Arrêt immédiat.${colors.reset}`);
      process.exit(1);
    }
    stopping = true;
    say();
    say(`${colors.dim}  Arrêt de la Chancellerie${server.child ? ' : FXServer est arrêté proprement…' : '.'}${colors.reset}`);
    scheduler.stop();
    updates.stop();
    await server.stop(journal.SYSTEM, { quick });
    metrics.stop();
    journal.record(journal.SYSTEM, 'panel_stopped');
    web.close();
    process.exit(code);
  }
  updates.on('restart-panel', () => {
    say(`${colors.brass}  Mise à jour de la Chancellerie : redémarrage…${colors.reset}`);
    shutdown(false, RESTART_CODE);
  });
  for (const signal of STOP_SIGNALS) process.on(signal, () => shutdown(false));
  for (const signal of CLOSE_SIGNALS) process.on(signal, () => shutdown(true));
}

/**
 * --verifier : la Chancellerie se charge-t-elle ? Tous ses modules, et le JavaScript de son interface (syntaxe).
 * Lancé sur une nouvelle version avant de l'installer ; rien n'est démarré ni écrit.
 */
function verify() {
  for (const file of fs.readdirSync(path.join(__dirname, 'lib')).filter((name) => name.endsWith('.js'))) require(path.join(__dirname, 'lib', file));
  const web = path.join(__dirname, 'web', 'js');
  for (const file of fs.readdirSync(web).filter((name) => name.endsWith('.js'))) new vm.Script(fs.readFileSync(path.join(web, file), 'utf8'), { filename: file });
  if (!fs.existsSync(path.join(__dirname, 'web', 'index.html'))) throw new Error('web/index.html absent');
  say(`Chancellerie ${config.VERSION} : chargée sans erreur.`);
}

if (process.argv.includes('--verifier')) {
  try {
    verify();
  } catch (error) {
    say(`Chancellerie invalide : ${error.stack || error.message}`);
    process.exitCode = 1;
  }
} else {
  main().catch((error) => {
    say(`${colors.red}Erreur au lancement de la Chancellerie : ${error.stack || error.message}${colors.reset}`);
    process.exitCode = 1;
  });
}
