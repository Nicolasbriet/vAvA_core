'use strict';
/*
 * vava_pause/web/js/strings.js
 * Rôle : tous les textes de la bannière (français, ton du royaume). Les commandes s'écrivent comme une phrase
 *        (EB Garamond gras, jamais en capitales) ; les rubriques et intitulés sont mis en capitales par la feuille.
 * Dépendances : aucune (STRINGS global dans la page, module.exports sous node pour les essais)
 */

const STRINGS = Object.freeze({
  title: 'Eldoria',
  guildFoot: (label) => `Bannière des ${label}`,
  rubrics: {
    reprendre: 'Reprendre', personnage: 'Personnage', codex: 'Codex', carte: 'Carte', reglages: 'Réglages',
    conseil: 'Le Conseil', parametres: 'Paramètres du jeu', quitter: 'Quitter Eldoria',
  },
  foot: (key) => `${key} pour reprendre`,
  footGamepad: 'B pour reprendre',
  downed: 'Vous êtes à terre : seuls ces choix vous restent.',
  close: 'Fermer',
  menu: 'Menu',

  personnage: {
    title: 'Personnage',
    state: 'État', health: 'Santé', hunger: 'Faim', thirst: 'Soif',
    skills: 'Savoir-faire', art: 'Art', rank: 'Rang', progress: 'Progrès', level: 'Niv.',
    guild: 'Confrérie', grade: 'Grade', trade: 'Métier',
    noGuild: 'Aucune : sujet du royaume', noTrade: 'Aucun encore',
    newcomer: 'Nouveau venu dans le royaume',
    subtitleGuild: (grade, label) => `${grade}, ${label}`,
    subtitleTrade: (rank, skill) => `${rank} en ${skill.toLocaleLowerCase('fr')}`,
    loading: 'Le registre se consulte…',
    failed: 'Le registre ne répond pas.',
    none: 'Aucun savoir-faire n\'est encore inscrit au registre.',
    restNovice: (n, word) => (n === 1 ? 'L\'autre savoir-faire est au rang Novice.' : `Les ${word} autres savoir-faire sont au rang Novice.`),
    restOther: (n, word) => (n === 1 ? 'Un autre savoir-faire est inscrit au registre.' : `${word[0].toUpperCase()}${word.slice(1)} autres savoir-faire sont inscrits au registre.`),
    rust: 'Un art négligé rouille ; un maître vous fera progresser plus vite.',
    showAll: (word) => `voir les ${word} savoir-faire`,
    showLess: 'revenir aux principaux',
    sheet: 'ouvrir la fiche complète',
    portrait: 'Portrait',
  },

  codex: {
    opening: 'Le Codex s\'ouvre…',
    closed: 'Le Codex est fermé pour l\'instant.',
  },

  carte: {
    title: 'Carte du royaume',
    text: 'La carte du royaume n\'est pas encore dressée. En attendant, les éclaireurs prêtent la leur.',
    open: 'ouvrir la carte (provisoire)',
  },

  reglages: {
    tabs: { interface: 'Interface', voix: 'Voix', touches: 'Touches' },
    tablist: 'Catégories de réglages',
    titles: { interface: 'Réglages de l\'interface', voix: 'Réglages de la voix', touches: 'Vos touches' },
    on: 'Activé', off: 'Désactivé',
    reset: 'revenir aux valeurs par défaut',
    saved: 'Enregistré à chaque changement',
    refused: 'Ce réglage n\'a pas été pris en compte.',
    empty: 'Aucun réglage dans cette catégorie pour l\'instant.',
    voiceRange: (label, distance) => `Portée de votre voix : ${label}, ${distance}`,
    voiceChange: 'Changer de portée',
    voiceTalk: 'Parler',
    voiceTalkHelp: 'Touche du jeu, à régler dans les paramètres du jeu.',
    voiceSettings: 'ouvrir les paramètres du jeu',
    voiceOff: 'La voix du royaume se tait pour l\'instant.',
    keysHelp: 'Les touches que vous avez liées ; chacune se change dans les paramètres du jeu.',
    keysChange: 'changer une touche',
    keysLoading: 'Le registre des touches se consulte…',
    keysNone: 'Aucune touche n\'est inscrite au registre.',
    hold: 'maintenir',
  },

  conseil: {
    title: 'Le Conseil vous écoute',
    kind: 'De quoi s\'agit-il ?',
    kinds: { question: 'Une question', player: 'Signaler un joueur', bug: 'Un bug', other: 'Autre' },
    message: 'Votre message',
    placeholder: 'Décrivez la situation en quelques phrases…',
    count: (n, max) => `${n} / ${max}`,
    position: 'Joindre ma position',
    positionPlayer: 'Le Conseil saura qui se trouvait près de vous.',
    send: 'Sceller et envoyer',
    sending: 'Le message part…',
    anonymous: 'Votre nom ne parvient qu\'au Conseil.',
    sent: (id) => `Votre demande n° ${id} est entre les mains du Conseil.`,
    sentText: (age) => `Envoyée ${age}. Un membre la prendra dès que possible.`,
    claimed: 'Votre demande précédente est prise en charge.',
    claimedText: 'Un membre du Conseil s\'en occupe.',
    closed: 'Votre demande a été close.',
    closedText: 'Si quelque chose demeure, écrivez de nouveau.',
    age: { now: 'à l\'instant', minutes: (n) => `il y a ${n} min`, hours: (n) => `il y a ${n} h` },
    errors: {
      too_short: 'Quelques mots de plus, s\'il vous plaît.',
      too_soon: (s) => `Patientez encore ${s} s avant une nouvelle demande.`,
      too_many: 'Vos demandes attendent déjà le Conseil : patientez qu\'il y réponde.',
      council_unavailable: 'Le Conseil ne siège pas en ce moment : revenez plus tard.',
      default: 'La demande n\'a pas pu partir.',
    },
  },

  quitter: {
    title: 'Quitter Eldoria ?',
    saved: 'Votre personnage est enregistré là où il se trouve, avec tout ce qu\'il porte.',
    note: 'Si vous êtes à terre, vous le serez encore à votre retour. Un échange en cours sera annulé.',
    stay: 'Rester à Eldoria',
    disconnect: 'Se déconnecter',
    quit: 'Quitter le jeu',
    leaving: 'Le royaume vous salue…',
  },

  plaque: { people: { one: '1 habitant présent', many: (n) => `${n} habitants présents` } },

  errors: { default: 'Action impossible pour l\'instant.' },

  // nombres écrits en lettres jusqu'à vingt (« voir les treize savoir-faire »)
  numbers: ['zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix', 'onze', 'douze',
    'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf', 'vingt'],
});

if (typeof module === 'object' && module && module.exports) module.exports = STRINGS;
