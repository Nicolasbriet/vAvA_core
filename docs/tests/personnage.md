# Connexion et personnage — procédure de test en jeu

Procédure pour vérifier en jeu l'arrivée d'un joueur et la vie de ses personnages : compte, création, apparence,
sélection, suppression, reconnexion, position, sauvegarde et temps de jeu. Modules : `vAvA_core` 0.9.0,
`vava_appearance` 1.0.1, `vava_characters_ui` 1.0.1, et l'outil de développement `vava_dev_characters` 1.3.0. Comptez
une heure et demie seul, une demi-heure de plus pour les tests marqués **(2 joueurs)**. Un test se cite
« personnage 4-2 ».

## 0. Préparation

1. **Préparation commune** (ordre de démarrage, compte du Conseil, consoles) : voir [LISEZMOI.md](LISEZMOI.md). Le
   Registre du Conseil (`F10`) → Joueurs sert ici à lire le numéro de compte, le temps de jeu et la position d'un
   joueur.
2. **Outil de développement** : `vava_dev_characters` (catégorie `[vava-dev]` de la Chancellerie, ou
   `ensure vava_dev_characters` dans la console du serveur). Jamais en production : il exige `set vava_env dev` au
   `server.cfg` (sinon rien n'est offert) et n'obéit qu'au Souverain (droit `staff`) ou à l'ACE `vava.dev`, voir
   [developpement.md](developpement.md) ; pour B, hors du Conseil (`/perso quitter` au § 6) :
   `add_ace identifier.license:<licence de B> vava.dev allow` en console. Il apporte `/perso liste | creer <prénom> <nom> <h|f> | choisir <id> | quitter | supprimer <id>` et
   `/respawn`. `/perso quitter` est le seul moyen de revenir à la sélection sans se reconnecter : le jeu de production
   n'a pas de commande pour cela. Les réponses s'affichent dans le chat et dans `F8`
   (`[vAvA][INFO][vava_dev_characters] …`). Sur l'écran de sélection le chat est fermé : tapez la commande dans
   `F8`, sans barre oblique (`perso liste`) ; que `F8` s'ouvre par-dessus cet écran est à confirmer.
   `/perso creer` passe par le RPC du core `core:characters:create` : le personnage n'a **aucune apparence** (ped par
   défaut). Ne vous en servez que pour la section 8, et supprimez ensuite ces personnages.
3. **Comptes** : le test 1-1 demande un compte Rockstar qui n'est jamais venu (celui du second joueur, par exemple) ou
   une base neuve ; un compte ne s'efface pas tant qu'il a des personnages (clé étrangère `ON DELETE RESTRICT`). Si
   la liste blanche Discord de la Chancellerie est active, les deux comptes doivent y être admis.
4. **Base** : gardez ouvertes les requêtes du § 11.
5. **Réglages pour aller vite** (facultatif, à remettre après ; les attendus citent les valeurs par défaut) :
   - `config/server.lua` du core : `persistence.positionSampleMs = 5000` (défaut `15000`) et
     `persistence.saveIntervalMs = 60000` (défaut `300000`) : relevé de position et de temps de jeu toutes les 5 s,
     sauvegarde groupée chaque minute ; `characters.uniqueNames = true` (défaut `false`) le temps des tests 2-12 et
     2-13. La config du core se relit au redémarrage du serveur (`vava_saveall`, `quit`, relance) : un
     `restart vAvA_core` arrêterait aussi les modules qui en dépendent (à confirmer).
   - `vava_appearance/config.lua` : `createRateLimit = { capacity = 10, refillPerSecond = 1 }` (défaut
     `{ capacity = 2, refillPerSecond = 0.05 }`) si vous enchaînez les créations ; à remettre avant la section 8.
     `restart vava_appearance`, puis `ensure vava_characters_ui` (voir 9-4).
6. **Ressource jetable pour 8-11 à 8-14** (jamais versionnée, jamais en production) : un dossier `t027_statebag`
   dans `resources/`, qui imite un client modifié réécrivant son propre statebag.
   **Sans objet depuis `vava_inventory` 1.7.0 (T-045)** : la main n'est plus un champ `public` (elle va au seul joueur,
   et aux joueurs proches par le statebag de son ped) et aucun module du dépôt ne déclare plus de champ public ;
   8-10b à 8-14 ne peuvent donc plus se jouer tels quels, et `/t027` ne montre plus rien. La garde du core reste
   vérifiée hors jeu (`tests/spec/core_sync_spec.lua`) ; celle de la main se teste dans
   [inventaire.md](inventaire.md), § 11b (8 et 9). Gardé pour le jour où un module déclarera un champ public :
   ```lua
   -- fxmanifest.lua
   fx_version 'cerulean'
   game 'gta5'
   lua54 'yes'
   client_script 'client.lua'

   -- client.lua : /t027 <objet> réécrit la main ; /t027 vide la vide ; /t027rafale <objet> réécrit 30 fois
   local function forge(item)
       if item == 'vide' then return LocalPlayer.state:set('vava_inventory:hands', nil, true) end
       local decl = (GlobalState['vava_inventory:heldModels'] or {})[item]
       if not decl then return print('objet sans « held » : ' .. tostring(item)) end
       LocalPlayer.state:set('vava_inventory:hands', { id = 999999, item = item, model = decl.model,
           bone = decl.bone, offset = decl.offset, rotation = decl.rotation }, true)
   end
   RegisterCommand('t027', function(_, args) forge(args[1] or 'hache_fer') print('main réécrite') end, false)
   RegisterCommand('t027rafale', function(_, args)
       CreateThread(function() for _ = 1, 30 do forge(args[1] or 'hache_fer') Wait(10) end print('rafale finie') end)
   end, false)
   ```
   `ensure t027_statebag` chez tout le monde (console du serveur), `stop t027_statebag` puis suppression du dossier
   après la section 8.

## 1. Première connexion et compte

| # | Faire | Attendu |
|---|---|---|
| 1 | Se connecter avec un compte jamais venu. | Pendant la connexion, FiveM affiche « Vérification de votre compte… » (bref). Console du serveur : `[vAvA][INFO][accounts] nouveau compte #N` — c'est ce `N` que demande `vava_conseil`. `vava_accounts` : une ligne `N` avec `license:…`, `created_at`, `last_seen_at` ; aucune autre colonne (ni IP, ni pseudo). |
| 2 | Attendre la fin du chargement. | Avec `vava_loading` : l'éclair de l'écran de chargement se dissout sur la sélection, sans image noire ([chargement.md](chargement.md) § 3) ; sans lui : fondu au noir. Puis « Registre des âmes », « Choisissez qui vous serez » : trois cartes « Nouveau personnage » / « Emplacement libre », « 3 emplacements libres ». Ni chat, ni jauges, ni radar. Le numéro de compte n'est pas montré au joueur. |
| 3 | `Échap`, clics hors des cartes. | Rien : on ne quitte cet écran qu'en jouant un personnage. |
| 4 | `F8` → `disconnect`, puis revenir. | Aucune ligne `nouveau compte` ; même compte `N` ; `last_seen_at` mis à jour (à l'arrivée et au départ). |
| 5 | **(2 joueurs)** B reste sur la sélection ; A ouvre le Registre (`F10`) → Joueurs. | Ligne de B : « En sélection de personnage », « <pseudo FiveM> · Compte n° N », sans temps de jeu ; dans sa fiche, Temps de jeu « — ». |
| 6 | (Facultatif) Se connecter juste après le lancement du serveur, avant la ligne `vAvA_core v0.8.0 prêt (API v1)`. | « Le serveur démarre, merci de patienter… », puis entrée normale dès que le core est prêt. Au-delà de 60 s (`players.coreWaitTimeoutMs`) : « Le serveur démarre, réessayez dans un instant. » |

## 2. Création — identité, noms, nombre maximal

| # | Faire | Attendu |
|---|---|---|
| 1 | Cliquer « Nouveau personnage ». | Éditeur « Nouveau personnage », « Étape 1 / 7 » ; onglets Identité, Héritage, Visage, Cheveux, Peau, Maquillage, Tenue ; ped masculin à droite, vue « Silhouette », posé au sol dans la scène provisoire (piste de McKenzie, Grapeseed : `scene` de `vava_characters_ui/config.lua`), cadré par la caméra (à confirmer : cadrage des trois vues à cet endroit) ; légende « Glisser pivoter · Q vers la gauche · E vers la droite » ; curseur dans le champ Prénom ; « Créer le personnage » grisé. |
| 2 | Prénom `Aldric`, Nom `Morvan`. | Bouton actif. Sous le Nom : « 2 à 24 lettres. Espace, apostrophe et trait d'union autorisés entre deux lettres. » : ce rappel est tiré de `characters.name` du core (reçu avec la liste), pas écrit dans l'interface. |
| 3 | Essayer tour à tour : `A` ; `Jean2` ; `-Jean` ; `Jean-` ; `Jean--Pierre` ; `Jean  Pierre` (deux espaces) ; `d’Aubigné` (apostrophe typographique). | « Ce nom n'est pas valide. » sous le champ, bouton grisé. |
| 4 | `Jean-Pierre`, `d'Aubigné`, `Le Roux`, `Éloïse`, `Œdipe` ; un nom de 24 lettres ; ` Jean ` (espaces autour). | Acceptés. Le champ refuse la 25e lettre. Les espaces de bord sont retirés à l'enregistrement. |
| 5 | Prénom `Łucja` (ou `Weiß`). | Refusé dès la saisie : « Ce nom n'est pas valide. », bouton grisé (`Ł` et `ß` sont hors de `characters.name.letters`, que l'interface reçoit du serveur). |
| 5b | (Facultatif, redémarrage du serveur) `characters.name.maxLength = 12` et retirer `-` de `separators` dans `config/server.lua` ; rouvrir l'éditeur. Remettre ensuite. | « 2 à 12 lettres. Espace et apostrophe autorisés entre deux lettres. » ; `Jean-Pierre` refusé à la saisie ; le champ s'arrête à 12 lettres. |
| 6 | Sexe : « Femme » sans rien avoir modifié ; puis modifier un trait (Visage) et revenir à « Homme ». | Premier changement sans confirmation (ped féminin). Second : « Changer de sexe ? » / « L'apparence sera réinitialisée. », boutons « Changer » et « Continuer » ; après « Changer », apparence de départ du nouveau sexe, prénom et nom conservés. |
| 7 | « Créer le personnage », puis « Continuer ». | « Créer ce personnage ? » / « Aldric Morvan rejoindra le royaume. Son nom ne pourra plus être modifié. » ; « Continuer » ramène à l'éditeur, rien n'est créé. |
| 8 | « Créer le personnage », puis « Créer ». | « Création… », l'écran se ferme, fondu ; apparition au point par défaut (−269,4 ; −955,3 ; 31,2), cap 205,8, avec l'apparence choisie. Console : `[vAvA][INFO][characters] compte #N : personnage #M créé`. En base : `first_name`, `last_name`, `sex`, `data` avec la clé `vava_appearance:data`, `play_seconds` 0, positions vides jusqu'à la première sauvegarde (§ 6). |
| 9 | Croix « Abandonner » ou `Échap` : d'abord sans rien saisir, puis après une saisie. | Sans saisie : retour direct à la sélection. Sinon : « Abandonner la création ? » / « Les choix effectués seront perdus. » ; `Échap` sur cette fenêtre vaut « Continuer ». |
| 10 | Créer trois personnages (retour à la sélection entre deux par `/perso quitter` ou une reconnexion). | Après le troisième : plus de carte « Nouveau personnage », « Aucun emplacement libre » (`characters.maxPerAccount` = 3). |
| 11 | Deux personnages du même nom (même compte, ou deux comptes). | Accepté : `characters.uniqueNames` vaut `false`. |
| 12 | Avec `uniqueNames = true` (§ 0.5) : recréer `Aldric Morvan`, puis `aldric morvan`, puis `Áldric Morvan`. | « Ce nom est déjà porté par un autre personnage. », retour sur Identité : casse et accents ne comptent pas. Une fois Aldric Morvan supprimé (4-4), le nom est de nouveau libre. |
| 13 | **(2 joueurs)** Avec `uniqueNames = true`, A et B saisissent le même nom libre et cliquent « Créer » ensemble. | Un seul est créé ; l'autre lit « Ce nom est déjà porté par un autre personnage. ». Jamais deux. |

## 3. Apparence — `vava_appearance`

| # | Faire | Attendu |
|---|---|---|
| 1 | « Suivant » / « Précédent » à travers les sept onglets. | « Étape n / 7 » ; « Suivant » disparaît sur Tenue. La caméra glisse (550 ms) vers « Visage » pour Héritage, Visage, Cheveux, Peau et Maquillage, vers « Silhouette » pour Identité et Tenue ; les boutons « Visage » et « Silhouette » changent la vue à la main. |
| 2 | Héritage : Mère, Père, Ressemblance, Teint. | « Visage 1 » à « Visage 46 » ; curseurs de 0 à 100 % entre Mère et Père ; le ped change en direct. |
| 3 | Visage : les 20 curseurs. | Six groupes (Nez, Sourcils, Pommettes et joues, Yeux et lèvres, Mâchoire et menton, Cou), de −100 à +100 ; chaque trait bouge seul. |
| 4 | Cheveux. | Coupe et Variante (le nombre de variantes suit la coupe), Couleur, Reflets ; Sourcils ; Barbe et Pilosité du torse pour un homme seulement ; Couleur des yeux « Teinte 1 » à « Teinte 32 ». |
| 5 | Peau, puis Maquillage. | Peau : Imperfections, Rides, Teint, Marques du soleil, Taches de rousseur (Style « Aucun » ou numéro, Intensité). Maquillage : Maquillage des yeux, Fard à joues, Rouge à lèvres ; une couleur pour le fard et le rouge seulement. |
| 6 | Tenue. | Haut, Sous-vêtement, Bras, Bas, Chaussures (Modèle, Variante) ; « Ajustez les bras si le haut laisse apparaître des manques. » ; Couvre-chef, Lunettes, Boucles d'oreilles à « Aucun », Variante grisée tant que le modèle est « Aucun ». |
| 7 | « Aléatoire » puis « Réinitialiser » sur chaque onglet. | Seules les parties de l'onglet changent ; les Bras ne sont jamais tirés au sort ; « Réinitialiser » rend l'apparence de départ de cet onglet. |
| 8 | Pivoter : `Q`, `E`, glisser sur l'aperçu ; puis taper `q` et `e` dans le champ Prénom. | 15° par touche, rotation au glisser, caméra immobile ; dans le champ, les lettres s'écrivent sans faire tourner le ped. |
| 9 | Créer (2-8) et comparer avec l'aperçu. | Personnage identique en jeu ; aucun ped par défaut visible avant l'apparence (elle est posée écran noir). |
| 10 | Se reconnecter et jouer ce personnage. | Apparence identique. |
| 11 | **(2 joueurs)** A regarde B en jeu. | A voit B tel que B s'est créé (visage, cheveux, tenue). |
| 12 | **(2 joueurs)** A se tient au point d'apparition par défaut pendant que B crée un personnage ; puis A va à la scène de création (piste de McKenzie, Grapeseed). | Au point d'apparition, A n'entre pas dans la scène de B : elle est ailleurs. À la scène, A ne voit pas le ped d'aperçu de B (ped local) ; B, lui, voit A passer derrière son aperçu : c'est pourquoi la scène doit rester un lieu où personne ne va (provisoire, `-- PLACEHOLDER`). |

## 4. Sélection et suppression

| # | Faire | Attendu |
|---|---|---|
| 1 | Revenir à la sélection avec un ou plusieurs personnages. | Une carte par personnage : initiales, « Prénom Nom », « Homme · Registre n° M » (`M` = `vava_characters.id`), « Jouer », corbeille (« Supprimer Prénom Nom » au survol) ; puis les emplacements libres. |
| 2 | « Jouer ». | « Entrée… », tous les boutons grisés ; l'écran se ferme ; apparition à la dernière position enregistrée (point par défaut s'il n'en a pas), apparence posée avant le fondu. `last_played_at` mis à jour. Registre : son nom et son temps de jeu. |
| 3 | Corbeille, puis « Continuer ». | « Supprimer ce personnage ? » / « <Prénom Nom> sera retiré du registre. Cette action est définitive. » ; rien ne change. |
| 4 | Corbeille, puis « Supprimer ». | La carte devient « Nouveau personnage », le compteur gagne un emplacement. Console : `compte #N : personnage #M supprimé`. En base, la ligne reste avec `deleted_at` renseigné. |
| 5 | Se reconnecter. | Le personnage supprimé n'apparaît plus ; l'emplacement libéré accepte une nouvelle création, même si le compte en avait trois. |

## 5. Reconnexion et position

| # | Faire | Attendu |
|---|---|---|
| 1 | Marcher jusqu'à un endroit reconnaissable, s'arrêter 20 s, relever la position (Registre → Joueurs → vous → Position, au dixième), puis `F8` → `disconnect`. | En base, aussitôt : `position_x/y/z`, `heading`, `play_seconds` écrits (sauvegarde immédiate au départ). |
| 2 | Revenir, « Jouer ». | Même endroit à 1 m près (`persistence.positionEpsilon`), même orientation ; jamais le point par défaut. |
| 3 | Courir, puis se déconnecter dans les 3 s. | Retour au point exact du départ si le ped était encore lisible à ce moment, sinon au dernier relevé, au plus 15 s de course en arrière (`positionSampleMs`) (à confirmer). |
| 4 | `/perso quitter`. | Fondu au noir, sélection rouverte avec la liste ; Registre : « En sélection de personnage ». Position et temps de jeu écrits comme à une déconnexion. |
| 5 | Jouer un premier personnage jusqu'à un endroit X, `/perso quitter`, amener un second ailleurs, revenir au premier. | Chacun reprend à sa propre place. |
| 6 | Se déconnecter, revenir et « Jouer » le plus vite possible. | Entrée normale. Si « Une action est déjà en cours. » s'affiche une fois, réessayer : le personnage finissait d'être sauvegardé par la session précédente (voulu). |

## 6. Sauvegarde et temps de jeu

| # | Faire | Attendu |
|---|---|---|
| 1 | En jeu, marcher 20 s ; regarder la base. | Position inchangée en base : le relevé reste en mémoire jusqu'à la sauvegarde groupée (toutes les 5 min, `saveIntervalMs`), sauf si elle tombe pendant ce temps. |
| 2 | Console du serveur : `vava_saveall`. | `[vAvA][INFO][persistence] vava_saveall : 1 personnage(s) sauvegardé(s)` (un par personnage en jeu modifié) ; position et `play_seconds` à jour en base. |
| 3 | `vava_saveall` à nouveau, dans la seconde. | `0 personnage(s) sauvegardé(s)`, sauf si un relevé (15 s) ou un module (santé, besoins) a modifié le personnage entre les deux. |
| 4 | Rester 5 min en jeu sans rien lancer. | La base se met à jour seule. |
| 5 | Registre → Joueurs après quelques minutes de jeu. | « <pseudo> · Compte n° N · 12 min », qui augmente (« 1 h 05 » au-delà d'une heure) ; même valeur dans la fiche. |
| 6 | Noter `play_seconds` en base après une déconnexion ; revenir, rester 3 min sur la sélection, « Jouer », se déconnecter dans les 30 s. | `play_seconds` n'a gagné que les secondes réellement jouées (moins de 30) : ni les 3 min de sélection, ni le chargement. |
| 7 | Même chose avec `/perso quitter` : 3 min sur la sélection, puis rejouer le personnage. | Le temps reprend à la valeur laissée. |
| 8 | **(2 joueurs)** B joue 2 min, `/perso quitter`, attend 2 min sur la sélection, rejoue ; A suit B dans le Registre. | Pendant l'attente, ligne de B sans temps de jeu ; ensuite, reprise depuis sa valeur, sans les 2 min. |
| 9 | (À faire en dernier.) Marcher 20 s puis, sans `vava_saveall`, `quit` dans la console. Recommencer avec `vava_saveall` juste avant `quit`. | Sans : `[vAvA][WARN][core] 1 personnage(s) avec des modifications non sauvegardées : lancez vava_saveall avant d'arrêter` (à confirmer : selon l'ordre d'arrêt de FiveM, le départ du joueur peut passer avant). Avec : aucun avertissement, position à jour au redémarrage. |

## 7. Connexions doubles et départs en pleine action

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs, même compte Rockstar sur deux machines)** Le premier est en jeu, le second se connecte. | Refus : « Ce compte est déjà connecté au serveur. » ; console : `[vAvA][WARN][accounts] connexion refusée : le compte #N est déjà connecté` ; le premier ne remarque rien. |
| 2 | Fermer FiveM (`Alt+F4`) pendant l'écran de chargement, puis se reconnecter aussitôt. | Refus « Ce compte est déjà connecté au serveur. » quelques secondes ; console, 5 à 10 s après la fermeture (deux relevés manqués, `players.connectCheckMs` = 5000) : `connexion du compte #N abandonnée pendant le chargement : license libérée` ; ensuite la connexion passe. Au pire 120 s (`connectTimeoutMs`). |
| 3 | En jeu, tuer FiveM depuis le gestionnaire des tâches, se reconnecter aussitôt. | « Ce compte est déjà connecté au serveur. » tant que le serveur n'a pas constaté le départ (délai de FXServer, à confirmer) ; ensuite entrée normale, personnage à sa dernière position relevée. |
| 4 | Dans l'éditeur, nom saisi et apparence modifiée : `Alt+F4`. | Rien en base ni dans la console ; au retour, l'emplacement est toujours libre. |
| 5 | « Créer le personnage » → « Créer », puis `Alt+F4` aussitôt. | Au retour, soit le personnage est dans la liste avec son apparence complète, soit rien. Jamais un personnage sans apparence, jamais un double. |
| 6 | « Jouer », puis `Alt+F4` pendant l'écran noir de l'apparition. | Au retour, le personnage se choisit normalement (« Une action est déjà en cours. » au plus une fois) ; position inchangée, `play_seconds` inchangé à quelques secondes près (le temps ne compte qu'après l'apparition confirmée). |

## 8. Tentatives de triche

Les commandes `perso` se tapent dans `F8` sur la sélection, ou dans le chat en jeu (§ 0.2).

| # | Faire | Attendu |
|---|---|---|
| 1 | Double-clic ou clics répétés sur « Jouer ». | Une seule entrée : les boutons sont grisés dès « Entrée… ». |
| 2 | Sur la sélection, `perso choisir <id>` deux fois de suite, puis cinq fois en rafale. | La première charge le personnage, la suivante répond `sélection : refusé (busy)` ou `(wrong_state)`. Au-delà de trois en rafale : `sélection : appel impossible (rate_limited)` (3, puis 1 toutes les 5 s). |
| 3 | **(2 joueurs)** A note le « Registre n° » d'un personnage de B ; sur sa propre sélection : `perso choisir <ce n°>`, `perso supprimer <ce n°>`. | `sélection : refusé (not_owner)`, `suppression : refusé (not_owner)` ; le personnage de B est intact. |
| 4 | En jeu : `/perso supprimer <n° du personnage joué>`, `/perso creer Jean Dupont h`. | `suppression : refusé (wrong_state)`, `création : refusé (wrong_state)` : on ne crée et ne supprime qu'en sélection. |
| 5 | Sur la sélection, avec trois personnages : `perso creer Jean Dupont h`. | `création : refusé (too_many_characters)`. |
| 6 | Avec un emplacement libre : `perso creer J Dupont h`, `perso creer Jean Dupont2 h`, `perso creer Abcdefghijklmnopqrstuvwxy Dupont h` (25 lettres), en laissant 20 s entre deux. | `création : refusé (invalid_name)` chaque fois. |
| 7 | Avec un seul personnage, après une minute sans création : `perso creer` trois fois en rafale, noms valides. | Deux créés ; le troisième : `création : appel impossible (rate_limited)` (la limite passe avant le maximum) ; console du serveur : `[vAvA][WARN][ratelimit] joueur S : limite dépassée sur core:characters:create`. Ensuite, une création toutes les 20 s. |
| 8 | `perso supprimer <id>` trois fois en rafale sur ses propres personnages. | Deux supprimés ; le troisième : `suppression : appel impossible (rate_limited)` (2, puis 1 toutes les 20 s). |
| 9 | À terre (`/aterre`) : `/perso quitter` puis rejouer le personnage ; puis à terre, se déconnecter et revenir. | Toujours à terre au retour, le temps déjà passé à terre conservé : changer de personnage ou partir ne relève pas (détails : procédure santé). |
| 10 | Joueur sans droit ACE : `/vava_saveall` dans le chat. | Aucune sauvegarde lancée : la commande est restreinte (`RegisterCommand(…, true)`, portée console au registre des commandes) ; aucune ligne `vava_saveall :` dans la console du serveur. |
| 10b | **Sans objet depuis `vava_inventory` 1.7.0 (§ 0.6).** **(2 joueurs)** Témoin, **sans** `/t027` (core 0.9.0) : A prend vraiment en main la hache, puis la pioche (décalages non entiers, `0.1`, `0.02`), et reste immobile 30 s chaque fois face à B. | Aucune ligne `[sync]` dans la console du serveur pendant ces 30 s ; chez B, l'objet reste stable dans la main de A, sans clignoter. C'est ce qui montre qu'une publication normale du serveur ne déclenche ni remise ni avertissement (valeur relue égale à l'arrondi près). Une ligne `[sync]` ici est un défaut à remonter, avec sa ligne complète. |
| 11 | **Sans objet depuis `vava_inventory` 1.7.0 (§ 0.6).** **(2 joueurs)** Champ public réécrit par son client (core 0.9.0, § 0.6). A et B face à face, mains vides. A tape `/t027 hache_fer`. | Chez B, la hache apparaît au plus un quart de seconde dans la main de A puis disparaît (`sync.publicGuardDelayMs` = 250) ; elle n'y revient pas. Console du serveur : `[vAvA][WARN][sync] joueur <A> : champ(s) public(s) réécrit(s) par son client, valeur du serveur remise (vava_inventory:hands)`. Rien ne change dans la besace de A (`I`) : la main y est toujours vide. Si la hache **reste** chez B : le serveur ne voit pas la réécriture (voir § 12), à noter tel quel. |
| 12 | **Sans objet depuis `vava_inventory` 1.7.0 (§ 0.6).** **(2 joueurs)** A prend vraiment la hache en main (besace → Mains), puis `/t027 pioche_fer` (ou un autre objet à « held » du catalogue), puis `/t027 vide`. | Chaque fois, B revoit la **hache** dans la main de A après un quart de seconde au plus. Une seule ligne `[sync]` par 10 s (les suivantes comptées `[n message(s) similaire(s) ignoré(s)]`). |
| 13 | **Sans objet depuis `vava_inventory` 1.7.0 (§ 0.6).** **(2 joueurs)** A tape `/t027rafale hache_fer` (30 réécritures en 0,3 s environ), mains vides. | Chez B, la hache clignote au plus pendant la rafale puis disparaît ; console : au plus une remise par quart de seconde (pas trente lignes, pas de ralentissement du serveur). Resmon de `vAvA_core` côté serveur (`resmon 1` dans la console, si disponible) : pic bref, retour au repos. Chez B, `netgraph 1` dans `F8` : relever le débit pendant la rafale et 10 s après ; attendu de l'ordre de 800 o/s par joueur témoin pendant la rafale, puis retour au niveau d'avant (noter les chiffres tels quels). Si A enchaîne les rafales sans rien prendre en main, dès la quatrième remise : une ligne `remis 3 fois de suite sans nouvelle publication`, puis des remises de plus en plus tardives (jusqu'à 10 s), jamais abandonnées. |
| 14 | **Sans objet depuis `vava_inventory` 1.7.0 (§ 0.6).** Sans second joueur : A tape `/t027 hache_fer` sur l'écran de sélection (`F8`, `t027 hache_fer`), avant de choisir un personnage. | Même ligne `[sync]` dans la console : un champ public est remis vide tant qu'aucun personnage n'est chargé. Puis « Jouer » : la main est celle du personnage (vide ou son objet), jamais la hache forgée. |
| 15 | Si `vava_example` est démarré : console du serveur `example_ping <n° de A>`. | `[vAvA][INFO][vava_example] joueur N : GetGameTimer client = … ms (déclaré par le client)` : un appel serveur → client avec `returns` fonctionne toujours (0.9.0 exige `returns`). |

## 9. Redémarrage des modules en cours de partie

Les commandes se tapent dans la console du serveur.

| # | Faire | Attendu |
|---|---|---|
| 1 | En jeu : `restart vava_characters_ui`. | Rien de visible. Ensuite `/perso quitter` : l'écran de sélection s'ouvre normalement. |
| 2 | Sur la sélection : `restart vava_characters_ui`. | L'écran disparaît puis revient avec la liste (la ressource rouvre l'écran quand le joueur attend un personnage), souris et clavier rendus à l'interface. |
| 3 | Dans l'éditeur : `restart vava_characters_ui`. | Un instant d'écran noir, puis retour à la sélection, choix perdus. Le ped d'aperçu de l'ancienne instance a disparu (le module le retire à l'arrêt, avec sa caméra et le radar caché) : un seul ped dans la scène dès qu'on rouvre l'éditeur. |
| 3b | Dans l'éditeur : `stop vava_characters_ui`, attendre, `start vava_characters_ui`. | À l'arrêt : écran noir, souris et clavier rendus au jeu, aucune caméra figée ni ped d'aperçu (comme l'attente de sélection du core). Au démarrage : la sélection revient avec la liste. |
| 4 | En jeu : `restart vava_appearance`. | Console : `[vAvA][INFO][modules] module 'vava_appearance' arrêté`, puis `module 'vava_appearance' v1.0.1 prêt`. Le ped garde son apparence. FiveM arrête aussi `vava_characters_ui`, qui en dépend (à confirmer dans la console) : `ensure vava_characters_ui`. Puis `/respawn` : apparence réappliquée, identique ; reconnexion : identique (la valeur reste dans `data` pendant l'arrêt). |
| 5 | Dans l'éditeur : `restart vava_appearance`, puis `ensure vava_characters_ui`. | L'éditeur disparaît, puis la sélection revient ; une création aboutit normalement (RPC `vava_appearance:create` de nouveau enregistré). |
| 6 | **(2 joueurs)** B est sur la sélection quand A lance `restart vava_characters_ui`. | B retrouve son écran avec sa liste ; A, en jeu, ne voit rien changer. |

## 10. Resmon

Mesure selon [LISEZMOI.md](LISEZMOI.md#mesurer-le-resmon).

| Ressource | Au repos (en jeu, rien d'ouvert) | Pendant l'action |
|---|---|---|
| `vAvA_core` | 0,00 à 0,01 ms : aucune boucle client permanente | apparition (2-8, 4-2) : courte hausse pendant le fondu (attentes bornées, relevées toutes les 50 ms), 0,15 ms au plus, puis retour au repos |
| `vava_characters_ui` | 0,00 ms : aucune boucle | sélection ouverte : 0,02 ms au plus ; éditeur, curseur glissé ou ped pivoté : 0,15 ms au plus (un aperçu par image et par réglage au maximum) |
| `vava_appearance` | 0,00 ms | aperçu dans l'éditeur, application à l'apparition : 0,15 ms au plus, ponctuel |

## 11. Ce qu'il faut regarder dans la base

```sql
SELECT id, license, created_at, last_seen_at FROM vava_accounts ORDER BY id;

SELECT id, first_name, last_name, sex, ROUND(position_x, 1) AS x, ROUND(position_y, 1) AS y,
       ROUND(position_z, 1) AS z, ROUND(heading) AS cap, play_seconds, last_played_at, deleted_at
FROM vava_characters WHERE account_id = <N> ORDER BY id;

SELECT JSON_EXTRACT(data, '$."vava_appearance:data".hair') FROM vava_characters WHERE id = <M>;
```

- `vava_accounts` : une ligne par license Rockstar, rien d'autre ; `last_seen_at` à l'arrivée et au départ.
- `vava_characters` : au plus trois lignes sans `deleted_at` par compte ; une suppression ne fait que remplir
  `deleted_at` ; positions vides tant que le personnage n'a jamais été sauvegardé après une apparition ;
  `play_seconds` ne bouge pas pendant la sélection ; `last_played_at` change à chaque « Jouer ».
- Écritures : aussitôt au départ (déconnexion ou `/perso quitter`), sinon toutes les 5 min ou à `vava_saveall`.

## 12. Ce que je ne peux pas avoir vérifié hors jeu

- Le rendu de l'interface dans CEF (polices, cadres, fenêtres) : `modules/vava_characters_ui/web/index.html` s'ouvre
  dans un navigateur avec des données simulées (`?screen=creator&tab=hair&sex=f`).
- Le placement des caméras et du ped d'aperçu (sol trouvé sous la scène, ped à droite, panneau à gauche) à la
  nouvelle scène provisoire (piste de McKenzie, Grapeseed : coordonnées vanilla reprises de mémoire, jamais vues en
  jeu) : 2-1 et 3-12 le disent ; si le sol ou le cadrage est faux, seule `scene` change.
- La règle des noms côté interface a été comparée hors jeu (sous jsdom) aux cas de 2-3 à 2-5 ; reste à la voir en
  jeu, avec les règles réellement reçues du serveur.
- La synchronisation de l'apparence vers les autres joueurs, assurée par le jeu et non par le module (3-11).
- Le comportement de FiveM à l'arrêt d'une ressource : arrêt des ressources dépendantes (9-4) ; le module rend
  lui-même focus, caméra scriptée et ped local (9-2, 9-3, 9-3b), à voir en jeu.
- La lisibilité du ped au moment du départ (5-3), le délai de FXServer avant de constater le départ d'un client tué
  (7-3), l'ouverture de `F8` par-dessus l'écran de sélection (§ 0.2).
- Garde des champs publics (core 0.9.0, 8-11 à 8-14), écrite d'après le comportement connu de FiveM sans l'avoir vu :
  qu'un client puisse réécrire son propre statebag de joueur avec réplication, et que la réécriture déclenche le
  gestionnaire `AddStateBagChangeHandler` du **serveur** (s'il ne le fait pas, la garde ne sert à rien mais ne gêne
  pas : la hache reste en 8-11) ; que ce gestionnaire soit appelé avant que la nouvelle valeur soit appliquée (d'où la
  remise différée) ; que les noms de statebag de joueur soient `player:<numéro>`. L'argument « répliqué » du
  gestionnaire n'est pas utilisé : la garde compare la valeur à celle publiée, quelle que soit son origine.
- Réponse d'un RPC à un joueur parti pendant un handler lent : couverte par un test unitaire seulement
  (`tests/spec/core_rpc_spec.lua`), la fenêtre étant trop courte pour se provoquer à la main.

## 13. Remonter un problème

Voir [LISEZMOI.md](LISEZMOI.md#remonter-un-problème). Ici, les lignes les plus parlantes sont celles du serveur
préfixées `[accounts]`, `[characters]`, `[persistence]` et `[modules]`, et, côté client (`F8`), `[spawn]`,
`[vava_characters_ui]` et `[vava_appearance]`.
