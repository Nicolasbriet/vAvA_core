'use strict';
/*
 * vava_atelier/web/boot.js — amorce de la page (T-157), livrée à tous : reçoit du Lua (client/loader.lua) la feuille et
 * les scripts du paquet du Conseil, les contrôle, les insère une fois, dans l'ordre, noms d'origine gardés (sourceURL),
 * et rend compte. N'exécute que ce que le Lua envoie. Messages : docs/plan/rapports/T-157-contrat.md (spec § 6.3, § 9.1).
 * Hors jeu : web/dev/index.html. Essais : web/dev/essais.js. Dépendances : aucune
 */

const Boot = (() => {
  // copies de VavaAtelier.CODEPACK (shared/constants.lua), tenues égales par les essais
  const LIMITS = Object.freeze({ MAX_PIECES: 48, MAX_BYTES: 524288, MAX_NAME: 96, MAX_DEPTH: 4 });
  const EXT = Object.freeze({ css: '.css', js: '.js' });
  const SEGMENT = /^[a-z][a-z0-9_-]*$/;
  const LEAF = /^[a-z][a-z0-9_-]*\.[a-z]+$/;
  const REFUSED = 'refus';
  const MARK = '__vavaBootMark';
  const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
  const no = (reason) => ({ ok: false, reason });

  /** Règle de codepack.validName : segments en minuscules, extension du genre. */
  function validName(name, kind) {
    if (typeof name !== 'string' || name.length < 1 || name.length > LIMITS.MAX_NAME) return false;
    if (kind !== 'css' && kind !== 'js') return false;
    const segments = name.split('/');
    const leaf = segments.pop();
    return segments.length <= LIMITS.MAX_DEPTH && LEAF.test(leaf) && leaf.slice(leaf.indexOf('.')) === EXT[kind]
      && segments.every((s) => SEGMENT.test(s));
  }

  const newState = () => ({ pieces: [], size: 0, refused: '', ended: false, result: null });

  /** `bootPiece` (pur, ne change rien) : `{ ok: true }` s'il est le fichier suivant attendu, sinon `{ ok: false, reason }`. */
  function accept(state, m) {
    if (!isObject(state) || !Array.isArray(state.pieces)) return no('bad_state');
    if (state.ended) return no('ended');
    if (!isObject(m)) return no('not_object');
    if (!Number.isInteger(m.index) || m.index !== state.pieces.length) return no('bad_index');
    if (m.kind !== 'css' && m.kind !== 'js') return no('bad_kind');
    if (!validName(m.name, m.kind)) return no('bad_name');
    if (typeof m.code !== 'string') return no('bad_code');
    if (state.pieces.length >= LIMITS.MAX_PIECES) return no('too_many');
    if (state.pieces.some((p) => p.name === m.name)) return no('duplicate');
    if (state.size + m.code.length > LIMITS.MAX_BYTES) return no('too_large');   // longueur JS ≤ octets UTF-8
    return { ok: true };
  }

  /** `bootEnd` (pur) : `{ insert: true }`, ou le compte rendu sans insertion ; `result` nul : fin déjà traitée. */
  function finish(state, m) {
    if (!isObject(state) || !Array.isArray(state.pieces)) return { insert: false, result: { ok: false, piece: REFUSED } };
    if (state.ended) return { insert: false, result: null };
    const count = isObject(m) ? m.count : undefined;
    if (state.refused || state.pieces.length === 0 || count !== state.pieces.length) {
      return { insert: false, result: { ok: false, piece: REFUSED } };
    }
    return { insert: true };
  }

  /**
   * Insertion dans l'ordre : `<style>` dans `<head>` (après vava_ui.css), `<script>` en ligne dans `<body>` (exécuté
   * aussitôt) suivi de sa marque. Un script en erreur n'atteint pas sa marque : arrêt, et on le nomme.
   */
  function insert(pieces, doc, win, log) {
    let marked = -1, failure = '';
    const onError = (e) => { if (!failure) failure = `${(e && e.message) || 'erreur'}${e && e.lineno > 0 ? ` (ligne ${e.lineno})` : ''}`; };
    win[MARK] = (index) => { marked = index; };
    win.addEventListener('error', onError);
    let result = { ok: true, count: pieces.length };
    try {
      for (const p of pieces) {
        const css = p.kind === 'css';
        const el = doc.createElement(css ? 'style' : 'script');
        el.textContent = css ? `${p.code}\n/*# sourceURL=vava_atelier/${p.name} */`
          : `${p.code}\n;window.${MARK}(${p.index});\n//# sourceURL=vava_atelier/${p.name}`;
        marked = -1;
        failure = '';
        (css ? doc.head : doc.body).appendChild(el);
        if (!css && marked !== p.index) {
          log(`[vava_atelier] ${p.name} : le script n'a pas abouti${failure ? ` : ${failure}` : ''} ; Atelier non chargé.`);
          result = { ok: false, piece: p.name };
          break;
        }
      }
    } finally {
      win.removeEventListener('error', onError);
      delete win[MARK];
    }
    return result;
  }

  /** Branche l'amorce : écoute les messages du Lua, dit « prête » ; `post(nom, données)` : rappel vers le Lua. */
  function attach(win, doc, post, log) {
    const state = newState();
    function onMessage(event) {
      const m = event && event.data;
      if (!isObject(m) || typeof m.action !== 'string') return;
      if (m.action === 'hello') {
        if (state.ended) post('booted', state.result);   // réponse perdue : le même compte rendu, sans réinsertion
        else post('pageReady', {});
      } else if (m.action === 'bootPiece') {
        if (state.ended) return;
        const p = m.payload;
        const verdict = accept(state, p);
        if (!verdict.ok) {
          if (!state.refused) log(`[vava_atelier] fichier de la page refusé (${verdict.reason}) : ${isObject(p) && typeof p.name === 'string' ? p.name.slice(0, LIMITS.MAX_NAME) : '?'}`);
          state.refused = state.refused || verdict.reason;
          return;
        }
        state.pieces.push({ index: p.index, kind: p.kind, name: p.name, code: p.code });
        state.size += p.code.length;
      } else if (m.action === 'bootEnd') {
        const decision = finish(state, m.payload);
        if (!decision.insert && decision.result === null) return;   // une seule fin
        if (!decision.insert) log(`[vava_atelier] page non chargée : ${state.refused || 'compte des fichiers faux'}`);
        const result = decision.insert ? insert(state.pieces, doc, win, log) : decision.result;
        Object.assign(state, { ended: true, result, pieces: [] });
        post('booted', result);
      }
    }
    win.addEventListener('message', onMessage);
    post('pageReady', {});
    return onMessage;
  }

  return Object.freeze({ LIMITS, REFUSED, validName, newState, accept, finish, insert, attach });
})();

if (typeof window === 'object' && typeof document === 'object') {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
  Boot.attach(window, document, (name, data) => {
    if (resource) {
      fetch(`https://${resource}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) })
        .catch(() => undefined);
    }
  }, (text) => console.error(text));
}
