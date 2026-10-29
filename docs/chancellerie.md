# La Chancellerie — panneau web du serveur

La Chancellerie est le panneau web de vAvA, dans l'esprit de txAdmin. C'est un programme Node.js autonome, sans
dépendance, qui installe, lance et surveille FXServer. Elle n'est **pas** une ressource FiveM : elle tourne à côté du
serveur et le lance elle-même.

> Livré : premier lancement, compte maître, connexion, assistant de configuration, démarrage / arrêt / redémarrage,
> relance après plantage, console en direct, tableau de bord ; comptes avec droits et rang du Conseil ; toute
> l'administration du royaume depuis le web (par le pont `vava_chancellerie`) et caméras sur l'écran des joueurs ;
> performances (processeur, mémoire, bande passante, joueurs, ticks) ; gestion des ressources ; éditeur du
> server.cfg ; sauvegardes du server.cfg et de la base de données ; redémarrages et sauvegardes planifiés ;
> installation complète du serveur (FXServer, oxmysql, vAvA) et mises à jour depuis GitHub, la Chancellerie comprise.

## Installation

Seule la Chancellerie s'installe à la main ; elle installe ensuite le reste (FXServer, oxmysql, vAvA).
Chez un hébergeur (à la place de txAdmin, VPS ou panel de jeu) : voir [docs/hebergeur.md](hebergeur.md).

### Serveur Linux (Debian, Ubuntu…)

1. Ce qu'il faut sur la machine : `curl` (ou `wget`), `tar` et `xz` (l'archive de FXServer est en `.tar.xz`), et
   MariaDB, le seul logiciel que la Chancellerie n'installe pas :

   ```sh
   sudo apt install curl xz-utils mariadb-server mariadb-client
   ```

   Créez un utilisateur MariaDB pour vAvA (ou gardez `root`) ; la base elle-même se crée depuis l'assistant.

2. Récupérez seulement la Chancellerie (sans git : une copie suivie par git ne se met pas à jour seule), dans le dossier
   qui accueillera le serveur, par exemple `/opt/vava` :

   ```sh
   sudo mkdir -p /opt/vava && sudo chown "$USER": /opt/vava && cd /opt/vava
   curl -L https://github.com/Nicolasbriet/vAvA_core/archive/refs/heads/main.tar.gz \
     | tar -xz --strip-components=1 vAvA_core-main/chancellerie
   ```

3. Lancez-la : `bash chancellerie/demarrer.sh`. Sans Node.js 22 ou plus récent sur la machine, il le télécharge depuis
   nodejs.org (version LTS fixée dans le script, empreinte SHA-256 vérifiée) dans `chancellerie/node/`. Si le
   téléchargement échoue, un Node.js 18 à 21 déjà installé sert quand même, sans le bot Discord.

   Pour qu'elle tourne en permanence (lancée au démarrage de la machine, relancée si elle tombe), installez-la comme
   service systemd : `sudo bash chancellerie/demarrer.sh --service`. Son code d'accès et ses messages se lisent alors
   avec `journalctl -u vava-chancellerie -f` ; `sudo systemctl stop vava-chancellerie` l'arrête, FXServer compris,
   proprement (personnages sauvegardés).

4. Ouvrez le panneau depuis votre ordinateur. Il n'écoute que la machine elle-même (127.0.0.1) : le plus simple et le
   plus sûr est un tunnel SSH, puis `http://127.0.0.1:40120/` dans votre navigateur :

   ```sh
   ssh -L 40120:127.0.0.1:40120 utilisateur@adresse-du-serveur
   ```

   Pour l'ouvrir sans tunnel, mettez `http.host` à `"0.0.0.0"` dans `chancellerie/data/config.json` et placez-le
   derrière un proxy HTTPS (Caddy, nginx) avec `http.secureCookies` à `true` : sans HTTPS, les mots de passe passeraient
   en clair sur Internet.

5. Ouvrez le port du jeu dans le pare-feu, en TCP et UDP : `sudo ufw allow 30120` (jamais le port 40120 du panneau).

L'assistant propose par défaut d'installer le serveur à côté de la Chancellerie : `/opt/vava/server` (FXServer,
`run.sh`) et `/opt/vava/server-data` (ressources, server.cfg).

### Windows

1. Copiez le dossier `chancellerie/` où vous voulez (par exemple `D:\vAvA\chancellerie`).
2. Arrêtez txAdmin s'il tourne : les deux se disputeraient le port 40120 et le serveur.
3. Lancez `demarrer.bat`. Sans Node.js 22 ou plus récent sur la machine, il le télécharge depuis nodejs.org (empreinte
   vérifiée) dans `node\node.exe`, à côté de lui ; le Node.js de la machine n'est pas touché. Si le téléchargement
   échoue, un Node.js plus ancien déjà installé sert quand même, sans le bot Discord.
4. Installez MariaDB ([mariadb.org](https://mariadb.org/), version LTS) si la machine n'en a pas.

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
   - **Installation**, deux possibilités :
     - **Nouveau serveur : tout installer** : choisissez un dossier (par défaut celui qui contient la Chancellerie).
       Elle y télécharge FXServer (build recommandée par Cfx.re) dans `server\`, crée `server-data\resources\`, y pose
       oxmysql (dernière version, `[standalone]`) et vAvA (dernière version du dépôt GitHub, `[vava]`). L'avancée se
       suit en direct ; ensuite l'assistant continue avec les dossiers posés.
     - **Serveur déjà en place** : le dossier du serveur (deviné s'il contient `resources/`) et le chemin de
       `FXServer.exe` ; la case « Installer ou compléter vAvA et oxmysql » pose ce qui manque et met à niveau ce qui est
       là, sans toucher à vos `config.lua` modifiés (voir Mises à jour).
   - **Identité** : nom affiché, nom de projet, description, places, présence dans la liste publique.
   - **Licence** : clé `cfxk_…` (portal.cfx.re), adresse et port d'écoute, OneSync.
   - **Base** : hôte, port, utilisateur, mot de passe et nom de la base d'oxmysql. Le bouton « Tester l'adresse » vérifie
     que MySQL / MariaDB répond (sans envoyer d'identifiants) ; « Créer la base » la crée si elle n'existe pas (utf8mb4),
     avec le client `mysql` livré avec MariaDB et MySQL. Les tables, elles, sont créées par vAvA à son démarrage.
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
- Le **tableau** montre aussi la charge de FXServer (processeur, mémoire), le débit réseau et le prochain redémarrage
  planifié.

## Performances

Un relevé toutes les 5 secondes (`metrics.intervalMs`), même serveur arrêté pour la machine :

- **Processeur** : celui de FXServer et celui de la machine, en part de la machine entière (100 % : tous les cœurs).
- **Mémoire de FXServer** (mémoire vive du processus) ; mémoire de la machine dans les chiffres du haut.
- **Bande passante** reçue et envoyée par toutes les cartes réseau actives de la machine (sur un serveur dédié,
  c'est surtout FXServer).
- **Joueurs connectés** (players.json).
- **Durée des ticks** des fils de FXServer (principal, réseau, synchronisation OneSync), lue dans son adresse
  `/perf/` comme le fait txAdmin : au-delà de 50 ms, le fil principal prend du retard. Absente si FXServer ne
  l'expose pas.
- **Fils de FXServer** les plus chargés au dernier relevé, en part d'un cœur (nom posé par FXServer, sinon son
  numéro) : un fil à 100 % sature son cœur, le serveur prend du retard même si le processeur global reste bas.

**Chez un hébergeur** (conteneur Docker, Pterodactyl, Podman…), Node voit la machine entière (la node) et non la part du
serveur : la Chancellerie lit alors les **cgroups** du conteneur (v2, ou v1 sur les machines anciennes) et tout est
rapporté à son allocation. Processeur du conteneur et de FXServer en part de cette allocation (100 % : toute
l'allocation, par exemple 4 cœurs) ; **bridé** : part du temps où le conteneur a buté sur son quota (le serveur
ralentit) ; mémoire du conteneur sur sa limite, comptée comme Docker et Pterodactyl (sans le cache de fichiers
inactif) ; bande passante des cartes du conteneur. Si l'hébergeur a **réservé des cœurs** au conteneur (champ
« Threads » de Pterodactyl), la charge de chacun s'affiche aussi. Hors conteneur, rien ne change.

La page **Performances** trace une courbe par mesure, sur la dernière heure (chaque relevé, en direct) ou sur 24 heures
(moyennes par minute, gardées dans `data/metrics.json` d'un lancement à l'autre) ; les mêmes relevés se lisent en
tableau. Sous Windows, un seul PowerShell reste ouvert à côté de la Chancellerie pour lire le processus, ses fils et le
réseau (il se ferme avec elle) ; sous Linux, tout se lit dans `/proc` et `/sys/fs/cgroup`.

**Joueurs** : FXServer ne donne les vrais joueurs de `players.json` (nom, numéro, latence) qu'à qui présente son jeton
`sv_playersToken` ; sans lui, chacun s'appelle « Player », numéro 0, latence 0. La Chancellerie tire un jeton à chaque
lancement et le passe à FXServer sur la ligne de commande (jamais dans le `server.cfg`, masqué dans la console). Si le
`server.cfg` fixe son propre `sv_playersToken`, c'est lui qu'elle utilise.

FiveM ne mesure pas côté serveur la consommation de chaque ressource : pour la trouver, la commande `profiler`
de la console de FXServer reste l'outil (`profiler record 500` puis `profiler view`).

## Ressources

La page **Ressources** liste le dossier `resources` par catégorie (`[…]`), avec la version, l'auteur et la
description de chaque manifeste, et les ressources lancées hors de ce dossier (celles du système de FXServer) :

- **État** sur le serveur en marche (lancée ou arrêtée, d'après `info.json`).
- **Démarrer**, **Redémarrer**, **Arrêter** (droit « serveur ») : les commandes `ensure`, `restart`, `stop` partent
  dans la console, précédées de `refresh` pour qu'une ressource ajoutée soit trouvée. Arrêter ou redémarrer
  `oxmysql`, `vAvA_core`, `vava_admin` ou `vava_chancellerie` demande confirmation.
- **Au démarrage** (droit « configuration ») : ajoute ou retire la ligne `ensure` du server.cfg, sans toucher au reste ;
  une ressource de vAvA prend sa place dans l'ordre attendu. Effet au prochain démarrage.
- **Relire le dossier** : `refresh`, après avoir déposé une ressource.

## server.cfg

La page **server.cfg** (droit « configuration ») ouvre le fichier brut. Les secrets n'arrivent jamais dans le
navigateur : la clé de licence, le mot de passe de la base, et toute valeur d'un réglage dont le nom finit par
`password`, `secret`, `token`, `apikey` (ou `rcon_password`, `steam_webApiKey`, `sv_tebexSecret`) sont remplacés par
`••••secret-1••••`, `••••secret-2••••`… La Chancellerie remet les vraies valeurs à l'enregistrement : laissez ces marques
telles quelles, ou remplacez-les par une nouvelle valeur. Le fichier est sauvegardé avant chaque écriture ; s'il a
changé depuis son ouverture (assistant, autre onglet, à la main), l'écriture est refusée et l'éditeur propose de le
recharger. Ctrl + S enregistre. L'assistant reste disponible et relit le fichier tel qu'il est.

## Sauvegardes

- **server.cfg** (droit « configuration ») : chaque écriture (assistant, éditeur, ressources) sauvegarde l'ancien
  fichier dans `data/backups/` (les 20 derniers). La page **Sauvegardes** les relit (sans leurs secrets) et les
  restaure (le fichier en place est sauvegardé d'abord).
- **Base de données** (droit « sauvegardes », qui donne accès à toutes les données des joueurs) : `mysqldump` (ou
  `mariadb-dump`) copie toute la base, compressée en `.sql.gz` dans `data/backups/db/`. L'outil est cherché seul (PATH,
  MariaDB, MySQL, XAMPP, Laragon, WampServer) ou désigné à la main. Identifiants lus dans le server.cfg et passés par un
  fichier d'options effacé aussitôt : jamais sur la ligne de commande. Une sauvegarde à la fois ; « Sauvegarder
  maintenant », heures quotidiennes planifiées, nombre gardé (14 par défaut, les plus anciennes effacées),
  téléchargement et suppression depuis la page.
- Restaurer la base reste un geste manuel : arrêter le serveur, décompresser le fichier, l'importer (HeidiSQL, ou
  `mysql -u utilisateur -p base < fichier.sql`).

## Planification

La page **Planification** (droit « serveur ») règle les **redémarrages quotidiens** (heures de la machine) :
personnages sauvegardés, joueurs déconnectés, relance. Les joueurs sont prévenus aux délais choisis (15, 5 et
1 minute par défaut) par une **proclamation** du Conseil au nom de la Chancellerie (il faut `vava_admin` et
`vava_chancellerie` lancés), avec le message choisi (`{minutes}` remplacé). Le prochain redémarrage peut être **sauté**
une fois. Un serveur arrêté n'est jamais lancé par un redémarrage planifié ; une échéance manquée de plus de 5 minutes
(machine en veille) est passée, pas rattrapée. Les sauvegardes planifiées de la base se règlent dans la page
Sauvegardes.

## Mises à jour

La Chancellerie suit le dépôt GitHub de vAvA (`updates.repo`, branche `main`) : chaque commit poussé est une nouvelle
version (ou seulement les releases publiées, au choix). Elle vérifie toutes les heures, et à la demande ; le tableau de
bord annonce une mise à jour disponible, et la page **Mises à jour** montre ce qui est installé (vAvA, Chancellerie,
oxmysql, FXServer), les changements arrivés depuis et les parties touchées.

Le compte maître l'applique (« Mettre à jour »), ou la laisse s'appliquer au prochain redémarrage planifié. Déroulé :

1. Téléchargement de la nouvelle version et comparaison, fichier par fichier, avec ce qui est installé.
2. Si la Chancellerie change : sa nouvelle version doit se charger, sinon tout s'arrête là, sans rien toucher.
3. Sauvegarde de la base (si mysqldump est là ; un échec arrête la mise à jour).
4. Joueurs prévenus par une proclamation, le délai choisi (tout de suite, 1, 5 ou 10 minutes), puis arrêt propre du
   serveur (personnages sauvegardés).
5. Sauvegarde des ressources qui vont changer (`data/updates/backups/`, les 3 dernières).
6. Écriture de la nouvelle version, qui garde ce que vous avez modifié :
   - un fichier que vous n'avez pas touché est remplacé ; un fichier supprimé en amont est retiré ;
   - un fichier que vous avez modifié et qui n'a pas changé en amont est gardé ;
   - un **réglage** (`config.lua`, dossier `config/`) modifié des deux côtés est gardé, et la nouvelle version posée à
     côté (`config.lua.nouveau`) pour que vous repreniez ses nouveautés ;
   - un autre fichier modifié des deux côtés prend la nouvelle version, la vôtre est gardée à côté (`.local`) ;
   - un nouveau module est posé dans `[vava]`, à activer dans la page Ressources. Le chat `vava_chat` remplace la
     ressource `chat` de FiveM : activer `vava_chat` et couper `chat` au même endroit ;
   - les exemples et outils de développement du dépôt (`examples/`) sont posés dans `[vava-dev]`, jamais lancés
     d'office : à activer seulement sur un serveur de test (ils n'ont aucun contrôle d'administration).
7. Relance du serveur, puis **contrôle** : en marche, sans arrêt imprévu, et toutes les ressources qui tournaient avant
   (et prévues au server.cfg) tournent encore. Sinon : **retour arrière** automatique (ressources remises à l'identique)
   et relance ; la page dit quelle ressource a échoué.

La Chancellerie se met à jour elle-même de la même façon : ses nouveaux fichiers remplacent les anciens (gardés dans
`data/updates/chancellerie-precedente`), puis elle redémarre (code 75, que `demarrer.sh` ou `demarrer.bat` relance) et
termine le contrôle du serveur. Si la nouvelle version s'arrête au démarrage, le lanceur remet l'ancienne et la
relance. `data/` et `node/` ne sont jamais touchés ; un nouveau lanceur est posé à côté (`demarrer.sh.nouveau`), celui en
cours ne pouvant se réécrire.

Une copie suivie par git (dossier de développement) n'est jamais écrasée, y compris une ressource posée par une jonction
ou un lien vers un dépôt (le vrai dossier est vérifié) : la page le signale, `git pull` reste l'outil.
Sur un serveur où vAvA a été posé à la main, la version installée est inconnue : la première mise à jour garde les
réglages qui diffèrent et remplace le reste ; les suivantes savent exactement ce qui a été modifié sur place.

## Comptes

Page **Comptes** (compte maître) : créer un compte (identifiant, mot de passe), lui donner des droits sur le panneau
(« serveur » : démarrer et arrêter le serveur et ses ressources, planifier les redémarrages ; « console » : la lire et
y écrire ; « configuration » : assistant, server.cfg et ses sauvegardes ; « sauvegardes » : celles de la base) et un
**rang du Conseil** (gardien,
sénéchal, souverain : mêmes droits qu'en jeu, pour administrer le royaume depuis le web), lui remettre un mot de passe
ou le supprimer. Chacun y change son propre mot de passe (l'ancien est demandé). Un mot de passe changé ou un compte
supprimé ferme ses autres sessions. Le compte maître a tous les droits du panneau et le rang de souverain.

### Relier un compte à son joueur

Chaque compte peut être relié à son joueur, et son **rang du Conseil s'applique alors aussi en jeu** :

1. Page **Comptes** → « Relier un joueur » : un code à 6 chiffres, valable 5 minutes, une seule fois (le maître peut en
   tirer un pour n'importe quel compte).
2. En jeu, console (touche F8) : `chancellerie 482913`. Le joueur est prévenu du résultat.
3. Le compte retient la license, l'identifiant `fivem:` et le numéro de compte vAvA du joueur. Une license ne se relie
   qu'à un seul compte ; après 5 codes faux, elle doit attendre.

Le panneau est la source du rang : il s'applique en jeu à la liaison, quand le maître change le rang, et à chaque
démarrage du serveur de jeu ; délier ou supprimer le compte retire le rang en jeu. Tout est inscrit au journal de la
Chancellerie et à celui du Conseil (« Chancellerie : <compte> »). Il faut `vava_admin` 1.3.0 et `vava_chancellerie`
1.2.0.

## Bot Discord

Page **Discord** (compte maître). Le bot se connecte lui-même à Discord (Gateway, sans droit privilégié) : rien à
ouvrir sur le serveur. Il demande Node.js 22 ou plus récent (celui que `demarrer.bat` et `demarrer.sh` installent).

- **Statut** : un message tenu à jour dans le salon choisi (chaque minute, à chaque changement d'état, arrivée ou départ
  de joueur) : en ligne ou non, joueurs, en ligne depuis, prochain redémarrage, boutons « Rejoindre » et « Discord ».
  Supprimé dans Discord, il est recréé.
- **Activité** : le statut personnalisé du bot dans la liste des membres suit le serveur, même sans salon de statut :
  « ⚔️ 12/48 dans le royaume » (pastille verte), « ⏳ Ouverture des portes… » ou « ⏳ Fermeture des portes… »
  (orange), « 🏰 Portes closes » (rouge). Envoyée à Discord seulement quand elle change.
- **Annonces** : serveur en ligne, arrêté, planté ; redémarrage planifié (aux délais des avertissements) ; mise à jour
  appliquée. Les nouveaux signalements vont au salon du staff.
- **Commandes slash** : `/statut` (public) et `/joueurs` pour tous ; `/lier <code>` relie son compte Discord à son
  compte de la Chancellerie (même code qu'en jeu, page Comptes ; une liaison faite en jeu retient aussi l'identifiant
  Discord du joueur) ; `/annonce`, `/avertir`, `/expulser`, `/bannir` pour le staff relié, au nom de son compte : le
  Registre du Conseil vérifie le droit de son rang et tient le journal.
- **Liste blanche** : à la connexion d'un joueur, le pont demande à la Chancellerie s'il a l'un des rôles choisis sur
  le serveur Discord (identifiant `discord:` du jeu) ; un joueur relié à un compte du panneau passe toujours. Refusé :
  il lit pourquoi (pas membre, avec l'invitation ; pas le rôle ; Discord fermé). Réponses gardées une minute.
  Discord injoignable : refusé, avec un message clair.

Bot absent du serveur Discord réglé (pas encore invité, invité ailleurs, ou mauvais identifiant) : la page Discord le
dit et liste les serveurs où il se trouve ; il ne tente alors ni commandes ni messages. Dès qu'il est invité sur le bon
serveur, il y enregistre ses commandes slash et reprend, sans relance. Une même erreur répétée n'est inscrite qu'une
fois au journal.

Créer le bot : discord.com/developers/applications → New Application → Bot → Reset Token (le jeton se colle dans la
page, il n'en ressort jamais) ; mode développeur de Discord pour copier les identifiants du serveur, des salons et des
rôles ; le lien « Inviter le bot » de la page l'ajoute au serveur Discord (droits : voir les salons, écrire, encarts,
historique). Il faut `vava_chancellerie` 1.2.0 pour la liste blanche.

## Le royaume depuis le web

Pour les comptes qui ont un rang du Conseil, quand le serveur de jeu tourne avec la ressource `vava_chancellerie`
(`ensure vava_chancellerie` après `vava_admin`, `vava_voice` et `vava_cameras`) :

- **Joueurs** : liste en direct (numéro de connexion, nom FiveM, personnage, rang, temps de jeu du personnage, latence,
  compte du panneau relié), fiche (vie, faim, soif, temps de jeu — compté par le serveur de jeu entre l'apparition et
  le déchargement du personnage, core 0.6.0 —, position, avertissements, **identifiants** : license, license2, fivem, discord, steam, xbl,
  live — lus à l'instant, jamais conservés, jamais l'adresse IP — à copier, avec le profil Steam ou Discord) et
  actions : écrire, avertir, envoyer vers un joueur ou un lieu, renvoyer, soigner, nourrir, immobiliser, expulser,
  bannir, voir l'inventaire, donner un objet, **regarder l'écran**.
- **Accès rapide** : le bouton « Joueurs en ligne » en tête de la colonne (avec leur nombre) ou la touche **J** ouvre
  la liste des joueurs depuis n'importe quelle page ; un clic ouvre la fiche. Les joueurs du tableau de bord ouvrent
  aussi leur fiche d'un clic. Le titre de l'onglet porte l'état du serveur : 🟢 en marche (avec le nombre de joueurs),
  🟠 au démarrage ou à l'arrêt, 🔴 arrêté.
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
| `demarrer.sh` | lanceur Linux (Node.js téléchargé s'il manque, relance après mise à jour, `--service` : service systemd) |
| `demarrer.bat` | lanceur Windows |
| `index.js` | lancement, bannière, arrêt propre |
| `lib/config.js` | emplacements et réglages (`data/config.json`) |
| `lib/accounts.js` · `sessions.js` · `pin.js` | comptes, sessions, code du premier lancement |
| `lib/security.js` · `http.js` · `routes.js` · `events.js` | serveur web, API, flux en direct |
| `lib/process.js` | FXServer : lancement, console, arrêt, relance |
| `lib/servercfg.js` · `resources.js` · `dbprobe.js` · `status.js` | server.cfg (et ses secrets masqués), ressources, base, joueurs, ressources lancées, ticks |
| `lib/system.js` · `metrics.js` | relevés de la machine et de FXServer, historiques des performances |
| `lib/backups.js` · `scheduler.js` | sauvegardes (server.cfg, base), redémarrages et sauvegardes planifiés |
| `lib/routes-ops.js` | performances, ressources, server.cfg brut, sauvegardes, planification |
| `lib/download.js` · `jobs.js` | téléchargements, extraction (tar de la machine), opération longue en cours |
| `lib/installer.js` · `updates.js` · `routes-updates.js` | installation, fusion des mises à jour, contrôle et retour arrière, mise à jour de la Chancellerie |
| `lib/bridge.js` · `camera.js` · `routes-game.js` | pont du serveur de jeu, caméras, royaume |
| `lib/routes-accounts.js` | comptes du panneau |
| `web/` | l'interface |
| `data/` | données locales (comptes, réglages, journal, performances, sauvegardes) — à ne jamais partager |

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
| `metrics.intervalMs` | `5000` | intervalle des relevés de performances |
| `schedule.restarts` / `warnings` / `message` | `[]` / `[15, 5, 1]` / `''` | redémarrages quotidiens, avertissements (minutes avant), message |
| `schedule.backups` | `[]` | heures des sauvegardes quotidiennes de la base |
| `schedule.skip` | `null` | échéance du redémarrage sauté une fois |
| `backups.dumpPath` / `keep` | `''` / `14` | mysqldump (vide : cherché seul), sauvegardes de la base gardées |
| `updates.repo` / `branch` | `Nicolasbriet/vAvA_core` / `main` | dépôt GitHub suivi |
| `updates.channel` | `commits` | `commits` : chaque commit de la branche ; `releases` : les releases publiées |
| `updates.autoCheck` / `checkEveryMin` | `true` / `60` | vérification à intervalle |
| `updates.applyAtRestart` | `false` | appliquer la mise à jour au redémarrage planifié |
| `discord.*` | désactivé | bot Discord : jeton, serveur, salons, liens, liste blanche (réglés depuis la page Discord) |

`data/install.json` retient ce qui est installé (version, empreinte de chaque fichier) : c'est lui qui permet de
distinguer vos modifications des changements en amont.

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
| `GET /api/metrics?range=hour\|day` | connecté | relevés (`samples`, `stepMs`), cœurs, dernier relevé ; flux : `metrics` à chaque relevé |
| `GET /api/resources` | connecté | ressources (`started`, `autostart`, version, auteur…), `live` |
| `POST /api/resources/action` | server | `{ name, action = start\|stop\|restart\|ensure }` |
| `POST /api/resources/refresh` | server | `refresh` dans la console |
| `POST /api/resources/autostart` | config | `{ name, enabled }` → ligne ensure du server.cfg |
| `GET /api/cfg` · `POST /api/cfg/save` | config | `{ text, revision, secrets }` · `{ text, revision }` → `{ backup, revision, restartNeeded }` |
| `GET /api/backups/cfg` · `GET /api/backups/cfg/view?name=` · `POST /api/backups/cfg/restore` | config | sauvegardes du server.cfg |
| `GET /api/backups/db` · `POST /api/backups/db/create` · `delete` · `settings` | backups | sauvegardes de la base ; flux : `backup` (début, fin) |
| `GET /api/backups/db/download?name=` | backups | le fichier `.sql.gz` en pièce jointe |
| `GET /api/schedule` | connecté | planification et prochaines échéances |
| `POST /api/schedule/restarts` · `skip` | server | `{ restarts, warnings, message }` · `{ skip }` |
| `GET /api/install/options` | config | dossier proposé, build recommandée de FXServer, dépôt |
| `POST /api/install/start` | config | `{ mode: 'new', base }` ou `{ mode: 'existing' }` (serveur arrêté) |
| `POST /api/assistant/dbcreate` | config | `{ host, port, user, password, database }` (mot de passe vide : celui du server.cfg) |
| `GET /api/jobs/current` | connecté | opération en cours ou dernière ; flux : `job` à chaque avancée |
| `GET /api/updates` · `POST /api/updates/check` | connecté | installé, dernière version, changements ; flux : `update` |
| `POST /api/updates/apply` · `settings` | compte maître | `{ backupDb, delayMin = 0\|1\|5\|10 }` · `{ channel, autoCheck, applyAtRestart }` |
| `POST /api/account/link` · `unlink` | connecté (soi) ou maître (`{ name }`) | code de liaison `{ code, expiresAt, ttlMs }` · délier ; flux : `linked` |
| `GET /api/links` | rang du Conseil | `[{ accountId, name }]` : comptes de jeu reliés à un compte du panneau |
| `GET /api/discord` · `POST /api/discord/settings` · `test` | compte maître | état du bot, lien d'invitation · réglages (jeton vide : gardé) · message d'essai |
| `POST /api/account/discord/unlink` | connecté (soi) ou maître (`{ name }`) | délie le compte Discord |
