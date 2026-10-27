'use strict';
/*
 * lib/journal.js
 * Rôle : journal de la Chancellerie (connexions, configuration, démarrages, arrêts, commandes saisies) : une ligne
 *        JSON par entrée dans data/journal.log, et les dernières en mémoire pour le tableau de bord. Aucune adresse
 *        IP n'y est écrite.
 */

const fs = require('fs');
const path = require('path');
const config = require('./config');

const FILE = path.join(config.DATA, 'journal.log');
const KEPT = 200;
// auteur des actions automatiques (relance après plantage, démarrage au lancement)
const SYSTEM = 'système';

const recent = [];

/** Reprend la fin du fichier : le tableau de bord montre aussi ce qui précède le dernier lancement. */
function loadTail() {
  try {
    const lines = fs.readFileSync(FILE, 'utf8').trim().split('\n').slice(-KEPT);
    for (const line of lines) {
      try {
        recent.push(JSON.parse(line));
      } catch (error) {
        // ligne abîmée (arrêt brutal pendant l'écriture) : ignorée
      }
    }
  } catch (error) {
    // pas encore de journal
  }
}
loadTail();

/**
 * @param {string} actor   compte, ou « système »
 * @param {string} action  identifiant court (login, start, command…)
 * @param {object} [details]
 */
function record(actor, action, details) {
  const entry = { at: new Date().toISOString(), actor, action, details: details || null };
  recent.push(entry);
  if (recent.length > KEPT) recent.shift();
  try {
    config.ensureData();
    fs.appendFileSync(FILE, `${JSON.stringify(entry)}\n`);
  } catch (error) {
    console.error(`[Chancellerie] journal non écrit : ${error.message}`);
  }
}

/** Dernières entrées, les plus récentes d'abord. */
function latest(count = 20) {
  return recent.slice(-count).reverse();
}

module.exports = { record, latest, SYSTEM };
