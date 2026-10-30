/*
 * vava_loading/web/js/progress.js
 * Rôle : logique pure de la progression : lecture et contrôle d'un message reçu (liste blanche, bornes), étape atteinte
 *        et pourcentage. Messages du jeu (startInitFunction*, initFunction*, performMapLoadFunction, *DataFileEntries,
 *        loadProgress, onLogLine) et du client Lua de vava_loading (resources, waiting, handoff).
 *        Règles (spec T-020 § 6.2) : l'étape ne recule jamais ; le pourcentage ne recule jamais ; aucune progression
 *        simulée (si rien n'arrive, rien ne bouge) ; 100 au passage à la sélection. Aucune chaîne venue d'un message
 *        n'est gardée : seuls des noms de la liste blanche, des types de l'énumération et des nombres bornés.
 * Dépendances : aucune
 */
(function (root) {
  'use strict';

  var VavaLoading = root.VavaLoading = root.VavaLoading || {};

  var MAX_RAW = 2048;     // caractères d'un message reçu en chaîne JSON
  var MAX_COUNT = 100000; // count et idx
  var LAST_STAGE = 5;
  var HANDOFF = { min: 300, max: 5000, fallback: 1800 };

  // Types d'initialisation connus et l'étape (0 à 5) dont ils sont le plancher ; INIT_CORE (démarrage à froid du jeu)
  // est accepté sans étape.
  var INIT_STAGE = { INIT_CORE: 0, INIT_BEFORE_MAP_LOADED: 1, INIT_AFTER_MAP_LOADED: 3, INIT_SESSION: 4 };

  // Liste blanche : nom du message → champs attendus (lus et bornés par read()).
  var MESSAGES = {
    startInitFunction: ['type'],
    startInitFunctionOrder: ['type', 'count'],
    initFunctionInvoking: ['type', 'idx'],
    initFunctionInvoked: ['type', 'idx'],
    endInitFunction: ['type'],
    performMapLoadFunction: ['idx'],
    startDataFileEntries: ['count'],
    onDataFileEntry: [],
    endDataFileEntries: [],
    loadProgress: ['loadFraction'],
    onLogLine: [],
    'vava_loading:resources': [],
    'vava_loading:waiting': [],
    'vava_loading:handoff': [],
  };

  var has = function (obj, key) { return Object.prototype.hasOwnProperty.call(obj, key); };
  var finite = function (v) { return typeof v === 'number' && isFinite(v); };

  /**
   * Message reçu (event.data : objet, ou chaîne JSON de 2 048 caractères au plus) → message contrôlé, ou null.
   * Message contrôlé : { eventName, type?, count?, idx?, loadFraction?, ms? } (entiers bornés, fraction 0..1) ; lire
   * un message déjà contrôlé le rend à l'identique.
   * @param {*} data
   * @return {Object|null}
   */
  function read(data) {
    if (typeof data === 'string') {
      if (data.length > MAX_RAW) return null;
      try { data = JSON.parse(data); } catch (e) { return null; }
    }
    if (!data || typeof data !== 'object' || Array.isArray(data)) return null;
    var name = data.eventName;
    if (typeof name !== 'string' || !has(MESSAGES, name)) return null;
    var msg = { eventName: name };
    var fields = MESSAGES[name];
    for (var i = 0; i < fields.length; i++) {
      var field = fields[i], value = data[field];
      if (field === 'type') {
        if (typeof value !== 'string' || !has(INIT_STAGE, value)) return null;
        msg.type = value;
      } else if (field === 'count' || field === 'idx') {
        if (!finite(value) || value < 0 || value > MAX_COUNT) return null;
        msg[field] = Math.floor(value);
      } else if (field === 'loadFraction') {
        if (!finite(value) || value < 0 || value > 1) return null;
        msg.loadFraction = value;
      }
    }
    if (name === 'vava_loading:handoff') {
      var ms = data.ms;
      msg.ms = finite(ms) ? Math.min(HANDOFF.max, Math.max(HANDOFF.min, Math.floor(ms))) : HANDOFF.fallback;
    }
    return msg;
  }

  /** État de départ : feu 1 allumé, rien de reçu. */
  function initial() {
    return { stage: 0, orders: {}, files: { done: 0, total: 0 }, fraction: null, pct: 0, done: false };
  }

  function copy(state) {
    var orders = {};
    for (var t in state.orders) if (has(state.orders, t)) {
      var o = state.orders[t];
      orders[t] = { idx: o.idx, count: o.count, ended: o.ended };
    }
    return { stage: state.stage, orders: orders, files: { done: state.files.done, total: state.files.total },
      fraction: state.fraction, pct: state.pct, done: state.done };
  }

  function raise(next, stage) { if (stage > next.stage) next.stage = Math.min(LAST_STAGE, stage); }

  function order(next, type) {
    if (!has(next.orders, type)) next.orders[type] = { idx: 0, count: 0, ended: false };
    return next.orders[type];
  }

  /** Avancement (0 à 1) dans l'étape en cours ; 0 si inconnu. */
  function within(state) {
    var type = null;
    if (state.stage === 1) type = 'INIT_BEFORE_MAP_LOADED';
    else if (state.stage === 3) type = 'INIT_AFTER_MAP_LOADED';
    else if (state.stage === 4) type = 'INIT_SESSION';
    else if (state.stage === 2) return state.files.total > 0 ? Math.min(1, state.files.done / state.files.total) : 0;
    if (!type || !has(state.orders, type)) return 0;
    var o = state.orders[type];
    if (o.ended) return 1;
    return o.count > 0 ? Math.min(1, o.idx / o.count) : 0;
  }

  /**
   * Pourcentage entier 0..100 : plancher de l'étape, avancement dans l'étape, loadProgress borné à l'étape ; jamais
   * moins que state.pct ; 100 au passage.
   * @param {Object} state
   * @param {number[]} floors  seuils des six feux (config.stages)
   * @return {number}
   */
  function percent(state, floors) {
    if (state.done) return 100;
    var k = state.stage;
    var lo = floors[k], hi = k < LAST_STAGE ? floors[k + 1] - 1 : 99;
    if (hi < lo) hi = lo;
    var a = lo + Math.floor(within(state) * (hi - lo));
    var b = state.fraction === null ? lo : Math.min(hi, Math.max(lo, Math.floor(state.fraction * 97)));
    return Math.min(100, Math.max(state.pct, a, b));
  }

  /**
   * Nouvel état après un message (brut ou déjà lu : il passe par read()) ; l'ancien n'est pas modifié. Message
   * invalide ou sans effet : le même état. Avec `floors`, le pourcentage est recalculé (percent).
   * @param {Object} state
   * @param {Object|null} msg
   * @param {number[]} [floors]
   * @return {Object}
   */
  function reduce(state, msg, floors) {
    msg = read(msg);
    if (!msg || state.done) return state;
    var next = copy(state), o;
    switch (msg.eventName) {
      case 'startInitFunction':
        raise(next, INIT_STAGE[msg.type]);
        break;
      case 'startInitFunctionOrder':
        raise(next, INIT_STAGE[msg.type]);
        o = order(next, msg.type);
        o.count = msg.count; o.idx = 0;
        break;
      case 'initFunctionInvoking':
      case 'initFunctionInvoked':
        raise(next, INIT_STAGE[msg.type]);
        o = order(next, msg.type);
        var reached = msg.eventName === 'initFunctionInvoked' ? msg.idx + 1 : msg.idx;
        if (o.count > 0) reached = Math.min(reached, o.count);
        if (reached > o.idx) o.idx = reached;
        break;
      case 'endInitFunction':
        raise(next, msg.type === 'INIT_SESSION' ? LAST_STAGE : INIT_STAGE[msg.type]);
        order(next, msg.type).ended = true;
        break;
      case 'performMapLoadFunction':
        raise(next, 1);
        break;
      case 'startDataFileEntries':
        raise(next, 2);
        next.files.total = msg.count;
        next.files.done = Math.min(next.files.done, msg.count);
        break;
      case 'onDataFileEntry':
        raise(next, 2);
        next.files.done = Math.min(next.files.total > 0 ? next.files.total : MAX_COUNT, next.files.done + 1);
        break;
      case 'endDataFileEntries':
        raise(next, 3);
        next.files.done = next.files.total;
        break;
      case 'loadProgress':
        next.fraction = msg.loadFraction;
        break;
      case 'vava_loading:resources':
        raise(next, 3);
        break;
      case 'vava_loading:waiting':
        raise(next, LAST_STAGE);
        break;
      case 'vava_loading:handoff':
        next.stage = LAST_STAGE; next.done = true;
        break;
      default: // onLogLine : noté au journal par la page, sans effet sur la progression
        return state;
    }
    if (floors) next.pct = percent(next, floors);
    return next;
  }

  VavaLoading.progress = {
    read: read, initial: initial, reduce: reduce, percent: percent, within: within,
    STAGES: LAST_STAGE + 1, HANDOFF: HANDOFF,
  };

  if (typeof module === 'object' && module.exports) module.exports = VavaLoading.progress;
})(typeof window !== 'undefined' ? window : globalThis);
