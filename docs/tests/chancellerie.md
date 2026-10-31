# Chancellerie et pont — procédure de test en jeu

Procédure pour vérifier en jeu la Chancellerie 1.6.0 et `vava_chancellerie` 1.5.0 : **la clé du pont ne passe plus sur
la ligne de commande de FXServer** (elle est demandée par le pont dans la console et donnée par l'entrée de FXServer),
et **un rang du Conseil n'est donné qu'à un joueur que le pont a vu relié en jeu**. Comptez une demi-heure ; la
section 2 se joue avec un client FiveM. La section 3 vérifie la page **Réseau** (Chancellerie 1.8.0, pont 1.7.0 : le
compteur de `/vava_reseau` en lecture seule, liste des joueurs), un quart d'heure de plus avec trois clients FiveM. Un test se cite
« chancellerie 1-3 ». Préparation commune, mesure du resmon et
remontée des écarts : [LISEZMOI.md](LISEZMOI.md). Le reste du pont (actions du Conseil depuis le web, caméras, zones de
voix, ciel et heure) : `modules/vava_chancellerie/README.md`, « À vérifier en jeu », et [registre.md](registre.md).

## 0. Préparation

1. **Versions** : la Chancellerie **et** les ressources mises à jour ensemble (page Mises à jour, ou `git pull` sur une
   copie de développement puis **relancer la Chancellerie elle-même**, qui garde l'ancienne `lib/bridge.js` en mémoire
   tant qu'elle tourne). La bannière de la fenêtre de la Chancellerie dit `v1.6.0` ; la console du serveur dit
   `module 'vava_chancellerie' v1.5.0 prêt`.
2. **Migration** : au premier démarrage du pont 1.5.0, la table `vava_chancellerie_links` est créée
   (`SHOW TABLES LIKE 'vava_chancellerie_links';`).
3. **Un compte du panneau relié avant la mise à jour**, avec un rang (le maître, ou un compte Gardien), si vous en avez
   un : il sert au test 2-1. Notez son numéro de compte de jeu (`<N>`, page Joueurs → fiche, ou page Comptes).
4. La console du serveur est celle de la Chancellerie (page Console) ; la fenêtre de la Chancellerie elle-même, et
   `chancellerie/data/journal.log`, servent aux vérifications de la section 1.

## 1. La clé hors de la ligne de commande

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur depuis la Chancellerie, puis regarder la page Console. | Une ligne `en attente de la clé de la Chancellerie (vava_chancellerie:cle?)` (parfois deux), puis `clé de la Chancellerie reçue : pont ouvert` dans la seconde. Jamais `pont fermé`, jamais `la Chancellerie n'a pas donné la clé du pont`. |
| 2 | Lire la ligne de commande de FXServer. Windows (PowerShell) : `Get-CimInstance Win32_Process -Filter "name='FXServer.exe'" \| Select-Object -ExpandProperty CommandLine`. Linux : `ps -ef \| grep -i fxserver`, ou `tr '\0' ' ' < /proc/<pid>/cmdline`. | On y lit `+set vava_chancellerie_url http://127.0.0.1:40120`, `+exec server.cfg` (et le jeton `sv_playersToken`, hors de cette tâche). **Aucun** `vava_chancellerie_token`, aucune suite de 64 signes hexadécimaux appartenant au pont. |
| 3 | Page Console : chercher `vava_chancellerie_cle`. Puis dans `chancellerie/data/journal.log`. | Console : rien, ou seulement `vava_chancellerie_cle ••••` si FXServer réaffiche les commandes reçues (à noter : c'est l'un des points à vérifier en jeu). Journal : aucune ligne. |
| 4 | Page Console, taper `vava_chancellerie_token` (FXServer affiche la valeur d'une convar quand on tape son nom). | Pas de valeur : la clé n'est plus une convar (« No such command » ou équivalent). |
| 5 | Pages Joueurs, Conseil, Sanctions de la Chancellerie. | Elles se remplissent : le pont répond avec la clé. |
| 6 | Page Console : `restart vava_chancellerie`. Attendre 5 s, rouvrir la page Joueurs. | `Started resource vava_chancellerie`, puis la marque revient, suivie de `clé de la Chancellerie reçue : pont ouvert` ; la page Joueurs marche de nouveau ; aucune alerte. |
| 7 | Page Console : `vava_chancellerie_cle 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef`. | `une autre clé du pont a été refusée : la première reçue est gardée`, puis l'alerte de la Chancellerie : console « Alerte : Le pont a refusé la clé de la Chancellerie… », bandeau en bas des pages ouvertes, journal « Alerte : clé du pont non prise » (ici sans danger : c'est vous qui avez tapé la clé). La clé tapée n'apparaît dans aucun message du pont ; la page Joueurs marche toujours. |
| 8 | Page Console : `vava_chancellerie_cle pasunecle`. | Rien de changé ; le pont reste ouvert avec sa clé. |
| 9 | **En jeu**, joueur hors du Conseil : `F8` → `vava_chancellerie_cle 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef`. | Rien ne se passe (commande réservée à la console ; au plus un refus d'accès de FiveM). Console du serveur : rien du pont. Le panneau marche toujours. |
| 10 | Arrêter le serveur, puis le redémarrer depuis la Chancellerie. | Même déroulé qu'en 1-1 : une nouvelle clé est donnée (rien à faire à la main). |
| 11 | Facultatif : lancer FXServer **sans** la Chancellerie (à la main, `+exec server.cfg`). | Console : `serveur lancé sans la Chancellerie : le pont reste fermé` ; aucune marque `vava_chancellerie:cle?`. Le jeu marche normalement. |
| 12 | Liste blanche Discord active : se connecter dans les toutes premières secondes du démarrage (avant « clé de la Chancellerie reçue »). Facultatif, la fenêtre est courte. | Refusé avec « Le registre des portes s'ouvre : réessayez dans un instant. » ; accepté (ou refusé selon le rôle Discord) une fois la clé reçue. |

## 2. Rangs des comptes reliés

| # | Faire | Attendu |
|---|---|---|
| 1 | Avec le compte relié **avant** la mise à jour (0-3) : redémarrer le serveur depuis la Chancellerie, puis ouvrir le tableau de bord (Journal). | Journal de la Chancellerie : « Rang non appliqué en jeu » · `<compte>` · « joueur jamais relié en jeu par un code : à relier de nouveau ». Console du serveur : `rang refusé au compte n° <N> : jamais relié en jeu par un code de la Chancellerie`. Le rang en jeu de `<N>` ne change pas (ni donné, ni retiré). |
| 2 | Page Comptes → « Relier un joueur » sur ce compte ; en jeu, avec le joueur `<N>`, `F8` → `chancellerie <code>`. | Le joueur lit « Ce joueur est relié au compte « … » de la Chancellerie ; son rang du Conseil s'applique. ». Console : `compte n° <N> relié en jeu à la Chancellerie`. Le rang s'applique : `F10` ouvre le Registre avec le sceau du rang. Journal de la Chancellerie : « Rang appliqué en jeu » (s'il a changé). En base : `SELECT * FROM vava_chancellerie_links;` → une ligne `<N>`, le nom du compte du panneau, l'heure. |
| 3 | Page Comptes : changer le rang de ce compte (Gardien → Sénéchal). | Appliqué en jeu sans reconnexion (`F10` : sceau « Sénéchal »). |
| 4 | Redémarrer le serveur depuis la Chancellerie. | Plus de « Rang non appliqué » pour ce compte ; son rang est toujours là en jeu. |
| 5 | Un autre joueur tape un code faux : `chancellerie 000000`. | « Code inconnu ou expiré… » ; aucune ligne ajoutée à `vava_chancellerie_links`. |
| 6 | Page Comptes : « Délier » le compte de 2-2. | Rang retiré en jeu (`F10` ne fait plus rien) : retirer reste toujours permis. La ligne de `vava_chancellerie_links` est supprimée ; console : `compte n° <N> délié de la Chancellerie`. |
| 7 | Relier de nouveau le même compte (code, `F8`). | La ligne revient en base, le rang revient aussitôt. |

## 3. Page Réseau (Chancellerie 1.8.0, pont 1.7.0)

Ce que montre `/vava_reseau` en jeu, lu depuis la Chancellerie, en lecture seule. Il faut `vAvA_core` 0.12.0 ou plus
récent (chaque joueur connecté suivi d'office), un compte du panneau de rang **Sénéchal** (droit `tools`) et un autre de
rang **Gardien** ; pour 3-7 à 3-9 et 3-17 à 3-19, des joueurs en jeu (`<B>`, son numéro de connexion, et un second
`<C>`) et un membre du Conseil en jeu (`<A>`, Sénéchal). Procédure du compteur lui-même : [reseau.md](reseau.md). La
bannière de la Chancellerie dit `v1.8.0` ; la console du serveur `module 'vava_chancellerie' v1.7.0 prêt` (ou plus récent :
Chancellerie 1.8.5 et pont 1.7.1 depuis T-132, qui ne changent rien à cette page).

| # | Faire | Attendu |
|---|---|---|
| 1 | Compte Gardien : regarder la colonne de navigation, puis taper `#reseau` dans l'adresse. | « Réseau » est grisé dans le groupe Royaume ; l'adresse ramène au tableau de bord. Journal du Conseil (`F10` → Journal, ou page Journal du Conseil) : aucune ligne « Compteur réseau consulté ». |
| 2 | Compte Sénéchal : ouvrir la page **Réseau**. | Titre « Réseau », à droite « lu à hh:mm:ss » ; tampons « Tout le royaume » (choisi), « Un module », « Un joueur » ; faits : Mesure (« exacte », ou « estimée » avec une phrase qui l'explique), Envois, Volume, Latents, Plus gros message ; tableau Module · Évènement · Envois · Volume · Plus gros · Latents, les plus lourds d'abord (20 au plus) ; pied « Non comptés : GlobalState, state bags et envois directs des modules. ». Journal du Conseil : **une** ligne « Compteur réseau consulté » au nom de « Chancellerie : <compte> ». |
| 3 | En jeu, `<A>` tape `/vava_reseau` ; aussitôt, sur la page, « Relire ». | Les 10 lignes du chat sont les 10 premières de la page (qui en montre 20), dans le même ordre, mêmes tailles (« 1,8 Ko » en jeu, « 1,76 Ko » ou « 1,8 Ko » sur la page : seule l'écriture diffère), à quelques envois près (la fenêtre a glissé entre les deux lectures). |
| 4 | Laisser la page ouverte deux minutes (relecture « toutes les 15 s », choisie par défaut). Puis choisir « toutes les 5 s », attendre 30 s ; puis « à la demande ». | L'heure « lu à » avance toutes les 15 s, puis toutes les 5 s ; plus rien à la demande, sauf « Relire ». Journal du Conseil : toujours **une seule** ligne « Compteur réseau consulté » (les relectures ne s'inscrivent pas). Navigateur, outils de développement (`F12`) → Réseau : au plus une requête `/api/game/request` toutes les 5 s. |
| 5 | Relecture « toutes les 5 s » ; passer à un autre onglet du navigateur une minute, puis revenir. | Pendant l'absence : « relecture en pause (page cachée) » à côté de l'heure, aucune requête (outils de développement). Au retour : une lecture aussitôt, puis toutes les 5 s. |
| 6 | Cliquer sur une ligne du tableau (par ex. `vava_codex`). Puis choisir « Un module », taper `vava_inventory`, Entrée. Puis taper `a/b`, « Lire ». | Le tampon « Un module » se choisit, le champ montre `vava_codex`, seul ce module reste ; ensuite seuls les envois de `vava_inventory` (ou « Aucun envoi de « vava_inventory » compté pendant la dernière minute. ») ; `a/b` : champ souligné de rouge, aucune requête. La ligne « (autres) », si elle paraît, ne se clique pas. Aucune nouvelle ligne au journal. |
| 7 | `<B>` joue une minute (besace, Codex). Choisir « Un joueur », taper le numéro de `<B>`, Entrée. Personne n'a tapé `/vava_reseau joueur` avant. | **Tout de suite** : « Joueur n° <B> · Prénom Nom », Mesure, Envois, Volume, Latents, Plus gros message, et les évènements reçus par `<B>` seulement (12 nommés au plus, puis « (autres) »). Aucune phrase sur un suivi à lancer. Journal du Conseil : « Réseau d'un joueur consulté », joueur = `<B>`, compte = son numéro de compte de jeu (page Joueurs → fiche). En jeu, rien ne change chez personne. |
| 8 | « Relire » sur le détail de `<B>`. Puis `<B>` revient à la sélection de personnage ; « Relire ». | Mêmes évènements mis à jour ; journal : pas de nouvelle ligne (même joueur). En sélection : « n° <B> · sans personnage », ses envois toujours là. |
| 9 | Taper un autre numéro de joueur en jeu, puis revenir à `<B>`. Puis taper `999` (personne). Puis `abc`, `0`, `70000`. | Une ligne « Réseau d'un joueur consulté » par changement de joueur. `999` : « Aucun joueur de ce numéro en jeu. », aucune ligne au journal. `abc`, `0`, `70000` : champ souligné, aucune requête. |
| 10 | Quitter la page (Tableau), y revenir aussitôt, la quitter et y revenir encore. Attendre une minute, y revenir. | Une seule ligne « Compteur réseau consulté » pour les retours de la même minute (une ouverture au plus par minute et par compte), puis une nouvelle après la minute ; la portée choisie est reprise. Hors de la page, aucune requête `netStats`. |
| 11 | Page ouverte, relecture « toutes les 5 s » : depuis un autre compte maître, retirer le rang Sénéchal du compte (page Comptes → Gardien). | À la lecture suivante : « Ce compte n'a pas ce droit. », « relecture automatique arrêtée » à côté de l'heure, la relecture passe « à la demande ». Après rechargement de l'onglet, « Réseau » est grisé. |
| 12 | Page Console : `stop vava_chancellerie`, « Relire » ; `start vava_chancellerie`, « Relire ». | « Le pont de la Chancellerie (vava_chancellerie) n'est pas lancé… », puis les chiffres reviennent avec **une** ligne « Compteur réseau consulté » (le pont redémarré ne connaît plus la page). |
| 13 | **Page ouverte, serveur de jeu arrêté** : relecture « toutes les 5 s », outils de développement (`F12`) → Réseau ouverts, arrêter le serveur de jeu depuis la Chancellerie ; laisser une minute. Recommencer avec `stop vava_chancellerie` (pont absent) au lieu de l'arrêt du serveur. | Serveur arrêté : **une** requête `/api/game/request` (« Le serveur de jeu est arrêté. »), puis la relecture s'arrête (« relecture automatique arrêtée », « à la demande ») ; plus aucune requête jusqu'à « Relire » ou un rythme choisi. Pont absent : une demande toutes les 5 s **au plus**, jamais plus (le message reste affiché) ; jamais « Trop de tentatives » sur les autres pages ouvertes. |
| 14 | Relecture « toutes les 5 s », double-cliquer vite sur « Relire ». | Une seule requête : « Relire » est grisé pendant la lecture. |
| 15 | Facultatif : relecture « toutes les 15 s », ne plus toucher à la page pendant 15 min (onglet visible). | Après 15 min : « relecture arrêtée après 15 min sans action », « à la demande » ; plus aucune requête. Choisir un rythme la relance. |
| 16 | Facultatif : un `vAvA_core` antérieur à 0.12.0. | « Les joueurs » et « Un joueur » : « Le compteur réseau demande vAvA_core 0.12.0 ou plus récent sur le serveur de jeu. » (jamais un détail faux) ; aucune erreur dans la console. |
| 17 | `<B>` et `<C>` en jeu, `<B>` très actif (besace, Codex), `<C>` immobile ; un troisième client en sélection de personnage. Choisir « Les joueurs ». | « 3 joueurs connectés. » et une ligne par joueur : N°, Personnage (« sans personnage » pour celui en sélection), Envois, Volume, Latents, `<B>` en tête (le plus chargé). Pas de champ de saisie. Journal du Conseil : **aucune** ligne nouvelle pour la liste (ni à la relecture). |
| 18 | Cliquer sur la ligne de `<C>`. | Le tampon « Un joueur » se choisit, le champ montre son numéro, son détail s'affiche ; journal : « Réseau d'un joueur consulté », joueur = `<C>`, compte = son compte de jeu. Revenir à « Les joueurs » : aucune nouvelle ligne. |
| 19 | `<C>` se déconnecte ; « Relire » sur « Les joueurs ». | `<C>` n'est plus dans la liste. S'il revient avec un autre numéro, son volume repart de zéro. |
| 20 | Un joueur `<D>` se connecte et reçoit le numéro qu'avait `<C>` (fréquent sur un petit serveur) ; ouvrir le détail de ce numéro. | Une **nouvelle** ligne « Réseau d'un joueur consulté » avec le compte de jeu de `<D>`, même si le numéro de `<C>` avait été lu dans la demi-heure. |
| 21 | Page Console : `stop vava_admin` ; ouvrir le détail d'un autre joueur. Puis `start vava_admin`. | Refus « Ce compte n'a pas ce droit. » (le Registre ne répond plus) ; jamais un détail affiché sans ligne au journal. Si le Registre accepte le droit mais refuse la ligne : « Le journal du Conseil n'a pas pu inscrire cette consultation… ». |
| 22 | Personnage au nom très accentué (24 lettres accentuées de prénom et de nom), connecté. « Les joueurs ». | Son nom s'affiche en entier, jamais « sans personnage ». |

## 4. Ce que je ne peux pas avoir vérifié hors jeu

Vérifié hors jeu : le pont réel sous Lua 5.4 avec un faux core (76 contrôles : clé reçue de la console seulement, la
première gardée, ancienne convar ignorée, adresse figée au setup et refusée hors de 127.0.0.1, marque répétée puis
abandonnée après 2 minutes, clé tardive acceptée, liste blanche refusée avant la clé, rang refusé à un compte inconnu,
liaisons en cours attendues sous une seule échéance, retrait permis, compte oublié à la déliaison) ; la Chancellerie réelle avec un faux FXServer
(clé absente des arguments, donnée une fois par l'entrée, masquée dans la console même réaffichée, absente du journal,
nouvelle clé à chaque lancement, une seule réponse par démarrage du pont et de nouveau après son redémarrage, alertes
sur clé refusée, clé étrangère et confirmation absente, compte oublié à la déliaison, refus lisible au journal) et ses suites existantes (liaisons, console, performances,
server.cfg, sauvegardes).

Restent à voir avec un vrai FXServer :
- qu'il lit bien une commande arrivée sur son entrée standard **pendant** le démarrage des ressources (la Chancellerie
  ne répond qu'à la marque du pont, donc après la déclaration de la commande : 1-1) ;
- qu'il ne réaffiche pas la commande reçue (sinon elle est masquée, 1-3) et qu'aucun fichier de log de FXServer ne la
  garde (`con_logFile`, s'il est réglé) ;
- que la ligne écrite par le pont (`print`) arrive sur la sortie standard que lit la Chancellerie, préfixée par
  `[script:vava_chancellerie]` (ou un nom abrégé, complété d'espaces : la Chancellerie accepte `[ script:vava_chan…]`,
  puis le texte exact, accents compris : si FXServer les abîmait, la marque ne serait plus reconnue, 1-1) ;
- que FXServer écrit bien `Started resource vava_chancellerie` (éventuellement précédé de `[ resources]`) à un
  `restart` : sinon la Chancellerie ne redonne pas la clé et alerte (1-6) ;
- qu'une commande déclarée réservée (`RegisterCommand(…, true)`) tapée par un joueur n'atteint pas le pont, ou l'atteint
  avec un numéro de joueur (refusée) : 1-9 ;
- l'ordre réel entre la réponse de la Chancellerie à une liaison et sa demande de rang (le pont attend la liaison en
  cours 5 s au plus par requête) : 2-2 doit appliquer le rang du premier coup.

Page Réseau (section 3), vérifiée hors jeu : le vrai `server/network.lua` du pont sous Lua 5.4 avec un faux Registre et
un faux `core.net` (59 contrôles : détail refusé sans ligne au journal, même numéro passé à un autre compte inscrit, core
ancien refusé ; arguments refusés, délai avant le droit, Gardien refusé sans rien lire ni inscrire,
une ligne à l'ouverture, aucune à la relecture, ouverture répétée prise une fois par minute, une ligne par autre joueur
avec son compte de jeu, échéance de 30 min, ligne refusée réessayée, nom du personnage rendu sans condition de suivi,
liste des joueurs copiée bornée à 128 et jamais inscrite, core sans liste, liste copiée pure, core sans `core.net`) ; la
vraie page sous jsdom (108 contrôles : journal indisponible ; liste des joueurs, « sans personnage », clic vers le détail, liste plafonnée ou
vide ; ouverture marquée une seule fois,
relecture à 15 s puis 5 s, pause onglet caché, ligne cliquée, numéros refusés sans requête, réponse dépassée ignorée,
droit retiré, aucun texte injecté en HTML ; et, après la relecture réseau, jamais moins de 5 s entre deux demandes
quand chaque lecture échoue, page rouverte en erreur sans relecture immédiate, relecture arrêtée sur serveur arrêté,
compteur absent ou joueur parti, retour d'onglet en retard, délai refusé par le pont sans effacer le tableau, double
clic sur « Relire », arrêt après 15 min sans action — 24 de ces contrôles échouent sur la page d'avant la correction).
Restent à voir en jeu :
- qu'un numéro de joueur arrivé en JSON (`12`) est bien lu par le pont (entier ou flottant entier : les deux sont
  acceptés) et que `DoesPlayerExist` le reconnaît (3-7, 3-9) ;
- qu'une liste vide (aucun envoi, aucun joueur) arrive à la page sans erreur, qu'elle soit encodée `[]` ou `{}`
  (3-6, 3-7, 3-17) ;
- l'arrêt de la relecture dans un onglet caché ou une fenêtre réduite selon le navigateur (3-5) ;
- le coût d'une lecture côté serveur (profiler de FXServer, page à 5 s) : attendu bien sous 0,1 ms.
