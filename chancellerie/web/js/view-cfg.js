'use strict';
/*
 * web/js/view-cfg.js
 * Rôle : l'éditeur du server.cfg, en texte brut sur une ardoise. Les secrets arrivent masqués (« ••••secret-1•••• »)
 *        et sont remis en place par la Chancellerie à l'enregistrement. Le fichier porte sa révision : s'il a changé
 *        entre-temps (assistant, autre onglet, à la main), l'écriture est refusée et l'éditeur propose de le
 *        recharger. Ctrl + S enregistre ; quitter la page avec des modifications non enregistrées demande confirmation
 *        au navigateur.
 */

const CfgView = (() => {
  const C = STRINGS.cfg;

  let sheet = null;
  let refs = null;
  let saved = '';
  let revision = '';
  let busy = false;

  const dirty = () => Boolean(refs) && refs.editor.value !== saved;

  function renderState() {
    if (!refs) return;
    const changed = dirty();
    refs.state.textContent = changed ? C.unsaved : C.clean;
    refs.state.classList.toggle('is-dirty', changed);
    refs.save.disabled = !changed || busy;
    refs.revert.disabled = !changed || busy;
  }

  function guard(event) {
    if (!dirty()) return;
    event.preventDefault();
    event.returnValue = '';
  }

  async function load() {
    const result = await API.get('/api/cfg');
    if (!sheet) return;
    if (!result.ok) {
      sheet.replaceChildren(UI.heading(C.title), UI.el('p', 'empty', result.error === 'paths_missing' ? C.noPaths : STRINGS.error(result.error)));
      return;
    }
    saved = result.text;
    revision = result.revision;
    refs.editor.value = result.text;
    refs.aside.textContent = `${result.file} · ${C.secrets(result.secrets)}`;
    refs.missing.hidden = result.exists;
    renderState();
  }

  async function save() {
    if (!dirty() || busy) return;
    busy = true;
    renderState();
    const text = refs.editor.value;
    const result = await API.post('/api/cfg/save', { text, revision });
    busy = false;
    if (!sheet) return;
    if (!result.ok) {
      if (result.error === 'cfg_changed') {
        refs.conflict.hidden = false;
      }
      UI.report(result);
      renderState();
      return;
    }
    saved = text;
    revision = result.revision;
    refs.conflict.hidden = true;
    UI.slip(result.restartNeeded ? C.savedRestart : C.saved);
    renderState();
  }

  async function revert() {
    if (!(await UI.confirm({ title: C.revertTitle, text: C.revertText, confirm: C.revert }))) return;
    refs.editor.value = saved;
    renderState();
  }

  return {
    show(target) {
      sheet = target;
      sheet.classList.add('is-console');
      refs = {
        aside: UI.el('span', 'page-aside'),
        editor: UI.el('textarea', 'cfg-editor'),
        state: UI.el('span', 'cfg-state'),
        missing: UI.el('p', 'hint', C.missing),
        conflict: UI.el('p', 'wizard-error', null, [
          document.createTextNode(`${STRINGS.errors.cfg_changed} `),
          UI.button(C.reload, async () => {
            refs.conflict.hidden = true;
            await load();
          }),
        ]),
        save: UI.button(C.save, save, 'seal'),
        revert: UI.button(C.revert, revert),
      };
      refs.conflict.hidden = true;
      refs.missing.hidden = true;
      refs.editor.spellcheck = false;
      refs.editor.wrap = 'off';
      refs.editor.setAttribute('aria-label', C.title);
      refs.editor.addEventListener('input', renderState);
      refs.editor.addEventListener('keydown', (event) => {
        if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') {
          event.preventDefault();
          save();
        } else if (event.key === 'Tab' && !event.shiftKey) {
          // tabulation dans le texte plutôt que vers le bouton suivant
          event.preventDefault();
          refs.editor.setRangeText('    ', refs.editor.selectionStart, refs.editor.selectionEnd, 'end');
          renderState();
        }
      });
      const heading = UI.heading(C.title);
      heading.append(refs.aside);
      sheet.replaceChildren(
        heading,
        UI.el('p', 'prose', C.intro),
        refs.missing,
        UI.el('div', 'slate cfg-slate', null, [refs.editor]),
        refs.conflict,
        UI.el('div', 'wizard-actions', null, [refs.state, UI.el('span', 'cell-sub', C.shortcut), UI.el('span', 'spacer'), refs.revert, refs.save]),
        UI.el('p', 'hint', C.backupNote),
      );
      window.addEventListener('beforeunload', guard);
      saved = '';
      refs.editor.value = '';
      renderState();
      load();
    },

    /** Changer de page : vrai si rien n'est perdu, ou si l'abandon des modifications est confirmé. */
    async leave() {
      if (!dirty()) return true;
      return UI.confirm({ title: C.revertTitle, text: C.unsaved, confirm: C.revert });
    },

    hide() {
      window.removeEventListener('beforeunload', guard);
      if (sheet) sheet.classList.remove('is-console');
      sheet = null;
      refs = null;
    },
  };
})();
