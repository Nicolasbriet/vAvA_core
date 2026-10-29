'use strict';
/*
 * web/js/creator.js
 * Rôle : éditeur de création. Sept onglets guidés (identité → tenue), aperçu en direct sur le ped local,
 *        caméra adaptée à chaque onglet, aléatoire et réinitialisation par onglet, rotation au glisser.
 *        Fluidité : chaque changement n'envoie que la partie modifiée, planifiée par Bridge.schedule.
 */

const Creator = (() => {
  const T = STRINGS.creator;
  const TABS = ['identity', 'heritage', 'face', 'hair', 'skin', 'makeup', 'outfit'];
  const TAB_VIEW = { identity: 'body', heritage: 'face', face: 'face', hair: 'face', skin: 'face', makeup: 'face', outfit: 'body' };
  const OVERLAY_NONE = 255;
  const EYEBROWS = 2;
  const MALE_OVERLAYS = [1, 10];          // barbe, pilosité du torse
  const SKIN_OVERLAYS = [0, 3, 6, 7, 9];
  const MAKEUP_OVERLAYS = [4, 5, 8];
  const ARMS_COMPONENT = 3;               // ajusté à la main : un tirage aléatoire crée des manques visibles
  const NATURAL_EYE_COLORS = 8;           // teintes 1 à 8 : couleurs naturelles du jeu
  const ROTATE_SENSITIVITY = 0.45;        // degrés par pixel glissé
  const ROTATE_KEY_STEP = 15;

  let refs = null;
  let handlers = null;
  let state = null;
  let view = null;
  let dragX = null;
  let pendingRotation = 0;

  const clone = (value) => JSON.parse(JSON.stringify(value));
  const percent = (value) => `${Math.round(value * 100)} %`;
  const signed = (value) => {
    const p = Math.round(value * 100);
    return p > 0 ? `+${p}` : String(p);
  };
  const randomInt = (min, max) => (max < min ? min : Math.floor(Math.random() * (max - min + 1)) + min);
  const randomFloat = (min, max) => Math.round((Math.random() * (max - min) + min) * 100) / 100;
  const chance = (probability) => Math.random() < probability;
  const byId = (list, id) => list.find((item) => item.id === id);
  const limitOf = (list, id) => byId(list, id) || { drawables: 0, styles: 0, colorType: 0 };
  const styleCount = (id) => limitOf(state.limits.overlays, id).styles;

  // Règles de nom du serveur (characters.name du core, reçues avec la liste des personnages) : la saisie est vérifiée
  // comme le serveur la vérifiera. Sans elles (core antérieur à 0.8.0), seul le serveur juge : tout nom non vide passe.
  let nameRules = null;

  /** Retient les règles reçues du jeu ({ minLength, maxLength, letters, separators }) ; illisibles : ignorées. */
  function setNameRules(rules) {
    const readable = rules && Number.isInteger(rules.minLength) && Number.isInteger(rules.maxLength)
      && typeof rules.letters === 'string' && typeof rules.separators === 'string';
    nameRules = readable ? {
      min: rules.minLength, max: rules.maxLength,
      letters: new Set(Array.from(rules.letters)), separators: Array.from(rules.separators),
    } : null;
  }

  /** Même contrôle que le serveur : longueur en caractères, chaque caractère pris dans les lettres ou les séparateurs,
   *  un séparateur jamais en tête, en fin ni doublé. */
  function validName(value) {
    const characters = Array.from(value.trim());
    if (!nameRules) return characters.length > 0;
    if (characters.length < nameRules.min || characters.length > nameRules.max) return false;
    let afterSeparator = true;   // interdit un séparateur en tête
    for (const character of characters) {
      if (nameRules.separators.includes(character)) {
        if (afterSeparator) return false;
        afterSeparator = true;
      } else if (nameRules.letters.has(character)) {
        afterSeparator = false;
      } else {
        return false;
      }
    }
    return !afterSeparator;
  }

  /** Rappel de la règle sous le champ, tiré des règles reçues. */
  function nameHint() {
    if (!nameRules) return '';
    const S = STRINGS.identity;
    return S.nameHint(nameRules.min, nameRules.max, nameRules.separators.map((s) => S.separatorNames[s] || `« ${s} »`));
  }

  const identityValid = () => validName(state.firstName) && validName(state.lastName);

  // Aperçu ----------------------------------------------------------------------------------------------

  /** Envoie une partie de l'apparence ; `onResult` reçoit la réponse (nombre de variantes…). */
  function preview(part, value, key = part, onResult) {
    state.dirty = true;
    const snapshot = clone(value);
    Bridge.schedule(key, () => Bridge.post('preview', { part, value: snapshot }).then((result) => {
      if (onResult && result && result.ok) onResult(result);
    }));
  }

  function applyAll() {
    state.dirty = true;
    const snapshot = clone(state.appearance);
    Bridge.schedule('all', () => Bridge.post('applyAll', { appearance: snapshot }));
  }

  function requestTextures(kind, id, drawable, control) {
    if (drawable < 0) {
      control.setMax(0);
      return;
    }
    Bridge.post('textures', { kind, id, drawable }).then((result) => {
      if (result && result.ok) control.setMax(Math.max(0, result.textures - 1));
    });
  }

  function setView(next) {
    if (next === view) return;
    view = next;
    for (const button of refs.views) button.classList.toggle('is-selected', button.dataset.view === next);
    Bridge.post('camera', { view: next });
  }

  function queueRotation(delta) {
    pendingRotation += delta;
    Bridge.schedule('rotate', () => {
      const amount = pendingRotation;
      pendingRotation = 0;
      return Bridge.post('rotate', { delta: amount });
    });
  }

  // Transformations par onglet (aléatoire, réinitialisation) ---------------------------------------------

  function copyOverlays(target, source, ids) {
    for (const id of ids) Object.assign(byId(target.overlays, id), clone(byId(source.overlays, id)));
  }

  const randomizers = {
    heritage(a, limits) {
      a.heritage = {
        mother: randomInt(0, limits.parents - 1), father: randomInt(0, limits.parents - 1),
        shapeMix: randomFloat(0, 1), skinMix: randomFloat(0, 1),
      };
    },
    face(a) {
      a.features = a.features.map(() => randomFloat(-0.5, 0.5));
    },
    hair(a, limits) {
      const color = randomInt(0, limits.hairColors - 1);
      a.hair = { style: randomInt(0, limits.hairStyles - 1), texture: 0, color, highlight: chance(0.5) ? color : randomInt(0, limits.hairColors - 1) };
      for (const overlay of a.overlays) {
        if (overlay.id === EYEBROWS) Object.assign(overlay, { style: randomInt(0, styleCount(overlay.id) - 1), opacity: randomFloat(0.6, 1), color });
        if (MALE_OVERLAYS.includes(overlay.id)) {
          Object.assign(overlay, state.sex === 'm' && chance(0.6)
            ? { style: randomInt(0, styleCount(overlay.id) - 1), opacity: randomFloat(0.5, 1), color }
            : { style: OVERLAY_NONE });
        }
      }
      a.eyeColor = randomInt(0, NATURAL_EYE_COLORS - 1);
    },
    skin(a) {
      for (const overlay of a.overlays) {
        if (!SKIN_OVERLAYS.includes(overlay.id)) continue;
        Object.assign(overlay, chance(0.5) ? { style: randomInt(0, styleCount(overlay.id) - 1), opacity: randomFloat(0.15, 0.6) } : { style: OVERLAY_NONE });
      }
    },
    makeup(a, limits) {
      for (const overlay of a.overlays) {
        if (!MAKEUP_OVERLAYS.includes(overlay.id)) continue;
        Object.assign(overlay, state.sex === 'f' && chance(0.6)
          ? { style: randomInt(0, styleCount(overlay.id) - 1), opacity: randomFloat(0.3, 0.9), color: randomInt(0, limits.makeupColors - 1) }
          : { style: OVERLAY_NONE });
      }
    },
    outfit(a, limits) {
      for (const component of a.components) {
        if (component.id === ARMS_COMPONENT) continue;
        component.drawable = randomInt(0, limitOf(limits.components, component.id).drawables - 1);
        component.texture = 0;
      }
      for (const prop of a.props) {
        prop.drawable = chance(0.3) ? randomInt(0, limitOf(limits.props, prop.id).drawables - 1) : -1;
        prop.texture = 0;
      }
    },
  };

  const resetters = {
    heritage(a, d) { a.heritage = clone(d.heritage); },
    face(a, d) { a.features = clone(d.features); },
    hair(a, d) {
      a.hair = clone(d.hair);
      a.eyeColor = d.eyeColor;
      copyOverlays(a, d, [EYEBROWS, ...MALE_OVERLAYS]);
    },
    skin(a, d) { copyOverlays(a, d, SKIN_OVERLAYS); },
    makeup(a, d) { copyOverlays(a, d, MAKEUP_OVERLAYS); },
    outfit(a, d) {
      a.components = clone(d.components);
      a.props = clone(d.props);
    },
  };

  function transform(kind, tab) {
    if (kind === 'random') randomizers[tab](state.appearance, state.limits);
    else resetters[tab](state.appearance, state.defaults);
    applyAll();
    renderContent();
  }

  function tabActions(tab) {
    return UI.el('div', { class: 'group-actions' }, [
      UI.iconButton('random', T.random, () => transform('random', tab)),
      UI.iconButton('reset', T.reset, () => transform('reset', tab)),
    ]);
  }

  // Onglets ---------------------------------------------------------------------------------------------

  function buildIdentity() {
    const S = STRINGS.identity;
    const nameField = (key, label, hint) => {
      const field = UI.textField({
        label, value: state[key], maxLength: nameRules ? nameRules.max : undefined, hint,
        onInput: (value) => {
          state[key] = value;
          field.setError(value.trim() && !validName(value) ? S.nameInvalid : '');
          updateFooter();
        },
      });
      if (state[key] && !validName(state[key])) field.setError(S.nameInvalid);
      return field;
    };
    // la règle n'est rappelée qu'une fois, sous le second champ
    const first = nameField('firstName', S.firstName, '');
    const last = nameField('lastName', S.lastName, nameHint());
    const sex = UI.segmented({
      label: S.sex, value: state.sex, onChange: changeSex,
      options: [{ value: 'm', label: STRINGS.sexes.m }, { value: 'f', label: STRINGS.sexes.f }],
    });
    setTimeout(() => first.input.focus(), 0);
    return [UI.group(null, [first.node, last.node]), UI.group(null, [sex.node])];
  }

  function buildHeritage() {
    const H = STRINGS.heritage;
    const heritage = state.appearance.heritage;
    const send = () => preview('heritage', heritage);
    const parent = (key, label) => UI.stepper({
      label, min: 0, max: state.limits.parents - 1, value: heritage[key], format: (v) => H.face(v + 1),
      onChange: (v) => { heritage[key] = v; send(); },
    }).node;
    const mix = (key, label) => UI.slider({
      label, min: 0, max: 1, step: 0.01, value: heritage[key], format: percent, legends: [H.mother, H.father],
      onInput: (v) => { heritage[key] = v; send(); },
    }).node;
    return [
      UI.group(H.parents, [parent('mother', H.mother), parent('father', H.father)], tabActions('heritage')),
      UI.group(H.blend, [mix('shapeMix', H.shapeMix), mix('skinMix', H.skinMix)]),
    ];
  }

  function buildFace() {
    const features = state.appearance.features;
    return STRINGS.featureGroups.map((group, index) => UI.group(group.title, group.features.map((i) => UI.slider({
      label: STRINGS.features[i], min: -1, max: 1, step: 0.01, value: features[i], format: signed,
      onInput: (v) => { features[i] = v; preview('feature', { index: i + 1, value: v }, `feature${i}`); },
    }).node), index === 0 ? tabActions('face') : null));
  }

  function overlayGroup(id, palette, colorCount, actions) {
    const O = STRINGS.overlay;
    const overlay = byId(state.appearance.overlays, id);
    const limit = limitOf(state.limits.overlays, id);
    const send = () => preview('overlay', overlay, `overlay${id}`);
    const controls = [
      UI.stepper({
        label: O.style, min: -1, max: limit.styles - 1, value: overlay.style === OVERLAY_NONE ? -1 : overlay.style,
        format: (v) => (v < 0 ? T.none : String(v + 1)),
        onChange: (v) => { overlay.style = v < 0 ? OVERLAY_NONE : v; send(); },
      }).node,
      UI.slider({
        label: O.opacity, min: 0, max: 1, step: 0.01, value: overlay.opacity, format: percent,
        onInput: (v) => { overlay.opacity = v; send(); },
      }).node,
    ];
    if (limit.colorType && palette) {
      controls.push(UI.colorPicker({
        label: O.color, colors: palette.slice(0, colorCount), value: overlay.color,
        onPick: (v) => { overlay.color = v; send(); },
      }).node);
    }
    return UI.group(STRINGS.overlays[id], controls, actions);
  }

  function buildHair() {
    const H = STRINGS.hair;
    const appearance = state.appearance;
    const hair = appearance.hair;
    const limits = state.limits;
    const palette = state.palettes.hair.slice(0, limits.hairColors);
    const send = (onResult) => preview('hair', hair, 'hair', onResult);

    const variant = UI.stepper({ label: H.variant, min: 0, max: 0, value: hair.texture, onChange: (v) => { hair.texture = v; send(); } });
    requestTextures('hair', 0, hair.style, variant);
    const style = UI.stepper({
      label: H.style, min: 0, max: limits.hairStyles - 1, value: hair.style,
      onChange: (v) => {
        hair.style = v;
        hair.texture = 0;
        variant.set(0);
        send((result) => variant.setMax(Math.max(0, result.textures - 1)));
      },
    });
    const groups = [UI.group(H.title, [
      UI.el('div', { class: 'pair' }, [style.node, variant.node]),
      UI.colorPicker({ label: H.color, colors: palette, value: hair.color, onPick: (v) => { hair.color = v; send(); } }).node,
      UI.colorPicker({ label: H.highlight, colors: palette, value: hair.highlight, onPick: (v) => { hair.highlight = v; send(); } }).node,
    ], tabActions('hair'))];

    const overlays = state.sex === 'm' ? [EYEBROWS, ...MALE_OVERLAYS] : [EYEBROWS];
    for (const id of overlays) groups.push(overlayGroup(id, state.palettes.hair, limits.hairColors));

    groups.push(UI.group(H.eyes, [UI.stepper({
      label: H.eyeColor, min: 0, max: limits.eyeColors - 1, value: appearance.eyeColor, format: (v) => H.eyeShade(v + 1),
      onChange: (v) => { appearance.eyeColor = v; preview('eyeColor', v); },
    }).node]));
    return groups;
  }

  function buildSkin() {
    return SKIN_OVERLAYS.map((id, index) => overlayGroup(id, null, 0, index === 0 ? tabActions('skin') : null));
  }

  function buildMakeup() {
    return MAKEUP_OVERLAYS.map((id, index) => overlayGroup(id, state.palettes.makeup, state.limits.makeupColors, index === 0 ? tabActions('makeup') : null));
  }

  function clothingPair(kind, item, drawables, label) {
    const O = STRINGS.outfit;
    const key = `${kind}${item.id}`;
    const variant = UI.stepper({ label: O.variant, min: 0, max: 0, value: item.texture, onChange: (v) => { item.texture = v; preview(kind, item, key); } });
    variant.setEnabled(item.drawable >= 0);
    requestTextures(kind, item.id, item.drawable, variant);
    const model = UI.stepper({
      label, min: kind === 'prop' ? -1 : 0, max: drawables - 1, value: item.drawable,
      format: (v) => (v < 0 ? T.none : String(v + 1)),
      onChange: (v) => {
        item.drawable = v;
        item.texture = 0;
        variant.set(0);
        variant.setEnabled(v >= 0);
        preview(kind, item, key, (result) => variant.setMax(Math.max(0, (result.textures || 0) - 1)));
      },
    });
    return UI.el('div', { class: 'pair' }, [model.node, variant.node]);
  }

  function buildOutfit() {
    const O = STRINGS.outfit;
    const { components, props } = state.appearance;
    const limits = state.limits;
    return [
      UI.group(O.clothes, components.map((c) => clothingPair('component', c, limitOf(limits.components, c.id).drawables, STRINGS.components[c.id])), tabActions('outfit')),
      UI.el('p', { class: 'note', text: O.armsHint }),
      UI.group(O.accessories, props.map((p) => clothingPair('prop', p, limitOf(limits.props, p.id).drawables, STRINGS.props[p.id]))),
    ];
  }

  const BUILDERS = { identity: buildIdentity, heritage: buildHeritage, face: buildFace, hair: buildHair, skin: buildSkin, makeup: buildMakeup, outfit: buildOutfit };

  // Rendu et navigation ----------------------------------------------------------------------------------

  function renderContent() {
    refs.content.replaceChildren(...BUILDERS[state.tab]());
  }

  function updateFooter() {
    const index = TABS.indexOf(state.tab);
    refs.previous.disabled = state.busy || index === 0;
    refs.next.hidden = index === TABS.length - 1;
    refs.next.disabled = state.busy;
    refs.create.disabled = state.busy || !identityValid();
    refs.step.textContent = T.step(index + 1, TABS.length);
  }

  function selectTab(tab) {
    state.tab = TABS.includes(tab) ? tab : TABS[0];
    for (const button of refs.rail.children) {
      const active = button.dataset.tab === state.tab;
      button.classList.toggle('is-active', active);
      button.setAttribute('aria-selected', active ? 'true' : 'false');
    }
    refs.content.scrollTop = 0;
    renderContent();
    setView(TAB_VIEW[state.tab]);
    updateFooter();
  }

  function buildRail() {
    refs.rail.replaceChildren(...TABS.map((tab) => UI.el('button', {
      type: 'button', class: 'rail-tab', role: 'tab', 'data-tab': tab, onclick: () => selectTab(tab),
    }, [UI.icon(tab), UI.el('span', { class: 'rail-label', text: STRINGS.tabs[tab] })])));
  }

  function setBusy(busy) {
    state.busy = busy;
    refs.panel.classList.toggle('is-busy', busy);
    updateFooter();
  }

  /** Charge un modèle reçu du jeu (ouverture ou changement de sexe). */
  function loadModel(result) {
    state.sex = result.sex;
    state.appearance = result.appearance;
    state.defaults = clone(result.appearance);
    state.limits = result.limits;
    if (result.palettes) state.palettes = result.palettes;
    state.dirty = false;
  }

  async function changeSex(next) {
    if (state.busy) return;
    if (state.dirty) {
      const confirmed = await Feedback.confirm({ title: T.sexChangeTitle, message: T.sexChangeMessage, confirmLabel: T.sexChangeConfirm, cancelLabel: T.keep });
      if (!confirmed) {
        renderContent();
        return;
      }
    }
    setBusy(true);
    const result = await Bridge.post('setSex', { sex: next });
    setBusy(false);
    if (!result.ok) {
      handlers.onError(result.error);
      renderContent();
      return;
    }
    loadModel(result);
    renderContent();
  }

  async function create() {
    if (state.busy) return;
    if (!identityValid()) {
      selectTab('identity');
      handlers.onError('invalid_name');
      return;
    }
    const firstName = state.firstName.trim();
    const lastName = state.lastName.trim();
    const confirmed = await Feedback.confirm({
      title: T.confirmTitle, message: T.confirmMessage(`${firstName} ${lastName}`), confirmLabel: T.confirm, cancelLabel: T.keep,
    });
    if (!confirmed) return;
    setBusy(true);
    refs.create.textContent = T.creating;
    const result = await Bridge.post('create', { firstName, lastName, sex: state.sex, appearance: state.appearance });
    refs.create.textContent = T.create;
    setBusy(false);
    if (result.ok) {
      handlers.onCreated();
      return;
    }
    handlers.onError(result.error);
    // créé mais non chargé : le personnage existe, retour à la sélection
    if (result.created) {
      handlers.onCancelled(await Bridge.post('list'));
    } else if (result.error === 'invalid_name' || result.error === 'name_taken') {
      selectTab('identity');
    }
  }

  async function cancel() {
    if (state.busy) return;
    if (state.dirty || state.firstName || state.lastName) {
      const confirmed = await Feedback.confirm({ title: T.cancelTitle, message: T.cancelMessage, confirmLabel: T.cancelConfirm, cancelLabel: T.keep, danger: true });
      if (!confirmed) return;
    }
    handlers.onCancelled(await Bridge.post('cancelCreator'));
  }

  function rotateBy(direction) {
    queueRotation(direction * ROTATE_KEY_STEP);
  }

  function bindViewport() {
    const viewport = refs.viewport;
    viewport.addEventListener('pointerdown', (event) => {
      dragX = event.clientX;
      viewport.setPointerCapture(event.pointerId);
      viewport.classList.add('is-dragging');
    });
    viewport.addEventListener('pointermove', (event) => {
      if (dragX === null) return;
      const delta = event.clientX - dragX;
      dragX = event.clientX;
      if (delta !== 0) queueRotation(delta * ROTATE_SENSITIVITY);
    });
    const end = () => {
      dragX = null;
      viewport.classList.remove('is-dragging');
    };
    viewport.addEventListener('pointerup', end);
    viewport.addEventListener('pointercancel', end);
  }

  function init(root, callbacks) {
    handlers = callbacks;
    refs = {
      panel: root.querySelector('.panel'),
      rail: root.querySelector('.rail'),
      content: root.querySelector('.panel-content'),
      previous: root.querySelector('[data-action="previous"]'),
      next: root.querySelector('[data-action="next"]'),
      create: root.querySelector('[data-action="create"]'),
      step: root.querySelector('.panel-step'),
      viewport: root.querySelector('.viewport'),
      views: [...root.querySelectorAll('[data-view]')],
    };
    root.querySelector('.panel-title').textContent = T.title;
    root.querySelector('.viewport-hint').replaceChildren(...T.rotateHint.map(([key, label]) => UI.el('span', { class: 'hint' }, [UI.el('kbd', { text: key }), label])));
    const cancelButton = root.querySelector('[data-action="cancel"]');
    cancelButton.setAttribute('title', T.cancel);
    cancelButton.setAttribute('aria-label', T.cancel);
    cancelButton.replaceChildren(UI.icon('close'));
    cancelButton.addEventListener('click', cancel);
    refs.previous.append(UI.icon('left'), UI.el('span', { text: T.previous }));
    refs.next.append(UI.el('span', { text: T.next }), UI.icon('right'));
    refs.create.textContent = T.create;
    refs.previous.addEventListener('click', () => selectTab(TABS[TABS.indexOf(state.tab) - 1]));
    refs.next.addEventListener('click', () => selectTab(TABS[TABS.indexOf(state.tab) + 1]));
    refs.create.addEventListener('click', create);
    for (const button of refs.views) {
      button.textContent = T.views[button.dataset.view];
      button.addEventListener('click', () => setView(button.dataset.view));
    }
    bindViewport();
  }

  /** Ouvre l'éditeur avec le modèle reçu du jeu. */
  function open(result, tab) {
    state = { firstName: '', lastName: '', tab: 'identity', busy: false, palettes: { hair: [], makeup: [] } };
    view = null;
    loadModel(result);
    buildRail();
    refs.panel.classList.remove('is-busy');
    selectTab(tab || 'identity');
  }

  return { init, open, cancel, rotateBy, setNameRules };
})();
