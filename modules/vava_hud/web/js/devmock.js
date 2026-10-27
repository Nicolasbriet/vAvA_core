'use strict';
/*
 * web/js/devmock.js
 * Rôle : jauges et notifications simulées quand la page est ouverte dans un navigateur (hors FiveM), pour travailler
 *        le rendu sans lancer le jeu. Inactif en jeu. Paramètres d'URL : ?values=0.8,0.62,0.08,0.5 (santé, faim, soif,
 *        voix) et ?talking=1 (lueur du médaillon de la voix).
 */

(() => {
  if (typeof GetParentResourceName === 'function') return;
  const icon = (resource, name) => `../../${resource}/web/icons/${name}.svg`;
  window.addEventListener('DOMContentLoaded', () => {
    document.body.classList.add('dev');
    const values = (new URLSearchParams(window.location.search).get('values') || '0.8,0.62,0.24,0.5').split(',').map(Number);
    const gauge = (id, label, order, value) => {
      const [resource, name] = id.split(':');
      return { id, label, icon: icon(resource, name), order, low: 0.3, critical: 0.1, value };
    };
    window.postMessage({ action: 'init', payload: {
      position: { left: '1.5vw', bottom: '3vh' },
      gauges: [
        gauge('vava_health:health', 'Santé', 5, values[0]),
        gauge('vava_needs:hunger', 'Faim', 10, values[1]),
        gauge('vava_needs:thirst', 'Soif', 20, values[2]),
        { ...gauge('vava_voice:voice', 'Voix', 40, values[3] ?? 0.5), low: 0, critical: 0 },
      ],
      visible: true,
      notifications: { durationMs: 600000, maxVisible: 4 },
    } }, '*');
    if (new URLSearchParams(window.location.search).get('talking') === '1') {
      window.postMessage({ action: 'active', payload: { id: 'vava_voice:voice', active: true } }, '*');
    }
    const samples = [
      ['Vous avez la gorge sèche.', 'info'],
      ['La faim vous affaiblit : vous ne tenez plus la course.', 'warning'],
      ['Personne n\'est à terre près de vous.', 'danger'],
    ];
    samples.forEach(([message, kind], i) => window.postMessage({ action: 'notify', payload: { id: i + 1, message, kind } }, '*'));
  });
})();
