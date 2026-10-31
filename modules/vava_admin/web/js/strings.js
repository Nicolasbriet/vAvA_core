'use strict';
/*
 * web/js/strings.js
 * Rôle : tous les textes du Registre du Conseil (français) : onglets, actions, libellés du journal, erreurs.
 */

const STRINGS = Object.freeze({
  title: 'Registre du Conseil',
  close: 'Fermer le registre',
  tabs: {
    players: 'Joueurs', reports: 'Signalements', bans: 'Sanctions', logs: 'Journal',
    staff: 'Conseil', tools: 'Outils', announce: 'Proclamation',
  },
  players: {
    heading: 'Âmes présentes',
    search: 'Chercher un nom, un numéro…',
    empty: 'Personne ne correspond.',
    none: 'Choisissez une âme dans la liste.',
    noCharacter: 'En sélection de personnage',
    session: (n) => `Session n° ${n}`,
    account: (n) => `Compte n° ${n}`,
    ping: (ms) => `${ms} ms`,
    // temps de jeu du personnage : « 12 h 34 », « 48 min », ou « — » sans personnage
    playtime: (seconds) => {
      if (!Number.isFinite(seconds)) return '—';
      const hours = Math.floor(seconds / 3600);
      const minutes = Math.floor((seconds % 3600) / 60);
      return hours ? `${hours} h ${String(minutes).padStart(2, '0')}` : `${minutes} min`;
    },
    labels: { name: 'Nom FiveM', account: 'Compte', session: 'Session', playtime: 'Temps de jeu', position: 'Position' },
    vitals: { health: 'Vie', hunger: 'Faim', thirst: 'Soif' },
    warnings: 'Avertissements',
    noWarnings: 'Aucun avertissement.',
    tags: { downed: 'À terre', frozen: 'Immobilisé', self: 'Vous' },
    groups: { move: 'Déplacements', care: 'Soins', words: 'Paroles', goods: 'Biens', justice: 'Justice', council: 'Conseil' },
    appoint: 'Rang au Conseil',
    noRank: 'Aucun rang',
    count: (n) => `${n} âme${n > 1 ? 's' : ''}`,
  },
  actions: {
    reach: 'Rejoindre', bring: 'Amener', sendBack: 'Renvoyer', freeze: 'Immobiliser', unfreeze: 'Libérer',
    heal: 'Soigner', feed: 'Nourrir', message: 'Écrire', warn: 'Avertir', kick: 'Expulser', ban: 'Bannir',
    inventory: 'Fouiller', give: 'Donner', spectate: 'Observer', appoint: 'Nommer',
  },
  dialogs: {
    message: { title: 'Écrire à', label: 'Message', confirm: 'Envoyer' },
    warn: { title: 'Avertir', label: 'Motif de l\'avertissement', confirm: 'Avertir' },
    kick: { title: 'Expulser', label: 'Motif de l\'expulsion', confirm: 'Expulser' },
    ban: { title: 'Bannir', label: 'Motif du ban', duration: 'Durée', confirm: 'Sceller le ban' },
    give: { title: 'Donner à', item: 'Objet (nom technique)', quantity: 'Quantité', confirm: 'Donner' },
    unban: { title: 'Lever le ban', text: (label) => `Lever tous les bans de ${label} ?`, confirm: 'Lever' },
    revoke: { title: 'Révoquer', text: (label) => `Retirer ${label} du Conseil ?`, confirm: 'Révoquer' },
    cancel: 'Annuler',
  },
  duration: (hours) => {
    if (hours === 0) return 'Définitif';
    if (hours % 24 === 0) return `${hours / 24} jour${hours / 24 > 1 ? 's' : ''}`;
    return `${hours} heure${hours > 1 ? 's' : ''}`;
  },
  reports: {
    heading: 'Doléances',
    empty: 'Aucun signalement en attente.',
    none: 'Choisissez un signalement.',
    from: (author) => `De ${author}`,
    age: (text) => `il y a ${text}`,
    claimedBy: (label) => `Pris en charge par ${label}`,
    open: 'En attente',
    gone: 'Le joueur a quitté le royaume.',
    claim: 'Prendre en charge', close: 'Clore', reach: 'Rejoindre', player: 'Voir la fiche',
    // nature de la demande (1.10.0) : bannière du royaume ; /signaler arrive en « Autre »
    kinds: { question: 'Question', player: 'Signalement', bug: 'Bug', other: 'Autre' },
    position: (p) => `Position jointe : ${p.x}, ${p.y}, ${p.z}`,
    witnesses: (names) => `Témoins à proximité : ${names.join(', ')}`,
    noWitnesses: 'Aucun témoin à proximité.',
  },
  bans: {
    heading: 'Bans en cours',
    empty: 'Aucun ban en cours.',
    columns: ['N°', 'Banni', 'Motif', 'Prononcé', 'Fin', 'Par', ''],
    forever: 'Définitif',
    lift: 'Lever',
  },
  logs: {
    heading: 'Journal du Conseil',
    empty: 'Le journal est vierge.',
    columns: ['Date', 'Auteur', 'Action', 'Cible', 'Détails'],
    labels: {
      reach: 'a rejoint', bring: 'a amené', sendBack: 'a renvoyé', freeze: 'a immobilisé', heal: 'a soigné', feed: 'a nourri',
      message: 'a écrit à', warn: 'a averti', kick: 'a expulsé', ban: 'a banni', unban: 'a levé le ban de',
      inventory: 'a fouillé', give: 'a donné à', spectate: 'a observé', staffGrant: 'a nommé', staffRevoke: 'a révoqué',
      announce: 'a proclamé', tool: 'a utilisé un outil', reportClaim: 'a pris en charge', reportClose: 'a clos le signalement de',
      moveToPlayer: 'a déplacé', moveToCoords: 'a déplacé', inventoryView: 'a consulté l\'inventaire de',
      watchScreen: 'a regardé l\'écran de',
    },
  },
  staff: {
    heading: 'Membres du Conseil',
    empty: 'Le Conseil ne compte aucun membre.',
    offline: 'Absent',
    revoke: 'Révoquer',
    hint: 'Nommez un joueur depuis sa fiche, dans l\'onglet Joueurs.',
  },
  tools: {
    heading: 'Outils du Conseil',
    noclip: {
      label: 'Vol libre',
      hint: (key) => `Raccourci ${key} (réglable). Invisible pendant le vol. ZQSD pour se déplacer, Espace et Ctrl pour monter et descendre, Maj pour accélérer.`,
    },
    invisible: { label: 'Invisibilité', hint: 'Les autres joueurs ne vous voient plus.' },
    godmode: { label: 'Invulnérabilité', hint: 'Rien ne peut vous mettre à terre.' },
    waypoint: { label: 'Rejoindre le repère', hint: 'Posez un repère sur la carte du menu pause.' },
    coords: { label: 'Copier ma position', hint: 'Coordonnées copiées dans le presse-papiers.' },
    spectating: (label) => `Vous observez ${label}.`,
    stop: 'Cesser d\'observer',
    on: 'Actif', off: 'Inactif',
    modules: 'Outils des modules',
    openTool: 'Ouvrir',
  },
  announce: {
    heading: 'Proclamation',
    label: 'Texte de la proclamation',
    hint: 'Lue par tout le royaume, en haut de l\'écran.',
    confirm: 'Proclamer',
    preview: 'Aperçu',
    title: 'Proclamation du Conseil',
    sent: 'Proclamation envoyée.',
  },
  watch: (label) => `Vous observez ${label}`,
  done: 'C\'est fait.',
  copied: (text) => `Position copiée : ${text}`,
  pages: { previous: 'Page précédente', next: 'Page suivante', page: (n) => `Page ${n}` },
  errors: {
    default: 'Action impossible.',
    forbidden: 'Votre rang ne le permet pas.',
    unknown_tool: 'Cet outil n\'est plus disponible (son module est arrêté).',
    not_found: 'Ce joueur n\'est plus là.',
    self: 'Pas sur vous-même.',
    outranked: 'Son rang est égal ou supérieur au vôtre.',
    no_ped: 'Personnage introuvable.',
    no_body: 'Il faut être en jeu.',
    no_previous: 'Aucune position où le renvoyer.',
    unavailable: 'Module indisponible.',
    db_error: 'La base de données ne répond pas.',
    ban_too_long: 'Durée au-delà de ce que permet votre rang.',
    not_banned: 'Aucun ban en cours.',
    unknown_rank: 'Rang inconnu.',
    not_staff: 'Ce compte ne siège pas au Conseil.',
    no_waypoint: 'Aucun repère sur la carte.',
    not_downed: 'Il n\'est pas à terre.',
    rate_limited: 'Doucement…',
    timeout: 'Le serveur ne répond pas.',
    invalid_args: 'Saisie refusée.',
    no_character: 'Aucun personnage chargé.',
    no_space: 'Pas assez de place dans son inventaire.',
    too_heavy: 'Trop lourd pour lui.',
    invalid_request: 'Demande refusée.',
    client_error: 'Erreur de l\'interface.',
  },
});

/** Message lisible pour un code d'erreur. */
function errorMessage(code) {
  return STRINGS.errors[code] || STRINGS.errors.default;
}

/** Durée écoulée lisible : « 3 min », « 2 h ». */
function ageText(ms) {
  const minutes = Math.floor(ms / 60000);
  if (minutes < 1) return 'un instant';
  if (minutes < 60) return `${minutes} min`;
  return `${Math.floor(minutes / 60)} h`;
}
