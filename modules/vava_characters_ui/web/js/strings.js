'use strict';
/*
 * web/js/strings.js
 * Rôle : tous les textes affichés par l'interface (français). Aucun texte n'est écrit ailleurs.
 */

const STRINGS = Object.freeze({
  selection: {
    title: 'Registre des âmes',
    subtitle: 'Choisissez qui vous serez',
    play: 'Jouer',
    playing: 'Entrée…',
    create: 'Nouveau personnage',
    emptySlot: 'Emplacement libre',
    delete: 'Supprimer',
    deleteTitle: 'Supprimer ce personnage ?',
    deleteMessage: (name) => `${name} sera retiré du registre. Cette action est définitive.`,
    deleteConfirm: 'Supprimer',
    slotsLeft: (n) => (n > 1 ? `${n} emplacements libres` : n === 1 ? '1 emplacement libre' : 'Aucun emplacement libre'),
    reference: (id) => `Registre n° ${id}`,
  },
  sexes: { m: 'Homme', f: 'Femme' },
  creator: {
    title: 'Nouveau personnage',
    previous: 'Précédent',
    next: 'Suivant',
    create: 'Créer le personnage',
    creating: 'Création…',
    random: 'Aléatoire',
    reset: 'Réinitialiser',
    cancel: 'Abandonner',
    cancelTitle: 'Abandonner la création ?',
    cancelMessage: 'Les choix effectués seront perdus.',
    cancelConfirm: 'Abandonner',
    keep: 'Continuer',
    confirmTitle: 'Créer ce personnage ?',
    confirmMessage: (name) => `${name} rejoindra le royaume. Son nom ne pourra plus être modifié.`,
    confirm: 'Créer',
    sexChangeTitle: 'Changer de sexe ?',
    sexChangeMessage: 'L\'apparence sera réinitialisée.',
    sexChangeConfirm: 'Changer',
    // [touche, action] : légende sous l'aperçu
    rotateHint: [['Glisser', 'pivoter'], ['Q', 'vers la gauche'], ['E', 'vers la droite']],
    views: { face: 'Visage', body: 'Silhouette' },
    none: 'Aucun',
    step: (current, total) => `Étape ${current} / ${total}`,
  },
  tabs: {
    identity: 'Identité',
    heritage: 'Héritage',
    face: 'Visage',
    hair: 'Cheveux',
    skin: 'Peau',
    makeup: 'Maquillage',
    outfit: 'Tenue',
  },
  identity: {
    firstName: 'Prénom',
    lastName: 'Nom',
    sex: 'Sexe',
    // règle rappelée sous le champ, d'après les règles du serveur : « 2 à 24 lettres. Espace, apostrophe et trait
    // d'union autorisés entre deux lettres. »
    nameHint: (min, max, separators) => {
      const length = `${min} à ${max} lettres.`;
      if (separators.length === 0) return length;
      const list = separators.length === 1 ? separators[0] : `${separators.slice(0, -1).join(', ')} et ${separators[separators.length - 1]}`;
      return `${length} ${list.charAt(0).toUpperCase()}${list.slice(1)} ${separators.length > 1 ? 'autorisés' : 'autorisé'} entre deux lettres.`;
    },
    separatorNames: { ' ': 'espace', '\'': 'apostrophe', '-': 'trait d\'union' },
    nameInvalid: 'Ce nom n\'est pas valide.',
  },
  heritage: {
    parents: 'Parents',
    mother: 'Mère',
    father: 'Père',
    face: (n) => `Visage ${n}`,
    blend: 'Mélange',
    shapeMix: 'Ressemblance',
    skinMix: 'Teint',
  },
  featureGroups: [
    { title: 'Nez', features: [0, 1, 2, 3, 4, 5] },
    { title: 'Sourcils', features: [6, 7] },
    { title: 'Pommettes et joues', features: [8, 9, 10] },
    { title: 'Yeux et lèvres', features: [11, 12] },
    { title: 'Mâchoire et menton', features: [13, 14, 15, 16, 17, 18] },
    { title: 'Cou', features: [19] },
  ],
  features: [
    'Largeur', 'Hauteur', 'Longueur', 'Arête', 'Pointe', 'Torsion',
    'Hauteur', 'Profondeur',
    'Hauteur des pommettes', 'Largeur des pommettes', 'Largeur des joues',
    'Ouverture des yeux', 'Épaisseur des lèvres',
    'Largeur de la mâchoire', 'Profondeur de la mâchoire', 'Hauteur du menton',
    'Avancée du menton', 'Largeur du menton', 'Fossette du menton',
    'Épaisseur du cou',
  ],
  hair: {
    title: 'Chevelure',
    style: 'Coupe',
    variant: 'Variante',
    color: 'Couleur',
    highlight: 'Reflets',
    eyes: 'Yeux',
    eyeColor: 'Couleur des yeux',
    eyeShade: (n) => `Teinte ${n}`,
  },
  overlays: {
    0: 'Imperfections',
    1: 'Barbe',
    2: 'Sourcils',
    3: 'Rides',
    4: 'Maquillage des yeux',
    5: 'Fard à joues',
    6: 'Teint',
    7: 'Marques du soleil',
    8: 'Rouge à lèvres',
    9: 'Taches de rousseur',
    10: 'Pilosité du torse',
  },
  overlay: { style: 'Style', opacity: 'Intensité', color: 'Couleur' },
  components: { 3: 'Bras', 4: 'Bas', 6: 'Chaussures', 8: 'Sous-vêtement', 11: 'Haut' },
  props: { 0: 'Couvre-chef', 1: 'Lunettes', 2: 'Boucles d\'oreilles' },
  outfit: { clothes: 'Vêtements', accessories: 'Accessoires', model: 'Modèle', variant: 'Variante', armsHint: 'Ajustez les bras si le haut laisse apparaître des manques.' },
  errors: {
    default: 'Une erreur est survenue.',
    invalid_name: 'Ce nom n\'est pas valide.',
    invalid_sex: 'Sexe invalide.',
    too_many_characters: 'Vous avez atteint le nombre maximum de personnages.',
    name_taken: 'Ce nom est déjà porté par un autre personnage.',
    busy: 'Une action est déjà en cours.',
    rate_limited: 'Doucement… réessayez dans un instant.',
    timeout: 'Le serveur ne répond pas, réessayez.',
    not_owner: 'Ce personnage ne vous appartient pas.',
    not_found: 'Personnage introuvable.',
    refused: 'Action refusée.',
    db_error: 'Le registre est indisponible, réessayez.',
    invalid_fields: 'Apparence invalide.',
    invalid_args: 'Données invalides.',
    wrong_state: 'Action impossible pour le moment.',
    model_unavailable: 'Modèle indisponible.',
    no_session: 'Session introuvable : reconnectez-vous.',
    corrupted_data: 'Les données de ce personnage sont illisibles.',
    client_error: 'Erreur de l\'interface.',
  },
});

/** Message lisible pour un code d'erreur du serveur ou d'un module (raison d'un refus). */
function errorMessage(code) {
  return STRINGS.errors[code] || (typeof code === 'string' && code.length > 0 && !code.includes('_') ? code : STRINGS.errors.default);
}
