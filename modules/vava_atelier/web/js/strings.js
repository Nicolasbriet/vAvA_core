'use strict';
/*
 * vava_atelier/web/js/strings.js — textes de la page (ceux des ateliers et des refus viennent du serveur)
 * Dépendances : aucune.
 */

const STRINGS = Object.freeze({
  title: 'L\'Atelier du Conseil',
  subtitle: 'Créez et modifiez le royaume en jeu, sans redémarrer le serveur. Chaque changement est inscrit au journal.',
  close: 'Fermer l\'Atelier',
  back: 'Retour à l\'Atelier',
  backList: 'Retour à la liste',
  rank: (rank) => `Vous siégez au Conseil en qualité de ${rank}.`,
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
    older: 'Lignes plus anciennes',
    summary: (text) => ` — ${text}`,
    who: (actor, when) => `${actor}, ${when}`,
  },

  list: {
    filter: (plural) => `Filtrer les ${plural}…`,
    filterLabel: 'Filtrer la liste',
    count: (n, noun, plural) => `${n} ${n > 1 ? plural : noun}`,
    // le genre se lit dans `newLabel` (Nouveau, Nouvel, Nouvelle)
    create: (noun, newLabel) => `Créer ${/^nouvelle\b/i.test(newLabel || '') ? 'une' : 'un'} ${noun}`,
    open: 'Ouvrir',
    empty: 'Rien ici pour l\'instant.',
    noMatch: 'Rien ne correspond à ce filtre.',
    previous: 'Page précédente',
    next: 'Page suivante',
    page: (page, pages) => `Page ${page} sur ${pages}`,
    tabs: 'Genres de fiches',
  },

  entry: {
    stateLive: 'En vigueur',
    stateNew: 'Rien d\'enregistré',
    check: 'Vérifier',
    checking: 'Vérification…',
    checkHint: 'Vérifier contrôle les réglages sans rien changer au royaume.',
    checkOk: 'Tout est en ordre.',
    note: 'Chaque réglage est revu par le serveur, pas seulement à l\'affichage. Vos changements ne touchent pas le royaume tant qu\'ils ne sont pas publiés.',
    warning: 'Valeur de départ remise : l\'ancienne manquait ou n\'est plus permise.',
    loading: 'Un instant…',
    steps: 'Étapes',
  },

  confirmLeave: {
    title: 'Quitter cette fiche ?',
    text: 'Rien n\'est encore enregistré : vos changements seront perdus.',
    cancel: 'Rester',
    ok: 'Quitter',
  },

  modeEdit: 'Mode édition : visible par vous seul',

  states: { stale: 'Une autre version a été publiée depuis le début de ce brouillon.' },
  buttons: { save: 'Enregistrer le brouillon', check: 'Vérifier' },
  working: 'Un instant…',
  saved: 'Brouillon enregistré.',
  warningsSaved: 'Brouillon enregistré. À corriger avant de publier :',
  invalid: 'Quelques réglages sont à corriger avant de continuer.',
  removalDone: 'Le retrait est publié.',
  changed: {
    live: 'Cette fiche vient de changer ailleurs : la voici à jour.',
    dirty: 'Cette fiche a changé ailleurs : vos changements ne sont pas enregistrés.',
    reload: 'Relire',
  },

  confirm: {
    ask: (label) => `${label} ?`,
    stay: 'Rester',
    backEntry: 'Revenir à la fiche',
    invalid: 'Quelques réglages sont à corriger avant de publier.',
    restore: (n) => `Revenir à la version ${n} ?`,
    restoreOk: 'Revenir à cette version',
    discard: { title: 'Abandonner ce brouillon ?', text: 'Rien de ce qu\'il contient ne sera gardé.', cancel: 'Garder', ok: 'Abandonner' },
    retire: (of, the, feminine) => ({
      title: `Préparer le retrait ${of} ?`,
      text: `Rien ne change en jeu avant que le retrait soit publié ; ${the} pourra être ${feminine ? 'rétablie' : 'rétabli'} depuis son historique.`,
      ok: 'Préparer le retrait',
    }),
    take: (who) => ({ title: `Reprendre le brouillon de ${who} ?`, text: 'La reprise sera inscrite au journal du Conseil.', ok: 'Reprendre le brouillon' }),
  },

  history: {
    title: 'Historique',
    back: 'Retour à la fiche',
    version: (n) => `Version ${n}`,
    tags: { live: 'Publiée', archived: 'Archivée', removal: 'Retrait' },
    from: (n) => `rétablie de la version ${n}`,
    view: 'Voir',
    restore: 'Revenir à cette version',
    older: 'Plus anciennes',
    none: 'Aucune version publiée.',
  },
  removed: { link: 'Fiches retirées du royaume', empty: 'Rien n\'a été retiré du royaume.' },

  fields: {
    required: 'À remplir.',
    range: (min, max) => `Entre ${min} et ${max}.`,
    step: (step) => `Par pas de ${step}.`,
    choice: 'Ce choix n\'est pas proposé.',
    length: (min, max) => `Entre ${min} et ${max} caractères.`,
    lines: (max) => `${max} lignes au plus.`,
    charset: {
      name: 'Lettres, chiffres, espaces, apostrophes, traits d\'union, virgules et points seulement.',
      id: 'Minuscules sans accent, chiffres et traits bas (_) seulement.',
      free: 'Les signes « < » et « > » ne sont pas permis.',
    },
    item: 'Cet objet n\'existe pas dans le royaume.',
    itemUnavailable: 'La liste des objets du royaume ne répond pas : impossible de vérifier cet objet.',
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

  duration: {
    long: { j: ['jour', 'jours'], h: ['heure', 'heures'], min: ['minute', 'minutes'], s: ['seconde', 'secondes'] },
    short: { j: 'j', h: 'h', min: 'min', s: 's' },
  },

  // refus du serveur : texte reçu avec le code ; ici, les seuls codes de la page et du relais
  errors: {
    unknown_kind: 'Ce genre de fiche n\'existe plus dans cet atelier.',
    timeout: 'Le serveur ne répond pas.',
    invalid_args: 'Demande refusée.',
    invalid_response: 'Réponse du serveur illisible : rouvrez l\'Atelier.',
    stale: 'L\'Atelier s\'est désaccordé du serveur : rouvrez-le.',
    client_error: 'Cette page a trébuché : rouvrez l\'Atelier.',
    default: 'Action impossible.',
  },
  revoked: 'Votre place au Conseil a changé : l\'Atelier se ferme.',
  editorGone: 'Cet atelier vient d\'être retiré : réessayez plus tard.',
});

function errorText(code, text) {
  return (typeof text === 'string' && text) || STRINGS.errors[code] || STRINGS.errors.default;
}
