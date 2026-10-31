'use strict';
/*
 * vava_pause/web/js/model.js
 * Rôle : règles pures de la bannière, sans DOM : entrées de la bannière (réduite à terre), rubrique de départ,
 *        couleurs et confrérie revérifiées, sous-titre et tableau des savoir-faire, nombres en lettres, plaque,
 *        encart de la demande au Conseil, octets d'un message, réglages et touches. Ce que le jeu envoie est relu
 *        ici : une valeur inattendue devient une absence, jamais une erreur.
 * Dépendances : strings.js (STRINGS) ; window.PauseModel dans la page, module.exports sous node (essais)
 */

const PauseModel = ((S) => {
  const PANELS = ['personnage', 'carte', 'reglages', 'conseil'];
  const RUBRICS = ['personnage', 'codex', 'carte', 'reglages', 'conseil', 'quitter'];
  const KINDS = ['question', 'player', 'bug', 'other'];
  const TABS = ['interface', 'voix', 'touches'];
  const MAX_TEXT = 500;   // octets : VavaPause.MAX_COUNCIL_TEXT (le serveur revérifie)
  const MIN_CHARS = 10;
  const NOVICE_BELOW = 20;
  const TABLE_MAX = 6;
  const TABLE_FALLBACK = 4;
  // teintes royales et encres des rangs : celles de config_client.lua, remplacées par celles du message `open`
  const ROYAL = Object.freeze({ cloth: '#6e2116', clothDark: '#4a150d', field: '#273b56', charge: 'croix' });
  const RANK_INKS = Object.freeze({ novice: '#6b5640', apprenti: '#3f5a33', compagnon: '#7c5d22', artisan: '#7c5d22',
    maitre: '#8e2c1d', grand_maitre: '#8e2c1d' });
  const CHARGES = ['croix'];

  const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
  const list = (value) => (Array.isArray(value) ? value : []);
  const text = (value, max) => (typeof value === 'string' && value.length > 0 ? value.slice(0, max) : null);
  const finite = (value) => typeof value === 'number' && Number.isFinite(value);
  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

  /** Couleur « #rrggbb » ou null (jamais posée telle quelle si elle ne passe pas). */
  function color(value) {
    return typeof value === 'string' && /^#[0-9a-f]{6}$/i.test(value) ? value.toLowerCase() : null;
  }

  /** Entrées de la bannière ; à terre : Reprendre, puis Paramètres du jeu et Quitter (les autres sont absentes). */
  function entries(downed) {
    const all = [
      { id: 'reprendre', kind: 'action' },
      { id: 'personnage', kind: 'panel' },
      { id: 'codex', kind: 'codex' },
      { id: 'carte', kind: 'panel' },
      { id: 'reglages', kind: 'panel' },
      { id: 'conseil', kind: 'panel' },
      { id: 'sep', kind: 'sep' },
      { id: 'parametres', kind: 'action', small: true },
      { id: 'quitter', kind: 'dialog', small: true },
    ];
    return downed ? all.filter((entry) => entry.kind !== 'panel' && entry.kind !== 'codex') : all;
  }

  /** Rubrique montrée à l'ouverture : celle demandée si elle a un panneau, sinon Personnage ; à terre, aucune. */
  function startRubric(wanted, downed) {
    if (downed) return null;
    return PANELS.includes(wanted) ? wanted : 'personnage';
  }

  /** Teintes de la bannière : confrérie si ses couleurs passent, sinon teintes royales (chacune revérifiée). */
  function banner(royal, guild) {
    const base = {
      cloth: color(royal && royal.cloth) || ROYAL.cloth,
      clothDark: color(royal && royal.clothDark) || ROYAL.clothDark,
      field: color(royal && royal.field) || ROYAL.field,
      charge: CHARGES.includes(royal && royal.charge) ? royal.charge : ROYAL.charge,
    };
    if (!guild) return base;
    return {
      cloth: guild.cloth || base.cloth,
      clothDark: guild.clothDark || base.clothDark,
      field: guild.field || base.field,
      charge: CHARGES.includes(guild.charge) ? guild.charge : 'croix',
    };
  }

  /** Confrérie relue (le serveur l'a déjà validée) ; sans libellé ni nom court : aucune. */
  function guild(raw) {
    if (!isObject(raw)) return null;
    const label = text(raw.label, 48);
    const short = text(raw.short, 16);
    if (!label || !short) return null;
    return {
      label, short, grade: text(raw.grade, 32),
      cloth: color(raw.cloth), clothDark: color(raw.clothDark), field: color(raw.field),
      charge: typeof raw.charge === 'string' ? raw.charge : 'croix',
    };
  }

  /** Savoir-faire relus : id, libellé, niveau 0 à 100, rang ; une ligne malformée est écartée. */
  function skills(raw) {
    const out = [];
    for (const row of list(raw)) {
      if (!isObject(row) || !finite(row.level)) continue;
      const label = text(row.label, 64);
      if (!label) continue;
      out.push({
        id: text(row.id, 64) || label, label, level: clamp(Math.floor(row.level), 0, 100),
        rank: text(row.rank, 32) || '', rankLabel: text(row.rankLabel, 32) || '',
      });
    }
    return out;
  }

  /** Métier principal : le plus haut niveau (égalité : ordre reçu). */
  function mainSkill(list_) {
    let best = null;
    for (const skill of list_) if (!best || skill.level > best.level) best = skill;
    return best;
  }

  const aboveNovice = (skill) => skill.level >= NOVICE_BELOW;

  /** Sous-titre sous le nom : confrérie, sinon rang du métier principal (au moins Apprenti), sinon nouveau venu. */
  function subtitle(list_, guild_) {
    if (guild_) return guild_.grade ? S.personnage.subtitleGuild(guild_.grade, guild_.label) : guild_.label;
    const main = mainSkill(list_);
    if (main && aboveNovice(main) && main.rankLabel) return S.personnage.subtitleTrade(main.rankLabel, main.label);
    return S.personnage.newcomer;
  }

  /**
   * Lignes du tableau : au-dessus de Novice, six au plus ; aucune : les quatre plus hautes ; `all` : toutes.
   * Rend { rows, hidden (non montrées), hiddenNovice (dont au rang Novice) }.
   */
  function table(list_, all) {
    const sorted = list_.map((skill, index) => ({ skill, index }))
      .sort((a, b) => b.skill.level - a.skill.level || a.index - b.index)
      .map((entry) => entry.skill);
    let rows;
    if (all) rows = sorted;
    else {
      rows = sorted.filter(aboveNovice).slice(0, TABLE_MAX);
      if (rows.length === 0) rows = sorted.slice(0, TABLE_FALLBACK);
    }
    const shown = new Set(rows);
    const rest = sorted.filter((skill) => !shown.has(skill));
    return { rows, hidden: rest.length, hiddenNovice: rest.filter((skill) => !aboveNovice(skill)).length };
  }

  /** Nombre en lettres jusqu'à vingt, en chiffres au-delà. */
  function numberWord(n) {
    return Number.isInteger(n) && n >= 0 && n < S.numbers.length ? S.numbers[n] : String(n);
  }

  /** Phrase sous le tableau (sans la maxime), ou null s'il ne cache rien. */
  function restLine(hidden, hiddenNovice) {
    if (hidden <= 0) return null;
    if (hiddenNovice === hidden) return S.personnage.restNovice(hidden, numberWord(hidden));
    return S.personnage.restOther(hidden, numberWord(hidden));
  }

  /** Part de 0 à 1, ou null si la valeur manque ; `max` : 1 (vie) ou 100 (faim, soif, niveau). */
  function fraction(value, max) {
    return finite(value) && max > 0 ? clamp(value / max, 0, 1) : null;
  }

  /** Âge d'une demande (secondes) en mots. */
  function ageText(seconds) {
    const s = finite(seconds) && seconds > 0 ? Math.floor(seconds) : 0;
    if (s < 60) return S.conseil.age.now;
    if (s < 3600) return S.conseil.age.minutes(Math.floor(s / 60));
    return S.conseil.age.hours(Math.floor(s / 3600));
  }

  /** Encart de suivi d'une demande : { tone, title, text } ou null. */
  function requestCard(request) {
    if (!isObject(request)) return null;
    if (request.state === 'sent') {
      const id = Number.isInteger(request.id) && request.id > 0 ? request.id : '?';
      return { tone: 'sent', title: S.conseil.sent(id), text: S.conseil.sentText(ageText(request.age)) };
    }
    if (request.state === 'claimed') return { tone: 'claimed', title: S.conseil.claimed, text: S.conseil.claimedText };
    if (request.state === 'closed') return { tone: 'closed', title: S.conseil.closed, text: S.conseil.closedText };
    return null;
  }

  /** Message d'un refus du Conseil. */
  function councilError(code, wait) {
    const errors = S.conseil.errors;
    if (code === 'too_soon') return errors.too_soon(finite(wait) && wait > 0 ? Math.ceil(wait) : 60);
    if (typeof errors[code] === 'string') return errors[code];
    return errors.default;
  }

  /** Taille en octets UTF-8 (celle que compte le serveur). */
  function bytes(value) {
    let n = 0;
    for (const char of String(value)) {
      const code = char.codePointAt(0);
      n += code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
    }
    return n;
  }

  /** Texte coupé à `max` octets, sans couper un caractère. */
  function clipBytes(value, max) {
    let n = 0;
    let out = '';
    for (const char of String(value)) {
      const size = bytes(char);
      if (n + size > max) break;
      n += size;
      out += char;
    }
    return out;
  }

  /** Nombre de caractères une fois les bords et espaces répétés retirés (comme le serveur les compte). */
  function chars(value) {
    return Array.from(String(value).replace(/\s+/g, ' ').trim()).length;
  }

  /** Avant l'envoi : null si le message peut partir, sinon le code du refus (le serveur revérifie). */
  function councilCheck(kind, value) {
    if (!KINDS.includes(kind)) return 'invalid_kind';
    if (chars(value) < MIN_CHARS) return 'too_short';
    if (bytes(value) > MAX_TEXT) return 'invalid_text';
    return null;
  }

  /** La position est forcée pour un signalement de joueur. */
  const positionForced = (kind) => kind === 'player';

  /** Habitants : texte déjà mis en forme, sinon nombre mis en forme, sinon null. */
  function people(data) {
    if (!isObject(data)) return null;
    if (isObject(data.plaque) && text(data.plaque.people, 48)) return data.plaque.people.slice(0, 48);
    if (Number.isInteger(data.people) && data.people >= 0) return data.people === 1 ? S.plaque.people.one : S.plaque.people.many(data.people);
    return null;
  }

  /** Parties de la plaque, dans l'ordre ; une partie absente est omise. */
  function plaque(local, data) {
    const own = isObject(local) && isObject(local.plaque) ? local.plaque : {};
    return [text(own.time, 32), text(own.season, 32), people(data)].filter(Boolean);
  }

  /** Distance d'une portée de voix : « 5 m », « 1,5 m ». */
  function meters(value) {
    if (!finite(value) || value < 0) return null;
    return `${String(Math.round(value * 10) / 10).replace('.', ',')} m`;
  }

  /** Échelle de la page d'après `ui.scale` (90, 100, 115…) ; hors bornes : 1. */
  function scale(value) {
    return finite(value) && value >= 50 && value <= 200 ? value / 100 : 1;
  }

  /** Définitions de réglages relues ; une définition sans clé, onglet ou sorte connus est écartée. */
  function settingDefs(raw) {
    const out = [];
    for (const def of list(raw)) {
      if (!isObject(def) || !text(def.key, 64) || !TABS.includes(def.tab)) continue;
      if (def.kind === 'choice') {
        const choices = list(def.choices).filter((value) => finite(value) || typeof value === 'string');
        if (choices.length === 0) continue;
        const labels = list(def.labels);
        out.push({ key: def.key, tab: def.tab, kind: 'choice', label: text(def.label, 80) || def.key, help: text(def.help, 160),
          default: def.default, choices, labels: choices.map((value, i) => text(labels[i], 32) || String(value)) });
      } else if (def.kind === 'lever') {
        out.push({ key: def.key, tab: def.tab, kind: 'lever', label: text(def.label, 80) || def.key, help: text(def.help, 160),
          default: def.default === true });
      }
    }
    return out;
  }

  /** Valeur d'un réglage : celle reçue si elle est permise, sinon son défaut. */
  function settingValue(def, values) {
    const value = isObject(values) ? values[def.key] : undefined;
    if (def.kind === 'lever') return typeof value === 'boolean' ? value : def.default;
    return def.choices.includes(value) ? value : def.default;
  }

  /** Touches relues et groupées par chapitre (ordre reçu) ; touche montrée : celle liée par le joueur d'abord. */
  function keyGroups(keys, labels) {
    const bound = isObject(labels) ? labels : {};
    const groups = [];
    for (const entry of list(keys)) {
      if (!isObject(entry) || !text(entry.name, 64) || !text(entry.label, 96)) continue;
      const key = text(bound[entry.name], 24) || text(entry.keyDisplay, 24) || text(entry.key, 24) || '?';
      const chapter = text(entry.chapter, 48) || '';
      let group = groups.length > 0 ? groups[groups.length - 1] : null;
      if (!group || group.chapter !== chapter) {
        group = { chapter, rows: [] };
        groups.push(group);
      }
      group.rows.push({ name: entry.name, label: entry.label.slice(0, 96), key, hold: entry.hold === true, module: text(entry.module, 64) });
    }
    return groups;
  }

  /** Touche du changement de portée de la voix (première touche du module vava_voice), ou null. */
  function voiceKey(keys, labels) {
    for (const group of keyGroups(keys, labels)) {
      for (const row of group.rows) if (row.module === 'vava_voice') return row.key;
    }
    return null;
  }

  /** Durée d'animation (ms) : celle reçue, bornée ; 0 sans animation. */
  function rollMs(value) {
    return finite(value) ? clamp(Math.round(value), 0, 1000) : 250;
  }

  return {
    PANELS, RUBRICS, KINDS, TABS, MAX_TEXT, MIN_CHARS, ROYAL, RANK_INKS,
    color, entries, startRubric, banner, guild, skills, mainSkill, subtitle, table, numberWord, restLine, fraction,
    ageText, requestCard, councilError, bytes, clipBytes, chars, councilCheck, positionForced, people, plaque, meters,
    scale, settingDefs, settingValue, keyGroups, voiceKey, rollMs,
  };
})(typeof STRINGS === 'object' ? STRINGS : require('./strings.js'));

if (typeof module === 'object' && module && module.exports) module.exports = PauseModel;
