'use strict';
/*
 * web/js/view-accounts.js
 * Rôle : la page Comptes. Le compte maître y crée les comptes de la Chancellerie, règle leurs droits sur le panneau
 *        et leur rang du Conseil (administration du royaume, mêmes droits qu'en jeu), leur remet un mot de passe ou
 *        les supprime. Chacun y change son propre mot de passe, et relie son compte à son joueur : un code à taper en
 *        jeu, après quoi le rang du compte s'applique aussi en jeu ; le maître peut relier ou délier tous les comptes.
 */

const AccountsView = (() => {
  const A = STRINGS.accounts;
  let sheet = null;
  let context = null;
  let ranks = [];
  let ranksLive = false;
  // compte dont le code de liaison est affiché (le dialogue se ferme quand la liaison arrive)
  let linking = null;

  const empty = (text) => UI.el('p', 'empty', text);
  const rankLabel = (name) => {
    if (!name) return A.none;
    const rank = ranks.find((r) => r.name === name);
    return rank ? rank.label : name;
  };
  const rankOptions = () => [{ value: '', label: A.noRank }, ...ranks.map((r) => ({ value: r.name, label: r.label }))];
  const permissionOptions = (checked) => ['server', 'console', 'config', 'backups'].map((p) => ({ value: p, label: A.permissionLabels[p], checked: checked.includes(p) }));
  // license:1a2b…9f0e — assez pour la reconnaître, sans l'étaler
  const shortLicense = (license) => (license.length > 20 ? `${license.slice(0, 12)}…${license.slice(-4)}` : license);

  async function create() {
    const values = await UI.form({
      title: A.createTitle, confirm: A.create,
      fields: [
        { name: 'name', label: A.name, max: 32, autocomplete: 'off' },
        { name: 'password', label: A.password, type: 'password', max: 200, autocomplete: 'new-password' },
        { name: 'permissions', label: A.permissions, type: 'checks', options: permissionOptions([]) },
        { name: 'rank', label: A.rank, type: 'select', options: rankOptions(), value: '', help: ranksLive ? null : A.ranksStale },
      ],
    });
    if (!values) return;
    if (UI.report(await API.post('/api/accounts/create', values), A.created)) refresh();
  }

  async function edit(account) {
    const values = await UI.form({
      title: A.editTitle, text: account.name, confirm: A.edit,
      fields: [
        { name: 'permissions', label: A.permissions, type: 'checks', options: permissionOptions(UI.list(account.permissions)) },
        { name: 'rank', label: A.rank, type: 'select', options: rankOptions(), value: account.rank, help: account.link ? A.rankFollows : ranksLive ? null : A.ranksStale },
      ],
    });
    if (!values) return;
    if (UI.report(await API.post('/api/accounts/update', { name: account.name, ...values }), A.updated)) refresh();
  }

  async function password(account) {
    const values = await UI.form({
      title: `${A.passwordTitle} ${account.name}`, confirm: A.setPassword,
      fields: [{ name: 'password', label: A.password, type: 'password', max: 200, autocomplete: 'new-password' }],
    });
    if (!values) return;
    UI.report(await API.post('/api/accounts/password', { name: account.name, password: values.password }), A.passwordSet);
  }

  async function remove(account) {
    if (!(await UI.confirm({ title: A.deleteTitle, text: A.deleteText(account.name), confirm: A.remove }))) return;
    if (UI.report(await API.post('/api/accounts/delete', { name: account.name }), A.removed)) refresh();
  }

  async function changeMine() {
    const values = await UI.form({
      title: A.mineTitle, confirm: A.change,
      fields: [
        { name: 'current', label: A.current, type: 'password', max: 200, autocomplete: 'current-password' },
        { name: 'password', label: A.fresh, type: 'password', max: 200, autocomplete: 'new-password' },
        { name: 'again', label: A.again, type: 'password', max: 200, autocomplete: 'new-password' },
      ],
    });
    if (!values) return;
    if (values.password !== values.again) {
      UI.slip(A.mismatch);
      return;
    }
    UI.report(await API.post('/api/account/password', { current: values.current, password: values.password }), A.passwordSet);
  }

  // Liaison au joueur ---------------------------------------------------------------------------------------------

  async function link(account) {
    const mine = account.name === context.account().name;
    const result = await API.post('/api/account/link', mine ? {} : { name: account.name });
    if (!UI.report(result)) return;
    const minutes = Math.round(result.ttlMs / 60000);
    const body = UI.el('div', 'link-code', null, [
      UI.el('p', 'prose', mine ? A.linkIntroMine : A.linkIntroOther(account.name)),
      UI.el('p', 'link-command', null, [UI.el('code', null, `chancellerie ${result.code}`)]),
      UI.el('p', 'hint', A.linkHelp(minutes)),
      UI.el('p', 'hint', A.linkRank),
    ]);
    linking = account.name;
    await UI.reading({ title: A.linkTitle, body, confirm: A.close });
    linking = null;
  }

  async function unlink(account) {
    if (!(await UI.confirm({ title: A.unlinkTitle, text: A.unlinkText(account.name, account.link.player), confirm: A.unlink }))) return;
    const mine = account.name === context.account().name;
    if (UI.report(await API.post('/api/account/unlink', mine ? {} : { name: account.name }), A.unlinked)) refresh();
  }

  function linkCell(account) {
    if (!account.link) return UI.el('td', 'cell-sub', A.notLinked);
    const ids = [shortLicense(account.link.license), account.link.fivem].filter(Boolean).join(' · ');
    return UI.el('td', null, null, [
      UI.el('span', 'cell-strong', account.link.player || A.gameAccount(account.link.accountId)),
      UI.el('div', 'cell-sub mono', ids),
    ]);
  }

  function linkButtons(account) {
    return account.link
      ? [UI.button(A.relink, () => link(account)), UI.button(A.unlink, () => unlink(account), 'plain')]
      : [UI.button(A.link, () => link(account))];
  }

  function table(accounts) {
    return UI.el('table', 'ledger', null, [
      UI.el('thead', null, null, [UI.el('tr', null, null, A.columns.map((c) => UI.el('th', null, c)))]),
      UI.el('tbody', null, null, accounts.map((account) => UI.el('tr', null, null, [
        UI.el('td', null, null, [UI.el('span', 'cell-strong', account.name), account.master ? UI.el('span', 'tag tag-rank', A.master) : null]),
        UI.el('td', 'cell-sub', UI.list(account.permissions).map((p) => A.permissionLabels[p]).join(' · ') || A.none),
        UI.el('td', null, rankLabel(account.rank)),
        linkCell(account),
        UI.el('td', 'cell-date', STRINGS.date(account.createdAt)),
        UI.el('td', 'cell-end', null, [UI.el('span', 'row-actions', null, [
          ...linkButtons(account),
          ...(account.master ? [] : [
            UI.button(A.edit, () => edit(account)),
            UI.button(A.setPassword, () => password(account)),
            UI.button(A.remove, () => remove(account), 'plain'),
          ]),
        ])]),
      ]))),
    ]);
  }

  /** Ce que voit un compte qui n'est pas le maître : son joueur relié, et de quoi le relier ou le délier. */
  function mineSection() {
    const me = context.account();
    return UI.el('section', 'link-mine', null, [
      UI.el('h3', 'section-title', A.mineLinkTitle),
      me.link
        ? UI.el('p', 'prose', A.mineLinked(me.link.player || A.gameAccount(me.link.accountId), shortLicense(me.link.license)))
        : UI.el('p', 'prose', A.mineNotLinked),
      UI.el('div', 'page-actions', null, linkButtons(me)),
    ]);
  }

  async function refresh() {
    if (!sheet) return;
    if (!context.account().master) {
      // le compte affiché vient de la session : relu pour connaître sa liaison
      const state = await API.get('/api/state');
      if (!sheet) return;
      if (state.ok && state.account) context.refreshAccount(state.account);
      sheet.replaceChildren(UI.heading(A.title), mineSection(), UI.el('div', 'page-actions', null, [UI.button(A.mineTitle, changeMine)]));
      return;
    }
    const [result, known] = await Promise.all([API.get('/api/accounts'), GAME.ranks()]);
    if (!sheet) return;
    ranks = known.ranks;
    ranksLive = known.live;
    sheet.replaceChildren(
      UI.heading(A.title),
      result.ok ? table(UI.list(result.accounts)) : empty(STRINGS.error(result.error)),
      UI.el('p', 'hint', A.linkNote),
      UI.el('div', 'page-actions', null, [UI.button(A.create, create, 'seal'), UI.button(A.mineTitle, changeMine)]),
    );
  }

  return {
    show(target, appContext) {
      sheet = target;
      context = appContext;
      refresh();
    },
    hide() {
      sheet = null;
    },
    /** Un compte vient d'être relié à son joueur (code tapé en jeu). */
    linked(event) {
      if (!sheet) return;
      if (linking && event && event.name === linking) {
        UI.close();
        UI.slip(A.linkedNow(event.name));
      }
      refresh();
    },
  };
})();
