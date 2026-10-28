'use strict';
/*
 * web/js/devmock.js
 * Rôle : données simulées quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu sans
 *        lancer le jeu. Inactif en jeu. Paramètre d'URL : ?view=prompt (invite, puis une variante sans outil et une
 *        variante épuisée), ?view=tension (barre de tension : tenir la touche E du clavier), ?view=zones (panneau).
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const zones = [
    { id: 'foret_brume', label: 'Forêt de Brume', kind: 'foret', vitality: 82, band: 'normal', scarred: false, distance: 36 },
    { id: 'riviere_claire', label: 'Rivière Claire', kind: 'eau', vitality: 47, band: 'reduced', scarred: false, distance: 210 },
    { id: 'mine_du_val', label: 'Mine du Val', kind: 'mine', vitality: 12, band: 'depleted', scarred: false, distance: 640 },
    { id: 'prairie_haute', label: 'Prairie Haute', kind: 'prairie', vitality: 3, band: 'depleted', scarred: true, distance: 1480 },
  ];
  const tension = { durationMs: 6000, zoneMin: 0.35, zoneMax: 0.65, drift: 0.12, pull: 0.9, gravity: 0.7, holdRatio: 0.6 };
  const post = (action, payload) => window.postMessage({ action, payload }, '*');

  async function handle(name, data) {
    await new Promise((resolve) => setTimeout(resolve, 60));
    if (name === 'tensionDone') {
      post('notify', { message: `Tenue : ${Math.round((data.ratio || 0) * 100)} % du temps dans la zone.`, kind: 'info' });
      return { ok: true };
    }
    if (name === 'zonesRefresh') return { ok: true, zones };
    if (name === 'close') {
      post('zonesClose', {});
      return { ok: true };
    }
    return { ok: true };
  }

  function prompt() {
    post('prompt', { key: 'E', anim: 'chop', label: 'Chêne', charges: 3, exhausted: false, zoneDepleted: false, toolKind: 'hache', toolOk: true });
    setTimeout(() => post('prompt', { key: 'E', anim: 'mine', label: 'Filon de fer', charges: 2, exhausted: false, zoneDepleted: true, toolKind: 'pioche', toolOk: false }), 3500);
    setTimeout(() => post('prompt', { key: 'E', anim: 'pick', label: 'Lavande', charges: 0, exhausted: true, zoneDepleted: false, toolKind: null, toolOk: true }), 7000);
    setTimeout(() => post('cast', { label: 'Banc de truites', key: 'E' }), 10500);
  }

  function tensionDemo() {
    post('tension', { token: 1, tension, key: 'E' });
    let held = false;
    document.addEventListener('keydown', (event) => {
      if (event.key.toLowerCase() === 'e' && !held) { held = true; post('tensionHold', { held: true }); }
    });
    document.addEventListener('keyup', (event) => {
      if (event.key.toLowerCase() === 'e') { held = false; post('tensionHold', { held: false }); }
    });
    // une nouvelle barre après le résultat, pour rejouer sans recharger
    const again = () => setTimeout(() => post('tension', { token: 1, tension, key: 'E' }), 2500);
    window.addEventListener('message', (event) => {
      if (event.data && event.data.action === 'notify') again();
    });
  }

  if (!inGame) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('dev');
      const view = new URLSearchParams(window.location.search).get('view') || 'prompt';
      if (view === 'tension') tensionDemo();
      else if (view === 'zones') post('zones', { zones, key: 'O' });
      else prompt();
    });
  }

  return { handle, inGame };
})();
