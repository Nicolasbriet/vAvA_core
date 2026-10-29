'use strict';
/*
 * lib/servercfg.js
 * Rôle : le server.cfg du serveur de jeu : lecture d'un fichier existant (les lignes inconnues sont gardées comme
 *        options avancées), validation d'un formulaire, écriture d'un fichier propre et commenté, sauvegarde de
 *        l'ancien (les 20 dernières). Toute valeur est nettoyée : un nom de serveur ne peut pas injecter de commande.
 *        Réglages qu'exige vAvA (voix de vava_voice) : écrits dans chaque fichier de l'assistant ; ajoutés à un
 *        fichier existant qui ne les pose pas par `setr`, sans toucher au reste (octets, BOM, fins de ligne) ; une
 *        valeur posée est gardée, un `set` signalé ; rien n'est écrit dans un fichier qui n'est pas en UTF-8 ou qui
 *        inclut d'autres fichiers (`exec`). Écriture sûre pour un fichier qui porte des secrets (voir write).
 *        Pour l'éditeur du fichier brut : secrets masqués (clé de licence, mot de passe de la base, clés d'API…) et
 *        remis à l'enregistrement, révision qui protège d'une écriture croisée ; lancement d'une ressource au
 *        démarrage ajouté ou retiré sans réécrire le reste.
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const config = require('./config');

const BACKUPS = path.join(config.DATA, 'backups');
const BACKUPS_KEPT = 20;
const ONESYNC = ['on', 'legacy', 'off'];
const LICENSE_PATTERN = /^cfxk_[A-Za-z0-9_]{10,200}$/;
const HOST_PATTERN = /^[A-Za-z0-9.-]{1,253}$/;
const BIND_PATTERN = /^(\d{1,3}\.){3}\d{1,3}$/;
const DATABASE_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;
const USER_PATTERN = /^[^\s"]{1,64}$/;
const RESOURCE_PATTERN = /^[A-Za-z0-9_.-]{1,64}$/;
// commandes que le formulaire gère : retirées des options avancées pour ne jamais être en double
const MANAGED = new Set(['endpoint_add_tcp', 'endpoint_add_udp', 'sv_hostname', 'sv_projectname', 'sv_projectdesc', 'sv_maxclients',
  'sv_licensekey', 'mysql_connection_string', 'onesync', 'sv_master1', 'sv_endpointprivacy', 'ensure', 'start']);

// réglages qu'exige vava_voice (docs/api.md) : son 3D du jeu, voix envoyée aux seuls joueurs à portée
const REQUIRED_TITLE = '## Voix (vava_voice) : son 3D du jeu, voix envoyée aux seuls joueurs à portée';
const REQUIRED = Object.freeze([
  { key: 'voice_usenativeaudio', line: 'setr voice_useNativeAudio true' },
  { key: 'voice_usesendingrangeonly', line: 'setr voice_useSendingRangeOnly true' },
]);

const DEFAULTS = Object.freeze({
  bind: '0.0.0.0', port: 30120, listed: true, hostname: 'Serveur vAvA', projectName: '', projectDesc: '',
  maxClients: 48, onesync: 'on', endpointPrivacy: true,
  db: { host: '127.0.0.1', port: 3306, user: 'root', database: 'vava' },
  resources: [], extra: '',
});

/** Mots d'une ligne de configuration : guillemets respectés. */
function words(line) {
  const out = [];
  const pattern = /"([^"]*)"|(\S+)/g;
  let match;
  while ((match = pattern.exec(line))) out.push(match[1] !== undefined ? match[1] : match[2]);
  return out;
}

/** Nom et valeur d'une commande, `set`/`sets`/`setr` compris : { key, value, parts }. */
function command(line) {
  const parts = words(line);
  if (!parts.length) return null;
  const head = parts[0].toLowerCase();
  if ((head === 'set' || head === 'sets' || head === 'setr') && parts.length >= 2) {
    return { key: parts[1].toLowerCase(), value: parts.slice(2).join(' '), parts };
  }
  return { key: head, value: parts.slice(1).join(' '), parts };
}

// noms acceptés par oxmysql dans la forme « clé=valeur; »
const MYSQL_KEYS = {
  host: 'host', hostname: 'host', ip: 'host', server: 'host', 'data source': 'host', datasource: 'host', addr: 'host', address: 'host',
  port: 'port', user: 'user', 'user id': 'user', userid: 'user', 'user name': 'user', username: 'user', uid: 'user',
  password: 'password', pwd: 'password', pass: 'password', database: 'database', db: 'database',
};
const OXMYSQL_URI = /^(?:([^:/?#.]+):)?(?:\/\/(?:([^/?#]*)@)?([\w\-Ā-￿.%]*)(?::([0-9]+))?)?([^?#]+)?(?:\?([^#]*))?$/;
// oxmysql lit le mot de passe d'une adresse mysql:// tel quel (sans décodage) : il n'y passe que s'il ne la casse pas
const URI_SAFE = /^[A-Za-z0-9\-._~!$&'()*+,;=]*$/;
// dans la forme « clé=valeur; », ni « = » ni « ; » (oxmysql coupe dessus)
const PAIR_SAFE = /^[^=;"\r\n]*$/;

/**
 * Chaîne de connexion oxmysql → champs, sous ses deux formes : mysql://utilisateur:motdepasse@hôte:port/base?…
 * ou host=…;user=…;password=…;database=… ; null si elle n'est ni l'une ni l'autre.
 */
function parseMysql(value) {
  if (/^mysql:\/\//i.test(value)) {
    // découpage identique à celui d'oxmysql : le mot de passe est lu tel qu'il l'utilisera
    const match = value.match(OXMYSQL_URI);
    if (!match || !match[3]) return null;
    const auth = match[2] ? match[2].split(':') : [];
    return {
      host: match[3], port: Number(match[4]) || 3306, user: auth[0] || '', password: auth[1] || '',
      database: (match[5] || '').replace(/^\/+/, ''),
    };
  }
  const out = { host: '', port: 3306, user: '', password: '', database: '' };
  for (const pair of value.split(';')) {
    const index = pair.indexOf('=');
    const key = MYSQL_KEYS[pair.slice(0, index).trim().toLowerCase()];
    if (index === -1 || !key) continue;
    const raw = pair.slice(index + 1).trim();
    out[key] = key === 'port' ? Number(raw) || 3306 : raw;
  }
  return out.host && out.database ? out : null;
}

/**
 * Lit un server.cfg. Les secrets sont séparés (`secrets`) : ils ne partent jamais vers le navigateur.
 * @param {string} text
 */
function parse(text) {
  const values = JSON.parse(JSON.stringify(DEFAULTS));
  const secrets = { licenseKey: '', dbPassword: '', playersToken: '' };
  const extra = [];
  let endpointSeen = false;
  for (const raw of String(text).split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#') || line.startsWith('//')) continue;
    const cmd = command(line);
    if (!cmd) continue;
    switch (cmd.key) {
      case 'endpoint_add_tcp': {
        if (endpointSeen) break;
        const [bind, port] = cmd.value.split(':');
        if (bind) values.bind = bind;
        if (Number(port)) values.port = Number(port);
        endpointSeen = true;
        break;
      }
      case 'endpoint_add_udp': break;
      case 'sv_hostname': values.hostname = cmd.value; break;
      case 'sv_projectname': values.projectName = cmd.value; break;
      case 'sv_projectdesc': values.projectDesc = cmd.value; break;
      case 'sv_maxclients': values.maxClients = Number(cmd.value) || values.maxClients; break;
      case 'sv_licensekey': secrets.licenseKey = cmd.value; break;
      case 'onesync': values.onesync = ONESYNC.includes(cmd.value) ? cmd.value : values.onesync; break;
      case 'sv_master1': values.listed = cmd.value !== ''; break;
      case 'sv_endpointprivacy': values.endpointPrivacy = cmd.value === 'true'; break;
      case 'mysql_connection_string': {
        const db = parseMysql(cmd.value);
        if (db) {
          secrets.dbPassword = db.password;
          values.db = { host: db.host, port: db.port, user: db.user, database: db.database };
        } else {
          extra.push(raw);
        }
        break;
      }
      case 'ensure':
      case 'start':
        if (cmd.parts[1] && !values.resources.includes(cmd.parts[1])) values.resources.push(cmd.parts[1]);
        break;
      // jeton de players.json posé à la main : la ligne reste telle quelle, la Chancellerie s'en sert pour lire les joueurs
      case 'sv_playerstoken':
        secrets.playersToken = cmd.value;
        extra.push(raw);
        break;
      default:
        extra.push(raw);
    }
  }
  values.extra = extra.join('\n');
  return { values, secrets };
}

/** Une valeur entre guillemets : ni guillemet ni retour à la ligne (aucune commande glissée). */
function quoted(value) {
  return `"${String(value).replace(/["\r\n]/g, '').trim()}"`;
}

const isInteger = (value, min, max) => Number.isInteger(value) && value >= min && value <= max;

/**
 * Valide un formulaire de configuration. Clé et mot de passe laissés vides : ceux d'avant sont gardés.
 * @returns {{ ok: true, values: object, secrets: object } | { ok: false, error: string, field: string }}
 */
function validate(form, previous, knownResources) {
  const fail = (field, error = 'invalid') => ({ ok: false, field, error });
  const f = form || {};
  const db = f.db || {};
  if (typeof f.hostname !== 'string' || !f.hostname.trim() || f.hostname.length > 80) return fail('hostname');
  if (typeof f.projectName !== 'string' || f.projectName.length > 80) return fail('projectName');
  if (typeof f.projectDesc !== 'string' || f.projectDesc.length > 200) return fail('projectDesc');
  if (!isInteger(f.maxClients, 1, 2048)) return fail('maxClients');
  if (typeof f.bind !== 'string' || !BIND_PATTERN.test(f.bind)) return fail('bind');
  if (!isInteger(f.port, 1024, 65535)) return fail('port');
  if (!ONESYNC.includes(f.onesync)) return fail('onesync');
  if (typeof f.licenseKey !== 'string' || (f.licenseKey && !LICENSE_PATTERN.test(f.licenseKey))) return fail('licenseKey');
  const licenseKey = f.licenseKey || previous.licenseKey;
  if (!licenseKey) return fail('licenseKey', 'required');
  if (typeof db.host !== 'string' || !HOST_PATTERN.test(db.host)) return fail('db.host');
  if (!isInteger(db.port, 1, 65535)) return fail('db.port');
  if (typeof db.user !== 'string' || !USER_PATTERN.test(db.user)) return fail('db.user');
  if (typeof db.database !== 'string' || !DATABASE_PATTERN.test(db.database)) return fail('db.database');
  if (typeof db.password !== 'string' || db.password.length > 200) return fail('db.password');
  const dbPassword = db.password || previous.dbPassword;
  if (!URI_SAFE.test(dbPassword) && !PAIR_SAFE.test(dbPassword)) return fail('db.password', 'unsupported_password');
  if (!URI_SAFE.test(db.user) && !PAIR_SAFE.test(db.user)) return fail('db.user');
  if (!Array.isArray(f.resources) || f.resources.length > 300) return fail('resources');
  for (const name of f.resources) {
    if (typeof name !== 'string' || !RESOURCE_PATTERN.test(name) || !knownResources.has(name)) return fail('resources', 'unknown_resource');
  }
  if (typeof f.extra !== 'string' || f.extra.length > 20000) return fail('extra');
  return {
    ok: true,
    values: {
      hostname: f.hostname.trim(), projectName: f.projectName.trim(), projectDesc: f.projectDesc.trim(), maxClients: f.maxClients,
      bind: f.bind, port: f.port, listed: f.listed === true, onesync: f.onesync, endpointPrivacy: f.endpointPrivacy !== false,
      db: { host: db.host, port: db.port, user: db.user, database: db.database },
      resources: [...new Set(f.resources)], extra: f.extra,
    },
    secrets: { licenseKey, dbPassword },
  };
}

/** Chaîne de connexion oxmysql : adresse mysql:// si identifiants s'y prêtent, sinon forme « clé=valeur; ». */
function connectionString(db, password) {
  if (URI_SAFE.test(db.user) && URI_SAFE.test(password)) {
    return `mysql://${db.user}${password ? `:${password}` : ''}@${db.host}:${db.port}/${db.database}?charset=utf8mb4`;
  }
  return `host=${db.host};port=${db.port};user=${db.user};password=${password};database=${db.database};charset=utf8mb4`;
}

/** Options avancées sans les commandes gérées par le formulaire. */
function cleanExtra(extra) {
  return String(extra).split(/\r?\n/).filter((line) => {
    const cmd = command(line.trim());
    return !cmd || !MANAGED.has(cmd.key);
  }).join('\n').trim();
}

/** Commande d'une ligne active (ni vide ni commentaire), ou null. */
function activeCommand(line) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#') || trimmed.startsWith('//')) return null;
  return command(trimmed);
}

/** Réglages exigés qu'un texte ne fixe nulle part, sous aucune forme (assistant : rien en double). */
function missingRequired(text) {
  const keys = new Set();
  for (const line of String(text).split(/\r?\n/)) {
    const cmd = activeCommand(line);
    if (cmd) keys.add(cmd.key);
  }
  return REQUIRED.filter((entry) => !keys.has(entry.key));
}

/** Morceaux d'une ligne séparés par des « ; » hors guillemets (FXServer y lit plusieurs commandes). */
function segments(line) {
  const out = [];
  let quoted = false;
  let start = 0;
  for (let i = 0; i < line.length; i += 1) {
    if (line[i] === '"') quoted = !quoted;
    else if (line[i] === ';' && !quoted) {
      out.push(line.slice(start, i));
      start = i + 1;
    }
  }
  out.push(line.slice(start));
  return out;
}

/**
 * Lignes d'un texte avec leur propre fin (\r\n, \n, ou rien pour la dernière) : rien n'est uniformisé.
 * @returns {{ lines: string[], eols: string[] }}
 */
function splitLines(text) {
  const lines = [];
  const eols = [];
  const pattern = /\r\n|\n/g;
  let last = 0;
  let match;
  while ((match = pattern.exec(text))) {
    lines.push(text.slice(last, match.index));
    eols.push(match[0]);
    last = pattern.lastIndex;
  }
  lines.push(text.slice(last));
  eols.push('');
  return { lines, eols };
}

/**
 * Ce qu'un server.cfg fait des réglages exigés. Ne compte comme posé qu'un `setr` lu sans ambiguïté ; un `set`, un
 * `sets` ou une convar nue (non répliqués aux joueurs) est signalé, jamais doublé. Un `exec` (fichier inclus, qui peut
 * les poser) ou une ligne à plusieurs commandes qui les touche rend le fichier douteux : on n'y écrit rien. Les
 * avertissements ne citent que des numéros de ligne (une ligne peut porter un secret).
 * @returns {{ missing: object[], doubts: object[], loose: object[] }}
 */
function analyzeRequired(lines) {
  const keys = new Set(REQUIRED.map((entry) => entry.key));
  const fixed = new Set();
  const loose = new Map();
  const doubts = [];
  lines.forEach((line, index) => {
    if (!activeCommand(line)) return;
    const parts = segments(line);
    const heads = parts.map((part) => activeCommand(part)).filter(Boolean);
    if (heads.some((cmd) => cmd.parts[0].toLowerCase() === 'exec')) {
      doubts.push({ code: 'exec', line: index + 1 });
      return;
    }
    if (parts.length > 1) {
      const lower = line.toLowerCase();
      if ([...keys].some((key) => lower.includes(key))) doubts.push({ code: 'ambiguous', line: index + 1 });
      return;
    }
    const cmd = heads[0];
    if (!cmd || !keys.has(cmd.key)) return;
    if (cmd.parts[0].toLowerCase() === 'setr') fixed.add(cmd.key);
    else if (!loose.has(cmd.key)) loose.set(cmd.key, index + 1);
  });
  return {
    missing: REQUIRED.filter((entry) => !fixed.has(entry.key) && !loose.has(entry.key)),
    doubts,
    loose: REQUIRED.filter((entry) => !fixed.has(entry.key) && loose.has(entry.key))
      .map((entry) => ({ code: 'set', key: entry.line.split(' ')[1], line: loose.get(entry.key) })),
  };
}

/**
 * Texte (sans BOM) complété des réglages exigés qui lui manquent, placés avant les lancements de ressources (et leur
 * titre), sinon à la fin ; chaque ligne garde sa fin, les lignes ajoutées prennent celle de leur voisine. Rien n'est
 * ajouté à un fichier douteux. Renvoie { text, added, warnings }.
 */
function withRequired(text) {
  const { lines, eols } = splitLines(String(text));
  const { missing, doubts, loose } = analyzeRequired(lines);
  const warnings = [...doubts, ...loose];
  if (doubts.length || !missing.length) return { text: String(text), added: [], warnings };
  let at = lines.findIndex((line) => {
    const cmd = activeCommand(line);
    return cmd && (cmd.key === 'ensure' || cmd.key === 'start');
  });
  let block;
  if (at === -1) {
    at = lines.length;
    while (at > 0 && !lines[at - 1].trim()) at -= 1;
    block = ['', REQUIRED_TITLE, ...missing.map((entry) => entry.line)];
  } else {
    while (at > 0 && lines[at - 1].trim().startsWith('#')) at -= 1;
    const spacer = at > 0 && lines[at - 1].trim() ? [''] : [];
    block = [...spacer, REQUIRED_TITLE, ...missing.map((entry) => entry.line), ''];
  }
  const eol = (at > 0 && eols[at - 1]) || eols.find(Boolean) || '\n';
  const blockEols = block.map(() => eol);
  if (at === lines.length) {
    // ajout après la dernière ligne, sans fin de ligne : elle en reçoit une, le bloc finit comme elle
    eols[at - 1] = eol;
    blockEols[blockEols.length - 1] = '';
  }
  lines.splice(at, 0, ...block);
  eols.splice(at, 0, ...blockEols);
  return { text: lines.map((line, i) => line + eols[i]).join(''), added: missing.map((entry) => entry.line), warnings };
}

// dernier état du fichier (chemin, date, taille) qui n'a pas pu être complété ou qui reste à vérifier, et sa réponse :
// tant qu'il ne change pas, rien n'est retenté ni réécrit au journal
let lastProblem = null;

// date de modification et taille : un droit rendu sans toucher au fichier n'est vu qu'au lancement de la Chancellerie
function stateKey(file) {
  const stat = fs.statSync(file);
  return `${file}|${stat.mtimeMs}|${stat.size}`;
}

/** Lecture, contrôle d'encodage, complément et écriture (voir complete). */
function completeNow(file) {
  let raw;
  try {
    raw = fs.readFileSync(file);
  } catch (error) {
    return { added: [], warnings: [], error: error.code || 'read_failed', missing: [] };
  }
  let text = raw.toString('utf8');
  // un fichier qui n'est pas en UTF-8 (ANSI d'un éditeur Windows…) ne survivrait pas intact à une réécriture
  if (!Buffer.from(text, 'utf8').equals(raw)) {
    return { added: [], warnings: [], error: 'encoding', missing: analyzeRequired(splitLines(text).lines).missing.map((e) => e.line) };
  }
  const bom = text.startsWith('﻿');
  if (bom) text = text.slice(1);
  const next = withRequired(text);
  if (!next.added.length) return { added: [], warnings: next.warnings };
  try {
    const backup = write(file, Buffer.from((bom ? '﻿' : '') + next.text, 'utf8'));
    return { added: next.added, warnings: next.warnings, backup };
  } catch (error) {
    return { added: [], warnings: next.warnings, error: error.code || error.message, missing: next.added };
  }
}

/**
 * Complète le server.cfg en place des réglages exigés qui lui manquent (serveur installé avant eux, fichier écrit à la
 * main), sans rien changer d'autre : octets, BOM et fins de ligne gardés ; fichier qui n'est pas en UTF-8 ou douteux
 * (exec, ligne à plusieurs commandes) : rien d'écrit, un avertissement. Fichier absent : rien. Un fichier inchangé
 * depuis un échec ou un avertissement n'est pas retenté (`repeated`).
 * @returns {{ added: string[], warnings: object[], backup?: string|null, error?: string, missing?: string[],
 *   repeated?: boolean }}
 */
function complete(file) {
  let key;
  try {
    key = stateKey(file);
  } catch (error) {
    return { added: [], warnings: [] };
  }
  if (lastProblem && lastProblem.key === key) return { ...lastProblem.result, repeated: true };
  const result = completeNow(file);
  lastProblem = null;
  if (result.error || result.warnings.length) {
    try {
      // l'état gardé est celui d'après l'écriture éventuelle : un ajout fait n'est jamais redit
      lastProblem = { key: stateKey(file), result: { ...result, added: [], backup: null } };
    } catch (error) {
      lastProblem = null;
    }
  }
  return result;
}

/** Texte complet du server.cfg. */
function generate(values, secrets) {
  const connection = connectionString(values.db, secrets.dbPassword);
  const lines = [
    `# server.cfg — écrit par la Chancellerie (vAvA) le ${new Date().toLocaleString('fr-FR')}.`,
    '# Modifiez-le depuis la Chancellerie : une ligne ajoutée ici à la main sera reprise dans les options avancées.',
    '',
    '## Réseau',
    `endpoint_add_tcp ${quoted(`${values.bind}:${values.port}`)}`,
    `endpoint_add_udp ${quoted(`${values.bind}:${values.port}`)}`,
    ...(values.listed ? [] : ['sv_master1 ""']),
    `sv_endpointprivacy ${values.endpointPrivacy ? 'true' : 'false'}`,
    '',
    '## Identité',
    `sv_hostname ${quoted(values.hostname)}`,
    ...(values.projectName ? [`sets sv_projectName ${quoted(values.projectName)}`] : []),
    ...(values.projectDesc ? [`sets sv_projectDesc ${quoted(values.projectDesc)}`] : []),
    `sv_maxclients ${values.maxClients}`,
    '',
    '## Moteur',
    `set onesync ${values.onesync}`,
    '',
    '## Licence et base de données (secrets : ce fichier ne se partage pas)',
    `sv_licenseKey ${quoted(secrets.licenseKey)}`,
    `set mysql_connection_string ${quoted(connection)}`,
  ];
  const extra = cleanExtra(values.extra);
  // un réglage exigé déjà posé dans les options avancées y reste, avec sa valeur
  const required = missingRequired(extra);
  if (required.length) lines.push('', REQUIRED_TITLE, ...required.map((entry) => entry.line));
  if (extra) lines.push('', '## Options avancées', extra);
  lines.push('', '## Ressources (dans l\'ordre de démarrage)', ...values.resources.map((name) => `ensure ${name}`), '');
  return lines.join('\n');
}

/** Garde les BACKUPS_KEPT dernières sauvegardes du server.cfg. Un échec ne remet pas en cause l'écriture faite. */
function rotateBackups() {
  try {
    const all = fs.readdirSync(BACKUPS).filter((name) => name.endsWith('.bak')).sort();
    for (const old of all.slice(0, Math.max(0, all.length - BACKUPS_KEPT))) fs.unlinkSync(path.join(BACKUPS, old));
  } catch (error) {
    console.error(`[Chancellerie] anciennes sauvegardes du server.cfg non retirées : ${error.message}`);
  }
}

function removeQuietly(file) {
  try {
    fs.unlinkSync(file);
  } catch (error) {
    // déjà absent
  }
}

/**
 * Écrit le server.cfg (il porte des secrets : rien ne doit le laisser à moitié écrit). Droit d'écriture vérifié
 * d'abord ; un lien symbolique est suivi (sa cible est écrite, le lien reste) ; le nouveau contenu part dans un
 * temporaire au nom unique, créé seul (`wx`) avec les droits de l'ancien fichier ; puis l'ancien est copié dans les
 * sauvegardes et le temporaire renommé à sa place. Un échec supprime le temporaire et la copie de ce tour : rien n'a
 * changé. Les anciennes sauvegardes ne sont retirées qu'après un succès. Toutes les écritures du fichier passent ici
 * (assistant, éditeur, lancement au démarrage, restauration, complément de la voix).
 * @param {string} file
 * @param {string|Buffer} data
 * @returns {string|null} nom de la sauvegarde ; lève l'erreur d'écriture
 */
function write(file, data) {
  const exists = fs.existsSync(file);
  const target = exists ? fs.realpathSync(file) : file;
  const options = { flag: 'wx' };
  if (exists) {
    fs.accessSync(target, fs.constants.W_OK);
    options.mode = fs.statSync(target).mode & 0o777;
  } else {
    fs.accessSync(path.dirname(target), fs.constants.W_OK);
  }
  const temporary = `${target}.${process.pid}-${crypto.randomBytes(6).toString('hex')}.tmp`;
  let backup = null;
  let copied = false;
  try {
    fs.writeFileSync(temporary, data, options);
    if (exists) {
      fs.mkdirSync(BACKUPS, { recursive: true });
      const stamp = new Date().toISOString().replace(/[:.]/g, '-');
      backup = `server.cfg.${stamp}.bak`;
      // deux écritures dans la même milliseconde : jamais une sauvegarde écrasée
      for (let n = 2; fs.existsSync(path.join(BACKUPS, backup)); n += 1) backup = `server.cfg.${stamp}-${n}.bak`;
      fs.copyFileSync(target, path.join(BACKUPS, backup), fs.constants.COPYFILE_EXCL);
      copied = true;
    }
    fs.renameSync(temporary, target);
  } catch (error) {
    removeQuietly(temporary);
    if (copied) removeQuietly(path.join(BACKUPS, backup));
    throw error;
  }
  if (backup) rotateBackups();
  return backup;
}

function read(file) {
  if (!file || !fs.existsSync(file)) return { values: JSON.parse(JSON.stringify(DEFAULTS)), secrets: { licenseKey: '', dbPassword: '', playersToken: '' }, exists: false };
  return { ...parse(fs.readFileSync(file, 'utf8')), exists: true };
}

let cache = { file: '', mtime: 0, current: null };

/** Le server.cfg géré, lu (valeurs et secrets) seulement s'il a changé ; null s'il n'existe pas. */
function current() {
  const file = config.cfgPath();
  let mtime = 0;
  try {
    mtime = fs.statSync(file).mtimeMs;
  } catch (error) {
    return null;
  }
  if (cache.file !== file || cache.mtime !== mtime) cache = { file, mtime, current: read(file) };
  return cache.current;
}

/** Adresse du serveur de jeu d'après le server.cfg : { bind, port }, ou null. */
function endpoint() {
  const cfg = current();
  return cfg ? { bind: cfg.values.bind, port: cfg.values.port } : null;
}

// Fichier brut (éditeur) ----------------------------------------------------------------------------------------------

// réglages dont la valeur est un secret : masquée avant de partir vers le navigateur, remise à l'enregistrement
const SECRET_KEY = /^(sv_licensekey|rcon_password|steam_webapikey|sv_tebexsecret)$|(password|passwd|secret|token|apikey|api_key)$/;
const PLACEHOLDER = (index) => `••••secret-${index}••••`;
const PLACEHOLDER_PATTERN = /••••secret-(\d+)••••/g;

/** Révision d'un texte : l'éditeur la renvoie, un fichier changé entre-temps n'est pas écrasé. */
function revision(text) {
  return crypto.createHash('sha256').update(text).digest('hex').slice(0, 20);
}

/** Masque une valeur trouvée dans une ligne (sa dernière occurrence, après la clé). */
function maskIn(line, value, secrets) {
  const index = line.lastIndexOf(value);
  if (!value || index === -1) return line;
  secrets.push(value);
  return line.slice(0, index) + PLACEHOLDER(secrets.length) + line.slice(index + value.length);
}

/** Mot de passe d'une chaîne oxmysql masqué dans sa ligne. */
function maskMysql(line, value, secrets) {
  const db = parseMysql(value);
  if (!db || !db.password) return line;
  if (/^mysql:\/\//i.test(value)) {
    const needle = `:${db.password}@`;
    const index = line.indexOf(needle);
    if (index === -1) return line;
    secrets.push(db.password);
    return `${line.slice(0, index + 1)}${PLACEHOLDER(secrets.length)}${line.slice(index + needle.length - 1)}`;
  }
  return line.replace(/((?:^|;|")\s*(?:password|pwd|pass)\s*=\s*)([^;"]*)/i, (whole, head, secret) => {
    if (!secret) return whole;
    secrets.push(secret);
    return head + PLACEHOLDER(secrets.length);
  });
}

/**
 * Texte du server.cfg sans ses secrets : { text, secrets } (secrets reste sur le serveur, dans l'ordre des
 * marques « ••••secret-1•••• » laissées dans le texte).
 */
function mask(text) {
  const secrets = [];
  const lines = String(text).split('\n').map((raw) => {
    const trimmed = raw.trim();
    if (!trimmed || trimmed.startsWith('#') || trimmed.startsWith('//')) return raw;
    const cmd = command(trimmed);
    if (!cmd || !cmd.value) return raw;
    if (cmd.key === 'mysql_connection_string') return maskMysql(raw, cmd.value, secrets);
    if (SECRET_KEY.test(cmd.key)) return maskIn(raw, cmd.parts[cmd.parts.length - 1], secrets);
    return raw;
  });
  return { text: lines.join('\n'), secrets };
}

/** Remet les secrets à la place de leurs marques ; null si une marque ne correspond à aucun secret. */
function unmask(text, secrets) {
  let unknown = false;
  const out = String(text).replace(PLACEHOLDER_PATTERN, (whole, number) => {
    const secret = secrets[Number(number) - 1];
    if (secret === undefined) unknown = true;
    return secret === undefined ? whole : secret;
  });
  return unknown ? null : out;
}

/** La ressource est-elle lancée au démarrage (ligne ensure ou start) ? */
function isAutostart(text, name) {
  return String(text).split(/\r?\n/).some((line) => {
    const cmd = command(line.trim());
    return cmd && (cmd.key === 'ensure' || cmd.key === 'start') && cmd.parts[1] === name;
  });
}

/**
 * Ajoute ou retire le lancement d'une ressource au démarrage, sans toucher au reste du fichier. Une ressource ajoutée
 * prend sa place dans l'ordre attendu par vAvA (`rank`), sinon après la dernière ligne ensure.
 * @param {(name: string) => number} rank
 */
function setAutostart(text, name, enabled, rank) {
  const eol = String(text).includes('\r\n') ? '\r\n' : '\n';
  const lines = String(text).split(/\r?\n/);
  const isLaunch = (line) => {
    const cmd = command(line.trim());
    return cmd && !line.trim().startsWith('#') && (cmd.key === 'ensure' || cmd.key === 'start') ? cmd.parts[1] : null;
  };
  if (!enabled) return lines.filter((line) => isLaunch(line) !== name).join(eol);
  if (lines.some((line) => isLaunch(line) === name)) return lines.join(eol);
  let at = -1;
  for (let i = 0; i < lines.length; i += 1) {
    const other = isLaunch(lines[i]);
    if (!other) continue;
    if (rank(other) > rank(name)) {
      at = i;
      break;
    }
    at = i + 1;
  }
  if (at === -1) {
    // aucune ligne de lancement : à la fin, avant les lignes vides finales
    at = lines.length;
    while (at > 0 && !lines[at - 1].trim()) at -= 1;
  }
  lines.splice(at, 0, `ensure ${name}`);
  return lines.join(eol);
}

module.exports = {
  parse, validate, generate, write, read, current, endpoint, cleanExtra, mask, unmask, revision, isAutostart, setAutostart,
  missingRequired, withRequired, complete, DEFAULTS, BACKUPS, RESOURCE_PATTERN, REQUIRED,
};
