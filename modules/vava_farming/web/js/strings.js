'use strict';
/*
 * web/js/strings.js
 * Rôle : tous les textes affichés par l'agriculture (français) : invite près d'un emplacement, d'un puits ou d'un
 *        grenier, menu d'emplacement (état, mesures, gestes et leurs refus), résultats, codes d'erreur.
 */

const STRINGS = Object.freeze({
  tiers: ['Grossier', 'Commun', 'Soigné', 'Excellent', 'Chef-d\'œuvre'],
  states: { growing: 'pousse', ripe: 'mûr', wilted: 'flétri', dead: 'mort' },
  prompt: {
    slot: 'Cultiver',
    well: 'Remplir le seau',
    granary: 'Ouvrir',
    slotLabel: (index) => `Emplacement ${index}`,
    free: 'libre',
    stage: (stage, stages) => `stade ${stage} / ${stages}`,
  },
  menu: {
    close: 'Fermer',
    refresh: 'Relire',
    slot: (index) => `Emplacement ${index}`,
    communal: 'Parcelle communale',
    privateParcel: 'Parcelle privée',
    free: 'Emplacement libre',
    freeText: 'La terre attend une graine.',
    progress: 'Croissance',
    moisture: 'Humidité',
    fertility: 'Fertilité',
    percent: (v) => `${Math.round(v)} %`,
    threshold: (v) => `seuil ${v} %`,
    dry: 'Terre sèche : la pousse marque une pause.',
    facts: {
      waterings: (n) => (n === 1 ? '1 arrosage' : `${n} arrosages`),
      dryHours: (h) => `${h.toLocaleString('fr-FR', { maximumFractionDigits: 1 })} h de sécheresse`,
      planted: (text) => `semé ${text}`,
    },
    since: (seconds) => {
      if (seconds < 60) return 'à l\'instant';
      if (seconds < 3600) return `il y a ${Math.floor(seconds / 60)} min`;
      if (seconds < 86400) return `il y a ${Math.floor(seconds / 3600)} h`;
      return `il y a ${Math.floor(seconds / 86400)} j`;
    },
    actions: {
      title: 'Gestes',
      plant: 'Semer',
      water: 'Arroser',
      fertilize: 'Fertiliser',
      harvest: 'Récolter',
      clear: 'Arracher',
      seedChoice: 'Graine :',
      tierChoice: 'Palier :',
      noSeeds: 'Vous n\'avez aucune graine.',
      count: (n) => `× ${n}`,
      bucketHeld: (charges) => (charges === 1 ? 'seau en main, 1 charge' : `seau en main, ${charges} charges`),
      bucketEmpty: 'seau en main, vide : remplissez-le à un puits',
      bucketNone: 'pas de seau en main',
      compost: (n) => (n === 0 ? 'aucun compost' : n === 1 ? '1 compost' : `${n} composts`),
      sickle: 'faucille en main : plus rapide',
      noSickle: 'à la main (une faucille irait plus vite)',
      waste: 'Une plante flétrie ou morte rend des déchets végétaux.',
      reasons: {
        occupied: 'Déjà planté.',
        empty: 'Rien ne pousse ici.',
        noSeeds: 'Aucune graine dans la besace.',
        noBucket: 'Prenez un seau en main.',
        bucketEmpty: 'Le seau est vide.',
        dead: 'La plante est morte : arrachez-la.',
        noCompost: 'Il vous faut du compost.',
        notRipe: (progress) => `Pas encore mûr (${Math.round(progress * 100)} %).`,
        refused: 'Impossible pour le moment.',
      },
    },
  },
  result: {
    plant: (label) => `${label} semé.`,
    water: 'Arrosé.',
    fertilize: 'Compost épandu.',
    harvest: (quantity, label, tier) => `${quantity} × ${label} (${tier}).`,
    seeds: (n) => (n === 1 ? ' Une graine récupérée.' : ` ${n} graines récupérées.`),
    clear: 'Emplacement dégagé.',
    clearWaste: (quantity, label) => `Emplacement dégagé : ${quantity} × ${label}.`,
    filled: (charges) => (charges === 1 ? 'Seau rempli (1 charge).' : `Seau rempli (${charges} charges).`),
  },
  hints: [['Échap', 'fermer']],
  errors: {
    default: 'Action impossible.',
    unknown_parcel: 'Cette parcelle n\'existe pas.',
    unknown_slot: 'Cet emplacement n\'existe pas.',
    unknown_crop: 'Culture inconnue.',
    unknown_well: 'Ce puits n\'existe pas.',
    no_granary: 'Cette parcelle n\'a pas de grenier.',
    invalid_action: 'Geste inconnu.',
    bad_tier: 'Palier de graine invalide.',
    missing_items: 'Il vous manque quelque chose.',
    full: 'Le seau est déjà plein.',
    busy: 'Un geste est déjà en cours.',
    downed: 'Vous êtes à terre.',
    too_far: 'Trop loin.',
    too_soon: 'Trop tôt.',
    not_found: 'Ce geste n\'est plus en cours.',
    no_character: 'Aucun personnage en jeu.',
    rate_limited: 'Doucement…',
    timeout: 'Le serveur ne répond pas.',
    refused: 'Action refusée.',
    client_error: 'Erreur de l\'interface.',
    server_error: 'Le serveur a rencontré une erreur.',
  },
});

/** Message lisible pour un code d'erreur, ou la raison donnée par un module si elle est déjà rédigée. */
function errorMessage(code) {
  return STRINGS.errors[code] || (typeof code === 'string' && code.length > 0 && !code.includes('_') ? code : STRINGS.errors.default);
}
