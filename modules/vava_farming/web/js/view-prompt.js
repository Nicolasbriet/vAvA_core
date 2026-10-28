'use strict';
/*
 * web/js/view-prompt.js
 * Rôle : l'invite près d'un emplacement (« [E] Cultiver — Emplacement 3 · Blé, pousse, stade 2 / 3 »), d'un puits
 *        (« Remplir le seau ») ou d'un grenier (« Ouvrir »). Rien n'est animé en continu : l'invite ne change que quand
 *        le jeu l'envoie.
 */

const PromptView = (() => {
  const prompt = document.getElementById('prompt');
  const refs = {
    key: prompt.querySelector('.prompt-key'),
    verb: prompt.querySelector('.prompt-verb'),
    label: prompt.querySelector('.prompt-label'),
    type: prompt.querySelector('.prompt-type'),
    help: prompt.querySelector('.prompt-help'),
  };

  /** Texte de la culture d'un emplacement : « Blé, pousse, stade 2 / 3 » / « Blé, mûr » / « libre ». */
  function cropText(payload) {
    const P = STRINGS.prompt;
    if (!payload.crop) return P.free;
    const parts = [payload.cropLabel || payload.crop];
    const state = payload.state && STRINGS.states[payload.state];
    if (state) parts.push(state);
    if (payload.state === 'growing' && Number(payload.stages) > 0) parts.push(P.stage(Number(payload.stage) || 1, Number(payload.stages)));
    return parts.join(', ');
  }

  /** Invite : { kind = slot | well | granary, key, … }. */
  function show(payload) {
    const P = STRINGS.prompt;
    refs.key.textContent = payload.key || 'E';
    refs.help.hidden = true;
    refs.help.textContent = '';
    prompt.dataset.kind = payload.kind || '';
    prompt.dataset.state = payload.state || '';
    if (payload.kind === 'well') {
      refs.verb.textContent = P.well;
      refs.label.textContent = payload.label || '';
      refs.type.textContent = '';
    } else if (payload.kind === 'granary') {
      refs.verb.textContent = P.granary;
      refs.label.textContent = payload.label || '';
      refs.type.textContent = '';
    } else {
      refs.verb.textContent = P.slot;
      refs.label.textContent = P.slotLabel(Number(payload.index) || 1);
      refs.type.textContent = `· ${cropText(payload)}`;
      if (payload.parcelLabel) {
        refs.help.textContent = payload.parcelLabel;
        refs.help.hidden = false;
      }
    }
    prompt.hidden = false;
  }

  function hide() {
    prompt.hidden = true;
  }

  return { show, hide, cropText };
})();
