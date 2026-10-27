'use strict';
/*
 * web/js/view-staff.js
 * Rôle : onglet Conseil : membres et leur rang ; révocation des membres de rang inférieur (le serveur le revérifie).
 *        Les nominations se font depuis la fiche d'un joueur.
 */

const StaffView = (() => {
  const S = STRINGS.staff;
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));

  async function show(ctx) {
    const result = await Bridge.request('staff');
    const members = result.ok ? list(result.result) : [];
    if (!result.ok) UI.report(result);
    const rows = members.map((member) => UI.el('div', 'member', null, [
      UI.el('span', 'seal seal-small', null),
      UI.el('span', 'member-main', null, [
        UI.el('span', 'entry-name', member.character || STRINGS.players.account(member.accountId)),
        UI.el('span', 'entry-sub', member.source ? `${STRINGS.players.account(member.accountId)} · ${STRINGS.players.session(member.source)}` : S.offline),
      ]),
      UI.el('span', 'tag tag-rank', member.rankLabel),
      member.level < ctx.session.rank.level && member.accountId !== ctx.session.accountId ? UI.button(S.revoke, async () => {
        const label = member.character || STRINGS.players.account(member.accountId);
        const ok = await UI.dialog({ title: STRINGS.dialogs.revoke.title, text: STRINGS.dialogs.revoke.text(label), confirm: STRINGS.dialogs.revoke.confirm });
        if (!ok) return;
        if (UI.report(await Bridge.request('staffSet', member.accountId, ''), STRINGS.done)) await show(ctx);
      }) : null,
    ]));
    ctx.single.replaceChildren(
      UI.heading(S.heading),
      UI.el('div', 'members', null, rows.length ? rows : [UI.el('p', 'empty', S.empty)]),
      UI.el('p', 'hint', S.hint),
    );
  }

  return { id: 'staff', permission: 'staff', single: true, show };
})();
