# Chancellerie et pont — procédure de test en jeu

Procédure pour vérifier en jeu la Chancellerie 1.6.0 et `vava_chancellerie` 1.5.0 : **la clé du pont ne passe plus sur
la ligne de commande de FXServer** (elle est demandée par le pont dans la console et donnée par l'entrée de FXServer),
et **un rang du Conseil n'est donné qu'à un joueur que le pont a vu relié en jeu**. Comptez une demi-heure ; la
section 2 se joue avec un client FiveM. Un test se cite « chancellerie 1-3 ». Préparation commune, mesure du resmon et
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

## 3. Ce que je ne peux pas avoir vérifié hors jeu

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
