'use strict';
/*
 * web/js/api.js
 * Rôle : échanges avec la Chancellerie : requêtes JSON (avec l'en-tête qui prouve qu'elles viennent d'ici), flux
 *        d'évènements (état du serveur, lignes de console). Une session expirée renvoie à la porte.
 */

const API = (() => {
  const CSRF_HEADER = 'x-chancellerie';
  let onLoggedOut = () => {};
  let source = null;

  /** Résultat toujours de la forme { ok, error?, … } ; jamais d'exception. */
  async function request(method, route, body) {
    const options = { method, credentials: 'same-origin', headers: { [CSRF_HEADER]: '1' } };
    if (body !== undefined) {
      options.headers['content-type'] = 'application/json';
      options.body = JSON.stringify(body);
    }
    let result;
    try {
      const response = await fetch(route, options);
      result = await response.json();
    } catch (error) {
      return { ok: false, error: 'network' };
    }
    if (!result || typeof result !== 'object') return { ok: false, error: 'network' };
    if (result.error === 'not_logged_in' && route !== '/api/state') onLoggedOut();
    return result;
  }

  /**
   * Ouvre le flux d'évènements ; `handlers` : { state, history, line, report, players, camera, metrics, backup, job,
   * update, error }.
   * Le navigateur se reconnecte seul après une coupure.
   */
  function connect(handlers) {
    disconnect();
    source = new EventSource('/api/events');
    for (const name of ['state', 'history', 'line', 'report', 'players', 'camera', 'metrics', 'backup', 'job', 'update']) {
      source.addEventListener(name, (event) => {
        let data;
        try {
          data = JSON.parse(event.data);
        } catch (error) {
          return;
        }
        if (handlers[name]) handlers[name](data);
      });
    }
    source.addEventListener('error', () => {
      if (handlers.error) handlers.error();
    });
  }

  function disconnect() {
    if (source) source.close();
    source = null;
  }

  return {
    get: (route) => request('GET', route),
    post: (route, body = {}) => request('POST', route, body),
    connect,
    disconnect,
    onLoggedOut(callback) {
      onLoggedOut = callback;
    },
  };
})();
