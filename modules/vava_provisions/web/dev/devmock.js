'use strict';
/*
 * web/dev/devmock.js
 * Rôle : invite simulée quand la page est ouverte dans un navigateur (hors FiveM). Paramètres d'URL :
 *        ?label=Puits%20du%20lavoir&verb=Puiser&key=E (une invite fixe ; label ou verb seul suffit) ; sans paramètre,
 *        les invites se succèdent toutes les 3 s (puiser ou boire, puiser seul, nom long, invite cachée), en boucle.
 *        Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère que
 *        hors FiveM.
 */

(() => {
  if (typeof GetParentResourceName === 'function') return;
  const post = (message) => window.postMessage({ action: 'prompt', ...message }, '*');
  const examples = [
    { key: 'E', verb: 'Puiser ou boire', label: 'Fontaine du bourg' },
    { key: 'E', verb: 'Puiser', label: 'Puits du lavoir' },
    { key: 'E', verb: 'Puiser ou boire', label: 'Source de la Rivière Claire, sous les saules' },
    { hidden: true },
  ];

  window.addEventListener('DOMContentLoaded', () => {
    document.body.classList.add('dev');
    const params = new URLSearchParams(window.location.search);
    if (params.has('label') || params.has('verb')) {
      post({ key: params.get('key') || 'E', verb: params.get('verb') || '', label: params.get('label') || '' });
      return;
    }
    let index = 0;
    const next = () => {
      post(examples[index]);
      index = (index + 1) % examples.length;
      setTimeout(next, 3000);
    };
    next();
  });
})();
