'use strict';
/*
 * web/js/reader.js
 * Rôle : pages de lecture (1.5.0), fonctions pures : index et blocs revalidés, cible d'openAt, pages voisines, liens,
 *        cache par empreinte, demandes de page, rendu sans HTML (document et minuteries en paramètre : dev/essais.js).
 * Dépendances : aucune (window.CodexReader dans la page, module.exports sous node)
 */

(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module && module.exports) module.exports = api;
  root.CodexReader = api;
})(typeof window !== 'undefined' ? window : globalThis, () => {
  // bornes de shared/constants.lua (READING) : la page revalide tout ce qu'elle reçoit
  const MAX_BLOCKS = 40, MAX_ITEMS = 12, MAX_TEXT = 1200, MAX_KBD = 16, MAX_LINK_LABEL = 48;
  const MAX_TITLE = 48, MAX_SUMMARY = 120, MAX_LABEL = 32, MAX_PAGES = 40, MAX_CHAPTERS = 8;
  const ID = /^[a-z][a-z0-9_]{0,31}$/;
  const KEY_NAME = /^[A-Za-z0-9_.-]{1,64}$/;
  const COMMAND = /^[A-Za-z0-9_.:-]{1,64}$/;
  const ACTION = /^[A-Za-z0-9_-]{1,32}$/;
  const HASH = /^[0-9a-f]{1,32}$/;
  const KBD_FORBIDDEN = /[[\]|*:]/;
  const LABEL_FORBIDDEN = /[[\]|*]/;

  // msgpack transmet une liste vide comme un objet vide : toujours une vraie liste
  const list = (value) => (Array.isArray(value) ? value : (value && typeof value === 'object' ? Object.values(value) : []));
  const isString = (value) => typeof value === 'string';

  function bytes(text) {
    let n = 0;
    for (const ch of text) {
      const code = ch.codePointAt(0);
      n += code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
    }
    return n;
  }

  const cut = (text, max) => (text.length <= max ? text : Array.from(text).slice(0, max).join(''));

  /** `content.reading` → { chapters, pages } sûrs dans l'ordre reçu ; null si absent (pages fermées). */
  function normalizeIndex(raw) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
    const chapters = [];
    const chapterIds = new Set();
    for (const c of list(raw.chapters)) {
      if (chapters.length >= MAX_CHAPTERS) break;
      if (!c || !isString(c.id) || !ID.test(c.id) || chapterIds.has(c.id) || !isString(c.label) || !c.label) continue;
      chapterIds.add(c.id);
      chapters.push({ id: c.id, label: cut(c.label, MAX_LABEL) });
    }
    const pages = [];
    const pageIds = new Set();
    for (const p of list(raw.pages)) {
      if (pages.length >= MAX_PAGES) break;
      if (!p || !isString(p.id) || !ID.test(p.id) || pageIds.has(p.id) || chapterIds.has(p.id)) continue;
      if (!chapterIds.has(p.chapter) || !isString(p.title) || !p.title || !isString(p.hash) || !HASH.test(p.hash)) continue;
      pageIds.add(p.id);
      pages.push({ id: p.id, chapter: p.chapter, title: cut(p.title, MAX_TITLE), summary: isString(p.summary) ? cut(p.summary, MAX_SUMMARY) : '', hash: p.hash, staff: p.staff === true });
    }
    return { chapters: chapters.filter((c) => pages.some((p) => p.chapter === c.id)), pages };
  }

  /** Segment sûr ou null : chaîne, ['kbd', s], ['key', nom], ['cmd', nom, action], ['page', id, libellé], ['em', s]. */
  function segment(raw) {
    if (isString(raw)) return raw ? cut(raw, MAX_TEXT) : null;
    const [kind, a, rawB] = list(raw);
    const b = rawB === undefined || rawB === null ? '' : rawB;
    if (kind === 'kbd') return isString(a) && a && bytes(a) <= MAX_KBD && !KBD_FORBIDDEN.test(a) ? ['kbd', a] : null;
    if (kind === 'key') return isString(a) && KEY_NAME.test(a) ? ['key', a] : null;
    if (kind === 'cmd') return isString(a) && COMMAND.test(a) && isString(b) && (b === '' || ACTION.test(b)) ? ['cmd', a, b] : null;
    if (kind === 'page') return isString(a) && ID.test(a) && isString(b) && bytes(b) <= MAX_LINK_LABEL && !LABEL_FORBIDDEN.test(b) ? ['page', a, b] : null;
    if (kind === 'em') return isString(a) && a ? ['em', cut(a, MAX_TEXT)] : null;
    return null;
  }

  // segments sûrs ; les chaînes devenues voisines sont jointes
  function segments(raw) {
    const out = [];
    for (const item of raw) {
      const seg = segment(item);
      if (seg === null) continue;
      if (isString(seg) && isString(out[out.length - 1])) out[out.length - 1] = cut(out[out.length - 1] + seg, MAX_TEXT);
      else out.push(seg);
    }
    return out;
  }

  /** Blocs reçus → blocs sûrs ('h', 'p', 'note', 'ul', 'ol') ; le reste est retiré ; 40 blocs, 12 éléments au plus. */
  function normalizeBody(raw) {
    const out = [];
    for (const item of list(raw)) {
      if (out.length >= MAX_BLOCKS) break;
      const block = list(item);
      const kind = block[0];
      if (kind === 'h') {
        if (isString(block[1]) && block[1]) out.push(['h', cut(block[1], MAX_TEXT)]);
      } else if (kind === 'p' || kind === 'note') {
        const segs = segments(block.slice(1));
        if (segs.length > 0) out.push([kind, ...segs]);
      } else if (kind === 'ul' || kind === 'ol') {
        const items = [];
        for (const element of block.slice(1)) {
          if (items.length >= MAX_ITEMS) break;
          const segs = element && typeof element === 'object' ? segments(list(element)) : [];
          if (segs.length > 0) items.push(segs);
        }
        if (items.length > 0) out.push([kind, ...items]);
      }
    }
    return out;
  }

  /** Réponse du rappel `page` ({ ok, page = { id, hash, body } }) → { hash, body } sûrs, ou null. */
  function readAnswer(result, id) {
    const page = result && result.ok === true && result.page && typeof result.page === 'object' ? result.page : null;
    if (!page || page.id !== id || !isString(page.hash) || !HASH.test(page.hash)) return null;
    return { hash: page.hash, body: normalizeBody(page.body) };
  }

  /** Cible d'un openAt : page, puis chapitre de lecture (sa première page), puis chapitre de commandes ; sinon null. */
  function focusTarget(id, reading, moduleChapters) {
    if (!isString(id) || !id) return null;
    const pages = reading ? reading.pages : [];
    if (pages.some((p) => p.id === id)) return { tab: 'reading', chapter: '', page: id };
    if (reading && reading.chapters.some((c) => c.id === id)) {
      const first = pages.find((p) => p.chapter === id);
      return { tab: 'reading', chapter: id, page: first ? first.id : '' };
    }
    if (list(moduleChapters).some((c) => c && c.id === id)) return { tab: 'commands', chapter: id };
    return null;
  }

  function neighbours(pages, id) {
    const i = pages.findIndex((p) => p.id === id);
    if (i === -1) return { previous: null, next: null };
    return { previous: i > 0 ? pages[i - 1].id : null, next: i < pages.length - 1 ? pages[i + 1].id : null };
  }

  // texte d'un lien : libellé, sinon titre de la cible ; null si la cible manque (texte brut : plainText)
  const linkText = (run, pagesById) => (pagesById.has(run[1]) ? run[2] || pagesById.get(run[1]).title : null);
  const plainText = (run) => run[2] || run[1].replace(/_/g, ' ');

  function cached(cache, id, hash) {
    const entry = cache.get(id);
    return entry && entry.hash === hash ? entry.body : null;
  }

  function store(cache, id, hash, body) {
    if (!ID.test(id) || !isString(hash) || !HASH.test(hash)) return false;
    cache.set(id, { hash, body });
    return true;
  }

  // oublie les pages absentes du nouvel index ou d'empreinte changée ; rend le nombre oublié
  function prune(cache, pagesById) {
    let removed = 0;
    for (const [id, entry] of cache) {
      const page = pagesById.get(id);
      if (!page || page.hash !== entry.hash) {
        cache.delete(id);
        removed += 1;
      }
    }
    return removed;
  }

  /** Demandes : une à la fois par page ; `delayed` attend `delay` ms ; rate_limited relancé une fois ; { skipped } si plus voulue. */
  function createLoader({ post, wait, wanted, delay = 150, retry = 1000 }) {
    const pending = new Map();
    function once(id) {
      if (!pending.has(id)) pending.set(id, Promise.resolve().then(() => post(id)).finally(() => pending.delete(id)));
      return pending.get(id);
    }
    async function load(id, delayed) {
      if (delayed && !pending.has(id)) {
        await wait(delay);
        if (!wanted(id)) return { skipped: true };
      }
      let result = await once(id);
      if (result && result.ok === false && result.error === 'rate_limited') {
        await wait(retry);
        if (!wanted(id)) return { skipped: true };
        result = await once(id);
      }
      return result;
    }
    return { load, pending: () => pending.size };
  }

  /** Éléments d'une page : textContent et createTextNode seulement ; data- ne reçoit que des valeurs revalidées. */
  function renderBlocks(blocks, ctx, doc) {
    const el = (tag, className, text) => {
      const node = doc.createElement(tag);
      if (className) node.className = className;
      if (text !== undefined) node.textContent = text;
      return node;
    };
    const button = (className, text, data) => {
      const node = el('button', className, text);
      node.type = 'button';
      Object.assign(node.dataset, data);
      return node;
    };
    function fill(parent, segs) {
      for (const seg of segs) {
        if (isString(seg)) {
          parent.appendChild(doc.createTextNode(seg));
          continue;
        }
        const [kind, a, b] = seg;
        let node;
        if (kind === 'kbd') node = el('kbd', 'reader-kbd', a);
        else if (kind === 'key') {
          const label = ctx.keyLabel(a);
          node = el('kbd', label ? 'reader-kbd' : 'reader-kbd is-missing', label || ctx.strings.noKey);
          if (!label) node.title = ctx.strings.noKeyHint;
        } else if (kind === 'cmd') {
          const text = b ? `/${a} ${b}` : `/${a}`;
          node = ctx.commandVisible(a, b) ? button('reader-cmd', text, { command: a, action: b }) : el('code', 'reader-cmd is-plain', text);
        } else if (kind === 'page') {
          const text = linkText(seg, ctx.pagesById);
          node = text === null ? doc.createTextNode(plainText(seg)) : button('reader-link', text, { page: a });
        } else if (kind === 'em') node = el('em', null, a);
        if (node) parent.appendChild(node);
      }
      return parent;
    }
    const nodes = [];
    for (const block of blocks) {
      const kind = block[0];
      if (kind === 'h') nodes.push(el('h3', 'reader-h', block[1]));
      else if (kind === 'p' || kind === 'note') nodes.push(fill(el('p', kind === 'p' ? 'reader-p' : 'reader-note'), block.slice(1)));
      else if (kind === 'ul' || kind === 'ol') {
        const listNode = el(kind, 'reader-list');
        for (const item of block.slice(1)) listNode.appendChild(fill(el('li', 'reader-item'), item));
        nodes.push(listNode);
      }
    }
    return nodes;
  }

  return { list, bytes, normalizeIndex, normalizeBody, readAnswer, focusTarget, neighbours, linkText, plainText, cached, store, prune, createLoader, renderBlocks };
});
