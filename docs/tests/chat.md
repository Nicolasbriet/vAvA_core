# Chat — procédure de test en jeu

Procédure pour vérifier en jeu `vava_chat` 1.1.0 : la fenêtre, le hors-RP, `/me` et `/do` (dans le chat et au-dessus
de la tête), les messages privés, le canal du Conseil, les suggestions de commandes, les limites, le journal de
modération et le redémarrage. Comptez une heure ; presque tout se fait à deux : **A**, membre du Conseil, et **B**,
simple joueur. Un test se cite « chat 3-4 » (section 3, ligne 4).

## 0. Préparation

1. **Commun** : ordre de démarrage, compte du Conseil, consoles, mesure du resmon et remontée des écarts :
   [LISEZMOI.md](LISEZMOI.md).
2. **Démarrage** : la console du serveur affiche `module 'vava_chat' v1.1.0 prêt`. Le `server.cfg` ne contient plus
   `ensure chat` (sinon deux chats s'affichent).
3. **Joueurs** : A Souverain (`vava_conseil <compte de A> souverain`), B sans rang. Le numéro de joueur (« n° ») paraît
   entre crochets devant le nom dans toute ligne hors-RP : faites écrire un mot à chacun pour noter les deux numéros.
4. **Repères de distance** : le cercle au sol de la voix (touche `W` en AZERTY, voir [voix.md](voix.md)) a pour rayon
   5 m en Parler, 15 m en Crier (la portée de `/me` et `/do`), 25 m en Déclamer (au-delà des 20 m du hors-RP).
5. **Réglages pour aller vite** (à remettre ensuite, puis `restart` du module) :
   `vava_chat/config.lua` → `log.flushMs = 1000` (défaut `10000` : le journal s'écrit en une seconde),
   `overhead.durationMs = 30000` (défaut `8000` : le temps de passer derrière un mur) ;
   `vava_voice/config.lua` → `ring.durationMs = 10000` (défaut `1500` : le cercle reste le temps de se placer).
6. **Textes à coller** (`Ctrl+V`), préparés dans un bloc-notes : 26 fois `0123456789` (260 signes) ; 25 fois
   `éééééééééé` (250 signes) ; 60 fois `éééééééééé` (600 signes, soit 1 200 octets).

## 1. Fenêtre et saisie

| # | Faire | Attendu |
|---|---|---|
| 1 | Appuyer sur `T`, relâcher. | Le chat s'ouvre au relâchement, sans « t » dans la saisie : onglets **Général** et **Actions** (plus **Conseil** chez A), saisie étiquetée « HRP » avec « Hors-RP… ou /me, /do, /mp », et dessous « Entrée : envoyer · Échap : fermer · ↑ ↓ : historique · Tab : compléter ». Le personnage ne bouge plus, la souris est libre. |
| 2 | `Échap`. | Le chat se ferme ; le personnage bouge de nouveau. |
| 3 | Chat fermé : ouvrir le menu pause, puis `T` pendant le menu. | Le chat disparaît sous le menu (en 0,3 s au plus) et ne s'ouvre pas ; il revient à la fermeture du menu. |
| 4 | Ouvrir l'inventaire (`I`), puis `T`. | Le chat ne s'ouvre pas tant qu'une autre fenêtre a le clavier. |
| 5 | Écrire `bonjour`, `Entrée`. | Le message part et le chat se ferme ; fermé, le fil Général reste visible puis s'efface 12 s après le dernier message (`ui.fadeMs`). `Entrée` sur une saisie vide ferme seulement. |
| 6 | Saisir le bandeau pour déplacer la fenêtre ; tirer son coin ; tenter de la sortir de l'écran ou de la réduire à rien. | La fenêtre suit ; elle reste dans l'écran et ne descend pas sous 300 × 180 px. |
| 7 | Se déconnecter, revenir. | Même place, même taille (gardées sur le PC du joueur). |
| 8 | `/chat reinit`, puis `/chat` seul. | « — Le chat est revenu à sa place. », la fenêtre retrouve sa place de départ (bord gauche, un peu au-dessus du milieu) ; puis « — Usage : /chat reinit (remet le chat à sa place) ». |
| 9 | Envoyer trois messages ; rouvrir, taper un début de phrase, `↑` trois fois, `↓` trois fois. | `↑` remonte les trois lignes envoyées ; `↓` redescend et rend le début de phrase. |
| 10 | Paramètres > Raccourcis > FiveM. | Ligne « Chat : écrire » sur `T` ; une autre touche choisie ouvre le chat à sa place. |

## 2. Hors-RP, actions et portées **(2 joueurs)**

A et B face à face, à 10 m environ (dans le cercle Crier de A), sauf mention.

| # | Faire | Attendu |
|---|---|---|
| 1 | A écrit `Bonjour` dans Général, sans commande. | Chez les deux, dans Général : étiquette « HRP », « [n° de A] Prénom Nom », insigne « Conseil », « : Bonjour ». |
| 2 | B : `/ooc Salut`. | La même ligne chez les deux, sans insigne. |
| 3 | A, chat ouvert, clique le nom de B dans cette ligne. | La saisie se remplit de « /mp <n° de B> ». |
| 4 | A : `/me salue d'un geste`. | Chez les deux, dans Général et Actions : « * Prénom Nom salue d'un geste * » en italique doré. Au-dessus de la tête de A : « * salue d'un geste * » en doré pendant 8 s, vu de B **et de A lui-même**, plus petit de loin. |
| 5 | A : `/do La porte est verrouillée`. | « * La porte est verrouillée * (Prénom Nom) » en gris-bleu dans Général et Actions ; au-dessus de la tête de A : « * La porte est verrouillée * » en gris-bleu. |
| 6 | A : `/me sourit à l'idée de l'été`. | Accents justes dans le chat et au-dessus de la tête. |
| 7 | A enchaîne quatre `/me` en moins de 8 s. | Trois lignes au plus au-dessus de sa tête, la plus ancienne en haut ; la quatrième chasse la première. |
| 8 | A : un `/me` de plus de 90 signes. | Au-dessus de la tête, coupé et terminé par « … » ; dans le chat, entier. |
| 9 | B à 17 m environ (trois pas au-delà du cercle Crier de A) ; A envoie `Bonjour`, `/me salue`, `/do Il pleut`. | B reçoit le seul hors-RP : ni `/me`, ni `/do`, ni texte au-dessus de la tête. A reçoit toujours ses propres messages. |
| 10 | B hors du cercle Déclamer de A (au-delà de 25 m) ; A envoie `Bonjour`. | B ne reçoit rien. |
| 11 | B à 10 m, derrière un mur ; A : `/me frappe à la porte`. | B reçoit la ligne dans le chat mais ne voit pas le texte au-dessus de la tête (ligne de vue) ; s'il sort de derrière le mur avant la fin des 8 s, le texte apparaît (ligne de vue relue toutes les 300 ms). |
| 12 | A : `/me attend` ; B recule au-delà de 15 m puis revient dans les 8 s. | Le texte disparaît au-delà de 15 m et reparaît au retour. |
| 13 | B ouvre l'onglet Actions et écrit `bonjour` sans commande. | Texte d'attente « /me une action, /do une description ». Rien ne part ; « — Ici, commencez par /me (une action) ou /do (une description). » dans Actions et dans Général. |
| 14 | B reste sur Actions, chat ouvert ; A envoie dix lignes hors-RP. | Pastille sur Général : 1, 2… puis « 9+ » ; elle s'efface quand B ouvre Général. |
| 15 | B à terre (voir [sante.md](sante.md)) : `/me gémit`, puis `/ooc test`. | Les deux partent normalement : le chat ne regarde pas l'état de santé. |

## 3. Messages privés **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | B, avant tout message privé : `/r coucou`. | « — Personne à qui répondre. » |
| 2 | A : `/mp <n° de B> Bonjour`. | Chez A : un onglet au nom de B apparaît ; dans Général, sceau de cire, étiquette « MP », « À [n°] Prénom Nom : Bonjour » ; dans l'onglet, « Vous : Bonjour ». Chez B : onglet au nom de A avec la pastille 1 ; dans Général, « De [n°] Prénom Nom », insigne « Conseil », « : Bonjour ». |
| 3 | B ouvre l'onglet de A et écrit `Bien reçu` sans commande. | Saisie étiquetée « MP », texte d'attente « Écrire à Prénom Nom… » ; A reçoit la ligne dans Général et dans l'onglet. |
| 4 | A : `/r Parfait`. | Arrive chez B, dans Général et dans l'onglet. |
| 5 | A, chat ouvert, clique la ligne privée de Général. | L'onglet de la conversation s'ouvre. |
| 6 | A ferme l'onglet par sa croix, puis clique l'ancienne ligne privée de Général ; B écrit de nouveau. | L'onglet disparaît ; le clic ne le rouvre pas. Au message suivant de B, l'onglet revient avec ce seul message et sa pastille. |
| 7 | Erreurs, une par une : `/mp` ; A `/mp <n° de A> test` ; `/mp 999 test` ; `/mp 0 test` ; `/r` seul. | « — Usage : /mp <n°> <message> » ; « — Vous ne pouvez pas vous écrire. » ; « — Aucun joueur en jeu sous ce numéro. » ; « — Message refusé. » ; « — Usage : /r <message> ». |
| 8 | B part à l'autre bout de la carte ; A lui écrit. | Reçu : le message privé n'a pas de portée. |
| 9 | B à 3 m de A ; B ouvre le Codex (`F1`) → Message privé. | La liste des joueurs propose A **et B lui-même** (défaut connu : le Codex compte le joueur parmi ses proches). B se choisit, écrit, Lancer : « — Vous ne pouvez pas vous écrire. » ; en choisissant A, le message part. |
| 10 | B à 10 m de A ; même chose. | A n'est plus proposé (au-delà de 5 m) ; B y figure toujours ; le numéro de A tapé à la main reste accepté. |
| 11 | A (Conseil) ouvre le même formulaire. | Tous les joueurs en jeu, quelle que soit la distance, A compris. |

## 4. Canal du Conseil **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | A ouvre l'onglet Conseil et écrit `Réunion ce soir` sans commande. | Saisie étiquetée « Conseil », texte d'attente « Au Conseil… ». Chez A, dans Général et Conseil : étiquette « Conseil », rang « Souverain » (en capitales), « · [n°] Prénom Nom : Réunion ce soir ». B ne reçoit rien. |
| 2 | A : `/staff test` depuis Général. | La même ligne. |
| 3 | B : `/staff bonjour`. | « — Ce canal est réservé au Conseil. » ; B n'a pas d'onglet Conseil, mais la suggestion `/staff` lui est proposée (déclarée pour tous). |
| 4 | Console du serveur : `vava_conseil <compte de B> gardien`. | Sans reconnexion, l'onglet Conseil apparaît chez B ; ses lignes hors-RP portent l'insigne « Conseil ». |
| 5 | B : `/staff me voici`. | Reçu par A et B, rang « Gardien ». |
| 6 | Console : `vava_conseil <compte de B> souverain` ; B tape `/met`. | Ni aide ni sous-commande (au plus `/metiers` nu, voir 5-7) : les suggestions décrites par le Codex ne sont redemandées qu'à l'apparition du personnage. Après une reconnexion, B a celles de 5-4. |
| 7 | Console : `vava_conseil <compte de B> aucun`. | L'onglet Conseil disparaît chez B ; `/staff` lui est de nouveau refusé. |
| 8 | En fin de séance : `stop vava_admin`, puis `start vava_admin`. | À l'arrêt, l'onglet Conseil de A disparaît (sans vava_admin, le canal suit la seule permission ACE `vava_chat.staff`) ; au redémarrage, il revient sans reconnexion. Relancer ensuite ce qui s'est arrêté avec lui (`ensure vava_chancellerie`…). |

Les proclamations du Registre (`F10` → Proclamation) ne passent pas par le chat : c'est une bannière de vava_admin,
testée dans [registre.md](registre.md).

## 5. Commandes et suggestions

| # | Faire | Attendu |
|---|---|---|
| 1 | Taper `/`. | Six suggestions au plus sous la saisie : d'abord les commandes qui ont une aide, par ordre alphabétique. |
| 2 | `/me`, puis une espace. | « /me <action> », aide « Action de votre personnage » ; après l'espace, `<action>` passe en rouge et l'aide devient « ex. : tire son épée ». |
| 3 | `/mp `, puis `/mp <n°> `. | « /mp <joueur> <message> » (description du Codex) : `<joueur>` en rouge, aide « numéro du joueur » ; après le numéro et l'espace, `<message>` en rouge, aide « Message privé ». |
| 4 | A (Conseil) : `/met`. | `/metiers` (« Compétences d'un joueur — niveau \| recette \| voir »), puis `/metiers niveau` (« Corriger un niveau »), `/metiers recette` (« Donner une recette »), `/metiers voir` (« Lire la fiche »). |
| 5 | A : `Tab` cinq fois. | La saisie devient « /metiers », « /metiers niveau », « /metiers recette », « /metiers voir », puis de nouveau « /metiers », la ligne choisie surlignée. |
| 6 | A : `/metiers niveau `, puis trois mots séparés d'espaces. | « /metiers niveau <joueur> <compétence> <niveau> », le paramètre en cours en rouge avec son aide : « numéro du joueur », « au choix dans la liste », « de 0 à 100 ». |
| 7 | B (sans rang) : `/met`. | `/metiers` seul, sans aide ni sous-commande (commande du serveur que FiveM ouvre à tous : à confirmer) ; la lancer ne produit rien. |
| 8 | `/ME salue` en capitales ; dans la console `F8`, `me salue`. | Les deux font comme `/me salue` ; un refus éventuel s'affiche dans Général. |
| 9 | `/me salue`, puis ouvrir le Codex (`F1`). | « Action de votre personnage » en tête des dernières pages (détail : [codex.md](codex.md)). |
| 10 | B : `/commandeinconnue`. | « — Commande inconnue : /commandeinconnue » chez B seul ; A ne voit rien. |
| 11 | A : `/metiers voir <n° de A>`. | La réponse arrive dans Général en texte simple, sans étiquette : « Prénom Nom (personnage n° …) — budget … / 200 », puis une ligne par compétence travaillée. |

## 6. Débit, longueur et texte brut (tentatives de triche)

| # | Faire | Attendu |
|---|---|---|
| 1 | Console `F8` : `ooc spam`, puis `↑` `Entrée` le plus vite possible, dix fois. | Les six premiers partent (B les voit), puis « — Doucement : vous écrivez trop vite. » dans Général ; ensuite un message par seconde au plus. Console du serveur : « joueur <n> : limite dépassée sur vava_chat:send ». |
| 2 | Même chose en alternant `me spam` et `ooc spam`. | Même limite : tous les genres de message partagent le même débit. |
| 3 | `F8` : `commandeinconnue`, puis `↑` `Entrée` vite, huit fois. | Trois avis « Commande inconnue », puis un avis toutes les 2 s au plus. |
| 4 | Coller les 260 signes (§ 0-6) dans Général, `Entrée`. | Le compteur paraît à 200 signes (« 200 / 250 ») et passe en rouge au-delà de 250 (« 260 / 250 ») ; le message part sans erreur et B en reçoit les 250 premiers signes. La saisie refuse ce qui dépasse 290 signes. |
| 5 | Coller les 250 « é ». | Compteur « 250 / 250 », pas en rouge ; B reçoit les 250 « é » (un « é » compte pour un signe). |
| 6 | `F8` : `ooc ` suivi des 600 « é » (1 200 octets). | « — Message refusé. » ; console du serveur : « joueur <n> : arguments refusés pour 'vava_chat:send' (…) ». |
| 7 | `/ooc <b>gras</b> <img src=x onerror=alert(1)> &amp; <script>alert(2)</script>`, puis le même texte en `/mp` et dans l'onglet Conseil. | Chez A et B, le texte s'affiche tel quel, `<`, `>` et `&amp;` compris : ni gras, ni image, ni fenêtre. |
| 8 | `/ooc ^1rouge ^2vert`. | « rouge vert », sans les codes, dans la couleur ordinaire. |
| 9 | `/me ~r~rouge~s~ ~h~gras`. | Au-dessus de la tête : « * rouge gras * », sans couleur ni gras. Dans le chat, les `~r~` restent visibles (texte brut). |
| 10 | `/me <C>serré</C> <font color='#ff0000'>rouge</font>`. | Au-dessus de la tête, le texte tel quel (à confirmer : GTA interprète peut-être `<C>` ou `<font>`, que le module ne retire pas). |
| 11 | `/ooc` suivi d'espaces seulement. | « — Usage : /ooc <message> ». |

## 7. Départ et déconnexion **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | A et B ont échangé un message privé ; A garde l'onglet de B ouvert ; B quitte le jeu. | Chez A, l'onglet de B se grise, « — Prénom Nom est parti. » s'y inscrit et la saisie se ferme sur ce même texte. |
| 2 | A : `/r encore là ?` | « — Ce joueur n'est plus là. » |
| 3 | B revient. Pendant qu'il est sur l'écran de sélection du personnage, A : `/mp <nouveau n° de B> test`, puis `Bonjour` en hors-RP. | « — Aucun joueur en jeu sous ce numéro. » ; B ne reçoit rien tant que son personnage n'est pas en jeu. |
| 4 | B reprend le même personnage et écrit `/mp <n° de A> me revoici`. | L'onglet grisé de A reprend vie avec ce message ; sa saisie se rouvre. |
| 5 | B ouvre le chat, tape un message sans l'envoyer et quitte le jeu. | Rien ne part. À son retour : chat fermé, fils vides, aucun onglet privé. |
| 6 | B revient avec un autre personnage et écrit à A. | Nouvel onglet à son nouveau nom chez A ; l'ancien reste grisé. |

## 8. Redémarrage du module

| # | Faire | Attendu |
|---|---|---|
| 1 | A chat ouvert, B en jeu : console du serveur `restart vava_chat`. | Chez A, le curseur disparaît et le personnage bouge ; console `module 'vava_chat' v1.1.0 prêt`. Le chat revient fermé, à la place choisie, fils et onglets privés vidés ; l'onglet Conseil revient chez A ; `T` ouvre. |
| 2 | Aussitôt après : A et B échangent hors-RP, `/me`, `/mp`. | Tout marche sans reconnexion, mêmes numéros de joueur. `/r` avant tout nouveau message privé : « — Personne à qui répondre. » |
| 3 | A : `/met`. | Mêmes suggestions qu'avant (profil redemandé au redémarrage). |
| 4 | Pendant qu'un `/me` s'affiche au-dessus d'une tête : `restart vava_chat`. | Le texte disparaît et ne revient pas. |
| 5 | A : `/ooc avant le redémarrage`, puis `restart vava_chat` dans les 10 s (`log.flushMs` par défaut). | La ligne est en base (la file part à l'arrêt). Si la console affiche « 1 message(s) du journal non écrit(s) à l'arrêt : … », le core avait fermé la base le premier : perte documentée, à noter. |

## 9. Journal en base

```sql
SELECT `id`, FROM_UNIXTIME(`at`) AS `quand`, `kind`, `character_id`, `author`, `target_id`, `target`, `recipients`, `message`
FROM `vava_chat_logs` ORDER BY `id` DESC LIMIT 30;
```

| # | Faire | Attendu |
|---|---|---|
| 1 | Après les sections 2 à 6, attendre 10 s (ou `log.flushMs = 1000`), lancer la requête. | Lignes `ooc`, `mp` et `staff` seulement : aucun `me` ni `do`. `author` est le nom du personnage. |
| 2 | Une ligne `ooc` envoyée avec B à 10 m ; une autre envoyée seul. | `recipients` = 2 (auteur compris), puis 1 ; `target_id` 0, `target` vide. |
| 3 | Une ligne `mp`. | `target_id` = numéro de personnage de B, `target` = son nom ; `recipients` = 1 (la copie de l'auteur n'est pas comptée). |
| 4 | Une ligne `staff` envoyée quand B était Gardien. | `recipients` = 2. |
| 5 | Les messages de la section 6. | 250 signes au plus ; balises en clair ; `^1` et `^2` absents. |
| 6 | Vieillir une ligne : `UPDATE vava_chat_logs SET at = at - 8 * 86400 WHERE id = <id>;`, puis `restart vava_chat`. | La ligne disparaît : purge au démarrage (puis toutes les heures) de ce qui a plus de 7 jours. |

## 10. Resmon

| Moment | `vava_chat` |
|---|---|
| Au repos : chat fermé, personne autour | 0,02 ms au plus (aucune boucle par image) |
| Chat ouvert, saisie et suggestions | 0,02 ms au plus |
| Texte au-dessus d'une ou plusieurs têtes (2-4 à 2-7) | 0,15 ms au plus ; retour au repos 8 s après le dernier `/me` ou `/do` |

## 11. Ce que je ne peux pas avoir vérifié hors jeu

- Le rendu de la fenêtre dans CEF (polices, cadre, rubans, pastilles) : `modules/vava_chat/web/index.html?view=open`
  (ou `passive`, `actions`, `mp`, `gone`, `staff`, `suggest`, `all`) s'ouvre dans un navigateur pour comparer.
- Le texte au-dessus des têtes : police 4 de GTA (accents ; un emoji paraîtra sans doute en carré), hauteur au-dessus
  de l'os de la tête (`overhead.headOffset`), découpe en morceaux de 96 octets d'un long texte accentué.
- Les balises que GTA interprète dans un texte dessiné (`<C>`, `<font>`) : le module ne retire que les codes `~…~`
  (6-10).
- L'arrivée au serveur de l'évènement de repli (`__cfx_internal:commandFallback`) pour une commande inconnue tapée
  dans le chat ou dans `F8` (5-10, 6-3).
- Le droit ACE `command.<nom>` des commandes ouvertes à tous (5-7) : s'il est accordé à tous, un simple joueur se voit
  proposer `/metiers`.
- Le collage (`Ctrl+V`) dans la saisie et la longueur de ligne acceptée par la console `F8` (6-4 à 6-6).
- L'ordre d'arrêt du core et du module lors d'un `restart` (8-5).
