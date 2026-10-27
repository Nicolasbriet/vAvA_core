'use strict';
/*
 * web/js/devmock.js
 * Rôle : aperçu de l'interface dans un navigateur, hors du jeu (sans effet en jeu) : web/index.html?view=<vue>
 *        avec composer, offer, naming, confirm, grimoire, lueur, sealed, register, cast, broken, murmur, unknown,
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
      sigils: 'Sigils mémorisables : %d', colors: 'Couleur de la lumière', close: 'Fermer',
    },
    wheel: { cancel: 'Annuler', deselect: 'Ranger la magie', cost: '%d', cooldown: '%d s', noSpell: 'Aucun sort', level: 'Niveau %d' },
    hud: { mana: 'Mana', asleep: 'Mains au repos' },
    states: { burn: 'Brûlure', wet: 'Mouillé', slow: 'Ralenti', stagger: 'Chancelant', knockdown: 'Renversé', frozen: 'Gelé', immune: 'Protégé' },
    register: {
      title: 'Registre des murmures', empty: 'Ce registre est vierge.', sent: 'À %s', received: 'De %s', unknown: 'D\'une présence inconnue',
      tear: 'Arracher la page',
      count: '%d / %d pages', close: 'Fermer',
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
  const WHEEL = {
    selected: 'boule_de_feu', releaseKey: 'TAB',
    groups: [
      { id: 'feu', label: 'Feu', icon: 'feu', spells: [
        { name: 'boule_de_feu', label: 'Boule de feu', icon: 'boule_de_feu', level: 2, cost: 13, cooldown: 0, color: FIRE },
        { name: 'mur_de_flammes', label: 'Mur de flammes', icon: 'mur_de_flammes', level: 1, cost: 24, cooldown: 0, color: FIRE },
        { name: 'nova_ardente', label: 'Nova ardente', icon: 'nova_ardente', level: 3, cost: 24, cooldown: 6000, color: FIRE },
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

  const SCENES = {
    composer: () => Bridge.emit('modal:composer', { contacts: CONTACTS, circle: 4, maxLength: 220, waypoint: true, cost: 8 }),
    offer: () => Bridge.emit('modal:offer', { id: 3, seconds: 30, nameMax: 24 }),
    naming: () => Bridge.emit('modal:naming', { id: 3, seconds: 30, nameMax: 24 }),
    confirm: () => Bridge.emit('modal:confirm', { kind: 'scramble', cost: 60 }),
    grimoire: () => Bridge.emit('modal:grimoire', { sealed: false, spells: SPELLS, groups: GROUPS, controls: CONTROLS }),
    sealed: () => Bridge.emit('modal:grimoire', { sealed: true }),
    register: () => Bridge.emit('modal:register', { id: 7, pages: PAGES, count: 3, max: 200 }),
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
  SCENES.wheelfire = () => {
    SCENES.wheel();
    const rect = document.getElementById('wheel').getBoundingClientRect();
    window.dispatchEvent(new MouseEvent('mousemove', { clientX: rect.left + rect.width * 0.5, clientY: rect.top + rect.height * 0.32 }));
    window.dispatchEvent(new MouseEvent('mousemove', { clientX: rect.left + rect.width * 0.5, clientY: rect.top + rect.height * 0.1 }));
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
      return { ok: true };
    },
  };
})();
