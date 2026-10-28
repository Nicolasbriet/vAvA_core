'use strict';
/*
 * web/js/strings.js
 * Rôle : tous les textes affichés par la récolte (français) : verbes des gestes, invite, ligne lancée, barre de
 *        tension, panneau des zones, codes d'erreur.
 */

const STRINGS = Object.freeze({
  // verbe de l'invite selon l'animation de la ressource (config.anims)
  verbs: { chop: 'Couper', mine: 'Piocher', pick: 'Cueillir', fish: 'Pêcher', skin: 'Dépouiller' },
  verbDefault: 'Récolter',
  prompt: {
    charges: (n) => (n > 1 ? `${n} charges` : n === 1 ? '1 charge' : 'épuisé'),
    exhausted: 'Rien à prendre ici pour le moment : la ressource se refait.',
    zoneDepleted: 'La terre est épuisée ici : la récolte sera maigre.',
    needTool: (tool) => `Il vous faut ${tool} en main.`,
    toolKinds: { hache: 'une hache', pioche: 'une pioche', faucille: 'une faucille', couteau: 'un couteau', canne: 'une canne à pêche' },
    toolDefault: 'l\'outil qui convient',
  },
  cast: {
    text: (label) => `Ligne lancée — ${label}`,
    waiting: 'Attendez la touche…',
    hint: (key) => `${key} : remonter la ligne`,
  },
  tension: {
    title: 'Ça mord !',
    hint: (key) => `Tenez ${key} pour tendre la ligne, relâchez pour lui laisser du mou. Gardez l'aiguille dans la zone.`,
    seconds: (s) => `${s} s`,
    success: 'La ligne a tenu !',
    failure: 'La ligne s\'est relâchée…',
  },
  zones: {
    title: 'Zones de récolte',
    refresh: 'Relire',
    close: 'Fermer',
    mark: 'Marquer',
    markHint: 'Poser le repère de la carte sur cette zone',
    marked: (label) => `Repère posé sur ${label}.`,
    empty: 'Aucune zone connue.',
    foot: 'La vitalité baisse à chaque récolte et se refait avec le temps. Une zone épuisée rend peu ; une cicatrice met longtemps à guérir.',
    kinds: { foret: 'Forêt', mine: 'Mine', prairie: 'Prairie', eau: 'Eau', gibier: 'Gibier' },
    bands: { normal: 'Florissante', reduced: 'Fatiguée', depleted: 'Épuisée' },
    scarred: 'Cicatrice',
    vitality: (v) => `${Math.round(v)} %`,
    distance: (m) => (m >= 1000 ? `${(m / 1000).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} km` : `${Math.round(m)} m`),
    hints: [['Échap', 'fermer']],
  },
  errors: {
    default: 'Action impossible.',
    unknown_node: 'Il n\'y a rien à récolter ici.',
    unknown_zone: 'Zone inconnue.',
    too_far: 'Trop loin.',
    too_soon: 'Trop tôt.',
    expired: 'Le geste a pris trop de temps.',
    not_found: 'Ce geste n\'est plus en cours.',
    busy: 'Vous êtes déjà occupé.',
    cooldown: 'Reprenez votre souffle un instant.',
    no_character: 'Aucun personnage en jeu.',
    rate_limited: 'Doucement…',
    timeout: 'Le serveur ne répond pas.',
    refused: 'Action refusée.',
    client_error: 'Erreur de l\'interface.',
    server_error: 'Le serveur a rencontré une erreur.',
  },
});

/** Message lisible pour un code d'erreur, ou la raison donnée par un module si elle est déjà rédigée. */
function errorMessage(code) {
  return STRINGS.errors[code] || (typeof code === 'string' && code.length > 0 && !code.includes('_') ? code : STRINGS.errors.default);
}
