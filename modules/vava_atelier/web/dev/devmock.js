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
 *        Essais des fonctions pures : node modules/vava_atelier/web/dev/essais.js
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const params = new URLSearchParams(window.location.search);
  const senechal = params.get('rank') === 'senechal';
  const empty = params.get('empty') === '1';
  let forceErrors = params.get('errors') === '1';
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
      texts: { trial: 'Voir le panneau', publish: 'Dresser le panneau' }, hasCompare: true,
      kinds: [
        { id: 'panneau', noun: 'panneau', nounPlural: 'panneaux', article: 'le', newLabel: 'Nouveau panneau', layout: 'page', creatable: true, form: PANNEAU_FORM },
        { id: 'affiche', noun: 'affiche', nounPlural: 'affiches', article: 'l\'', newLabel: 'Nouvelle affiche', layout: 'side', creatable: true, parent: 'panneau',
          form: { titleField: 'titre', groups: {}, fields: [
            { id: 'titre', widget: 'text', label: 'Nom de l\'affiche', help: 'Ce qu\'annonce l\'affiche, en quelques mots.', min: 3, max: 40, charset: 'name', default: '' },
            { id: 'couleur', widget: 'segmented', label: 'Couleur', help: 'La teinte du papier, pour qu\'on la remarque.', options: [{ value: 'rouge', label: 'Rouge' }, { value: 'bleu', label: 'Bleu' }, { value: 'vert', label: 'Vert' }, { value: 'ocre', label: 'Ocre' }], default: 'ocre' },
            { id: 'duree', widget: 'duration', label: 'Reste affichée', help: 'Passé ce délai, l\'affiche est décrochée.', min: 3600, max: 604800, units: ['h', 'j'], default: 259200 },
          ] } },
      ],
    },
    'vava_example_atelier:proclamations': {
      family: 'societe', label: 'Proclamations (exemple)', description: 'Exemple de développement : un atelier réservé au Souverain.', icon: 'parchemin', order: 900,
      texts: { trial: 'Lire la proclamation', publish: 'Proclamer' }, hasCompare: false,
      kinds: [{ id: 'proclamation', noun: 'proclamation', nounPlural: 'proclamations', article: 'la', newLabel: 'Nouvelle proclamation', layout: 'page', creatable: true,
        form: { titleField: 'titre', groups: [], fields: [
          { id: 'titre', widget: 'text', label: 'Titre', help: 'Le titre crié par le héraut.', min: 3, max: 40, charset: 'name', default: '' },
          { id: 'texte', widget: 'text', label: 'Texte', help: 'Ce que le héraut lira sur la place.', min: 10, max: 300, multiline: true, charset: 'free', default: '' },
          { id: 'solennelle', widget: 'toggle', label: 'Solennelle', help: 'Les cloches sonnent avant la lecture.', default: true },
        ] } }],
    },
    'vava_gathering:zones': {
      family: 'monde', label: 'Récolte', description: 'Forêts, mines, prairies et coins de pêche, arbres et filons un par un.', icon: 'recolte', order: 10,
      texts: { trial: 'Tester la récolte', publish: 'Publier la zone', publishHint: 'Publier rend les nouveaux points visibles aux joueurs proches.' }, hasCompare: false,
      kinds: [{ id: 'zone', noun: 'zone', nounPlural: 'zones', article: 'la', newLabel: 'Nouvelle zone', layout: 'side', creatable: true, placement: 'circle', steps: ['La zone', 'Les points', 'Publier'],
        form: { titleField: 'nom', groups: [{ id: 'point', label: 'Prochain point à poser' }, { id: 'reglages', label: 'Réglages de la zone', folded: true, help: 'Type, rayon, vitesse à laquelle la terre se repose, durée d\'une cicatrice.' }], fields: [
          { id: 'nom', widget: 'text', label: 'Nom de la zone', help: 'Le nom que verront les récolteurs.', min: 3, max: 40, charset: 'name', default: '' },
          { id: 'ressource', widget: 'segmented', label: 'Ressource', help: 'Ce que donne le prochain point posé.', group: 'point', options: [{ value: 'chene', label: 'Chêne' }, { value: 'pin', label: 'Pin' }, { value: 'autre', label: 'Autre…' }], default: 'chene' },
          { id: 'charges', widget: 'slider', label: 'Récoltes avant repos', help: 'Combien de fois on récolte avant que le point se repose.', group: 'point', min: 1, max: 10, step: 1, integer: true, default: 3, width: 'half' },
          { id: 'repousse', widget: 'duration', label: 'Repousse d\'une récolte', help: 'Le temps qu\'il faut pour qu\'une récolte revienne.', group: 'point', min: 60, max: 86400, units: ['min', 'h'], default: 600, width: 'half' },
          { id: 'modele', widget: 'model', label: 'Apparence', help: 'Chêne de GTA en attendant le modèle médiéval.', group: 'point', choices: [{ value: 'prop_tree_oak_01', label: 'Chêne de GTA', provisional: true }, { value: 'prop_tree_pine_01', label: 'Pin de GTA', provisional: true }], default: 'prop_tree_oak_01' },
          { id: 'type', widget: 'segmented', label: 'Type de zone', help: 'Ce que la zone abrite.', group: 'reglages', options: [{ value: 'foret', label: 'Forêt' }, { value: 'mine', label: 'Mine' }, { value: 'prairie', label: 'Prairie' }, { value: 'peche', label: 'Pêche' }, { value: 'marais', label: 'Marais' }], default: 'foret' },
          { id: 'rayon', widget: 'slider', label: 'Rayon', help: 'Jusqu\'où s\'étend la zone autour de son centre.', group: 'reglages', min: 10, max: 300, step: 5, integer: true, unit: 'm', default: 120 },
          { id: 'repos', widget: 'slider', label: 'Repos de la terre', help: 'Vitesse à laquelle la terre reprend des forces.', group: 'reglages', min: 0.5, max: 2, step: 0.1, decimals: 1, prefix: '×', default: 1 },
          { id: 'cicatrice', widget: 'duration', label: 'Durée d\'une cicatrice', help: 'Le temps qu\'une terre épuisée met à guérir.', group: 'reglages', min: 3600, max: 2592000, units: ['h', 'j'], default: 172800 },
        ] } }],
    },
  };
  function descriptorFor(editor) {
    if (descriptors[editor]) return descriptors[editor];
    const card = cards.find((c) => c.editor === editor && !c.upcoming);
    if (!card) return null;
    const station = editor === 'vava_crafting:stations';
    return { family: card.family, label: card.label, description: card.description, icon: card.icon, order: 10, texts: { trial: 'Essayer', publish: 'Publier' }, hasCompare: false,
      kinds: [{ id: station ? 'station' : 'fiche', noun: station ? 'station' : 'fiche', nounPlural: station ? 'stations' : 'fiches', article: 'la', newLabel: station ? 'Nouvelle station' : 'Nouvelle fiche', layout: 'side', creatable: true,
        form: { titleField: 'nom', groups: [], fields: [
          { id: 'nom', widget: 'text', label: 'Nom', help: 'Le nom affiché dans les listes du Conseil.', min: 3, max: 40, charset: 'name', default: '' },
          { id: 'portee', widget: 'slider', label: 'Portée', help: 'Distance à laquelle on peut s\'en servir.', min: 1, max: 10, step: 0.5, decimals: 1, unit: 'm', default: 2 },
        ] } }] };
  }

  // Entrées et valeurs ------------------------------------------------------------------------------------------------
  const entries = {
    'vava_example_atelier:panneaux|panneau': [
      { id: 'place_du_marche', title: 'Panneau de la place', hint: 'Le marché, bois', values: { n: { taille: 1.5, portee: 3, duree: 604800 }, s: { titre: 'Panneau de la place', texte: 'Marché chaque jeudi, de l\'aube à la cloche de midi.\nLes étals se montent la veille.', langue: 'commun', matiere: 'bois', quartier: 'marche', offrande: 'pain', modele: 'prop_sign_road_01a' }, b: { eclaire: true } } },
      { id: 'porte_nord', title: 'Pancarte de la porte nord', hint: 'Les remparts, pierre', values: { n: { taille: 2.2, portee: 5, duree: 2592000 }, s: { titre: 'Pancarte de la porte nord', texte: 'Fermeture des portes au couvre-feu.', langue: 'commun', matiere: 'pierre', quartier: 'remparts', offrande: '', modele: 'prop_sign_road_03a' }, b: { eclaire: false } } },
      { id: 'enseigne_port', title: 'Enseigne du port', hint: 'Le port, parchemin cloué', values: { n: { taille: 1.5, portee: 4, duree: 86400 }, s: { titre: 'Enseigne du port', texte: '', langue: 'runes', matiere: 'parchemin', quartier: 'port', offrande: '', modele: 'prop_sign_road_01a' }, b: { eclaire: false } }, warnings: ['taille'] },
    ],
    'vava_example_atelier:panneaux|affiche': [
      { id: 'foire', title: 'Foire d\'automne', hint: 'Ocre, 3 jours', values: { n: { duree: 259200 }, s: { titre: 'Foire d\'automne', couleur: 'ocre' } } },
    ],
    'vava_example_atelier:proclamations|proclamation': [
      { id: 'couronnement', title: 'Proclamation du couronnement', values: { s: { titre: 'Proclamation du couronnement', texte: 'Oyez, oyez : la Couronne sera remise au jour de la Saint-Aldric.' }, b: { solennelle: true } } },
    ],
    'vava_gathering:zones|zone': [
      { id: 'foret_brume', title: 'Forêt de Brume', hint: '5 points, rayon 120 m', values: { n: { charges: 3, repousse: 600, rayon: 120, repos: 1, cicatrice: 172800 }, s: { nom: 'Forêt de Brume', ressource: 'chene', modele: 'prop_tree_oak_01', type: 'foret' } } },
      { id: 'mine_val', title: 'Mine du Val', hint: '3 filons, rayon 60 m', values: { n: { charges: 4, repousse: 1800, rayon: 60, repos: 0.8, cicatrice: 259200 }, s: { nom: 'Mine du Val', ressource: 'autre', modele: 'prop_tree_pine_01', type: 'mine' } } },
      { id: 'prairie_saules', title: 'Prairie des Saules', hint: '8 points, rayon 90 m', values: { n: { charges: 2, repousse: 900, rayon: 90, repos: 1.2, cicatrice: 86400 }, s: { nom: 'Prairie des Saules', ressource: 'autre', modele: 'prop_tree_oak_01', type: 'prairie' } } },
      { id: 'etang_moulin', title: 'Étang du Moulin', hint: '2 coins de pêche', values: { n: { charges: 5, repousse: 1200, rayon: 40, repos: 1, cicatrice: 86400 }, s: { nom: 'Étang du Moulin', ressource: 'autre', modele: 'prop_tree_oak_01', type: 'peche' } } },
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

  const optionsOf = (fieldId) => (fieldId === 'quartier' ? districts : (fieldId === 'offrande' ? items : []));

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
    for (const editor of Object.keys(tags)) if (!visibleCards().some((c) => c.editor === editor)) delete tags[editor];
    return tags;
  }

  const sentDescriptors = new Set();
  let homeSent = false;
  const ok = (data) => ({ ok: true, data });
  const fail = (error) => ({ ok: false, error });

  function homePayload(version) {
    const withContent = version !== 'accueil-1' || !homeSent;
    homeSent = true;
    return {
      version: 'accueil-1',
      content: withContent ? { families: clone(families), cards: clone(visibleCards()), footnote: 'Chaque atelier n\'apparaît qu\'aux rangs qui y ont droit. Un Sénéchal ne voit que le monde ; un Souverain voit tout.' } : undefined,
      tags: tagsOf(),
      drafts: empty ? [] : clone(drafts),
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
        return ok({ total: found.length, page, pages, entries: found.slice((page - 1) * 50, page * 50).map((e) => ({ id: e.id, title: e.title, hint: e.hint })) });
      }
      case 'read': {
        const entry = (entries[`${data.editor}|${data.kind}`] || []).find((e) => e.id === data.id);
        if (!entry) return fail('unknown_entry');
        const kind = (descriptorFor(data.editor) || { kinds: [] }).kinds.find((k) => k.id === data.kind);
        const answer = { id: entry.id, title: entry.title, values: clone(entry.values), labels: labelsOf(kind, entry.values), warnings: entry.warnings, state: { label: 'En vigueur', tone: 'live' }, footer: [{ id: 'check', label: 'Vérifier', primary: true }] };
        if (data.editor === 'vava_example_atelier:panneaux' && data.kind === 'panneau') {
          answer.compare = data.id === 'porte_nord' ? { title: 'Pour comparer : Panneau de la place', text: '1,5 m, lisible à 3 m, 7 jours' } : { title: 'Pour comparer : Pancarte de la porte nord', text: '2,2 m, lisible à 5 m, 30 jours' };
        }
        return ok(answer);
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
      default: return fail('invalid_args');
    }
  }

  const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  async function play() {
    document.body.classList.add('dev');
    const screen = params.get('screen') || 'home';
    window.postMessage({ action: 'open', payload: homePayload('') }, '*');
    await pause(80);
    const A = window.Atelier;
    if (screen === 'search') {
      await A.state.view.setSearch(params.get('q') || 'forge');
    } else if (screen === 'list') {
      await A.openEditor('vava_example_atelier:panneaux');
    } else if (screen === 'entry' || screen === 'confirm') {
      if (params.get('layout') === 'side') await A.openEntry('vava_example_atelier:panneaux', 'affiche', 'foire');
      else await A.openEntry('vava_example_atelier:panneaux', 'panneau', 'place_du_marche');
      if (forceErrors) await A.check();
      if (screen === 'confirm') {
        const input = document.querySelector('.sheet .field input[type=text], .sheet .field textarea');
        input.value = `${input.value} (retouché)`;
        input.dispatchEvent(new Event('input', { bubbles: true }));
        A.back();
      }
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
