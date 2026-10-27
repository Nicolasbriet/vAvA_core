'use strict';
/*
 * lib/accounts.js
 * Rôle : comptes de la Chancellerie (data/accounts.json), comme ceux de txAdmin : identifiant et mot de passe, droits
 *        sur le panneau (serveur, console, configuration, sauvegardes) et rang du Conseil pour administrer le royaume depuis le
 *        web (mêmes droits qu'en jeu, vérifiés par le Registre). Le compte maître a tous les droits du panneau et le
 *        rang de souverain. Les mots de passe sont dérivés par scrypt avec un sel aléatoire ; jamais stockés ni
 *        journalisés en clair. Les comptes vivent hors de la base de données : le panneau reste utilisable si MySQL
 *        est en panne.
 */

const crypto = require('crypto');
const path = require('path');
const { promisify } = require('util');
const config = require('./config');

const scrypt = promisify(crypto.scrypt);
const FILE = path.join(config.DATA, 'accounts.json');
const KEY_LENGTH = 64;
const SALT_BYTES = 16;
const SCRYPT = { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
const NAME_PATTERN = /^[A-Za-z0-9_.-]{3,32}$/;
// rang du Conseil (nom donné par vava_admin) ; vide : aucun accès au royaume
const RANK_PATTERN = /^[a-z0-9_]{0,32}$/;
const PASSWORD_MIN = 10;
const PASSWORD_MAX = 200;
const MASTER_RANK = 'souverain';
const MAX_ACCOUNTS = 100;

// Droits d'un compte sur le panneau. « backups » : sauvegardes de la base (toutes les données des joueurs).
const PERMISSIONS = Object.freeze(['server', 'console', 'config', 'backups']);

let store = config.readJson(FILE, { accounts: [] });
// sel factice : un identifiant inconnu coûte le même calcul qu'un vrai (aucune information par le temps de réponse)
const DUMMY_SALT = crypto.randomBytes(SALT_BYTES).toString('hex');

function save() {
  config.writeJson(FILE, store);
}

async function derive(password, salt) {
  return (await scrypt(password, salt, KEY_LENGTH, SCRYPT)).toString('hex');
}

const findIndex = (name) => store.accounts.findIndex((account) => account.name.toLowerCase() === String(name).toLowerCase());

function publicView(account) {
  return {
    name: account.name,
    master: account.master === true,
    permissions: account.master ? [...PERMISSIONS] : [...account.permissions],
    rank: account.master ? MASTER_RANK : account.rank || '',
    createdAt: account.createdAt,
  };
}

/** Règles d'un mot de passe ; renvoie un code d'erreur ou null. */
function checkPassword(password) {
  if (typeof password !== 'string' || password.length < PASSWORD_MIN) return 'password_too_short';
  if (password.length > PASSWORD_MAX) return 'password_too_long';
  return null;
}

/** Droits du panneau et rang reçus d'un formulaire ; renvoie { permissions, rank } ou { error }. */
function rightsOf(permissions, rank) {
  if (!Array.isArray(permissions) || permissions.some((p) => !PERMISSIONS.includes(p))) return { error: 'invalid_permissions' };
  if (typeof rank !== 'string' || !RANK_PATTERN.test(rank)) return { error: 'invalid_rank' };
  return { permissions: [...new Set(permissions)], rank };
}

module.exports = {
  PERMISSIONS,
  MASTER_RANK,
  count: () => store.accounts.length,

  /** Crée un compte ; renvoie { ok, account } ou { ok: false, error }. */
  async create(name, password, { master = false, permissions = [], rank = '' } = {}) {
    if (typeof name !== 'string' || !NAME_PATTERN.test(name)) return { ok: false, error: 'invalid_name' };
    const problem = checkPassword(password);
    if (problem) return { ok: false, error: problem };
    const rights = rightsOf(permissions, rank);
    if (rights.error) return { ok: false, error: rights.error };
    if (findIndex(name) !== -1) return { ok: false, error: 'name_taken' };
    if (store.accounts.length >= MAX_ACCOUNTS) return { ok: false, error: 'too_many_accounts' };
    const salt = crypto.randomBytes(SALT_BYTES).toString('hex');
    const account = {
      name, salt, hash: await derive(password, salt), master,
      permissions: rights.permissions, rank: master ? MASTER_RANK : rights.rank, createdAt: new Date().toISOString(),
    };
    store.accounts.push(account);
    save();
    return { ok: true, account: publicView(account) };
  },

  /** Vérifie identifiant et mot de passe ; renvoie la vue publique du compte, ou null. */
  async verify(name, password) {
    const index = typeof name === 'string' ? findIndex(name) : -1;
    const account = index === -1 ? null : store.accounts[index];
    const candidate = await derive(typeof password === 'string' ? password : '', account ? account.salt : DUMMY_SALT);
    if (!account) return null;
    const expected = Buffer.from(account.hash, 'hex');
    const given = Buffer.from(candidate, 'hex');
    return expected.length === given.length && crypto.timingSafeEqual(expected, given) ? publicView(account) : null;
  },

  /** Vue publique d'un compte existant, ou null (compte supprimé : ses sessions tombent). */
  get(name) {
    const index = findIndex(name);
    return index === -1 ? null : publicView(store.accounts[index]);
  },

  /** Tous les comptes, maître d'abord puis par nom. */
  list() {
    return store.accounts.map(publicView).sort((a, b) => Number(b.master) - Number(a.master) || a.name.localeCompare(b.name));
  },

  /** Droits et rang d'un compte (pas du maître, qui a tout). */
  update(name, { permissions, rank }) {
    const index = findIndex(name);
    if (index === -1) return { ok: false, error: 'unknown_account' };
    const account = store.accounts[index];
    if (account.master) return { ok: false, error: 'master_account' };
    const rights = rightsOf(permissions, rank);
    if (rights.error) return { ok: false, error: rights.error };
    account.permissions = rights.permissions;
    account.rank = rights.rank;
    save();
    return { ok: true, account: publicView(account) };
  },

  /** Nouveau mot de passe (le maître pour un compte, ou le compte lui-même). */
  async setPassword(name, password) {
    const index = findIndex(name);
    if (index === -1) return { ok: false, error: 'unknown_account' };
    const problem = checkPassword(password);
    if (problem) return { ok: false, error: problem };
    const account = store.accounts[index];
    account.salt = crypto.randomBytes(SALT_BYTES).toString('hex');
    account.hash = await derive(password, account.salt);
    save();
    return { ok: true };
  },

  /** Supprime un compte (jamais le maître) : ses sessions tombent à la requête suivante. */
  remove(name) {
    const index = findIndex(name);
    if (index === -1) return { ok: false, error: 'unknown_account' };
    if (store.accounts[index].master) return { ok: false, error: 'master_account' };
    store.accounts.splice(index, 1);
    save();
    return { ok: true };
  },

  /** Relit le fichier (tests). */
  reload() {
    store = config.readJson(FILE, { accounts: [] });
  },
};
