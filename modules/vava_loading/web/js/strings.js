/*
 * vava_loading/web/js/strings.js
 * Rôle : TOUS les textes vus du joueur sur l'écran de chargement (textes définitifs, T-021). Chaque conseil décrit le
 *        jeu tel qu'il est codé : une règle qui change dans un module fait relire le conseil qui en parle.
 * Format fixé (lu aussi par tests/spec/loading_screen_spec.lua) :
 *   - aucun balisage, aucun chevron ouvrant dans tout le fichier ; apostrophes typographiques (’) dans les textes ;
 *   - quotes: [ … ] et tips: [ … ] : une chaîne entre apostrophes simples par ligne, la liste fermée seule sur sa
 *     ligne ; 6 à 40 extraits, 6 à 20 conseils, 240 octets au plus chacun ;
 *   - une touche s'écrit [[F1]] (12 octets au plus, 3 touches au plus par conseil) : la page en fait un cartouche ;
 *     les touches citées sont celles PAR DÉFAUT des configs (vava_codex F1, vava_inventory I, vava_chat T,
 *     vava_skills K, vava_health G pour relever, vava_gathering O), la page ne peut pas lire celles du joueur
 *     (décision 12 : changer une de ces touches par défaut oblige à retoucher ce fichier) ; seules des touches à la
 *     même place en QWERTY et en AZERTY sont citées : FiveM nomme les touches d'après le QWERTY (le Z de la voix est
 *     le W d'un clavier AZERTY, les chiffres de la ceinture n'y sont pas des chiffres), le Codex montre la touche
 *     réellement liée ;
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
      { text: 'Les veilleurs allument les lanternes', detail: 'Ressources du royaume' },
      { text: 'Le registre s’ouvre à votre nom', detail: 'Ouverture de la session' },
      { text: 'Le bourg prépare votre arrivée', detail: 'En attente de la sélection du personnage' },
    ],

    quotes: [
      // le troc et les liens
      '« À Eldoria, nul ne compte en pièces d’or : on donne ce qu’on a, on reçoit ce qu’il faut. »',
      '« Ici, on ne demande pas : combien ? On demande : de quoi as-tu besoin ? »',
      '« Chaque échange tisse un lien. Le forgeron se souvient de qui lui a porté le charbon. »',
      '« Trois truites contre une hache réparée : c’est ainsi que l’on s’entend, à Eldoria. »',
      '« Le titre ne nourrit personne. Ici, on vous juge à ce que vous faites de vos mains. »',
      // le savoir
      '« Personne ne sait tout faire. C’est pour cela que l’on frappe aux portes. »',
      '« Nul n’a deux vies pour tout apprendre. Ce que l’on choisit d’oublier fait place à ce que l’on apprend. »',
      '« Le savoir ne s’achète pas : il passe de la main du maître à celle de l’apprenti. »',
      '« L’apprenti qui travaille aux côtés de son maître avance plus vite que celui qui cherche seul. »',
      '« Qui a appris d’un maître enseigne à son tour. Ainsi chaque savoir remonte, de main en main, jusqu’à son fondateur. »',
      // la terre et les saisons
      '« La terre donne à qui la ménage. Une coupe trop avide laisse une cicatrice, et la terre tarde à pardonner. »',
      '« Qui coupe tout aujourd’hui ne coupera rien demain. La forêt ne rend que ce qu’on lui laisse. »',
      '« Le pêcheur pressé rentre bredouille. L’eau, comme la terre, a besoin de repos. »',
      '« La même graine au même sillon finit par lasser la terre. Changez de culture, ou laissez-la dormir. »',
      '« Semailles, moissons, brumes, frimas : chaque saison demande sa part de travail. »',
      '« Une nuit d’hiver suffit à geler un champ. Le cultivateur avisé couvre ses rangs avant que le froid tombe. »',
      '« Le grenier commun est à tous. Ce qu’on y dépose et ce qu’on y prend, le registre s’en souvient. »',
      // les objets
      '« Chaque objet porte une histoire : le poinçon de son artisan, puis chaque main qui l’a réparé. »',
      '« Un chef-d’œuvre porte un nom. Celui qui l’a façonné le lui a donné, et nul ne peut le lui reprendre. »',
      // la magie
      '« La magie se paie toujours. Les anciens disent qu’elle se souvient de ceux qui l’oublient. »',
      '« On ne choisit pas la magie : c’est elle qui répond, ou qui se tait. »',
      '« Les Arcanes ne s’apprennent pas dans les livres : il y faut un maître, à portée de voix. »',
      '« Le feu et l’eau, mêlés, donnent autre chose que du feu ou de l’eau. Ce qu’on découvre ainsi, on l’écrit. »',
      '« Le mage qui a tout donné doit attendre que la force lui revienne. Nul sort ne se lance à vide. »',
      // l'entraide et l'arrivée
      '« Un blessé ne se relève jamais seul. Une main tendue vaut mieux que dix bonnes intentions. »',
      '« On vient à Eldoria pour recommencer. Personne ne vous demandera d’où vous venez. »',
      '« Le pain du premier soir, le royaume vous le donne. Celui des jours suivants se partage. »',
      '« Un mot chuchoté ne porte pas plus loin qu’un pas. Un cri, lui, traverse la place. »',
    ],

    tips: [
      '[[F1]] ouvre le Codex : toutes les commandes et les touches du royaume.',
      '[[I]] ouvre votre besace. Ce que vous tenez en main, les autres le voient.',
      '[[T]] ouvre le chat : /me et /do pour vos gestes. Le reste y est dit hors du rôle.',
      'Une touche change la portée de votre voix : chuchoter, parler, crier, déclamer. Le Codex [[F1]] vous dit laquelle.',
      '[[K]] ouvre le livre de vos compétences. Nul ne peut tout pousser au sommet : choisissez ce que vous laissez filer.',
      'Un apprenti progresse plus vite quand son maître travaille à ses côtés. Cherchez qui sait, et demandez.',
      'Certaines recettes ne s’apprennent qu’en regardant faire : trois leçons auprès de qui les connaît.',
      'Rien ne s’achète ici : proposez un service, un troc, un coup de main.',
      'Haches, pioches, faucilles et cannes se tiennent en main et s’usent. Un artisan, à sa station, sait les réparer.',
      '[[O]] montre les zones de récolte et leur état. Une terre épuisée rapporte peu : laissez-la souffler, allez plus loin.',
      'Les champs communaux sont à tous : on y sème, on y arrose, et l’on porte une part de la récolte au grenier.',
      'Le pain et l’eau de votre arrivée tiennent une soirée. Pour la suite, trouvez qui cultive, pêche ou cuisine.',
      '[[G]] près d’une personne à terre : vous l’aidez à se relever. Personne ne se relève seul.',
      '/date donne l’heure, la saison et le ciel. En hiver, une nuit peut geler les champs : couvrez-les à temps.',
      'Un objet dit d’où il vient : sa qualité, sa provenance, parfois le poinçon de son artisan. Demandez qui l’a fait.',
    ],
  };

  if (typeof module === 'object' && module.exports) module.exports = VavaLoading.strings;
})(typeof window !== 'undefined' ? window : globalThis);
