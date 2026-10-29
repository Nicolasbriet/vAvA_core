'use strict';
/*
 * lib/routes-accounts.js
 * Rôle : comptes du panneau. Le compte maître crée, règle (droits du panneau, rang du Conseil), remet un mot de passe
 *        et supprime les autres comptes ; chacun change son propre mot de passe (l'ancien exigé). Un mot de passe
 *        changé ou un compte supprimé ferme ses autres sessions. Chacun relie son compte à son joueur (code à taper en
 *        jeu) ou l'en délie, le maître pour tous ; le rang d'un compte relié suit en jeu, et les caméras regardées
 *        depuis le web suivent le rang changé. Tout est inscrit au journal, sans mot de passe.
 */

const accounts = require('./accounts');
const camera = require('./camera');
const events = require('./events');
const journal = require('./journal');
const links = require('./links');
const sessions = require('./sessions');

/** Ferme les sessions d'un compte, sauf celle de la requête. */
function dropSessions(name, exceptToken) {
  for (const token of sessions.destroyFor(name, exceptToken)) events.closeSession(token);
}

/**
 * @param {Function} route  déclaration d'une route (méthode, chemin, options, traitement)
 * @param {{ ok: Function, fail: Function }} reply
 */
function register(route, { ok, fail }) {
  route('GET', '/api/accounts', { auth: true, master: true }, () => ok({ accounts: accounts.list(), permissions: accounts.PERMISSIONS }));

  route('POST', '/api/accounts/create', { auth: true, master: true }, async (ctx) => {
    const { name, password, permissions, rank } = ctx.body;
    const result = await accounts.create(name, password, { permissions, rank });
    if (!result.ok) return fail(400, result.error);
    journal.record(ctx.account.name, 'account_created', { compte: result.account.name, rang: result.account.rank || '—' });
    return ok({ account: result.account });
  });

  route('POST', '/api/accounts/update', { auth: true, master: true }, (ctx) => {
    const { name, permissions, rank } = ctx.body;
    const result = accounts.update(name, { permissions, rank });
    if (!result.ok) return fail(400, result.error);
    journal.record(ctx.account.name, 'account_updated', { compte: result.account.name, rang: result.account.rank || '—' });
    // compte relié : son nouveau rang s'applique aussi en jeu
    links.sync(result.account, ctx.account.name);
    // ses caméras regardées depuis le web suivent son nouveau rang (compte relié ou non)
    camera.recheck();
    return ok({ account: result.account });
  });

  route('POST', '/api/accounts/password', { auth: true, master: true }, async (ctx) => {
    const { name, password } = ctx.body;
    const target = accounts.get(name);
    if (!target) return fail(400, 'unknown_account');
    if (target.master) return fail(400, 'master_account');
    const result = await accounts.setPassword(target.name, password);
    if (!result.ok) return fail(400, result.error);
    dropSessions(target.name, null);
    journal.record(ctx.account.name, 'password_reset', { compte: target.name });
    return ok();
  });

  route('POST', '/api/accounts/delete', { auth: true, master: true }, (ctx) => {
    const target = accounts.get(ctx.body.name);
    if (!target) return fail(400, 'unknown_account');
    const result = accounts.remove(target.name);
    if (!result.ok) return fail(400, result.error);
    dropSessions(target.name, null);
    journal.record(ctx.account.name, 'account_deleted', { compte: target.name });
    // son joueur relié perd son rang en jeu
    links.revoke(target.link, target.name, ctx.account.name);
    return ok();
  });

  // Liaison au joueur : chacun pour son compte, le maître pour tous ----------------------------------------------

  const targetOf = (ctx) => {
    const name = ctx.body.name;
    if (name === undefined || name === ctx.account.name) return ctx.account;
    return ctx.account.master ? accounts.get(name) : undefined;
  };

  route('POST', '/api/account/link', { auth: true, limit: 'probe', limitBy: 'token' }, (ctx) => {
    const target = targetOf(ctx);
    if (target === undefined) return fail(403, 'forbidden');
    if (!target) return fail(400, 'unknown_account');
    const { code, expiresAt } = links.issue(target.name);
    return ok({ code, expiresAt, ttlMs: links.CODE_TTL_MS, account: target.name });
  });

  route('POST', '/api/account/unlink', { auth: true }, (ctx) => {
    const target = targetOf(ctx);
    if (target === undefined) return fail(403, 'forbidden');
    if (!target) return fail(400, 'unknown_account');
    const result = accounts.clearLink(target.name);
    if (!result.ok) return fail(400, result.error);
    journal.record(ctx.account.name, 'account_unlinked', { compte: target.name });
    links.revoke(result.link, target.name, ctx.account.name);
    return ok();
  });

  // son propre mot de passe : l'ancien est exigé (une session laissée ouverte ne suffit pas)
  route('POST', '/api/account/password', { auth: true, limit: 'password', limitBy: 'token' }, async (ctx) => {
    const { current, password } = ctx.body;
    if (!(await accounts.verify(ctx.account.name, current))) return fail(400, 'bad_password');
    const result = await accounts.setPassword(ctx.account.name, password);
    if (!result.ok) return fail(400, result.error);
    dropSessions(ctx.account.name, ctx.token);
    journal.record(ctx.account.name, 'password_changed');
    return ok();
  });
}

module.exports = { register };
