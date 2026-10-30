'use strict';
/*
 * lib/links.js
 * Rôle : relier un compte du panneau à son joueur (et à son compte Discord), et appliquer en jeu le rang du compte
 *        relié.
 *        - Le panneau tire un code à 6 chiffres (5 minutes, un seul en cours par compte) ; le joueur le tape en jeu, le
 *          pont l'envoie avec sa license, son identifiant fivem (et discord) et son numéro de compte vAvA. Le même code
 *          tapé dans Discord (/lier) relie le compte Discord de son auteur. Les codes faux sont comptés par license ou
 *          par compte Discord : au-delà de quelques-uns, il faut attendre.
 *        - Le rang du Conseil du compte relié s'applique en jeu (aucun rang : révoqué), quand le compte est relié,
 *          quand son rang change, quand il est délié ou supprimé (révoqué), et à chaque démarrage du serveur de jeu
 *          (le pont prévient). Le panneau est la source : un rang changé en jeu pour ce compte est remis au suivant.
 */

const crypto = require('crypto');
const accounts = require('./accounts');
const bridge = require('./bridge');
const journal = require('./journal');
const servercfg = require('./servercfg');

const CODE_TTL_MS = 5 * 60000;
const CODE_DIGITS = 6;
const FAILS_MAX = 5;
const FAIL_WINDOW_MS = 10 * 60000;
const CODE_PATTERN = /^\d{6}$/;
const LICENSE_PATTERN = /^license:[0-9a-f]{40}$/;
const FIVEM_PATTERN = /^fivem:\d{1,12}$/;
const DISCORD_PATTERN = /^discord:(\d{17,20})$/;
const PLAYER_MAX = 64;
const ACCOUNT_ID_MAX = 0xffffffff;
// refus du pont lisibles au journal (le pont ne donne un rang qu'à un joueur qu'il a vu relié en jeu par un code)
const SYNC_ERRORS = { not_linked_in_game: 'joueur jamais relié en jeu par un code : à relier de nouveau' };

/** @type {Map<string, { name: string, expiresAt: number }>} code → compte */
const pending = new Map();
/** @type {Map<string, number[]>} license → instants de ses codes faux */
const failures = new Map();
let server = null;

function sweep() {
  const now = Date.now();
  for (const [code, entry] of pending) if (entry.expiresAt <= now) pending.delete(code);
  for (const [license, times] of failures) {
    const kept = times.filter((at) => now - at < FAIL_WINDOW_MS);
    if (kept.length) failures.set(license, kept);
    else failures.delete(license);
  }
}

/** Nouveau code pour un compte (l'ancien, s'il y en avait un, ne vaut plus) : { code, expiresAt }. */
function issue(name) {
  sweep();
  for (const [code, entry] of pending) if (entry.name === name) pending.delete(code);
  let code;
  do {
    code = String(crypto.randomInt(0, 10 ** CODE_DIGITS)).padStart(CODE_DIGITS, '0');
  } while (pending.has(code));
  const expiresAt = Date.now() + CODE_TTL_MS;
  pending.set(code, { name, expiresAt });
  return { code, expiresAt };
}

/**
 * Rangs à appliquer en jeu : [{ accountId, rank ('' : aucun), label }]. Sans effet serveur arrêté : le pont prévient
 * au démarrage suivant, et tout est appliqué alors.
 */
async function apply(members, actor) {
  if (!members.length || !server || !server.child) return;
  const result = await bridge.request(servercfg.endpoint(), 'POST', '/staff/sync', { members });
  const results = result.ok && Array.isArray(result.results) ? result.results : null;
  if (!results) {
    journal.record(actor || journal.SYSTEM, 'rank_sync_failed', { erreur: result.error || 'réponse illisible' });
    return;
  }
  results.forEach((entry, index) => {
    const member = members[index];
    if (!entry.ok) journal.record(actor || journal.SYSTEM, 'rank_sync_failed', { compte: member.label, erreur: Object.hasOwn(SYNC_ERRORS, entry.error) ? SYNC_ERRORS[entry.error] : String(entry.error) });
    else if (entry.changed) journal.record(actor || journal.SYSTEM, 'rank_synced', { compte: member.label, jeu: `compte n° ${member.accountId}`, rang: member.rank || 'aucun' });
  });
}

const memberOf = (account) => ({ accountId: account.link.accountId, rank: account.rank || '', label: account.name });

module.exports = {
  CODE_TTL_MS,
  issue,

  /** Branche la liaison sur le processus FXServer (les rangs ne s'appliquent que serveur en marche). */
  attach(serverProcess) {
    server = serverProcess;
  },

  /** Applique en jeu le rang d'un compte relié (après liaison ou changement de rang). */
  sync(account, actor) {
    if (account && account.link) apply([memberOf(account)], actor);
  },

  /**
   * Révoque en jeu le rang d'un joueur délié (ou dont le compte du panneau est supprimé) ; `unlinked` : le pont oublie
   * aussi ce joueur, qui devra être relié de nouveau en jeu pour recevoir un rang.
   */
  revoke(link, name, actor) {
    if (link) apply([{ accountId: link.accountId, rank: '', label: name, unlinked: true }], actor);
  },

  /** Serveur de jeu démarré : tous les rangs des comptes reliés. */
  syncAll() {
    apply(accounts.linked().map(memberOf), journal.SYSTEM);
  },

  /**
   * Code tapé en jeu, reçu du pont : relie le compte qui l'a demandé. Renvoie { ok, account } ou { ok: false, error }.
   * @param {{ code, license, fivem?, accountId, player? }} event
   */
  consume(event) {
    sweep();
    const code = String(event.code || '');
    const license = String(event.license || '');
    const accountId = Number(event.accountId);
    if (!CODE_PATTERN.test(code) || !LICENSE_PATTERN.test(license) || !Number.isInteger(accountId) || accountId < 1 || accountId > ACCOUNT_ID_MAX) {
      return { ok: false, error: 'invalid' };
    }
    const fails = failures.get(license) || [];
    if (fails.length >= FAILS_MAX) return { ok: false, error: 'too_many_attempts' };
    const entry = pending.get(code);
    if (!entry || entry.expiresAt <= Date.now()) {
      failures.set(license, [...fails, Date.now()]);
      return { ok: false, error: 'unknown_code' };
    }
    pending.delete(code);
    const fivem = FIVEM_PATTERN.test(String(event.fivem || '')) ? String(event.fivem) : '';
    const player = String(event.player || '').replace(/[\x00-\x1f\x7f]/g, '').slice(0, PLAYER_MAX);
    const result = accounts.setLink(entry.name, { license, fivem, accountId, player });
    if (!result.ok) return { ok: false, error: result.error };
    failures.delete(license);
    if (result.previous) {
      journal.record(journal.SYSTEM, 'account_unlinked', { compte: result.previous.name, raison: `joueur relié à ${result.account.name}` });
    }
    journal.record(result.account.name, 'account_linked', { joueur: player || `compte n° ${accountId}`, compte_jeu: accountId });
    // le joueur avait Discord ouvert : son compte Discord est relié du même coup (s'il ne l'était pas déjà)
    const discord = DISCORD_PATTERN.exec(String(event.discord || ''));
    if (discord && !result.account.discord) accounts.setDiscord(result.account.name, { id: discord[1], username: '' });
    // une license est un seul compte vAvA : le rang du nouveau compte relié remplace celui de l'ancien, rien à révoquer
    this.sync(result.account, result.account.name);
    return { ok: true, account: result.account };
  },

  /**
   * Code tapé dans Discord (/lier) : relie le compte Discord de l'auteur au compte qui a demandé le code.
   * @param {{ code: string, id: string, username: string }} user
   */
  consumeDiscord(user) {
    sweep();
    const code = String(user.code || '').trim();
    if (!CODE_PATTERN.test(code) || !/^\d{17,20}$/.test(String(user.id))) return { ok: false, error: 'unknown_code' };
    const key = `discord:${user.id}`;
    const fails = failures.get(key) || [];
    if (fails.length >= FAILS_MAX) return { ok: false, error: 'too_many_attempts' };
    const entry = pending.get(code);
    if (!entry || entry.expiresAt <= Date.now()) {
      failures.set(key, [...fails, Date.now()]);
      return { ok: false, error: 'unknown_code' };
    }
    pending.delete(code);
    failures.delete(key);
    const username = String(user.username || '').replace(/[\x00-\x1f\x7f]/g, '').slice(0, PLAYER_MAX);
    const result = accounts.setDiscord(entry.name, { id: String(user.id), username });
    if (!result.ok) return result;
    journal.record(result.account.name, 'discord_linked', { discord: username || user.id });
    return { ok: true, account: result.account };
  },
};
