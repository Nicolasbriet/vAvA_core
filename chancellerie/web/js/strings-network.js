'use strict';
/*
 * web/js/strings-network.js
 * Rôle : textes de la page Réseau (compteur des envois du core, ce que montre /vava_reseau en jeu) et de ses erreurs,
 *        ajoutés à STRINGS (strings.js, chargé avant). Les noms des modules et des évènements viennent du serveur de
 *        jeu, tels quels.
 */

STRINGS.nav.network = 'Réseau';

Object.assign(STRINGS.errors, {
  net_unavailable: 'Le compteur réseau demande vAvA_core 0.10.0 ou plus récent sur le serveur de jeu.',
  unknown_player: 'Aucun joueur de ce numéro en jeu.',
});

STRINGS.network = {
  title: 'Réseau',
  hint: 'Ce que le serveur de jeu a envoyé aux joueurs pendant la dernière minute, compté par le core : les évènements les plus lourds d\'abord, avec leurs envois en latent et leur plus gros message. La même chose que « /vava_reseau » en jeu, en lecture seule. L\'ouverture de cette page et chaque joueur lu s\'inscrivent au journal du Conseil.',
  notCounted: 'Non comptés : GlobalState, state bags et envois directs des modules.',
  scopes: { all: 'Tout le royaume', resource: 'Un module', player: 'Un joueur' },
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
  facts: {
    mode: 'Mesure',
    messages: 'Envois',
    bytes: 'Volume',
    latent: 'Latents',
    largest: 'Plus gros message',
    player: 'Joueur',
    watched: 'Détail',
  },
  modes: { exact: 'exacte', estimate: 'estimée' },
  modeHelp: 'Estimée : le serveur de jeu n\'offre pas la sérialisation à part ; les tailles sont approchées.',
  playerText: (target, name) => (name ? `n° ${target} · ${name}` : `n° ${target}`),
  watchedYes: 'évènement par évènement',
  watchedNo: 'totaux seulement',
  notWatched: (target) => `Ce joueur n'est pas suivi : seuls ses totaux sont connus. Pour le détail évènement par évènement, un membre du Conseil tape « /vava_reseau joueur ${target} » en jeu (suivi de 5 minutes, inscrit au journal), puis relit cette page.`,
  columns: ['Module', 'Évènement', 'Envois', 'Volume', 'Plus gros', 'Latents'],
  other: '(autres)',
  rowHelp: 'Un clic sur une ligne ne garde que ce module.',
  empty: 'Aucun envoi compté pendant la dernière minute.',
  emptyResource: (name) => `Aucun envoi de « ${name} » compté pendant la dernière minute.`,
  emptyPlayer: 'Aucun envoi suivi vers ce joueur pendant la dernière minute.',
};
