'use strict';
/*
 * vava_atelier/web/js/strings.js
 * Rôle : tous les textes de l'interface de l'Atelier (français, ton du royaume). Les textes venus du jeu (libellés des
 *        ateliers, des champs, aide, erreurs des modules, journal) ne sont pas ici : ils arrivent du serveur.
 * Dépendances : aucune.
 */

const STRINGS = Object.freeze({
  title: 'L\'Atelier du Conseil',
  subtitle: 'Créez et modifiez le royaume en jeu, sans redémarrer le serveur. Chaque changement est inscrit au journal.',
  close: 'Fermer l\'Atelier',
  back: 'Retour à l\'Atelier',
  backList: 'Retour à la liste',
  rank: (rank) => `Vous siégez au Conseil : ${rank}.`,
  upcoming: 'Bientôt',

  search: {
    label: 'Chercher dans l\'Atelier',
    placeholder: 'Chercher un lieu, un sort, un geste…',
    hits: 'Dans les ateliers',
    pending: 'On cherche dans les ateliers…',
    none: 'Rien de tel dans les ateliers.',
    noCard: 'Aucun atelier ne porte ce nom.',
    where: (where) => ` — ${where}`,
  },

  drafts: { title: 'Vos brouillons', none: 'Aucun brouillon en cours.' },
  status: { draft: 'Brouillon', trial: 'Essai', published: 'Publié', archived: 'Archivé' },

  journal: {
    title: 'Journal du Conseil',
    all: 'Tout le journal',
    none: 'Rien n\'a encore été changé.',
    allEditors: 'Tous les ateliers',
    filter: 'Atelier',
    older: 'Plus anciens',
    summary: (text) => ` — ${text}`,
    who: (actor, when) => `${actor}, ${when}`,
  },

  list: {
    filter: (plural) => `Filtrer les ${plural}…`,
    filterLabel: 'Filtrer la liste',
    count: (n, noun, plural) => `${n} ${n > 1 ? plural : noun}`,
    // « Créer un panneau », « Créer une zone » : le genre se lit dans `newLabel` (Nouveau, Nouvel, Nouvelle)
    create: (noun, newLabel) => `Créer ${/^nouvelle\b/i.test(newLabel || '') ? 'une' : 'un'} ${noun}`,
    open: 'Ouvrir',
    empty: 'Rien ici pour l\'instant.',
    noMatch: 'Rien ne correspond à ce filtre.',
    previous: 'Page précédente',
    next: 'Page suivante',
    page: (page, pages) => `Page ${page} sur ${pages}`,
    tabs: 'Types de l\'atelier',
  },

  entry: {
    stateLive: 'En vigueur',
    stateNew: 'Nouveau, rien n\'est enregistré',
    check: 'Vérifier',
    checking: 'Vérification…',
    checkHint: 'Vérifier contrôle les réglages sans rien changer au royaume.',
    checkOk: 'Tout est en ordre.',
    note: 'Le serveur revoit chaque réglage, pas seulement l\'interface. Rien n\'est changé au royaume tant que rien n\'est publié.',
    warning: 'Valeur reprise par défaut.',
    loading: 'Un instant…',
    steps: 'Étapes',
  },

  confirmLeave: {
    title: 'Quitter cette fiche ?',
    text: 'Les changements non vérifiés seront perdus.',
    cancel: 'Rester',
    ok: 'Quitter',
  },

  modeEdit: 'Mode édition : visible par vous seul',

  fields: {
    required: 'À remplir.',
    range: (min, max) => `Entre ${min} et ${max}.`,
    step: (step) => `Par pas de ${step}.`,
    choice: 'Choix inconnu.',
    length: (min, max) => `Entre ${min} et ${max} caractères.`,
    lines: (max) => `${max} lignes au plus.`,
    charset: {
      name: 'Lettres, chiffres, espaces, apostrophes, traits d\'union, virgules et points seulement.',
      id: 'Minuscules sans accent, chiffres et « _ » seulement.',
      free: 'Les signes « < » et « > » ne sont pas permis.',
    },
    item: 'Cet objet n\'existe pas dans le royaume.',
    itemUnavailable: 'La besace du royaume est indisponible : objet impossible à vérifier.',
    model: 'Ce modèle n\'est pas proposé.',
    counter: (n, max) => `${n} / ${max}`,
    choose: 'Choisir…',
    none: 'Aucun',
    noneItem: 'Aucun objet',
    chooseModel: 'Choisir',
    modelFree: 'Nom du modèle',
    provisional: 'Modèle provisoire : il sera remplacé automatiquement quand le modèle médiéval sera ajouté.',
    durationAmount: 'Durée',
    units: { s: 's', min: 'min', h: 'h', j: 'j' },
    unitNames: { s: 'secondes', min: 'minutes', h: 'heures', j: 'jours' },
  },

  picker: {
    search: 'Chercher…',
    loading: 'Un instant…',
    empty: 'Aucun choix.',
    more: 'Plus de choix',
    provisional: 'provisoire',
  },

  // durées lues (« 10 minutes », « 1 h 30 min », « 7 jours »)
  duration: {
    long: { j: ['jour', 'jours'], h: ['heure', 'heures'], min: ['minute', 'minutes'], s: ['seconde', 'secondes'] },
    short: { j: 'j', h: 'h', min: 'min', s: 's' },
  },

  // codes de refus du serveur et du transport (§ 6.2)
  errors: {
    not_ready: 'Le Registre du Conseil s\'éveille : réessayez dans un instant.',
    no_character: 'Aucun personnage chargé.',
    not_allowed: 'L\'Atelier est réservé au Conseil.',
    not_open: 'L\'Atelier s\'est refermé : rouvrez-le.',
    unknown_editor: 'Cet atelier n\'existe plus.',
    unknown_kind: 'Ce type n\'existe plus dans l\'atelier.',
    unknown_entry: 'Cette fiche n\'existe plus.',
    unknown_field: 'Ce réglage n\'existe plus.',
    busy: 'Un instant : une demande est déjà en cours.',
    editor_error: 'Cet atelier ne répond pas : prévenez un développeur.',
    db_error: 'Le journal est indisponible pour l\'instant.',
    rate_limited: 'Patience : trop de demandes à la fois. Réessayez dans un instant.',
    timeout: 'Le serveur ne répond pas.',
    invalid_args: 'Demande refusée.',
    invalid_response: 'Réponse incomprise.',
    stale: 'L\'Atelier s\'est désaccordé du serveur : rouvrez-le.',
    client_error: 'Erreur de l\'interface.',
    default: 'Action impossible.',
  },
  revoked: 'Votre place au Conseil a changé : l\'Atelier se ferme.',
  editorGone: 'Cet atelier vient d\'être retiré (module arrêté).',
});

/** Message lisible pour un code de refus (jamais le code brut). */
function errorText(code) {
  return STRINGS.errors[code] || STRINGS.errors.default;
}
