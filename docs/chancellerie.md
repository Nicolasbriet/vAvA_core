# La Chancellerie — panneau web du serveur

La Chancellerie est le panneau web de vAvA, dans l'esprit de txAdmin. C'est un programme Node.js autonome, sans
dépendance, qui installe, lance et surveille FXServer. Elle n'est **pas** une ressource FiveM : elle tourne à côté du
serveur et le lance elle-même.

> Livré : premier lancement, compte maître, connexion, assistant de configuration, démarrage / arrêt / redémarrage,
> relance après plantage, console en direct, tableau de bord ; comptes avec droits et rang du Conseil ; toute
> l'administration du royaume depuis le web (par le pont `vava_chancellerie`) et caméras sur l'écran des joueurs.
> À venir : gestion des ressources, édition du server.cfg et sauvegardes, redémarrages planifiés.

## Installation

1. Installez [Node.js](https://nodejs.org/) (version LTS, 18 ou plus récente), ou posez `node.exe` à côté de
   `demarrer.bat`.
2. Copiez le dossier `chancellerie/` dans le dossier du serveur (celui qui contient `resources/`), à côté de
   `resources/` ou dedans.
3. Arrêtez txAdmin s'il tourne : les deux se disputeraient le port 40120 et le serveur.
4. Lancez `demarrer.bat`.

La fenêtre affiche :

```
  ══════════════════════════════════════════════════════════════
     La Chancellerie  ·  panneau du serveur vAvA  ·  v1.0.0
  ══════════════════════════════════════════════════════════════
     Ouvrez dans votre navigateur :  http://127.0.0.1:40120/

  ── Premier lancement ──
     Code d'accès :  123 456
```

## Premier lancement

1. Ouvrez le lien, saisissez le **code d'accès** de la fenêtre, puis créez le **compte maître** (identifiant et mot de
   passe d'au moins 10 caractères). Le code ne sert qu'une fois : il disparaît dès que le compte existe. Après cinq
   erreurs, un nouveau code est tiré et affiché.
2. L'**assistant** pose ses questions en six étapes :
   - **Dossiers** : le dossier du serveur (deviné s'il contient `resources/`) et le chemin de `FXServer.exe`.
   - **Identité** : nom affiché, nom de projet, description, places, présence dans la liste publique.
   - **Licence** : clé `cfxk_…` (portal.cfx.re), adresse et port d'écoute, OneSync.
   - **Base** : hôte, port, utilisateur, mot de passe et nom de la base d'oxmysql. Le bouton « Tester l'adresse » vérifie
     que MySQL / MariaDB répond (sans envoyer d'identifiants).
   - **Ressources** : cases à cocher (catégories `[…]` comprises) et options avancées (lignes libres du server.cfg).
   - **Sceau** : relecture, puis écriture du `server.cfg` et lancement du serveur.
3. Un `server.cfg` déjà présent est **repris** : ses valeurs remplissent l'assistant, ses lignes inconnues deviennent les
   options avancées, et l'ancien fichier est sauvegardé dans `chancellerie/data/backups/` (les 20 derniers).

Les ressources de vAvA sont écrites dans l'ordre qu'elles attendent (`oxmysql`, `vAvA_core`, `vava_appearance`,
`vava_characters_ui`, `vava_hud`, `vava_inventory`, `vava_needs`, `vava_health`, `vava_admin`), les autres ensuite.

## Au quotidien

- **Tableau** : état du serveur (sceau vert en marche, ambre au démarrage ou à l'arrêt, gris à l'arrêt, rouge planté),
  joueurs connectés, durée de fonctionnement, arrêts imprévus récents, journal de la Chancellerie.
- **Console** : la console de FXServer en direct, avec ses couleurs. Les commandes saisies partent sur le serveur ; flèches
  haut et bas pour l'historique. `quit` est refusé : le bouton « Arrêter » sauvegarde d'abord les personnages.
- **Arrêter / Redémarrer** : `vava_saveall`, attente, puis `quit`. Si FXServer ne répond pas en 20 secondes, il est
  arrêté de force (lui et son gestionnaire de plantage).
- **Plantage** : FXServer est relancé après 5 secondes. Au-delà de 3 arrêts imprévus en 2 minutes, la relance est
  suspendue ; un lancement à la main remet le compte à zéro.
- **Fermer la Chancellerie** : Ctrl+C (ou fermer la fenêtre) arrête d'abord FXServer proprement. Un second Ctrl+C
  quitte immédiatement. Si la Chancellerie est tuée brutalement, le FXServer resté seul est retrouvé et arrêté au
  lancement suivant.
- Une fois configurée, la Chancellerie relance FXServer à chaque démarrage (`autoStart`).

## Comptes

Page **Comptes** (compte maître) : créer un compte (identifiant, mot de passe), lui donner des droits sur le panneau
(démarrer et arrêter le serveur, lire et écrire la console, configurer le serveur) et un **rang du Conseil** (gardien,
sénéchal, souverain : mêmes droits qu'en jeu, pour administrer le royaume depuis le web), lui remettre un mot de passe
ou le supprimer. Chacun y change son propre mot de passe (l'ancien est demandé). Un mot de passe changé ou un compte
supprimé ferme ses autres sessions. Le compte maître a tous les droits du panneau et le rang de souverain.

## Le royaume depuis le web

Pour les comptes qui ont un rang du Conseil, quand le serveur de jeu tourne avec la ressource `vava_chancellerie`
(`ensure vava_chancellerie` après `vava_admin`, `vava_voice` et `vava_cameras`) :

- **Joueurs** : liste en direct, fiche (vie, faim, soif, position, avertissements) et actions : écrire, avertir, envoyer
  vers un joueur ou un lieu, renvoyer, soigner, nourrir, immobiliser, expulser, bannir, voir l'inventaire, donner un
  objet, **regarder l'écran**.
- **Signalements** (en direct), **Sanctions** (bans, levée), **Journal du Conseil**, **Conseil** (nommer, changer de
  rang, révoquer), **Proclamation**, **Zones de voix** (modifier, supprimer ; la création reste en jeu, car une zone se
  centre sur la personne qui la crée), **Caméras** (le mur de l'écran des joueurs connectés).
- Restent en jeu : vol libre, invisibilité, invulnérabilité, repère, rejoindre et amener à soi (ils supposent un
  personnage dans le monde).
- Chaque action passe par le Registre du Conseil, qui vérifie le droit du rang, la cible et son rang, et l'inscrit au
  journal au nom de « Chancellerie : <compte> ».

**Caméras** (module `vava_cameras`) : tout membre du Conseil regarde tout le monde, sans règle de rang.
- La page **Caméras** est un mur de l'écran de tous les joueurs connectés : 1 × 1, 2 × 2, 3 × 3 ou 4 × 4 (touches 1 à 4,
  disposition retenue par le navigateur), par pages (flèches). Un clic ouvre un écran en grand ; les flèches passent au
  joueur précédent ou suivant, Échap revient au mur. Un joueur en sélection de personnage est signalé, sans caméra.
- Seuls les écrans de la page affichée sont ouverts, en qualité réduite (480 × 270, 10 images/s) ; en grand, les cases
  se ferment et seule la vue en grand reste (960 × 540, 20 images/s). Quitter la page ou fermer l'onglet éteint tout.
- « Regarder l'écran », sur la fiche d'un joueur, ouvre la même vue en grand dans une fenêtre.
- L'image arrive en WebRTC direct du jeu du joueur au navigateur (sans son, ni ses autres fenêtres) : elle ne passe ni
  par la Chancellerie ni par le serveur de jeu, qui ne relaient que la mise en relation (quelques Ko par caméra).
- Le joueur n'est pas prévenu : mentionnez-le dans le règlement. L'ouverture du mur et chaque vue en grand sont
  inscrites au journal du Conseil.
- Le WebRTC direct révèle l'adresse IP du joueur au navigateur qui regarde. L'adresse STUN, utile entre deux réseaux,
  se règle dans `vava_cameras/config.lua` (celle de Google par défaut) ; derrière certains pare-feux, la connexion
  directe échoue.

## Sécurité

- Écoute sur `127.0.0.1` seulement : le panneau n'est joignable que depuis la machine. Pour y accéder à distance,
  passez par un tunnel ou un proxy HTTPS (et mettez `http.secureCookies` à `true`).
- Mots de passe dérivés par scrypt avec sel ; jamais stockés ni journalisés en clair. Sessions en mémoire (12 h
  d'inactivité, 7 jours au plus), cookie `HttpOnly`, `SameSite=Strict`.
- Toute requête qui modifie quelque chose exige l'en-tête `x-chancellerie` et une origine identique ; le nom d'hôte est
  vérifié (protection contre le rebond DNS). Connexion et code d'accès limités en débit.
- La clé de licence et le mot de passe de la base ne quittent jamais le `server.cfg` : l'interface sait seulement
  s'ils sont renseignés, et un champ laissé vide garde la valeur en place. Une clé ou un mot de passe affiché par une
  commande est masqué dans la console (`cfxk_••••`, `mysql://utilisateur:••••@…`).
- Les valeurs écrites dans le `server.cfg` sont nettoyées (guillemets et retours à la ligne retirés) : un nom de
  serveur ne peut pas glisser de commande.
- Le journal (`data/journal.log`) n'enregistre aucune adresse IP.
- Les options avancées du `server.cfg` sont visibles par les comptes qui ont le droit « configuration » : n'y laissez
  pas d'autre secret que ceux que vous leur confiez.
- Le pont du serveur de jeu n'accepte que les requêtes de la machine portant la clé tirée à chaque lancement de
  FXServer (passée en `+set`, jamais écrite dans le `server.cfg`, masquée dans la console) ; les évènements qu'il envoie
  à la Chancellerie sont vérifiés de la même façon.

## Fichiers

| Fichier | Contenu |
|---|---|
| `demarrer.bat` | lanceur Windows |
| `index.js` | lancement, bannière, arrêt propre |
| `lib/config.js` | emplacements et réglages (`data/config.json`) |
| `lib/accounts.js` · `sessions.js` · `pin.js` | comptes, sessions, code du premier lancement |
| `lib/security.js` · `http.js` · `routes.js` · `events.js` | serveur web, API, flux en direct |
| `lib/process.js` | FXServer : lancement, console, arrêt, relance |
| `lib/servercfg.js` · `resources.js` · `dbprobe.js` · `status.js` | server.cfg, ressources, base, joueurs |
| `lib/bridge.js` · `camera.js` · `routes-game.js` | pont du serveur de jeu, caméras, royaume |
| `lib/routes-accounts.js` | comptes du panneau |
| `web/` | l'interface |
| `data/` | données locales (comptes, réglages, journal, sauvegardes) — à ne jamais partager |

Réglages de `data/config.json` (créé au premier lancement) :

| Clé | Défaut | Rôle |
|---|---|---|
| `http.host` / `http.port` | `127.0.0.1` / `40120` | adresse du panneau (`0.0.0.0` pour toutes les cartes réseau) |
| `http.secureCookies` | `false` | cookie réservé à HTTPS (derrière un proxy) |
| `autoStart` | `true` | lancer FXServer au démarrage de la Chancellerie |
| `process.restartDelayMs` | `5000` | attente avant de relancer après un plantage |
| `process.maxCrashes` / `crashWindowMs` | `3` / `120000` | plantages tolérés dans la fenêtre |
| `process.saveCommand` / `saveWaitMs` | `vava_saveall` / `3000` | sauvegarde avant arrêt |
| `process.stopTimeoutMs` | `20000` | délai avant arrêt forcé |
| `process.runningAfterMs` | `30000` | « en marche » sans la ligne Cfx.re Nucleus |
| `process.consoleLines` | `3000` | lignes de console gardées |
| `game.ranks` | (lu du pont) | rangs du Conseil gardés pour le formulaire des comptes, serveur arrêté |

## API (pour les étapes suivantes)

Toutes les réponses sont `{ ok, error?, … }`. Les `POST` demandent `x-chancellerie: 1` et un corps JSON.

| Route | Droit | Rôle |
|---|---|---|
| `GET /api/state` | — | phase (`pin`, `login`, `ready`), compte, configuration faite |
| `POST /api/setup/master` | code | `{ pin, name, password }` |
| `POST /api/login` · `/api/logout` | — · connecté | `{ name, password }` |
| `GET /api/assistant` | config | valeurs du server.cfg (sans secrets), ressources trouvées |
| `POST /api/assistant/paths` | config | `{ serverDataPath, fxserverPath }` |
| `POST /api/assistant/dbcheck` | config | `{ host, port }` → `{ version }` |
| `POST /api/assistant/save` | config | `{ form, start }` → `{ backup, started, restartNeeded }` |
| `GET /api/server` | connecté | état, joueurs (`id`, `name`, `ping`), nom, places, port |
| `POST /api/server/start` · `stop` · `restart` | server | |
| `GET /api/events` | connecté | flux : `state`, `history` et `line` (droit console), `report` et `players` (rang du Conseil), `camera` (session qui regarde) |
| `POST /api/console/command` | console | `{ command }` |
| `GET /api/journal` | connecté | 50 dernières inscriptions |
| `GET /api/accounts` · `POST /api/accounts/create` · `update` · `password` · `delete` | compte maître | comptes du panneau |
| `POST /api/account/password` | connecté | `{ current, password }` son propre mot de passe |
| `POST /api/game/request` | rang du Conseil | `{ name, args }` demande au Registre (liste fermée) → `{ result }` |
| `GET /api/game/ranks` | connecté | rangs du Conseil (`live` : lus à l'instant) |
| `POST /api/game/cameras/wall` · `players` | rang du Conseil | joueurs du mur `{ source, label, active }` ; `wall` inscrit l'ouverture au journal |
| `POST /api/game/camera/start` · `answer` · `stop` | rang du Conseil | `{ target, quality = tile\|full }` → `{ session, label, iceServers }` ; 17 caméras par onglet au plus (un mur 4 × 4 et une vue en grand) |
| `POST /api/bridge/event` | pont (machine et clé) | évènements du serveur de jeu |
