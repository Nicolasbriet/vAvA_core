'use strict';
/*
 * vava_pause/web/dev/devmock.js
 * Rôle : la bannière simulée quand la page est ouverte dans un navigateur (hors FiveM). Jamais livré (absent des
 *        `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère que hors FiveM.
 *        Paramètres d'URL (combinables) :
 *          ?rubric=personnage|codex|carte|reglages|conseil|quitter   rubrique montrée (codex : panneau du Codex simulé,
 *                                                                   quitter : dialogue ouvert)
 *          &tab=interface|voix|touches       signet des Réglages
 *          &guild=1                          bannière aux couleurs d'une confrérie
 *          &request=sent|claimed|closed      encart de la dernière demande au Conseil
 *          &loading=1                        réponse du serveur jamais arrivée (« Le registre se consulte… »)
 *          &nodata=1                         réponse en échec (« Le registre ne répond pas. »)
 *          &refused=combat                   refus arrivé après le déroulé : la bannière se replie
 *          &downed=1                         à terre : bannière réduite (Reprendre, Paramètres du jeu, Quitter)
 *          &gamepad=1                        manette (pied « B pour reprendre »)
 *          &scale=90|100|115                 taille de l'interface
 *          &novice=1                         nouveau venu (tous les savoir-faire au rang Novice)
 *          &council=0  &voice=0  &codex=0    Conseil, voix ou Codex absents
 *          &slow=1                           réponse du serveur 800 ms après le déroulé (message `data`)
 *          &motion=0                         sans animation (open.rollMs = 0)
 *        Touches de la manette simulées : 8 2 4 6 (pavé numérique) = croix, 5 = A, 0 = B, 7 / 9 = LB / RB.
 *        Échap ferme : la page se rouvre par un clic n'importe où.
 */

const DevMock = (() => {
  if (typeof GetParentResourceName === 'function') return { handle: async () => ({ ok: false }) };
  const params = new URLSearchParams(window.location.search);
  const flag = (name) => params.get(name) === '1';
  const post = (action, payload) => window.postMessage({ action, payload }, '*');
  const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const RUBRICS = ['personnage', 'codex', 'carte', 'reglages', 'conseil', 'quitter'];
  const wanted = RUBRICS.includes(params.get('rubric')) ? params.get('rubric') : 'personnage';

  const skills = [
    ['herboristerie', 'Herboristerie', 46], ['alchimie', 'Alchimie', 31], ['cuisine', 'Cuisine', 22],
    ['agriculture', 'Agriculture', 12], ['bucheronnage', 'Bûcheronnage', 9], ['minage', 'Minage', 7],
    ['forge', 'Forge', 5], ['peche', 'Pêche', 4], ['couture', 'Couture', 3], ['tannerie', 'Tannerie', 2],
    ['menuiserie', 'Menuiserie', 2], ['arcanes', 'Arcanes', 1], ['chasse', 'Chasse', 0],
  ];
  const RANKS = [['novice', 'Novice', 0], ['apprenti', 'Apprenti', 20], ['compagnon', 'Compagnon', 40], ['artisan', 'Artisan', 60], ['maitre', 'Maître', 80], ['grand_maitre', 'Grand Maître', 95]];
  const rankOf = (level) => RANKS.filter((rank) => level >= rank[2]).pop();
  const skillRows = () => skills.map(([id, label, level]) => {
    const lvl = flag('novice') ? Math.min(level, 15) : level;
    const [rank, rankLabel] = rankOf(lvl);
    return { id, label, level: lvl, rank, rankLabel };
  });

  const keys = [
    { name: 'vava_pause', label: 'Déployer la bannière du royaume', chapter: 'Royaume', module: 'vava_pause', key: 'ESCAPE', keyDisplay: 'Échap ou P' },
    { name: 'codex', label: 'Ouvrir le Codex', chapter: 'Codex', module: 'vava_codex', key: 'F1' },
    { name: 'vava_inventory', label: 'Ouvrir l\'inventaire', chapter: 'Inventaire', module: 'vava_inventory', key: 'I' },
    { name: 'vava_inventory_slot', label: 'Raccourcis de la ceinture (5 emplacements)', chapter: 'Inventaire', module: 'vava_inventory', key: '1', keyDisplay: '1 à 5' },
    { name: 'vava_skills', label: 'Ouvrir le livre des compétences', chapter: 'Compétences', module: 'vava_skills', key: 'K' },
    { name: 'vava_gathering_interact', label: 'Récolter (nœud proche)', chapter: 'Récolte', module: 'vava_gathering', key: 'E', hold: true },
    { name: 'vava_magic_roue', label: 'Magie : roue des sorts', chapter: 'Magie', module: 'vava_magic', key: 'TAB', keyDisplay: 'Tab', hold: true },
    { name: 'vava_voice_portee', label: 'Changer la portée de la voix', chapter: 'Voix', module: 'vava_voice', key: 'Z' },
    // un libellé hostile reste du texte : il ne doit jamais devenir du HTML
    { name: 'essai_injection', label: '<img src=x onerror="document.body.dataset.pwned=1">', chapter: 'Essais', module: 'essai', key: 'F9' },
  ];
  const requests = {
    sent: { id: 12, kind: 'question', state: 'sent', age: 190 },
    claimed: { id: 12, kind: 'question', state: 'claimed', age: 600 },
    closed: { id: 11, kind: 'bug', state: 'closed', age: 300 },
  };
  const defs = [
    { key: 'ui.scale', tab: 'interface', kind: 'choice', default: 100, choices: [90, 100, 115], labels: ['90 %', '100 %', '115 %'], label: 'Taille de l\'interface', help: 'Plus lisible de loin, sur un grand écran.' },
    { key: 'hud.notifyDuration', tab: 'interface', kind: 'choice', default: 'normale', choices: ['courte', 'normale', 'longue'], labels: ['Courte', 'Normale', 'Longue'], label: 'Durée des notifications', help: 'Le temps qu\'un message reste à l\'écran.' },
    ...(params.get('voice') === '0' ? [] : [{ key: 'voice.circle', tab: 'voix', kind: 'lever', default: true, label: 'Cercle de portée au sol', help: 'Montre jusqu\'où porte votre voix quand vous en changez.' }]),
  ];
  const values = { 'ui.scale': Number(params.get('scale')) || 100, 'hud.notifyDuration': 'normale', 'voice.circle': true };

  function snapshot() {
    if (flag('downed')) return { downed: true, people: 28 };
    return {
      skills: skillRows(),
      guild: flag('guild') ? { label: 'Guérisseurs d\'Eldoria', short: 'Guérisseurs', grade: 'Soignante', cloth: '#2c4527', clothDark: '#1a2c17', field: '#5c1a12', charge: 'croix' } : null,
      people: 28,
      council: params.get('council') !== '0',
      request: requests[params.get('request')] || null,
      keysVersion: '1793404800-7',
      keys,
    };
  }

  function openMessage() {
    const message = {
      rubric: wanted === 'quitter' || wanted === 'codex' ? 'personnage' : wanted,
      downed: flag('downed'),
      local: {
        name: 'Elwen Corbel', health: 0.82, hunger: 64, thirst: 47,
        plaque: { time: 'Soir, 19 h', season: 'Automne' },
        voice: params.get('voice') === '0' ? null : { label: 'Parler', distance: 5 },
      },
      settings: { defs, values: { ...values } },
      keyLabels: { vava_skills: 'L' },
      resources: { codex: params.get('codex') !== '0', sheet: true, voice: params.get('voice') !== '0', council: params.get('council') !== '0' },
      closeKey: 'Échap',
      gamepad: flag('gamepad'),
      rollMs: params.get('motion') === '0' ? 0 : 250,
    };
    if (!flag('loading') && !flag('slow') && !flag('nodata')) message.data = snapshot();
    if (flag('nodata')) message.data = false;
    return message;
  }

  // Codex en panneau, simulé : cadre pointillé au rectangle de config_client.lua
  let frame = null;
  function codexFrame(on) {
    if (!frame) {
      frame = document.createElement('div');
      frame.textContent = 'Le Codex s\'affiche ici (vava_codex, mode panneau) — cliquez pour le refermer';
      Object.assign(frame.style, { position: 'fixed', left: '32.6vw', top: '10.7vh', width: '58.3vw', height: '71.1vh', display: 'grid', placeItems: 'center',
        border: '2px dashed #dcc08a', color: '#ece1c8', font: 'italic 20px Georgia, serif', background: 'rgba(20,14,9,.35)', cursor: 'pointer' });
      frame.addEventListener('click', () => { codexFrame(false); post('codexClosed', { rubric: 'personnage' }); });
      document.body.append(frame);
    }
    frame.hidden = !on;
  }

  async function openPage() {
    post('open', openMessage());
    if (flag('slow')) setTimeout(() => post('data', snapshot()), 800);
    if (params.get('refused')) setTimeout(() => post('refused', { reason: params.get('refused') }), 600);
    await wait(50);
    if (wanted === 'codex') document.querySelector('.bn[data-id="codex"]').click();
    if (wanted === 'quitter') document.querySelector('.bn[data-id="quitter"]').click();
    if (wanted === 'reglages' && params.get('tab')) document.querySelector(`.ribbon[data-tab="${params.get('tab')}"]`).click();
  }

  let council = 0;
  async function handle(name, data) {
    await wait(30);
    console.info('[devmock] rappel', name, data);
    if (name === 'close') return { ok: true };
    if (name === 'codex') {
      if (params.get('codex') === '0') return { ok: false, error: 'not_started' };
      codexFrame(true);
      return { ok: true };
    }
    if (name === 'map' || name === 'gameSettings' || name === 'keyBindings') {
      post('native', { hidden: true });
      setTimeout(() => post('native', { hidden: false }), 1500);
      return { ok: true };
    }
    if (name === 'sheet') {
      post('close', {});
      return { ok: true };
    }
    if (name === 'setting') {
      values[data.key] = data.value;
      return { ok: true, value: data.value };
    }
    if (name === 'resetSettings') {
      Object.assign(values, { 'ui.scale': 100, 'hud.notifyDuration': 'normale', 'voice.circle': true });
      return { ok: true, values: { ...values } };
    }
    if (name === 'council') {
      await wait(400);
      council += 1;
      if (council > 1) return { ok: false, error: 'too_soon', wait: 50 };
      return { ok: true, request: { id: 13, kind: data.kind, state: 'sent', age: 0 } };
    }
    if (name === 'leave') {
      await wait(400);
      return { ok: false, error: 'dev' };
    }
    return { ok: true };
  }

  function start() {
    document.body.classList.add('dev');
    openPage();
    document.addEventListener('click', () => { if (document.getElementById('app').hidden) openPage(); });
    const pad = { 8: 'up', 2: 'down', 4: 'left', 6: 'right', 5: 'accept', 0: 'back', 7: 'prevTab', 9: 'nextTab' };
    document.addEventListener('keydown', (event) => {
      if (event.code && event.code.startsWith('Numpad') && pad[event.code.slice(6)]) {
        event.preventDefault();
        event.stopImmediatePropagation();
        post('nav', { dir: pad[event.code.slice(6)] });
      }
    }, true);
  }
  if (document.readyState === 'loading') window.addEventListener('DOMContentLoaded', start);
  else setTimeout(start, 0);

  return { handle };
})();
