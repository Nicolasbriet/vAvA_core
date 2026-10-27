'use strict';
/*
 * web/js/view-tools.js
 * Rôle : onglet Outils : vol libre, invisibilité, invulnérabilité (leviers), repère de la carte, copie de sa
 *        position, outils des autres modules, fin d'une observation. Chaque outil est accordé par le serveur et
 *        inscrit au journal.
 */

const ToolsView = (() => {
  const T = STRINGS.tools;
  const TOGGLES = ['noclip', 'invisible', 'godmode'];
  const list = (value) => (Array.isArray(value) ? value : Object.values(value || {}));

  /** Copie dans le presse-papiers (l'API moderne n'est pas toujours permise dans le jeu). */
  function copy(text) {
    const area = UI.el('textarea', 'offscreen');
    area.value = text;
    document.body.append(area);
    area.select();
    document.execCommand('copy');
    area.remove();
  }

  function lever(ctx, name) {
    const active = Boolean(ctx.tools[name]);
    const node = UI.el('button', `lever${active ? ' is-on' : ''}`, null, [
      UI.el('span', 'lever-track', null, [UI.el('span', 'lever-knob')]),
      UI.el('span', 'lever-state', active ? T.on : T.off),
    ]);
    node.type = 'button';
    node.setAttribute('role', 'switch');
    node.setAttribute('aria-checked', String(active));
    node.addEventListener('click', async () => {
      const result = await Bridge.request('tool', name, !active);
      if (!UI.report(result)) return;
      ctx.tools = result.result;
      show(ctx);
    });
    return node;
  }

  function tool(label, hint, control) {
    return UI.el('div', 'tool', null, [
      UI.el('div', 'tool-text', null, [UI.el('span', 'entry-name', label), UI.el('span', 'entry-sub', hint)]),
      control,
    ]);
  }

  async function copyPosition(ctx) {
    const result = await Bridge.request('player', ctx.session.self);
    if (!UI.report(result) || !result.result.position) return;
    const p = result.result.position;
    const text = `${p.x}, ${p.y}, ${p.z}`;
    copy(text);
    UI.slip(STRINGS.copied(text));
  }

  function show(ctx) {
    const hint = (name) => (typeof T[name].hint === 'function' ? T[name].hint(ctx.session.noclipKey || 'F2') : T[name].hint);
    const rows = TOGGLES.map((name) => tool(T[name].label, hint(name), lever(ctx, name)));
    rows.push(tool(T.waypoint.label, T.waypoint.hint, UI.button(T.waypoint.label, async () => {
      UI.report(await Bridge.request('tool', 'waypoint', true), STRINGS.done);
    })));
    rows.push(tool(T.coords.label, T.coords.hint, UI.button(T.coords.label, () => copyPosition(ctx))));
    // outils ajoutés par les autres modules (zones de voix…) : les ouvrir ferme le Registre
    const moduleTools = list(ctx.session.moduleTools);
    if (moduleTools.length) {
      rows.push(UI.el('h3', 'group-title tools-group', T.modules));
      for (const entry of moduleTools) {
        rows.push(tool(entry.label, entry.hint, UI.button(T.openTool, async () => {
          UI.report(await Bridge.request('moduleTool', entry.key));
        })));
      }
    }
    if (ctx.tools.spectating) {
      rows.push(tool(T.spectating(ctx.tools.spectating), '', UI.button(T.stop, async () => {
        await Bridge.post('stopSpectate');
        ctx.tools.spectating = null;
        show(ctx);
      }, 'seal')));
    }
    ctx.single.replaceChildren(UI.heading(T.heading), UI.el('div', 'tools', null, rows));
  }

  return { id: 'tools', permission: 'tools', single: true, show };
})();
