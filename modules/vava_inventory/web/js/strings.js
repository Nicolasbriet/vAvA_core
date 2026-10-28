'use strict';
/*
 * web/js/strings.js
 * Rôle : tous les textes affichés par l'inventaire (français).
 */

const STRINGS = Object.freeze({
  weightMax: (max) => (max > 0 ? ` / ${kilos(max)} kg` : ' kg'),
  quantity: (quantity, stack) => (stack > 1 ? `${quantity} / ${stack}` : ''),
  hotbar: 'Ceinture',
  hotbarHint: 'Glissez un objet sur un emplacement',
  hands: 'Mains',
  handsHint: 'Glissez ici ce qui se tient en main',
  dropZone: 'Relâcher pour jeter au sol',
  // [touche, action] : légende en bas de l'écran
  hints: [
    ['Glisser', 'déplacer'],
    ['R', 'pivoter'],
    ['Maj', 'diviser'],
    ['Double-clic', 'utiliser ou tenir'],
    ['Clic droit', 'actions'],
    ['Échap', 'fermer'],
  ],
  // Métadonnées connues (contrat standard, voir docs/api.md) ; `lines` d'un module s'affiche tel quel.
  metadata: {
    tiers: ['Grossier', 'Commun', 'Soigné', 'Excellent', 'Chef-d\'œuvre'],
    tierNumerals: ['I', 'II', 'III', 'IV', 'V'],
    tier: 'Palier',
    tierLabel: (tier) => STRINGS.metadata.tiers[tier - 1] || `Palier ${tier}`,
    quality: 'Qualité',
    qualityValue: (quality) => `${Math.round(quality)} / 100`,
    durability: 'Solidité',
    durabilityValue: (current, max) => `${Math.round(current)} / ${Math.round(max)}`,
    broken: 'Brisé',
    brokenNote: 'Inutilisable tant qu\'il n\'est pas réparé.',
    origin: 'Provenance',
    crafter: (name) => `Façonné par ${name}`,
    mark: 'Poinçon',
    craftedAt: (date) => `le ${date}`,
    history: 'Histoire',
    // natures d'entrées d'histoire connues ; une autre nature s'affiche telle quelle
    historyKinds: {
      creation: 'Création',
      repair: 'Réparation',
      rename: 'Baptême',
      enchant: 'Enchantement',
      transfer: 'Transmission',
    },
    historyBy: (who) => ` par ${who}`,
    held: 'En main',
    date: (seconds) => new Date(seconds * 1000).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' }),
  },
  // effets affichés dans la fiche d'un objet, dans cet ordre ; un effet absent de cette liste n'est pas montré
  effects: [['hunger', 'Faim'], ['thirst', 'Soif']],
  effectValue: (value) => `${value > 0 ? '+' : '−'}${Math.abs(value).toLocaleString('fr-FR', { maximumFractionDigits: 1 })}`,
  // catégories connues du thème ; une autre catégorie s'affiche telle quelle
  categories: {
    nourriture: 'Nourriture',
    boisson: 'Boisson',
    arme: 'Arme',
    armure: 'Armure',
    outil: 'Outil',
    materiau: 'Matériau',
    valeur: 'Objet de valeur',
    soin: 'Soin',
    divers: 'Divers',
  },
  actions: {
    use: 'Utiliser',
    hold: 'Tenir en main',
    release: 'Reposer',
    split: 'Diviser…',
    drop: 'Jeter',
    pickup: 'Ramasser',
    clearSlot: 'Vider le raccourci',
  },
  split: { title: 'Diviser la pile', confirm: 'Diviser', cancel: 'Annuler', quantity: 'Quantité' },
  tooltip: {
    weight: 'Poids',
    size: 'Taille',
    quantity: 'Pile',
    kilos: (grams) => `${kilos(grams)} kg`,
    unit: (grams) => `${kilos(grams)} kg l'unité`,
    cells: (w, h) => `${w} × ${h}`,
    use: ['Double-clic', 'utiliser'],
    hold: ['Double-clic', 'tenir en main'],
    release: ['Double-clic', 'reposer'],
  },
  errors: {
    default: 'Action impossible.',
    no_space: 'Pas assez de place.',
    too_heavy: 'Trop lourd.',
    too_big: 'Cet objet ne tient pas dans un sac.',
    no_access: 'Hors de portée.',
    not_found: 'Cet objet n\'est plus là.',
    unknown_item: 'Objet inconnu.',
    not_stackable: 'Ces objets ne s\'empilent pas.',
    stack_full: 'La pile est pleine.',
    invalid_quantity: 'Quantité invalide.',
    conflict: 'L\'inventaire a changé, réessayez.',
    not_usable: 'Cet objet ne s\'utilise pas.',
    not_holdable: 'Cet objet ne se tient pas en main.',
    use_failed: 'Impossible d\'utiliser cet objet.',
    too_far: 'Trop loin.',
    invalid_metadata: 'Inscription refusée.',
    drop_failed: 'Impossible de poser un sac ici.',
    already_dropped: 'Cet objet est déjà au sol.',
    rate_limited: 'Doucement…',
    timeout: 'Le serveur ne répond pas.',
    refused: 'Action refusée.',
    no_character: 'Aucun personnage chargé.',
    client_error: 'Erreur de l\'interface.',
  },
});

function kilos(grams) {
  return (grams / 1000).toLocaleString('fr-FR', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
}

/** Nom affiché d'une catégorie : celui du thème, sinon la catégorie avec une majuscule. */
function categoryLabel(category) {
  return STRINGS.categories[category] || category.charAt(0).toUpperCase() + category.slice(1);
}

/** Message lisible pour un code d'erreur, ou la raison donnée par un module si elle est déjà rédigée. */
function errorMessage(code) {
  return STRINGS.errors[code] || (typeof code === 'string' && code.length > 0 && !code.includes('_') ? code : STRINGS.errors.default);
}
