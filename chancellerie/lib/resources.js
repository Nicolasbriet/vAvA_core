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
// ordre de démarrage attendu par vAvA ; une ressource inconnue garde la place choisie, après celles-ci
const KNOWN_ORDER = ['chat', 'sessionmanager', 'hardcap', 'oxmysql', 'vAvA_core', 'vava_world', 'vava_appearance',
  'vava_characters_ui', 'vava_hud', 'vava_inventory', 'vava_needs', 'vava_health', 'vava_admin', 'vava_voice', 'vava_cameras',
  'vava_chancellerie'];
const CORE_DESCRIPTIONS = {
  vAvA_core: 'Le cœur du serveur (obligatoire)',
  oxmysql: 'Accès à la base de données (obligatoire)',
  vava_appearance: 'Apparence des personnages',
  vava_characters_ui: 'Écran de sélection et de création',
  vava_hud: 'Jauges et notifications à l\'écran',
  vava_inventory: 'Inventaire en grille',
  vava_needs: 'Faim et soif',
  vava_health: 'Santé, mise à terre, réanimation',
  vava_admin: 'Registre du Conseil (administration en jeu)',
  vava_world: 'Carte sans PNJ ni véhicules',
  vava_voice: 'Chat vocal de proximité',
  vava_cameras: 'Écran des joueurs pour le Conseil (mur des caméras)',
  vava_chancellerie: 'Pont de la Chancellerie (administration du royaume depuis le web)',
};

function isDirectory(full) {
  try {
    return fs.statSync(full).isDirectory();
  } catch (error) {
    return false;
  }
}

/**
 * Ressources trouvées : [{ name, category, description }], triées par nom.
 * @param {string} serverDataPath
 */
function scan(serverDataPath) {
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
        found.set(name, { name, category: category || '', description: CORE_DESCRIPTIONS[name] || '' });
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

module.exports = { scan, order, KNOWN_ORDER };
