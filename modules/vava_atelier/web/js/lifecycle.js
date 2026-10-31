'use strict';
/*
 * vava_atelier/web/js/lifecycle.js — fonctions pures du cycle d'une fiche : pied, lecture seule, boîtes, historique
 * Dépendances : strings.js, format.js
 */

const Lifecycle = (() => {
  const { str, list } = Format;
  const T = STRINGS;
  const int = (value) => (Number.isInteger(value) && value >= 0 ? value : 0);
  const yes = (value) => value === true || value === 1;
  const elided = (article) => /['’]$/.test(article);

  function newFooter(descriptor) {
    if (descriptor && descriptor.stored === true) {
      return [{ id: 'save', label: T.buttons.save, primary: true }, { id: 'check', label: T.buttons.check, link: true }];
    }
    return [{ id: 'check', label: T.buttons.check, primary: true }];
  }

  function foot(footer, ctx) {
    const items = list(footer).filter((b) => b && typeof b.id === 'string' && str(b.label));
    const commands = items.filter((b) => b.link !== true).map((b) => ({ id: b.id, label: b.label, primary: b.primary === true }));
    commands.sort((a, b) => Number(a.primary) - Number(b.primary));
    const links = items.filter((b) => b.link === true).map((b) => ({ id: b.id, label: b.label }));
    let hint = '';
    if (commands.some((b) => b.id === 'publish')) hint = ctx && ctx.tone === 'removal' ? '' : str(ctx && ctx.publishHint);
    else if (items.length === 1 && items[0].id === 'check') hint = T.entry.checkHint;
    return { commands, links, hint };
  }

  function label(footer, id, fallback) {
    const found = list(footer).find((b) => b && b.id === id);
    return (found && str(found.label)) || fallback || '';
  }

  function readOnly(data, version) {
    if (version) return true;
    const holder = data && data.holder;
    if (holder && typeof holder === 'object' && holder.mine !== true) return true;
    return yes(data && data.removal) || Boolean(data && data.state && data.state.tone === 'removal');
  }

  const ofNoun = (kind) => {
    const article = str(kind.article), noun = str(kind.noun);
    if (article === 'le') return `du ${noun}`;
    if (article === 'les') return `des ${noun}`;
    return elided(article) ? `de ${article}${noun}` : `de ${article} ${noun}`;
  };
  const theNoun = (kind) => (elided(str(kind.article)) ? `${kind.article}${str(kind.noun)}` : `${str(kind.article)} ${str(kind.noun)}`);
  const feminine = (kind) => (typeof kind.feminine === 'boolean' ? kind.feminine : kind.article === 'la');

  function errorLines(errors, fields) {
    const labels = new Map(list(fields).filter((f) => f && typeof f.id === 'string').map((f) => [f.id, str(f.label)]));
    return list(errors).filter((e) => e && str(e.text)).slice(0, 16).map((e) => (labels.get(e.field) ? `${labels.get(e.field)} : ${e.text}` : e.text));
  }

  const texts = (value, max) => list(value).filter((t) => str(t)).slice(0, max);

  function confirmOf(what, preview, ctx) {
    const p = preview || {};
    const title = what === 'restore' ? T.confirm.restore(ctx.version) : T.confirm.ask(ctx.label);
    if (p.valid !== true) {
      return { title, text: what === 'restore' ? T.invalid : T.confirm.invalid, errors: errorLines(p.errors, ctx.fields), cancel: T.confirm.backEntry, ok: '' };
    }
    return {
      title, lines: texts(p.lines, 8), warnings: texts(p.warnings, 4),
      hint: what === 'publish' && !ctx.removal ? str(ctx.publishHint) : '',
      cancel: T.confirm.stay, ok: what === 'restore' ? T.confirm.restoreOk : ctx.label,
    };
  }

  function confirmRetire(kind) {
    const c = T.confirm.retire(ofNoun(kind), theNoun(kind), feminine(kind));
    return { title: c.title, text: c.text, cancel: T.confirm.stay, ok: c.ok };
  }

  function confirmTake(who) {
    const c = T.confirm.take(who);
    return { title: c.title, text: c.text, cancel: T.confirm.stay, ok: c.ok };
  }

  function historyRow(v) {
    const removal = yes(v.removal);
    const tone = removal ? 'removal' : (v.status === 'published' ? 'live' : 'archived');
    const author = str(v.author), when = str(v.when);
    const from = int(v.restoredFrom);
    return {
      version: int(v.version), tone, tag: T.history.tags[tone], title: T.history.version(int(v.version)),
      summary: str(v.summary), who: author && when ? T.journal.who(author, when) : author || when,
      from: from > 0 ? T.history.from(from) : '', canRestore: tone === 'archived',
    };
  }

  const history = (versions) => list(versions).filter((v) => v && int(v.version) > 0).map(historyRow);

  function changed(entry, payload, dirty) {
    if (!entry || entry.mode !== 'entry' || !entry.id) return 'none';
    if (str(payload.editor) !== entry.editor || str(payload.kind) !== entry.kind.id || str(payload.id) !== entry.id) return 'none';
    return dirty ? 'notice' : 'reload';
  }

  return { newFooter, foot, label, readOnly, ofNoun, theNoun, feminine, errorLines, confirmOf, confirmRetire, confirmTake, history, changed };
})();
