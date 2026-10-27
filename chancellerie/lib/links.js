'use strict';
/*
 * lib/links.js
 * Rôle : relier un compte du panneau à son joueur, et appliquer en jeu le rang du compte relié.
 *        - Le panneau tire un code à 6 chiffres (5 minutes, un seul en cours par compte) ; le joueur le tape en jeu, le
 *          pont l'envoie avec sa license, son identifiant fivem et son numéro de compte vAvA. Les codes faux sont
 *          comptés par license : au-delà de quelques-uns, elle doit attendre.
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
const PLAYER_MAX = 64;
const ACCOUNT_ID_MAX = 0xffffffff;

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
    if (!entry.ok) journal.record(actor || journal.SYSTEM, 'rank_sync_failed', { compte: member.label, erreur: String(entry.error) });
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

  /** Révoque en jeu le rang d'un joueur délié (ou dont le compte du panneau est supprimé). */
  revoke(link, name, actor) {
    if (link) apply([{ accountId: link.accountId, rank: '', label: name }], actor);
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
    // une license est un seul compte vAvA : le rang du nouveau compte relié remplace celui de l'ancien, rien à révoquer
    this.sync(result.account, result.account.name);
    return { ok: true, account: result.account };
  },
};
