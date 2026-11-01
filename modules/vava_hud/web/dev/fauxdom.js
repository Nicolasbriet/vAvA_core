/*
 * vava_hud/web/dev/fauxdom.js
 * Rôle : faux DOM et fausse horloge, juste assez pour charger js/hud.js sous node et rejouer ses messages (essais de la
 *        remontée d'une jauge, T-114) : éléments, classes, attributs, style en ligne, minuteries avancées à la main.
 *        Jamais livré (dossier dev/, hors des `files`).
 * Dépendances : aucune (node : vm, fs)
 */
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

class ClassList {
  constructor() { this.set = new Set(); }
  add(...names) { for (const n of names) this.set.add(n); }
  remove(...names) { for (const n of names) this.set.delete(n); }
  contains(name) { return this.set.has(name); }
  toggle(name, force) {
    const on = force === undefined ? !this.set.has(name) : Boolean(force);
    if (on) this.set.add(name); else this.set.delete(name);
    return on;
  }
}

class Element {
  constructor(tag) {
    this.tagName = tag;
    this.attributes = new Map();
    this.children = [];
    this.parent = null;
    this.classList = new ClassList();
    this.dataset = {};
    this.style = { setProperty(key, value) { this[key] = value; } };
    this.listeners = {};
    this.textContent = '';
    this.offsetWidth = 0;
  }
  set className(value) { this.classList = new ClassList(); this.classList.add(...String(value).split(' ').filter(Boolean)); }
  get className() { return [...this.classList.set].join(' '); }
  setAttribute(key, value) {
    this.attributes.set(key, String(value));
    if (key === 'class') this.className = value;
  }
  getAttribute(key) { return this.attributes.has(key) ? this.attributes.get(key) : null; }
  append(...nodes) {
    for (const node of nodes) {
      if (node.parent) node.remove();
      node.parent = this;
      this.children.push(node);
    }
  }
  insertBefore(node, ref) {
    if (node.parent) node.remove();
    node.parent = this;
    const at = ref ? this.children.indexOf(ref) : -1;
    if (at < 0) this.children.push(node); else this.children.splice(at, 0, node);
    return node;
  }
  replaceChildren(...nodes) {
    for (const child of this.children) { child.parent = null; child.detached = (child.detached || 0) + 1; }
    this.children = [];
    this.append(...nodes);
  }
  // `detached` compte les sorties du document : chacune couperait une transition en cours dans un vrai navigateur
  remove() {
    if (!this.parent) return;
    this.parent.children = this.parent.children.filter((child) => child !== this);
    this.parent = null;
    this.detached = (this.detached || 0) + 1;
  }
  addEventListener(type, fn) { (this.listeners[type] = this.listeners[type] || []).push(fn); }
  querySelector(selector) {
    const name = selector.replace(/^\./, '');
    for (const child of this.children) {
      if (child.classList.contains(name)) return child;
      const deep = child.querySelector(selector);
      if (deep) return deep;
    }
    return null;
  }
}

// charge les scripts de la page (chemins relatifs à web/) dans un contexte neuf ; rend { post, clock, timers, byId }
function load(web, scripts) {
  const byId = {};
  const make = (tag, id, className) => {
    const node = new Element(tag);
    if (className) node.className = className;
    if (id) byId[id] = node;
    return node;
  };
  const progress = make('div', 'progress', 'progress');
  const track = make('div', null, 'progress-track');
  track.append(make('div', null, 'progress-fill'));
  progress.append(make('div', null, 'progress-label'), track, make('div', null, 'progress-hint'));
  make('div', 'hud', 'hud');
  make('div', 'toasts', 'toasts');
  make('div', 'numbers', 'numbers');

  const clock = { now: 0 };
  const timers = new Map();
  let nextTimer = 0;
  const messageListeners = [];
  const sandbox = {
    console,
    document: {
      getElementById: (id) => byId[id] || null,
      createElement: (tag) => new Element(tag),
      createElementNS: (_, tag) => new Element(tag),
      documentElement: new Element('html'),
    },
    performance: { now: () => clock.now },
    setTimeout: (fn, ms) => { nextTimer += 1; timers.set(nextTimer, { fn, at: clock.now + Math.max(0, ms || 0) }); return nextTimer; },
    clearTimeout: (id) => { timers.delete(id); },
  };
  sandbox.window = { addEventListener: (type, fn) => { if (type === 'message') messageListeners.push(fn); } };
  vm.createContext(sandbox);
  for (const file of scripts) vm.runInContext(fs.readFileSync(path.join(web, file), 'utf8'), sandbox, { filename: file });

  return {
    byId,
    timers,
    clock,
    post(action, payload) { for (const fn of messageListeners) fn({ data: { action, payload } }); },
    // avance l'horloge jusqu'à `ms` après maintenant, minuteries dues lancées dans l'ordre
    advance(ms) {
      const until = clock.now + ms;
      for (;;) {
        let due = null;
        for (const [id, timer] of timers) if (timer.at <= until && (!due || timer.at < due[1].at)) due = [id, timer];
        if (!due) break;
        timers.delete(due[0]);
        clock.now = due[1].at;
        due[1].fn();
      }
      clock.now = until;
    },
  };
}

module.exports = { load };
