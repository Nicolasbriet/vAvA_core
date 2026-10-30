'use strict';
/*
 * web/js/view-prompt.js
 * Rôle : l'invite près d'un nœud (« [E] Couper — Chêne · 3 charges » et une ligne d'aide : épuisé, terre épuisée,
 *        outil à tenir) et l'état « ligne lancée » de la pêche. Rien n'est animé en continu : l'invite ne change que
 *        quand le jeu l'envoie.
 */

const PromptView = (() => {
  const prompt = document.getElementById('prompt');
  const cast = document.getElementById('cast');
  const refs = {
    key: prompt.querySelector('.prompt-key'),
    verb: prompt.querySelector('.prompt-verb'),
    label: prompt.querySelector('.prompt-label'),
    charges: prompt.querySelector('.prompt-charges'),
    help: prompt.querySelector('.prompt-help'),
    castText: cast.querySelector('.cast-text'),
    castHint: cast.querySelector('.cast-hint'),
  };

  /** Invite pour un nœud : { key, anim, label, charges, exhausted, zoneDepleted, water, toolKind, toolOk }. */
  function show(payload) {
    const P = STRINGS.prompt;
    refs.key.textContent = payload.key || 'E';
    refs.verb.textContent = STRINGS.verbs[payload.anim] || STRINGS.verbDefault;
    refs.label.textContent = payload.label || '';
    refs.charges.textContent = `· ${P.charges(Number(payload.charges) || 0)}`;
    let help = '';
    if (payload.exhausted) help = P.exhausted;
    else if (payload.toolKind && payload.toolOk === false) help = P.needTool(P.toolKinds[payload.toolKind] || P.toolDefault);
    else if (payload.zoneDepleted) help = payload.water ? P.zoneDepletedWater : P.zoneDepleted;
    refs.help.textContent = help;
    refs.help.hidden = help === '';
    prompt.classList.toggle('is-blocked', Boolean(payload.exhausted) || (Boolean(payload.toolKind) && payload.toolOk === false));
    prompt.classList.toggle('is-warning', !payload.exhausted && Boolean(payload.zoneDepleted));
    prompt.hidden = false;
  }

  function hide() {
    prompt.hidden = true;
  }

  /** Ligne lancée : { label, key } ; { hidden: true } la retire. */
  function castShow(payload) {
    if (payload.hidden) {
      cast.hidden = true;
      return;
    }
    refs.castText.textContent = STRINGS.cast.text(payload.label || '');
    refs.castHint.textContent = `${STRINGS.cast.waiting} ${STRINGS.cast.hint(payload.key || 'E')}`;
    cast.hidden = false;
  }

  return { show, hide, castShow };
})();
