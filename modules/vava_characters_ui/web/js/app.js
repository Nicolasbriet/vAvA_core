'use strict';
/*
 * web/js/app.js
 * Rôle : assemblage : écrans, messages du jeu (ouverture, fermeture), raccourcis clavier.
 */

(() => {
  const app = document.getElementById('app');
  const screens = {
    selection: document.getElementById('screen-selection'),
    creator: document.getElementById('screen-creator'),
  };
  let current = null;

  function show(name) {
    current = name;
    for (const [key, node] of Object.entries(screens)) node.hidden = key !== name;
  }

  function showSelection(result) {
    if (!result || !result.ok) {
      Feedback.show(errorMessage(result && result.error));
      return;
    }
    show('selection');
    Selection.render(result);
    // règles de nom du serveur, arrivées avec la liste : l'éditeur vérifie la saisie comme lui
    Creator.setNameRules(result.nameRules);
  }

  Feedback.init();

  Selection.init(screens.selection, {
    async onPlay(character) {
      const result = await Bridge.post('play', { id: character.id });
      // en cas de succès, le jeu ferme l'écran
      if (!result.ok) Feedback.show(errorMessage(result.error));
    },
    async onDelete(character) {
      const S = STRINGS.selection;
      const confirmed = await Feedback.confirm({
        title: S.deleteTitle, message: S.deleteMessage(`${character.firstName} ${character.lastName}`),
        confirmLabel: S.deleteConfirm, cancelLabel: STRINGS.creator.keep, danger: true,
      });
      if (!confirmed) return;
      const result = await Bridge.post('delete', { id: character.id });
      if (!result.ok) {
        Feedback.show(errorMessage(result.error));
        return;
      }
      showSelection(result);
    },
    async onCreate() {
      const result = await Bridge.post('startCreator', { sex: 'm' });
      if (!result.ok) {
        Feedback.show(errorMessage(result.error));
        return;
      }
      show('creator');
      Creator.open(result);
    },
  });

  Creator.init(screens.creator, {
    onCancelled: showSelection,
    async onCreated() {
      // en jeu, la sélection du nouveau personnage ferme l'écran ; hors jeu, retour à la liste simulée
      if (!Bridge.inGame) showSelection(await Bridge.post('list'));
    },
    onError: (code) => Feedback.show(errorMessage(code)),
  });

  /** Hors jeu : ouverture directe d'un écran (?screen=creator&tab=hair&sex=f) pour travailler le rendu. */
  async function devStart() {
    const params = new URLSearchParams(window.location.search);
    if (params.get('screen') !== 'creator') return;
    const result = await Bridge.post('startCreator', { sex: params.get('sex') || 'm' });
    show('creator');
    Creator.open(result, params.get('tab'));
  }

  Bridge.onMessage((action, payload) => {
    if (action === 'open') {
      app.hidden = false;
      showSelection(payload);
      if (!Bridge.inGame) devStart();
    } else if (action === 'close') {
      Feedback.closeModal(false);
      app.hidden = true;
      show(null);
    }
  });

  document.addEventListener('keydown', (event) => {
    if (app.hidden) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      if (Feedback.isModalOpen()) Feedback.closeModal(false);
      else if (current === 'creator') Creator.cancel();
      return;
    }
    const typing = event.target instanceof HTMLInputElement && event.target.type === 'text';
    if (current !== 'creator' || typing || Feedback.isModalOpen()) return;
    const key = event.key.toLowerCase();
    if (key === 'q') Creator.rotateBy(-1);
    if (key === 'e') Creator.rotateBy(1);
  });
})();
