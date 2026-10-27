'use strict';
/*
 * web/js/devmock.js
 * Rôle : registre simulé quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans
 *        lancer le jeu. Inactif en jeu. Paramètres d'URL : ?tab=players|reports|bans|logs|staff|tools|announce,
 *        &dialog=ban, &proclaim=1, &watch=1.
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const params = new URLSearchParams(window.location.search);
  const players = [
    { source: 1, name: 'vAvA', accountId: 1, character: 'Aldric Morvan', ping: 18, rank: 'Souverain', frozen: false, downed: false },
    { source: 3, name: 'Eloise_42', accountId: 7, character: 'Éloïse d\'Aubigné', ping: 41, rank: null, frozen: false, downed: true },
    { source: 4, name: 'Bertrand', accountId: 9, character: 'Bertrand Dugarry', ping: 63, rank: 'Gardien', frozen: false, downed: false },
    { source: 6, name: 'Corwin', accountId: 12, character: 'Corwin le Roux', ping: 95, rank: null, frozen: true, downed: false },
    { source: 8, name: 'newcomer', accountId: 15, character: null, ping: 30, rank: null, frozen: false, downed: false },
  ];
  const detail = (source) => {
    const p = players.find((x) => x.source === source) || players[0];
    return {
      ...p, rankLabel: p.rank, rank: p.rank ? p.rank.toLowerCase() : null, characterId: 30 + source,
      position: { x: 215.4, y: -810.2, z: 30.7 },
      health: { health: p.downed ? 0 : 0.72, downed: p.downed }, needs: { hunger: 64.5, thirst: 38.2 },
      warnings: source === 3 ? [
        { id: 4, reason: 'Conduite à contresens dans la grand-rue.', actor_label: 'Gardien Bertrand Dugarry', created: '24/10/2026 21:14' },
        { id: 2, reason: 'Insultes hors du jeu de rôle.', actor_label: 'Souverain Aldric Morvan', created: '19/10/2026 18:02' },
      ] : [],
    };
  };
  const responses = {
    players: () => players,
    player: (args) => detail(args[0]),
    reports: () => [
      { id: 12, source: 3, accountId: 7, author: 'Éloïse d\'Aubigné', message: 'Un joueur me bloque à la porte de l\'auberge depuis dix minutes.', ageMs: 240000, claimedBy: null },
      { id: 11, source: 6, accountId: 12, author: 'Corwin le Roux', message: 'Je suis coincé sous le pont de la rivière.', ageMs: 1500000, claimedBy: 'Gardien Bertrand Dugarry' },
    ],
    bans: () => [
      { id: 7, account_id: 21, target_label: 'Mordred Vane', reason: 'Triche (vol libre).', actor_label: 'Souverain Aldric Morvan', created: '25/10/2026 22:10', until: null },
      { id: 6, account_id: 18, target_label: 'Gaspard Fol', reason: 'Harcèlement répété après avertissements.', actor_label: 'Sénéchal Isolde Varenne', created: '24/10/2026 19:44', until: '31/10/2026 19:44' },
    ],
    logs: () => [
      { id: 90, actor_label: 'Souverain Aldric Morvan', action: 'ban', target_label: 'Mordred Vane', details: 'ban : 7 ; duree : définitif ; motif : Triche (vol libre).', created: '25/10/2026 22:10' },
      { id: 89, actor_label: 'Gardien Bertrand Dugarry', action: 'heal', target_label: 'Éloïse d\'Aubigné', details: 'releve : oui', created: '25/10/2026 21:58' },
      { id: 88, actor_label: 'Gardien Bertrand Dugarry', action: 'reportClaim', target_label: 'Corwin le Roux', details: 'signalement : 11', created: '25/10/2026 21:40' },
      { id: 87, actor_label: 'Console', action: 'staffGrant', target_label: 'compte n° 9', details: 'rang : gardien', created: '25/10/2026 20:12' },
    ],
    staff: () => [
      { accountId: 1, rank: 'souverain', rankLabel: 'Souverain', level: 3, source: 1, character: 'Aldric Morvan' },
      { accountId: 30, rank: 'senechal', rankLabel: 'Sénéchal', level: 2, source: null, character: null },
      { accountId: 9, rank: 'gardien', rankLabel: 'Gardien', level: 1, source: 4, character: 'Bertrand Dugarry' },
    ],
    tool: (args) => ({ noclip: args[0] === 'noclip' ? args[1] : false, invisible: args[0] === 'invisible' ? args[1] : false, godmode: false }),
  };

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 30));
    if (name !== 'request') return { ok: true };
    const respond = responses[data.name];
    return { ok: true, result: respond ? respond(data.args || []) : null };
  }

  if (!inGame) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('dev');
      const all = ['view', 'teleport', 'freeze', 'heal', 'message', 'warn', 'kick', 'reports', 'ban', 'inventory', 'give',
        'announce', 'tools', 'spectate', 'logs', 'bans', 'unban', 'staff'];
      window.postMessage({ action: 'open', payload: {
        self: 1, accountId: 1, rank: { name: 'souverain', label: 'Souverain', level: 3 }, permissions: all,
        ranks: [{ name: 'gardien', label: 'Gardien', level: 1 }, { name: 'senechal', label: 'Sénéchal', level: 2 }, { name: 'souverain', label: 'Souverain', level: 3 }],
        banDurations: [1, 6, 24, 72, 168, 720, 0], pageSize: 50, tools: { noclip: false, invisible: true, godmode: false },
        moduleTools: [{ key: 'vava_voice:zones', label: 'Zones de voix', hint: 'Lieux où la voix porte plus ou moins loin.' }],
      } }, '*');
      const tab = params.get('tab');
      setTimeout(() => {
        if (tab) document.querySelector(`.ribbon[data-tab="${tab}"]`)?.click();
        setTimeout(() => {
          if (tab === 'players' || !tab) document.querySelectorAll('.entry')[1]?.click();
          if (params.get('dialog') === 'ban') setTimeout(() => [...document.querySelectorAll('.seal-button')].find((b) => b.textContent === 'Bannir')?.click(), 120);
        }, 120);
      }, 60);
      if (params.get('proclaim') === '1') {
        window.postMessage({ action: 'announce', payload: { text: 'Le grand marché ouvrira ses portes demain à l\'aube, place du château.', author: 'Souverain', durationMs: 600000 } }, '*');
      }
      if (params.get('watch') === '1') window.postMessage({ action: 'spectate', payload: { active: true, label: 'Corwin le Roux', key: 'F10' } }, '*');
    });
  }

  return { handle };
})();
