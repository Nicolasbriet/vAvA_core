'use strict';
/*
 * web/dev/devmock.js
 * Rôle : jauges, notifications et progression simulées quand la page est ouverte dans un navigateur (hors FiveM), pour
 *        travailler le rendu sans lancer le jeu. Jamais livré (absent des `files`), jamais chargé en jeu : la ligne
 *        hors jeu de index.html ne l'insère que hors FiveM. Paramètres d'URL : ?values=0.8,0.62,0.08,0.5 (santé,
 *        faim, soif, voix), ?talking=1 (lueur du médaillon de la voix), ?progress=1 (barre de progression de 8 s menée
 *        à son terme) ou ?progress=cancel (interrompue à 60 %). Réglages de la bannière (1.5.0) : ?scale=90|100|115
 *        (taille de l'interface), ?notify=courte|normale|longue (durée des notifications : 0,6, 1 ou 1,6 × 4,5 s ; sans
 *        ce paramètre, les notifications simulées restent à l'écran).
 */

(() => {
  if (typeof GetParentResourceName === 'function') return;
  const icon = (resource, name) => `../../${resource}/web/icons/${name}.svg`;
  window.addEventListener('DOMContentLoaded', () => {
    document.body.classList.add('dev');
    const params = new URLSearchParams(window.location.search);
    const values = (params.get('values') || '0.8,0.62,0.24,0.5').split(',').map(Number);
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
    // réglages de la bannière, envoyés comme le ferait client/main.lua (échelle et durée déjà calculées)
    const factors = { courte: 0.6, normale: 1, longue: 1.6 };
    if (params.get('scale') || factors[params.get('notify')]) {
      window.postMessage({ action: 'settings', payload: {
        scale: (Number(params.get('scale')) || 100) / 100,
        durationMs: factors[params.get('notify')] ? 4500 * factors[params.get('notify')] : undefined,
      } }, '*');
    }
    if (params.get('talking') === '1') {
      window.postMessage({ action: 'active', payload: { id: 'vava_voice:voice', active: true } }, '*');
    }
    const progressMode = params.get('progress');
    if (progressMode) {
      const durationMs = 8000;
      window.postMessage({ action: 'progress', payload: {
        id: 'vava_gathering:chop', label: 'Vous abattez un chêne', durationMs, elapsedMs: 0,
        cancelable: true, hint: 'Peut être interrompue',
      } }, '*');
      const cancelled = progressMode === 'cancel';
      setTimeout(() => window.postMessage({ action: 'progressEnd', payload: { id: 'vava_gathering:chop', done: !cancelled } }, '*'),
        cancelled ? durationMs * 0.6 : durationMs);
    }
    const samples = [
      ['Vous avez la gorge sèche.', 'info'],
      ['La faim vous affaiblit : vous ne tenez plus la course.', 'warning'],
      ['Personne n\'est à terre près de vous.', 'danger'],
    ];
    samples.forEach(([message, kind], i) => window.postMessage({ action: 'notify', payload: { id: i + 1, message, kind } }, '*'));
  });
})();
