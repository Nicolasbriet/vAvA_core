'use strict';
/*
 * vava_atelier/web/js/form.js — fiche pilotée par le schéma d'un type, paquet { n, s, b } ; contrôles de confort seulement
 *   `env.between` (T-102) : blocs du placement posés entre les champs hors groupes et les groupes.
 * Dépendances : strings.js, format.js, components.js, widgets.js
 */

const Form = (() => {
  const { h } = UI;
  const F = STRINGS.fields;
  const CHARSETS = { name: /^[\p{L}\p{M}\p{N} '’\-,.]*$/u, id: /^[a-z0-9_]*$/ };
  const CONTROL = /[\u0000-\u0008\u000b-\u001f\u007f]/;
  const MAX_LINES = 8;

  function localError(field, value) {
    const optional = field.optional === true;
    switch (field.widget) {
      case 'text': {
        const text = String(value).trim();
        const length = Format.chars(text), min = Number(field.min) || 0, max = Number(field.max) || 80;
        const charset = CHARSETS[field.charset] ? field.charset : 'free';
        if (length === 0) return min > 0 && !optional ? F.required : '';
        if (length < min || length > max) return F.length(min, max);
        if (/[<>]/.test(text) || CONTROL.test(text) || (field.multiline !== true && text.includes('\n'))) return F.charset.free;
        if (charset !== 'free' && !CHARSETS[charset].test(text)) return F.charset[charset];
        return field.multiline === true && text.split('\n').length > MAX_LINES ? F.lines(MAX_LINES) : '';
      }
      case 'duration':
        if (!Number.isFinite(value)) return F.required;
        return value < Number(field.min) || value > Number(field.max) ? F.range(Format.duration(field.min), Format.duration(field.max)) : '';
      case 'model':
        if (value !== '' && field.free === true && !/^[\w-]+$/.test(value)) return F.model;
        return value === '' && !optional ? F.required : '';
      case 'segmented': case 'select': case 'item':
        return value === '' && !optional ? F.required : '';
      default:
        return '';
    }
  }

  function build(kind, values, env) {
    const form = kind.form || {};
    const fields = Format.list(form.fields).filter((f) => f && typeof f.id === 'string' && Widgets.MAP[f.widget]);
    const groups = Format.list(form.groups).filter((g) => g && typeof g.id === 'string');
    const entries = new Map();
    const alerts = h('div', { class: 'alerts', role: 'alert', hidden: true });

    function block(field) {
      const err = h('p', { class: 'err', hidden: true });
      const node = h('div', { class: 'field', data: { field: field.id } });
      const value = Object.prototype.hasOwnProperty.call(values, field.id) ? values[field.id] : Widgets.defaultOf(field);
      const widget = Widgets.create(field, value, {
        changed: () => { setError(field.id, ''); env.changed(field.id); },
        lookup: env.lookup, known: env.known, remember: env.remember,
      });
      UI.append(node, [widget.nodes, h('p', { class: 'hp', text: Format.str(field.help) }), widget.after,
        env.warnings.has(field.id) ? h('p', { class: 'warn', text: STRINGS.entry.warning }) : null, err]);
      entries.set(field.id, { field, widget, node, err });
      return node;
    }

    function rows(list) {
      const out = [];
      for (let i = 0; i < list.length; i += 1) {
        if (list[i].width === 'half' && list[i + 1] && list[i + 1].width === 'half') {
          out.push(h('div', { class: 'pair' }, block(list[i]), block(list[i + 1])));
          i += 1;
        } else out.push(block(list[i]));
      }
      return out;
    }

    const declared = new Set(groups.map((g) => g.id));
    const root = h('div', { class: 'form' }, alerts, rows(fields.filter((f) => !declared.has(f.group))), env.between || null);
    for (const group of groups) {
      const members = fields.filter((f) => f.group === group.id);
      if (members.length === 0) continue;
      const folded = group.folded === true;
      root.append(h(folded ? 'details' : 'section', { class: 'fgroup' },
        h(folded ? 'summary' : 'h2', { class: 'gh', text: Format.str(group.label) }),
        Format.str(group.help) ? h('p', { class: 'hp gh-help', text: group.help }) : null,
        h('div', { class: 'fgroup-body' }, rows(members))));
    }

    function setError(id, text, add) {
      const entry = entries.get(id);
      const full = add && entry.err.textContent ? `${entry.err.textContent} ${text}` : text;
      entry.err.textContent = full;
      entry.err.hidden = !full;
      entry.node.classList.toggle('invalid', Boolean(full));
      entry.widget.control.setAttribute('aria-invalid', String(Boolean(full)));
      const details = full ? entry.node.closest('details') : null;
      if (details) details.open = true;
    }

    function clear() {
      for (const id of entries.keys()) setError(id, '');
      alerts.replaceChildren();
      alerts.hidden = true;
    }

    function packet() {
      const out = { n: {}, s: {}, b: {} };
      for (const [id, entry] of entries) {
        const map = Widgets.MAP[entry.field.widget], value = entry.widget.get();
        out[map][id] = map === 'n' ? (Number.isFinite(value) ? value : 0) : (map === 'b' ? value === true : Format.clip(String(value), 1200));
      }
      for (const map of ['n', 's', 'b']) if (Object.keys(out[map]).length === 0) delete out[map];
      return out;
    }

    function validate() {
      clear();
      let ok = true;
      for (const [id, entry] of entries) {
        const text = localError(entry.field, entry.widget.get());
        if (text) { setError(id, text); ok = false; }
      }
      return ok;
    }

    function showErrors(errors) {
      clear();
      for (const error of Format.list(errors)) {
        if (!error || typeof error.text !== 'string') continue;
        if (entries.has(error.field)) setError(error.field, error.text, true);
        else alerts.append(h('p', { text: error.text }));
      }
      alerts.hidden = alerts.childElementCount === 0;
    }

    function focusFirstError() {
      const entry = Array.from(entries.values()).find((e) => !e.err.hidden);
      (entry ? entry.node : alerts).scrollIntoView({ block: 'nearest' });
      if (entry) entry.widget.focus();
    }

    const titleField = Format.str(form.titleField);
    return {
      el: root, packet, validate, showErrors, clear, focusFirstError, titleField,
      snapshot: () => JSON.stringify(packet()),
      title: () => (entries.has(titleField) ? String(entries.get(titleField).widget.get()).trim() : ''),
      focusFirst: () => { const first = entries.values().next().value; if (first) first.widget.focus(); },
    };
  }

  return { build, localError };
})();
