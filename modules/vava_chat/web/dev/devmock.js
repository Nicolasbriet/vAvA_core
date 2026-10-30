'use strict';
/*
 * web/dev/devmock.js
 * Rôle : aperçu de l'interface dans un navigateur, hors du jeu (sans effet en jeu) : web/index.html?view=<vue> avec
 *        passive (chat fermé), open (Général), actions, mp, gone (correspondant parti), staff, suggest, all.
 *        Les textes ci-dessous ne sont qu'une copie d'aperçu : en jeu, ils viennent de config.lua.
 *        Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère
 *        que hors FiveM.
 */

window.DevMock = (() => {
  if (Bridge.inGame) return null;
  const posted = [];

  const TEXTS = {
    tabs: { general: 'Général', actions: 'Actions', staff: 'Conseil' },
    tags: { ooc: 'HRP', mp: 'MP', staff: 'Conseil', system: 'Royaume' },
    me: '* %s %s *',
    do: '* %s * (%s)',
    mpFrom: 'De %s',
    mpTo: 'À %s',
    you: 'Vous',
    staffBadge: 'Conseil',
    placeholder: {
      general: 'Hors-RP… ou /me, /do, /mp', actions: '/me une action, /do une description', mp: 'Écrire à %s…',
      gone: '%s est parti.', staff: 'Au Conseil…',
    },
    closeTab: 'Fermer la conversation',
    moveHint: 'Saisir pour déplacer',
    resizeHint: 'Tirer pour agrandir',
    counter: '%d / %d',
    hint: 'Entrée : envoyer · Échap : fermer · ↑ ↓ : historique · Tab : compléter',
  };

  const SETTINGS = {
    maxLength: 250, inputMax: 290, maxMessages: 200, historyMax: 30, fadeMs: 600000, suggestionsMax: 6,
    minSize: { w: 300, h: 180 }, defaultLayout: { x: 0.015, y: 0.22, w: 0.3, h: 0.34 }, mpCommand: 'mp',
  };

  const SUGGESTIONS = [
    { name: 'ooc', help: 'Hors-RP, aux joueurs proches', params: [{ name: 'message', help: 'le message' }] },
    { name: 'mp', help: 'Message privé à un joueur', params: [{ name: 'n°', help: 'numéro du joueur' }, { name: 'message', help: 'le message' }] },
    { name: 'me', help: 'Une action de votre personnage', params: [{ name: 'action', help: 'ex. : tire son épée' }] },
    { name: 'do', help: 'Une description de la scène', params: [{ name: 'description', help: 'ex. : la porte est verrouillée' }] },
    { name: 'staff', help: 'Canal du Conseil', params: [{ name: 'message', help: 'le message' }] },
    { name: 'signaler', help: 'Signaler un problème au Conseil', params: [{ name: 'motif', help: 'ce qui se passe' }] },
  ];

  const MESSAGES = [
    { kind: 'system', author: 'Magie', text: 'Vous apprenez le sort Lueur (niveau 1).' },
    { kind: 'ooc', id: 12, name: 'Aldric Morvan', text: 'Quelqu\'un sait où se trouve la forge du village ?' },
    { kind: 'me', id: 7, name: 'Isaure de Valcourt', text: 'pose sa lanterne sur la table et dégaine lentement sa dague' },
    { kind: 'do', id: 12, name: 'Aldric Morvan', text: 'La porte de la taverne est verrouillée de l\'intérieur' },
    { kind: 'ooc', id: 3, name: 'Gautier Belleval', staff: true, text: 'Pensez à lire le règlement avant la session de ce soir.' },
    { kind: 'mp', id: 7, chat: 41, name: 'Isaure de Valcourt', text: 'Retrouve-moi derrière l\'église à la tombée de la nuit.' },
    { kind: 'mp', out: true, id: 7, chat: 41, name: 'Isaure de Valcourt', text: 'J\'y serai, seul.' },
    { kind: 'me', id: 5, name: 'Vous-même', text: 'ajuste sa cape et salue d\'un signe de tête' },
  ];

  const STAFF = [
    { kind: 'staff', id: 3, name: 'Gautier Belleval', rank: 'Sénéchal', text: 'Un joueur signale un bug au moulin, j\'y vais.' },
    { kind: 'staff', id: 5, name: 'Vous-même', rank: 'Gardien', text: 'Bien reçu, je surveille la place.' },
  ];

  function answer(name, body) {
    posted.push({ name, body });
    if (name === 'submit') {
      const text = body.text || '';
      if (!text.startsWith('/')) {
        const kind = body.tab === 'mp' ? 'mp' : body.tab === 'staff' ? 'staff' : 'ooc';
        if (body.tab === 'actions') Bridge.emit('notice', { tab: 'actions', text: 'Ici, commencez par /me (une action) ou /do (une description).' });
        else Bridge.emit('message', { kind, id: 5, name: 'Vous-même', text, out: kind === 'mp', chat: body.chat, rank: 'Gardien' });
      }
    }
    return { ok: true };
  }

  function boot(view) {
    document.body.classList.add('dev');
    Bridge.emit('init', { texts: TEXTS, settings: SETTINGS });
    Bridge.emit('layout', SETTINGS.defaultLayout);
    Bridge.emit('profile', { id: 5, staff: view === 'staff' || view === 'all', rank: 'Gardien' });
    Bridge.emit('suggestions', { list: SUGGESTIONS });
    Bridge.emit('commands', { names: ['e', 'emote', 'signaler', 'sigil'] });
    for (const message of MESSAGES) Bridge.emit('message', message);
    if (view === 'staff' || view === 'all') for (const message of STAFF) Bridge.emit('message', message);
    Bridge.emit('notice', { tab: 'general', text: 'Aucun joueur en jeu sous ce numéro.' });
    if (view === 'passive') return;
    Bridge.emit('open');
    if (view === 'actions') Tabs.activate('actions');
    if (view === 'mp' || view === 'gone' || view === 'all') Tabs.activate('mp:41');
    if (view === 'gone') Bridge.emit('gone', { chat: 41 });
    if (view === 'staff') Tabs.activate('staff');
    if (view === 'suggest') {
      const input = document.getElementById('composer-input');
      input.value = '/m';
      input.dispatchEvent(new Event('input'));
    }
  }

  const view = new URLSearchParams(window.location.search).get('view');
  if (view) window.addEventListener('load', () => boot(view));

  return { answer, posted, boot };
})();
