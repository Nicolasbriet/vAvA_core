'use strict';
/*
 * web/js/strings.js
 * Rôle : tous les textes de la Chancellerie (français), messages d'erreur de l'API compris, et leur mise en forme
 *        (durées, dates, nombres).
 */

const STRINGS = (() => {
  const errors = {
    bad_pin: 'Code d\'accès incorrect. Après plusieurs erreurs, un nouveau code s\'affiche dans la fenêtre de la Chancellerie.',
    invalid_name: 'Identifiant : 3 à 32 caractères, lettres, chiffres, point, tiret ou soulignement.',
    password_too_short: 'Le mot de passe doit compter au moins 10 caractères.',
    password_too_long: 'Le mot de passe est trop long (200 caractères au plus).',
    password_mismatch: 'Les deux mots de passe ne sont pas identiques.',
    name_taken: 'Cet identifiant est déjà pris.',
    already_done: 'Le compte maître existe déjà : connectez-vous.',
    bad_credentials: 'Identifiant ou mot de passe incorrect.',
    rate_limited: 'Trop de tentatives : patientez un instant.',
    not_logged_in: 'Votre session a pris fin : reconnectez-vous.',
    forbidden: 'Ce compte n\'a pas ce droit.',
    csrf: 'Requête refusée : rechargez la page.',
    bad_host: 'Adresse refusée : ouvrez la Chancellerie par 127.0.0.1 ou localhost.',
    server_folder_invalid: 'Ce dossier ne contient pas de dossier « resources » : ce n\'est pas un dossier de serveur.',
    fxserver_invalid: 'FXServer.exe est introuvable à cet emplacement.',
    server_running: 'Arrêtez d\'abord le serveur.',
    paths_missing: 'Choisissez d\'abord les dossiers (première étape).',
    required: 'Ce champ est obligatoire.',
    invalid: 'Valeur incorrecte.',
    unknown_resource: 'Une ressource cochée n\'existe pas dans le dossier du serveur.',
    unsupported_password: 'Ce mot de passe mêle des caractères qu\'oxmysql ne sait pas lire ensemble (« : @ / ? # % » avec « = » ou « ; »), ou contient un guillemet.',
    db_refused: 'La base de données refuse cette machine (hôte non autorisé ?).',
    db_unreachable: 'Rien n\'écoute à cette adresse : MySQL ou MariaDB est-il lancé ?',
    db_timeout: 'La base de données ne répond pas (délai dépassé).',
    db_not_mysql: 'Quelque chose répond, mais ce n\'est pas MySQL ni MariaDB.',
    db_error: 'Connexion impossible à cette adresse.',
    already_running: 'Le serveur est déjà lancé.',
    not_running: 'Le serveur n\'est pas lancé.',
    not_configured: 'Le serveur n\'est pas encore configuré : terminez l\'assistant.',
    fxserver_missing: 'FXServer.exe est introuvable : vérifiez la configuration.',
    server_folder_missing: 'Le dossier du serveur est introuvable : vérifiez la configuration.',
    cfg_missing: 'Le server.cfg est introuvable : terminez l\'assistant.',
    spawn_failed: 'FXServer n\'a pas pu être lancé.',
    use_stop_button: 'Pour arrêter le serveur, utilisez le bouton « Arrêter » : il sauvegarde les personnages avant.',
    too_many_streams: 'Trop d\'onglets ouverts sur la Chancellerie.',
    too_large: 'Envoi trop volumineux.',
    network: 'La Chancellerie ne répond pas. Est-elle toujours lancée ?',
    // royaume (Registre du Conseil, par le pont du serveur de jeu)
    server_stopped: 'Le serveur de jeu est arrêté.',
    bridge_unreachable: 'Le serveur de jeu ne répond pas encore.',
    bridge_missing: 'Le pont de la Chancellerie (vava_chancellerie) n\'est pas lancé sur le serveur de jeu.',
    bridge_error: 'Réponse incompréhensible du serveur de jeu.',
    admin_unavailable: 'Le Registre du Conseil (vava_admin) n\'est pas lancé.',
    voice_unavailable: 'Le chat vocal (vava_voice) n\'est pas lancé.',
    no_rank: 'Ce compte n\'a pas de rang du Conseil : le compte maître peut lui en donner un.',
    invalid_actor: 'Le rang de ce compte n\'existe plus au Conseil.',
    unknown_request: 'Demande inconnue.',
    not_found: 'Ce joueur n\'est plus là.',
    self: 'Pas sur la même personne.',
    outranked: 'Son rang est égal ou supérieur au vôtre.',
    no_ped: 'Personnage introuvable (encore en sélection ?).',
    no_previous: 'Aucune position où le renvoyer.',
    destination_not_found: 'Le joueur de destination n\'est plus là.',
    unavailable: 'Module indisponible sur le serveur de jeu.',
    db_error: 'La base de données ne répond pas.',
    ban_too_long: 'Durée au-delà de ce que permet votre rang.',
    not_banned: 'Aucun ban en cours.',
    unknown_rank: 'Rang inconnu.',
    no_character: 'Aucun personnage chargé.',
    no_space: 'Pas assez de place dans son inventaire.',
    too_heavy: 'Trop lourd pour lui.',
    invalid_args: 'Saisie refusée.',
    unknown_zone: 'Cette zone n\'existe plus.',
    invalid_label: 'Donnez un nom.',
    too_many_cameras: 'Trop de caméras ouvertes.',
    too_many_viewers: 'Six membres du Conseil regardent déjà ce joueur.',
    not_playing: 'Ce joueur est en sélection de personnage.',
    cameras_unavailable: 'Les caméras (vava_cameras) ne sont pas lancées sur le serveur de jeu.',
    unknown_session: 'Cette caméra est déjà éteinte.',
    // comptes
    unknown_account: 'Compte introuvable.',
    master_account: 'Le compte maître ne se modifie pas ainsi.',
    invalid_permissions: 'Droits refusés.',
    invalid_rank: 'Rang refusé.',
    too_many_accounts: 'Nombre maximal de comptes atteint.',
    bad_password: 'Mot de passe actuel incorrect.',
  };

  const fields = {
    serverDataPath: 'Dossier du serveur', fxserverPath: 'FXServer.exe', hostname: 'Nom du serveur', projectName: 'Nom du projet',
    projectDesc: 'Description', maxClients: 'Places', bind: 'Adresse d\'écoute', port: 'Port', onesync: 'OneSync',
    licenseKey: 'Clé de licence', 'db.host': 'Hôte', 'db.port': 'Port', 'db.user': 'Utilisateur', 'db.database': 'Base',
    'db.password': 'Mot de passe', resources: 'Ressources', extra: 'Options avancées',
  };

  const states = {
    stopped: 'Arrêté', starting: 'Démarrage', running: 'En marche', stopping: 'Arrêt en cours', crashed: 'Planté',
  };

  const actions = {
    panel_started: 'Chancellerie lancée', panel_stopped: 'Chancellerie arrêtée', master_created: 'Compte maître créé',
    login: 'Connexion', login_failed: 'Connexion refusée', logout: 'Déconnexion', paths: 'Dossiers choisis',
    cfg_written: 'server.cfg écrit', start: 'Démarrage', stop: 'Arrêt', restart: 'Redémarrage', crash: 'Arrêt imprévu',
    relaunch_abandoned: 'Relance abandonnée', orphan_stopped: 'FXServer orphelin arrêté', command: 'Commande',
    spawn_failed: 'Lancement impossible', account_created: 'Compte créé', account_updated: 'Compte modifié',
    account_deleted: 'Compte supprimé', password_reset: 'Mot de passe remis', password_changed: 'Mot de passe changé',
  };

  function plural(count, one, many) {
    return `${count} ${count > 1 ? many : one}`;
  }

  /** 3 j 4 h · 2 h 05 min · 12 min · 40 s */
  function duration(ms) {
    const seconds = Math.max(0, Math.floor(ms / 1000));
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (days) return `${days} j ${hours} h`;
    if (hours) return `${hours} h ${String(minutes).padStart(2, '0')} min`;
    if (minutes) return `${minutes} min`;
    return `${seconds} s`;
  }

  const dateFormat = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
  // « de » élidé devant une voyelle : « l'écran d'Aldric », « l'inventaire de Brune »
  const of = (label) => (/^[aeiouyàâäéèêëîïôöûü]/i.test(label) ? `d'${label}` : `de ${label}`);

  /**
   * Précision sous l'état du serveur (« depuis 2 h 05 min », « relance dans 4 s »…).
   * @param {object} status  état reçu de la Chancellerie, `skew` = écart entre l'horloge du navigateur et la sienne
   */
  function describe(status, setupDone) {
    if (!setupDone && status.state === 'stopped') return STRINGS.server.notConfigured;
    const now = Date.now() - (status.skew || 0);
    if (status.state === 'crashed') return status.relaunchAt ? STRINGS.server.relaunchIn(Math.max(0, status.relaunchAt - now)) : STRINGS.server.relaunchStopped;
    if (status.state === 'running' && status.startedAt) return STRINGS.server.since(now - status.startedAt);
    return STRINGS.server.since(now - status.since);
  }

  return {
    errors, fields, states, actions, plural, duration, describe,
    date: (value) => dateFormat.format(new Date(value)),
    error(code, field) {
      const base = errors[code] || `Erreur inattendue (${code}).`;
      return field && fields[field] && (code === 'invalid' || code === 'required') ? `${fields[field]} : ${base.charAt(0).toLowerCase()}${base.slice(1)}` : base;
    },

    gate: {
      foot: 'vAvA · panneau du serveur',
      pinTitle: 'Premier lancement',
      pinIntro: 'Saisissez le code d\'accès affiché dans la fenêtre de la Chancellerie, puis créez le compte maître : il aura tous les droits.',
      pinLabel: 'Code d\'accès',
      name: 'Identifiant',
      password: 'Mot de passe',
      passwordAgain: 'Mot de passe, encore',
      passwordHelp: '10 caractères au moins.',
      createMaster: 'Créer le compte maître',
      loginTitle: 'Registre du serveur',
      login: 'Entrer',
    },

    nav: {
      dashboard: 'Tableau', console: 'Console', setup: 'Configuration', logout: 'Se retirer',
      players: 'Joueurs', reports: 'Signalements', bans: 'Sanctions', logs: 'Journal du Conseil', council: 'Conseil',
      announce: 'Proclamation', zones: 'Zones de voix', cameras: 'Caméras', accounts: 'Comptes',
      groups: { server: 'Serveur', realm: 'Royaume', chancellery: 'Chancellerie' },
    },

    pages: { previous: 'Page précédente', next: 'Page suivante', page: (n) => `Page ${n}` },
    done: 'C\'est fait.',
    realmStopped: 'Le serveur de jeu est arrêté : le royaume se gère quand il est en marche.',

    players: {
      title: 'Joueurs',
      count: (n) => plural(n, 'âme en jeu', 'âmes en jeu'),
      empty: 'Personne n\'est connecté.',
      columns: ['N°', 'Nom FiveM', 'Personnage', 'Rang', 'Latence'],
      none: 'Choisissez un joueur dans la liste.',
      gone: 'Ce joueur vient de partir.',
      tags: { downed: 'À terre', frozen: 'Immobilisé' },
      facts: { account: 'Compte', name: 'Nom FiveM', health: 'Vie', hunger: 'Faim', thirst: 'Soif', position: 'Position', ping: 'Latence' },
      account: (id) => `n° ${id}`,
      noCharacter: 'En sélection',
      warnings: 'Avertissements',
      noWarnings: 'Aucun avertissement.',
      groups: { words: 'Paroles', move: 'Déplacements', care: 'Soins', justice: 'Justice', goods: 'Biens', watch: 'Surveillance' },
      actions: {
        message: 'Écrire', warn: 'Avertir', moveToPlayer: 'Vers un joueur', moveToCoords: 'Vers un lieu', sendBack: 'Renvoyer',
        heal: 'Soigner', feed: 'Nourrir', freeze: 'Immobiliser', unfreeze: 'Libérer', kick: 'Expulser', ban: 'Bannir',
        inventory: 'Voir l\'inventaire', give: 'Donner un objet', watch: 'Regarder l\'écran',
      },
      dialogs: {
        message: { title: 'Écrire à', label: 'Message', confirm: 'Envoyer' },
        warn: { title: 'Avertir', label: 'Motif de l\'avertissement', confirm: 'Avertir' },
        moveToPlayer: { title: 'Envoyer auprès de', label: 'Joueur de destination', confirm: 'Envoyer' },
        moveToCoords: { title: 'Envoyer vers un lieu', confirm: 'Envoyer' },
        kick: { title: 'Expulser', label: 'Motif de l\'expulsion', confirm: 'Expulser' },
        ban: { title: 'Bannir', duration: 'Durée', label: 'Motif du ban', confirm: 'Sceller le ban' },
        give: { title: 'Donner à', item: 'Objet (nom technique)', quantity: 'Quantité', confirm: 'Donner' },
        inventory: { title: (label) => `Inventaire ${of(label)}`, empty: 'Inventaire vide.', close: 'Fermer' },
      },
      done: { message: 'Message envoyé.', warn: 'Avertissement inscrit.', move: 'Déplacé.', heal: 'Soigné.', feed: 'Nourri.',
        freeze: 'Immobilisé.', unfreeze: 'Libéré.', kick: 'Expulsé.', ban: 'Ban scellé.', give: 'Objet donné.' },
      percent: (value) => `${Math.round(value)} %`,
      ms: (value) => `${value} ms`,
    },

    banDuration: (hours) => {
      if (hours === 0) return 'Définitif';
      if (hours % 24 === 0) return `${hours / 24} jour${hours / 24 > 1 ? 's' : ''}`;
      return `${hours} heure${hours > 1 ? 's' : ''}`;
    },

    reports: {
      title: 'Signalements',
      empty: 'Aucun signalement en attente.',
      columns: ['N°', 'De', 'Message', 'Reçu', 'Suivi', ''],
      ago: (ms) => `il y a ${duration(ms)}`,
      open: 'En attente',
      claimedBy: (label) => `Pris en charge par ${label}`,
      claim: 'Prendre en charge',
      close: 'Clore',
      arrived: (author) => `Nouveau signalement de ${author}.`,
    },

    bans: {
      title: 'Sanctions',
      empty: 'Aucun ban en cours.',
      columns: ['N°', 'Banni', 'Motif', 'Prononcé', 'Fin', 'Par', ''],
      forever: 'Définitif',
      lift: 'Lever',
      liftTitle: 'Lever le ban',
      liftText: (label) => `Lever tous les bans de ${label} ?`,
    },

    logs: {
      title: 'Journal du Conseil',
      empty: 'Le journal est vierge.',
      columns: ['Date', 'Auteur', 'Action', 'Cible', 'Détails'],
      labels: {
        reach: 'a rejoint', bring: 'a amené', sendBack: 'a renvoyé', freeze: 'a immobilisé', heal: 'a soigné', feed: 'a nourri',
        message: 'a écrit à', warn: 'a averti', kick: 'a expulsé', ban: 'a banni', unban: 'a levé le ban de',
        inventory: 'a fouillé', give: 'a donné à', spectate: 'a observé', staffGrant: 'a nommé', staffRevoke: 'a révoqué',
        announce: 'a proclamé', tool: 'a utilisé un outil', reportClaim: 'a pris en charge', reportClose: 'a clos le signalement de',
        moveToPlayer: 'a déplacé', moveToCoords: 'a déplacé', inventoryView: 'a consulté l\'inventaire de',
        watchScreen: 'a regardé l\'écran de',
      },
    },

    council: {
      title: 'Membres du Conseil',
      empty: 'Le Conseil ne compte aucun membre.',
      columns: ['Membre', 'Rang', 'En jeu', ''],
      offline: 'Absent',
      online: (source) => `oui (n° ${source})`,
      revoke: 'Révoquer',
      revokeTitle: 'Révoquer',
      revokeText: (label) => `Retirer ${label} du Conseil ?`,
      appoint: 'Nommer un membre',
      appointTitle: 'Nommer au Conseil',
      accountField: 'Numéro de compte du joueur',
      accountHelp: 'Lisible dans la fiche du joueur (page Joueurs).',
      rankField: 'Rang',
      confirm: 'Nommer',
    },

    announce: {
      title: 'Proclamation',
      label: 'Texte de la proclamation',
      hint: 'Lue par tout le royaume, en haut de l\'écran de chaque joueur.',
      send: 'Proclamer',
      sent: 'Proclamation envoyée.',
      confirmTitle: 'Proclamer à tout le royaume ?',
    },

    zones: {
      title: 'Zones de voix',
      empty: 'Aucune zone de voix.',
      hint: 'Les zones se créent en jeu (Registre du Conseil, outil « Zones de voix ») : elles se centrent sur la personne qui les crée.',
      columns: ['Nom', 'Effet', 'Rayon', 'Hauteur', 'Centre', ''],
      edit: 'Modifier',
      remove: 'Supprimer',
      save: 'Sceller',
      editTitle: 'Modifier la zone',
      name: 'Nom du lieu',
      radius: 'Rayon (m)',
      height: 'Hauteur (m)',
      effect: 'Effet sur la voix',
      effects: { 0.5: '×0,5 très feutrée', 0.75: '×0,75 feutrée', 1: '×1 normale', 1.5: '×1,5 porte un peu', 2: '×2 porte loin', 3: '×3 porte très loin' },
      removeTitle: 'Supprimer la zone',
      removeText: (label) => `Supprimer la zone « ${label} » ?`,
      saved: 'Zone enregistrée.',
      removed: 'Zone supprimée.',
      meters: (value) => `${value} m`,
    },

    accounts: {
      title: 'Comptes de la Chancellerie',
      columns: ['Compte', 'Droits du panneau', 'Rang du Conseil', 'Créé le', ''],
      master: 'Compte maître',
      none: 'aucun',
      create: 'Créer un compte',
      createTitle: 'Nouveau compte',
      editTitle: 'Droits du compte',
      passwordTitle: 'Nouveau mot de passe pour',
      deleteTitle: 'Supprimer le compte',
      deleteText: (name) => `Supprimer le compte ${name} ? Ses sessions ouvertes se ferment.`,
      name: 'Identifiant',
      password: 'Mot de passe (10 caractères au moins)',
      permissions: 'Droits du panneau',
      permissionLabels: { server: 'Démarrer et arrêter le serveur', console: 'Lire la console et y écrire', config: 'Configurer le serveur' },
      rank: 'Rang du Conseil (administration du royaume)',
      noRank: 'Aucun',
      ranksStale: 'Rangs lus au dernier démarrage du serveur de jeu.',
      edit: 'Droits',
      setPassword: 'Mot de passe',
      remove: 'Supprimer',
      created: 'Compte créé.',
      updated: 'Compte modifié.',
      removed: 'Compte supprimé.',
      passwordSet: 'Mot de passe changé.',
      mineTitle: 'Mon mot de passe',
      current: 'Mot de passe actuel',
      fresh: 'Nouveau mot de passe',
      again: 'Nouveau mot de passe, encore',
      change: 'Changer',
      mismatch: 'Les deux mots de passe ne sont pas identiques.',
    },

    camera: {
      title: (label) => `Écran ${of(label)}`,
      connecting: 'Connexion au jeu du joueur…',
      waiting: 'Le jeu du joueur prépare l\'image…',
      live: 'En direct',
      stop: 'Fermer',
      ended: {
        stopped: 'Caméra fermée.', dropped: 'Le joueur a quitté le serveur.', expired: 'Durée maximale atteinte.',
        capture_failed: 'Le jeu du joueur n\'a pas pu filmer son écran.', unsupported: 'Le jeu du joueur ne permet pas la caméra.',
        connection_failed: 'La connexion directe avec le joueur a échoué (réseau, pare-feu).', closed: 'La connexion s\'est fermée.',
        server_stopped: 'Le serveur de jeu s\'est arrêté.', left_game: 'Le joueur n\'est plus en jeu (sélection de personnage ou départ).',
        no_answer: 'Pas de réponse à temps.',
      },
      privacy: 'Le joueur n\'est pas prévenu : ce regard est inscrit au journal du Conseil.',
    },

    cameras: {
      title: 'Mur des caméras',
      count: (n) => (n === 0 ? 'Aucun joueur connecté' : plural(n, 'joueur connecté', 'joueurs connectés')),
      layout: (n) => `Disposition ${n} × ${n}`,
      page: (current, total) => `Page ${current} / ${total}`,
      previousPage: 'Page précédente',
      nextPage: 'Page suivante',
      previousPlayer: 'Joueur précédent',
      nextPlayer: 'Joueur suivant',
      back: 'Retour au mur',
      number: (source) => `n° ${source}`,
      empty: 'Aucun joueur à regarder pour l\'instant.',
      connecting: 'Ouverture de la caméra…',
      hint: 'Un clic sur un écran l\'ouvre en grand · Flèches : pages · 1 à 4 : disposition',
      focusHint: 'Flèches : joueur précédent ou suivant · Échap : retour au mur',
      privacy: 'Les joueurs ne sont pas prévenus : l\'ouverture du mur et chaque vue en grand sont inscrites au journal du Conseil.',
      status: {
        not_playing: 'En sélection de personnage', too_many_viewers: 'Déjà regardé par six membres', too_many_cameras: 'Trop de caméras ouvertes',
        forbidden: 'Droit refusé', dropped: 'Joueur parti', left_game: 'Plus en jeu', connection_failed: 'Connexion perdue',
        no_answer: 'Pas de réponse du joueur', capture_failed: 'Capture impossible', unsupported: 'Jeu du joueur incompatible',
        expired: 'Caméra expirée', closed: 'Caméra fermée', stopped: 'Caméra fermée', server_stopped: 'Serveur de jeu arrêté',
        rate_limited: 'Trop de demandes, nouvel essai bientôt', unavailable: 'Image indisponible',
      },
    },

    server: {
      start: 'Démarrer', stop: 'Arrêter', restart: 'Redémarrer',
      stopTitle: 'Arrêter le serveur ?',
      stopText: 'Les personnages sont sauvegardés, puis les joueurs connectés sont déconnectés.',
      restartTitle: 'Redémarrer le serveur ?',
      restartText: 'Les personnages sont sauvegardés, les joueurs déconnectés, puis le serveur se relance.',
      cancel: 'Annuler',
      since: (ms) => `depuis ${duration(ms)}`,
      relaunchIn: (ms) => `relance dans ${duration(ms)}`,
      relaunchStopped: 'relance automatique suspendue',
      starting: 'Démarrage demandé.',
      stopping: 'Arrêt demandé : sauvegarde des personnages.',
      restarting: 'Redémarrage demandé.',
      notConfigured: 'à configurer',
    },

    dashboard: {
      title: 'Tableau de bord',
      players: 'Joueurs',
      uptime: 'En marche depuis',
      crashes: 'Arrêts imprévus',
      crashesHelp: 'ces dernières minutes',
      port: 'Port',
      playersTitle: 'Joueurs connectés',
      noPlayers: 'Personne n\'est connecté.',
      playersUnknown: 'Le serveur ne répond pas encore à la liste des joueurs.',
      offline: 'Le serveur est arrêté.',
      id: 'N°', name: 'Nom', ping: 'Latence',
      journalTitle: 'Journal de la Chancellerie',
      noJournal: 'Rien n\'est encore inscrit.',
      setupTitle: 'Le serveur n\'est pas encore configuré',
      setupText: 'L\'assistant pose quelques questions (dossiers, nom, clé de licence, base de données, ressources), écrit le server.cfg et lance le serveur.',
      setupButton: 'Ouvrir l\'assistant',
      ms: (value) => `${value} ms`,
    },

    console: {
      title: 'Console',
      placeholder: 'Commande du serveur (ex. : status, restart vava_hud)…',
      send: 'Envoyer',
      follow: 'Suivre les nouvelles lignes',
      empty: 'La console est vide : le serveur n\'a encore rien écrit.',
      offline: 'Serveur arrêté : la console reprendra au prochain démarrage.',
      denied: 'Ce compte ne peut pas lire la console.',
    },

    wizard: {
      title: 'Configuration du serveur',
      steps: ['Dossiers', 'Identité', 'Licence', 'Base', 'Ressources', 'Sceau'],
      previous: 'Précédent',
      next: 'Suivant',
      checking: 'Vérification…',
      pathsIntro: 'Où se trouve le serveur ? Le dossier du serveur est celui qui contient « resources » (et où le server.cfg sera écrit). FXServer.exe est le programme du serveur, téléchargé depuis les artefacts de FiveM.',
      pathsRunning: 'Le serveur tourne : arrêtez-le pour changer de dossiers.',
      serverDataPath: 'Dossier du serveur',
      serverDataPathHelp: 'Exemple : D:\\MonServeur — il doit contenir le dossier resources.',
      fxserverPath: 'Chemin de FXServer.exe',
      fxserverPathHelp: 'Exemple : D:\\fivemserver\\FXServer.exe',
      cfgFound: 'Un server.cfg existe déjà dans ce dossier : ses valeurs sont reprises, et l\'ancien fichier sera sauvegardé avant d\'être remplacé.',
      cfgNew: 'Aucun server.cfg dans ce dossier : il sera créé.',
      identityIntro: 'Ce que voient les joueurs dans la liste des serveurs.',
      hostname: 'Nom du serveur',
      projectName: 'Nom du projet',
      projectNameHelp: 'Facultatif : titre court dans la liste des serveurs.',
      projectDesc: 'Description',
      maxClients: 'Places',
      maxClientsHelp: 'Au-delà de 48, une clé de licence d\'un niveau supérieur est demandée par Cfx.re.',
      listed: 'Afficher le serveur dans la liste publique de FiveM',
      listedHelp: 'Décochez pour un serveur privé ou de test.',
      licenseIntro: 'La clé de licence se crée gratuitement sur portal.cfx.re (« Server Registration Keys »). Elle reste dans le server.cfg et n\'est jamais réaffichée ici.',
      licenseKey: 'Clé de licence',
      licenseKeySet: 'Clé déjà renseignée : laissez vide pour la garder.',
      licenseKeyPlaceholder: 'cfxk_…',
      bind: 'Adresse d\'écoute',
      bindHelp: '0.0.0.0 : toutes les cartes réseau de la machine.',
      port: 'Port du jeu',
      portHelp: '30120 par défaut. Le port doit être ouvert (TCP et UDP) sur la box et le pare-feu.',
      onesync: 'OneSync',
      onesyncOptions: { on: 'Activé (recommandé, requis par vAvA)', legacy: 'Ancien mode', off: 'Désactivé' },
      endpointPrivacy: 'Masquer les adresses IP des joueurs dans les informations publiques du serveur',
      dbIntro: 'vAvA garde comptes, personnages et inventaires dans MySQL ou MariaDB, par oxmysql. Le mot de passe reste dans le server.cfg.',
      dbHost: 'Hôte',
      dbPort: 'Port',
      dbUser: 'Utilisateur',
      dbPassword: 'Mot de passe',
      dbPasswordSet: 'Mot de passe déjà renseigné : laissez vide pour le garder.',
      dbDatabase: 'Nom de la base',
      dbCheck: 'Tester l\'adresse',
      dbChecking: 'Interrogation…',
      dbAnswer: (version) => `La base répond : ${version}. Les identifiants seront vérifiés par oxmysql au démarrage.`,
      resourcesIntro: 'Cochez les ressources à lancer. Celles de vAvA démarrent dans l\'ordre qu\'elles attendent ; les autres ensuite, dans l\'ordre de la liste.',
      resourcesEmpty: 'Aucune ressource trouvée dans le dossier resources.',
      resourceMissing: 'Introuvable dans le dossier resources',
      uncategorized: 'Sans catégorie',
      extra: 'Options avancées du server.cfg',
      extraHelp: 'Lignes reprises telles quelles (convars, permissions…). Les réglages des étapes précédentes n\'ont rien à y faire : ils y seraient ignorés.',
      summaryIntro: 'Relisez avant de sceller : le server.cfg sera écrit (l\'ancien est sauvegardé dans data/backups de la Chancellerie).',
      summaryResources: (count) => plural(count, 'ressource', 'ressources'),
      licenseYes: 'renseignée',
      licenseNo: 'manquante',
      passwordYes: 'renseigné',
      passwordNo: 'aucun',
      listedYes: 'publique',
      listedNo: 'privée (hors liste)',
      seal: 'Sceller et lancer le serveur',
      sealOnly: 'Sceller le server.cfg',
      saved: 'Le server.cfg est écrit.',
      savedRestart: 'Le server.cfg est écrit : redémarrez le serveur pour l\'appliquer.',
      summary: {
        folder: 'Dossier', executable: 'FXServer', hostname: 'Nom', slots: 'Places', listing: 'Liste', endpoint: 'Écoute',
        onesync: 'OneSync', license: 'Clé de licence', database: 'Base de données', password: 'Mot de passe', resources: 'Ressources',
      },
    },
  };
})();
