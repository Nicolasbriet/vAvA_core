'use strict';
/*
 * vava_pause/web/js/nav.js
 * Rôle : clavier et manette. Trois niveaux : les rubriques de la bannière, le panneau, le dialogue Quitter (focus
 *        piégé). Clavier : ↑ ↓ rubriques ; Entrée ou → entrer ; Tab / Maj+Tab dans le panneau ; ← ou Retour arrière
 *        (hors champ) revenir aux rubriques ; ← → sur les signets et entre des tampons ; Échap ferme la bannière (dans
 *        le dialogue : Rester). Manette (messages `nav` du jeu, sur appui seulement) : croix, A choisir, B revenir
 *        (aux rubriques : reprendre), LB / RB signets, Start reprendre. Aucune boucle : tout part d'un évènement.
 * Dépendances : views.js ; les actions sont fournies par app.js
 */

const PauseNav = (() => {
  let app = null;
  let refs = null;
  let actions = null;
  let isDialog = () => false;

  function init(options) {
    ({ app, refs, actions } = options);
    isDialog = options.isDialog;
    document.addEventListener('keydown', onKey);
    app.addEventListener('mousedown', () => app.classList.add('is-pointer'));
  }

  const visible = (node) => node.getClientRects().length > 0;

  function focusables(container) {
    return Array.from(container.querySelectorAll('button, textarea'))
      .filter((node) => !node.disabled && node.tabIndex >= 0 && visible(node));
  }

  function level() {
    if (isDialog()) return 'dialog';
    const active = document.activeElement;
    if (active && refs.leaf.contains(active)) return 'panel';
    return 'rubrics';
  }

  function focus(node) {
    if (node) node.focus({ preventScroll: false });
    return Boolean(node);
  }

  // Rubriques ---------------------------------------------------------------------------------------------

  /** Focus sur une entrée de la bannière (sinon sur l'entrée active, sinon la première). */
  function toRubrics(id) {
    const buttons = PauseViews.navButtons();
    const wanted = buttons.find((node) => node.dataset.id === id) || buttons.find((node) => node.classList.contains('is-active')) || buttons[0];
    return focus(wanted);
  }

  function moveEntry(delta) {
    const buttons = PauseViews.navButtons();
    if (buttons.length === 0) return;
    const index = buttons.indexOf(document.activeElement);
    const next = buttons[(index === -1 ? 0 : index + delta + buttons.length) % buttons.length];
    focus(next);
    actions.preview(next.dataset.id);
    // la bannière a pu être refaite par l'aperçu : on retrouve le même bouton
    if (!next.isConnected) toRubrics(next.dataset.id);
  }

  const focusedEntry = () => (document.activeElement && document.activeElement.classList.contains('bn') ? document.activeElement.dataset.id : null);

  // Panneau -----------------------------------------------------------------------------------------------

  /** Entre dans le panneau : premier élément utile (la croix seulement s'il n'y a qu'elle). */
  function enterPanel() {
    if (refs.tome.hidden) return false;
    const list = focusables(refs.leaf);
    return focus(list.find((node) => !node.classList.contains('cross')) || list[0]);
  }

  function movePanel(delta) {
    const list = focusables(refs.leaf);
    if (list.length === 0) return;
    const index = list.indexOf(document.activeElement);
    focus(list[(index === -1 ? 0 : index + delta + list.length) % list.length]);
  }

  /** ← → dans un groupe de tampons ; rend false au bord gauche (on revient alors aux rubriques). */
  function moveInGroup(target, delta) {
    const group = target.closest('.stamps');
    if (!group) return false;
    const list = focusables(group);
    const index = list.indexOf(target);
    const next = list[index + delta];
    if (next) return focus(next);
    return delta > 0;
  }

  function moveDialog(delta) {
    const list = focusables(refs.dialog);
    if (list.length === 0) return;
    const index = list.indexOf(document.activeElement);
    focus(list[(index === -1 ? 0 : index + delta + list.length) % list.length]);
  }

  const isRibbon = (node) => Boolean(node && node.classList && node.classList.contains('ribbon'));

  // Clavier -----------------------------------------------------------------------------------------------

  function onKey(event) {
    if (app.hidden || app.classList.contains('is-native')) return;
    app.classList.remove('is-pointer');
    actions.gamepad(false);
    const key = event.key;
    const target = event.target;
    const inField = target && target.tagName === 'TEXTAREA';
    const where = level();

    if (key === 'Escape') {
      event.preventDefault();
      if (where === 'dialog') actions.stay();
      else actions.close();
      return;
    }
    if (where === 'dialog') {
      if (key === 'Tab' || key.startsWith('Arrow')) {
        event.preventDefault();
        moveDialog(key === 'ArrowUp' || key === 'ArrowLeft' || (key === 'Tab' && event.shiftKey) ? -1 : 1);
      }
      return;
    }
    if (where === 'rubrics') {
      if (key === 'ArrowDown' || key === 'ArrowUp') {
        event.preventDefault();
        moveEntry(key === 'ArrowDown' ? 1 : -1);
      } else if (key === 'Enter' || key === 'ArrowRight' || key === ' ') {
        event.preventDefault();
        const id = focusedEntry();
        if (id) actions.activate(id, true);
        else toRubrics();
      } else if (key === 'Tab') {
        event.preventDefault();
        if (!enterPanel()) moveEntry(event.shiftKey ? -1 : 1);
      }
      return;
    }
    // panneau
    if (key === 'Tab') {
      event.preventDefault();
      movePanel(event.shiftKey ? -1 : 1);
      return;
    }
    if (inField) return;
    if (key === 'ArrowDown' || key === 'ArrowUp') {
      event.preventDefault();
      movePanel(key === 'ArrowDown' ? 1 : -1);
    } else if (key === 'ArrowLeft' || key === 'ArrowRight') {
      event.preventDefault();
      const delta = key === 'ArrowRight' ? 1 : -1;
      if (isRibbon(target)) actions.tab(delta);
      else if (!moveInGroup(target, delta) && delta < 0) toRubrics();
    } else if (key === 'Backspace') {
      event.preventDefault();
      toRubrics();
    }
  }

  // Manette -----------------------------------------------------------------------------------------------

  function dir(name) {
    if (app.hidden || app.classList.contains('is-native')) return;
    app.classList.remove('is-pointer');
    actions.gamepad(true);
    const where = level();
    const active = document.activeElement;
    if (name === 'resume') {
      actions.close();
      return;
    }
    if (name === 'prevTab' || name === 'nextTab') {
      if (where !== 'dialog') actions.tab(name === 'nextTab' ? 1 : -1);
      return;
    }
    if (where === 'dialog') {
      if (name === 'back') actions.stay();
      else if (name === 'accept') { if (active && refs.dialog.contains(active)) active.click(); else moveDialog(1); }
      else moveDialog(name === 'up' || name === 'left' ? -1 : 1);
      return;
    }
    if (where === 'rubrics') {
      if (name === 'up' || name === 'down') moveEntry(name === 'down' ? 1 : -1);
      else if (name === 'accept' || name === 'right') {
        const id = focusedEntry();
        if (id) actions.activate(id, true);
        else toRubrics();
      } else if (name === 'back') actions.close();
      return;
    }
    if (name === 'up' || name === 'down') movePanel(name === 'down' ? 1 : -1);
    else if (name === 'left' || name === 'right') {
      const delta = name === 'right' ? 1 : -1;
      if (isRibbon(active)) actions.tab(delta);
      else if (!moveInGroup(active, delta)) { if (delta < 0) toRubrics(); else movePanel(1); }
    } else if (name === 'accept') {
      if (active && active.tagName === 'BUTTON') active.click();
    } else if (name === 'back') toRubrics();
  }

  // Focus gardé d'un rendu à l'autre ---------------------------------------------------------------------

  const KEYS = ['act', 'id', 'key', 'index', 'kind', 'tab', 'mode'];
  // valeur d'attribut entre guillemets dans un sélecteur : seuls « " » et « \ » sont à échapper
  const quote = (value) => value.replace(/["\\]/g, (char) => `\\${char}`);

  /** Rend le panneau ou la bannière par `render`, puis remet le focus sur l'élément équivalent. */
  function keep(render) {
    const active = document.activeElement;
    const inApp = active && app.contains(active) && active !== document.body;
    const selector = inApp ? (active.tagName === 'TEXTAREA' ? 'textarea'
      : KEYS.filter((key) => active.dataset[key] !== undefined).map((key) => `[data-${key}="${quote(active.dataset[key])}"]`).join('')) : '';
    render();
    if (!selector || (active.isConnected && document.activeElement === active)) return;
    const again = app.querySelector(selector);
    if (again && !again.disabled) again.focus({ preventScroll: true });
    else if (refs.leaf.contains(active) || !active.isConnected) {
      if (!enterPanel()) toRubrics();
    }
  }

  return { init, dir, keep, toRubrics, enterPanel };
})();
