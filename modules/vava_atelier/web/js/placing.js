'use strict';
/*
 * vava_atelier/web/js/placing.js — placement en jeu (T-102) : bloc « Lieu », « Prochain … à poser », liste des enfants,
 *   étapes cochées, demande de visée. Fonctions pures en tête (essais : dev/essais.js). L'aperçu vert ou rouge et les
 *   étiquettes sont dessinés par le jeu : la page ne reçoit rien à chaque image. Texte du jeu : toujours textContent.
 * Dépendances : strings.js, format.js, lifecycle.js, components.js, widgets.js
 */

const Placing = (() => {
  const { str, list } = Format;
  const P = STRINGS.place;
  const SHAPES = new Set(['point', 'oriented', 'circle', 'polygon']);
  const TONES = new Set(['live', 'draft', 'new', 'removal', 'other']);
  const MAX_ROWS = 200;
  const NBSP = ' ';
  const num = (value) => (typeof value === 'number' && Number.isFinite(value) ? value : null);
  const own = (map, key) => Boolean(map) && typeof map === 'object' && Object.prototype.hasOwnProperty.call(map, key);

  // Fonctions pures --------------------------------------------------------------------------------------------------

  const placeable = (kind) => Boolean(kind) && SHAPES.has(kind.placement);
  const childOf = (descriptor, kind) => list(descriptor && descriptor.kinds).find((k) => k && k.parent === kind.id && placeable(k)) || null;
  const kindOf = (descriptor, id) => list(descriptor && descriptor.kinds).find((k) => k && k.id === id) || null;

  /** Lieu reçu : les seules clés de sa forme, nombres finis ; null s'il n'y en a pas. */
  function cleanPlace(shape, place) {
    if (!place || typeof place !== 'object') return null;
    if (shape === 'polygon') {
      const points = list(place.points).filter((p) => p && num(p.x) !== null && num(p.y) !== null).slice(0, 32).map((p) => ({ x: p.x, y: p.y }));
      return points.length >= 3 ? { z: num(place.z) || 0, points } : null;
    }
    if (num(place.x) === null || num(place.y) === null) return null;
    const out = { x: place.x, y: place.y, z: num(place.z) || 0 };
    if (shape === 'oriented' && num(place.h) !== null) out.h = place.h;
    if (shape === 'circle' && num(place.r) !== null) out.r = place.r;
    return out;
  }

  /** Repère GPS : le point, le centre du cercle ou la moyenne des sommets. */
  function center(place) {
    if (!place) return null;
    if (Array.isArray(place.points)) {
      if (place.points.length === 0) return null;
      const sum = place.points.reduce((s, p) => ({ x: s.x + p.x, y: s.y + p.y }), { x: 0, y: 0 });
      return { x: sum.x / place.points.length, y: sum.y / place.points.length };
    }
    return num(place.x) !== null && num(place.y) !== null ? { x: place.x, y: place.y } : null;
  }

  const meters = (n) => (n >= 1000 ? `${Format.number(n / 1000, 1)}${NBSP}km` : `${Format.number(Math.round(n))}${NBSP}m`);
  const decimal = (n) => Format.number(n, Number.isInteger(n) ? 0 : 1);

  /** « Pas encore placée. » ou « Posée à 32 m de vous, rayon 120 m » (distance donnée par le jeu à la lecture). */
  function lieuLine(kind, place, distance) {
    const f = Lifecycle.feminine(kind);
    if (!place) return P.none(f);
    const far = num(distance) !== null && distance >= 0 ? meters(distance) : '';
    let more = '';
    if (kind.placement === 'circle' && num(place.r) !== null) more = P.radius(decimal(place.r));
    else if (kind.placement === 'polygon' && place.points) more = P.vertices(place.points.length);
    return P.posed(f, far) + more;
  }

  function cleanRow(row, child) {
    if (!row || typeof row !== 'object' || !str(row.id)) return null;
    return { kind: str(row.kind) || child.id, id: row.id, title: str(row.title) || row.id, hint: str(row.hint),
      tone: TONES.has(row.tone) ? row.tone : 'live', place: cleanPlace(child.placement, row.place) };
  }

  /** « 5 points, dont 1 nouveau » ; les retraits préparés ne comptent pas. */
  function countLine(rows, child) {
    const f = Lifecycle.feminine(child), shown = rows.filter((r) => r.tone !== 'removal');
    if (shown.length === 0) return P.empty(f, str(child.noun));
    return P.count(shown.length, str(child.noun), str(child.nounPlural), shown.filter((r) => r.tone === 'new').length, f);
  }

  function mark(row, child) {
    if (row.tone === 'other') return { text: P.marks.other, tone: 'other' };
    return P.marks[row.tone] && row.tone !== 'live' ? { text: P.marks[row.tone](Lifecycle.feminine(child)), tone: row.tone } : null;
  }

  /** Corbeille : jamais publiée → abandon du brouillon ; publiée → retrait préparé ; rien pour un retrait ou le brouillon d'un autre. */
  const removal = (row) => (row.tone === 'new' ? 'discard' : (row.tone === 'live' || row.tone === 'draft' ? 'retire' : ''));

  /** Étapes : la 1re faite quand la fiche a un lieu, la 2e quand elle a un enfant ; la première non faite est en cours. */
  function stepStates(count, progress) {
    const done = [progress.placed === true, progress.children === true];
    const out = [];
    for (let i = 0; i < count; i += 1) {
      if (out.includes('current')) out.push('todo');
      else out.push(done[i] ? 'done' : 'current');
    }
    return out;
  }

  /** Fantôme d'après la valeur du champ `ghost.field` : `models` du type, sinon la valeur est le modèle. */
  function ghostOf(kind, value, known) {
    const g = kind && kind.ghost;
    if (!g || typeof g !== 'object' || !str(g.field) || !str(value)) return null;
    if (g.models && typeof g.models === 'object') {
      const m = own(g.models, value) ? g.models[value] : null;
      return m && str(m.model) ? { model: m.model, label: str(m.label), provisional: m.provisional === true } : null;
    }
    return { model: value, label: str(known && known.label), provisional: Boolean(known && known.provisional === true) };
  }

  const lookLine = (ghost) => (ghost && ghost.label ? (ghost.provisional ? P.lookProvisional(ghost.label) : P.look(ghost.label)) : '');

  /**
   * Retour `placeStart` (§ 9.2) : la fiche elle-même (`self`) ou ses enfants (`children` : `kind` de l'enfant, `id` vide,
   * `parent` et `parentRev` de la fiche ouverte, valeurs du modèle et libellé du titre automatique).
   */
  function startPayload(o) {
    const children = o.mode === 'children';
    const target = children ? o.child : o.kind;
    const out = { editor: o.editor, kind: target.id, id: children ? '' : o.id, rev: children ? 0 : o.rev, mode: children ? 'children' : 'self',
      shape: target.placement, rules: target.rules && typeof target.rules === 'object' ? target.rules : {}, title: o.title };
    if (children) Object.assign(out, { parent: o.id, parentRev: o.rev, template: o.template || {}, label: o.label || '' });
    if (o.ghost) out.ghost = o.ghost;
    return out;
  }

  function upsert(rows, row) {
    const index = rows.findIndex((r) => r.id === row.id);
    if (index >= 0) return rows.map((r, i) => (i === index ? row : r));
    return rows.length < MAX_ROWS ? rows.concat([row]) : rows;
  }

  // Interface --------------------------------------------------------------------------------------------------------

  const recents = new Map();   // « editor|type|champ » → deux derniers choix { value, label }
  const memory = new Map();    // « editor|type » → valeurs du modèle, gardées d'une ouverture à l'autre

  function labelOf(field, value, known) {
    const statics = list(field.widget === 'model' ? field.choices : field.options);
    const found = statics.find((o) => o && o.value === value) || (known ? known(field, value) : null);
    return found && str(found.label) ? found : null;
  }

  /** `select` à liste distante : segmenté des deux derniers choix + « Autre… » (ouvre la liste). */
  function recentChoice(field, value, ctx) {
    const { h, Picker } = UI;
    const key = `${ctx.key}|${field.id}`;
    const lid = `pl-${field.id}-l`;
    let current = str(value);
    const box = h('div', { class: 'seg', role: 'radiogroup', 'aria-labelledby': lid });
    const other = h('button', { type: 'button', class: 'opt', text: P.other, 'aria-haspopup': 'listbox', 'aria-expanded': 'false' });
    const take = (item) => {
      recents.set(key, [item].concat((recents.get(key) || []).filter((o) => o.value !== item.value)).slice(0, 2));
      current = item.value;
      draw();
    };
    function draw() {
      const items = recents.get(key) || [];
      box.replaceChildren(...items.map((o) => h('button', { type: 'button', role: 'radio', class: `opt${o.value === current ? ' on' : ''}`, 'aria-checked': String(o.value === current),
        text: o.label, onclick: () => { take(o); ctx.changed(); } })), other);
    }
    other.addEventListener('click', () => {
      if (Picker.isOpen()) { Picker.close(true); return; }
      Picker.open(other, { search: true, remote: true, current, load: (q, p) => ctx.lookup(field, q, p),
        onPick: (o) => { if (!o.value) return; ctx.remember(field, o); take({ value: o.value, label: str(o.label) || o.value }); ctx.changed(); } });
    });
    const known = labelOf(field, current, ctx.known);
    if (known) take({ value: current, label: known.label });
    else if (!(recents.get(key) || []).length) {
      // première ouverture : les deux premiers choix de la liste (une seule demande)
      ctx.lookup(field, '', 1).then((got) => {
        const items = list(got && got.items).slice(0, 2);
        for (const item of items.slice().reverse()) take({ value: item.value, label: str(item.label) || item.value });
        if (items[0]) { current = items[0].value; draw(); ctx.changed(); }
      });
    }
    draw();
    return { nodes: [h('div', { class: 'fh' }, h('span', { class: 'lb', id: lid, text: str(field.label) })), box], get: () => current,
      focus: () => (box.querySelector('.on') || other).focus(), control: box,
      label: () => ((recents.get(key) || []).find((o) => o.value === current) || {}).label || '' };
  }

  /** Champs `template` du type enfant (maquette : deux champs chiffrés côte à côte, l'aide en infobulle). */
  function templateFields(child, ctx) {
    const { h } = UI;
    const fields = list(child.template).map((id) => list((child.form || {}).fields).find((f) => f && f.id === id)).filter((f) => f && Widgets.MAP[f.widget]);
    const saved = memory.get(ctx.key) || {};
    const widgets = new Map();
    const blocks = fields.map((field) => {
      const value = own(saved, field.id) ? saved[field.id] : Widgets.defaultOf(field);
      const w = field.widget === 'select' && str(field.source) ? recentChoice(field, value, ctx) : Widgets.create(field, value, ctx);
      widgets.set(field.id, { field, w });
      return h('div', { class: 'field', title: str(field.help) || null, data: { field: field.id } }, w.nodes, w.after || null);
    });
    const numeric = (f) => f && (f.widget === 'slider' || f.widget === 'duration');
    const out = [];
    for (let i = 0; i < blocks.length; i += 1) {
      if (numeric(fields[i]) && numeric(fields[i + 1])) { out.push(h('div', { class: 'pair' }, blocks[i], blocks[i + 1])); i += 1; } else out.push(blocks[i]);
    }
    const value = (id) => (widgets.has(id) ? widgets.get(id).w.get() : '');
    const labelFor = (id) => {
      const got = widgets.get(id);
      if (!got) return '';
      if (got.w.label) return got.w.label();
      const known = labelOf(got.field, got.w.get(), ctx.known);
      return known ? known.label : '';
    };
    return {
      el: h('div', { class: 'form' }, out),
      remember() { const flat = {}; for (const [id, got] of widgets) flat[id] = got.w.get(); memory.set(ctx.key, flat); },
      packet() {
        const pack = { n: {}, s: {}, b: {} };
        for (const [id, { field, w }] of widgets) {
          const map = Widgets.MAP[field.widget], v = w.get();
          pack[map][id] = map === 'n' ? (Number.isFinite(v) ? v : 0) : (map === 'b' ? v === true : Format.clip(String(v), 1200));
        }
        for (const map of ['n', 's', 'b']) if (Object.keys(pack[map]).length === 0) delete pack[map];
        return pack;
      },
      ghost() {
        const id = str(child.ghost && child.ghost.field), got = widgets.get(id);
        return got ? ghostOf(child, got.w.get(), labelOf(got.field, got.w.get(), ctx.known) || (got.w.label ? { label: got.w.label() } : null)) : null;
      },
      label: () => labelFor(str(child.autoTitle)),
      value,
    };
  }

  /**
   * Blocs d'une fiche à lieu, posés entre les champs hors groupes et les groupes repliés.
   * model { key, kind, child?, place?, distance? } ; actions { start(mode), go(row), remove(row), open(row), changed(),
   * lookup(field, q, p), known(field, v), remember(field, item) }
   */
  function build(model, actions) {
    const { h, icon } = UI;
    const { kind, child } = model;
    let place = cleanPlace(kind.placement, model.place), distance = model.distance, rows = [], listed = false;
    const line = h('p', { class: 'place-line' });
    const placeButton = h('button', { type: 'button', class: 'btn small', onclick: () => actions.start('self') });
    const lieuMsg = h('p', { class: 'err place-msg', role: 'alert', hidden: true });
    const nodes = [h('section', { class: 'place-box' }, h('h2', { class: 'gh', text: P.lieu }), h('div', { class: 'place-row' }, line, placeButton), lieuMsg)];
    let template = null, nextButton = null, nextMsg = null, look = null, count = null, items = null;

    if (child) {
      const f = Lifecycle.feminine(child);
      template = templateFields(child, {
        key: `${model.key}|${child.id}`, lookup: actions.lookup, known: actions.known, remember: actions.remember,
        changed: () => { template.remember(); showLook(); actions.changed(); },
      });
      look = h('p', { class: 'hp' });
      nextButton = h('button', { type: 'button', class: 'btn small dark', text: P.many(str(child.nounPlural)), onclick: () => actions.start('children') });
      nextMsg = h('p', { class: 'err place-msg', role: 'alert', hidden: true });
      nodes.push(h('section', { class: 'place-box' }, h('h2', { class: 'gh', text: P.next(f, str(child.noun)) }), template.el, look, nextButton, nextMsg));
      count = h('span', { class: 'hp' });
      items = h('div', { class: 'place-items', role: 'list' });
      nodes.push(h('section', { class: 'place-list' },
        h('div', { class: 'place-list-head' }, h('h2', { class: 'gh', text: P.list(str(child.nounPlural), Lifecycle.ofNoun(kind)) }), count), items));
    }

    function showLook() {
      const text = lookLine(template.ghost());
      look.textContent = text;
      look.hidden = !text;
    }

    function showLieu() {
      line.textContent = lieuLine(kind, place, distance);
      placeButton.textContent = place ? P.move(Lifecycle.theNoun(kind)) : P.put(Lifecycle.theNoun(kind));
      if (nextButton) nextButton.disabled = !place;
    }

    function itemNode(row) {
      const m = mark(row, child), go = center(row.place), rm = removal(row);
      const small = (name, label, onclick) => h('button', { type: 'button', class: 'ib', 'aria-label': label, title: label, onclick }, icon(name, 16, 2));
      return h('div', { class: `row place-item${row.tone === 'new' ? ' fresh' : ''}`, role: 'listitem' },
        h('button', { type: 'button', class: 'row-main', onclick: () => actions.open(row) },
          h('span', { class: `row-title${row.tone === 'removal' ? ' gone' : ''}`, text: row.title }), m ? h('span', { class: `mark mark-${m.tone}`, text: m.text }) : null),
        row.hint ? h('span', { class: 'hp', text: row.hint }) : null,
        go ? small('pin', P.goTo(row.title), () => actions.go(row, go)) : null,
        rm ? small('trash', P.remove(row.title), () => actions.remove(row, rm)) : null);
    }

    function showRows() {
      if (!items) return;
      items.replaceChildren(...rows.map(itemNode));
      count.textContent = listed ? countLine(rows, child) : P.loading;
    }

    function message(mode, text) {
      for (const node of [lieuMsg, nextMsg]) if (node) { node.textContent = ''; node.hidden = true; }
      const node = mode === 'children' && nextMsg ? nextMsg : lieuMsg;
      node.textContent = text || '';
      node.hidden = !text;
    }

    showLieu();
    if (template) showLook();
    showRows();
    return {
      el: h('div', { class: 'place-blocks' }, nodes),
      setPlace(value, far) { place = cleanPlace(kind.placement, value); if (far !== undefined) distance = far; showLieu(); },
      setRows(got) { if (!child) return; rows = list(got).map((r) => cleanRow(r, child)).filter(Boolean).slice(0, MAX_ROWS); listed = true; showRows(); },
      upsert(row) { const clean = child ? cleanRow(row, child) : null; if (clean) { rows = upsert(rows, clean); listed = true; showRows(); } },
      drop(id) { rows = rows.filter((r) => r.id !== id); showRows(); },
      failed(text) { if (count) count.textContent = text; },
      progress: () => ({ placed: Boolean(place), children: rows.some((r) => r.tone !== 'removal') }),
      message,
      template: () => (template ? template.packet() : null),
      ghost: () => (template ? template.ghost() : null),
      label: () => (template ? template.label() : ''),
    };
  }

  return { placeable, childOf, kindOf, cleanPlace, center, lieuLine, cleanRow, countLine, mark, removal, stepStates, ghostOf, lookLine, startPayload, upsert, build };
})();
