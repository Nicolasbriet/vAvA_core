'use strict';
/*
 * lib/discord-bot.js
 * Rôle : le bot Discord de la Chancellerie, comme celui de txAdmin.
 *        - Statut : un message dans le salon choisi, tenu à jour (chaque minute, et à chaque changement d'état ou
 *          arrivée de joueur) : état du serveur, joueurs, en ligne depuis, prochain redémarrage, bouton « Rejoindre ».
 *        - Annonces : serveur en ligne, arrêté, planté, redémarrage planifié, mise à jour ; signalements au salon staff.
 *        - Commandes slash : /statut et /joueurs pour tous ; /lier pour relier son compte Discord à son compte du
 *          panneau (même code qu'en jeu) ; /annonce, /avertir, /expulser, /bannir pour le staff, au nom de son compte
 *          du panneau : c'est le Registre du Conseil qui vérifie le droit du rang, la cible, et tient le journal.
 *        - Liste blanche : à la connexion d'un joueur, le pont demande s'il a l'un des rôles choisis sur le serveur
 *          Discord (identifiant discord du jeu) ; un compte du panneau relié à ce joueur passe toujours. Réponses
 *          gardées un court moment ; Discord injoignable : connexion refusée, avec un message clair.
 */

const path = require('path');
const accounts = require('./accounts');
const bridge = require('./bridge');
const config = require('./config');
const events = require('./events');
const journal = require('./journal');
const links = require('./links');
const notices = require('./notices');
const servercfg = require('./servercfg');
const status = require('./status');
const { DiscordClient } = require('./discord');
const { STATES } = require('./process');

const STATE_FILE = path.join(config.DATA, 'discord.json');
const STATUS_EVERY_MS = 60000;
const STATUS_DEBOUNCE_MS = 3000;
const WHITELIST_OK_MS = 60000;
const WHITELIST_NO_MS = 15000;
const EPHEMERAL = 64;
const COLORS = { running: 0x3f8f4f, starting: 0xd39a45, stopping: 0xd39a45, stopped: 0x8f2c1d, crashed: 0x8f2c1d, info: 0xb39463 };
const STATE_TEXT = { running: '🟢 **En ligne**', starting: '🟠 **Démarrage…**', stopping: '🟠 **Arrêt en cours…**', stopped: '🔴 **Hors ligne**', crashed: '🔴 **Arrêt imprévu**' };
const SNOWFLAKE = /^\d{17,20}$/;
const BAN_CHOICES = [[1, '1 heure'], [6, '6 heures'], [24, '1 jour'], [72, '3 jours'], [168, '7 jours'], [720, '30 jours'], [0, 'Définitif']];
const PLAYERS_SHOWN = 40;
// erreurs du Registre ou du pont, en clair pour Discord
const ERRORS = {
  forbidden: 'Votre rang n\'a pas ce droit.', outranked: 'Son rang est égal ou supérieur au vôtre.', not_found: 'Ce joueur n\'est plus là.',
  self: 'Pas sur vous-même.', ban_too_long: 'Durée au-delà de ce que permet votre rang.', invalid_args: 'Saisie refusée.',
  invalid_actor: 'Le rang de votre compte n\'existe plus au Conseil.', server_stopped: 'Le serveur de jeu est arrêté.',
  bridge_unreachable: 'Le serveur de jeu ne répond pas encore.', bridge_missing: 'Le pont de la Chancellerie n\'est pas lancé en jeu.',
  admin_unavailable: 'Le Registre du Conseil n\'est pas lancé.', unknown_code: 'Code inconnu ou expiré : demandez-en un nouveau dans la Chancellerie.',
  too_many_attempts: 'Trop de codes faux : patientez quelques minutes.',
};

const COMMANDS = [
  { name: 'statut', description: 'État du serveur : en ligne, joueurs, prochain redémarrage' },
  { name: 'joueurs', description: 'Joueurs connectés' },
  { name: 'lier', description: 'Relier votre compte Discord à votre compte de la Chancellerie', options: [{ type: 3, name: 'code', description: 'Code à 6 chiffres affiché dans la Chancellerie (page Comptes)', required: true, min_length: 6, max_length: 6 }] },
  { name: 'annonce', description: 'Proclamation à tous les joueurs (staff)', options: [{ type: 3, name: 'texte', description: 'Texte de la proclamation', required: true, max_length: 500 }] },
  { name: 'avertir', description: 'Avertir un joueur (staff)', options: [{ type: 4, name: 'joueur', description: 'Numéro de connexion du joueur (/joueurs)', required: true, min_value: 1, max_value: 65535 }, { type: 3, name: 'motif', description: 'Motif', required: true, max_length: 500 }] },
  { name: 'expulser', description: 'Expulser un joueur (staff)', options: [{ type: 4, name: 'joueur', description: 'Numéro de connexion du joueur (/joueurs)', required: true, min_value: 1, max_value: 65535 }, { type: 3, name: 'motif', description: 'Motif', required: true, max_length: 500 }] },
  {
    name: 'bannir', description: 'Bannir un joueur (staff)',
    options: [
      { type: 4, name: 'joueur', description: 'Numéro de connexion du joueur (/joueurs)', required: true, min_value: 1, max_value: 65535 },
      { type: 4, name: 'duree', description: 'Durée', required: true, choices: BAN_CHOICES.map(([value, name]) => ({ name, value })) },
      { type: 3, name: 'motif', description: 'Motif', required: true, max_length: 500 },
    ],
  },
];

const option = (interaction, name) => {
  const found = (interaction.data.options || []).find((o) => o.name === name);
  return found ? found.value : undefined;
};
const unix = (ms) => Math.floor(ms / 1000);

class DiscordBot {
  /**
   * @param {import('./process').ServerProcess} server
   * @param {import('./scheduler').Scheduler} scheduler
   */
  constructor(server, scheduler) {
    this.server = server;
    this.scheduler = scheduler;
    this.client = null;
    this.timer = null;
    this.debounce = null;
    this.busy = false;
    this.cache = new Map();
    this.lastState = server.state;
    this.saved = config.readJson(STATE_FILE, { statusMessageId: null, statusChannelId: null });
    server.on('state', (st) => this.onServerState(st));
    notices.on('restart-warning', ({ minutes }) => this.announce('announce', `⏳ Le serveur redémarre dans **${minutes} minute${minutes > 1 ? 's' : ''}**.`, COLORS.starting));
    notices.on('update', ({ ok, summary }) => {
      if (ok) this.announce('announce', `⬆️ Le royaume a été mis à jour${summary ? ` : ${summary}` : ''}.`, COLORS.info);
    });
    notices.on('report', (report) => this.announce('staff', `📣 Nouveau signalement n° ${report.id} de **${report.author || 'un joueur'}** : voir le Registre ou la Chancellerie.`, COLORS.info));
    notices.on('players', () => this.scheduleStatus());
  }

  settings() {
    return config.get().discord;
  }

  /** Lance le bot si réglé et activé (et l'arrête d'abord s'il tournait). */
  start() {
    this.stop();
    const s = this.settings();
    this.cache.clear();
    if (!s.enabled || !s.token) return;
    this.client = new DiscordClient(s.token);
    this.client.on('ready', () => this.onReady());
    this.client.on('interaction', (interaction) => this.onInteraction(interaction).catch((error) => {
      console.error(`[Chancellerie] commande Discord en erreur : ${error.message}`);
    }));
    this.client.connect();
    this.timer = setInterval(() => this.refreshStatus(), STATUS_EVERY_MS);
  }

  stop() {
    clearInterval(this.timer);
    clearTimeout(this.debounce);
    this.timer = null;
    if (this.client) this.client.stop();
    this.client = null;
  }

  view() {
    const s = this.settings();
    const client = this.client;
    return {
      enabled: s.enabled, hasToken: Boolean(s.token), guildId: s.guildId, statusChannelId: s.statusChannelId,
      announceChannelId: s.announceChannelId, staffChannelId: s.staffChannelId, joinUrl: s.joinUrl, inviteUrl: s.inviteUrl,
      whitelist: { enabled: s.whitelist.enabled, roleIds: [...s.whitelist.roleIds] },
      state: client ? client.state : 'stopped', error: client ? client.error : null, user: client ? client.user : null,
      applicationId: client ? client.applicationId : null,
    };
  }

  async onReady() {
    const s = this.settings();
    if (s.guildId) {
      try {
        await this.client.rest('PUT', `/applications/${this.client.applicationId}/guilds/${s.guildId}/commands`, COMMANDS);
      } catch (error) {
        journal.record(journal.SYSTEM, 'discord_error', { action: 'commandes', erreur: error.message.slice(0, 160) });
      }
    }
    this.refreshStatus();
  }

  // Statut ------------------------------------------------------------------------------------------------------------

  async statusMessage() {
    const st = this.server.status();
    const cfg = servercfg.current();
    const values = cfg ? cfg.values : servercfg.DEFAULTS;
    const running = st.state === STATES.RUNNING;
    const endpoint = servercfg.endpoint();
    const players = running && endpoint ? await status.players(endpoint) : null;
    const fields = [{ name: 'Joueurs', value: running && players ? `${players.length} / ${values.maxClients}` : '—', inline: true }];
    if (running && st.startedAt) fields.push({ name: 'En ligne', value: `depuis <t:${unix(st.startedAt)}:R>`, inline: true });
    if (this.scheduler && this.scheduler.restartAt) {
      fields.push({ name: 'Prochain redémarrage', value: this.scheduler.skipped() ? 'sauté' : `<t:${unix(this.scheduler.restartAt)}:R>`, inline: true });
    }
    const s = this.settings();
    const buttons = [];
    if (/^https:\/\//.test(s.joinUrl)) buttons.push({ type: 2, style: 5, label: 'Rejoindre', url: s.joinUrl });
    if (/^https:\/\//.test(s.inviteUrl)) buttons.push({ type: 2, style: 5, label: 'Discord', url: s.inviteUrl });
    return {
      embeds: [{
        title: values.hostname || 'Serveur vAvA', description: STATE_TEXT[st.state] || STATE_TEXT.stopped, color: COLORS[st.state] || COLORS.stopped,
        fields, footer: { text: 'La Chancellerie · mis à jour' }, timestamp: new Date().toISOString(),
      }],
      components: buttons.length ? [{ type: 1, components: buttons }] : [],
    };
  }

  scheduleStatus() {
    clearTimeout(this.debounce);
    this.debounce = setTimeout(() => this.refreshStatus(), STATUS_DEBOUNCE_MS);
  }

  /** Crée le message de statut, ou le met à jour (recréé s'il a été supprimé ou si le salon a changé). */
  async refreshStatus() {
    const s = this.settings();
    if (!this.client || this.client.state !== 'ready' || !s.statusChannelId || this.busy) return;
    this.busy = true;
    try {
      const message = await this.statusMessage();
      const same = this.saved.statusMessageId && this.saved.statusChannelId === s.statusChannelId;
      if (same) {
        try {
          await this.client.rest('PATCH', `/channels/${s.statusChannelId}/messages/${this.saved.statusMessageId}`, message);
          return;
        } catch (error) {
          if (error.code !== 'discord_404') throw error;
        }
      }
      const created = await this.client.rest('POST', `/channels/${s.statusChannelId}/messages`, message);
      this.saved = { statusMessageId: created.id, statusChannelId: s.statusChannelId };
      config.writeJson(STATE_FILE, this.saved);
    } catch (error) {
      journal.record(journal.SYSTEM, 'discord_error', { action: 'statut', erreur: error.message.slice(0, 160) });
    } finally {
      this.busy = false;
    }
  }

  // Annonces ----------------------------------------------------------------------------------------------------------

  /** Message dans le salon des annonces ('announce') ou du staff ('staff') ; sans effet si non réglé. */
  async announce(channel, text, color = COLORS.info) {
    const s = this.settings();
    const id = channel === 'staff' ? s.staffChannelId || s.announceChannelId : s.announceChannelId;
    if (!this.client || this.client.state !== 'ready' || !id) return { ok: false, error: 'discord_not_ready' };
    try {
      await this.client.rest('POST', `/channels/${id}/messages`, { embeds: [{ description: text, color }], allowed_mentions: { parse: [] } });
      return { ok: true };
    } catch (error) {
      journal.record(journal.SYSTEM, 'discord_error', { action: 'annonce', erreur: error.message.slice(0, 160) });
      return { ok: false, error: error.code || 'discord_error', detail: error.message };
    }
  }

  onServerState(st) {
    const previous = this.lastState;
    this.lastState = st.state;
    if (previous === st.state) return;
    if (st.state === STATES.RUNNING) this.announce('announce', '🟢 Le serveur est **en ligne**.', COLORS.running);
    else if (st.state === STATES.STOPPED && previous === STATES.STOPPING) this.announce('announce', '🔴 Le serveur est **arrêté**.', COLORS.stopped);
    else if (st.state === STATES.CRASHED) {
      this.announce('announce', st.relaunchAt
        ? '💥 Le serveur s\'est **arrêté de lui-même** : relance automatique.'
        : '💥 Le serveur s\'est **arrêté de lui-même** plusieurs fois : relance suspendue, le staff est prévenu.', COLORS.crashed);
    }
    this.scheduleStatus();
  }

  // Commandes ---------------------------------------------------------------------------------------------------------

  async reply(interaction, body) {
    await this.client.rest('PATCH', `/webhooks/${this.client.applicationId}/${interaction.token}/messages/@original`, { allowed_mentions: { parse: [] }, ...body });
  }

  async onInteraction(interaction) {
    // 2 : commande slash
    if (interaction.type !== 2 || !this.client) return;
    const name = interaction.data.name;
    const ephemeral = name !== 'statut';
    await this.client.rest('POST', `/interactions/${interaction.id}/${interaction.token}/callback`, { type: 5, data: { flags: ephemeral ? EPHEMERAL : 0 } });
    const user = interaction.member ? interaction.member.user : interaction.user;
    if (interaction.guild_id !== this.settings().guildId) {
      await this.reply(interaction, { content: 'Cette commande s\'utilise sur le serveur Discord du royaume.' });
      return;
    }
    let body;
    try {
      body = await this.command(name, interaction, user);
    } catch (error) {
      body = { content: 'La commande a échoué : réessayez dans un instant.' };
      console.error(`[Chancellerie] /${name} : ${error.message}`);
    }
    await this.reply(interaction, typeof body === 'string' ? { content: body } : body);
  }

  async command(name, interaction, user) {
    if (name === 'statut') return this.statusMessage();
    if (name === 'joueurs') return this.playersReply();
    if (name === 'lier') {
      const result = links.consumeDiscord({ code: String(option(interaction, 'code') || ''), id: user.id, username: user.global_name || user.username });
      if (result.ok) events.broadcast('linked', { name: result.account.name });
      return result.ok
        ? `Votre compte Discord est relié au compte « ${result.account.name} » de la Chancellerie.`
        : ERRORS[result.error] || 'Liaison refusée.';
    }
    // commandes du staff : au nom du compte du panneau relié à ce compte Discord, avec son rang du Conseil
    const account = accounts.byDiscord(user.id);
    if (!account) return 'Votre compte Discord n\'est relié à aucun compte de la Chancellerie : demandez un code (page Comptes), puis /lier.';
    if (!account.rank) return 'Votre compte de la Chancellerie n\'a pas de rang du Conseil.';
    if (!this.server.child) return ERRORS.server_stopped;
    const actor = { label: account.name, rank: account.rank };
    const requests = {
      annonce: ['announce', [String(option(interaction, 'texte'))], 'Proclamation envoyée.'],
      avertir: ['warn', [option(interaction, 'joueur'), String(option(interaction, 'motif'))], 'Avertissement inscrit.'],
      expulser: ['kick', [option(interaction, 'joueur'), String(option(interaction, 'motif'))], 'Joueur expulsé.'],
      bannir: ['ban', [option(interaction, 'joueur'), option(interaction, 'duree'), String(option(interaction, 'motif'))], 'Ban scellé.'],
    };
    const request = requests[name];
    if (!request) return 'Commande inconnue.';
    const result = await bridge.request(servercfg.endpoint(), 'POST', '/request', { actor, name: request[0], args: request[1] });
    return result.ok ? `✅ ${request[2]}` : `❌ ${ERRORS[result.error] || `Refusé (${result.error}).`}`;
  }

  async playersReply() {
    const endpoint = servercfg.endpoint();
    if (this.server.state !== STATES.RUNNING || !endpoint) return ERRORS.server_stopped;
    const players = await status.players(endpoint);
    if (!players) return ERRORS.bridge_unreachable;
    if (!players.length) return 'Personne n\'est connecté.';
    const lines = players.slice(0, PLAYERS_SHOWN).map((p) => `\`${String(p.id).padStart(3)}\` ${p.name.replace(/[*_`~|>]/g, '')}`);
    if (players.length > PLAYERS_SHOWN) lines.push(`… et ${players.length - PLAYERS_SHOWN} autres.`);
    return { embeds: [{ title: `${players.length} joueur${players.length > 1 ? 's' : ''} connecté${players.length > 1 ? 's' : ''}`, description: lines.join('\n'), color: COLORS.running }] };
  }

  // Liste blanche -----------------------------------------------------------------------------------------------------

  whitelistActive() {
    const s = this.settings();
    return Boolean(s.enabled && s.whitelist.enabled && s.whitelist.roleIds.length);
  }

  /**
   * Un joueur qui se connecte peut-il entrer ? { allowed, reason? } (reason : le message affiché au joueur).
   * @param {{ license: string, discord?: string }} player
   */
  async whitelist(player) {
    const s = this.settings();
    if (!this.whitelistActive()) return { allowed: true };
    const join = s.inviteUrl ? ` Rejoignez-nous : ${s.inviteUrl}` : '';
    // le staff relié à son joueur passe toujours
    if (accounts.linked().some((account) => account.link.license === player.license)) return { allowed: true };
    const match = /^discord:(\d{17,20})$/.exec(String(player.discord || ''));
    if (!match) return { allowed: false, reason: `Ce serveur est réservé aux membres de son Discord. Lancez Discord avant FiveM, puis reconnectez-vous.${join}` };
    const id = match[1];
    const cached = this.cache.get(id);
    if (cached && cached.until > Date.now()) return cached.answer;
    if (!this.client || !s.guildId) return { allowed: false, reason: 'La liste blanche ne peut pas être vérifiée pour l\'instant : réessayez dans une minute.' };
    let answer;
    try {
      const member = await this.client.rest('GET', `/guilds/${s.guildId}/members/${id}`);
      const roles = new Set(member.roles || []);
      answer = s.whitelist.roleIds.some((role) => roles.has(role))
        ? { allowed: true }
        : { allowed: false, reason: 'Vous n\'avez pas (encore) le rôle qui ouvre les portes du royaume sur notre Discord.' };
    } catch (error) {
      if (error.code === 'discord_404') answer = { allowed: false, reason: `Vous n'êtes pas membre de notre Discord.${join}` };
      else return { allowed: false, reason: 'La liste blanche ne peut pas être vérifiée pour l\'instant : réessayez dans une minute.' };
    }
    this.cache.set(id, { answer, until: Date.now() + (answer.allowed ? WHITELIST_OK_MS : WHITELIST_NO_MS) });
    return answer;
  }
}

/**
 * Réglages reçus du navigateur, nettoyés ; jeton vide : celui en place est gardé. Renvoie { value } ou { error, field }.
 */
function validateSettings(input, previousToken) {
  const body = input || {};
  const id = (value) => value === '' || SNOWFLAKE.test(value);
  if (typeof body.enabled !== 'boolean') return { error: 'invalid', field: 'enabled' };
  if (typeof body.token !== 'string' || (body.token && !/^[A-Za-z0-9_.-]{50,120}$/.test(body.token))) return { error: 'invalid', field: 'token' };
  for (const field of ['guildId', 'statusChannelId', 'announceChannelId', 'staffChannelId']) {
    if (typeof body[field] !== 'string' || !id(body[field])) return { error: 'invalid', field };
  }
  for (const field of ['joinUrl', 'inviteUrl']) {
    if (typeof body[field] !== 'string' || body[field].length > 200 || (body[field] && !/^https:\/\/[^\s"<>]+$/.test(body[field]))) return { error: 'invalid', field };
  }
  const whitelist = body.whitelist || {};
  if (typeof whitelist.enabled !== 'boolean' || !Array.isArray(whitelist.roleIds) || whitelist.roleIds.length > 10
    || whitelist.roleIds.some((role) => typeof role !== 'string' || !SNOWFLAKE.test(role))) return { error: 'invalid', field: 'roleIds' };
  const token = body.token || previousToken;
  if (body.enabled && !token) return { error: 'required', field: 'token' };
  if (body.enabled && !body.guildId) return { error: 'required', field: 'guildId' };
  if (whitelist.enabled && !whitelist.roleIds.length) return { error: 'required', field: 'roleIds' };
  return {
    value: {
      enabled: body.enabled, token, guildId: body.guildId, statusChannelId: body.statusChannelId, announceChannelId: body.announceChannelId,
      staffChannelId: body.staffChannelId, joinUrl: body.joinUrl, inviteUrl: body.inviteUrl,
      whitelist: { enabled: whitelist.enabled, roleIds: [...new Set(whitelist.roleIds)] },
    },
  };
}

module.exports = { DiscordBot, validateSettings, COMMANDS };
