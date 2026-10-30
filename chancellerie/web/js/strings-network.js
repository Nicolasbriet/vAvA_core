'use strict';
/*
 * web/js/strings-network.js
 * Rôle : textes de la page Réseau (compteur des envois du core, ce que montre /vava_reseau en jeu) et de ses erreurs,
 *        ajoutés à STRINGS (strings.js, chargé avant). Les noms des modules, des évènements et des personnages viennent
 *        du serveur de jeu, tels quels.
 */

STRINGS.nav.network = 'Réseau';

Object.assign(STRINGS.errors, {
  net_unavailable: 'Le compteur réseau demande vAvA_core 0.12.0 ou plus récent sur le serveur de jeu.',
  unknown_player: 'Aucun joueur de ce numéro en jeu.',
  journal_unavailable: 'Le journal du Conseil n\'a pas pu inscrire cette consultation : le détail du joueur n\'est pas montré. Réessayez dans un instant.',
});

STRINGS.network = {
  title: 'Réseau',
  hint: 'Ce que le serveur de jeu a envoyé aux joueurs pendant la dernière minute, compté par le core : les évènements les plus lourds d\'abord, avec leurs envois en latent et leur plus gros message. La même chose que « /vava_reseau » en jeu, en lecture seule. Chaque joueur connecté est suivi d\'office : « Les joueurs » les liste, du plus chargé au moins chargé, et un clic ouvre le détail de l\'un d\'eux. L\'ouverture de cette page et le détail de chaque joueur lu s\'inscrivent au journal du Conseil ; la liste, non.',
  notCounted: 'Non comptés : GlobalState, state bags et envois directs des modules.',
  scopes: { all: 'Tout le royaume', players: 'Les joueurs', resource: 'Un module', player: 'Un joueur' },
  resourceField: 'Nom de la ressource',
  resourcePlaceholder: 'vava_codex',
  playerField: 'Numéro du joueur',
  playerPlaceholder: 'n°',
  read: 'Lire',
  reload: 'Relire',
  autoLabel: 'Relecture',
  autos: { 0: 'à la demande', 5000: 'toutes les 5 s', 15000: 'toutes les 15 s', 30000: 'toutes les 30 s' },
  readAt: (clock) => `lu à ${clock}`,
  paused: 'relecture en pause (page cachée)',
  autoStopped: 'relecture automatique arrêtée',
  autoStoppedHelp: 'La relecture automatique s\'est arrêtée : relisez à la main, ou choisissez de nouveau un rythme, une fois la cause levée.',
  idleStopped: 'relecture arrêtée après 15 min sans action',
  facts: {
    mode: 'Mesure',
    messages: 'Envois',
    bytes: 'Volume',
    latent: 'Latents',
    largest: 'Plus gros message',
    player: 'Joueur',
  },
  modes: { exact: 'exacte', estimate: 'estimée' },
  modeHelp: 'Estimée : le serveur de jeu n\'offre pas la sérialisation à part ; les tailles sont approchées.',
  playerText: (target, name) => `n° ${target} · ${name}`,
  noCharacter: 'sans personnage',
  playersAll: (count) => (count === 1 ? '1 joueur connecté.' : `${count} joueurs connectés.`),
  playersSome: (count, shown) => `${count} joueurs connectés : les ${shown} plus chargés.`,
  noPlayers: 'Aucun joueur connecté.',
  playerColumns: ['N°', 'Personnage', 'Envois', 'Volume', 'Latents'],
  playerRowHelp: 'Un clic sur un joueur ouvre son détail par évènement (inscrit au journal du Conseil).',
  columns: ['Module', 'Évènement', 'Envois', 'Volume', 'Plus gros', 'Latents'],
  other: '(autres)',
  rowHelp: 'Un clic sur une ligne ne garde que ce module.',
  empty: 'Aucun envoi compté pendant la dernière minute.',
  emptyResource: (name) => `Aucun envoi de « ${name} » compté pendant la dernière minute.`,
  emptyPlayer: 'Aucun envoi vers ce joueur pendant la dernière minute.',
};
