'use strict';
/*
 * web/dev/devmock.js
 * Rôle : fiche simulée quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans
 *        lancer le jeu. Inactif en jeu. Paramètre d'URL : ?tab=mentorat (ou competences, savoirs, penurie). Treize
 *        compétences, un maître, deux apprentis, une proposition, trois savoirs dont une lignée à trois maillons, un
 *        apprentissage 2/3, deux métiers en pénurie. Les retours de l'interface reçoivent des réponses plausibles.
 *        Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère
 *        que hors FiveM.
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const NOW = Math.floor(Date.now() / 1000);
  const DAY = 86400;
  const xpToNext = (level) => Math.floor(50 + 1.5 * level * level);
  const RANKS = [
    { name: 'novice', label: 'Novice', min: 0 }, { name: 'apprenti', label: 'Apprenti', min: 20 },
    { name: 'compagnon', label: 'Compagnon', min: 40 }, { name: 'artisan', label: 'Artisan', min: 60 },
    { name: 'maitre', label: 'Maître', min: 80 }, { name: 'grand_maitre', label: 'Grand Maître', min: 95 },
  ];
  const rankOf = (level) => RANKS.reduce((found, rank) => (level >= rank.min ? rank : found), RANKS[0]);
  const CATEGORIES = [
    { id: 'recolte', label: 'Récolte' }, { id: 'terre', label: 'Terre' },
    { id: 'transformation', label: 'Transformation' }, { id: 'savoir', label: 'Savoir' },
  ];
  const BASE = [
    ['bucheronnage', 'Bûcheronnage', 'recolte', 34, 'up'], ['minage', 'Minage', 'recolte', 12, 'keep'],
    ['herboristerie', 'Herboristerie', 'recolte', 48, 'down'], ['peche', 'Pêche', 'recolte', 7, 'keep'],
    ['chasse', 'Chasse', 'recolte', 0, 'keep'], ['agriculture', 'Agriculture', 'terre', 26, 'up'],
    ['forge', 'Forge', 'transformation', 84, 'up'], ['menuiserie', 'Menuiserie', 'transformation', 41, 'keep'],
    ['tissage', 'Tissage et couture', 'transformation', 3, 'keep'], ['tannerie', 'Tannerie', 'transformation', 0, 'keep'],
    ['alchimie', 'Alchimie', 'transformation', 19, 'up'], ['cuisine', 'Cuisine', 'transformation', 55, 'down'],
    ['arcanes', 'Arcanes', 'savoir', 22, 'up'],
  ];
  const aldric = { mentorshipId: 11, characterId: 42, name: 'Aldric Ferrand', since: NOW - 12 * DAY, online: true };
  const apprentices = [
    { mentorshipId: 21, characterId: 77, name: 'Perrin Lavoie', since: NOW - 5 * DAY, online: true },
    { mentorshipId: 22, characterId: 91, name: 'Mahaut de Serre', since: NOW - 40 * DAY, online: false },
  ];

  function skill([id, label, category, level, mode]) {
    const next = xpToNext(level);
    const view = {
      id, label, category, level, xp: Math.floor(next * ((level * 7) % 10) / 10), xpToNext: next, rank: rankOf(level), mode,
      renown: id === 'forge' ? 340 : 0, practicedAt: level > 0 ? NOW - (level * 1700) % (6 * DAY) : 0,
      mentoredOnly: id === 'arcanes', canMentor: level >= 80, mentor: null, apprentices: [],
    };
    if (id === 'herboristerie') view.shortage = 1.5;
    if (id === 'tannerie') view.shortage = 1.5;
    if (id === 'arcanes') view.mentor = aldric;
    if (id === 'forge') view.apprentices = apprentices;
    return view;
  }

  const skills = BASE.map(skill);
  const used = skills.reduce((sum, entry) => sum + Math.max(0, entry.level - 20), 0);

  const sheet = {
    character: { id: 7, name: 'Corwin le Roux', playSeconds: 45 * 3600 + 12 * 60 },
    rules: {
      commonKnowledge: 20, budget: 200, maxLevel: 100, ranks: RANKS, lessonsRequired: 3,
      mentoring: { minRank: 'maitre', maxApprentices: 3, bonus: 0.5 },
    },
    budget: { used, total: 200 },
    categories: CATEGORIES,
    skills,
    recipes: [
      { id: 'acier_trempe', label: 'Trempe de l\'acier', skill: 'forge', learnedAt: NOW - 60 * DAY, source: 'lesson', taughtBy: { characterId: 42, name: 'Aldric Ferrand' } },
      { id: 'lame_runique', label: 'Lame runique', skill: 'forge', learnedAt: NOW - 20 * DAY, source: 'fragments', taughtBy: null },
      { id: 'pain_des_moines', label: 'Pain des moines', skill: 'cuisine', learnedAt: NOW - 200 * DAY, source: 'founder', taughtBy: null },
    ],
    lessons: [
      { recipe: 'onguent_de_lune', label: 'Onguent de lune', skill: 'herboristerie', count: 2, required: 3, lastAt: NOW - 1800, nextAllowedAt: NOW + 1800 },
    ],
    proposals: [
      { id: 501, masterName: 'Brunehilde Vastel', masterCharacterId: 58, skill: 'herboristerie', skillLabel: 'Herboristerie', expiresInMs: 48000 },
    ],
    shortages: [
      { skill: 'herboristerie', label: 'Herboristerie', count: 1, multiplier: 1.5 },
      { skill: 'tannerie', label: 'Tannerie', count: 0, multiplier: 1.5 },
    ],
    now: NOW,
    closeKey: 'K',
  };

  const lineages = {
    acier_trempe: { recipe: 'acier_trempe', label: 'Trempe de l\'acier', chain: [
      { characterId: 7, name: 'Corwin le Roux', learnedAt: NOW - 60 * DAY, source: 'lesson' },
      { characterId: 42, name: 'Aldric Ferrand', learnedAt: NOW - 400 * DAY, source: 'lesson' },
      { characterId: 3, name: 'Guillemette l\'Ancienne', learnedAt: NOW - 900 * DAY, source: 'founder' },
    ] },
    lame_runique: { recipe: 'lame_runique', label: 'Lame runique', chain: [
      { characterId: 7, name: 'Corwin le Roux', learnedAt: NOW - 20 * DAY, source: 'fragments' },
    ] },
    pain_des_moines: { recipe: 'pain_des_moines', label: 'Pain des moines', chain: [
      { characterId: 7, name: 'Corwin le Roux', learnedAt: NOW - 200 * DAY, source: 'founder' },
    ] },
  };

  const nearby = [
    { serverId: 12, name: 'Perrin Lavoie', distance: 2.4 },
    { serverId: 19, name: 'Ysolde Marchant', distance: 6.1 },
  ];

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 80));
    if (name === 'setMode') {
      const entry = sheet.skills.find((skill) => skill.id === data.skill);
      if (!entry) return { ok: false, error: 'unknown_skill' };
      entry.mode = data.mode;
      return { ok: true, skill: { ...entry }, budget: sheet.budget };
    }
    if (name === 'nearby') return { ok: true, players: nearby };
    if (name === 'propose') {
      if (data.skill === 'forge') return { ok: false, error: 'full' };
      return { ok: true };
    }
    if (name === 'answer') {
      sheet.proposals = sheet.proposals.filter((proposal) => proposal.id !== data.id);
      if (data.accept) {
        const herbo = sheet.skills.find((skill) => skill.id === 'herboristerie');
        herbo.mentor = { mentorshipId: 31, characterId: 58, name: 'Brunehilde Vastel', since: NOW, online: true };
      }
      return { ok: true };
    }
    if (name === 'break') {
      for (const entry of sheet.skills) {
        if (entry.mentor && entry.mentor.mentorshipId === data.mentorshipId) entry.mentor = null;
        entry.apprentices = entry.apprentices.filter((apprentice) => apprentice.mentorshipId !== data.mentorshipId);
      }
      return { ok: true };
    }
    if (name === 'lineage') {
      const lineage = lineages[data.recipe];
      return lineage ? { ok: true, lineage } : { ok: false, error: 'unknown_recipe' };
    }
    if (name === 'shortages') return { ok: true, shortages: sheet.shortages };
    if (name === 'refresh') return { ok: true, sheet: JSON.parse(JSON.stringify(sheet)) };
    return { ok: true };
  }

  if (!inGame) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('dev');
      const tab = new URLSearchParams(window.location.search).get('tab');
      window.postMessage({ action: 'open', payload: JSON.parse(JSON.stringify(sheet)) }, '*');
      if (tab) setTimeout(() => App.show(tab), 0);
    });
  }

  return { handle, inGame };
})();
