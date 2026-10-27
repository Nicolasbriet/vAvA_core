'use strict';
/*
 * lib/routes-game.js
 * Rôle : administration du royaume depuis le panneau, pour les comptes qui ont un rang du Conseil. Les demandes
 *        partent au pont du serveur de jeu (liste fermée de noms) au nom du compte : c'est le Registre du Conseil qui
 *        vérifie le droit du rang, la cible, le rang de la cible, et qui tient le journal. Caméras sur l'écran des
 *        joueurs (mur et vue en grand) ; évènements du pont (signalements, joueurs, caméras) reçus et relayés aux
 *        navigateurs ; liaison d'un compte du panneau (code tapé en jeu) et rangs des comptes reliés appliqués quand
 *        le serveur de jeu démarre.
 */

const accounts = require('./accounts');
const bridge = require('./bridge');
const camera = require('./camera');
const links = require('./links');
const config = require('./config');
const events = require('./events');

// demandes du Registre permises au web (le Registre refuse de lui-même celles qui supposent un personnage)
const WEB_REQUESTS = new Set([
  'session', 'players', 'player', 'reports', 'reportClaim', 'reportClose', 'bans', 'unban', 'logs', 'staff', 'staffSet',
  'announce', 'sendBack', 'moveToPlayer', 'moveToCoords', 'freeze', 'heal', 'feed', 'message', 'warn', 'kick', 'ban',
  'inventoryView', 'give', 'zones', 'zoneUpdate', 'zoneDelete',
]);
const ARGS_MAX = 8;
const PLAYER_MAX = 65535;
const SESSION_PATTERN = /^[0-9a-f]{24}$/;
const QUALITIES = new Set(['tile', 'full']);

/**
 * @param {Function} route
 * @param {{ ok: Function, fail: Function, endpoint: Function, server: import('./process').ServerProcess }} deps
 */
function register(route, { ok, fail, endpoint, server }) {
  const stopped = () => !server.child;
  // erreur métier (refus du Registre, joueur parti…) : réponse ordinaire, l'interface l'explique
  const answer = (result, extra) => (result.ok ? ok(extra || {}) : fail(200, result.error));

  events.onSessionEmpty((token) => camera.closeSession(endpoint(), token));
  server.on('exit', () => camera.clear());
  links.attach(server);

  route('POST', '/api/game/request', { auth: true, rank: true, limit: 'game', limitBy: 'token' }, async (ctx) => {
    const { name, args } = ctx.body;
    if (typeof name !== 'string' || !WEB_REQUESTS.has(name)) return fail(400, 'unknown_request');
    if (args !== undefined && (!Array.isArray(args) || args.length > ARGS_MAX)) return fail(400, 'invalid');
    if (stopped()) return fail(200, 'server_stopped');
    const result = await bridge.request(endpoint(), 'POST', '/request', { actor: bridge.actorOf(ctx.account), name, args: args || [] });
    return answer(result, { result: result.result });
  });

  route('GET', '/api/game/ranks', { auth: true }, async () => {
    if (!stopped()) {
      const result = await bridge.request(endpoint(), 'GET', '/ranks');
      if (result.ok && Array.isArray(result.ranks)) {
        const ranks = result.ranks.map((r) => ({ name: String(r.name), label: String(r.label), level: Number(r.level) || 0 }));
        config.update({ game: { ranks } });
        return ok({ ranks, live: true });
      }
    }
    return ok({ ranks: config.get().game.ranks, live: false });
  });

  // mur : ouverture (au journal) puis relecture de la liste
  for (const [path, opening] of [['/api/game/cameras/wall', true], ['/api/game/cameras/players', false]]) {
    route('POST', path, { auth: true, rank: true, limit: 'game', limitBy: 'token' }, async (ctx) => {
      if (stopped()) return fail(200, 'server_stopped');
      const result = await camera.players(endpoint(), ctx.account, opening);
      return answer(result, { players: result.players });
    });
  }

  route('POST', '/api/game/camera/start', { auth: true, rank: true, limit: 'camera', limitBy: 'token' }, async (ctx) => {
    const { target, quality = 'full' } = ctx.body;
    if (!Number.isInteger(target) || target < 1 || target > PLAYER_MAX || !QUALITIES.has(quality)) return fail(400, 'invalid');
    if (stopped()) return fail(200, 'server_stopped');
    const result = await camera.start(endpoint(), ctx.account, ctx.token, target, quality);
    return answer(result, { session: result.session, label: result.label, iceServers: result.iceServers });
  });

  route('POST', '/api/game/camera/answer', { auth: true, rank: true, limit: 'camera', limitBy: 'token' }, async (ctx) => {
    const { session, sdp } = ctx.body;
    if (typeof session !== 'string' || !SESSION_PATTERN.test(session)) return fail(400, 'invalid');
    return answer(await camera.answer(endpoint(), ctx.token, session, sdp));
  });

  route('POST', '/api/game/camera/stop', { auth: true, rank: true }, async (ctx) => {
    const { session } = ctx.body;
    if (typeof session !== 'string' || !SESSION_PATTERN.test(session)) return fail(400, 'invalid');
    return answer(await camera.stop(endpoint(), ctx.token, session));
  });

  // évènements du pont : machine locale et clé du lancement (vérifiées avant d'arriver ici)
  route('POST', '/api/bridge/event', { bridge: true }, (ctx) => {
    const event = ctx.body;
    if (event.type === 'report') {
      events.broadcastRanked('report', { action: String(event.action), id: Number(event.id) || 0, author: String(event.author || '') });
    } else if (event.type === 'players') {
      events.broadcastRanked('players', {});
    } else if (event.type === 'camera') {
      camera.incoming(event);
    } else if (event.type === 'ready') {
      // serveur de jeu démarré : les rangs des comptes reliés s'y appliquent
      links.syncAll();
    } else if (event.type === 'link') {
      // code tapé en jeu : la réponse revient au joueur (le pont l'en prévient)
      const result = links.consume(event);
      if (!result.ok) return fail(200, result.error);
      events.broadcast('linked', { name: result.account.name });
      return ok({ account: result.account.name });
    }
    return ok();
  });

  // pour la page Joueurs : quel compte du panneau est relié à quel compte de jeu
  route('GET', '/api/links', { auth: true, rank: true }, () => ok({
    links: accounts.linked().map((account) => ({ accountId: account.link.accountId, name: account.name })),
  }));
}

module.exports = { register };
