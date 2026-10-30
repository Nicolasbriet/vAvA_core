/*
 * vava_loading/web/js/config.js
 * Rôle : réglages de la page de l'écran de chargement (rythmes de l'ouverture et des textes, seuils des six feux,
 *        effets, musique, journal de calibrage). La page s'affiche avant que le moindre script Lua tourne : elle ne
 *        peut pas lire config.lua (décision 5 de T-020). Seule durée partagée avec le Lua : celle de l'éclair, envoyée
 *        par le client avec le message de passage (la page n'en garde pas de copie).
 *        Toute retouche de ce fichier le fait retélécharger par chaque joueur : retouches rares et groupées.
 * Dépendances : aucune (premier script de la page). Seule globale : window.VavaLoading.
 */
(function (root) {
  'use strict';

  var VavaLoading = root.VavaLoading = root.VavaLoading || {};

  VavaLoading.config = {
    // Seuil en % de chacun des six feux (position sur le chemin, plancher de l'étape). Six entiers croissants de 0 à
    // 99. Recalibrés après le premier test en jeu (journal ci-dessous, docs/tests/chargement.md test 1-4).
    stages: [0, 12, 38, 72, 88, 97],

    // Ouverture jouée à chaque connexion (décision 7), passable d'un clic : filet tracé, lettres qui s'embrasent une à
    // une, rideau levé (≈ 2,7 s pour « Eldoria »).
    opening: {
      enabled: true,
      lineMs: 300,          // filet d'étincelle tracé
      firstLetterMs: 1100,  // première lettre embrasée
      letterStepMs: 190,    // écart entre deux lettres
      revealAfterMs: 300,   // rideau levé après la dernière lettre
      reducedMs: 600,       // fondu seul quand le joueur a demandé moins d'animations
      beaconStepMs: 120,    // feux déjà atteints rallumés un à un à la levée du rideau
    },

    // Extraits du lore à gauche, conseils à droite (fondu de fadeMs entre deux textes).
    rotation: { quoteMs: 9000, tipMs: 6500, fadeMs: 900 },

    effects: {
      level: 'auto',        // 'auto', 'haute', 'moyenne' ou 'basse' (auto : choix au démarrage, puis dégradation)
      fpsMax: 30,           // images par seconde au plus pour les canvas
      minFps: 20,           // en dessous, sur badWindows fenêtres de windowMs de suite : un niveau de moins
      windowMs: 2000,
      badWindows: 2,
      measureDelayMs: 1000, // mesure commencée après la levée du rideau (l'ouverture fausserait tout)
      maxPixelRatio: 1,     // résolution des canvas (le paysage est flou par nature : 1 suffit)
      levels: {
        haute: { stars: 250, embers: 60, fogs: 7, letterSparks: 26, beaconSparks: 30, finalSparks: 40,
          parallax: true, camera: true, comet: true, grain: true, shine: true },
        moyenne: { stars: 150, embers: 25, fogs: 3, letterSparks: 12, beaconSparks: 15, finalSparks: 20,
          parallax: true, camera: true, comet: false, grain: true, shine: true },
        // paysage peint une fois (et à chaque redimensionnement), plus aucune image animée par le script
        basse: { stars: 150, embers: 0, fogs: 3, letterSparks: 0, beaconSparks: 0, finalSparks: 0,
          parallax: false, camera: false, comet: false, grain: false, shine: false },
      },
    },

    // Musique facultative (décision 4) : aucune piste livrée en 1.0.0, bouton caché tant que file est vide. Une piste
    // ajoutée : OGG dans web/audio/, 90 s au plus en boucle, 400 Ko au plus, coupée par défaut, motif ajouté au
    // manifeste et plafond du test relevé.
    music: { file: '', volume: 0.3, fadeMs: 2000 },

    // true : liste à l'écran des messages reçus (nom, type, instant) pour calibrer les seuils. Remis à false avant
    // fusion (le test unitaire le vérifie).
    debug: { journal: false },
  };

  if (typeof module === 'object' && module.exports) module.exports = VavaLoading.config;
})(typeof window !== 'undefined' ? window : globalThis);
