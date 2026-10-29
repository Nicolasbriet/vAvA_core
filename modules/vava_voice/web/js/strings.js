'use strict';
/*
 * web/js/strings.js
 * Rôle : textes de l'éditeur des zones de voix (français), libellés des effets, erreurs, mise en forme des nombres.
 */

const STRINGS = (() => {
  const decimal = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 });
  const number = (value) => decimal.format(value);

  return {
    title: 'Zones de voix',
    close: 'Fermer',
    intro: 'Les zones proches sont dessinées autour de vous. Quand des zones se chevauchent, la plus petite l\'emporte.',
    count: (count, max) => `${count} / ${max} zones`,
    create: 'Nouvelle zone ici',
    empty: 'Aucune zone pour l\'instant. Placez-vous au centre du lieu, puis créez-la.',
    entrySub: (zone) => `${STRINGS.effect(zone.multiplier)} · rayon ${number(zone.radius)} m · hauteur ${number(zone.height)} m`,
    distance: (meters) => (meters < 1 ? 'ici' : `à ${number(meters)} m`),
    newTitle: 'Nouvelle zone',
    editTitle: 'Modifier la zone',
    newHint: 'Centrée sur l\'endroit où vous vous tenez.',
    name: 'Nom du lieu',
    namePlaceholder: 'Salle du trône, place du marché…',
    radius: 'Rayon',
    height: 'Hauteur',
    heightHint: (below) => `Comptée depuis vos hanches ; la zone descend aussi de ${number(below)} m sous elles. Séparez ainsi les étages.`,
    effectLabel: 'Effet sur la voix',
    meters: (value) => `${number(value)} m`,
    effect: (multiplier) => `×${number(multiplier)}`,
    effects: {
      0.5: 'Très feutrée',
      0.75: 'Feutrée',
      1: 'Normale',
      1.5: 'Porte un peu',
      2: 'Porte loin',
      3: 'Porte très loin',
    },
    rangeLine: (label, from, to) => `${label} : ${number(from)} m → ${number(to)} m`,
    moveHere: 'Recentrer la zone là où je me trouve',
    save: 'Sceller',
    cancel: 'Annuler',
    reach: 'S\'y rendre',
    remove: 'Supprimer',
    confirmRemove: 'Confirmer la suppression',
    saved: (label) => `Zone « ${label} » scellée.`,
    removed: (label) => `Zone « ${label} » supprimée.`,
    reached: 'Vous voici au centre de la zone.',
    errors: {
      default: 'Action impossible.',
      forbidden: 'Votre rang ne le permet pas.',
      too_many_zones: 'Le nombre maximal de zones est atteint.',
      invalid_label: 'Donnez un nom au lieu.',
      label_unreadable: 'Ce nom contient des signes illisibles.',
      label_too_long: 'Ce nom est trop long.',
      busy: 'Un instant : la demande précédente n\'a pas encore abouti.',
      unknown_zone: 'Cette zone n\'existe plus.',
      no_position: 'Votre position est introuvable.',
      db_error: 'La zone n\'a pas pu être enregistrée.',
      rate_limited: 'Trop de demandes : patientez un instant.',
      invalid_args: 'Valeurs refusées.',
    },
    error(code) {
      return STRINGS.errors[code] || STRINGS.errors.default;
    },
  };
})();
