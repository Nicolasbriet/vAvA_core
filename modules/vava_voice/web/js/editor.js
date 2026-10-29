'use strict';
/*
 * web/js/editor.js
 * Rôle : l'éditeur des zones de voix, panneau de parchemin sur le côté (le monde reste visible : les zones y sont
 *        dessinées). Liste des zones (des plus proches aux plus lointaines), création centrée sur le membre du
 *        Conseil, modification (nom, rayon, hauteur, effet, recentrage), déplacement, suppression confirmée. Chaque
 *        réglage met à jour l'aperçu dans le monde ; chaque action est décidée par le serveur. Le nom se compte en
 *        signes, comme sur le serveur ; un seul « Sceller » à la fois.
 */

(() => {
  const S = STRINGS;
  const SLIP_MS = 3200;
  const root = document.getElementById('editor');
  const body = root.querySelector('.editor-body');
  const slipNode = root.querySelector('.slip');
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));

  const state = { zones: [], canTeleport: false, limits: null, form: null };
  let slipTimer = null;

  /** Élément : classes, texte (jamais de HTML), enfants. */
  function el(tag, className, text, children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    if (children) node.append(...children.filter(Boolean));
    return node;
  }

  function button(label, onClick, kind = 'ink') {
    const classes = { seal: 'seal-button', plain: 'plain-button' };
    const node = el('button', classes[kind] || 'ink-button', label);
    node.type = 'button';
    node.addEventListener('click', onClick);
    return node;
  }

  function slip(message) {
    slipNode.textContent = message;
    slipNode.hidden = false;
    clearTimeout(slipTimer);
    slipTimer = setTimeout(() => { slipNode.hidden = true; }, SLIP_MS);
  }

  /** Réponse du jeu : mot d'erreur si refus ; renvoie result.ok. */
  function report(result, success) {
    if (!result.ok) slip(S.error(result.error));
    else if (success) slip(success);
    return result.ok;
  }

  // Liste -------------------------------------------------------------------------------------------------------

  function renderList() {
    state.form = null;
    const { limits } = state;
    const entries = state.zones.map((zone) => {
      const node = el('button', 'entry', null, [
        el('span', `effect-dot effect-${zone.multiplier < 1 ? 'quiet' : zone.multiplier > 1 ? 'loud' : 'neutral'}`),
        el('span', 'entry-main', null, [el('span', 'entry-name', zone.label), el('span', 'entry-sub', S.entrySub(zone))]),
        el('span', 'entry-distance', S.distance(zone.distance)),
      ]);
      node.type = 'button';
      node.addEventListener('click', () => openForm(zone));
      return node;
    });
    const create = button(S.create, () => openForm(null), 'seal');
    create.disabled = state.zones.length >= limits.max;
    body.replaceChildren(
      el('p', 'hint', S.intro),
      el('div', 'list-head', null, [el('span', 'count', S.count(state.zones.length, limits.max)), create]),
      entries.length ? el('div', 'entries', null, entries) : el('p', 'empty', S.empty),
    );
  }

  // Formulaire ----------------------------------------------------------------------------------------------------

  function values() {
    const { form } = state;
    return {
      id: form.zone ? form.zone.id : undefined,
      label: form.name.value.trim(),
      radius: Number(form.radius.value),
      height: Number(form.height.value),
      multiplier: form.multiplier,
      moveHere: form.moveHere ? form.moveHere.checked : false,
    };
  }

  /** Portées avant et après l'effet choisi. */
  function renderEffect() {
    const { form } = state;
    for (const stamp of form.stamps.children) stamp.classList.toggle('is-selected', Number(stamp.dataset.value) === form.multiplier);
    form.explain.replaceChildren(...list(state.limits.ranges).map((range) => el('li', null, S.rangeLine(range.label, range.distance, range.distance * form.multiplier))));
  }

  function changed() {
    const { form } = state;
    form.radiusValue.textContent = S.meters(Number(form.radius.value));
    form.heightValue.textContent = S.meters(Number(form.height.value));
    renderEffect();
    Bridge.post('preview', values());
  }

  function slider(label, bounds, value, hint) {
    const input = el('input', 'slider');
    input.type = 'range';
    input.min = String(bounds.min);
    input.max = String(bounds.max);
    input.step = String(bounds.step);
    input.value = String(value);
    input.addEventListener('input', changed);
    const shown = el('span', 'slider-value', S.meters(value));
    const id = `field-${label}`;
    input.id = id;
    const caption = el('label', 'field-label', label);
    caption.htmlFor = id;
    return {
      input, shown,
      node: el('div', 'field', null, [el('div', 'field-row', null, [caption, shown]), input, hint ? el('span', 'field-help', hint) : null]),
    };
  }

  async function save() {
    const { form } = state;
    // une demande à la fois : Entrée répété (ou maintenu) pendant l'attente ne scelle pas une seconde zone
    if (!form || form.saving) return;
    const data = values();
    if (!data.label) {
      slip(S.error('invalid_label'));
      form.name.focus();
      return;
    }
    form.saving = true;
    form.saveButton.disabled = true;
    const result = await Bridge.post('save', data);
    form.saving = false;
    if (state.form === form) form.saveButton.disabled = false;
    if (report(result, S.saved(data.label))) renderList();
  }

  async function remove(zone, node) {
    if (!node.classList.contains('is-armed')) {
      node.classList.add('is-armed');
      node.textContent = S.confirmRemove;
      return;
    }
    const result = await Bridge.post('delete', { id: zone.id });
    if (report(result, S.removed(zone.label))) renderList();
  }

  async function cancel() {
    await Bridge.post('cancel');
    renderList();
  }

  async function openForm(zone) {
    const { limits } = state;
    const started = await Bridge.post(zone ? 'edit' : 'startNew', zone ? { id: zone.id } : {});
    if (!report(started)) return;
    const name = el('input', 'field-input');
    name.type = 'text';
    // le serveur compte le nom en signes (un « é » ou un emoji pour un) ; maxLength compte en unités UTF-16 (un
    // emoji pour deux) : il ne sert que de garde, la saisie est ramenée au nombre de signes permis
    name.maxLength = limits.labelMax * 2;
    name.placeholder = S.namePlaceholder;
    name.value = zone ? zone.label : '';
    name.id = 'field-name';
    name.addEventListener('input', () => {
      const signs = Array.from(name.value);
      if (signs.length > limits.labelMax) name.value = signs.slice(0, limits.labelMax).join('');
    });
    name.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter') return;
      event.preventDefault();
      save();
    });
    const nameLabel = el('label', 'field-label', S.name);
    nameLabel.htmlFor = 'field-name';
    const radius = slider(S.radius, limits.radius, zone ? zone.radius : limits.radius.default);
    const height = slider(S.height, limits.height, zone ? zone.height : limits.height.default, S.heightHint(limits.baseOffset));
    const stamps = el('div', 'stamps');
    stamps.setAttribute('role', 'radiogroup');
    for (const multiplier of list(limits.multipliers)) {
      const stamp = el('button', 'stamp', null, [el('span', 'stamp-value', S.effect(multiplier)), el('span', 'stamp-label', S.effects[multiplier] || '')]);
      stamp.type = 'button';
      stamp.dataset.value = String(multiplier);
      stamp.setAttribute('role', 'radio');
      stamp.addEventListener('click', () => {
        state.form.multiplier = multiplier;
        changed();
      });
      stamps.append(stamp);
    }
    let moveHere = null;
    let moveNode = null;
    if (zone) {
      moveHere = el('input');
      moveHere.type = 'checkbox';
      moveHere.addEventListener('change', changed);
      moveNode = el('label', 'choice', null, [moveHere, el('span', null, S.moveHere)]);
    }
    const saveButton = button(S.save, save, 'seal');
    const actions = [button(S.cancel, cancel), saveButton];
    const extra = [];
    if (zone && state.canTeleport) {
      extra.push(button(S.reach, async () => report(await Bridge.post('reach', { id: zone.id }), S.reached)));
    }
    if (zone) {
      const removeButton = button(S.remove, () => remove(zone, removeButton), 'plain');
      extra.push(removeButton);
    }
    const explain = el('ul', 'explain');
    state.form = {
      zone, name, radius: radius.input, height: height.input, radiusValue: radius.shown, heightValue: height.shown,
      stamps, explain, moveHere, saveButton, multiplier: zone ? zone.multiplier : limits.defaultMultiplier,
    };
    body.replaceChildren(...[
      el('h2', 'form-title', zone ? S.editTitle : S.newTitle),
      zone ? null : el('p', 'hint', S.newHint),
      el('div', 'field', null, [nameLabel, name]),
      radius.node,
      height.node,
      el('div', 'field', null, [el('span', 'field-label', S.effectLabel), stamps, explain]),
      moveNode,
      el('div', 'form-actions', null, actions),
      extra.length ? el('div', 'form-extra', null, extra) : null,
    ].filter(Boolean));
    changed();
    name.focus();
  }

  // Messages du jeu -----------------------------------------------------------------------------------------------

  function close() {
    root.hidden = true;
    state.form = null;
  }

  const handlers = {
    open(payload) {
      state.zones = list(payload.zones);
      state.canTeleport = Boolean(payload.canTeleport);
      state.limits = payload.limits;
      root.querySelector('.editor-title').replaceChildren(el('span', 'lettrine', S.title[0]), document.createTextNode(S.title.slice(1)));
      root.hidden = false;
      renderList();
    },
    zones(payload) {
      state.zones = list(payload.zones);
      if (!root.hidden && !state.form) renderList();
    },
    close,
  };

  Bridge.onMessage((action, payload) => {
    if (handlers[action]) handlers[action](payload);
  });

  root.querySelector('[data-action="close"]').setAttribute('aria-label', S.close);
  root.querySelector('[data-action="close"]').addEventListener('click', () => Bridge.post('close'));
  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape' || root.hidden) return;
    if (state.form) cancel();
    else Bridge.post('close');
  });

  if (Bridge.inGame) Bridge.post('ready');
  else DevMock.start();
})();
