'use strict';
/*
 * web/js/devmock.js
 * Rôle : Codex simulé quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans lancer
 *        le jeu. Inactif en jeu. Paramètre d'URL : ?staff=0 pour voir le Codex d'un simple joueur. Les listes des
 *        formulaires (joueurs, compétences, zones) sont simulées ; « Lancer » affiche la ligne.
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

  function argOf(name, action, index) {
    const entry = entries.find((candidate) => candidate.name === name);
    if (!entry) return null;
    const args = entry.actions ? (entry.actions.find((candidate) => (candidate.id || '') === action) || {}).args : entry.args;
    return args ? args[index - 1] : null;
  }

  /** Message d'ouverture complet, de la forme envoyée par client/main.lua : contenu, préférences, touches du joueur. */
  function snapshot(staff) {
    const visible = entries.filter((entry) => staff || entry.scope === 'player');
    const keys = {};
    for (const entry of visible) if (entry.keyLabel) keys[entry.name] = entry.keyLabel;
    return {
      version: staff ? 'dev0000000000001' : 'dev0000000000000',
      content: {
        entries: JSON.parse(JSON.stringify(visible)), chapters: chapters.filter((chapter) => visible.some((entry) => entry.module === chapter.id)),
        undeclared: staff ? [{ name: 'vava_admin_noclip', module: 'vava_admin' }, { name: 'zonesvoix', module: 'vava_voice' }] : [],
        staff,
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
    if (name === 'refresh') return { ok: true, payload: snapshot(true) };
    return { ok: true };
  }

  if (!inGame) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('dev');
      const staff = new URLSearchParams(window.location.search).get('staff') !== '0';
      window.postMessage({ action: 'open', payload: snapshot(staff) }, '*');
    });
  }

  return { handle, snapshot, inGame };
})();
