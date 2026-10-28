'use strict';
/*
 * web/js/view-zones.js
 * Rôle : le panneau des zones de récolte : nom, genre, vitalité (barre teintée par bande), cicatrice, distance.
 *        Construit à l'ouverture et à chaque relecture ; rien n'est animé en continu.
 */

const ZonesView = (() => {
  const root = document.getElementById('zones');
  const refs = {
    title: root.querySelector('.zones-title'),
    refresh: root.querySelector('.zones-refresh'),
    close: root.querySelector('.zones-close'),
    list: root.querySelector('.zones-list'),
    foot: root.querySelector('.zones-foot'),
  };
  const Z = STRINGS.zones;

  function row(zone) {
    const band = zone.band || 'normal';
    const vitality = UI.clamp(Number(zone.vitality) || 0, 0, 100);
    const fill = UI.el('span', `zone-fill is-${band}${zone.scarred ? ' is-scarred' : ''}`);
    fill.style.transform = `scaleX(${(vitality / 100).toFixed(3)})`;
    const track = UI.el('div', 'zone-track', null, [fill]);
    const tags = [UI.el('span', `zone-band is-${band}`, Z.bands[band] || band)];
    if (zone.scarred) tags.push(UI.el('span', 'zone-band is-scar', Z.scarred));
    return UI.el('div', `zone-row${zone.scarred ? ' is-scarred' : ''}`, null, [
      UI.el('div', 'zone-main', null, [
        UI.el('div', 'zone-head', null, [
          UI.el('span', 'zone-name', zone.label || zone.id),
          UI.el('span', 'zone-kind', Z.kinds[zone.kind] || zone.kind || ''),
          ...tags,
        ]),
        UI.el('div', 'zone-bar', null, [track, UI.el('span', 'zone-value', Z.vitality(vitality))]),
      ]),
      UI.el('span', 'zone-distance', typeof zone.distance === 'number' ? Z.distance(zone.distance) : ''),
    ]);
  }

  /** Affiche la liste (déjà triée par distance par le serveur). */
  function show(zones) {
    const list = Array.isArray(zones) ? zones : Object.values(zones || {});
    refs.list.replaceChildren(...(list.length ? list.map(row) : [UI.el('p', 'empty', Z.empty)]));
    root.hidden = false;
  }

  function hide() {
    root.hidden = true;
  }

  async function refresh() {
    refs.refresh.disabled = true;
    const result = await Bridge.post('zonesRefresh', {});
    refs.refresh.disabled = false;
    if (result.ok && result.zones) show(result.zones);
    else if (!result.ok) App.toast(errorMessage(result.error), 'warning');
  }

  refs.title.textContent = Z.title;
  refs.refresh.textContent = Z.refresh;
  refs.close.title = Z.close;
  refs.foot.textContent = Z.foot;
  refs.refresh.addEventListener('click', refresh);
  refs.close.addEventListener('click', () => App.closeZones());

  return { show, hide, isOpen: () => !root.hidden };
})();
