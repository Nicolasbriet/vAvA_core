'use strict';
/*
 * web/js/chat.js
 * Rôle : états de la fenêtre : fermée (le fil Général paraît à chaque message puis s'efface au bout de `fadeMs`),
 *        ouverte (cadre, onglets, saisie ; Échap ferme), cachée (menu pause, écran noir, sélection du personnage).
 *        Un envoi part au jeu avec son onglet, puis le chat se ferme.
 */

const Chat = (() => {
  const node = document.getElementById('chat');
  let open = false;
  let fadeTimer = null;

  function fadeLater() {
    clearTimeout(fadeTimer);
    fadeTimer = setTimeout(() => {
      if (!open) node.classList.add('is-faded');
    }, UI.config().fadeMs || 12000);
  }

  /** Un message est arrivé : chat fermé, le fil reparaît puis s'efface. */
  function activity() {
    if (open) return;
    node.classList.remove('is-faded');
    fadeLater();
  }

  function show() {
    open = true;
    clearTimeout(fadeTimer);
    node.classList.remove('is-faded');
    node.classList.add('is-open');
    Tabs.setOpen(true);
    Composer.target(Tabs.current());
    Composer.focus();
  }

  /** Ferme le chat ; `notify` : le jeu rend le clavier et la souris (fermeture voulue par le joueur). */
  function hide(notify) {
    if (!open) return;
    open = false;
    node.classList.remove('is-open');
    Composer.clear();
    Tabs.setOpen(false);
    fadeLater();
    if (notify) Bridge.post('close');
  }

  /** Entrée : le texte part avec l'onglet d'où il est tapé (vide : le chat se ferme seulement). */
  function submit(value) {
    const tab = Tabs.current();
    if (value) Bridge.post('submit', { text: value, tab: tab.kind, chat: tab.kind === 'mp' ? tab.chat : undefined });
    hide(true);
  }

  function setVisible(visible) {
    node.classList.toggle('is-hidden', !visible);
  }

  function isOpen() {
    return open;
  }

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && open) {
      event.preventDefault();
      hide(true);
    }
  });

  return { show, hide, submit, activity, setVisible, isOpen };
})();
