'use strict';
/*
 * web/js/devmock.js
 * Rôle : aperçu de l'interface dans un navigateur, hors du jeu (sans effet en jeu) : web/index.html?view=<vue>
 *        avec composer, offer, naming, confirm, grimoire, lueur, sealed, register, registerlong, cast, broken, murmur, unknown,
 *        threat, wheel, wheelfire, hud, aim, states, frost, messages, all.
 *        Les textes ci-dessous ne sont qu'une copie d'aperçu : en jeu, ils viennent de config.lua.
 */

window.DevMock = (() => {
  if (Bridge.inGame) return null;
  const posted = [];

  const TEXTS = {
    cast: { interrupted: 'Incantation brisée' },
    threat: { text: 'Un frisson vous parcourt…' },
    composer: {
      title: 'Murmure', to: 'Destinataires', circle: 'Votre cercle : %d contact(s) au plus',
      noContacts: 'Vous ne gardez encore aucun sigil : échangez-en face à face (/sigil offrir).',
      message: 'Votre message', placeholder: 'Quelques mots à confier au vent…', count: '%d / %d signes',
      position: 'Joindre ma position', positionLocked: 'Joindre sa position : niveau 3', send: 'Murmurer', close: 'Fermer', cost: 'Mana : %d',
    },
    murmur: { from: 'De %s', unknown: 'Une présence inconnue', waypoint: 'Un point de passage est marqué sur votre carte.' },
    offer: {
      title: 'Un sigil vous est tendu', body: 'La personne en face de vous vous confie son sigil. Sous quel nom le garderez-vous ?',
      name: 'Nom du contact', giveBack: 'Lui confier mon sigil en retour', accept: 'Accepter', refuse: 'Refuser', remaining: '%d s',
    },
    naming: {
      title: 'Un sigil en retour', body: 'On vous confie un sigil en retour. Sous quel nom le garderez-vous ?',
      name: 'Nom du contact', accept: 'Garder', refuse: 'Refuser', remaining: '%d s',
    },
    confirm: {
      scrambleTitle: 'Brouiller votre sigil',
      scrambleBody: 'Un nouveau sigil remplacera l\'ancien : tous ceux qui le connaissaient perdront le lien. Votre propre liste vous reste. Coût : %d de mana.',
      confirm: 'Brouiller', cancel: 'Renoncer',
    },
    grimoire: {
      title: 'Grimoire', sealed: 'Les pages restent illisibles : les signes se dérobent à votre regard, comme si le livre refusait de vous parler.',
      empty: 'Aucun sort n\'est encore couché dans ces pages.', level: 'Niveau %d', mastered: 'Maîtrise achevée', xp: '%d / %d XP', xpMax: '%d XP',
      cost: 'Mana : %d', cooldown: 'Recharge : %s s', cast: 'Incantation : %s s', instant: 'Incantation : instantanée',
      element: 'Élément : %s', lock: 'Verrouiller : %s', controls: 'Roue : %s · viser : %s · lancer : %s',
      current: 'Ce que vous savez', next: 'Au niveau suivant',
      combos: 'Combinaisons', comboTrigger: 'Déclencheur', comboResult: 'Résultat', comboElements: 'Éléments : %s',
      combosHidden: '%d combinaison(s) restent à découvrir.',
      combosNone: 'Aucune combinaison découverte : mêlez les éléments, et ces pages s\'écriront d\'elles-mêmes.',
      sigils: 'Sigils mémorisables : %d', colors: 'Couleur de la lumière', close: 'Fermer',
    },
    wheel: { cancel: 'Annuler', deselect: 'Ranger la magie', cost: '%d', cooldown: '%d s', noSpell: 'Aucun sort', level: 'Niveau %d' },
    hud: { mana: 'Mana', asleep: 'Mains au repos' },
    states: { burn: 'Brûlure', wet: 'Mouillé', slow: 'Ralenti', stagger: 'Chancelant', knockdown: 'Renversé', frozen: 'Gelé', immune: 'Protégé' },
    register: {
      title: 'Registre des murmures', empty: 'Ce registre est vierge.', sent: 'À %s', received: 'De %s', unknown: 'D\'une présence inconnue',
      tear: 'Arracher la page',
      count: '%d / %d pages', close: 'Fermer',
      more: 'tourner les pages plus anciennes', loading: 'Les pages tournent…',
      months: ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
      date: 'Le %d %s, à %dh%s',
    },
  };

  const CONTACTS = [
    { index: 1, name: 'Mage du moulin' }, { index: 2, name: 'Écuyère Aline' }, { index: 3, name: 'Le souverain' },
    { index: 4, name: 'Frère Anselme' }, { index: 5, name: 'Dame de Brocéliande' },
  ];
  const COLORS = [
    { name: 'ambre', label: 'Ambre', r: 255, g: 196, b: 128 }, { name: 'lune', label: 'Clair de lune', r: 190, g: 210, b: 255 },
    { name: 'aube', label: 'Aube rosée', r: 255, g: 170, b: 150 }, { name: 'sylve', label: 'Sylve', r: 160, g: 240, b: 170 },
    { name: 'flamme', label: 'Flamme', r: 255, g: 140, b: 60 }, { name: 'arcane', label: 'Arcane', r: 190, g: 150, b: 255 },
  ];
  const FIRE = { r: 255, g: 132, b: 52 };
  const WATER = { r: 96, g: 176, b: 255 };
  const EARTH = { r: 200, g: 156, b: 98 };
  const LIGHT = { r: 255, g: 224, b: 150 };
  const SPIRIT = { r: 190, g: 164, b: 255 };
  const GROUPS = [
    { id: 'feu', label: 'Feu', icon: 'feu' }, { id: 'eau', label: 'Eau', icon: 'eau' },
    { id: 'terre', label: 'Terre', icon: 'terre' }, { id: 'utilitaires', label: 'Utilitaires', icon: 'utilitaires' },
  ];
  const SPELLS = [
    {
      name: 'boule_de_feu', label: 'Boule de feu', summary: 'Rassembler les flammes et les jeter sur un adversaire.', level: 2, xp: 140, from: 100, to: 300,
      icon: 'boule_de_feu', element: 'Feu', group: 'feu', color: FIRE,
      description: 'Plus brûlante et plus lointaine (vingt-six mètres) ; elle ne s\'éteint plus qu\'une fois sur dix.',
      next: 'Votre boule de feu éclate à l\'impact et touche ceux qui entourent la cible.', cost: 13, cooldown: '3,5', lock: 'Clic molette',
    },
    {
      name: 'trait_de_glace', label: 'Trait de glace', summary: 'Darder un éclat de glace qui transit l\'adversaire et alourdit ses pas.', level: 3, xp: 380, from: 300, to: 700,
      icon: 'trait_de_glace', element: 'Eau', group: 'eau', color: WATER,
      description: 'Trente-deux mètres de portée ; la cible perd un tiers de son allure trois secondes.',
      next: 'Votre trait empêche de courir et s\'incurve vers la cible verrouillée.', cost: 10, cooldown: '2,5', lock: 'Clic molette',
    },
    {
      name: 'rempart', label: 'Rempart', summary: 'Faire surgir du sol un mur de pierre qui arrête les pas et les sorts.', level: 5, xp: 1500, from: 1500,
      icon: 'rempart', element: 'Terre', group: 'terre', color: EARTH,
      description: 'Deux pans de quatre mètres en chevron, qui couvrent aussi vos flancs, seize secondes durant.', cost: 17, cooldown: '15', cast: '1',
    },
    {
      name: 'lueur', label: 'Lueur', summary: 'Faire naître la lumière, au creux de la main puis en orbe.', level: 5, xp: 1500, from: 1500,
      icon: 'lueur', element: 'Lumière', group: 'utilitaires', color: LIGHT,
      description: 'Dix minutes de lumière, dans la couleur de votre choix ; vos orbes ancrés durent autant.', cost: 5, cooldown: '4', cast: '1,5',
      colors: COLORS, lightColor: 'lune',
    },
    {
      name: 'murmure', label: 'Murmure', summary: 'Confier quelques mots au vent, jusqu\'à ceux dont on garde le sigil.', level: 3, xp: 412, from: 300, to: 700,
      icon: 'murmure', element: 'Esprit', group: 'utilitaires', color: SPIRIT,
      description: 'Cent soixante signes, sans limite de distance. Quelques mots seulement se trahissent, et vous pouvez joindre votre position.',
      next: 'Vous pouvez murmurer à un cercle de quatre contacts en un seul envoi.', cost: 10, cooldown: '16', cast: '5', sigils: 25,
    },
  ];
  const CONTROLS = { wheel: 'Tab', aim: 'Clic droit', cast: 'Clic gauche' };
  const COMBOS = [
    {
      id: 'vapeur', label: 'Vapeur', summary: 'L\'eau jetée sur les flammes les étouffe en un nuage brûlant.',
      trigger: 'Une vague ou un trait de glace touche un mur de flammes.',
      result: 'Le mur s\'éteint et laisse un nuage de vapeur qui cache la vue et brûle légèrement ceux qui s\'y tiennent.',
      elements: [{ icon: 'eau', label: 'Eau', color: WATER }, { icon: 'feu', label: 'Feu', color: FIRE }],
    },
    {
      id: 'boue', label: 'Boue', summary: 'La terre remuée sous l\'eau devient un bourbier.',
      trigger: 'Une secousse frappe un sol mouillé.',
      result: 'Une boue épaisse s\'étale et ralentit fortement ceux qui s\'y enfoncent, trente secondes durant.',
      elements: [{ icon: 'terre', label: 'Terre', color: EARTH }, { icon: 'eau', label: 'Eau', color: WATER }],
    },
  ];
  const WHEEL = {
    selected: 'boule_de_feu', releaseKey: 'TAB',
    groups: [
      { id: 'feu', label: 'Feu', icon: 'feu', spells: [
        { name: 'boule_de_feu', label: 'Boule de feu', icon: 'boule_de_feu', level: 2, cost: 13, cooldown: 0, color: FIRE },
        { name: 'mur_de_flammes', label: 'Mur de flammes', icon: 'mur_de_flammes', level: 1, cost: 24, cooldown: 0, color: FIRE },
        { name: 'nova_ardente', label: 'Nova ardente', icon: 'nova_ardente', level: 3, cost: 24, cooldown: 6000, color: FIRE },
      ] },
      { id: 'eau', label: 'Eau', icon: 'eau', spells: [
        { name: 'trait_de_glace', label: 'Trait de glace', icon: 'trait_de_glace', level: 3, cost: 10, cooldown: 0, color: WATER },
        { name: 'vague', label: 'Vague', icon: 'vague', level: 2, cost: 23, cooldown: 0, color: WATER },
        { name: 'brume', label: 'Brume', icon: 'brume', level: 4, cost: 15, cooldown: 7000, color: WATER },
      ] },
      { id: 'terre', label: 'Terre', icon: 'terre', spells: [
        { name: 'projectile_de_roche', label: 'Projectile de roche', icon: 'projectile_de_roche', level: 1, cost: 18, cooldown: 0, color: EARTH },
        { name: 'secousse', label: 'Secousse', icon: 'secousse', level: 4, cost: 17, cooldown: 0, color: EARTH },
        { name: 'rempart', label: 'Rempart', icon: 'rempart', level: 5, cost: 17, cooldown: 12000, color: EARTH },
      ] },
      { id: 'utilitaires', label: 'Utilitaires', icon: 'utilitaires', spells: [
        { name: 'lueur', label: 'Lueur', icon: 'lueur', level: 5, cost: 5, cooldown: 0, color: LIGHT },
        { name: 'murmure', label: 'Murmure', icon: 'murmure', level: 3, cost: 10, cooldown: 9000, color: SPIRIT },
      ] },
    ],
  };
  const NOW = Math.floor(Date.now() / 1000);
  const PAGES = [
    { id: 41, at: NOW - 600, direction: 2, contact: 'Mage du moulin', text: 'Rendez-vous au moulin quand la lune sera haute. Apporte le registre … et viens seul.' },
    { id: 40, at: NOW - 7200, direction: 1, contact: 'Mage du moulin, Le souverain', text: 'Le conseil se tiendra demain à la troisième heure, dans la salle aux tapisseries.' },
    { id: 37, at: NOW - 90000, direction: 2, contact: '', text: 'On t\'observe depuis le pont.' },
  ];
  // registre long (?view=registerlong) : 47 pages, envoyées par lots de 20 comme le fait le serveur
  const LONG = Array.from({ length: 47 }, (_, i) => ({
    id: 300 - i * 3, at: NOW - 3600 * (i + 1), direction: i % 3 === 0 ? 1 : 2, contact: i % 5 === 4 ? '' : CONTACTS[i % CONTACTS.length].name,
    text: `Murmure n° ${47 - i} : quelques mots confiés au vent, pour feuilleter le registre.`,
  }));
  const LOT = 20;
  function lotBefore(before) {
    const older = LONG.filter((page) => page.id < before);
    return { pages: older.slice(0, LOT), more: older.length > LOT };
  }

  const SCENES = {
    composer: () => Bridge.emit('modal:composer', { contacts: CONTACTS, circle: 4, maxLength: 220, waypoint: true, cost: 8 }),
    offer: () => Bridge.emit('modal:offer', { id: 3, seconds: 30, nameMax: 24 }),
    naming: () => Bridge.emit('modal:naming', { id: 3, seconds: 30, nameMax: 24 }),
    confirm: () => Bridge.emit('modal:confirm', { kind: 'scramble', cost: 60 }),
    grimoire: () => Bridge.emit('modal:grimoire', { sealed: false, spells: SPELLS, groups: GROUPS, controls: CONTROLS, combos: COMBOS, hiddenCombos: 5 }),
    sealed: () => Bridge.emit('modal:grimoire', { sealed: true }),
    register: () => Bridge.emit('modal:register', { id: 7, pages: PAGES, more: false, count: 3, max: 200 }),
    registerlong: () => Bridge.emit('modal:register', { id: 8, ...lotBefore(Infinity), count: LONG.length, max: 200 }),
    cast: () => Bridge.emit('cast:start', { label: 'Murmure', ms: 6000 }),
    broken: () => { Bridge.emit('cast:start', { label: 'Boule de feu', ms: 4000 }); setTimeout(() => Bridge.emit('cast:interrupted'), 1500); },
    murmur: () => Bridge.emit('murmur:show', { from: 'Mage du moulin', text: 'Rendez-vous au moulin ce soir, … la lune sera haute.', waypoint: true, ms: 600000 }),
    unknown: () => Bridge.emit('murmur:show', { text: 'On t\'observe depuis le pont.', ms: 600000 }),
    threat: () => Bridge.emit('threat', { ms: 4000 }),
    hud: () => {
      Bridge.emit('hud:spell', { name: 'boule_de_feu', label: 'Boule de feu', icon: 'boule_de_feu', level: 2, color: FIRE });
      Bridge.emit('hud:mana', { value: 62, max: 100, points: 3, period: 5000, elapsed: 1200 });
      Bridge.emit('hud:mode', { awake: true });
    },
    aim: () => { SCENES.hud(); Bridge.emit('reticle', { visible: true, color: FIRE, out: false }); },
    states: () => {
      SCENES.hud();
      Bridge.emit('states', { list: [{ name: 'burn', ms: 3400 }, { name: 'wet', ms: 9000 }, { name: 'slow', ms: 2600 }, { name: 'frozen', ms: 1800 }] });
      Bridge.emit('screen', { burn: true, frost: false });
    },
    frost: () => {
      SCENES.hud();
      Bridge.emit('states', { list: [{ name: 'frozen', ms: 1800 }, { name: 'immune', ms: 7000 }] });
      Bridge.emit('screen', { burn: false, frost: true });
    },
    wheel: () => {
      SCENES.hud();
      Bridge.emit('wheel:open', WHEEL);
      // la souris sur Lueur, pour l'aperçu
      const rect = document.getElementById('wheel').getBoundingClientRect();
      window.dispatchEvent(new MouseEvent('mousemove', { clientX: rect.left + rect.width * 0.5, clientY: rect.top + rect.height * 0.5 }));
      window.dispatchEvent(new MouseEvent('mousemove', { clientX: rect.left + rect.width * 0.28, clientY: rect.top + rect.height * 0.84 }));
    },
  };
  SCENES.lueur = () => { SCENES.grimoire(); document.querySelectorAll('#view-grimoire .entry')[1].click(); };
  SCENES.combos = () => { SCENES.grimoire(); document.querySelector('#view-grimoire .entry.is-combo').click(); };
  SCENES.combo = () => { SCENES.hud(); Bridge.emit('combo', { label: 'Vapeur !' }); };
  SCENES.wheelfire = () => {
    SCENES.wheel();
    const rect = document.getElementById('wheel').getBoundingClientRect();
    window.dispatchEvent(new MouseEvent('mousemove', { clientX: rect.left + rect.width * 0.5, clientY: rect.top + rect.height * 0.32 }));
    window.dispatchEvent(new MouseEvent('mousemove', { clientX: rect.left + rect.width * 0.5, clientY: rect.top + rect.height * 0.1 }));
  };
  // survol d'un groupe de la roue : angle du groupe (radians, 0 en haut, sens des aiguilles d'une montre ; cinq
  // entrées : quatre groupes et « ranger »)
  const hoverGroup = (angle) => {
    SCENES.wheel();
    const rect = document.getElementById('wheel').getBoundingClientRect();
    const cx = rect.left + rect.width / 2, cy = rect.top + rect.height / 2;
    for (const share of [0.18, 0.4]) {
      window.dispatchEvent(new MouseEvent('mousemove', {
        clientX: cx + Math.sin(angle) * rect.width * share, clientY: cy - Math.cos(angle) * rect.height * share,
      }));
    }
  };
  SCENES.wheelwater = () => hoverGroup((2 * Math.PI) / 5);
  SCENES.wheelearth = () => hoverGroup((4 * Math.PI) / 5);
  SCENES.mist = () => {
    SCENES.hud();
    Bridge.emit('states', { list: [{ name: 'wet', ms: 9000 }] });
    Bridge.emit('screen:mist', { density: 0.85 });
  };
  SCENES.hits = () => {
    SCENES.hud();
    ['water', 'frost', 'earth'].forEach((kind, index) => setTimeout(() => Bridge.emit('screen:hit', { kind }), index * 700));
  };
  SCENES.messages = () => { SCENES.murmur(); SCENES.unknown(); SCENES.cast(); };
  SCENES.all = () => { SCENES.messages(); SCENES.grimoire(); };

  window.addEventListener('load', () => {
    document.body.classList.add('dev');
    Bridge.emit('init', { texts: TEXTS });
    const view = new URLSearchParams(location.search).get('view');
    if (view && SCENES[view]) SCENES[view]();
  });

  return {
    posted,
    texts: TEXTS,
    answer(name, body) {
      posted.push({ name, body });
      if (name === 'register:more') return { ok: true, ...lotBefore(Number(body.before)) };
      return { ok: true };
    },
  };
})();
