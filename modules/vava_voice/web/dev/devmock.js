'use strict';
/*
 * web/dev/devmock.js
 * Rôle : aperçu de l'éditeur dans un navigateur, sans le jeu : fond de scène, zones d'exemple, réponses simulées.
 *        Inactif en jeu. Paramètre d'URL : ?zone=<numéro> ouvre directement la zone.
 *        Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère
 *        que hors FiveM.
 */

const DevMock = (() => {
  const ZONES = [
    { id: 1, label: 'Salle du trône', radius: 18, height: 9, multiplier: 2, distance: 6 },
    { id: 2, label: 'Bibliothèque de l\'abbaye', radius: 12, height: 5, multiplier: 0.5, distance: 42 },
    { id: 3, label: 'Place du marché', radius: 35, height: 12, multiplier: 1.5, distance: 120 },
    { id: 4, label: 'Chambre du roi', radius: 4, height: 4, multiplier: 1, distance: 9 },
  ];
  const LIMITS = {
    radius: { min: 2, max: 60, default: 10, step: 0.5 },
    height: { min: 2, max: 30, default: 6, step: 0.5 },
    multipliers: [0.5, 0.75, 1, 1.5, 2, 3], defaultMultiplier: 2, labelMax: 40, max: 200, baseOffset: 1,
    ranges: [
      { name: 'whisper', label: 'Chuchoter', distance: 1.5 },
      { name: 'talk', label: 'Parler', distance: 5 },
      { name: 'shout', label: 'Crier', distance: 15 },
      { name: 'declaim', label: 'Déclamer', distance: 25 },
    ],
  };
  let nextId = 5;

  function send(action, payload) {
    window.postMessage({ action, payload }, '*');
  }

  async function handle(name, data) {
    if (name === 'save') {
      if (data.id) {
        const zone = ZONES.find((z) => z.id === data.id);
        Object.assign(zone, { label: data.label, radius: data.radius, height: data.height, multiplier: data.multiplier });
      } else {
        ZONES.unshift({ id: nextId, label: data.label, radius: data.radius, height: data.height, multiplier: data.multiplier, distance: 0 });
        nextId += 1;
      }
      setTimeout(() => send('zones', { zones: ZONES }), 50);
    } else if (name === 'delete') {
      ZONES.splice(ZONES.findIndex((z) => z.id === data.id), 1);
      setTimeout(() => send('zones', { zones: ZONES }), 50);
    } else if (name === 'close') {
      setTimeout(() => send('close', {}), 10);
    }
    return { ok: true };
  }

  function start() {
    document.body.classList.add('dev');
    send('open', { zones: ZONES, canTeleport: true, limits: LIMITS });
    const zone = new URLSearchParams(location.search).get('zone');
    if (zone) {
      setTimeout(() => {
        const node = [...document.querySelectorAll('.entry')][Number(zone) - 1];
        if (node) node.click();
      }, 120);
    }
  }

  return { handle, start };
})();
