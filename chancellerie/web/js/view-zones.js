'use strict';
/*
 * web/js/view-zones.js
 * Rôle : la page Zones de voix : lieux où la voix porte plus ou moins loin, avec leurs réglages ; modifier (nom,
 *        rayon, hauteur, effet) ou supprimer une zone. La création reste en jeu : une zone se centre sur la personne
 *        qui la crée. Chaque changement part aussitôt à tous les joueurs et s'inscrit au journal du Conseil.
 */

const ZonesView = (() => {
  const Z = STRINGS.zones;
  const MULTIPLIERS = [0.5, 0.75, 1, 1.5, 2, 3];
  const RADIUS = { min: 2, max: 60 };
  const HEIGHT = { min: 2, max: 30 };
  const LABEL_MAX = 40;

  let sheet = null;

  const empty = (text) => UI.el('p', 'empty', text);
  const effect = (multiplier) => Z.effects[multiplier] || `×${multiplier}`;

  async function edit(zone) {
    const values = await UI.form({
      title: Z.editTitle, text: zone.label, confirm: Z.save,
      fields: [
        { name: 'label', label: Z.name, value: zone.label, max: LABEL_MAX },
        { name: 'radius', label: Z.radius, type: 'number', min: RADIUS.min, max: RADIUS.max, value: zone.radius },
        { name: 'height', label: Z.height, type: 'number', min: HEIGHT.min, max: HEIGHT.max, value: zone.height },
        { name: 'multiplier', label: Z.effect, type: 'stamps', value: zone.multiplier, options: MULTIPLIERS.map((m) => ({ value: m, label: effect(m) })) },
      ],
    });
    if (!values) return;
    if (UI.report(await GAME.call('zoneUpdate', zone.id, values.label, values.radius, values.height, values.multiplier), Z.saved)) refresh();
  }

  async function remove(zone) {
    if (!(await UI.confirm({ title: Z.removeTitle, text: Z.removeText(zone.label), confirm: Z.remove }))) return;
    if (UI.report(await GAME.call('zoneDelete', zone.id), Z.removed)) refresh();
  }

  async function refresh() {
    if (!sheet) return;
    const result = await GAME.call('zones');
    if (!sheet) return;
    let content;
    if (!result.ok) {
      content = empty(STRINGS.error(result.error));
    } else {
      const zones = UI.list(result.result);
      content = zones.length ? UI.el('table', 'ledger', null, [
        UI.el('thead', null, null, [UI.el('tr', null, null, Z.columns.map((c) => UI.el('th', null, c)))]),
        UI.el('tbody', null, null, zones.map((zone) => UI.el('tr', null, null, [
          UI.el('td', 'cell-strong', zone.label),
          UI.el('td', null, effect(zone.multiplier)),
          UI.el('td', null, Z.meters(zone.radius)),
          UI.el('td', null, Z.meters(zone.height)),
          UI.el('td', 'cell-sub', `${Math.round(zone.x)}, ${Math.round(zone.y)}, ${Math.round(zone.z)}`),
          UI.el('td', 'cell-end', null, GAME.can('tools') ? [UI.button(Z.edit, () => edit(zone)), UI.button(Z.remove, () => remove(zone), 'plain')] : []),
        ]))),
      ]) : empty(Z.empty);
    }
    sheet.replaceChildren(UI.heading(Z.title), UI.el('p', 'prose', Z.hint), content);
  }

  return {
    async show(target) {
      sheet = target;
      sheet.replaceChildren(UI.heading(Z.title), empty('…'));
      const ready = await GAME.ensure();
      if (!sheet) return;
      if (!ready.ok) {
        sheet.replaceChildren(UI.heading(Z.title), empty(STRINGS.error(ready.error)));
        return;
      }
      refresh();
    },
    hide() {
      sheet = null;
    },
  };
})();
