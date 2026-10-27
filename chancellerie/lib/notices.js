'use strict';
/*
 * lib/notices.js
 * Rôle : les nouvelles de la Chancellerie que d'autres veulent relayer (le bot Discord) : avertissement d'un
 *        redémarrage planifié, mise à jour terminée, signalement reçu, joueurs arrivés ou partis. Ceux qui les
 *        produisent n'ont pas à savoir qui écoute.
 *        Évènements : « restart-warning » { minutes }, « update » { ok, summary }, « report » { id, author },
 *        « players ».
 */

const EventEmitter = require('events');

module.exports = new EventEmitter();
