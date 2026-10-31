'use strict';
/*
 * vava_atelier/web/dev/devmock.js
 * Rôle : Atelier simulé quand la page est ouverte dans un navigateur (hors FiveM), pour voir chaque écran sans lancer
 *        le jeu. Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère
 *        que hors FiveM. Réponses de la forme de client/relay.lua : { ok, error?, data? }.
 *        Paramètres d'URL (§ 9.5 de la spec T-100) :
 *          ?screen=home                 accueil d'un Souverain (trois familles, brouillons, journal)
 *          ?screen=home&rank=senechal   seulement « Le monde »
 *          ?screen=home&empty=1         ni brouillon ni journal
 *          ?screen=search&q=forge       cartes filtrées et « Dans les ateliers »
 *          ?screen=list                 « Panneaux du bourg (exemple) », deux onglets
 *          ?screen=entry                fiche « page » du panneau : les huit widgets, groupes, « Pour comparer »
 *          ?screen=entry&errors=1       la même avec trois erreurs de champ et une erreur générale
 *          ?screen=entry&layout=side    fiche « volet » (affiche) avec bandeau
 *          ?screen=keys                 volet, bandeau et barre des touches de la maquette Recolte (aperçu de T-102)
 *          ?screen=journal              journal entier, filtre, « Lignes plus anciennes »
 *          ?screen=confirm              boîte de confirmation
 *          ?screen=picker               liste cherchable d'un champ « objet » ouverte (en plus du § 9.5)
 *        Écrans de T-101 (§ 9.5 de sa spec) :
 *          ?screen=entry&state=draft            son brouillon de panneau : « Brouillon », pied complet, phrase
 *          ?screen=entry&state=trial&layout=side affiche en essai : « Essai, version 2 », bandeau, « Arrêter l'essai »
 *          ?screen=entry&state=other            brouillon d'un autre : lecture seule, « Reprendre le brouillon »
 *          ?screen=entry&state=stale            son brouillon dépassé par une publication
 *          ?screen=entry&state=removal          « Retrait en attente », « Publier le retrait »
 *          ?screen=entry&state=archived         version 2 archivée en lecture, « Revenir à cette version »
 *          ?screen=confirm&what=publish[&errors=1]   boîte de publication (trois lignes, un avertissement ; ou erreurs)
 *          ?screen=confirm&what=restore|discard|retire|take
 *          ?screen=history                      six versions (une rétablie, un retrait), « Plus anciennes »
 *          ?screen=removed                      trois fiches retirées
 *          ?screen=home&drafts=1                « Vos brouillons » : essai, brouillon à enfants, fiche nouvelle, retrait
 *          ?screen=entry&changed=1              fiche modifiée, puis changée ailleurs (entryChanged)
 *        Écrans de T-102 (§ 9.4 de sa spec) :
 *          ?screen=entry&editor=recolte&step=2      maquette Recolte : Forêt de Brume en brouillon, cinq points dont un
 *                                                   nouveau, « Prochain point à poser »
 *          ?screen=entry&editor=recolte&step=1      zone nouvelle : « Pas encore placée. », « Placer la zone »
 *          ?screen=entry&editor=recolte&refused=1   refus « Trop près de « Chêne 2 » (1,4 m) » sous le bloc
 *          ?screen=placing&shape=oriented|circle|polygon   volet atténué, bandeau d'édition, barre des touches du mode
 *          ?screen=placing&shape=oriented&layout=page      panneau (mise en page « page ») : bandeau et barre seuls
 *          ?screen=placing&picked=1                 barre « Déplacer ici · … · Lâcher le point »
 *          ?screen=suspended                        bandeau de l'essai joué seul (F9 : revenir)
 *        Visée simulée : clic pose (un clic sur trois refusé en mode points), clic droit choisit un point, Entrée ferme
 *        un tracé (trois clics au moins), Échap quitte.
 *        Le cycle entier est simulé (enregistrer, essayer, publier, abandonner, retirer, reprendre, rétablir) ;
 *        l'historique est servi par pages de 5 (20 en jeu) pour montrer « Plus anciennes ».
 *        Essais des fonctions pures : node modules/vava_atelier/web/dev/essais.js
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const params = new URLSearchParams(window.location.search);
  const senechal = params.get('rank') === 'senechal';
  const empty = params.get('empty') === '1';
  let forceErrors = params.get('errors') === '1';
  const scene = params.get('state') || '';
  const what = params.get('what') || '';
  const manyDrafts = params.get('drafts') === '1';
  const fold = (t) => String(t || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  const clone = (v) => JSON.parse(JSON.stringify(v));

  // Accueil ----------------------------------------------------------------------------------------------------------
  const families = [{ id: 'monde', label: 'Le monde' }, { id: 'societe', label: 'La société' }, { id: 'arts', label: 'Les arts' }];
  const cards = [
    { editor: 'vava_gathering:zones', family: 'monde', label: 'Récolte', description: 'Forêts, mines, prairies et coins de pêche, arbres et filons un par un.', icon: 'recolte', upcoming: false },
    { editor: 'vava_farming:parcelles', family: 'monde', label: 'Agriculture', description: 'Parcelles communales ou privées, puits, greniers et composteurs.', icon: 'agriculture', upcoming: false },
    { editor: 'vava_crafting:stations', family: 'monde', label: 'Artisanat', description: 'Forges, établis, métiers à tisser : où ils sont, ce qu\'on peut y faire.', icon: 'artisanat', upcoming: false },
    { editor: 'vava_doors:portes', family: 'monde', label: 'Portes et clés', description: 'Viser une porte, la déclarer, la verrouiller, créer ses clés.', icon: 'porte', upcoming: true },
    { editor: 'vava_example_atelier:panneaux', family: 'monde', label: 'Panneaux du bourg (exemple)', description: 'Exemple de développement : tous les réglages qu\'un atelier peut montrer.', icon: 'parchemin', upcoming: false },
    { editor: 'vava_guilds:confreries', family: 'societe', label: 'Confréries', description: 'La Garde, les Guérisseurs, les guildes : grades, droits, coffres, lieux.', icon: 'confrerie', upcoming: false },
    { editor: 'vava_housing:logis', family: 'societe', label: 'Logis', description: 'Maisons et chambres attribuées par le Conseil, coffres privés.', icon: 'logis', upcoming: true },
    { editor: 'vava_example_atelier:proclamations', family: 'societe', label: 'Proclamations (exemple)', description: 'Exemple de développement : un atelier réservé au Souverain.', icon: 'parchemin', upcoming: false },
    { editor: 'vava_emotes:gestes', family: 'arts', label: 'Gestes', description: 'Animations et accessoires pour les émotes et les métiers.', icon: 'geste', upcoming: false },
    { editor: 'vava_combat:techniques', family: 'arts', label: 'Techniques de combat', description: 'Coups, parades, esquives : animation, timing et zone touchée.', icon: 'combat', upcoming: false },
    { editor: 'vava_magic:effets', family: 'arts', label: 'Effets', description: 'Particules, lumières et sons réutilisables partout.', icon: 'effet', upcoming: false },
    { editor: 'vava_magic:sorts', family: 'arts', label: 'Sorts', description: 'Assembler un sort : type, valeurs, geste et effets.', icon: 'sort', upcoming: false },
  ];
  const visibleCards = () => cards.filter((c) => !senechal || c.family === 'monde');
  const allDrafts = [
    { editor: 'vava_gathering:zones', kind: 'zone', id: 'mine_val', title: 'Mine du Val', line: 'Zone en essai, vous seul la voyez en jeu', status: 'trial' },
    { editor: 'vava_gathering:zones', kind: 'zone', id: 'foret_brume', title: 'Forêt de Brume', line: '2 points ajoutés, pas encore publiés', status: 'draft' },
    { editor: 'vava_example_atelier:panneaux', kind: 'panneau', id: 'lanterne_du_port', title: 'Lanterne du port', line: 'Nouveau panneau, pas encore publié', status: 'draft' },
    { editor: 'vava_example_atelier:panneaux', kind: 'affiche', id: 'foire', title: 'Foire d\'automne', line: 'Retrait de l\'affiche, pas encore publié', status: 'draft' },
  ];
  const drafts = [
    { editor: 'vava_magic:sorts', kind: 'sort', id: 'flamme_bleue', title: 'Flamme bleue', line: 'Sort en essai, vous seul pouvez le lancer', status: 'trial' },
    { editor: 'vava_gathering:zones', kind: 'zone', id: 'foret_brume', title: 'Forêt de Brume', line: '2 points ajoutés, pas encore publiés', status: 'draft' },
  ];

  // Journal : 3 lignes de la maquette Main, puis des annotations pour la pagination -------------------------------
  const journal = [
    { id: 64, lead: 'A publié la station', title: 'Forge du bourg', actor: 'Sénéchal Aldric Morn', when: 'il y a 12 min', editor: 'vava_crafting:stations' },
    { id: 63, lead: 'A déplacé le puits', title: 'Puits communal', summary: 'de 4 m', actor: 'Sénéchal Aldric Morn', when: 'il y a 1 h', editor: 'vava_farming:parcelles' },
    { id: 62, lead: 'A enregistré le brouillon de la confrérie', title: 'La Garde d\'Eldoria', summary: 'grade Sergent ajouté', actor: 'Souveraine Ysolde', when: 'hier', editor: 'vava_guilds:confreries' },
  ];
  for (let i = 61; i >= 1; i -= 1) {
    const panel = i % 3 !== 0;
    journal.push({ id: i, lead: panel ? 'A annoté le panneau' : 'A annoté la proclamation', title: panel ? 'Panneau de la place' : 'Proclamation du couronnement',
      summary: `Note n° ${i}`, actor: 'Souveraine Ysolde', when: i > 40 ? 'il y a 3 jours' : 'le 12/10',
      editor: panel ? 'vava_example_atelier:panneaux' : 'vava_example_atelier:proclamations' });
  }

  // Descripteurs ----------------------------------------------------------------------------------------------------
  const PANNEAU_FORM = {
    titleField: 'titre',
    groups: [
      { id: 'ecrit', label: 'Ce qui est écrit', help: 'Ce que les passants liront en s\'approchant.' },
      { id: 'allure', label: 'Son allure' },
      { id: 'reglages', label: 'Réglages', folded: true },
    ],
    fields: [
      { id: 'titre', widget: 'text', label: 'Nom du panneau', help: 'Le nom que le Conseil verra dans ses listes.', group: 'ecrit', min: 3, max: 40, charset: 'name', default: '' },
      { id: 'texte', widget: 'text', label: 'Ce qui est écrit', help: 'Quelques lignes que les passants pourront lire.', group: 'ecrit', min: 0, max: 300, multiline: true, charset: 'free', optional: true, default: '' },
      { id: 'langue', widget: 'select', label: 'Langue', help: 'La langue des lettres ; tous ne savent pas lire les runes.', group: 'ecrit', options: [{ value: 'commun', label: 'Langue commune' }, { value: 'ancien', label: 'Ancien parler' }, { value: 'runes', label: 'Runes' }], default: 'commun' },
      { id: 'matiere', widget: 'segmented', label: 'Matière', help: 'Change l\'allure du panneau, pas ce qu\'il dit.', group: 'allure', options: [{ value: 'bois', label: 'Bois' }, { value: 'pierre', label: 'Pierre' }, { value: 'parchemin', label: 'Parchemin cloué' }], default: 'bois' },
      { id: 'quartier', widget: 'select', label: 'Quartier', help: 'Le quartier où le panneau se dresse.', group: 'allure', source: 'quartiers', default: 'marche' },
      { id: 'taille', widget: 'slider', label: 'Hauteur', help: 'Plus haut, il se voit de plus loin.', group: 'allure', min: 0.5, max: 3, step: 0.1, decimals: 1, unit: 'm', default: 1.5, width: 'half' },
      { id: 'portee', widget: 'slider', label: 'Distance de lecture', help: 'La distance d\'où l\'on peut encore le lire.', group: 'allure', min: 1, max: 10, step: 1, integer: true, unit: 'm', default: 3, width: 'half' },
      { id: 'modele', widget: 'model', label: 'Apparence', help: 'Le modèle utilisé en jeu.', group: 'allure', choices: [{ value: 'prop_sign_road_01a', label: 'Panneau de bois', provisional: true }, { value: 'prop_sign_road_03a', label: 'Pancarte de pierre', provisional: true }], default: 'prop_sign_road_01a' },
      { id: 'eclaire', widget: 'toggle', label: 'Éclairé la nuit', help: 'Une lanterne à son pied, allumée au crépuscule.', group: 'reglages', default: false },
      { id: 'duree', widget: 'duration', label: 'Reste affiché', help: 'Passé ce délai, le panneau est retiré.', group: 'reglages', min: 3600, max: 2592000, units: ['h', 'j'], default: 604800 },
      { id: 'offrande', widget: 'item', label: 'Objet au pied du panneau', help: 'Un objet posé là pour le décor : nul ne peut l\'emporter.', group: 'reglages', optional: true, default: '' },
    ],
  };
  const descriptors = {
    'vava_example_atelier:panneaux': {
      family: 'monde', label: 'Panneaux du bourg (exemple)', description: 'Exemple de développement : tous les réglages qu\'un atelier peut montrer.', icon: 'parchemin', order: 900,
      texts: { trial: 'Voir le panneau', publish: 'Dresser le panneau', publishHint: 'Dresser le panneau le rend lisible aux passants.' }, hasCompare: true,
      stored: true, hasTrial: true, format: 1,
      kinds: [
        { id: 'panneau', noun: 'panneau', nounPlural: 'panneaux', article: 'le', feminine: false, newLabel: 'Nouveau panneau', layout: 'page', creatable: true, placement: 'oriented', ghost: { field: 'modele' }, form: PANNEAU_FORM },
        { id: 'affiche', noun: 'affiche', nounPlural: 'affiches', article: 'l\'', feminine: true, newLabel: 'Nouvelle affiche', layout: 'side', creatable: true, parent: 'panneau',
          form: { titleField: 'titre', groups: {}, fields: [
            { id: 'titre', widget: 'text', label: 'Nom de l\'affiche', help: 'Ce qu\'annonce l\'affiche, en quelques mots.', min: 3, max: 40, charset: 'name', default: '' },
            { id: 'couleur', widget: 'segmented', label: 'Couleur', help: 'La teinte du papier, pour qu\'on la remarque.', options: [{ value: 'rouge', label: 'Rouge' }, { value: 'bleu', label: 'Bleu' }, { value: 'vert', label: 'Vert' }, { value: 'ocre', label: 'Ocre' }], default: 'ocre' },
            { id: 'duree', widget: 'duration', label: 'Reste affichée', help: 'Passé ce délai, l\'affiche est décrochée.', min: 3600, max: 604800, units: ['h', 'j'], default: 259200 },
          ] } },
        { id: 'enclos', noun: 'enclos', nounPlural: 'enclos', article: 'l\'', feminine: false, newLabel: 'Nouvel enclos', layout: 'side', creatable: true, placement: 'polygon', rules: { vertices: { min: 3, max: 32 } },
          form: { titleField: 'nom', groups: [], fields: [
            { id: 'nom', widget: 'text', label: 'Nom de l\'enclos', help: 'Le nom que donne /atelier_exemple lire à qui s\'y tient.', min: 3, max: 40, charset: 'name', default: '' },
          ] } },
        { id: 'borne', noun: 'borne', nounPlural: 'bornes', article: 'la', feminine: true, newLabel: 'Nouvelle borne', layout: 'side', creatable: false, parent: 'enclos', placement: 'point',
          rules: { inside: { slack: 0 }, spacing: 1 }, template: ['couleur'], autoTitle: 'couleur',
          ghost: { field: 'couleur', models: { rouge: { model: 'prop_roadcone02a', label: 'cône de GTA', provisional: true }, blanc: { model: 'prop_mp_cone_02', label: 'cône blanc de GTA', provisional: true } } },
          form: { titleField: 'nom', groups: [], fields: [
            { id: 'nom', widget: 'text', label: 'Nom de la borne', help: 'Donné tout seul à la pose (« Rouge 2 »).', min: 1, max: 40, charset: 'name', default: '' },
            { id: 'couleur', widget: 'segmented', label: 'Couleur', help: 'La couleur du cône, et son modèle.', options: [{ value: 'rouge', label: 'Rouge' }, { value: 'blanc', label: 'Blanc' }], default: 'rouge' },
          ] } },
      ],
    },
    'vava_example_atelier:proclamations': {
      family: 'societe', label: 'Proclamations (exemple)', description: 'Exemple de développement : un atelier réservé au Souverain.', icon: 'parchemin', order: 900,
      texts: { publish: 'Proclamer' }, hasCompare: false, stored: true, hasTrial: false, format: 1,
      kinds: [{ id: 'proclamation', noun: 'proclamation', nounPlural: 'proclamations', article: 'la', feminine: true, newLabel: 'Nouvelle proclamation', layout: 'page', creatable: true,
        form: { titleField: 'titre', groups: [], fields: [
          { id: 'titre', widget: 'text', label: 'Titre', help: 'Le titre crié par le héraut.', min: 3, max: 40, charset: 'name', default: '' },
          { id: 'texte', widget: 'text', label: 'Texte', help: 'Ce que le héraut lira sur la place.', min: 10, max: 300, multiline: true, charset: 'free', default: '' },
          { id: 'solennelle', widget: 'toggle', label: 'Solennelle', help: 'Les cloches sonnent avant la lecture.', default: true },
        ] } }],
    },
    // atelier de la récolte (spec T-102 § 5.5) : zone (cercle) et point (orienté, enfant d'une zone)
    'vava_gathering:zones': {
      family: 'monde', label: 'Récolte', description: 'Forêts, mines, prairies et coins de pêche, arbres et filons un par un.', icon: 'recolte', order: 10,
      texts: { trial: 'Tester la récolte', publish: 'Publier la zone', publishHint: 'Publier rend les nouveaux points visibles aux joueurs proches.', trialLine: 'Mode essai : vous seul voyez ces points' },
      hasCompare: false, stored: true, hasTrial: true, trialPlay: true, format: 1,
      kinds: [
        { id: 'zone', noun: 'zone', nounPlural: 'zones', article: 'la', feminine: true, newLabel: 'Nouvelle zone', layout: 'side', creatable: true, placement: 'circle', steps: ['La zone', 'Les points', 'Publier'],
          rules: { radius: { min: 10, max: 300, default: 60 } },
          form: { titleField: 'nom', groups: [{ id: 'terre', label: 'Réglages de la zone', folded: true, help: 'Type, rayon, vitesse à laquelle la terre se repose, durée d\'une cicatrice.' }], fields: [
            { id: 'nom', widget: 'text', label: 'Nom de la zone', help: 'Le nom que verront les récoltants sur la carte et dans le panneau des zones.', min: 3, max: 40, charset: 'name', default: '' },
            { id: 'genre', widget: 'segmented', label: 'Type de lieu', help: 'Donne l\'icône de la carte ; dans une zone d\'eau, on pêche et la terre devient l\'eau.', group: 'terre', options: [{ value: 'foret', label: 'Forêt' }, { value: 'mine', label: 'Mine' }, { value: 'prairie', label: 'Prairie' }, { value: 'eau', label: 'Eau' }], default: 'foret' },
            { id: 'fatigue', widget: 'slider', label: 'Fatigue par récolte', help: 'Vitalité (sur 100) que perd la zone à chaque récolte réussie : plus elle est haute, plus la terre s\'épuise vite.', group: 'terre', min: 0.5, max: 10, step: 0.5, decimals: 1, unit: 'pts', default: 2 },
            { id: 'repos', widget: 'slider', label: 'Repos de la terre', help: 'Vitalité que la terre regagne chaque heure quand on la laisse en paix.', group: 'terre', min: 0.5, max: 24, step: 0.5, decimals: 1, unit: 'pts/h', default: 4 },
            { id: 'cicatrice', widget: 'duration', label: 'Durée d\'une cicatrice', help: 'Une zone épuisée jusqu\'à zéro se remet bien plus lentement pendant ce temps.', group: 'terre', min: 3600, max: 2592000, units: ['h', 'j'], default: 172800 },
          ] } },
        { id: 'node', noun: 'point', nounPlural: 'points', article: 'le', feminine: false, newLabel: 'Nouveau point', layout: 'side', creatable: false, parent: 'zone', placement: 'oriented',
          rules: { inside: { slack: 5 }, spacing: 2 }, template: ['ressource', 'charges', 'repousse'], autoTitle: 'ressource', hintField: 'charges', hintFormat: '%s récoltes',
          ghost: { field: 'ressource', models: {
            chene: { model: 'prop_tree_oak_01', label: 'chêne de GTA', provisional: true }, pin: { model: 'prop_tree_pine_01', label: 'pin de GTA', provisional: true },
            fer: { model: 'prop_rock_1_a', label: 'rocher de GTA', provisional: true }, cuivre: { model: 'prop_rock_1_b', label: 'rocher de GTA', provisional: true },
            pierre: { model: 'prop_rock_1_c', label: 'rocher de GTA', provisional: true }, lavande: { model: 'prop_plant_01a', label: 'plante de GTA', provisional: true },
            sauge: { model: 'prop_plant_01b', label: 'plante de GTA', provisional: true }, truite: { model: 'prop_dock_float_1', label: 'flotteur de GTA', provisional: true },
          } },
          form: { titleField: 'nom', groups: [], fields: [
            { id: 'nom', widget: 'text', label: 'Nom du point', help: 'Pour le retrouver dans la liste ; donné tout seul à la pose (« Chêne 4 »).', min: 1, max: 40, charset: 'name', default: '' },
            { id: 'ressource', widget: 'select', label: 'Ressource', help: 'Ce que l\'on récolte ici : elle fixe l\'outil, l\'apparence et le savoir-faire.', source: 'ressources' },
            { id: 'charges', widget: 'slider', label: 'Récoltes avant repos', help: 'Combien de récoltes ce point donne avant de devoir repousser.', min: 1, max: 20, step: 1, integer: true, default: 3 },
            { id: 'repousse', widget: 'duration', label: 'Repousse d\'une récolte', help: 'Temps pour qu\'une récolte revienne ; la saison l\'accélère ou la ralentit.', min: 60, max: 86400, units: ['min', 'h'], default: 600 },
          ] } },
      ],
    },
  };
  function descriptorFor(editor) {
    if (descriptors[editor]) return descriptors[editor];
    const card = cards.find((c) => c.editor === editor && !c.upcoming);
    if (!card) return null;
    const station = editor === 'vava_crafting:stations';
    return { family: card.family, label: card.label, description: card.description, icon: card.icon, order: 10, texts: {}, hasCompare: false, stored: false, hasTrial: false,
      kinds: [{ id: station ? 'station' : 'fiche', noun: station ? 'station' : 'fiche', nounPlural: station ? 'stations' : 'fiches', article: 'la', feminine: true, newLabel: station ? 'Nouvelle station' : 'Nouvelle fiche', layout: 'side', creatable: true,
        form: { titleField: 'nom', groups: [], fields: [
          { id: 'nom', widget: 'text', label: 'Nom', help: 'Le nom affiché dans les listes du Conseil.', min: 3, max: 40, charset: 'name', default: '' },
          { id: 'portee', widget: 'slider', label: 'Portée', help: 'Distance à laquelle on peut s\'en servir.', min: 1, max: 10, step: 0.5, decimals: 1, unit: 'm', default: 2 },
        ] } }] };
  }

  // Entrées et valeurs ------------------------------------------------------------------------------------------------
  const entries = {
    'vava_example_atelier:panneaux|panneau': [
      { id: 'place_du_marche', title: 'Panneau de la place', hint: 'Le marché, bois', place: { x: -250, y: -930, z: 31.2, h: 90 }, values: { n: { taille: 1.5, portee: 3, duree: 604800 }, s: { titre: 'Panneau de la place', texte: 'Marché chaque jeudi, de l\'aube à la cloche de midi.\nLes étals se montent la veille.', langue: 'commun', matiere: 'bois', quartier: 'marche', offrande: 'pain', modele: 'prop_sign_road_01a' }, b: { eclaire: true } } },
      { id: 'porte_nord', title: 'Pancarte de la porte nord', hint: 'Les remparts, pierre', place: { x: -300, y: -870, z: 31, h: 0 }, values: { n: { taille: 2.2, portee: 5, duree: 2592000 }, s: { titre: 'Pancarte de la porte nord', texte: 'Fermeture des portes au couvre-feu.', langue: 'commun', matiere: 'pierre', quartier: 'remparts', offrande: '', modele: 'prop_sign_road_03a' }, b: { eclaire: false } } },
      { id: 'enseigne_port', title: 'Enseigne du port', hint: 'Le port, parchemin cloué', values: { n: { taille: 1.5, portee: 4, duree: 86400 }, s: { titre: 'Enseigne du port', texte: '', langue: 'runes', matiere: 'parchemin', quartier: 'port', offrande: '', modele: 'prop_sign_road_01a' }, b: { eclaire: false } }, warnings: ['taille'] },
    ],
    'vava_example_atelier:panneaux|affiche': [
      { id: 'foire', title: 'Foire d\'automne', hint: 'Ocre, 3 jours', values: { n: { duree: 259200 }, s: { titre: 'Foire d\'automne', couleur: 'ocre' } } },
    ],
    'vava_example_atelier:proclamations|proclamation': [
      { id: 'couronnement', title: 'Proclamation du couronnement', values: { s: { titre: 'Proclamation du couronnement', texte: 'Oyez, oyez : la Couronne sera remise au jour de la Saint-Aldric.' }, b: { solennelle: true } } },
    ],
    'vava_gathering:zones|zone': [
      { id: 'foret_brume', title: 'Forêt de Brume', hint: '5 points', place: { x: -480.5, y: 5520.2, z: 75.1, r: 120 }, values: { n: { fatigue: 2, repos: 4, cicatrice: 172800 }, s: { nom: 'Forêt de Brume', genre: 'foret' } } },
      { id: 'mine_val', title: 'Mine du Val', hint: '3 points', place: { x: 2950, y: 2780, z: 42.5, r: 60 }, values: { n: { fatigue: 3, repos: 2, cicatrice: 259200 }, s: { nom: 'Mine du Val', genre: 'mine' } } },
      { id: 'prairie_saules', title: 'Prairie des Saules', hint: '2 points', place: { x: 1900, y: 4850, z: 44, r: 90 }, values: { n: { fatigue: 1.5, repos: 6, cicatrice: 86400 }, s: { nom: 'Prairie des Saules', genre: 'prairie' } } },
      { id: 'etang_moulin', title: 'Étang du Moulin', hint: '2 points', place: { x: -190, y: 4220, z: 32, r: 40 }, values: { n: { fatigue: 2, repos: 4, cicatrice: 86400 }, s: { nom: 'Étang du Moulin', genre: 'eau' } } },
    ],
    // points de la Forêt de Brume (maquette Recolte) : quatre publiés, un cinquième nouveau (brouillon, voir seed)
    'vava_gathering:zones|node': [
      ['chene_1', 'Chêne 1', 'chene', 3, 0, 0], ['chene_2', 'Chêne 2', 'chene', 3, 6, 4], ['pin_1', 'Pin 1', 'pin', 4, 12, -3], ['chene_3', 'Chêne 3', 'chene', 3, -5, 9],
      ['chene_4', 'Chêne 4', 'chene', 3, 3, 14],
    ].map(([id, title, ressource, charges, dx, dy]) => ({ id, title, parent: 'foret_brume', place: { x: -480.5 + dx, y: 5520.2 + dy, z: 75.1, h: 90 },
      values: { n: { charges, repousse: 600 }, s: { nom: title, ressource } } })),
    'vava_example_atelier:panneaux|enclos': [
      { id: 'enclos_moutons', title: 'Enclos aux moutons', hint: '4 sommets', place: { z: 31, points: [{ x: -260, y: -940 }, { x: -240, y: -940 }, { x: -240, y: -920 }, { x: -260, y: -920 }] }, values: { s: { nom: 'Enclos aux moutons' } } },
    ],
    'vava_crafting:stations|station': [
      { id: 'forge_bourg', title: 'Forge du bourg', hint: 'Forge, place du marché', values: { n: { portee: 2 }, s: { nom: 'Forge du bourg' } } },
      { id: 'etabli_port', title: 'Établi du port', hint: 'Établi', values: { n: { portee: 1.5 }, s: { nom: 'Établi du port' } } },
    ],
  };
  const districts = [{ value: 'marche', label: 'Le marché' }, { value: 'remparts', label: 'Les remparts' }, { value: 'port', label: 'Le port' }, { value: 'chateau', label: 'Le château' }];
  const items = ['Pain', 'Pomme', 'Fromage', 'Miche de seigle', 'Ragoût de lièvre', 'Potion de soin', 'Lingot de fer', 'Lingot de cuivre', 'Charbon', 'Cuir', 'Épée courte',
    'Marteau de forge', 'Talisman', 'Veste de cuir', 'Anneau de cuivre', 'Bûche de chêne', 'Planche de pin', 'Corde de chanvre', 'Lanterne', 'Bougie', 'Parchemin vierge',
    'Encre', 'Plume d\'oie', 'Sac de grain', 'Graines de blé', 'Graines d\'orge', 'Herbe de lune', 'Racine amère', 'Champignon des bois', 'Truite', 'Saumon', 'Hameçon',
    'Filet de pêche', 'Pioche', 'Hache', 'Faucille', 'Seau', 'Cruche d\'eau', 'Vin de pays', 'Bière d\'orge']
    .map((label) => ({ value: fold(label).replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, ''), label, image: `nui://vava_inventory/web/items/${fold(label).replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '')}.webp` }));

  const resources = [['chene', 'Chêne'], ['pin', 'Pin'], ['fer', 'Filon de fer'], ['cuivre', 'Filon de cuivre'], ['pierre', 'Pierre'], ['lavande', 'Lavande'], ['sauge', 'Sauge'], ['truite', 'Banc de truites']]
    .map(([value, label]) => ({ value, label }));
  const OPTIONS = { quartier: districts, offrande: items, ressource: resources };
  const optionsOf = (fieldId) => OPTIONS[fieldId] || [];

  /** `labels` de read : { [champ] = { label, image?, provisional? } } pour chaque champ à liste distante dont la valeur est connue. */
  function labelsOf(kind, values) {
    const labels = {};
    for (const field of kind ? kind.form.fields : []) {
      const value = (values.s || {})[field.id];
      if (!value || !(field.widget === 'item' || field.source)) continue;
      const found = optionsOf(field.id).find((o) => o.value === value);
      if (found) labels[field.id] = { label: found.label, image: found.image };
    }
    return labels;
  }

  // Règles de l'exemple (comme shared/rules.lua de vava_example_atelier) --------------------------------------------
  function validatePanel(id, data) {
    const errors = [];
    const name = fold(String(data.s.titre || '').trim());
    if ((entries['vava_example_atelier:panneaux|panneau'] || []).some((e) => e.id !== id && fold(e.title) === name)) errors.push({ field: 'titre', text: 'Un panneau porte déjà ce nom.' });
    if (data.b.eclaire === true && Number(data.n.duree) < 86400) errors.push({ field: 'duree', text: 'Un panneau éclairé reste au moins un jour : la lanterne doit valoir la peine.' });
    if (data.s.langue === 'runes' && Array.from(String(data.s.texte || '')).length > 120) errors.push({ field: 'texte', text: 'Les runes se gravent lentement : 120 caractères au plus.' });
    return errors;
  }

  // Débit simulé de « Vérifier » (capacité 5, une par seconde)
  let tokens = 5, refilled = Date.now();
  function spend() {
    const now = Date.now();
    tokens = Math.min(5, tokens + (now - refilled) / 1000);
    refilled = now;
    if (tokens < 1) return false;
    tokens -= 1;
    return true;
  }

  // Étiquettes des cartes : hors du contenu gardé, recalculées à chaque réponse d'accueil (comme le serveur)
  function tagsOf() {
    const count = (key, noun, plural) => { const n = (entries[key] || []).length; return { text: `${n} ${n > 1 ? plural : noun}`, tone: 'count' }; };
    const tags = {
      'vava_gathering:zones': count('vava_gathering:zones|zone', 'zone', 'zones'),
      'vava_example_atelier:panneaux': count('vava_example_atelier:panneaux|panneau', 'panneau', 'panneaux'),
      'vava_example_atelier:proclamations': count('vava_example_atelier:proclamations|proclamation', 'proclamation', 'proclamations'),
      'vava_magic:sorts': { text: '1 en essai', tone: 'trial' },
    };
    if (manyDrafts) tags['vava_gathering:zones'] = { text: '1 en essai', tone: 'trial' };
    for (const editor of Object.keys(tags)) if (!visibleCards().some((c) => c.editor === editor)) delete tags[editor];
    return tags;
  }

  // Cycle de vie (comme server/lifecycle.lua) : une fiche = publiée (values de `entries`) + brouillon éventuel ----------
  const ME = 'Souveraine Ysolde', OTHER = 'Sénéchal Aldric Morn';
  const life = new Map();
  const removedList = [];
  const listOf = (editor, kind) => (entries[`${editor}|${kind}`] = entries[`${editor}|${kind}`] || []);
  const findEntry = (editor, kind, id) => listOf(editor, kind).find((e) => e.id === id);
  function lifeOf(editor, kind, id) {
    const key = `${editor}|${kind}|${id}`;
    if (!life.has(key)) {
      const entry = findEntry(editor, kind, id);
      const gone = entry ? null : removedList.find((r) => r.key === key);
      const first = { version: 1, status: gone ? 'archived' : 'published', origin: 'seed', author: 'Console', when: 'le 12/10', values: clone((entry || gone || {}).values || {}) };
      life.set(key, { version: gone ? 2 : 1, draft: null, versions: gone ? [{ ...first, version: 2, removal: 1, origin: 'atelier', author: OTHER, when: gone.removedHint }, first] : [first] });
    }
    return life.get(key);
  }
  const B = (id, label, more) => ({ id, label, ...more });
  const LINK = { link: true };
  function footerOf(descriptor, l) {
    const t = descriptor.texts || {}, d = l.draft;
    if (!descriptor.stored) return [B('check', 'Vérifier', { primary: true })];
    if (!d) return [B('save', 'Enregistrer le brouillon', { primary: true }), B('history', 'Historique', LINK), B('retire', 'Retirer du royaume', LINK), B('check', 'Vérifier', LINK)];
    if (!d.mine) return [B('take', 'Reprendre le brouillon', { primary: true }), B('history', 'Historique', LINK)];
    if (d.removal) return [B('publish', 'Publier le retrait', { primary: true }), B('history', 'Historique', LINK), B('discard', 'Renoncer au retrait', LINK)];
    if (d.trial) return [B('save', 'Enregistrer le brouillon'), B('endTrial', 'Arrêter l\'essai'), B('publish', t.publish, { primary: true }), B('history', 'Historique', LINK), B('discard', 'Abandonner le brouillon', LINK)];
    return [B('save', 'Enregistrer le brouillon'), descriptor.hasTrial ? B('trial', t.trial) : null, B('publish', t.publish, { primary: true }),
      B('history', 'Historique', LINK), B('discard', 'Abandonner le brouillon', LINK), B('check', 'Vérifier', LINK)].filter(Boolean);
  }
  function stateOf(l) {
    const d = l.draft;
    if (!d) return l.refused ? { label: 'Publiée, mais refusée en jeu', tone: 'refused' } : { label: `Version ${l.version}, publiée`, tone: 'live' };
    if (d.removal) return { label: 'Retrait en attente', tone: 'removal' };
    if (d.trial) return { label: `Essai, version ${l.version + 1}`, tone: 'trial' };
    return { label: 'Brouillon', tone: 'draft' };
  }
  function hintOf(editor, kind, entry) {
    const d = lifeOf(editor, kind, entry.id).draft;
    if (!d) return { hint: entry.hint };
    if (d.removal) return { hint: 'Retrait en attente', tone: 'removal' };
    if (d.trial) return { hint: 'En essai', tone: 'trial' };
    if (!d.mine) return { hint: `Brouillon de ${OTHER}`, tone: 'draft' };
    return { hint: d.fresh ? 'Jamais publié' : 'Votre brouillon', tone: d.fresh ? 'new' : 'draft' };
  }
  function banner(editor, trial) {
    const descriptor = descriptorFor(editor);
    const line = trial ? (descriptor.texts.trialLine || 'Mode essai : vous seul voyez ce changement en jeu') : 'Mode édition : visible par vous seul';
    window.postMessage({ action: 'mode', payload: { banner: { title: descriptor.label, line } } }, '*');
  }
  function slug(editor, kind, title, noun) {
    const base = fold(title).replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 40) || fold(noun);
    let id = base;
    for (let n = 2; findEntry(editor, kind, id) || removedList.some((r) => r.id === id); n += 1) id = `${base}_${n}`;
    return id;
  }
  const TOKEN = '0123456789abcdef';
  function changesOf(kindDef, before, after) {
    const fields = kindDef.form.fields.filter((f) => JSON.stringify(valueOf(before, f.id)) !== JSON.stringify(valueOf(after, f.id)));
    if (fields.length === 0) return [];
    if (fields.length === 1 && fields[0].id === 'texte') return ['Texte repeint'];
    return [`Retouché : ${fields.map((f) => f.label).join(', ')}`];
  }
  function valueOf(values, id) {
    for (const map of ['n', 's', 'b']) if (values && values[map] && id in values[map]) return values[map][id];
    return undefined;
  }
  function publishLines(editor, kind, l, entry) {
    const kindDef = descriptorFor(editor).kinds.find((k) => k.id === kind);
    if (l.draft.removal) return [`Retrait ${kind === 'panneau' ? 'du panneau' : 'de l\'affiche'}`, `La version ${l.version} sera archivée.`];
    const lines = l.version === 0 ? [] : changesOf(kindDef, entry.values, l.draft.values);
    if (what === 'publish' && kind === 'panneau') lines.push('1 affiche ajoutée');
    lines.push(l.version === 0 ? 'Ce sera la version 1.' : `La version ${l.version} sera archivée ; celle-ci deviendra la version ${l.version + 1}.`);
    return lines;
  }
  function readAnswer(editor, kind, entry, l) {
    const kindDef = (descriptorFor(editor) || { kinds: [] }).kinds.find((k) => k.id === kind);
    const values = l.draft ? l.draft.values : entry.values;
    const answer = { id: entry.id, title: valueOf(values, kindDef.form.titleField) || entry.title, values: clone(values), labels: labelsOf(kindDef, values), warnings: entry.warnings,
      state: stateOf(l), footer: footerOf(descriptorFor(editor), l), rev: l.draft ? l.draft.rev : 0, version: l.version, removal: Boolean(l.draft && l.draft.removal), stale: Boolean(l.draft && l.draft.stale),
      place: entry.place ? clone(entry.place) : undefined, parent: entry.parent, distance: entry.place ? (entry.parent ? 4 : 32) : undefined };
    if (l.draft && !l.draft.mine) {
      answer.holder = { label: OTHER, mine: false };
      answer.state.line = `Brouillon de ${OTHER}, enregistré il y a 3 min`;
    }
    else if (l.draft) answer.holder = { label: ME, mine: true };
    if (editor === 'vava_example_atelier:panneaux' && kind === 'panneau') {
      answer.compare = entry.id === 'porte_nord' ? { title: 'Pour comparer : Panneau de la place', text: '1,5 m, lisible à 3 m, 7 jours' } : { title: 'Pour comparer : Pancarte de la porte nord', text: '2,2 m, lisible à 5 m, 30 jours' };
    }
    return answer;
  }
  // un retrait remet la fiche à part, un rétablissement la rend à sa liste
  function removeEntry(editor, kind, id) {
    const all = listOf(editor, kind), index = all.findIndex((e) => e.id === id);
    if (index >= 0) removedList.unshift({ key: `${editor}|${kind}|${id}`, editor, kind, ...all.splice(index, 1)[0], removedHint: 'retiré à l\'instant' });
  }
  function bringBack(editor, kind, id) {
    const index = removedList.findIndex((r) => r.key === `${editor}|${kind}|${id}`);
    if (index >= 0) { const r = removedList.splice(index, 1)[0]; listOf(editor, kind).push({ id: r.id, title: r.title, hint: r.hint, values: r.values }); }
  }

  // Situations de départ des écrans (§ 9.5 de T-101)
  function seed() {
    const G = 'vava_gathering:zones';
    lifeOf(G, 'zone', 'foret_brume').draft = { values: clone(findEntry(G, 'zone', 'foret_brume').values), rev: 3, mine: true };
    life.set(`${G}|node|chene_4`, { version: 0, draft: { values: clone(findEntry(G, 'node', 'chene_4').values), rev: 1, mine: true, fresh: true }, versions: [] });
    if (params.get('step') === '1') {
      listOf(G, 'zone').push({ id: 'bois_des_essais', title: 'Bois des Essais', hint: '', values: { n: { fatigue: 2, repos: 4, cicatrice: 172800 }, s: { nom: 'Bois des Essais', genre: 'foret' } } });
      life.set(`${G}|zone|bois_des_essais`, { version: 0, draft: { values: clone(findEntry(G, 'zone', 'bois_des_essais').values), rev: 1, mine: true, fresh: true }, versions: [] });
    }
    const P = 'vava_example_atelier:panneaux';
    const place = findEntry(P, 'panneau', 'place_du_marche');
    const v = (text) => { const values = clone(place.values); values.s.texte = text; return values; };
    life.set(`${P}|panneau|place_du_marche`, { version: 6, draft: null, versions: [
      { version: 6, status: 'published', origin: 'atelier', summary: 'Hauteur de 1,5 m à 2 m', author: ME, when: 'il y a 2 h', values: clone(place.values) },
      { version: 5, status: 'archived', origin: 'atelier', summary: 'Texte repeint', author: OTHER, when: 'hier', values: v('Marché chaque jeudi, de l\'aube à midi.') },
      { version: 4, status: 'archived', origin: 'restore', restoredFrom: 2, summary: 'version 2 rétablie', author: ME, when: 'il y a 3 jours', values: v('Marché le jeudi.') },
      { version: 3, status: 'archived', removal: 1, summary: 'et ses 2 affiches', author: OTHER, when: 'il y a 4 jours', values: v('Marché le jeudi.') },
      { version: 2, status: 'archived', origin: 'atelier', summary: 'Texte repeint', author: OTHER, when: 'le 14/10', values: v('Marché le jeudi.') },
      { version: 1, status: 'archived', origin: 'seed', author: 'Console', when: 'le 12/10', values: v('Marché.') },
    ] });
    const l = lifeOf(P, 'panneau', 'place_du_marche');
    if (scene === 'draft' || scene === 'stale' || ['publish', 'discard'].includes(what) || params.get('changed') === '1') {
      l.draft = { values: v('Marché chaque jeudi, de l\'aube à la cloche de midi.\nFoire d\'automne le premier jeudi d\'octobre.'), rev: 3, mine: true, stale: scene === 'stale' };
    }
    if (scene === 'trial') lifeOf(P, 'affiche', 'foire').draft = { values: clone(findEntry(P, 'affiche', 'foire').values), rev: 2, mine: true, trial: true };
    const north = lifeOf(P, 'panneau', 'porte_nord');
    if (scene === 'other' || what === 'take') north.draft = { values: clone(findEntry(P, 'panneau', 'porte_nord').values), rev: 4, mine: false };
    if (scene === 'removal') north.draft = { values: clone(findEntry(P, 'panneau', 'porte_nord').values), rev: 1, mine: true, removal: true };
    for (const [id, title, hint] of [['halle_aux_grains', 'Halle aux grains', 'retiré il y a 3 jours'], ['vieux_pont', 'Panneau du vieux pont', 'retiré il y a 2 semaines'], ['puits_sec', 'Puits asséché', 'retiré le 02/10']]) {
      removedList.push({ key: `${P}|panneau|${id}`, editor: P, kind: 'panneau', id, title, hint: 'Le marché, bois', removedHint: hint, values: clone(place.values) });
    }
  }

  function lifecycle(name, data) {
    const descriptor = descriptorFor(data.editor);
    if (!descriptor) return fail('unknown_editor');
    if (!descriptor.stored) return fail('not_stored');
    const kindDef = descriptor.kinds.find((k) => k.id === data.kind);
    if (!kindDef) return fail('unknown_kind');
    if (name === 'removed') {
      const rows = removedList.filter((r) => r.editor === data.editor && r.kind === data.kind);
      return ok({ total: rows.length, page: 1, pages: 1, entries: rows.map((r) => ({ id: r.id, title: r.title, hint: r.removedHint })) });
    }
    if (name === 'save' && !data.id) {
      const values = { n: data.values.n || {}, s: data.values.s || {}, b: data.values.b || {} };
      const title = String(valueOf(values, kindDef.form.titleField) || '').trim();
      const id = slug(data.editor, data.kind, title, kindDef.noun);
      listOf(data.editor, data.kind).push({ id, title, hint: '', values });
      const l = { version: 0, draft: { values, rev: 1, mine: true, fresh: true }, versions: [] };
      life.set(`${data.editor}|${data.kind}|${id}`, l);
      return ok({ done: true, id, rev: 1, title, state: stateOf(l), footer: footerOf(descriptor, l) });
    }
    const entry = findEntry(data.editor, data.kind, data.id) || removedList.find((r) => r.key === `${data.editor}|${data.kind}|${data.id}`);
    if (!entry) return fail('unknown_entry');
    const l = lifeOf(data.editor, data.kind, data.id), d = l.draft;
    const answer = (more) => ok({ done: true, rev: l.draft ? l.draft.rev : 0, state: stateOf(l), footer: footerOf(descriptor, l), ...more });
    const holding = (rev = data.rev) => (!d ? 'no_draft' : (!d.mine ? 'not_holder' : (d.rev !== rev ? 'stale' : '')));
    switch (name) {
      case 'save': {
        if (d && !d.mine) return fail('draft_taken');
        if (d && d.rev !== data.rev) return fail('stale');
        const values = { n: data.values.n || {}, s: data.values.s || {}, b: data.values.b || {} };
        if (d) Object.assign(d, { values, rev: d.rev + 1 }); else l.draft = { values, rev: 1, mine: true };
        if (l.draft.trial) banner(data.editor, true);
        const warnings = data.kind === 'panneau' ? validatePanel(data.id, values) : [];
        return answer({ id: data.id, title: String(valueOf(values, kindDef.form.titleField) || entry.title), warnings });
      }
      case 'trial': {
        if (!descriptor.hasTrial) return fail('no_trial');
        if (holding()) return fail(holding());
        d.trial = true;
        banner(data.editor, true);
        return answer({ children: 0 });
      }
      case 'endTrial':
        if (!d || !d.trial) return fail('no_draft');
        d.trial = false;
        banner(data.editor, false);
        return answer({});
      case 'preview': {
        if (data.what === 'restore') {
          const v = l.versions.find((x) => x.version === data.ref);
          if (!v) return fail('unknown_version');
          if (v.status !== 'archived' || v.removal) return fail('not_archived');
          return ok({ title: entry.title, lines: [`La version ${v.version} sera rétablie et deviendra la version ${l.version + 1}.`], warnings: [], token: TOKEN, valid: true });
        }
        if (holding(data.ref)) return fail(holding(data.ref));
        if (forceErrors) {
          forceErrors = false;
          return ok({ title: entry.title, lines: [], warnings: [], token: TOKEN, valid: false, errors: [
            { field: 'titre', text: 'Un panneau porte déjà ce nom.' }, { text: 'Le port est fermé aux nouveaux panneaux pendant la foire d\'automne.' }] });
        }
        const warnings = what === 'publish' ? ['La pancarte de la porte nord est à moins de 5 m : les passants confondront les deux.'] : [];
        return ok({ title: entry.title, lines: publishLines(data.editor, data.kind, l, entry), warnings, token: TOKEN, valid: true });
      }
      case 'publish': {
        if (holding()) return fail(holding());
        if (data.token !== TOKEN) return fail('stale');
        if (d.trial) banner(data.editor, false);
        for (const v of l.versions) if (v.status === 'published') v.status = 'archived';
        l.version += 1;
        l.versions.unshift({ version: l.version, status: d.removal ? 'archived' : 'published', removal: d.removal ? 1 : 0, origin: 'atelier', summary: d.removal ? '' : 'Texte repeint', author: ME, when: 'à l\'instant', values: clone(d.values) });
        if (d.removal) removeEntry(data.editor, data.kind, data.id); else entry.values = clone(d.values);
        l.draft = null;
        return answer({ version: l.version });
      }
      case 'restore': {
        const v = l.versions.find((x) => x.version === data.version);
        if (!v || v.status !== 'archived' || v.removal) return fail('not_archived');
        for (const x of l.versions) if (x.status === 'published') x.status = 'archived';
        l.version += 1;
        l.versions.unshift({ version: l.version, status: 'published', origin: 'restore', restoredFrom: v.version, summary: `version ${v.version} rétablie`, author: ME, when: 'à l\'instant', values: clone(v.values) });
        bringBack(data.editor, data.kind, data.id);
        findEntry(data.editor, data.kind, data.id).values = clone(v.values);
        return answer({ version: l.version });
      }
      case 'discard':
        if (holding()) return fail(holding());
        if (d.trial) banner(data.editor, false);
        l.draft = null;
        if (d.fresh) { listOf(data.editor, data.kind).splice(listOf(data.editor, data.kind).indexOf(entry), 1); return ok({ done: true, gone: true }); }
        return answer({});
      case 'retire':
        if (d && !d.mine) return fail('draft_taken');
        if (d && d.fresh) return lifecycle('discard', { ...data, rev: d.rev });
        if (d) return fail('draft_open');
        l.draft = { values: clone(entry.values), rev: 1, mine: true, removal: true };
        return answer({});
      case 'take':
        if (!d || d.mine) return fail('no_draft');
        if (d.rev !== data.rev) return fail('stale');
        Object.assign(d, { mine: true, rev: d.rev + 1, trial: false });
        return answer({});
      case 'history': {
        const older = l.versions.filter((v) => !data.before || v.version < data.before);
        return ok({ versions: older.slice(0, 5).map((v) => ({ version: v.version, status: v.status, removal: v.removal || 0, restoredFrom: v.restoredFrom, summary: v.summary, author: v.author, when: v.when })), more: older.length > 5 });
      }
      case 'version': {
        const v = l.versions.find((x) => x.version === data.version);
        if (!v) return fail('unknown_version');
        const archived = v.status === 'archived';
        return ok({ id: data.id, title: valueOf(v.values, kindDef.form.titleField) || entry.title, version: v.version, values: clone(v.values), labels: labelsOf(kindDef, v.values),
          state: v.removal ? { label: `Version ${v.version}, retrait`, tone: 'removal' } : (archived ? { label: `Version ${v.version}, archivée`, tone: 'archived' } : { label: `Version ${v.version}, publiée`, tone: 'live' }),
          footer: archived && !v.removal ? [B('restore', 'Revenir à cette version', { primary: true })] : [] });
      }
      default: return fail('invalid_args');
    }
  }

  const sentDescriptors = new Set();
  let homeSent = false;
  const ok = (data) => ({ ok: true, data });
  const REFUSED = {
    not_allowed: 'L\'Atelier est réservé au Conseil.', unknown_editor: 'Cet atelier n\'existe plus.', unknown_kind: 'Ce genre de fiche n\'existe plus dans cet atelier.',
    unknown_entry: 'Cette fiche n\'existe plus.', rate_limited: 'Doucement : patientez un instant.',
    stale: 'Cette fiche a changé depuis que vous l\'avez ouverte : rouvrez-la pour voir la dernière version.',
    draft_taken: 'Un autre membre du Conseil tient déjà un brouillon de cette fiche : ouvrez-le pour le lire ou le reprendre.',
    draft_open: 'Vous avez déjà un brouillon de cette fiche : abandonnez-le d\'abord.', not_holder: 'Ce brouillon est tenu par un autre membre du Conseil.',
    no_draft: 'Cette fiche n\'a pas de brouillon en cours.', not_stored: 'Cet atelier ne garde encore rien : on peut seulement y vérifier une fiche.',
    no_trial: 'Cet atelier ne propose pas d\'essai.', unknown_version: 'Cette version n\'existe plus.', not_archived: 'Seule une ancienne version peut être rétablie.',
  };
  REFUSED.busy = 'Un instant…';
  const fail = (error) => ({ ok: false, error, text: REFUSED[error] || '' });

  // Placement (T-102) : lieux des fiches, visée simulée (clic : poser ; clic droit : choisir ; Entrée : fermer un tracé ;
  // Échap : quitter), essai joué (F9 : revenir). Le jeu dessine l'aperçu ; ici, rien d'autre que les messages de § 9.2.
  const post = (action, payload) => window.postMessage({ action, payload }, '*');
  const K = (keys, label) => ({ keys, label });
  let aim = null, suspended = false, clicks = 0;
  function keysFor(p) {
    const undo = K(['Ctrl', 'Z'], 'Annuler'), quit = K(['Échap'], 'Quitter');
    if (p.shape === 'polygon') return [K(['Clic'], 'Ajouter un sommet'), K(['Entrée'], 'Fermer le tracé'), K(['Clic droit'], 'Choisir un sommet'), K(['Ctrl', 'Z'], 'Retirer le dernier'), quit];
    if (p.mode === 'children') return [K(['Clic'], p.picked ? 'Déplacer ici' : 'Poser ici'), K(['Molette'], 'Tourner'), K(['Maj'], 'Placement précis'), K(['Clic droit'], p.picked ? 'Lâcher le point' : 'Choisir un point'), undo, quit];
    if (p.shape === 'circle') return [K(['Clic'], 'Poser ici'), K(['Molette'], 'Rayon'), K(['Maj'], 'Réglage fin'), undo, quit];
    return [K(['Clic'], 'Poser ici')].concat(p.shape === 'oriented' ? [K(['Molette'], 'Tourner'), K(['Maj'], 'Placement précis')] : [], [undo, quit]);
  }
  const showAim = () => post('placing', { on: true, mode: aim.mode, shape: aim.shape, keys: keysFor(aim) });
  function stopAim() { if (aim) { aim = null; post('placing', { on: false }); } }
  function rowOf(editor, kind, e) {
    const d = lifeOf(editor, kind.id, e.id).draft;
    const tone = !d ? 'live' : (d.removal ? 'removal' : (!d.mine ? 'other' : (d.fresh ? 'new' : 'draft')));
    const n = valueOf((d || e).values, kind.hintField);
    return { kind: kind.id, id: e.id, title: e.title, hint: kind.hintFormat && n !== undefined ? kind.hintFormat.replace('%s', n) : '', tone, place: clone(e.place || {}) };
  }
  function childrenOf(data) {
    const descriptor = descriptorFor(data.editor), kindDef = descriptor && descriptor.kinds.find((k) => k.id === data.kind);
    const entry = kindDef && findEntry(data.editor, data.kind, data.id);
    if (!entry) return fail('unknown_entry');
    const rows = (k, parentId) => listOf(data.editor, k.id).filter((e) => e.parent === parentId).map((e) => rowOf(data.editor, k, e));
    const child = descriptor.kinds.find((k) => k.parent === kindDef.id && k.placement);
    if (child) return ok({ self: { place: entry.place, distance: 32 }, rows: rows(child, entry.id) });
    const parentKind = descriptor.kinds.find((k) => k.id === kindDef.parent);
    const parent = parentKind && findEntry(data.editor, parentKind.id, entry.parent);
    return ok({ self: { place: entry.place, distance: 4 }, parent: parent ? { kind: parentKind.id, id: parent.id, title: parent.title, place: parent.place } : undefined,
      rows: parent ? rows(kindDef, parent.id).filter((r) => r.id !== entry.id) : [] });
  }
  /** Brouillon tenu (révision montée si `bump`) ou créé (copie de la publiée) ; vrai s'il vient d'être créé. */
  function hold(editor, kind, id, bump) {
    const l = lifeOf(editor, kind, id);
    if (l.draft) { if (bump) l.draft.rev += 1; return false; }
    l.draft = { values: clone(findEntry(editor, kind, id).values), rev: 1, mine: true };
    return true;
  }
  function pose() {
    const descriptor = descriptorFor(aim.editor), kindDef = descriptor.kinds.find((k) => k.id === aim.kind);
    clicks += 1;
    if (aim.mode === 'children') {
      if (clicks % 3 === 0) { post('placeRefused', { text: 'Trop près de « Chêne 2 » (1,4 m).' }); return; }
      const all = listOf(aim.editor, aim.kind), parent = findEntry(aim.editor, kindDef.parent, aim.parent);
      const label = aim.label || kindDef.noun;
      let n = 1;
      while (all.some((e) => e.parent === aim.parent && e.title === `${label} ${n}`)) n += 1;
      const id = slug(aim.editor, aim.kind, `${label} ${n}`, kindDef.noun);
      const values = { n: { ...(aim.template.n || {}) }, s: { ...(aim.template.s || {}), [kindDef.form.titleField]: `${label} ${n}` }, b: { ...(aim.template.b || {}) } };
      const e = { id, title: `${label} ${n}`, parent: aim.parent, place: { ...(parent.place.points ? { x: parent.place.points[0].x + 2, y: parent.place.points[0].y + 2 } : { x: parent.place.x + 4 * n, y: parent.place.y - 3 }), z: parent.place.z, h: 90 }, values };
      if (kindDef.placement !== 'oriented') delete e.place.h;
      all.push(e);
      const l = { version: 0, draft: { values, rev: 1, mine: true, fresh: true }, versions: [] };
      life.set(`${aim.editor}|${aim.kind}|${id}`, l);
      const created = hold(aim.editor, kindDef.parent, aim.parent), pl = lifeOf(aim.editor, kindDef.parent, aim.parent);
      post('placed', { kind: aim.kind, id, rev: 1, title: e.title, state: stateOf(l), footer: footerOf(descriptor, l), place: e.place, row: rowOf(aim.editor, kindDef, e),
        parent: created ? { id: aim.parent, rev: pl.draft.rev, state: stateOf(pl), footer: footerOf(descriptor, pl) } : undefined });
      return;
    }
    if (aim.shape === 'polygon') { aim.vertices = (aim.vertices || 0) + 1; return; }
    const entry = findEntry(aim.editor, aim.kind, aim.id);
    entry.place = aim.shape === 'circle' ? (entry.place ? { ...entry.place, x: entry.place.x + 12, r: entry.place.r + 20 } : { x: -400, y: 5400, z: 70, r: kindDef.rules.radius.default })
      : { x: -248, y: -927, z: 31.2, ...(aim.shape === 'oriented' ? { h: 130 } : {}) };
    placedSelf(descriptor, entry);
  }
  function placedSelf(descriptor, entry) {
    hold(aim.editor, aim.kind, aim.id, true);
    const l = lifeOf(aim.editor, aim.kind, aim.id);
    post('placed', { kind: aim.kind, id: aim.id, rev: l.draft.rev, title: entry.title, state: stateOf(l), footer: footerOf(descriptor, l), place: clone(entry.place), distance: 3 });
    stopAim();   // fiche seule : retour au volet après la pose
  }
  function closeTrace() {
    if (!aim || aim.shape !== 'polygon' || (aim.vertices || 0) < 3) return;
    const entry = findEntry(aim.editor, aim.kind, aim.id), n = aim.vertices;
    entry.place = { z: 31, points: Array.from({ length: n }, (_, i) => ({ x: -250 + 12 * Math.cos((2 * Math.PI * i) / n), y: -930 + 12 * Math.sin((2 * Math.PI * i) / n) })) };
    placedSelf(descriptorFor(aim.editor), entry);
  }
  if (!inGame) {
    document.addEventListener('mousedown', (event) => { if (aim && !event.target.closest('#side, #banner, #toast')) { if (event.button === 2 && aim.mode === 'children') { aim.picked = !aim.picked; showAim(); } else if (event.button === 0) pose(); } });
    document.addEventListener('contextmenu', (event) => { if (aim) event.preventDefault(); });
    document.addEventListener('keydown', (event) => {
      if (aim && event.key === 'Escape') stopAim();
      else if (aim && event.key === 'Enter') closeTrace();
      else if (suspended && event.key === 'F9') { suspended = false; post('suspended', { on: false }); }
    });
  }
  function placing(name, data) {
    switch (name) {
      case 'children': return childrenOf(data);
      case 'placeStart':
        if (aim) return fail('busy');
        aim = { ...data, template: data.template || {} };
        clicks = 0;
        showAim();
        return { ok: true };
      case 'placeStop': aim = null; return { ok: true };
      case 'suspend': suspended = true; setTimeout(() => post('suspended', { on: true }), 50); return { ok: true };
      default: return { ok: true };   // templateChanged, goTo : rien à simuler
    }
  }

  function homePayload(version) {
    const withContent = version !== 'accueil-1' || !homeSent;
    homeSent = true;
    return {
      version: 'accueil-1',
      content: withContent ? { families: clone(families), cards: clone(visibleCards()), footnote: 'Chaque atelier n\'apparaît qu\'aux rangs qui y ont droit. Un Sénéchal ne voit que le monde ; un Souverain voit tout.' } : undefined,
      tags: tagsOf(),
      drafts: empty ? [] : clone(manyDrafts ? allDrafts : drafts),
      journal: empty ? [] : clone(journal.filter((l) => !senechal || visibleCards().some((c) => c.editor === l.editor)).slice(0, 5)),
      rank: senechal ? 'Sénéchal' : 'Souveraine',
      closeKey: 'F9',
    };
  }

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 60));
    const visible = (editor) => visibleCards().some((c) => c.editor === editor && !c.upcoming);
    switch (name) {
      case 'home': return ok(homePayload(data.version));
      case 'stale': sentDescriptors.clear(); homeSent = false; return { ok: true };
      case 'close': return { ok: true };
      case 'editor': {
        if (!visible(data.editor)) return fail(cards.some((c) => c.editor === data.editor) ? 'not_allowed' : 'unknown_editor');
        const descriptor = descriptorFor(data.editor);
        const first = !sentDescriptors.has(data.editor);
        sentDescriptors.add(data.editor);
        return ok({ version: `${data.editor}-1`, descriptor: first ? clone(descriptor) : undefined });
      }
      case 'list': {
        const all = entries[`${data.editor}|${data.kind}`] || [];
        const q = fold(data.query);
        const found = all.filter((e) => !q || fold(e.title).includes(q)).sort((a, b) => fold(a.title).localeCompare(fold(b.title)));
        const pages = Math.max(1, Math.ceil(found.length / 50));
        const page = Math.min(pages, data.page || 1);
        return ok({ total: found.length, page, pages, entries: found.slice((page - 1) * 50, page * 50).map((e) => ({ id: e.id, title: e.title, ...hintOf(data.editor, data.kind, e) })) });
      }
      case 'read': {
        const entry = (entries[`${data.editor}|${data.kind}`] || []).find((e) => e.id === data.id);
        if (!entry) return fail('unknown_entry');
        const l = lifeOf(data.editor, data.kind, data.id);
        if (l.draft && l.draft.trial) banner(data.editor, true);
        return ok(readAnswer(data.editor, data.kind, entry, l));
      }
      case 'check': {
        if (!spend()) return fail('rate_limited');
        const values = { n: data.values.n || {}, s: data.values.s || {}, b: data.values.b || {} };
        if (forceErrors) {
          forceErrors = false;
          return ok({ valid: false, errors: [
            { field: 'titre', text: 'Un panneau porte déjà ce nom.' },
            { field: 'duree', text: 'Un panneau éclairé reste au moins un jour : la lanterne doit valoir la peine.' },
            { field: 'texte', text: 'Les runes se gravent lentement : 120 caractères au plus.' },
            { text: 'Le port est fermé aux nouveaux panneaux pendant la foire d\'automne.' },
          ] });
        }
        const errors = data.editor === 'vava_example_atelier:panneaux' && data.kind === 'panneau' ? validatePanel(data.id, values) : [];
        return ok(errors.length > 0 ? { valid: false, errors } : { valid: true });
      }
      case 'options': {
        const list = optionsOf(data.field);
        const q = fold(data.query);
        const found = list.filter((i) => !q || fold(i.label).includes(q) || i.value === data.query);
        const page = data.page || 1;
        return ok({ items: clone(found.slice((page - 1) * 30, page * 30)), more: found.length > page * 30 });
      }
      case 'search': {
        const q = fold(data.text);
        const hits = [];
        for (const card of visibleCards()) {
          if (card.upcoming) continue;
          if (fold(card.label).includes(q)) hits.push({ editor: card.editor, kind: '', title: card.label, where: 'atelier' });
          const descriptor = descriptorFor(card.editor);
          for (const kind of descriptor ? descriptor.kinds : []) {
            for (const e of entries[`${card.editor}|${kind.id}`] || []) {
              if (fold(e.title).includes(q)) hits.push({ editor: card.editor, kind: kind.id, id: e.id, title: e.title, where: `${card.label} › ${kind.noun}` });
            }
          }
        }
        return ok({ hits: hits.slice(0, 20) });
      }
      case 'journal': {
        const lines = journal.filter((l) => (!data.editor || l.editor === data.editor) && (!data.before || l.id < data.before)
          && (!senechal || visibleCards().some((c) => c.editor === l.editor)));
        const page = lines.slice(0, 25);
        const sent = clone(page);
        if (data.editor) for (const line of sent) delete line.editor;
        return ok({ lines: sent, more: lines.length > 25, next: page.length > 0 ? page[page.length - 1].id : 0 });
      }
      case 'children': case 'placeStart': case 'placeStop': case 'templateChanged': case 'goTo': case 'suspend':
        return placing(name, data);
      case 'save': case 'trial': case 'endTrial': case 'preview': case 'publish': case 'restore':
      case 'discard': case 'retire': case 'take': case 'history': case 'version': case 'removed':
        return lifecycle(name, data);
      default: return fail('invalid_args');
    }
  }

  const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  const P = 'vava_example_atelier:panneaux';
  const click = (selector) => { const node = document.querySelector(selector); if (node) node.click(); return node; };
  const editField = () => {
    const input = document.querySelector('.sheet .field input[type=text], .sheet .field textarea');
    input.value = `${input.value} (retouché)`;
    input.dispatchEvent(new Event('input', { bubbles: true }));
  };

  /** Écrans de T-101 ; faux si l'écran demandé n'en est pas un. */
  async function playLifecycle(screen, A) {
    if (screen === 'history' || scene === 'archived' || what === 'restore') {
      await A.openEntry(P, 'panneau', 'place_du_marche');
      A.run('history');
      await pause(200);
      if (scene !== 'archived' && what !== 'restore') return true;
      const row = Array.from(document.querySelectorAll('.hrow')).find((r) => r.textContent.includes('Version 2'));
      row.querySelector('.link').click();
      await pause(200);
      if (what === 'restore') A.run('restore');
      return true;
    }
    if (screen === 'removed') { await A.openEditor(P); A.openRemoved(); return true; }
    if (scene === 'trial') { await A.openEntry(P, 'affiche', 'foire'); return true; }
    if (scene === 'other' || scene === 'removal' || what === 'take') {
      await A.openEntry(P, 'panneau', 'porte_nord');
      if (what === 'take') A.run('take');
      return true;
    }
    if (what === 'retire') { await A.openEntry(P, 'panneau', 'enseigne_port'); A.run('retire'); return true; }
    if (scene === 'draft' || scene === 'stale' || what === 'publish' || what === 'discard' || params.get('changed') === '1') {
      await A.openEntry(P, 'panneau', 'place_du_marche');
      if (what) A.run(what);
      if (params.get('changed') === '1') {
        editField();
        window.postMessage({ action: 'entryChanged', payload: { editor: P, kind: 'panneau', id: 'place_du_marche', what: 'taken' } }, '*');
      }
      return true;
    }
    return false;
  }

  async function play() {
    document.body.classList.add('dev');
    seed();
    const screen = params.get('screen') || 'home';
    window.postMessage({ action: 'open', payload: homePayload('') }, '*');
    await pause(80);
    const A = window.Atelier;
    if (await playLifecycle(screen, A)) return;
    if (screen === 'search') {
      await A.state.view.setSearch(params.get('q') || 'forge');
    } else if (screen === 'list') {
      await A.openEditor('vava_example_atelier:panneaux');
    } else if ((screen === 'entry' && params.get('editor') !== 'recolte') || screen === 'confirm') {
      if (params.get('layout') === 'side') await A.openEntry('vava_example_atelier:panneaux', 'affiche', 'foire');
      else await A.openEntry('vava_example_atelier:panneaux', 'panneau', 'place_du_marche');
      if (forceErrors) await A.check();
      if (screen === 'confirm') {
        editField();
        A.back();
      }
    } else if (screen === 'entry' && params.get('editor') === 'recolte') {
      await A.openEntry('vava_gathering:zones', 'zone', params.get('step') === '1' ? 'bois_des_essais' : 'foret_brume');
      if (params.get('refused') === '1') {
        await pause(300);
        A.state.lastMode = 'children';
        post('placeRefused', { text: 'Trop près de « Chêne 2 » (1,4 m).' });
      }
    } else if (screen === 'placing') {
      const shape = params.get('shape') || 'oriented', page = params.get('layout') === 'page';
      if (shape === 'polygon') await A.openEntry(P, 'enclos', 'enclos_moutons');
      else if (page) await A.openEntry(P, 'panneau', 'place_du_marche');
      else await A.openEntry('vava_gathering:zones', 'zone', 'foret_brume');
      await pause(300);
      click(shape === 'oriented' && !page ? '.place-box .btn.dark' : '.place-row .btn');
      if (params.get('picked') === '1') { await pause(300); aim.picked = true; showAim(); }
    } else if (screen === 'suspended') {
      await A.openEntry('vava_gathering:zones', 'zone', 'foret_brume');
      await pause(200);
      A.run('trial');
    } else if (screen === 'keys') {
      await A.openEntry('vava_gathering:zones', 'zone', 'foret_brume');
      window.postMessage({ action: 'mode', payload: { banner: { title: 'Atelier de la récolte', line: 'Mode édition : les cercles et étiquettes ne sont visibles que par vous' } } }, '*');
      window.postMessage({ action: 'keys', payload: { keys: [
        { keys: ['Clic'], label: 'Poser ici' }, { keys: ['Molette'], label: 'Tourner' }, { keys: ['Maj'], label: 'Placement précis' },
        { keys: ['Clic droit'], label: 'Choisir un point' }, { keys: ['Ctrl', 'Z'], label: 'Annuler' }, { keys: ['Échap'], label: 'Quitter' },
      ] } }, '*');
    } else if (screen === 'journal') {
      A.openJournal('');
    } else if (screen === 'picker') {
      // liste cherchable d'un champ `item` (RPC options simulé), groupe replié rouvert
      await A.openEntry('vava_example_atelier:panneaux', 'panneau', 'place_du_marche');
      await pause(400);
      const field = document.querySelector('[data-field="offrande"]');
      field.closest('details').open = true;
      field.scrollIntoView({ block: 'center' });
      field.querySelector('button.pick').click();
    }
  }

  if (!inGame) window.addEventListener('DOMContentLoaded', () => { play(); });

  return { handle, inGame };
})();
