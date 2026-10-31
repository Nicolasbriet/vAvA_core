# Compteur réseau — procédure de test en jeu

Procédure pour vérifier en jeu `core.net` (core 0.10.0, T-013) : mesure de chaque envoi du serveur vers les joueurs,
envoi latent des gros messages, compteur `/vava_reseau`, essai `vava_reseau_essai`, et `vava_chat` 1.2.0 (plus d'envoi
à tous par son export). Comptez trois quarts d'heure ; les tests à deux joueurs sont marqués **(2 joueurs)**. Chaque
test dit quoi faire et ce qui doit se passer ; si ce n'est pas le cas, notez l'étape, ce que vous avez vu, et la ligne
de console correspondante (serveur, ou `F8` du joueur).

## 0. Préparation

1. Ordre de démarrage habituel ([LISEZMOI.md](LISEZMOI.md) § Préparation commune) : rien ne change.
2. **Compte du Conseil** : un Souverain ou un Sénéchal (droit `tools`). Pour les tests 2 et 6, un second compte au
   rang de Gardien (`vava_conseil <compte> gardien`), qui n'a pas `tools`.
3. **Consoles** : celle du serveur (les lignes du compteur commencent par `[vAvA][…][net]`), et `F8` de chaque joueur.
4. **Codex** : `vava_codex` démarré (tests 4 et 5).

## 1. Démarrage

| # | Faire | Attendu |
|---|---|---|
| 1 | `ensure vAvA_core` (ou démarrage du serveur). | Console du serveur : `[net] mesure exacte`. Si la ligne dit `[net] estimation (fonctions du runtime absentes : …)`, la noter **avec la liste** : la version de FXServer n'offre pas la sérialisation à part ; tout marche, mais les tailles sont estimées et chaque cible coûte une sérialisation. |
| 2 | Gardien (sans `tools`) : `/vava_reseau`, puis `F1` (Codex), chapitre Core. | Rien ne se passe, aucun message ; le Codex ne propose pas « Compteur réseau ». |
| 3 | Sénéchal : marcher une minute, puis `/vava_reseau`. Retaper aussitôt `/vava_reseau`. | Au plus 13 lignes « Réseau » dans le chat : « Dernière minute (mesure exacte) : … envois, …, dont … latents. », puis les plus gros envois (`vAvA_core · vAvA:character:fields`, réponses `rpc …` des modules) avec leur taille (« 1,8 Ko »), puis « Non comptés : GlobalState, state bags et envois directs des modules. ». La seconde commande, dans les 2 s : rien. |
| 4 | Sénéchal : `F1` → chapitre Core → « Compteur réseau ». | Quatre actions : « Les plus gros envois », « Ce que reçoit un joueur » (choix d'un joueur), « Envois d'un module » (nom de la ressource), « Zones et abonnements » (joueur facultatif, core 0.11.0 : voir [zones.md](zones.md)). Lancer la première donne la même sortie qu'en 1-3. |
| 5 | Console du serveur : `vava_reseau`, puis `vava_reseau ressource vAvA_core`. | Les mêmes lignes, préfixées « Réseau : », dans la console ; la seconde ne liste que `vAvA_core`. |
| 6 | Sénéchal : `/vava_reseau quoi`, `/vava_reseau joueur abc`, `/vava_reseau ressource a/b`, `/vava_reseau joueur 999`. | « usage : /vava_reseau \| joueur <n°> \| ressource <nom> \| zones [n°] » trois fois (une commande toutes les 2 s), puis « Aucun joueur n° 999 en jeu. ». |

## 2. Gros envois en latent

| # | Faire | Attendu |
|---|---|---|
| 1 | Ouvrir le Codex (`F1`) trois fois (en le fermant entre deux), puis `/vava_reseau ressource vava_codex`. | Ligne `rpc vava_codex:open` : 3 envois, le plus gros entre 10 et 30 Ko au premier passage, et « … latents » si le message dépasse 8 Ko. Le Codex s'ouvre normalement à chaque fois, sans « délai dépassé ». Depuis `vava_codex` 1.2.0, les ouvertures suivantes sont petites (contenu gardé par la page) : c'est attendu. |
| 2 | Ouvrir la besace (`I`) puis `/vava_reseau ressource vava_inventory`. | Seuls les envois comptés par le core paraissent (réponses aux RPC de l'inventaire : `rpc vava_inventory:…`) ; ses envois directs (`vava_inventory:delta`…) ne le sont pas encore (§ Ce qui n'est pas compté). |
| 3 | Créer un personnage, se déconnecter, revenir, mourir et réapparaître (`/respawn` en développement, ou les soins). | Chargement, apparence et apparition comme avant (ordre chargement → champs → apparition gardé) ; aucune erreur dans la console. |
| 4 | Au repos, `resmon` côté client. | `vAvA_core` à 0,00 ms : aucune boucle ajoutée (deux gestionnaires d'évènement seulement). |

## 3. Ce que reçoit un joueur (2 joueurs)

Depuis le core 0.12.0, chaque joueur connecté est suivi d'office, évènement par évènement (ses 6 évènements les plus
lourds de la minute, le reste sous `* · <autres>`) : plus de suivi à lancer, plus de limite de 4 joueurs.

| # | Faire | Attendu |
|---|---|---|
| 1 | B joue une minute (ouvre la besace, le Codex, marche). A (Sénéchal) tape `/vava_reseau joueur <n° de B>`. | **Tout de suite** : « Joueur <n°> (Prénom Nom) : … envois, … dans la dernière minute. », puis les évènements reçus par B, les plus lourds d'abord (seulement les siens : aucun envoi fait à A), puis le pied. Jamais « relancez la commande dans une minute ». Registre du Conseil (`F10`) → Journal : « Réseau d'un joueur consulté », joueur = n° de B, compte = son numéro de compte de jeu. |
| 2 | B vient de se connecter, encore en sélection de personnage. A tape `/vava_reseau joueur <n° de B>`. | « Joueur <n°> (sans personnage) : … », et les envois de la sélection (réponses `rpc` des personnages) ; ligne au journal. |
| 3 | A tape `/vava_reseau joueur` pour cinq joueurs différents l'un après l'autre (un toutes les 2 s). | Chacun répond tout de suite avec son détail ; une ligne au journal par consultation. |
| 4 | B se déconnecte, A tape `/vava_reseau joueur <n° de B>`. | « Aucun joueur n° … en jeu. » ; aucune erreur dans la console. Si un autre joueur reprend ce numéro, son détail repart de zéro (rien de B). |
| 5 | B ouvre beaucoup d'interfaces différentes en une minute (besace, Codex, métiers, Registre…), puis A tape `/vava_reseau joueur <n° de B>`. | Au plus 6 évènements nommés, plus une ligne `* · <autres>` qui cumule les plus petits ; le total de l'en-tête est celui de tous les envois à B. |
| 6 | `resmon` du serveur (ou `profiler record` de la console) avec plusieurs joueurs actifs, avant et après la mise à jour. | Pas de hausse visible de `vAvA_core` : mesuré hors jeu, environ 0,3 µs de plus par joueur servi à chaque envoi. |

## 4. Essai du réseau (console du serveur)

| # | Faire | Attendu |
|---|---|---|
| 1 | Console : `vava_reseau_essai <B> 100`. | Console : « essai envoyé au joueur <B> : 100 Ko en latent ». `F8` de B : « [vAvA] essai réseau : latent de 100 Ko reçu 1 600 ms après le début (≈ 64 Ko/s) ; ordre d'arrivée 1, 3, 2 » (environ 1,6 s à 64 Ko/s ; noter le chiffre réel). L'ordre « 1, 3, 2 » est attendu : un message fiable envoyé après un latent arrive avant lui. |
| 2 | Console : `vava_reseau_essai <B> 1`, puis `vava_reseau_essai <B> 256`. | Deux lignes `F8` chez B, avec le débit de chacune ; noter les deux chiffres (et les comparer avec `netgraph 1` si possible). |
| 3 | Console : `vava_reseau_essai <B> 256` trois fois de suite, vite. | Les deux premiers partent ; le troisième : « essai refusé : saturated » (512 Ko au plus en route vers un joueur) ; quatre secondes plus tard, il repart. Chez B, le second essai remplace le premier (une seule ligne finale, celle du dernier). Noter l'ordre d'arrivée affiché (ordre entre deux latents). |
| 4 | **(2 joueurs)** A à 10 m de B. Console : `vava_reseau_essai <B> 1 20`. | Console : « essai envoyé au joueur <B> : 1 Ko en latent, 2 joueur(s) à 20 m ». `F8` de A : « [vAvA] essai réseau : message de proximité reçu ». `F8` de B : l'essai complet. |
| 5 | **(2 joueurs)** A à plus de 500 m de B : `vava_reseau_essai <B> 1 20`. | Rien chez A ; console : « … 1 joueur(s) à 20 m ». |
| 6 | **(2 joueurs)** B se déconnecte pendant `vava_reseau_essai <B> 256`. | Aucune erreur dans la console du serveur. |
| 7 | Console : `vava_reseau_essai`, `vava_reseau_essai <B> 0`, `vava_reseau_essai <B> 300`, `vava_reseau_essai <B> 10 2000`, `vava_reseau_essai 999 10`. | « usage : vava_reseau_essai <n° du joueur> <Ko 1-256> [rayon] » pour les quatre premiers ; « essai refusé : invalid_target » pour le dernier. |
| 8 | Un joueur tape `/vava_reseau_essai <son n°> 10` dans le chat. | Rien (commande de console). |
| 9 | Console : `vava_reseau_essai <B> 256` (4 s de latent en route vers B), et **aussitôt** B ouvre le Codex (`F1`) après un redémarrage de `vava_codex` (contenu complet, plus de 8 Ko). | Le Codex s'ouvre quand l'essai est passé, sans « délai dépassé » : le préavis de la réponse compte les 4 s déjà en route. |

## 5. Chat sans envoi à tous

| # | Faire | Attendu |
|---|---|---|
| 1 | Les messages des métiers (`/recolte`, `/artisanat`) et de la magie arrivent toujours dans Général (export `addMessage` vers un joueur). | Comme avant. |
| 2 | (Développeur) Depuis une ressource serveur de test : `exports.vava_chat:addMessage(-1, 'essai')`. | `false, 'invalid_target'` ; personne ne reçoit rien. |

## 6. Audit statique

| # | Faire | Attendu |
|---|---|---|
| 1 | `./scripts/audit-reseau.sh` puis `./scripts/audit-reseau.sh --essai` (ou `./scripts/verifier.sh`). | Aucun BLOQUANT hors exceptions inscrites (plus aucune exception des zones de voix depuis T-014 ; exceptions transitoires de T-132 pour les configs des lots 3 et 4 depuis T-141) ; « ESSAI : OK (… cas) ». |

## 7. Ce que télécharge un joueur (T-132)

Depuis T-132, un module basculé ne sert aux joueurs que `shared/constants.lua`, `config_client.lua` et la logique
dont son client se sert ; `config.lua` (réglages du seul serveur) est en tête des `server_scripts`. Préparation :
préparation commune ([LISEZMOI.md](LISEZMOI.md)), mode développement pour l'exemple de l'Atelier
(`vava_example_atelier`) ; **A** Souverain, **B** hors du Conseil ; console `F8` de chaque client ouverte (repérer
`SCRIPT ERROR`). Hors jeu, `./scripts/poids-client.sh vava_atelier vava_arrival vava_chancellerie` donne ce que
chaque ressource sert (brut et gzip).

### 7-A — lot 1 : Atelier, arrivée, pont de la Chancellerie

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur. | `module 'vava_atelier' v1.2.0 prêt`, `module 'vava_arrival' v1.2.0 prêt`, `module 'vava_chancellerie' v1.7.1 prêt` (ou pont fermé si le serveur est lancé sans la Chancellerie, comme avant) ; aucune ligne « config.lua garde la forme d'avant 1.2.0 ». |
| 2 | **(2 joueurs)** A et B se connectent ; `F8` de chacun. | Aucune `SCRIPT ERROR` de `vava_atelier` ni de `vava_arrival`. |
| 3 | B : `resmon 1`. | `vava_chancellerie` n'apparaît pas (aucun script client) ; `vava_atelier` à 0,00 ms. |
| 4 | A : `F9`, puis `Échap`, puis `/atelier`. | L'Atelier s'ouvre et se ferme comme avant (atelier 1-1 à 1-3). |
| 5 | A : Paramètres › Raccourcis › FiveM. | « Ouvrir l'Atelier du Conseil » sur `F9` (atelier 1-7). |
| 6 | `stop vava_admin` ; A : `F9` ; puis `ensure vava_admin`. | « Le Registre du Conseil s'éveille : réessayez dans un instant. » (texte de refus venu de `config_client.lua`). |
| 7 | A : essai d'un panneau d'exemple (atelier 11-1), fiche en volet ; puis le laisser prendre fin sans le demander (`trial.maxMinutes = 1` dans `config.lua`, comme atelier 11-6). | Bandeau « Mode essai : vous seul voyez ce changement en jeu » ; à la fin, notification « L'essai de « … » a pris fin. » (textes de `config_client.lua`, durée lue au serveur dans `config.lua`). Remettre 30. |
| 8 | A : `/atelier_archives etat`. | Réponse au chat sous le nom « Atelier » (`texts.sayAuthor`, atelier 16). |
| 9 | **(2 joueurs)** A publie un changement de panneau (atelier 12-2), B est proche. | B le voit comme avant : rien d'autre n'a bougé. |
| 10 | Nouveau personnage de B (accueil 1). | Mot d'accueil, ligne de la dotation, Codex ouvert à « Vivre à Eldoria » ; avec une interface ouverte, l'accueil attend (accueil 2). |
| 11 | Chancellerie : relier un compte (chancellerie 2), page Réseau (chancellerie 3). | Comme avant. |
| 12 | Serveur arrêté ; remplacer `modules/vava_atelier/config.lua` par celui de 1.1.0 (`git show 457611f:modules/vava_atelier/config.lua`) ; démarrer. | Console : « config.lua garde la forme d'avant 1.2.0 … » ; l'Atelier s'ouvre quand même. Remettre le fichier de 1.2.0. |
| 13 | Serveur arrêté ; `keys.open = 'F7'` dans `modules/vava_atelier/config_client.lua` ; démarrer ; un **nouveau** joueur se connecte. | `F7` ouvre l'Atelier chez lui (FiveM garde la touche déjà enregistrée chez A : attendu). Remettre `F9`. |
| 14 | Si possible : avant de passer à la branche (serveur sur `main`) puis après, vider le cache FiveM d'un client, se connecter, puis relever la taille de `cache/files/<ressource>/resource.rpf` (dossier de données de FiveM du client) pour `vava_atelier`, `vava_arrival`, `vava_chancellerie` ; ou mesurer le téléchargement. | Ordre de grandeur cohérent avec la colonne `total` de `./scripts/poids-client.sh vava_atelier vava_arrival vava_chancellerie` (Lua, page, images et manifeste) : `vava_atelier` ≈ 157 Ko (≈ 178 avant), `vava_arrival` ≈ 16,4 Ko (≈ 28,5 avant), `vava_chancellerie` ≈ 2,4 Ko, son seul manifeste (≈ 9,5 avant) ; noter au rapport les tailles relevées et si FXServer compresse. |
| 15 | Mise à jour par la Chancellerie (1.8.5) d'un serveur où `config_client.lua` de l'Atelier a été modifié à la main. | Le fichier modifié est gardé, la nouvelle version posée à côté en `config_client.lua.nouveau` (comme `config.lua`). |

### 7-B — lot 2 (T-141) : métiers et vivres

Modules : `vava_skills` 1.3.0, `vava_farming` 1.8.0, `vava_crafting` 1.6.0, `vava_gathering` 1.7.0, `vava_provisions`
1.1.0. Préparation de [metiers.md](metiers.md) § 0 et d'[eau.md](eau.md) § 0 (objets du catalogue, lieux d'exemple,
réglages pour aller vite). Hors jeu, `./scripts/poids-client.sh vava_skills vava_farming vava_crafting vava_gathering
vava_provisions` donne ce que chaque ressource sert.

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur. | `module 'vava_skills' v1.3.0 prêt`, `module 'vava_farming' v1.8.0 prêt`, `module 'vava_crafting' v1.6.0 prêt`, `module 'vava_gathering' v1.7.0 prêt`, `module 'vava_provisions' v1.1.0 prêt` ; aucune ligne « config.lua garde la forme d'avant … » ; aucun refus de config (`vava_provisions` relit sa config entière au démarrage, `vava_gathering` ses zones). |
| 2 | **(2 joueurs)** A et B se connectent ; `F8` de chacun ; ouvrir chaque interface ci-dessous. | Aucune `SCRIPT ERROR` des cinq modules, au chargement comme pendant les gestes. |
| 3 | B : `resmon 1`, loin de tout lieu de métier, puis près du bourg. | Comme avant (métiers 6) : 0,00 ms loin de tout ; les cinq modules présents (ils ont tous des scripts client). |
| 4 | B : `K`, puis `K` de nouveau. | Le livre s'ouvre (métiers 2-1) et se ferme à la même touche (`keys.open`, lue dans `config_client.lua`). Si la fiche ne répond pas (rare), le texte « Le livre des compétences est indisponible pour le moment. » vient aussi de `config_client.lua`. |
| 5 | B : Paramètres › Raccourcis › FiveM. | « Ouvrir le livre des compétences » (`K`), « Récolter (nœud proche) » (`E`), « Ouvrir le panneau des zones de récolte » (`O`), « Utiliser une station d'artisanat » (`E`), « Cultiver (emplacement, puits ou grenier proche) » (`E`), « Puiser ou boire (point d'eau proche) » (`E`). |
| 6 | Récolte : métiers 3.1-1 et 3.1-2 (props, blips, panneau `O`), 3.2-2 et 3.2-4 (couper, marcher pendant le geste), 3.3-1 à 3.3-3 (pêche). | Comme avant : arbres et rochers à 80 m, blips des zones, invite, geste annulé au-delà de 1,5 m, barre de tension tenue à 60 %. |
| 7 | Artisanat : métiers 4-1 à 4-4 (fourneau, forge), 4-8 (baptême d'un chef-d'œuvre), 4-9 (réparation). | Comme avant : props des stations, invite, animation de la station, nom refusé sous 2 ou au-delà de 32 lettres (boîte du client), réparation de 4 s. |
| 8 | Agriculture : métiers 5-1 à 5-4 (planter, arroser), 5-6 (récolte à la faucille), 5-8 (grenier) ; puits du bourg (seau). | Comme avant : props des plantes par stade, invite, gestes et leurs animations, prop du puits. |
| 9 | Vivres : eau 4 à 8 (approche, puiser, boire, pas soif, patienter), eau 18 (outre fendue : `tearChance = 1` dans `config.lua`). | Comme avant : props des points d'eau, invite « Puiser ou boire », textes de réussite, de refus et d'outre fendue (venus de `config_client.lua`). |
| 10 | **(2 joueurs)** Leçon devant un élève (métiers 2-15) ou récolte communale au champ (métiers 5-6, A récolte, B regarde). | B voit le geste et les props comme avant ; la leçon est comptée (élève à 10 m), ou la plante récoltée disparaît chez B. |
| 11 | Serveur arrêté ; remplacer `modules/vava_farming/config.lua` par celui de 1.7.0 (`git show 00db326:modules/vava_farming/config.lua`) ; démarrer. | Console : « config.lua garde la forme d'avant 1.8.0 … » ; l'agriculture marche quand même. Remettre le fichier de 1.8.0. |
| 12 | Serveur arrêté ; `keys.open = 'J'` dans `modules/vava_skills/config_client.lua` ; démarrer ; un **nouveau** joueur se connecte. | `J` ouvre le livre chez lui (FiveM garde la touche déjà enregistrée chez A : attendu). Remettre `K`. |
| 13 | Serveur arrêté ; `streaming.subscribeSlack = 35.0` dans `modules/vava_gathering/config.lua` ; démarrer ; B arrive au galop vers la Forêt de Brume (métiers 3.4-8). | Le réglage est pris (le serveur le lit dans `config.lua`, ajouté à la table `streaming`) ; arbres présents avant d'arriver. Remettre 20.0. |
| 14 | Si possible : comme 7-A-14, avant (serveur sur `main`) et après, taille de `cache/files/<ressource>/resource.rpf` pour les cinq modules. | Ordre de grandeur cohérent avec la colonne `total` de `poids-client.sh` : `vava_farming` ≈ 127 Ko (≈ 151 avant), `vava_crafting` ≈ 133 Ko (≈ 149), `vava_gathering` ≈ 119 Ko (≈ 131), `vava_skills` ≈ 77 Ko (≈ 87), `vava_provisions` ≈ 81 Ko (≈ 84) ; noter au rapport. |

7-C (lot 3, T-142), 7-D (lot 4, T-143) : écrits par chaque tâche sur le même modèle (démarrage sans ligne d'ancienne
forme ; `F8` sans `SCRIPT ERROR` des modules du lot ; un tour des gestes de chaque module, en renvoyant à sa
procédure ; un test **(2 joueurs)** par lot).

## Ce qui n'est pas compté

GlobalState, state bags, et les envois que les modules font encore eux-mêmes par `TriggerClientEvent` (inventaire,
magie, chat, santé, compétences, Codex…) : le pied de `/vava_reseau` le rappelle. Ils le seront quand chaque module
passera par `core.net`.

## À vérifier en jeu (ce qui n'a pas pu l'être hors jeu)

- Présence de `msgpack.pack_args`, `TriggerClientEventInternal` et `TriggerLatentClientEventInternal` sur la version de
  FXServer du serveur (1-1), et cible passée en texte acceptée par les deux fonctions internes : si un envoi interne
  échoue, la console dit « envoi interne du runtime en échec (…) : estimation à partir de maintenant » et tout repasse
  par `TriggerClientEvent` ; à remonter avec la ligne. Secours : `net.mode = 'estimate'` dans `config/server.lua`.
- Débit réel d'un envoi latent à 64 Ko/s (4-1, 4-2), comparé à `netgraph 1`.
- Ordre : un fiable envoyé après un latent arrive avant lui (4-1) ; ordre entre deux latents (4-3).
- Le préavis allonge bien l'attente : ouvrir le Codex sur une connexion bridée (limiteur de débit du système) ne doit
  pas donner de « délai dépassé ».
- Écart entre les octets du compteur et `netgraph` pour un envoi connu (l'en-tête réseau n'est pas compté).
- Coût serveur d'un `sendNear` à beaucoup de joueurs (profiler de FXServer) : attendu bien sous 0,1 ms.
