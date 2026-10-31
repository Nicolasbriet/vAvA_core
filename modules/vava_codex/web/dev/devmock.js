'use strict';
/*
 * web/dev/devmock.js
 * Rôle : Codex simulé quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans lancer
 *        le jeu. Inactif en jeu. Paramètres d'URL : ?staff=0 pour voir le Codex d'un simple joueur ; ?focus=<chapitre>
 *        simule l'ouverture par l'export openAt ; ?dock=1 : mode panneau (openDocked, appelé par
 *        vava_pause, 1.6.0), combinable avec ?focus=… ; (ex. ?focus=vava_gathering : chapitre Récolte ; ?focus=premiers_pas :
 *        Lecture, première page du chapitre, contrat de T-022 ; ?focus=troquer : une page) ; ?lecture=0 : pages de
 *        lecture fermées (aucun index, pas d'onglet). Les listes des formulaires (joueurs, compétences, zones) sont
 *        simulées ; « Lancer » affiche la ligne. Lecture (1.5.0) : index de quatre pages, dont « Siéger au Conseil »
 *        réservée (absente avec ?staff=0) ; trois textes simulés couvrant tous les blocs et jetons (touche liée,
 *        touche absente « ? », commande visible ou non, lien présent ou cible absente, italique), rendus après
 *        40 ms ; « Apprendre un métier » n'a pas de texte : sa demande rend unknown_page (état d'échec).
 *        Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère
 *        que hors FiveM.
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const player = { name: 'joueur', type: 'player' };
  const skill = { name: 'compétence', type: 'registry', registry: 'vava_skills:skills', dynamic: true };
  const entries = [
    { name: 'me', kind: 'command', module: 'vava_chat', chapter: 'Chat', label: 'Action de votre personnage', description: 'Décrit ce que fait votre personnage, vu des joueurs proches.', scope: 'player', runnable: true, args: [{ name: 'action', type: 'text', rest: true, hint: 'ex. : tire son épée' }] },
    { name: 'do', kind: 'command', module: 'vava_chat', chapter: 'Chat', label: 'Décrire la scène', scope: 'player', runnable: true, args: [{ name: 'description', type: 'text', rest: true }] },
    { name: 'mp', kind: 'command', module: 'vava_chat', chapter: 'Chat', label: 'Message privé', description: 'Écrire en privé à un joueur en jeu.', scope: 'player', runnable: true, args: [{ ...player, dynamic: true }, { name: 'message', type: 'text', rest: true }] },
    { name: 'vava_chat_ouvrir', kind: 'key', module: 'vava_chat', chapter: 'Chat', label: 'Chat : écrire', scope: 'player', runnable: false, key: 'T', keyLabel: 'T', hold: true },
    { name: 'vava_inventory', kind: 'key', module: 'vava_inventory', chapter: 'Inventaire', label: 'Ouvrir l\'inventaire', scope: 'player', runnable: false, key: 'I', keyLabel: 'I' },
    { name: 'vava_inventory_slot', kind: 'key', module: 'vava_inventory', chapter: 'Inventaire', label: 'Raccourcis de la ceinture (5 emplacements)', scope: 'player', runnable: false, key: '1', keyDisplay: '1 à 5', keyLabel: '1 à 5' },
    { name: 'catalogue', kind: 'command', module: 'vava_inventory', chapter: 'Inventaire', label: 'Catalogue de développement', description: 'Ouvrir le catalogue de tous les objets connus, par catégorie et par page (serveur de test).', scope: 'admin', runnable: true, ui: true, args: [{ name: 'catégorie', type: 'list', list: 'categories', optional: true, dynamic: true }, { name: 'page', type: 'integer', min: 1, max: 999, optional: true }] },
    { name: 'vava_skills', kind: 'key', module: 'vava_skills', chapter: 'Compétences', label: 'Ouvrir le livre des compétences', scope: 'player', runnable: false, key: 'K', keyLabel: 'K' },
    { name: 'metiers', kind: 'command', module: 'vava_skills', chapter: 'Compétences', label: 'Compétences d\'un joueur', description: 'Corriger un niveau, donner une recette ou lire la fiche d\'un joueur.', scope: 'admin', runnable: true,
      actions: [
        { id: 'niveau', label: 'Corriger un niveau', description: 'Fixe le niveau d\'une compétence (l\'XP en cours est remise à zéro).', args: [{ ...player, dynamic: true }, skill, { name: 'niveau', type: 'integer', min: 0, max: 100 }] },
        { id: 'recette', label: 'Donner une recette', args: [{ ...player, dynamic: true }, { name: 'recette', type: 'registry', registry: 'vava_skills:recipes', dynamic: true }] },
        { id: 'voir', label: 'Lire la fiche', args: [{ ...player, dynamic: true }] },
      ] },
    { name: 'vava_fondateur', kind: 'command', module: 'vava_skills', chapter: 'Compétences', label: 'Nommer un fondateur', description: 'Fixe le niveau d\'une compétence et donne des recettes d\'origine. Console, ou ACE.', scope: 'console', runnable: false, args: [{ ...player, dynamic: true }, skill, { name: 'niveau', type: 'integer', min: 0, max: 100 }] },
    { name: 'vava_gathering_interact', kind: 'key', module: 'vava_gathering', chapter: 'Récolte', label: 'Récolter (nœud proche)', scope: 'player', runnable: false, key: 'E', keyLabel: 'E', hold: true },
    { name: 'vava_gathering_zones', kind: 'key', module: 'vava_gathering', chapter: 'Récolte', label: 'Ouvrir le panneau des zones de récolte', scope: 'player', runnable: false, key: 'O', keyLabel: 'O' },
    { name: 'recolte', kind: 'command', module: 'vava_gathering', chapter: 'Récolte', label: 'Zones et nœuds de récolte', description: 'État des zones et des nœuds, vitalité forcée, recharge d\'un nœud.', scope: 'admin', runnable: true,
      actions: [
        { id: 'zones', label: 'État des zones', description: 'Vitalité, bande et cicatrice de chaque zone, dans le chat.' },
        { id: 'zone', label: 'Détail d\'une zone', args: [{ name: 'zone', type: 'list', list: 'zones', dynamic: true }] },
        { id: 'vitalite', label: 'Fixer la vitalité d\'une zone', description: '0 marque une cicatrice, 100 remet la zone à neuf.', args: [{ name: 'zone', type: 'list', list: 'zones', dynamic: true }, { name: 'vitalité', type: 'integer', min: 0, max: 100 }] },
      ] },
    { name: 'sort', kind: 'command', module: 'vava_magic', chapter: 'Magie', label: 'Sort prêt dans vos mains', scope: 'player', runnable: true,
      actions: [{ label: 'Choisir un sort', args: [{ name: 'sort', type: 'registry', registry: 'vava_magic:spells', dynamic: true }] }, { id: 'aucun', label: 'Les mains vides' }] },
    { name: 'vava_magic_roue', kind: 'key', module: 'vava_magic', chapter: 'Magie', label: 'Magie : roue des sorts (maintenir)', scope: 'player', runnable: false, key: 'TAB', keyDisplay: 'Tab', keyLabel: 'Tab', hold: true },
    { name: 'vava_magic_viser', kind: 'key', module: 'vava_magic', chapter: 'Magie', label: 'Magie : viser (maintenir)', scope: 'player', runnable: false, key: 'MOUSE_RIGHT', keyDevice: 'MOUSE_BUTTON', keyDisplay: 'Clic droit', keyLabel: 'Clic droit', hold: true },
    { name: 'conseil', kind: 'command', module: 'vava_admin', chapter: 'Conseil', label: 'Registre du Conseil', description: 'Ouvrir le Registre du Conseil : joueurs, signalements, journal, bans.', scope: 'admin', runnable: true, ui: true, key: 'F10', keyLabel: 'F10' },
    { name: 'vava_conseil', kind: 'command', module: 'vava_admin', chapter: 'Conseil', label: 'Nommer ou révoquer un membre du Conseil', scope: 'console', runnable: false, args: [{ name: 'compte', type: 'account' }, { name: 'rang', type: 'choice', choices: ['gardien', 'senechal', 'souverain', 'aucun'], labels: { gardien: 'Gardien', senechal: 'Sénéchal', souverain: 'Souverain', aucun: 'Révoquer' } }] },
    { name: 'signaler', kind: 'command', module: 'vava_admin', chapter: 'Conseil', label: 'Signaler au Conseil', description: 'Transmettre un signalement au Conseil (un par minute).', scope: 'player', runnable: true, args: [{ name: 'message', type: 'text', rest: true }] },
    { name: 'codex', kind: 'command', module: 'vava_codex', chapter: 'Codex', label: 'Ouvrir le Codex', scope: 'player', runnable: true, ui: true, key: 'F1', keyLabel: 'F1' },
    { name: 'vava_saveall', kind: 'command', module: 'vAvA_core', chapter: 'Core', label: 'Sauvegarder tous les personnages', description: 'Écrit en base les personnages modifiés ; à lancer avant un arrêt du serveur.', scope: 'console', runnable: false },
  ];
  const chapters = [
    { id: 'vava_chat', label: 'Chat' }, { id: 'vava_codex', label: 'Codex' }, { id: 'vava_skills', label: 'Compétences' }, { id: 'vava_admin', label: 'Conseil' },
    { id: 'vAvA_core', label: 'Core' }, { id: 'vava_inventory', label: 'Inventaire' }, { id: 'vava_magic', label: 'Magie' }, { id: 'vava_gathering', label: 'Récolte' },
  ];
  const prefs = { favorites: ['metiers', 'recolte'], recent: [{ name: 'metiers', action: 'voir', at: 1730000000 }, { name: 'me', at: 1729990000 }], keepOpen: true };
  const lists = {
    'vava_skills:skills': [{ value: 'bucheronnage', label: 'Bûcheronnage' }, { value: 'forge', label: 'Forge' }, { value: 'minage', label: 'Minage' }, { value: 'herboristerie', label: 'Herboristerie' }, { value: 'arcanes', label: 'Arcanes' }],
    'vava_skills:recipes': [{ value: 'epee_courte', label: 'Épée courte' }, { value: 'talisman', label: 'Talisman' }],
    'vava_magic:spells': [{ value: 'boule_de_feu', label: 'Boule de feu' }, { value: 'trait_de_glace', label: 'Trait de glace' }],
    zones: [{ value: 'foret_brume', label: 'Forêt de Brume' }, { value: 'mine_du_val', label: 'Mine du Val' }, { value: 'prairie_haute', label: 'Prairie Haute' }, { value: 'riviere_claire', label: 'Rivière Claire' }],
    categories: [{ value: 'materiau', label: 'materiau' }, { value: 'outil', label: 'outil' }, { value: 'nourriture', label: 'nourriture' }],
    players: [{ value: '1', label: 'Aldric Ferrand (n° 1)' }, { value: '3', label: 'Bertrand Vauclair (n° 3)' }, { value: '7', label: 'Nicolas (n° 7)' }],
  };

  // Lecture : index tel que le serveur l'envoie (content.reading), puis les blocs déjà analysés de trois pages
  const readingChapters = [{ id: 'premiers_pas', label: 'Premiers pas' }, { id: 'metiers', label: 'Les métiers' }, { id: 'royaume', label: 'Le royaume' }];
  const readingPages = [
    { id: 'bienvenue', chapter: 'premiers_pas', title: 'Vivre à Eldoria', summary: 'Une cité sans pièce, où chacun a besoin des autres.', hash: '9f1c2a7b3d4e5f60' },
    { id: 'troquer', chapter: 'premiers_pas', title: 'Troquer et partager', summary: 'Ici rien ne s’achète : on donne, on rend service, on partage.', hash: '0a1b2c3d4e5f6071' },
    { id: 'apprendre', chapter: 'metiers', title: 'Apprendre un métier', summary: 'Compétences, rangs, maîtres et apprentis.', hash: '1b2c3d4e5f607182' },
    { id: 'conseil_sieger', chapter: 'royaume', title: 'Siéger au Conseil', summary: 'Rangs, droits et outils, et l’esprit dans lequel on s’en sert.', hash: '2c3d4e5f60718293', staff: true },
  ];
  const bodies = {
    bienvenue: [
      ['p', 'Ici, nul ne compte en pièces. On troque, on rend service, on partage les réserves communes. Personne ne sait tout faire : chacun apprend des autres, et c’est ce qui fait vivre la cité.'],
      ['note', 'Vous arrivez avec un peu de pain et d’eau, de quoi tenir un soir. La suite se trouve auprès des gens d’Eldoria.'],
      ['h', 'Ce livre'],
      ['p', 'Le Codex s’ouvre avec ', ['key', 'codex'], '. Trois onglets : ', ['em', 'Lecture'], ', que vous lisez, ', ['em', 'Commandes'], ', où chaque commande se compose et se lance, et ', ['em', 'Touches'], ', qui montre les vôtres.', ['foo', 'segment inconnu, retiré']],
      ['h', 'Vos premiers gestes'],
      ['ul',
        ['Ouvrir sa besace : ', ['key', 'vava_inventory'], '.'],
        ['Le livre des compétences : ', ['key', 'vava_skills'], '.'],
        ['L’heure, la saison et le ciel : ', ['cmd', 'date', ''], '.'],
        ['Fermer une fenêtre : ', ['kbd', 'Échap'], ' ; viser : ', ['key', 'vava_magic_viser'], '.']],
      ['p', 'Ce qui s’écrit dans le chat sans commande est dit hors du rôle, et entendu des seuls joueurs proches. Pour faire agir votre personnage, écrivez ', ['cmd', 'me', ''], ' ; pour décrire la scène, ', ['cmd', 'do', ''], '.'],
      ['h', 'Pour aller plus loin'],
      ['ul',
        [['page', 'se_parler', '']],
        [['page', 'troquer', '']],
        [['page', 'apprendre', 'Apprendre un métier auprès d’un maître']],
        [['page', 'conseil', 'Joindre le Conseil']]],
    ],
    troquer: [
      ['p', 'Ici, rien ne s’achète. La valeur d’un objet tient à sa qualité, à sa provenance et à la main qui l’a façonné : sa fiche montre son palier, d’où il vient, son artisan et son poinçon.'],
      ['h', 'Donner un objet'],
      ['ol',
        ['Ouvrez votre besace (', ['key', 'vava_inventory'], ').'],
        ['Faites glisser l’objet hors de la fenêtre : un sac se pose à vos pieds, visible des proches.'],
        ['L’autre ouvre sa besace près du sac et ramasse d’un double-clic.']],
      ['note', 'Un sac ne reste pas indéfiniment et ne survit pas au redémarrage du royaume : ne posez que devant celui qui prend.'],
      ['p', 'Annoncez-le d’un ', ['cmd', 'me', ''], ', et restez jusqu’à ce que l’autre ait pris.'],
      ['h', 'Rendre service'],
      ['ul',
        ['Réparer un outil (', ['page', 'artisanat', 'l’artisanat'], ').'],
        ['Relever un blessé : ', ['key', 'vava_health_assist'], ', un geste de quelques secondes.'],
        ['Enseigner (', ['page', 'apprendre', ''], ').'],
        ['Porter une part de récolte au grenier commun, où chaque dépôt et chaque retrait est ', ['em', 'inscrit'], '.']],
      ['p', 'Un souci hors du rôle ? ', ['cmd', 'signaler', ''], ' prévient le Conseil.'],
    ],
    conseil_sieger: [
      ['p', 'Le Conseil veille sur le royaume hors du rôle. Il répare et arbitre ; il n’enrichit personne.'],
      ['h', 'Les outils'],
      ['ul',
        ['Le Registre : ', ['key', 'conseil'], '.'],
        ['État des zones de récolte : ', ['cmd', 'recolte', 'zones'], '.'],
        ['Fiche d’un joueur : ', ['cmd', 'metiers', 'voir'], '.'],
        ['Fiche de magie : ', ['cmd', 'magie', 'fiche'], '.']],
      ['note', 'Toute action est inscrite au journal et au registre du Conseil.'],
      ['p', 'Retour au début : ', ['page', 'bienvenue', ''], '.'],
    ],
  };
  let mockStaff = true;
  let mockReading = true;

  function argOf(name, action, index) {
    const entry = entries.find((candidate) => candidate.name === name);
    if (!entry) return null;
    const args = entry.actions ? (entry.actions.find((candidate) => (candidate.id || '') === action) || {}).args : entry.args;
    return args ? args[index - 1] : null;
  }

  /** Message d'ouverture complet, de la forme envoyée par client/main.lua : contenu, préférences, touches du joueur. */
  function snapshot(staff) {
    mockStaff = staff;
    const visible = entries.filter((entry) => staff || entry.scope === 'player');
    const keys = {};
    for (const entry of visible) if (entry.keyLabel) keys[entry.name] = entry.keyLabel;
    const pages = readingPages.filter((page) => staff || !page.staff);
    return {
      version: staff ? 'dev0000000000001' : 'dev0000000000000',
      content: {
        entries: JSON.parse(JSON.stringify(visible)), chapters: chapters.filter((chapter) => visible.some((entry) => entry.module === chapter.id)),
        undeclared: staff ? [{ name: 'vava_admin_noclip', module: 'vava_admin' }, { name: 'zonesvoix', module: 'vava_voice' }] : [],
        staff,
        reading: mockReading ? {
          chapters: readingChapters.filter((chapter) => pages.some((page) => page.chapter === chapter.id)),
          pages: JSON.parse(JSON.stringify(pages)),
        } : undefined,
      },
      prefs: JSON.parse(JSON.stringify(prefs)), keys, closeKey: 'F1', recentMax: 12,
    };
  }

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 40));
    if (name === 'options') {
      const arg = argOf(data.name, data.action || '', data.index);
      if (!arg) return { ok: false, error: 'invalid_request' };
      if (arg.type === 'player') return { ok: true, options: lists.players };
      if (arg.type === 'registry') return { ok: true, options: lists[arg.registry] || [] };
      if (arg.type === 'list') return { ok: true, options: lists[arg.list] || [] };
      return { ok: false, error: 'invalid_request' };
    }
    if (name === 'favorite') {
      prefs.favorites = prefs.favorites.filter((entry) => entry !== data.name);
      if (data.on) prefs.favorites.push(data.name);
      return { ok: true, favorites: prefs.favorites.slice() };
    }
    if (name === 'keepOpen') {
      prefs.keepOpen = data.value === true;
      return { ok: true, keepOpen: prefs.keepOpen };
    }
    if (name === 'run') {
      prefs.recent = [{ name: data.name, action: data.action || undefined, at: Math.floor(Date.now() / 1000) }].concat(prefs.recent.filter((entry) => entry.name !== data.name || (entry.action || '') !== (data.action || ''))).slice(0, 12);
      return { ok: true, closed: data.ui === true || !prefs.keepOpen };
    }
    if (name === 'page') {
      // mêmes règles que le serveur : page de l'index visible pour ce joueur, sinon unknown_page (un seul code)
      const page = readingPages.find((candidate) => candidate.id === data.id && (mockStaff || !candidate.staff));
      if (!mockReading) return { ok: false, error: 'disabled' };
      if (!page || !bodies[page.id]) return { ok: false, error: 'unknown_page' };
      return { ok: true, page: { id: page.id, hash: page.hash, body: JSON.parse(JSON.stringify(bodies[page.id])) } };
    }
    if (name === 'refresh') return { ok: true, payload: snapshot(mockStaff) };
    return { ok: true };
  }

  if (!inGame) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('dev');
      const params = new URLSearchParams(window.location.search);
      mockReading = params.get('lecture') !== '0';
      const payload = snapshot(params.get('staff') !== '0');
      if (params.get('focus')) payload.focus = params.get('focus');
      // mode panneau (1.6.0) : rectangle de config_client.lua de vava_pause ; la bannière est esquissée à gauche
      if (params.get('dock') === '1') {
        payload.dock = { left: 32.6, top: 10.7, width: 58.3, height: 71.1 };
        const banner = document.createElement('div');
        banner.textContent = 'bannière (vava_pause)';
        Object.assign(banner.style, { position: 'fixed', left: '5.8vw', top: '0', width: '23vw', height: '91vh', background: '#6e2116', color: '#dcc08a',
          clipPath: 'polygon(0 0,100% 0,100% 100%,50% 92.5%,0 100%)', display: 'grid', placeItems: 'center', font: '20px Georgia, serif' });
        document.body.prepend(banner);
      }
      window.postMessage({ action: 'open', payload }, '*');
    });
  }

  return { handle, snapshot, inGame };
})();
