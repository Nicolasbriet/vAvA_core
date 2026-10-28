'use strict';
/*
 * web/js/view-mentoring.js
 * Rôle : onglet Mentorat : propositions reçues (accepter ou refuser, compte à rebours tenu par un seul intervalle
 *        d'une seconde, actif seulement tant qu'une proposition est affichée), mes maîtres et mes apprentis par
 *        compétence (en jeu ou absent, depuis quand, rompre en deux temps), et proposer un mentorat : compétence
 *        où l'on peut enseigner, personne à portée (lue côté serveur), envoi. Les réponses du serveur font relire
 *        la fiche ; les refus sont traduits.
 */

const MentoringView = (() => {
  const T = STRINGS.mentoring;
  const CONFIRM_MS = 4000;
  // choix du formulaire, gardés d'un rendu à l'autre tant que l'onglet est ouvert
  let form = { skill: null, players: null, target: null, searching: false };

  async function answer(proposal, accept) {
    const result = await Bridge.post('answer', { id: proposal.id, accept });
    if (!result.ok) {
      App.toast(errorMessage(result.error), 'warning');
      if (result.error === 'expired' || result.error === 'not_found') Model.removeProposal(proposal.id);
      App.refresh();
      return;
    }
    Model.removeProposal(proposal.id);
    App.refresh();
  }

  async function breakUp(mentorshipId) {
    const result = await Bridge.post('break', { mentorshipId });
    if (!result.ok) {
      App.toast(errorMessage(result.error), 'warning');
      return;
    }
    App.refresh();
  }

  /** Bouton « Rompre » qui demande confirmation pendant quelques secondes. */
  function breakButton(mentorshipId) {
    let timer = null;
    const button = UI.button(T.breakUp, 'button button-ghost is-danger', () => {
      if (button.classList.contains('is-armed')) {
        clearTimeout(timer);
        breakUp(mentorshipId);
        return;
      }
      button.classList.add('is-armed');
      button.textContent = T.confirmBreak;
      timer = setTimeout(() => {
        button.classList.remove('is-armed');
        button.textContent = T.breakUp;
      }, CONFIRM_MS);
    });
    return button;
  }

  function proposalCard(proposal) {
    const remaining = UI.el('span', 'card-sub proposal-timer', T.expiresIn(UI.countdown(proposal.expiresAtMs - Date.now())));
    remaining.dataset.expires = String(proposal.expiresAtMs);
    return UI.el('article', 'card is-proposal', null, [
      UI.el('p', 'card-text', T.proposalText(proposal.masterName, proposal.skillLabel)),
      remaining,
      UI.el('div', 'card-actions', null, [
        UI.button(T.decline, 'button button-ghost', () => answer(proposal, false)),
        UI.button(T.accept, 'button button-primary', () => answer(proposal, true)),
      ]),
    ]);
  }

  /** Carte d'un maître ou d'un apprenti : présence, nom, compétence, ancienneté, rupture. */
  function buildPerson(skill, person) {
    const card = UI.el('article', `card is-person${person.online ? ' is-online' : ''}`);
    card.append(
      UI.el('span', 'presence'),
      UI.el('div', 'card-main', null, [
        UI.el('span', 'card-title', person.name),
        UI.el('span', 'card-sub', `${skill.label} · ${person.online ? T.online : T.offline} · ${T.since(UI.duration(Model.now() - person.since))}`),
      ]),
      UI.el('div', 'card-actions', null, [breakButton(person.mentorshipId)]),
    );
    return card;
  }

  async function search(skillId, rerender) {
    form.searching = true;
    form.players = null;
    form.target = null;
    rerender();
    const result = await Bridge.post('nearby', {});
    form.searching = false;
    if (!result.ok) {
      App.toast(errorMessage(result.error), 'warning');
      form.players = [];
    } else {
      form.players = Model.list(result.players);
    }
    // la compétence a pu être changée pendant la recherche
    if (form.skill === skillId) rerender();
  }

  async function send(rerender) {
    if (!form.skill || !form.target) return;
    const result = await Bridge.post('propose', { serverId: form.target, skill: form.skill });
    if (!result.ok) {
      App.toast(errorMessage(result.error), 'warning');
      return;
    }
    App.toast(T.sent, 'info');
    form.players = null;
    form.target = null;
    rerender();
  }

  function proposeBlock(sheet, rerender) {
    const teachable = Model.teachable();
    const block = UI.el('section', 'propose');
    block.append(UI.section(T.propose));
    if (teachable.length === 0) {
      block.append(UI.el('p', 'prose is-muted', T.noMasterSkill));
      return block;
    }
    if (!teachable.some((skill) => skill.id === form.skill)) form.skill = teachable[0].id;
    block.append(UI.el('p', 'prose', T.proposeIntro(sheet.rules.mentoring.maxApprentices || 3)));

    const chips = UI.el('div', 'chips');
    for (const skill of teachable) {
      const chip = UI.button(skill.label, `chip${skill.id === form.skill ? ' is-selected' : ''}`, () => {
        form.skill = skill.id;
        form.players = null;
        form.target = null;
        rerender();
      });
      chips.append(chip);
    }
    block.append(UI.el('p', 'field-label', T.chooseSkill), chips);

    block.append(UI.el('p', 'field-label', T.choosePlayer));
    const searchButton = UI.button(form.searching ? T.searching : T.search, 'button button-ghost', () => search(form.skill, rerender));
    searchButton.disabled = form.searching;
    const players = UI.el('div', 'chips');
    if (form.players) {
      if (form.players.length === 0) players.append(UI.el('p', 'prose is-muted', T.nobody));
      for (const player of form.players) {
        const chip = UI.button('', `chip is-person${player.serverId === form.target ? ' is-selected' : ''}`, () => {
          form.target = player.serverId;
          rerender();
        });
        chip.append(UI.el('span', null, player.name), UI.el('small', null, T.distance(player.distance)));
        players.append(chip);
      }
    }
    const sendButton = UI.button(T.send, 'button button-primary', () => send(rerender));
    sendButton.disabled = !form.target;
    block.append(UI.el('div', 'form-row', null, [searchButton, sendButton]), players);
    return block;
  }

  /** Avance les comptes à rebours affichés ; retire les propositions échues. */
  function tick(page, rerender) {
    if (Model.pruneProposals()) {
      rerender();
      return;
    }
    for (const node of page.querySelectorAll('.proposal-timer')) {
      node.textContent = T.expiresIn(UI.countdown(Number(node.dataset.expires) - Date.now()));
    }
  }

  function render(pages) {
    const sheet = Model.state.sheet;
    const page = UI.el('div', 'page');
    let timer = null;
    const rerender = () => App.render();

    page.append(UI.section(T.proposals));
    if (sheet.proposals.length === 0) page.append(UI.el('p', 'prose is-muted', T.noProposal));
    for (const proposal of sheet.proposals) page.append(proposalCard(proposal));
    if (sheet.proposals.length > 0) timer = setInterval(() => tick(page, rerender), 1000);

    page.append(UI.section(T.masters));
    const masters = sheet.skills.filter((skill) => skill.mentor);
    if (masters.length === 0) page.append(UI.el('p', 'prose is-muted', T.noMaster));
    for (const skill of masters) page.append(buildPerson(skill, skill.mentor));
    page.append(UI.el('p', 'prose is-muted', T.bonus(Math.round((sheet.rules.mentoring.bonus || 0) * 100))));

    page.append(UI.section(T.apprentices));
    const withApprentices = sheet.skills.filter((skill) => skill.apprentices.length > 0);
    if (withApprentices.length === 0) page.append(UI.el('p', 'prose is-muted', T.noApprentice));
    for (const skill of withApprentices) {
      for (const apprentice of skill.apprentices) page.append(buildPerson(skill, apprentice));
    }

    page.append(proposeBlock(sheet, rerender));
    pages.classList.add('is-single');
    pages.append(page);
    return () => { if (timer) clearInterval(timer); };
  }

  // le formulaire oublie ses choix quand le livre se ferme
  function reset() {
    form = { skill: null, players: null, target: null, searching: false };
  }

  return { render, reset };
})();
