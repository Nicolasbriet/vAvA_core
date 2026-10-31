'use strict';
/*
 * web/js/dock.js
 * Rôle : mode « panneau » (1.6.0) : le livre s'ouvre dans un rectangle de l'écran (vw, vh) donné par la ressource hôte
 *        (la bannière de vava_pause), sans voile, la bannière restant visible à côté. Le rectangle est relu ici avec
 *        les mêmes règles que shared/dock.lua : quatre nombres finis, rien d'autre ; 0 ≤ left, top ; 10 ≤ width,
 *        height ; left + width ≤ 100 ; top + height ≤ 100. Invalide : le livre s'ouvre en plein écran comme avant.
 * Dépendances : aucune (window.CodexDock dans la page, module.exports sous node)
 */

const CodexDock = (() => {
  const KEYS = ['left', 'top', 'width', 'height'];
  const finite = (value) => typeof value === 'number' && Number.isFinite(value);

  /** Rectangle valide `{ left, top, width, height }`, ou null. */
  function rect(raw) {
    if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) return null;
    if (Object.keys(raw).some((key) => !KEYS.includes(key))) return null;
    if (!KEYS.every((key) => finite(raw[key]))) return null;
    const { left, top, width, height } = raw;
    if (left < 0 || top < 0 || width < 10 || height < 10) return null;
    if (left + width > 100 || top + height > 100) return null;
    return { left, top, width, height };
  }

  /** Pose ou retire le mode panneau sur `.app` (classe is-docked et --dock-*). */
  function apply(app, dock) {
    app.classList.toggle('is-docked', Boolean(dock));
    for (const key of KEYS) {
      if (dock) app.style.setProperty(`--dock-${key}`, String(dock[key]));
      else app.style.removeProperty(`--dock-${key}`);
    }
  }

  return { rect, apply };
})();

if (typeof module === 'object' && module && module.exports) module.exports = CodexDock;
