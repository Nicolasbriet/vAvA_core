'use strict';
/*
 * web/dev/devmock.js
 * Rôle : données simulées quand la page est ouverte dans un navigateur (hors FiveM), pour travailler le rendu
 *        sans lancer le jeu. Inactif en jeu : aucun appel n'y est routé.
 *        Paramètres d'URL : ?screen=creator&tab=hair&sex=f
 *        Jamais livré (absent des `files`), jamais chargé en jeu : la ligne hors jeu de index.html ne l'insère
 *        que hors FiveM.
 */

const DevMock = (() => {
  const inGame = typeof GetParentResourceName === 'function';
  const characters = [
    { id: 3, firstName: 'Éloïse', lastName: 'd\'Aubigné', sex: 'f' },
    { id: 7, firstName: 'Aldric', lastName: 'Morvan', sex: 'm' },
  ];
  // règles de nom envoyées par le core avec la liste (valeurs par défaut de config/server.lua)
  const nameRules = {
    minLength: 2, maxLength: 24, separators: ' \'-',
    letters: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZàâäáãåæçéèêëíìîïñóòôöõøœúùûüýÿÀÂÄÁÃÅÆÇÉÈÊËÍÌÎÏÑÓÒÔÖÕØŒÚÙÛÜÝŸ',
  };
  const listed = () => ({ ok: true, characters, max: 3, nameRules });
  const OVERLAY_IDS = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  const COLOR_TYPES = { 1: 1, 2: 1, 10: 1, 5: 2, 8: 2 };

  const limits = {
    parents: 46, features: 20, eyeColors: 32, hairStyles: 76, hairColors: 64, makeupColors: 64,
    overlays: OVERLAY_IDS.map((id) => ({ id, styles: [24, 29, 34, 15, 72, 7, 12, 11, 10, 18, 17][id], colorType: COLOR_TYPES[id] || 0 })),
    components: [{ id: 11, drawables: 392 }, { id: 8, drawables: 188 }, { id: 3, drawables: 196 }, { id: 4, drawables: 143 }, { id: 6, drawables: 101 }],
    props: [{ id: 0, drawables: 152 }, { id: 1, drawables: 34 }, { id: 2, drawables: 41 }],
  };

  const lerp = (a, b, t) => Math.round(a + (b - a) * t);
  const ramp = (count, from, to) => Array.from({ length: count }, (_, i) => {
    const t = i / (count - 1);
    return [lerp(from[0], to[0], t), lerp(from[1], to[1], t), lerp(from[2], to[2], t)];
  });
  const palettes = { hair: ramp(64, [20, 14, 10], [238, 214, 168]), makeup: ramp(64, [120, 20, 40], [250, 170, 160]) };

  function defaults(sex) {
    return {
      heritage: { mother: 21, father: 0, shapeMix: sex === 'f' ? 0 : 0.5, skinMix: 0.5 },
      features: Array.from({ length: 20 }, () => 0),
      hair: { style: 4, texture: 0, color: 0, highlight: 0 },
      eyeColor: 0,
      overlays: OVERLAY_IDS.map((id) => ({ id, style: id === 2 ? 0 : 255, opacity: 1, color: 0 })),
      components: [11, 8, 3, 4, 6].map((id) => ({ id, drawable: id === 8 ? (sex === 'f' ? 14 : 15) : id === 6 ? 1 : 0, texture: 0 })),
      props: [0, 1, 2].map((id) => ({ id, drawable: -1, texture: 0 })),
    };
  }

  const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  async function handle(name, data) {
    await delay(name === 'preview' || name === 'rotate' ? 0 : 120);
    switch (name) {
      case 'list':
        return listed();
      case 'startCreator':
      case 'setSex': {
        const sex = data.sex === 'f' ? 'f' : 'm';
        return { ok: true, sex, appearance: defaults(sex), limits, palettes };
      }
      case 'preview':
      case 'textures':
        return { ok: true, textures: 8 };
      case 'cancelCreator':
        return listed();
      case 'delete': {
        const index = characters.findIndex((c) => c.id === data.id);
        if (index >= 0) characters.splice(index, 1);
        return listed();
      }
      case 'create':
        characters.push({ id: 9, firstName: data.firstName, lastName: data.lastName, sex: data.sex });
        return { ok: true };
      default:
        return { ok: true };
    }
  }

  if (!inGame) {
    window.addEventListener('DOMContentLoaded', () => {
      document.body.classList.add('dev');
      window.postMessage({ action: 'open', payload: listed() }, '*');
    });
  }

  return { handle, inGame };
})();
