'use strict';
/*
 * web/js/strings.js
 * Rôle : textes du mur des caméras (français).
 */

const STRINGS = {
  title: 'Mur des caméras',
  count: (n) => (n === 0 ? 'Aucun joueur connecté' : n === 1 ? 'Un joueur connecté' : `${n} joueurs connectés`),
  layout: (n) => `Disposition ${n} × ${n}`,
  page: (current, total) => `Page ${current} / ${total}`,
  previousPage: 'Page précédente',
  nextPage: 'Page suivante',
  previousPlayer: 'Joueur précédent',
  nextPlayer: 'Joueur suivant',
  close: 'Fermer le mur',
  back: 'Retour au mur',
  number: (source) => `n° ${source}`,
  empty: 'Aucun joueur à regarder pour l\'instant.',
  hint: 'Un clic sur une case l\'ouvre en grand · Flèches : pages · 1 à 4 : disposition · Échap : fermer',
  focusHint: 'Flèches : joueur précédent ou suivant · Échap : retour au mur',
  connecting: 'Ouverture de la caméra…',
  status: {
    not_playing: 'En sélection de personnage',
    too_many_viewers: 'Déjà regardé par six membres',
    too_many_cameras: 'Trop de caméras ouvertes',
    forbidden: 'Droit refusé',
    self: 'Votre propre écran',
    dropped: 'Joueur parti',
    left_game: 'Plus en jeu',
    connection_failed: 'Connexion perdue',
    no_answer: 'Pas de réponse du joueur',
    capture_failed: 'Capture impossible',
    unsupported: 'Jeu du joueur incompatible',
    expired: 'Caméra expirée',
    closed: 'Caméra fermée',
    unavailable: 'Image indisponible',
  },
  statusOf(code) {
    return this.status[code] || this.status.unavailable;
  },
};
