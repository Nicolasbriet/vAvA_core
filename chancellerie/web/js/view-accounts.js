'use strict';
/*
 * web/js/view-accounts.js
 * Rôle : la page Comptes. Le compte maître y crée les comptes de la Chancellerie, règle leurs droits sur le panneau
 *        et leur rang du Conseil (administration du royaume, mêmes droits qu'en jeu), leur remet un mot de passe ou
 *        les supprime. Chacun y change son propre mot de passe.
 */

const AccountsView = (() => {
  const A = STRINGS.accounts;
  let sheet = null;
  let context = null;
  let ranks = [];
  let ranksLive = false;

  const empty = (text) => UI.el('p', 'empty', text);
  const rankLabel = (name) => {
    if (!name) return A.none;
    const rank = ranks.find((r) => r.name === name);
    return rank ? rank.label : name;
  };
  const rankOptions = () => [{ value: '', label: A.noRank }, ...ranks.map((r) => ({ value: r.name, label: r.label }))];
  const permissionOptions = (checked) => ['server', 'console', 'config', 'backups'].map((p) => ({ value: p, label: A.permissionLabels[p], checked: checked.includes(p) }));

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
        { name: 'rank', label: A.rank, type: 'select', options: rankOptions(), value: account.rank, help: ranksLive ? null : A.ranksStale },
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

  function table(accounts) {
    return UI.el('table', 'ledger', null, [
      UI.el('thead', null, null, [UI.el('tr', null, null, A.columns.map((c) => UI.el('th', null, c)))]),
      UI.el('tbody', null, null, accounts.map((account) => UI.el('tr', null, null, [
        UI.el('td', null, null, [UI.el('span', 'cell-strong', account.name), account.master ? UI.el('span', 'tag tag-rank', A.master) : null]),
        UI.el('td', 'cell-sub', UI.list(account.permissions).map((p) => A.permissionLabels[p]).join(' · ') || A.none),
        UI.el('td', null, rankLabel(account.rank)),
        UI.el('td', 'cell-date', STRINGS.date(account.createdAt)),
        UI.el('td', 'cell-end', null, account.master ? [] : [
          UI.button(A.edit, () => edit(account)),
          UI.button(A.setPassword, () => password(account)),
          UI.button(A.remove, () => remove(account), 'plain'),
        ]),
      ]))),
    ]);
  }

  async function refresh() {
    if (!sheet) return;
    const mine = UI.el('div', 'page-actions', null, [UI.button(A.mineTitle, changeMine)]);
    if (!context.account().master) {
      sheet.replaceChildren(UI.heading(A.title), mine);
      return;
    }
    const [result, known] = await Promise.all([API.get('/api/accounts'), GAME.ranks()]);
    if (!sheet) return;
    ranks = known.ranks;
    ranksLive = known.live;
    sheet.replaceChildren(
      UI.heading(A.title),
      result.ok ? table(UI.list(result.accounts)) : empty(STRINGS.error(result.error)),
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
  };
})();
