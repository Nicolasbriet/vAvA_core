'use strict';
/*
 * web/js/app.js
 * Rôle : l'application : porte (premier lancement ou connexion), puis la coquille (colonne de navigation, état du
 *        serveur, compte) et ses pages, en trois groupes : le serveur (tableau de bord, performances, console,
 *        ressources, server.cfg, planification, sauvegardes, configuration), le
 *        royaume pour les comptes qui ont un rang du Conseil (joueurs, signalements, sanctions, journal, Conseil,
 *        proclamation, zones de voix, ciel et heure, caméras, réseau), la Chancellerie (comptes). Tient l'état du serveur et la
 *        console reçus en direct, et les distribue à la page affichée avec les relevés des performances et l'avancée
 *        des sauvegardes.
 *        Adresse de la page dans le fragment (#joueurs).
 */

const App = (() => {
  const N = STRINGS.nav;
  const MAX_LINES = 3000;
  const STATE_TICK_MS = 1000;
  const BASE_TITLE = document.title;
  const TITLE_DOTS = { running: '🟢', starting: '🟠', stopping: '🟠', stopped: '🔴', crashed: '🔴' };

  // pages : groupe, droit du panneau (permission, ou l'un de anyPermission) ou du rang du Conseil (realm), vue
  const PAGES = [
    { id: 'tableau', group: 'server', label: N.dashboard, view: DashboardView },
    { id: 'performances', group: 'server', label: N.performance, view: PerformanceView },
    { id: 'console', group: 'server', label: N.console, permission: 'console', view: ConsoleView },
    { id: 'ressources', group: 'server', label: N.resources, view: ResourcesView },
    { id: 'server-cfg', group: 'server', label: N.cfg, permission: 'config', view: CfgView },
    { id: 'planification', group: 'server', label: N.schedule, view: ScheduleView },
    { id: 'sauvegardes', group: 'server', label: N.backups, anyPermission: ['backups', 'config'], view: BackupsView },
    { id: 'configuration', group: 'server', label: N.setup, permission: 'config', view: WizardView },
    { id: 'joueurs', group: 'realm', label: N.players, realm: 'view', view: PlayersView },
    { id: 'signalements', group: 'realm', label: N.reports, realm: 'reports', view: RealmViews.reports },
    { id: 'sanctions', group: 'realm', label: N.bans, realm: 'bans', view: RealmViews.bans },
    { id: 'journal-du-conseil', group: 'realm', label: N.logs, realm: 'logs', view: RealmViews.logs },
    { id: 'conseil', group: 'realm', label: N.council, realm: 'staff', view: RealmViews.council },
    { id: 'proclamation', group: 'realm', label: N.announce, realm: 'announce', view: RealmViews.announce },
    { id: 'zones-de-voix', group: 'realm', label: N.zones, realm: 'view', view: ZonesView },
    { id: 'ciel-et-heure', group: 'realm', label: N.time, realm: 'view', view: TimeView },
    { id: 'cameras', group: 'realm', label: N.cameras, realm: 'watch', view: CamerasView },
    { id: 'reseau', group: 'realm', label: N.network, realm: 'tools', view: NetworkView },
    { id: 'comptes', group: 'chancellery', label: N.accounts, view: AccountsView },
    { id: 'mises-a-jour', group: 'chancellery', label: N.updates, view: UpdatesView },
    { id: 'discord', group: 'chancellery', label: N.discord, master: true, view: DiscordView },
  ];
  const GROUPS = ['server', 'realm', 'chancellery'];

  let account = null;
  let setupDone = false;
  let status = { state: 'stopped', since: Date.now(), crashes: 0, skew: 0 };
  // joueurs connectés, d'après le dernier relevé (null : inconnu)
  let playerCount = null;
  let lines = [];
  let current = null;
  let currentView = null;
  let refs = null;
  let tick = null;

  const context = {
    status: () => status,
    lines: () => lines,
    setupDone: () => setupDone,
    account: () => account,
    can: (permission) => Boolean(account && account.permissions.includes(permission)),
    navigate: (page) => { location.hash = page; },
    /** Compte relu (liaison au joueur faite ou défaite) : mêmes droits, nouvelle liaison. */
    refreshAccount(next) {
      if (account && next && next.name === account.name) account = next;
    },
    setServerName(name) {
      refs.server.textContent = name || '';
    },
  };

  const hasRealm = () => Boolean(account && account.rank);

  /** Page affichable pour ce compte ? (droit du rang inconnu tant que le serveur de jeu n'a pas répondu : permis) */
  function allowed(page) {
    if (page.permission && !context.can(page.permission)) return false;
    if (page.anyPermission && !page.anyPermission.some((permission) => context.can(permission))) return false;
    if (page.master && !(account && account.master)) return false;
    if (page.group === 'realm' && !hasRealm()) return false;
    if (page.realm && GAME.loaded() && !GAME.can(page.realm)) return false;
    return true;
  }

  /**
   * Titre de l'onglet : pastille de l'état du serveur (verte en marche, orange au démarrage ou à l'arrêt, rouge arrêté
   * ou planté), et le nombre de joueurs entre parenthèses quand il tourne. Sans session : le titre seul.
   */
  function renderTitle() {
    if (!account) {
      document.title = BASE_TITLE;
      return;
    }
    const dot = TITLE_DOTS[status.state] || TITLE_DOTS.stopped;
    const players = status.state === 'running' && Number.isInteger(playerCount) ? ` (${playerCount})` : '';
    document.title = `${dot}${players} ${BASE_TITLE}`;
  }

  function renderState() {
    refs.state.className = `sidebar-state is-${status.state}`;
    refs.stateLabel.textContent = STRINGS.states[status.state];
    refs.stateDetail.textContent = STRINGS.describe(status, setupDone);
    renderTitle();
  }

  /** Droits du rang relus (ouverture, serveur reparti) ; la navigation suit. */
  async function loadRealm() {
    if (!hasRealm()) return;
    await GAME.load();
    if (account) buildNav();
  }

  function onState(next) {
    const wasRunning = status.state === 'running';
    status = { ...next, skew: Date.now() - next.now };
    renderState();
    if (!wasRunning && status.state === 'running') loadRealm();
    if (currentView && currentView.update) currentView.update(status);
  }

  function onHistory({ lines: incoming }) {
    const lastId = lines.length ? lines[lines.length - 1].id : 0;
    const restarted = incoming.length && incoming[incoming.length - 1].id < lastId;
    if (restarted || !lines.length) {
      lines = incoming.slice(-MAX_LINES);
      if (currentView === ConsoleView) ConsoleView.reset(lines);
      return;
    }
    onLines(incoming.filter((line) => line.id > lastId));
  }

  function onLines(incoming) {
    if (!incoming.length) return;
    lines.push(...incoming);
    if (lines.length > MAX_LINES) lines.splice(0, lines.length - MAX_LINES);
    if (currentView === ConsoleView) ConsoleView.lines(incoming);
  }

  function onReport(event) {
    if (event.action === 'created') UI.slip(STRINGS.reports.arrived(event.author));
    if (currentView === RealmViews.reports) RealmViews.reports.refresh();
  }

  function pageFromHash() {
    const id = location.hash.replace(/^#/, '');
    const page = PAGES.find((p) => p.id === id);
    if (page && allowed(page)) return page;
    return PAGES.find((p) => p.id === (setupDone || !context.can('config') ? 'tableau' : 'configuration'));
  }

  function show(page) {
    if (currentView && currentView.hide) currentView.hide();
    current = page.id;
    currentView = page.view;
    for (const node of refs.nav.querySelectorAll('.nav-item')) node.classList.toggle('is-active', node.dataset.page === page.id);
    refs.sheet.className = 'sheet';
    if (page.id === 'configuration') {
      currentView.show(refs.sheet, {
        canStart: context.can('server'),
        onFinish(result) {
          setupDone = true;
          renderState();
          context.navigate(result.started ? 'console' : 'tableau');
        },
      });
    } else {
      currentView.show(refs.sheet, context);
    }
    window.scrollTo(0, 0);
  }

  function buildNav() {
    const nodes = [];
    for (const group of GROUPS) {
      const pages = PAGES.filter((p) => p.group === group && (group !== 'realm' || hasRealm()));
      if (!pages.length) continue;
      nodes.push(UI.el('p', 'nav-group', N.groups[group]));
      for (const page of pages) {
        const node = UI.button(page.label, () => context.navigate(page.id));
        node.className = `nav-item${page.id === current ? ' is-active' : ''}`;
        node.dataset.page = page.id;
        if (!allowed(page)) node.disabled = true;
        nodes.push(node);
      }
    }
    refs.nav.replaceChildren(...nodes);
  }

  function openShell(who, done) {
    account = who;
    setupDone = done;
    GateView.hide();
    refs.shell.hidden = false;
    refs.accountName.textContent = account.name;
    buildNav();
    renderState();
    API.connect({
      state: onState, history: onHistory, line: (line) => onLines([line]), report: onReport,
      players: () => {
        PlayersView.players();
        CamerasView.players();
        QuickPlayers.players();
      },
      camera: (data) => CAMERA.event(data),
      metrics: (sample) => {
        playerCount = sample && Number.isInteger(sample.players) ? sample.players : null;
        renderTitle();
        QuickPlayers.metrics(sample);
        if (currentView && currentView.metrics) currentView.metrics(sample);
      },
      backup: (state) => {
        if (currentView && currentView.backup) currentView.backup(state);
      },
      job: (job) => {
        if (currentView && currentView.job) currentView.job(job);
      },
      update: (view) => {
        if (currentView && currentView.updates) currentView.updates(view);
      },
      linked: (data) => {
        if (currentView && currentView.linked) currentView.linked(data);
      },
      // le pont n'a pas pris la clé de la Chancellerie (aussi dans la console et au journal)
      alert: (data) => {
        if (data && typeof data.text === 'string') UI.slip(data.text);
      },
    });
    clearInterval(tick);
    tick = setInterval(() => { refs.stateDetail.textContent = STRINGS.describe(status, setupDone); }, STATE_TICK_MS);
    show(pageFromHash());
    loadRealm();
  }

  function closeShell() {
    API.disconnect();
    CAMERA.reset();
    GAME.forget();
    clearInterval(tick);
    tick = null;
    if (currentView && currentView.hide) currentView.hide();
    currentView = null;
    current = null;
    account = null;
    lines = [];
    playerCount = null;
    renderTitle();
    refs.shell.hidden = true;
    refs.sheet.replaceChildren();
  }

  async function boot() {
    const state = await API.get('/api/state');
    if (!state.ok) {
      document.body.append(UI.el('p', 'noscript', STRINGS.error(state.error)));
      return;
    }
    if (state.phase === 'ready') {
      openShell(state.account, state.setupDone);
      return;
    }
    closeShell();
    GateView.show(state, async () => {
      // l'état complet (configuration faite ou non) est relu après l'entrée
      const fresh = await API.get('/api/state');
      if (fresh.ok && fresh.phase === 'ready') openShell(fresh.account, fresh.setupDone);
    });
  }

  function init() {
    refs = {
      shell: document.getElementById('shell'),
      sheet: document.querySelector('.sheet'),
      nav: document.querySelector('.nav'),
      server: document.querySelector('.crest-server'),
      state: document.querySelector('.sidebar-state'),
      stateLabel: document.querySelector('.state-label'),
      stateDetail: document.querySelector('.state-detail'),
      accountName: document.querySelector('.account-name'),
    };
    UI.init();
    GateView.init();
    CAMERA.init();
    QuickPlayers.init(context);
    const logout = document.querySelector('[data-action="logout"]');
    logout.textContent = N.logout;
    logout.addEventListener('click', async () => {
      CAMERA.reset();
      await API.post('/api/logout');
      location.hash = '';
      boot();
    });
    API.onLoggedOut(() => {
      if (account) boot();
    });
    window.addEventListener('hashchange', async () => {
      if (!account) return;
      const page = pageFromHash();
      if (page.id === current) return;
      // une page qui retient des modifications (éditeur du server.cfg) peut refuser qu'on la quitte
      if (currentView && currentView.leave) {
        const leaving = current;
        if (!(await currentView.leave())) {
          history.replaceState(null, '', `#${leaving}`);
          return;
        }
      }
      show(pageFromHash());
    });
    boot();
  }

  return { init };
})();

App.init();
