'use strict';
/*
 * web/js/game.js
 * Rôle : le royaume vu de la Chancellerie : demandes au Registre du Conseil (par le pont du serveur de jeu), droits
 *        du rang de ce compte (relus à l'ouverture et quand le serveur repart), rangs du Conseil. Les droits ne
 *        servent qu'à n'afficher que l'utile : le Registre revérifie tout.
 */

const GAME = (() => {
  let session = null;
  let permissions = new Set();

  /** Demande au Registre : { ok, result } ou { ok: false, error }. */
  function call(name, ...args) {
    return API.post('/api/game/request', { name, args });
  }

  /** Relit le rang et ses droits ; faux si le serveur de jeu ne répond pas. */
  async function load() {
    const result = await call('session');
    session = result.ok ? result.result : null;
    permissions = new Set(session ? UI.list(session.permissions) : []);
    return result;
  }

  return {
    call,
    load,
    /** Droits du rang connus, ou relus : { ok } ou { ok: false, error }. */
    ensure: () => (session ? Promise.resolve({ ok: true }) : load()),
    can: (permission) => permissions.has(permission),
    loaded: () => session !== null,
    session: () => session,
    banDurations: () => (session ? UI.list(session.banDurations) : []),
    pageSize: () => (session ? session.pageSize : 50),
    async ranks() {
      const result = await API.get('/api/game/ranks');
      return result.ok ? { ranks: UI.list(result.ranks), live: result.live } : { ranks: [], live: false };
    },
    forget() {
      session = null;
      permissions = new Set();
    },
  };
})();
