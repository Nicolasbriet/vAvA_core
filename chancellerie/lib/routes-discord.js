'use strict';
/*
 * lib/routes-discord.js
 * Rôle : le bot Discord, réglé par le compte maître : réglages (le jeton n'en ressort jamais : l'interface sait
 *        seulement qu'il est renseigné), état de la connexion, message d'essai. Chacun délie son compte Discord ;
 *        le maître, celui de tous.
 */

const accounts = require('./accounts');
const config = require('./config');
const journal = require('./journal');
const { validateSettings } = require('./discord-bot');

// droits demandés à l'invitation du bot : voir les salons, y écrire, y mettre des encarts, relire l'historique
const BOT_PERMISSIONS = 1024 + 2048 + 16384 + 65536;

/**
 * @param {Function} route
 * @param {{ ok: Function, fail: Function, discord: import('./discord-bot').DiscordBot }} deps
 */
function register(route, { ok, fail, discord }) {
  const view = () => {
    const current = discord.view();
    // lien d'invitation : l'identifiant de l'application est connu une fois le bot connecté
    const invite = current.applicationId
      ? `https://discord.com/oauth2/authorize?client_id=${current.applicationId}&scope=bot+applications.commands&permissions=${BOT_PERMISSIONS}`
      : null;
    return { discord: current, invite, nodeOk: typeof WebSocket === 'function' };
  };

  route('GET', '/api/discord', { auth: true, master: true }, () => ok(view()));

  route('POST', '/api/discord/settings', { auth: true, master: true }, (ctx) => {
    const result = validateSettings(ctx.body, config.get().discord.token);
    if (result.error) return fail(400, result.error, { field: result.field });
    config.update({ discord: result.value });
    journal.record(ctx.account.name, 'discord_settings', { actif: result.value.enabled ? 'oui' : 'non', liste_blanche: result.value.whitelist.enabled ? 'oui' : 'non' });
    discord.start();
    return ok(view());
  });

  route('POST', '/api/discord/test', { auth: true, master: true, limit: 'probe' }, async (ctx) => {
    const result = await discord.announce('announce', `🔔 Message d'essai de la Chancellerie, envoyé par ${ctx.account.name}.`);
    return result.ok ? ok() : fail(200, result.error, { detail: result.detail });
  });

  route('POST', '/api/account/discord/unlink', { auth: true }, (ctx) => {
    const name = ctx.body.name === undefined ? ctx.account.name : ctx.body.name;
    if (name !== ctx.account.name && !ctx.account.master) return fail(403, 'forbidden');
    const target = accounts.get(name);
    if (!target) return fail(400, 'unknown_account');
    const result = accounts.clearDiscord(target.name);
    if (!result.ok) return fail(400, result.error);
    journal.record(ctx.account.name, 'discord_unlinked', { compte: target.name });
    return ok();
  });
}

module.exports = { register };
