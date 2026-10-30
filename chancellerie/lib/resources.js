'use strict';
/*
 * lib/resources.js
 * Rôle : ressources présentes dans le dossier du serveur, comme FiveM les trouve : un dossier avec un fxmanifest.lua
 *        (ou __resource.lua), éventuellement rangé dans des catégories [entre crochets] ; les liens (jonctions) sont
 *        suivis. Ordre de démarrage recommandé pour les ressources connues de vAvA.
 */

const fs = require('fs');
const path = require('path');

const MANIFESTS = ['fxmanifest.lua', '__resource.lua'];
const MAX_DEPTH = 4;
// ordre de démarrage attendu par vAvA ; une ressource inconnue garde la place choisie, après celles-ci. vava_ui (polices
// et textures communes des pages) juste après le core, avant la première ressource à page.
const KNOWN_ORDER = ['chat', 'sessionmanager', 'hardcap', 'oxmysql', 'vAvA_core', 'vava_ui', 'vava_chat', 'vava_world', 'vava_time',
  'vava_appearance', 'vava_characters_ui', 'vava_hud', 'vava_inventory', 'vava_needs', 'vava_health', 'vava_admin', 'vava_voice',
  'vava_cameras', 'vava_magic', 'vava_skills', 'vava_gathering', 'vava_crafting', 'vava_farming', 'vava_codex', 'vava_chancellerie'];
const CORE_DESCRIPTIONS = {
  vAvA_core: 'Le cœur du serveur (obligatoire)',
  oxmysql: 'Accès à la base de données (obligatoire)',
  vava_ui: 'Polices, textures et ornements communs des interfaces (aucun script)',
  vava_chat: 'Chat du royaume : hors-RP, /me, /do, messages privés, Conseil (remplace « chat »)',
  vava_appearance: 'Apparence des personnages',
  vava_characters_ui: 'Écran de sélection et de création',
  vava_hud: 'Jauges et notifications à l\'écran',
  vava_inventory: 'Inventaire en grille',
  vava_needs: 'Faim et soif',
  vava_health: 'Santé, mise à terre, réanimation',
  vava_admin: 'Registre du Conseil (administration en jeu)',
  vava_world: 'Carte sans PNJ ni véhicules',
  vava_time: 'Ciel et heure du royaume : heure de Paris, saisons, ciel, nuits de gel, décisions du Conseil',
  vava_voice: 'Chat vocal de proximité',
  vava_cameras: 'Écran des joueurs pour le Conseil (mur des caméras)',
  vava_magic: 'Magie : roue des sorts, mode magie, états, zones, sorts de feu, d\'eau et de terre, combinaisons, Lueur, Murmure, grimoire et registre',
  vava_skills: 'Compétences : niveaux et rangs, rouille, pénurie, mentorat et Renommée, recettes transmises et lignées (fondation des métiers)',
  vava_gathering: 'Récolte : zones à vitalité sur la carte, nœuds, outils en main, qualité et provenance, pêche, pistes de gibier',
  vava_crafting: 'Artisanat : stations, recettes, qualité, objets signés, poinçon, baptême, réparation, leçons',
  vava_farming: 'Agriculture : parcelles, croissance par dates, humidité et fertilité, qualité, grenier commun',
  vava_codex: 'Codex : toutes les commandes et touches du serveur, classées, cherchées, composées et lancées (F1)',
  vava_chancellerie: 'Pont de la Chancellerie (administration du royaume depuis le web)',
  // outils de développement ([vava-dev]) : à n'activer que sur un serveur de test
  vava_example: 'Exemple (dev) : module minimal, modèle pour en écrire un',
  vava_example_items: 'Exemple (dev) : objets d\'inventaire avec leurs images',
  vava_dev_characters: 'Outil de test (dev) : /perso, /respawn, /objet, /besoins, /vie, /aterre — aucun contrôle',
  vava_anim_test: 'Outil de test (dev) : animations personnalisées (.ycd dans stream/), /anim, /epee — aucun contrôle',
};

const MANIFEST_READ_MAX = 64 * 1024;
const MANIFEST_FIELDS = ['version', 'author', 'description'];

function isDirectory(full) {
  try {
    return fs.statSync(full).isDirectory();
  } catch (error) {
    return false;
  }
}

/** Version, auteur et description déclarés par un manifeste (`version '1.0.0'`, `author "…"`). */
function manifestDetails(dir) {
  const file = MANIFESTS.map((manifest) => path.join(dir, manifest)).find((candidate) => fs.existsSync(candidate));
  const out = { version: '', author: '' };
  if (!file) return out;
  let text = '';
  try {
    const handle = fs.openSync(file, 'r');
    const buffer = Buffer.alloc(MANIFEST_READ_MAX);
    const size = fs.readSync(handle, buffer, 0, MANIFEST_READ_MAX, 0);
    fs.closeSync(handle);
    text = buffer.subarray(0, size).toString('utf8');
  } catch (error) {
    return out;
  }
  for (const field of MANIFEST_FIELDS) {
    const match = new RegExp(`^\\s*${field}\\s*\\(?\\s*(['"])(.*?)\\1`, 'm').exec(text);
    if (match) out[field] = match[2].slice(0, 160);
  }
  return out;
}

/**
 * Ressources trouvées : [{ name, category, description }], triées par nom. `details` : version, auteur et
 * description lus dans chaque manifeste, et dossier (relatif à resources).
 * @param {string} serverDataPath
 * @param {{ details?: boolean }} [options]
 */
function scan(serverDataPath, { details = false } = {}) {
  const root = path.join(serverDataPath || '', 'resources');
  const found = new Map();
  function walk(dir, category, depth) {
    if (depth > MAX_DEPTH) return;
    let entries;
    try {
      entries = fs.readdirSync(dir);
    } catch (error) {
      return;
    }
    for (const name of entries) {
      const full = path.join(dir, name);
      if (!isDirectory(full)) continue;
      if (name.startsWith('[') && name.endsWith(']')) {
        walk(full, name.slice(1, -1), depth + 1);
      } else if (MANIFESTS.some((manifest) => fs.existsSync(path.join(full, manifest))) && !found.has(name)) {
        const resource = { name, category: category || '', description: CORE_DESCRIPTIONS[name] || '' };
        if (details) {
          const manifest = manifestDetails(full);
          Object.assign(resource, { version: manifest.version, author: manifest.author, folder: path.relative(root, full) });
          if (!resource.description) resource.description = manifest.description || '';
        }
        found.set(name, resource);
      }
    }
  }
  walk(root, '', 0);
  return [...found.values()].sort((a, b) => a.name.localeCompare(b.name));
}

/** Ordre de démarrage : les ressources connues de vAvA dans leur ordre, puis les autres dans l'ordre donné. */
function order(names) {
  const rank = (name) => {
    const index = KNOWN_ORDER.indexOf(name);
    return index === -1 ? KNOWN_ORDER.length : index;
  };
  return names.map((name, index) => ({ name, index })).sort((a, b) => rank(a.name) - rank(b.name) || a.index - b.index).map((e) => e.name);
}

/** Rang d'une ressource dans l'ordre de démarrage de vAvA (les inconnues après toutes les autres). */
function rank(name) {
  const index = KNOWN_ORDER.indexOf(name);
  return index === -1 ? KNOWN_ORDER.length : index;
}

module.exports = { scan, order, rank, KNOWN_ORDER };
