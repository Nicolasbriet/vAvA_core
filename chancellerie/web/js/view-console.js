'use strict';
/*
 * web/js/view-console.js
 * Rôle : la console de FXServer en direct, sur une ardoise : couleurs du serveur, défilement qui suit les
 *        nouvelles lignes tant qu'on est en bas (sinon un bouton propose d'y revenir), saisie de commandes avec
 *        historique (flèches haut et bas). Les lignes arrivées en rafale sont écrites une fois par image.
 */

const ConsoleView = (() => {
  const C = STRINGS.console;
  const MAX_LINES = 3000;
  const HISTORY_MAX = 50;
  const BOTTOM_SLACK_PX = 24;

  let sheet = null;
  let refs = null;
  let context = null;
  let queue = [];
  let frame = null;
  let following = true;
  const history = [];
  let historyIndex = -1;

  function lineNode(line) {
    const node = UI.el('div', `line line-${line.stream}`);
    node.append(...ANSI.render(line.text));
    return node;
  }

  function atBottom() {
    const box = refs.lines;
    return box.scrollHeight - box.scrollTop - box.clientHeight <= BOTTOM_SLACK_PX;
  }

  function scrollDown() {
    refs.lines.scrollTop = refs.lines.scrollHeight;
  }

  function flush() {
    frame = null;
    if (!refs || !queue.length) return;
    const fragment = document.createDocumentFragment();
    for (const line of queue) fragment.append(lineNode(line));
    queue = [];
    if (refs.empty.isConnected) refs.empty.remove();
    refs.lines.append(fragment);
    const excess = refs.lines.childElementCount - MAX_LINES;
    for (let i = 0; i < excess; i += 1) refs.lines.firstElementChild.remove();
    if (following) scrollDown();
    else refs.follow.hidden = false;
  }

  function schedule() {
    if (!frame) frame = requestAnimationFrame(flush);
  }

  function setPrompt(status) {
    const open = status.state === 'starting' || status.state === 'running';
    refs.input.disabled = !open;
    refs.send.disabled = !open;
    refs.input.placeholder = open ? C.placeholder : C.offline;
  }

  async function send() {
    const command = refs.input.value.trim();
    if (!command) return;
    const result = await API.post('/api/console/command', { command });
    if (!UI.report(result)) return;
    if (history[0] !== command) history.unshift(command);
    if (history.length > HISTORY_MAX) history.pop();
    historyIndex = -1;
    refs.input.value = '';
    following = true;
    scrollDown();
  }

  function browseHistory(direction) {
    if (!history.length) return;
    historyIndex = Math.max(-1, Math.min(history.length - 1, historyIndex + direction));
    refs.input.value = historyIndex === -1 ? '' : history[historyIndex];
    refs.input.setSelectionRange(refs.input.value.length, refs.input.value.length);
  }

  function build() {
    refs = {
      lines: UI.el('div', 'slate-lines'),
      empty: UI.el('div', 'slate-empty', C.empty),
      follow: UI.button(C.follow, () => {
        following = true;
        refs.follow.hidden = true;
        scrollDown();
      }),
      input: UI.el('input', 'prompt-input'),
      send: UI.button(C.send, () => send()),
    };
    refs.follow.className = 'slate-follow';
    refs.follow.hidden = true;
    refs.lines.setAttribute('role', 'log');
    refs.input.type = 'text';
    refs.input.maxLength = 500;
    refs.input.spellcheck = false;
    refs.input.autocomplete = 'off';
    refs.input.setAttribute('aria-label', C.placeholder);
    refs.lines.addEventListener('scroll', () => {
      following = atBottom();
      if (following) refs.follow.hidden = true;
    });
    refs.input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        send();
      } else if (event.key === 'ArrowUp') {
        event.preventDefault();
        browseHistory(1);
      } else if (event.key === 'ArrowDown') {
        event.preventDefault();
        browseHistory(-1);
      }
    });
  }

  return {
    show(target, appContext) {
      sheet = target;
      context = appContext;
      sheet.classList.add('is-console');
      if (!context.can('console')) {
        sheet.replaceChildren(UI.heading(C.title), UI.el('p', 'empty', C.denied));
        return;
      }
      build();
      const lines = context.lines();
      sheet.replaceChildren(
        UI.heading(C.title),
        UI.el('div', 'slate', null, [refs.lines, refs.follow]),
        UI.el('div', 'prompt', null, [UI.el('span', 'prompt-mark', '›'), refs.input, refs.send]),
      );
      refs.lines.append(refs.empty);
      following = true;
      queue = lines.slice(-MAX_LINES);
      flush();
      setPrompt(context.status());
      if (!refs.input.disabled) refs.input.focus();
    },

    hide() {
      if (sheet) sheet.classList.remove('is-console');
      if (frame) cancelAnimationFrame(frame);
      frame = null;
      queue = [];
      sheet = null;
      refs = null;
    },

    update(status) {
      if (refs) setPrompt(status);
    },

    /** Nouvelles lignes reçues. */
    lines(lines) {
      if (!refs) return;
      queue.push(...lines);
      schedule();
    },

    /** L'historique a été remplacé (reconnexion après un redémarrage de la Chancellerie). */
    reset(lines) {
      if (!refs) return;
      refs.lines.replaceChildren(refs.empty);
      queue = lines.slice(-MAX_LINES);
      schedule();
    },
  };
})();
