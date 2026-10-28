'use strict';
/*
 * web/js/strings.js
 * Rôle : tous les textes du livre des compétences (français). Les noms des compétences, des rangs et des personnes
 *        viennent du serveur ; ici seulement l'habillage, les légendes et les messages d'erreur.
 */

const STRINGS = Object.freeze({
  title: 'Livre des compétences',
  close: 'Fermer',
  // [identifiant, libellé] des onglets, dans l'ordre
  tabs: [
    ['competences', 'Compétences'],
    ['mentorat', 'Mentorat'],
    ['savoirs', 'Savoirs'],
    ['penurie', 'Pénurie'],
  ],
  // [touche, action] : légende en bas de l'écran
  hints: [['Échap', 'fermer']],
  character: { playtime: (text) => `${text} de jeu` },

  budget: {
    title: 'Points de maîtrise',
    used: (used, total) => `${fmt(used)} / ${fmt(total)}`,
    remaining: (n) => (n > 1 ? `${fmt(n)} points encore libres` : `${fmt(n)} point encore libre`),
    full: 'Plafond atteint : marquez une compétence à oublier (↓) pour continuer à progresser ailleurs.',
    common: (n) => `Les ${n} premiers niveaux de chaque compétence sont du savoir commun : ils ne comptent pas.`,
  },

  skill: {
    level: (n) => `Niveau ${n}`,
    xp: (xp, next) => `${fmt(xp)} / ${fmt(next)} XP`,
    max: 'Niveau maximal',
    renown: (n) => `Renommée ${fmt(n)}`,
    shortage: (m) => `En pénurie ×${fmtMult(m)}`,
    mentoredOnly: 'Ne progresse qu\'auprès de votre maître',
    mentor: (name) => `Votre maître : ${name}`,
    mentorAway: (name) => `Votre maître : ${name} (absent)`,
    apprentices: (n) => `${n} ${n > 1 ? 'apprentis' : 'apprenti'}`,
    practiced: (when) => `Pratiquée ${when}`,
    never: 'Jamais pratiquée',
  },

  modes: {
    legend: 'Cliquez le signe d\'une compétence pour la faire tourner :',
    up: { glyph: '↑', label: 'progresse', hint: 'Progresse : cette compétence gagne de l\'expérience.' },
    keep: { glyph: '=', label: 'verrouillée', hint: 'Verrouillée : ni gain ni perte.' },
    down: { glyph: '↓', label: 's\'efface', hint: 'S\'efface : au plafond, elle cède un point aux compétences qui progressent.' },
  },

  mentoring: {
    proposals: 'Propositions reçues',
    proposalText: (name, skill) => `${name} vous propose de devenir votre maître en ${skill}.`,
    expiresIn: (text) => `expire dans ${text}`,
    accept: 'Accepter',
    decline: 'Refuser',
    noProposal: 'Aucune proposition en attente.',
    masters: 'Mes maîtres',
    apprentices: 'Mes apprentis',
    noMaster: 'Vous n\'avez aucun maître. Un Maître peut vous proposer un mentorat : à ses côtés, vous apprenez plus vite.',
    noApprentice: 'Vous n\'avez aucun apprenti.',
    online: 'en jeu',
    offline: 'absent',
    since: (text) => `depuis ${text}`,
    breakUp: 'Rompre',
    confirmBreak: 'Confirmer ?',
    propose: 'Proposer un mentorat',
    proposeIntro: (max) => `Un maître prend jusqu'à ${max} apprentis par compétence. Choisissez la compétence, puis la personne à vos côtés.`,
    noMasterSkill: 'Aucune de vos compétences n\'a encore le rang pour enseigner.',
    chooseSkill: 'Compétence enseignée',
    choosePlayer: 'Personne à vos côtés',
    search: 'Chercher autour de moi',
    searching: 'Recherche…',
    nobody: 'Personne à portée.',
    distance: (m) => `${Math.round(m)} m`,
    send: 'Proposer',
    sent: 'Proposition envoyée.',
    bonus: (pct) => `À quelques pas de son maître, quand celui-ci pratique, l'apprenti gagne ${pct} % d'expérience en plus ; le maître y gagne en Renommée.`,
  },

  knowledge: {
    known: 'Savoirs transmis',
    none: 'Vous ne détenez encore aucun savoir transmis. Les recettes communes ne demandent que le niveau ; celles-ci s\'apprennent d\'un maître, leçon après leçon.',
    learning: 'Apprentissages en cours',
    noLearning: 'Aucune leçon en cours.',
    lessons: (n, total) => `${n} / ${total} leçons`,
    nextLesson: (text) => `prochaine leçon possible dans ${text}`,
    nextLessonNow: 'prochaine leçon possible dès maintenant',
    source: {
      lesson: 'appris d\'un maître',
      founder: 'savoir fondateur',
      fragments: 'reconstitué à partir de fragments',
      admin: 'accordé par le Conseil',
    },
    taughtBy: (name) => `Enseigné par ${name}`,
    learnedOn: (date) => `le ${date}`,
    select: 'Choisissez un savoir pour lire son histoire.',
    lineage: 'Lignée du savoir',
    showLineage: 'Voir la lignée',
    loading: 'Lecture…',
    you: 'vous',
    founder: 'fondateur',
    lineageIntro: 'De vous jusqu\'à celui qui, le premier, détint ce savoir :',
    lineageUnavailable: 'La lignée de ce savoir ne peut être lue.',
  },

  shortages: {
    title: 'Métiers en pénurie',
    intro: 'Quand trop peu d\'artisans confirmés pratiquent un métier, le royaume manque de bras : l\'expérience y est multipliée pour qui s\'y met.',
    none: 'Aucun métier ne manque de bras en ce moment.',
    count: (n) => `${n} ${n > 1 ? 'artisans confirmés' : 'artisan confirmé'}`,
    multiplier: (m) => `×${fmtMult(m)}`,
    board: 'Ce panneau est celui des places du royaume : il se met à jour régulièrement.',
  },

  errors: {
    default: 'Action impossible.',
    unknown_skill: 'Compétence inconnue.',
    invalid_mode: 'Mode invalide.',
    not_master: 'Vous n\'avez pas le rang pour enseigner cette compétence.',
    too_young: 'Vous n\'avez pas encore assez vécu dans le royaume pour enseigner.',
    same_account: 'Impossible avec cette personne.',
    too_far: 'Trop loin.',
    already_mentored: 'Cette personne a déjà un maître dans cette compétence.',
    full: 'Vous avez déjà tous vos apprentis dans cette compétence.',
    no_target: 'Cette personne n\'est plus là.',
    self: 'Vous ne pouvez pas être votre propre maître.',
    pending: 'Une proposition est déjà en attente.',
    not_found: 'Introuvable.',
    expired: 'Cette proposition a expiré.',
    not_party: 'Ce mentorat ne vous concerne pas.',
    unknown_recipe: 'Savoir inconnu.',
    not_known: 'Vous ne détenez pas ce savoir.',
    rate_limited: 'Doucement…',
    timeout: 'Le serveur ne répond pas.',
    client_error: 'Erreur de l\'interface.',
    no_character: 'Aucun personnage chargé.',
  },

  time: {
    now: 'à l\'instant',
    ago: (text) => `il y a ${text}`,
    lessThanMinute: 'moins d\'une minute',
    minutes: (n) => `${n} min`,
    hours: (h, m) => (m > 0 ? `${h} h ${String(m).padStart(2, '0')}` : `${h} h`),
    days: (n) => `${n} ${n > 1 ? 'jours' : 'jour'}`,
    seconds: (n) => `${n} s`,
  },
});

/** Nombre entier en français (séparateurs de milliers). */
function fmt(value) {
  return Math.round(Number(value) || 0).toLocaleString('fr-FR');
}

/** Multiplicateur : « 1,5 ». */
function fmtMult(value) {
  return Number(value || 1).toLocaleString('fr-FR', { maximumFractionDigits: 2 });
}

/** Message lisible pour un code d'erreur, ou la raison donnée par un module si elle est déjà rédigée. */
function errorMessage(code) {
  return STRINGS.errors[code] || (typeof code === 'string' && code.length > 0 && !code.includes('_') ? code : STRINGS.errors.default);
}
