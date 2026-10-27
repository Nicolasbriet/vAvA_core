'use strict';
/*
 * web/js/view-discord.js
 * Rôle : la page Discord (compte maître) : état du bot (connecté, en connexion, erreur, absent du serveur réglé avec
 *        les serveurs où il se trouve), lien pour l'inviter sur le
 *        serveur Discord, message d'essai, et ses réglages — jeton (jamais réaffiché : un champ vide garde celui en
 *        place), serveur Discord, salons du statut, des annonces et du staff, liens « Rejoindre » et d'invitation,
 *        liste blanche par rôles. Les étapes pour créer le bot sont rappelées.
 */

const DiscordView = (() => {
  const D = STRINGS.discord;
  const RECHECK_MS = [1500, 4000, 8000];

  let sheet = null;
  let refs = null;
  let data = null;
  let timers = [];

  const ids = (text) => text.split(/[,;\s]+/).map((t) => t.trim()).filter(Boolean);

  function renderState() {
    const bot = data.discord;
    const label = bot.state === 'ready' ? D.states.ready(bot.user ? bot.user.username : '') : D.states[bot.state] || bot.state;
    const detail = bot.error ? D.errors[bot.error] || bot.error
      : bot.problem ? D.problems[bot.problem](bot.guilds.map((guild) => guild.name || guild.id))
        : bot.enabled ? '' : D.disabledNote;
    const actions = [];
    if (data.invite) {
      const invite = UI.el('a', 'ink-button link-button', D.invite);
      invite.href = data.invite;
      invite.target = '_blank';
      invite.rel = 'noopener noreferrer';
      actions.push(invite);
    }
    if (bot.state === 'ready') {
      actions.push(UI.button(D.test, async () => {
        const result = await API.post('/api/discord/test');
        UI.slip(result.ok ? D.testDone : `${STRINGS.error(result.error)}${result.detail ? ` (${result.detail})` : ''}`);
      }));
    }
    const kind = bot.state === 'ready' ? (bot.problem ? 'starting' : 'running') : bot.state === 'connecting' ? 'starting' : bot.state === 'error' ? 'crashed' : 'stopped';
    refs.state.className = `state-banner is-${kind}`;
    refs.state.replaceChildren(
      UI.el('span', 'state-seal'),
      UI.el('div', 'state-banner-text', null, [UI.el('span', 'state-banner-label', label), detail ? UI.el('span', 'state-banner-detail', detail) : null]),
      UI.el('div', 'state-banner-actions', null, actions),
    );
  }

  function renderForm() {
    const bot = data.discord;
    const inputs = {};
    const grid = UI.el('div', 'form-grid');
    const add = (def) => {
      const made = UI.field(def);
      inputs[def.name] = made.input;
      grid.append(made.node);
    };
    const enabled = UI.choice(D.enabled, bot.enabled, D.enabledHelp);
    enabled.node.classList.add('is-wide');
    grid.append(enabled.node);
    add({ name: 'token', label: D.token, type: 'password', value: '', max: 120, wide: true, autocomplete: 'off', help: bot.hasToken ? D.tokenSet : D.tokenHelp });
    add({ name: 'guildId', label: D.guildId, value: bot.guildId, max: 20, help: D.idHelp });
    add({ name: 'statusChannelId', label: D.statusChannelId, value: bot.statusChannelId, max: 20, help: D.statusHelp });
    add({ name: 'announceChannelId', label: D.announceChannelId, value: bot.announceChannelId, max: 20, help: D.announceHelp });
    add({ name: 'staffChannelId', label: D.staffChannelId, value: bot.staffChannelId, max: 20, help: D.staffHelp });
    add({ name: 'joinUrl', label: D.joinUrl, value: bot.joinUrl, max: 200, help: D.joinHelp });
    add({ name: 'inviteUrl', label: D.inviteUrl, value: bot.inviteUrl, max: 200, help: D.inviteHelp });
    const whitelist = UI.choice(D.whitelist, bot.whitelist.enabled, D.whitelistHelp);
    whitelist.node.classList.add('is-wide');
    grid.append(whitelist.node);
    add({ name: 'roleIds', label: D.roleIds, value: bot.whitelist.roleIds.join(', '), max: 220, wide: true, help: D.roleIdsHelp });
    const save = UI.button(D.save, async () => {
      for (const input of Object.values(inputs)) input.classList.remove('is-invalid');
      save.disabled = true;
      const result = await API.post('/api/discord/settings', {
        enabled: enabled.input.checked, token: inputs.token.value.trim(), guildId: inputs.guildId.value.trim(),
        statusChannelId: inputs.statusChannelId.value.trim(), announceChannelId: inputs.announceChannelId.value.trim(),
        staffChannelId: inputs.staffChannelId.value.trim(), joinUrl: inputs.joinUrl.value.trim(), inviteUrl: inputs.inviteUrl.value.trim(),
        whitelist: { enabled: whitelist.input.checked, roleIds: ids(inputs.roleIds.value) },
      });
      save.disabled = false;
      if (!result.ok) {
        const field = result.field === 'enabled' ? null : inputs[result.field];
        if (field) {
          field.classList.add('is-invalid');
          field.focus();
        }
        UI.report(result);
        return;
      }
      UI.slip(D.saved);
      data = result;
      inputs.token.value = '';
      render();
      recheck();
    }, 'seal');
    return [grid, UI.el('div', 'page-actions', null, [save])];
  }

  function render() {
    if (!sheet || !data) return;
    renderState();
    refs.form.replaceChildren(...renderForm());
  }

  async function load() {
    const result = await API.get('/api/discord');
    if (!sheet) return;
    if (!result.ok) {
      UI.report(result);
      return;
    }
    data = result;
    refs.node.hidden = result.nodeOk;
    renderState();
    if (!refs.form.childElementCount) refs.form.replaceChildren(...renderForm());
  }

  /** La connexion à Discord prend quelques secondes : l'état est relu. */
  function recheck() {
    for (const timer of timers) clearTimeout(timer);
    timers = RECHECK_MS.map((ms) => setTimeout(load, ms));
  }

  return {
    show(target, appContext) {
      sheet = target;
      if (!appContext.account().master) {
        sheet.replaceChildren(UI.heading(D.title), UI.el('p', 'empty', D.masterOnly));
        return;
      }
      refs = {
        state: UI.el('div', 'state-banner'),
        node: UI.el('p', 'wizard-error', D.nodeTooOld),
        form: UI.el('div'),
      };
      refs.node.hidden = true;
      sheet.replaceChildren(
        UI.heading(D.title),
        UI.el('p', 'prose', D.intro),
        refs.node,
        refs.state,
        UI.el('h3', 'section-title', D.settings),
        refs.form,
        UI.el('h3', 'section-title', D.stepsTitle),
        UI.el('ol', 'discord-steps', null, D.steps.map((step) => UI.el('li', null, step))),
        UI.el('h3', 'section-title', D.commandsTitle),
        UI.el('ul', 'discord-commands', null, D.commands.map(([name, text]) => UI.el('li', null, null, [UI.el('code', null, name), document.createTextNode(` — ${text}`)]))),
      );
      load();
    },

    hide() {
      for (const timer of timers) clearTimeout(timer);
      timers = [];
      sheet = null;
      refs = null;
      data = null;
    },
  };
})();
