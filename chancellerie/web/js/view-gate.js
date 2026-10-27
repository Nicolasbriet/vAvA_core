'use strict';
/*
 * web/js/view-gate.js
 * Rôle : la porte de la Chancellerie. Au premier lancement : code d'accès (affiché dans la fenêtre du programme)
 *        et création du compte maître. Ensuite : connexion par identifiant et mot de passe.
 */

const GateView = (() => {
  const S = STRINGS.gate;
  let refs = null;
  let busy = false;

  function showError(message) {
    refs.error.textContent = message || '';
    refs.error.hidden = !message;
  }

  /** Formulaire du premier lancement : code, identifiant, mot de passe deux fois. */
  function renderMaster(digits, onDone) {
    refs.subtitle.textContent = S.pinTitle;
    refs.submit.textContent = S.createMaster;
    const code = UI.el('input', 'pin-input');
    code.inputMode = 'numeric';
    code.autocomplete = 'one-time-code';
    code.maxLength = digits + 2;
    code.placeholder = '0'.repeat(digits);
    code.setAttribute('aria-label', S.pinLabel);
    const name = UI.field({ name: 'name', label: S.name, autocomplete: 'username', max: 32 });
    const password = UI.field({ name: 'password', label: S.password, type: 'password', autocomplete: 'new-password', max: 200, help: S.passwordHelp });
    const again = UI.field({ name: 'again', label: S.passwordAgain, type: 'password', autocomplete: 'new-password', max: 200 });
    refs.body.replaceChildren(UI.el('p', 'charter-intro', S.pinIntro), UI.el('div', 'field', null, [UI.el('span', 'field-label', S.pinLabel), code]), name.node, password.node, again.node);
    refs.submitHandler = async () => {
      if (password.input.value !== again.input.value) {
        showError(STRINGS.error('password_mismatch'));
        return;
      }
      const result = await API.post('/api/setup/master', { pin: code.value, name: name.input.value.trim(), password: password.input.value });
      if (!result.ok) {
        showError(STRINGS.error(result.error));
        if (result.error === 'bad_pin') code.select();
        return;
      }
      onDone(result.account);
    };
    code.focus();
  }

  function renderLogin(onDone) {
    refs.subtitle.textContent = S.loginTitle;
    refs.submit.textContent = S.login;
    const name = UI.field({ name: 'name', label: S.name, autocomplete: 'username', max: 32 });
    const password = UI.field({ name: 'password', label: S.password, type: 'password', autocomplete: 'current-password', max: 200 });
    refs.body.replaceChildren(name.node, password.node);
    refs.submitHandler = async () => {
      const result = await API.post('/api/login', { name: name.input.value.trim(), password: password.input.value });
      if (!result.ok) {
        showError(STRINGS.error(result.error));
        password.input.select();
        return;
      }
      onDone(result.account);
    };
    name.input.focus();
  }

  function init() {
    const root = document.getElementById('gate');
    refs = {
      root,
      form: root.querySelector('.charter'),
      subtitle: root.querySelector('.charter-subtitle'),
      body: root.querySelector('.charter-body'),
      error: root.querySelector('.charter-error'),
      submit: root.querySelector('.charter-submit'),
      submitHandler: null,
    };
    root.querySelector('.gate-foot').textContent = S.foot;
    refs.form.addEventListener('submit', async (event) => {
      event.preventDefault();
      if (busy || !refs.submitHandler) return;
      busy = true;
      refs.submit.disabled = true;
      showError('');
      try {
        await refs.submitHandler();
      } finally {
        busy = false;
        refs.submit.disabled = false;
      }
    });
  }

  return {
    init,
    /** @param {{ phase: string, pinDigits: number }} state  @param {(account: object) => void} onDone */
    show(state, onDone) {
      showError('');
      refs.root.hidden = false;
      if (state.phase === 'pin') renderMaster(state.pinDigits, onDone);
      else renderLogin(onDone);
    },
    hide() {
      refs.root.hidden = true;
      refs.body.replaceChildren();
    },
  };
})();
