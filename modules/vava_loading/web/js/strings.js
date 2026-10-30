/*
 * vava_loading/web/js/strings.js
 * Rôle : TOUS les textes vus du joueur sur l'écran de chargement. Textes provisoires (ceux de la maquette) : T-021 les
 *        remplace en ne touchant que ce fichier.
 * Format fixé (lu aussi par tests/spec/loading_screen_spec.lua) :
 *   - aucun balisage, aucun chevron ouvrant dans tout le fichier ; apostrophes typographiques (’) dans les textes ;
 *   - quotes: [ … ] et tips: [ … ] : une chaîne entre apostrophes simples par ligne, la liste fermée seule sur sa
 *     ligne ; 6 à 40 extraits, 6 à 20 conseils, 240 octets au plus chacun ;
 *   - une touche s'écrit [[F1]] (12 octets au plus, 3 touches au plus par conseil) : la page en fait un cartouche ;
 *     les touches citées sont celles PAR DÉFAUT des configs (vava_codex F1, vava_inventory I, vava_chat T), la page
 *     ne peut pas lire celles du joueur (décision 12) ; la touche de la voix n'est pas citée : FiveM nomme les touches
 *     d'après le QWERTY, son Z est le W d'un clavier AZERTY (le Codex montre la touche réellement liée) ;
 *   - stages : exactement 6 étapes { text, detail }, une par ligne ;
 *   - {n}, {total}, {done} : remplacés par la page.
 * Dépendances : js/config.js (window.VavaLoading)
 */
(function (root) {
  'use strict';

  var VavaLoading = root.VavaLoading = root.VavaLoading || {};

  VavaLoading.strings = {
    realm: 'Royaume d’Eldoria',
    tagline: 'Rôle médiéval fantastique',
    eyebrow: 'Bienvenue, voyageur',
    title: 'Eldoria',
    motto: 'Là où naissent les légendes',
    loreLabel: 'Ce que l’on dit au bourg',
    tipLabel: 'Avis au voyageur',
    skip: 'Passer l’ouverture',
    musicOff: 'Musique coupée',
    musicOn: 'Musique jouée',
    progressLabel: 'Progression du chargement',
    step: 'Étape {n} sur {total}',
    files: '{done} / {total} fichiers',
    handoffTitle: 'Le royaume vous attend',
    handoffText: 'La sélection du personnage s’ouvre',
    percent: '{pct} %',
    // journal de calibrage (config.debug.journal, premier test en jeu seulement)
    journalTitle: 'Journal de calibrage',
    journalStage: 'feu {n} : {t} s',
    journalRow: '{name} ×{count} : {first} → {last} s',
    journalFoot: '{pct} % · ignorés : {ignored} · effets : {level}',
    // runes du sceau (bloc runique d'Unicode, police système Segoe UI Historic)
    sigil: 'ᚱᛟᛃᚨᚢᛗᛖ · ᛞ · ᛖᛚᛞᛟᚱᛁᚨ · ᛚᚨ · ᛟᚢ · ᚾᚨᛁᛋᛋᛖᚾᛏ · ᛚᛖᛋ · ᛚᛖᚷᛖᚾᛞᛖᛋ ·',

    stages: [
      { text: 'Le messager franchit les portes', detail: 'Connexion au royaume' },
      { text: 'On déroule les cartes du royaume', detail: 'Chargement de la carte' },
      { text: 'Les artisans ouvrent leurs ateliers', detail: 'Données du monde' },
      { text: 'Les veilleurs allument les lanternes', detail: 'Ressources du serveur' },
      { text: 'Le registre s’ouvre à votre nom', detail: 'Ouverture de la session' },
      { text: 'Le bourg prépare votre arrivée', detail: 'En attente de la sélection du personnage' },
    ],

    quotes: [
      '« À Eldoria, nul ne compte en pièces d’or : on donne ce qu’on a, on reçoit ce qu’il faut. »',
      '« Chaque échange tisse un lien. Le forgeron se souvient de qui lui a porté le charbon. »',
      '« Personne ne sait tout faire. C’est pour cela que l’on frappe aux portes. »',
      '« La terre donne à qui la ménage. Une coupe trop avide laisse une cicatrice, et la terre tarde à pardonner. »',
      '« La magie se paie toujours. Les anciens disent qu’elle se souvient de ceux qui l’oublient. »',
      '« Le savoir ne s’achète pas : il passe de la main du maître à celle de l’apprenti. »',
      '« On vient à Eldoria pour recommencer. Personne ne vous demandera d’où vous venez. »',
      '« Chaque objet porte une histoire : le poinçon de son artisan, les mains qui l’ont tenu. »',
    ],

    tips: [
      '[[F1]] ouvre le Codex : toutes les commandes et les touches du royaume.',
      '[[I]] ouvre votre besace. Ce que vous tenez en main, les autres le voient.',
      'Une touche change la portée de votre voix : chuchoter, parler, crier, déclamer. Le Codex [[F1]] vous dit laquelle.',
      '[[T]] ouvre le chat : /me et /do pour vos gestes. Le reste y est dit hors du rôle.',
      'Un apprenti progresse plus vite auprès d’un maître. Cherchez qui sait.',
      'Rien ne s’achète ici : proposez un service, un troc, un coup de main.',
    ],
  };

  if (typeof module === 'object' && module.exports) module.exports = VavaLoading.strings;
})(typeof window !== 'undefined' ? window : globalThis);
