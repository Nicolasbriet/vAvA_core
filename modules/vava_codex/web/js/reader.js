'use strict';
/*
 * web/js/reader.js
 * Rôle : pages de lecture du Codex (1.5.0), fonctions PURES : index et blocs reçus du serveur ramenés à des formes
 *        sûres (normalizeIndex, normalizeBody), cible d'un openAt (focusTarget : page, chapitre de lecture, puis
 *        module), page précédente et suivante, texte d'un lien, pages gardées par empreinte (cached, store, prune),
 *        rendu des blocs en éléments (renderBlocks : createElement et textContent seulement, jamais de HTML).
 *        Aucune dépendance au DOM de la page : le document est passé en paramètre (essais par node :
 *        web/dev/essais.js).
 * Dépendances : aucune (window.CodexReader dans la page, module.exports sous node)
 */

(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module && module.exports) module.exports = api;
  root.CodexReader = api;
})(typeof window !== 'undefined' ? window : globalThis, () => {
  // Bornes du format (shared/constants.lua, READING) : la page ne fait confiance à rien de ce qu'elle reçoit.
  const MAX_BLOCKS = 40;
  const MAX_ITEMS = 12;
  const MAX_TEXT = 1200;       // caractères d'une chaîne (paragraphe, note, élément, segment)
  const MAX_KBD = 16;          // octets d'une touche littérale
  const MAX_LINK_LABEL = 48;   // octets du libellé d'un lien
  const MAX_TITLE = 48;
  const MAX_SUMMARY = 120;
  const MAX_LABEL = 32;
  const MAX_PAGES = 40;
  const MAX_CHAPTERS = 8;
  const ID = /^[a-z][a-z0-9_]{0,31}$/;                 // page ou chapitre de lecture
  const KEY_NAME = /^[A-Za-z0-9_.-]{1,64}$/;            // entrée du registre core:commands (touche)
  const COMMAND = /^[A-Za-z0-9_.:-]{1,64}$/;            // nom d'une commande (NAME_PATTERN du Codex)
  const ACTION = /^[A-Za-z0-9_-]{1,32}$/;               // sous-commande
  const HASH = /^[0-9a-f]{1,32}$/;                      // empreinte (16 chiffres hexadécimaux aujourd'hui)
  const KBD_FORBIDDEN = /[[\]|*:]/;
  const LABEL_FORBIDDEN = /[[\]|*]/;

  /** msgpack transmet une liste vide comme un objet vide : toujours une vraie liste. */
  const list = (value) => (Array.isArray(value) ? value : (value && typeof value === 'object' ? Object.values(value) : []));

  /** Octets UTF-8 d'une chaîne (les bornes du serveur sont en octets). */
  function bytes(text) {
    let n = 0;
    for (const ch of text) {
      const code = ch.codePointAt(0);
      n += code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
    }
    return n;
  }

  /** Chaîne coupée à `max` caractères (sans casser une lettre hors du plan de base). */
  function cut(text, max) {
    if (text.length <= max) return text;
    return Array.from(text).slice(0, max).join('');
  }

  const isString = (value) => typeof value === 'string';

  // Index ---------------------------------------------------------------------------------------------------------

  /** Index de lecture reçu dans le contenu (`content.reading`) → `{ chapters, pages }` sûrs, dans l'ordre du serveur ;
   *  `null` si absent (pages de lecture fermées). Une page dont le chapitre manque, ou en double, est retirée. */
  function normalizeIndex(raw) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
    const chapters = [];
    const chapterIds = new Set();
    for (const chapter of list(raw.chapters)) {
      if (chapters.length >= MAX_CHAPTERS) break;
      if (!chapter || !isString(chapter.id) || !ID.test(chapter.id) || chapterIds.has(chapter.id)) continue;
      if (!isString(chapter.label) || chapter.label.length === 0) continue;
      chapterIds.add(chapter.id);
      chapters.push({ id: chapter.id, label: cut(chapter.label, MAX_LABEL) });
    }
    const pages = [];
    const pageIds = new Set();
    for (const page of list(raw.pages)) {
      if (pages.length >= MAX_PAGES) break;
      if (!page || !isString(page.id) || !ID.test(page.id) || pageIds.has(page.id) || chapterIds.has(page.id)) continue;
      if (!isString(page.chapter) || !chapterIds.has(page.chapter)) continue;
      if (!isString(page.title) || page.title.length === 0 || !isString(page.hash) || !HASH.test(page.hash)) continue;
      pageIds.add(page.id);
      pages.push({
        id: page.id, chapter: page.chapter, title: cut(page.title, MAX_TITLE),
        summary: isString(page.summary) ? cut(page.summary, MAX_SUMMARY) : '', hash: page.hash, staff: page.staff === true,
      });
    }
    // un chapitre sans page n'est pas montré (le serveur l'omet déjà)
    return { chapters: chapters.filter((chapter) => pages.some((page) => page.chapter === chapter.id)), pages };
  }

  // Blocs -----------------------------------------------------------------------------------------------------------

  /** Un segment sûr, ou null : chaîne, ['kbd', s], ['key', nom], ['cmd', nom, action], ['page', id, libellé], ['em', s]. */
  function segment(raw) {
    if (isString(raw)) return raw.length > 0 ? cut(raw, MAX_TEXT) : null;
    const run = list(raw);
    const kind = run[0];
    const a = run[1];
    const b = run[2] === undefined || run[2] === null ? '' : run[2];
    if (kind === 'kbd') return isString(a) && a.length > 0 && bytes(a) <= MAX_KBD && !KBD_FORBIDDEN.test(a) ? ['kbd', a] : null;
    if (kind === 'key') return isString(a) && KEY_NAME.test(a) ? ['key', a] : null;
    if (kind === 'cmd') return isString(a) && COMMAND.test(a) && isString(b) && (b === '' || ACTION.test(b)) ? ['cmd', a, b] : null;
    if (kind === 'page') {
      if (!isString(a) || !ID.test(a) || !isString(b) || bytes(b) > MAX_LINK_LABEL || LABEL_FORBIDDEN.test(b)) return null;
      return ['page', a, b];
    }
    if (kind === 'em') return isString(a) && a.length > 0 ? ['em', cut(a, MAX_TEXT)] : null;
    return null;
  }

  /** Segments sûrs d'un texte ; les chaînes voisines (après retrait d'un segment refusé) sont jointes. */
  function segments(raw) {
    const out = [];
    for (const item of raw) {
      const seg = segment(item);
      if (seg === null) continue;
      if (isString(seg) && out.length > 0 && isString(out[out.length - 1])) out[out.length - 1] = cut(out[out.length - 1] + seg, MAX_TEXT);
      else out.push(seg);
    }
    return out;
  }

  /** Blocs reçus (réponse `page`) → blocs sûrs : 'h' (chaîne), 'p' et 'note' (segments), 'ul' et 'ol' (éléments,
   *  chacun une liste de segments) ; tout le reste est retiré ; au plus 40 blocs, 12 éléments par liste. */
  function normalizeBody(raw) {
    const out = [];
    for (const item of list(raw)) {
      if (out.length >= MAX_BLOCKS) break;
      const block = list(item);
      const kind = block[0];
      if (kind === 'h') {
        if (isString(block[1]) && block[1].length > 0) out.push(['h', cut(block[1], MAX_TEXT)]);
      } else if (kind === 'p' || kind === 'note') {
        const segs = segments(block.slice(1));
        if (segs.length > 0) out.push([kind, ...segs]);
      } else if (kind === 'ul' || kind === 'ol') {
        const items = [];
        for (const element of block.slice(1)) {
          if (items.length >= MAX_ITEMS) break;
          if (!element || typeof element !== 'object') continue;
          const segs = segments(list(element));
          if (segs.length > 0) items.push(segs);
        }
        if (items.length > 0) out.push([kind, ...items]);
      }
    }
    return out;
  }

  // Navigation ------------------------------------------------------------------------------------------------------

  /** Cible d'un openAt : une page de l'index, puis un chapitre de lecture (sa première page), puis un chapitre de
   *  commandes (module) ; sinon null (le livre reste à son index, sans message). */
  function focusTarget(id, reading, moduleChapters) {
    if (!isString(id) || id.length === 0) return null;
    const pages = reading ? reading.pages : [];
    if (pages.some((page) => page.id === id)) return { tab: 'reading', chapter: '', page: id };
    if (reading && reading.chapters.some((chapter) => chapter.id === id)) {
      const first = pages.find((page) => page.chapter === id);
      return { tab: 'reading', chapter: id, page: first ? first.id : '' };
    }
    if (list(moduleChapters).some((chapter) => chapter && chapter.id === id)) return { tab: 'commands', chapter: id };
    return null;
  }

  /** Pages précédente et suivante dans l'ordre de l'index (d'un chapitre à l'autre) ; null en bout de livre. */
  function neighbours(pages, id) {
    const index = pages.findIndex((page) => page.id === id);
    if (index === -1) return { previous: null, next: null };
    return { previous: index > 0 ? pages[index - 1].id : null, next: index < pages.length - 1 ? pages[index + 1].id : null };
  }

  /** Texte d'un lien de page : son libellé, sinon le titre de la cible ; null si la cible n'est pas dans l'index
   *  (le lien est alors rendu en texte brut, voir plainText). */
  function linkText(run, pagesById) {
    const target = pagesById.get(run[1]);
    if (!target) return null;
    return run[2] || target.title;
  }

  /** Texte brut d'un lien dont la cible manque : le libellé, sinon l'identifiant lisible (« faim soif »). */
  const plainText = (run) => run[2] || run[1].replace(/_/g, ' ');

  // Pages gardées (empreinte) ----------------------------------------------------------------------------------

  /** Blocs gardés pour cette page à cette empreinte, sinon null. */
  function cached(cache, id, hash) {
    const entry = cache.get(id);
    return entry && entry.hash === hash ? entry.body : null;
  }

  function store(cache, id, hash, body) {
    if (!ID.test(id) || !isString(hash) || !HASH.test(hash)) return false;
    cache.set(id, { hash, body });
    return true;
  }

  /** Oublie les pages absentes du nouvel index ou dont l'empreinte a changé ; rend le nombre de pages oubliées. */
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

  // Rendu -----------------------------------------------------------------------------------------------------------

  /** Éléments d'une page lue. `ctx` : { pagesById, keyLabel(nom) → texte ou null, commandVisible(nom, action),
   *  strings: { noKey, noKeyHint } } ; `doc` : le document (ou un faux document sous node). Tout texte passe par
   *  textContent ou createTextNode ; les attributs data- ne reçoivent que des valeurs passées par normalizeBody. */
  function renderBlocks(blocks, ctx, doc) {
    const el = (tag, className, text) => {
      const node = doc.createElement(tag);
      if (className) node.className = className;
      if (text !== undefined) node.textContent = text;
      return node;
    };

    function fill(parent, segs) {
      for (const seg of segs) {
        if (isString(seg)) {
          parent.appendChild(doc.createTextNode(seg));
          continue;
        }
        const [kind, a, b] = seg;
        if (kind === 'kbd') {
          parent.appendChild(el('kbd', 'reader-kbd', a));
        } else if (kind === 'key') {
          const label = ctx.keyLabel(a);
          const node = el('kbd', label ? 'reader-kbd' : 'reader-kbd is-missing', label || ctx.strings.noKey);
          if (!label) node.title = ctx.strings.noKeyHint;
          parent.appendChild(node);
        } else if (kind === 'cmd') {
          const text = b ? `/${a} ${b}` : `/${a}`;
          if (ctx.commandVisible(a, b)) {
            const node = el('button', 'reader-cmd', text);
            node.type = 'button';
            node.dataset.command = a;
            node.dataset.action = b;
            parent.appendChild(node);
          } else {
            parent.appendChild(el('code', 'reader-cmd is-plain', text));
          }
        } else if (kind === 'page') {
          const text = linkText(seg, ctx.pagesById);
          if (text === null) {
            parent.appendChild(doc.createTextNode(plainText(seg)));
          } else {
            const node = el('button', 'reader-link', text);
            node.type = 'button';
            node.dataset.page = a;
            parent.appendChild(node);
          }
        } else if (kind === 'em') {
          parent.appendChild(el('em', null, a));
        }
      }
      return parent;
    }

    const nodes = [];
    for (const block of blocks) {
      const kind = block[0];
      if (kind === 'h') nodes.push(el('h3', 'reader-h', block[1]));
      else if (kind === 'p') nodes.push(fill(el('p', 'reader-p'), block.slice(1)));
      else if (kind === 'note') nodes.push(fill(el('p', 'reader-note'), block.slice(1)));
      else if (kind === 'ul' || kind === 'ol') {
        const listNode = el(kind, 'reader-list');
        for (const item of block.slice(1)) listNode.appendChild(fill(el('li', 'reader-item'), item));
        nodes.push(listNode);
      }
    }
    return nodes;
  }

  return {
    list, bytes, normalizeIndex, normalizeBody, focusTarget, neighbours, linkText, plainText, cached, store, prune, renderBlocks,
  };
});
