'use strict';
/*
 * web/js/layout.js
 * Rôle : place et taille de la fenêtre, en parts de l'écran (gardées par le jeu sur le PC du joueur) : déplacée en la
 *        saisissant par son bandeau, agrandie par son coin, toujours tenue dans l'écran (aussi quand la résolution
 *        change). La nouvelle place part au jeu à la fin du geste, une seule fois.
 */

const Layout = (() => {
  const node = document.getElementById('chat');
  const head = document.getElementById('chat-head');
  const grip = document.getElementById('chat-grip');
  const corner = document.getElementById('chat-resize');
  const PRECISION = 10000;

  let current = null;
  let gesture = null;

  function clamp(value, low, high) {
    return Math.min(Math.max(value, low), Math.max(low, high));
  }

  function minSize() {
    const min = UI.config().minSize || { w: 300, h: 180 };
    return { w: Math.min(min.w, window.innerWidth), h: Math.min(min.h, window.innerHeight) };
  }

  /** Pose la fenêtre (pixels), tenue dans l'écran. */
  function place(box) {
    const min = minSize();
    const w = clamp(box.w, min.w, window.innerWidth);
    const h = clamp(box.h, min.h, window.innerHeight);
    const x = clamp(box.x, 0, window.innerWidth - w);
    const y = clamp(box.y, 0, window.innerHeight - h);
    Object.assign(node.style, { left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px` });
  }

  function apply() {
    if (!current) return;
    const width = window.innerWidth;
    const height = window.innerHeight;
    place({ x: current.x * width, y: current.y * height, w: current.w * width, h: current.h * height });
  }

  /** Place reçue du jeu : { x, y, w, h } en parts de l'écran. */
  function set(layout) {
    current = { x: layout.x, y: layout.y, w: layout.w, h: layout.h };
    apply();
  }

  function share(value, total) {
    return Math.round((value / total) * PRECISION) / PRECISION;
  }

  function save() {
    const rect = node.getBoundingClientRect();
    current = {
      x: share(rect.left, window.innerWidth), y: share(rect.top, window.innerHeight),
      w: share(rect.width, window.innerWidth), h: share(rect.height, window.innerHeight),
    };
    Bridge.post('layout', current);
  }

  function start(event, mode) {
    if (event.button !== 0 || !node.classList.contains('is-open')) return;
    if (mode === 'move' && event.target.closest('button')) return;
    event.preventDefault();
    gesture = { mode, pointer: event.pointerId, x: event.clientX, y: event.clientY, rect: node.getBoundingClientRect() };
    event.currentTarget.setPointerCapture(event.pointerId);
    node.classList.add(mode === 'move' ? 'is-moving' : 'is-sizing');
  }

  function move(event) {
    if (!gesture || event.pointerId !== gesture.pointer) return;
    const dx = event.clientX - gesture.x;
    const dy = event.clientY - gesture.y;
    const rect = gesture.rect;
    if (gesture.mode === 'move') {
      place({ x: rect.left + dx, y: rect.top + dy, w: rect.width, h: rect.height });
    } else {
      place({
        x: rect.left, y: rect.top,
        w: Math.min(rect.width + dx, window.innerWidth - rect.left), h: Math.min(rect.height + dy, window.innerHeight - rect.top),
      });
    }
  }

  function end(event) {
    if (!gesture || event.pointerId !== gesture.pointer) return;
    gesture = null;
    node.classList.remove('is-moving', 'is-sizing');
    save();
  }

  function setup() {
    const texts = UI.t();
    grip.title = texts.moveHint;
    corner.title = texts.resizeHint;
    if (!current) set(UI.config().defaultLayout || { x: 0.015, y: 0.22, w: 0.3, h: 0.34 });
  }

  head.addEventListener('pointerdown', (event) => start(event, 'move'));
  corner.addEventListener('pointerdown', (event) => start(event, 'size'));
  for (const target of [head, corner]) {
    target.addEventListener('pointermove', move);
    target.addEventListener('pointerup', end);
    target.addEventListener('pointercancel', end);
  }
  window.addEventListener('resize', apply);

  return { setup, set };
})();
