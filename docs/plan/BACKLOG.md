# Backlog d'Eldoria

## Règles (lues par chaque agent avant de choisir)

**Statuts** : `à faire` · `en cours` · `à tester en jeu` · `validée` · `bloquée`. Seul un humain met `validée`.

Une tâche est **éligible** si :
1. son statut est `à faire` ;
2. elle n'est pas marquée **HUMAIN** ;
3. chacune de ses dépendances est `à tester en jeu` ou `validée` ;
4. toutes les **portes de phase** des phases précédentes sont `validée`.

On prend la première tâche éligible dans l'ordre du fichier. On passe son statut à `en cours` au début, à
`à tester en jeu` à la fin (ou `bloquée` avec une ligne `Blocage :` qui dit pourquoi). Un problème trouvé hors
périmètre devient une **nouvelle tâche** ajoutée à la fin de la phase concernée (numéro libre suivant), jamais une
correction sauvage. Un problème **BLOQUANT** remonté par un audit devient une tâche placée en tête de sa phase.

---

## Phase 0 — Socle

### T-001 — Lint propre et CI
- Agent : vava-dev-lua · Dépend de : — · Statut : à tester en jeu
- Corriger les 14 avertissements luacheck relevés le 29 octobre 2026 (variables inutilisées, masquages, branche
  vide, affectation écrasée) sans changer le comportement. Vérifier que `.github/workflows/verifier.yml` passe.
- Critères : `luacheck .` sans avertissement ; versions des modules touchés montées en correctif.

### T-002 — Tests unitaires du core
- Agent : vava-testeur · Dépend de : — · Statut : à tester en jeu
- Tester `shared/lib/schema.lua` en priorité (c'est la barrière de sécurité de chaque RPC : bornes, NaN, ±inf,
  tables imbriquées, clés inconnues, chaînes trop longues, entrée réseau vs locale), puis `string.lua`, `table.lua`,
  `pending.lua`, `hooks.lua`.
- Critères : chaque règle du tableau « Schémas » de `docs/api.md` a au moins un test positif et un négatif.

### T-003 — Tests unitaires des modules métiers et magie
- Agent : vava-testeur · Dépend de : T-002 · Statut : à tester en jeu
- Logique pure de `vava_crafting/shared/quality.lua`, `vava_farming/shared/growth.lua` et `geometry.lua`,
  `vava_gathering/shared/geometry.lua`, `vava_skills/shared/progression.lua` (compléter), `vava_magic/shared/*`,
  `vava_inventory/shared/grid.lua`. Vérifier les valeurs documentées dans chaque README.

### T-004 — Procédures de test en jeu manquantes
- Agent : vava-testeur · Dépend de : — · Statut : à tester en jeu
- Écrire `docs/tests/` pour : connexion et personnage (création, sélection, suppression, reconnexion, position),
  inventaire (y compris 2 joueurs et conteneurs), besoins, santé (mort, aide, réveil), chat, voix, magie (reprendre
  la section « Tests à faire en jeu » de son README), Registre du Conseil, Codex. Déplacer `docs/tests-metiers.md`
  dans `docs/tests/metiers.md` (en laissant un renvoi).

Les tâches T-005 à T-008 corrigent les anomalies relevées par T-004 (détail, fichiers et lignes dans
`docs/plan/rapports/T-004.md`) avant la session de test T-009. Chacune met aussi à jour les attendus des procédures
de `docs/tests/` qui décrivaient le défaut, et les README ou `docs/api.md` qui contredisaient le code. Les points
marqués « décision » attendent le porteur du projet : ne pas les coder sans sa réponse.

### T-005 — Inventaire : redémarrage, affichage et messages
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à tester en jeu
- I1 : après `restart vava_inventory`, les objets d'autres modules mis de côté au chargement des besaces sont
  replacés dès que leur définition revient, main comprise, sans jamais perdre ni recouvrir une pile.
- Interface : un refus du serveur n'efface pas les changements arrivés entre-temps (geste d'un autre joueur).
- Messages : « Cet objet n'est plus là. » quand un autre l'a pris ; refus d'un objet tenable par la ceinture
  notifié ; la touche de fermeture suit celle que le joueur a choisie pour l'ouverture.
- Critères : test du replacement (logique pure ou harnais) ; `restart vava_inventory` à 2 joueurs sans objet perdu
  dans la procédure ; versions montées.

### T-006 — À terre, santé, besoins et magie
- Agent : vava-dev-lua · Dépend de : — · Statut : à tester en jeu
- S1 : la mise à terre couche le ped même quand sa vie GTA vaut exactement 100 (faim, soif, sort, `/vie 0`).
- S2 : aucune action de récolte, d'artisanat ou d'agriculture à terre, refusée par le serveur avec l'export
  existant `vava_health:isDowned` (pas de copie de la règle) ; `E` ne fait plus que rendre l'âme à terre.
- M1 : un joueur à terre n'est plus mouillé, poussé ni renversé par la magie (Vague, sol mouillé, brume, boue).
- M2 : la fin d'un Gel ne libère pas un joueur immobilisé par le Registre.
- Santé : médaillon rendu après un redémarrage à terre ; l'écran affiche la touche du joueur.
- Magie : verrou de cible à la portée du sort prêt ; `/lancer` refusé arme en main ; `/sort` chez un non-mage ne dit
  plus « Sort prêt » ; journal des dégâts entièrement écrit à l'arrêt ; messages du Conseil et `/lueur couleur`
  en français.
- README à écrire : `vava_needs`, `vava_health` ; README de `vava_magic` à remettre d'accord avec le code.
- Décisions : délai entre deux soins ; objets consommés quand `vava_needs` ou `vava_health` est arrêté ; membre du
  Conseil à terre qui se relève lui-même ; Brume et Rempart en zone protégée.

### T-007 — Codex, Registre et personnage
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à tester en jeu
- C1 : un nombre obligatoire du Codex doit être choisi (pas de 0 d'office) ; valeur bornée et arrondie.
- Codex : un maximum de favoris ou de dernières pages abaissé tronque au lieu de bloquer « Lancer » ; `recent.max`
  lu au lieu de 12 ; main rendue à l'arrêt.
- Registre : outil des caméras visible avec le droit `watch` ; état « immobilisé » cohérent après un redémarrage ;
  identifiants (license, discord, steam) plus envoyés à l'interface ; observateur qui part : jamais rendu sous terre.
- Personnage : règles de nom de l'interface tirées de la config du serveur (peut toucher le core : cette tâche
  l'autorise) ; nettoyage à l'arrêt de `vava_characters_ui` ; scène de création distincte du point d'apparition
  (`-- PLACEHOLDER`).
- README à écrire : `vava_appearance`, `vava_characters_ui` ; README de `vava_codex` (test 4) corrigé.
- Décisions : `core:characters:create` ouvert aux clients ; revenir à la sélection sans se reconnecter.

### T-008 — Voix, chat et Chancellerie
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à tester en jeu
- V1 : le `server.cfg` écrit par la Chancellerie contient `setr voice_useNativeAudio true` et
  `setr voice_useSendingRangeOnly true` (cette tâche autorise à toucher `chancellerie/`).
- Voix : nom de zone borné de façon cohérente entre le champ (signes) et le schéma (octets) ; pas de double envoi
  par `Entrée` ; focus rendu à l'arrêt ; zones et limite « à terre » redemandées après un redémarrage ; personne en
  sélection ne s'entend pendant un `restart`.
- Chat : README remis d'accord (test 9, `recipients`) ; `/staff` suggéré au seul Conseil.
- Chat (repris de T-007) : suggestions du chat à jour après un changement de rang du Conseil, sans reconnexion.
- README à écrire : `vava_voice`, `vava_cameras`, `vava_chancellerie`.
- `docs/api.md` : ordre de démarrage complet, refus des besoins « dès 95 », actions non protégées par le rang.

### T-009 — PORTE : première session de test complète — **HUMAIN**
- Dépend de : T-001, T-004, T-005 à T-008 · Statut : validée
- Validée le 29 octobre 2026 par le porteur du projet : la phase 1 est ouverte. Les procédures de `docs/tests/` restent
  la référence pour chaque écart rencontré ensuite (tâche de correction en tête de la phase en cours), et les
  mesures de resmon et de poids téléchargé se prennent à la porte T-019.
- Dérouler toutes les procédures de `docs/tests/`, noter chaque écart en tâche de correction (phase 0), mesurer le
  resmon de chaque ressource au repos et en action, noter le poids téléchargé à la première connexion.

### Suites des points relevés pendant T-002 à T-008 — Statut : à tester en jeu

Points des rapports T-002 à T-008, traités le 29 octobre 2026 par le porteur du projet hors de la boucle des agents
(un commit par module, tests unitaires verts, audit statique passé). À dérouler pendant T-009 :
- **Inventaire 1.6.4** (sécurité, relecture de T-005) : ce qu'un module note sur une besace par son numéro de
  conteneur pendant l'écriture qui précède le déchargement part aussi avant la sortie de mémoire, et un conteneur relu
  en base dont des écritures attendent les fait partir d'abord (plus d'objet retiré qui revient si le personnage
  reparaît dans les 3 s). Export `close(source, conteneur?)` (interface fermée, évènement `vava_inventory:dismiss`) ;
  **santé 1.1.4** ferme l'inventaire ouvert à la mise à terre ; **vava_example_items 1.1.1** redéclare ses objets au
  redémarrage de l'inventaire. Procédures : inventaire 14-7, métiers 5-13, santé 3-9.
- **Core 0.8.1** : définition de schéma cyclique refusée à la compilation ; entiers arrivés en flottant convertis à
  tout niveau (champs de table, listes, maps) dans les arguments et les retours client ; module retiré au **tour
  suivant** son arrêt (état `stopping` : il garde `core.db` pour les dernières écritures de son `onResourceStop`, le
  journal des dégâts de la magie n'est plus perdu). Tests de `rpc.lua`, `ratelimit.lua`, `registry.lua`,
  `modules.lua` (72 tests).
- **Magie 2.6.3** : « Libérer » du Registre pendant un Gel ne relâche plus le ped avant la fin du gel (le serveur le
  refige sur l'action du Conseil) ; `/lancer <sort>` ne transmet la cible verrouillée que si le sort nommé la vise et
  l'atteint, sinon il part droit devant ; **décision prise** : textes du Trait de glace corrigés (la course n'est
  coupée qu'au N5 ; la force du N4 reste 0,45, la progression garde une marche entre N4 et N5). Procédure : magie 2-21,
  6.1-2 et 3, 9-11 bis.
- **Agriculture 1.2.3** : `/agriculture pousser` arrose la terre (la plante ne reflétrit plus dans la foulée) ; les
  heures sèches s'arrêtent à la mort, calculées en une fois ou peu à peu ; **décision prise** : le dernier modèle de
  `stages` est réservé à la plante mûre (100 %, quand la récolte est possible), les autres se partagent la croissance
  à parts égales. Procédure : métiers 5-3 et 5-5.
- **Voix 1.2.2** : un nom refusé pour un signe de contrôle ou invisible répond « Ce nom contient des signes
  illisibles. » (code `label_unreadable` ; la Chancellerie montre son message générique tant que ses textes ne le
  connaissent pas : à ajouter à `chancellerie/web/js/strings.js` lors d'une prochaine version du panneau).
  Procédure : voix 3-18.

Reportés dans leur tâche : la vie GTA tenue par le client → T-110 ; la diffusion des zones de voix à tous → T-014.

## Phase 1 — Sécurité, performance, réseau

Corrections issues de l'audit T-010 (30 octobre 2026), à prendre avant le reste de la phase :

### T-024 — Ressources d'exemple et de développement inoffensives en public
- Agent : vava-dev-lua · Dépend de : — · Statut : à tester en jeu
- **BLOQUANT** (`docs/audits/securite-examples.md`) : `vava_dev_characters` donne à tout joueur `/objet` (100 objets par
  appel), `/vie`, `/aterre` et `/besoins` sans droit ni journal (`server/main.lua:29-74`), et la ressource est `ensure`
  sur le serveur de test. Garde par le code : `setup` refusé si la convar `vava_env` ne vaut pas `dev` (console :
  « mode développement absent »), chaque commande réservée au droit `staff` de vava_admin ou à l'ACE `vava.dev`, dons et
  soins journalisés par `vava_admin:log`. Même garde pour `vava_example` (`/note` : plafond par personnage et purge, ou
  retrait) et `vava_anim_test` (commandes hors du Codex des joueurs). README racine : liste des ressources à ne jamais
  `ensure` sur un serveur ouvert ; contrôle ajouté à `docs/hebergeur.md`.
- Critères : sans la convar, les quatre ressources démarrent sans rien offrir ; procédure `docs/tests/` complétée ;
  versions montées.

### T-025 — Chancellerie : clé du pont hors de la ligne de commande
- Agent : vava-dev-lua (cette tâche autorise à toucher `chancellerie/`) · Dépend de : — · Statut : à tester en jeu
- **IMPORTANT** (`securite-vava_chancellerie.md`) : la clé du pont est passée à FXServer par
  `+set vava_chancellerie_token …` (`chancellerie/lib/bridge.js:30-34`, `lib/process.js:205`, lue par
  `modules/vava_chancellerie/server/auth.lua:20-22`) : lisible par tout utilisateur de la machine (`ps`,
  `/proc/<pid>/cmdline`, Gestionnaire des tâches), elle permet d'appeler `/request` avec un acteur de rang `souverain` et
  `/staff/sync`. La transmettre par l'entrée standard de FXServer après le lancement (déjà masquée par `secrets()`) ou
  par un fichier à droits restreints lu au démarrage puis effacé ; en défense en profondeur, réserver `/staff/sync` et
  les actions de rang élevé à une liste de comptes connus du pont ou à un second secret.
- Critères : la clé n'apparaît plus dans la ligne de commande ni dans les journaux ; tests de la Chancellerie (faux
  FXServer) à jour ; `docs/chancellerie.md` et README du pont à jour ; versions montées.
- Fait (`vava_chancellerie` **1.5.0**, Chancellerie **1.6.0**, rapport `docs/plan/rapports/T-025.md`, test en jeu
  `docs/tests/chancellerie.md`) : clé demandée par le pont dans la console et donnée par l'entrée de FXServer, en
  mémoire seule ; rang donné aux seuls comptes vus reliés en jeu (comptes reliés avant : à relier une fois de plus).

### T-026 — Registre et caméras : bannis en panne de base, offres en boucle, cases sans mur
- Agent : vava-dev-lua (cette tâche autorise à toucher `server/players/accounts.lua`) · Dépend de : — · Statut : à tester en jeu
- **IMPORTANT** (`securite-vava_admin.md`) : `server/bans.lua:27-33` laisse entrer quand `accountId` est nul ou quand
  la requête de ban échoue (`server/players/accounts.lua:264-266` perd l'erreur) : refuser la connexion
  (`messages.unavailable`) sur erreur, et second contrôle au hook `core:player:joined` qui expulse un compte banni.
- **IMPORTANT** (`securite-vava_cameras.md`) : `server/sessions.lua:118-123`, le joueur filmé peut renvoyer `sendOffer`
  en boucle (jusqu'à 20 Ko relayés par offre vers le spectateur ou la Chancellerie) : `camera.offered` posé à la
  première offre, `already_offered` ensuite. `server/main.lua:69-77` : `watch(joueur, 'tile')` sans mur ouvert n'est
  jamais journalisé : tenir côté serveur un état « mur ouvert » par spectateur (posé par `wall`, levé par `leave`,
  `forget`, `revoke`) et refuser `tile` sans lui ; côté pont (`modules/vava_chancellerie/server/routes.lua:139-141`),
  exiger `/cameras/wall` d'abord ou journaliser la première caméra d'un compte sans mur.
- Critères : procédure `docs/tests/registre.md` complétée ; versions montées.
- Fait (core **0.9.1**, vava_admin **1.7.1**, vava_cameras **1.2.0**, pont **1.4.1**, rapport
  `docs/plan/rapports/T-026.md`) : base muette à la recherche du compte ou des bans → connexion refusée avec un message
  clair, second contrôle à l'arrivée en jeu et relecture des joueurs au démarrage du Registre (banni expulsé et inscrit
  au journal), porte gardée par le core tant que le Registre démarre, a échoué ou est arrêté ; une offre par caméra ;
  case refusée sans mur ouvert depuis moins de 2 h (`wall_closed`) ; depuis le web, case sans mur inscrite au journal
  (choix motivé dans le rapport). Relecture et contre-relecture appliquées ; `banRecheck.onError = 'keep'` (décision
  du 30 octobre 2026). Procédure : registre 7-13 à 7-21, 10-9 à 10-14.

### T-027 — Core : `returns` obligatoire dans callClient, champs publics du state bag
- Agent : vava-dev-lua (cette tâche autorise à toucher le core) · Dépend de : — · Statut : à tester en jeu
- **IMPORTANT** (`securite-vAvA_core.md`) : `server/core/rpc.lua:188-198`, `returns` est facultatif dans `callClient` :
  sans schéma, jusqu'à 16 valeurs de forme quelconque remontent au module ; exiger `returns` comme `args` (`{}` admis),
  ou répondre `invalid_response` quand il manque et que `count > 0`. `server/players/sync.lua:204,216` : un champ
  `public` est publié dans le state bag du joueur, que son propre client peut réécrire aux yeux des autres clients :
  écrire dans `docs/api.md` qu'une valeur lue sur un autre client n'est pas authentique et, si FiveM le permet
  (`AddStateBagChangeHandler` côté serveur, origine du changement), remettre la valeur serveur quand un changement ne
  vient pas de lui. Au passage, le MINEUR d'une ligne : réponse RPC livrée sans revérifier que le joueur est le même
  après un handler lent (`rpc.lua:146`).
- Critères : tests dans `tests/spec/core_rpc_spec.lua` (`returns` manquant refusé) ; `docs/api.md` à jour ; version du
  core montée.
- Fait (core **0.9.0**, rapport `docs/plan/rapports/T-027.md`) : `returns` obligatoire dans `callClientWith`, `callClient`
  sans options n'accepte aucune valeur ; réponse RPC retenue si le joueur est parti pendant le handler ; champs publics
  gardés (valeur serveur remise) et plus rien envoyé pour un personnage qui n'est plus celui du joueur. Procédure :
  personnage 8-11 à 8-15.

### T-028 — Artisanat : signature et durabilité protégées par le hook des métadonnées
- Agent : vava-dev-lua · Dépend de : — · Statut : à tester en jeu
- **IMPORTANT** (`securite-vava_crafting.md`) : aucun abonné au hook `vava_inventory:metadata` ne protège `crafter_id`,
  `crafter_name`, `crafted_at`, `mark`, `quality`, `tier` et `max_durability` (`server/signature.lua:138-147`) : tout
  module à venir qui appellera `setMetadata` ou `patchMetadata` avec des clés venues de son client réécrirait le
  créateur (baptême, `signature.lua:210`) ou la durabilité (`repair.lua:55-59,170-171`), alors que le README promet un
  créateur figé. S'abonner en `before` dans `bridge/server.lua` et refuser tout `set` ou `patch` qui change ces clés
  (ou augmente `max_durability`) quand l'écriture ne vient pas de `vava_crafting` (drapeau local autour de ses propres
  appels, synchrones).
- Critères : test de la règle pure (clés protégées) ; README et `docs/api.md` à jour ; version montée.

### T-029 — Le serveur décide : pêche, récolte communale, faim et soif
- Agent : vava-dev-lua · Dépend de : — · Statut : à tester en jeu
- **IMPORTANT** (`securite-vava_gathering.md`) : la réussite de la barre de tension est calculée par la page
  (`web/js/view-tension.js:81`) et transmise par le client (`client/fishing.lua:50`, `server/fishing.lua:50`) : un
  client modifié prend un poisson à chaque touche. Faire tirer la réussite par le serveur (chance selon le niveau de
  Pêche et la bande, comme `quality.failed`), la barre ne pouvant que faire rater. Décision prise le 30 octobre
  2026 : le serveur tire la réussite.
- **IMPORTANT** (`securite-vava_farming.md`) : `server/actions.lua:405-424` (et arrachage `:443-445`) ajoute le produit
  avant de vider l'emplacement ; un hook `before` de `vava_inventory:add` qui céderait la main laisserait deux joueurs
  récolter la même plante. Appliquer `slots.harvest` ou `slots.clear` avant l'ajout et restaurer l'emplacement si la
  besace refuse (comme `vava_gathering/server/harvest.lua:221-222`).
- **IMPORTANT** (`securite-vava_needs.md`) : la perte de vie d'un besoin épuisé est appliquée par le client
  (`server/decay.lua:131`, `client/effects.lua:106-112`) : quand `vava_health` tourne, l'appliquer côté serveur par
  `exports.vava_health:damage`, l'évènement client restant le seul repli sans lui ; l'endurance reste un effet GTA
  client.
- Critères : tests des règles pures (chance de pêche, ordre de la récolte) ; procédures `docs/tests/metiers.md` et
  `besoins.md` complétées ; versions montées.
- Fait le 30 octobre 2026 : `vava_gathering` 1.4.0, `vava_farming` 1.5.1, `vava_needs` 1.2.0 ; compte rendu, réglages
  de la pêche et décisions à confirmer dans `docs/plan/rapports/T-029.md`.

Corrections issues de l'audit réseau T-011 (30 octobre 2026). Son seul BLOQUANT (zones de voix envoyées à tous) est
versé à T-014 ; les autres points déjà couverts sont précisés dans T-012 à T-019.

### T-045 — Inventaire : objet en main vu des seuls joueurs proches, et dès leur arrivée
- Agent : vava-dev-lua (vava-architecte pour le choix du support) · Dépend de : — · Statut : à tester en jeu
- **IMPORTANT** (`docs/audits/reseau-vava_inventory.md`) : `client/hands.lua:129-139` efface la valeur d'un porteur hors
  de la zone de culling (`wanted[serverId] = nil`, `:137`) et rien ne la relit quand il arrive, ni au démarrage
  (`:189-195` ne parcourt que les joueurs à portée) : l'outil d'un joueur venu de loin reste invisible tant qu'il ne
  change pas d'objet. Garder les valeurs des joueurs hors de portée (effacées seulement à `nil` ou au départ) et les
  attacher quand le ped apparaît.
- **IMPORTANT** : `server/hands.lua:75-79`, `:85`, le champ public part chez **tous** les joueurs (environ 110 o par
  objet pris) avec un placement que chaque client connaît déjà par `GlobalState[HELD_MODELS]`. Ne publier que
  `{ id, item }` (environ 30 o) ; **décision** de l'architecte : state bag du ped (répliqué aux seuls joueurs proches et
  relu à l'apparition du ped, réécrit par le serveur à chaque apparition) ou champ public du joueur réduit. Au passage
  (MINEUR) : regrouper par tick les écritures de `GlobalState[HELD_MODELS]` (`:92-97`).
- Critères : test de la règle pure (accessoire reconnu depuis `{ id, item }`) ; procédure `docs/tests/inventaire.md`
  complétée (un joueur prend un outil à plus de 500 m puis rejoint l'autre, qui le voit) ; README et `docs/api.md` à
  jour ; version montée.

### T-046 — Codex : contenu versionné, gardé par la page entre deux ouvertures
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à tester en jeu
- **IMPORTANT** (`docs/audits/reseau-vava_codex.md`) : `server/main.lua:26-35`, appelé par `client/main.lua:82-97`,
  renvoie tout le contenu visible (estimé 10 à 30 Ko, évènement fiable) à **chaque** appui sur F1, alors qu'il ne change
  qu'au démarrage ou à l'arrêt d'un module et au changement de rang. Numéro de version du catalogue (hooks
  `core:registry:added`/`removed` sur `core:commands`) et empreinte des droits du joueur ; `open` reçoit la version
  connue et ne renvoie que les préférences si rien n'a changé ; la page garde le contenu. Envoi latent au-delà du
  seuil de T-013 quand elle sera faite. Au passage (MINEUR) : préférences en `private` (`server/prefs.lua:50`, aucun
  lecteur côté client).
- Critères : test de la version et de l'empreinte ; une seconde ouverture sans changement envoie moins de 2 Ko ; le
  contenu suit un redémarrage de module et un rang donné ; procédure `docs/tests/codex.md` complétée ; version montée.

### T-047 — Caméras : budget du débit montant d'un joueur filmé
- Agent : vava-dev-lua (+ vava-dev-nui pour la répartition dans la page) · Dépend de : T-026 · Statut : à tester en jeu
- **IMPORTANT** (`docs/audits/reseau-vava_cameras.md`) : `config.lua:17-21`, `:28-29`, un encodeur et un débit par
  spectateur, jusqu'à 6 : jusqu'à 7,2 Mbit/s pris sur la connexion montante d'un joueur filmé (le jeu et la voix
  passent par la même). Budget total par joueur filmé en config (**décision** : 1 500 kbit/s proposés), une seule vue
  pleine à la fois, refus `budget` (message en français) au-delà, côté serveur (`server/sessions.lua`).
- Critères : test de la règle de répartition ; procédure `docs/tests/registre.md` complétée avec la mesure des images
  par seconde et du ping du joueur filmé par 1, 3 et 6 membres ; README à jour ; version montée.
- Fait le 30 octobre 2026 : `vava_cameras` 1.3.0, pont 1.5.1, Chancellerie 1.6.1 ; 1 500 kbit/s pour tous les
  spectateurs d'un joueur filmé, une seule vue en grand, refus `budget` retenté par le mur et la Chancellerie ; parts
  revues à chaque arrivée ou départ (`shared/budget.lua`, planchers puis vue en grand puis cases) et appliquées par
  `setParameters` chez le seul joueur filmé (`vava_cameras:rates`, sans nouvelle offre) ; offre relayée au membre en
  envoi latent ; vue en grand refusée jamais inscrite au journal depuis le web (`webCheck`). Compte rendu
  `docs/plan/rapports/T-047.md` (décisions à confirmer : budget, planchers, refus plutôt que vue réduite, envoi
  latent) ; procédure `docs/tests/registre.md` 10-15 à 10-20.

### T-048 — Magie : registre des murmures envoyé par pages
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à tester en jeu
- **IMPORTANT** (`docs/audits/reseau-vava_magic.md`) : `server/registers.lua:154-167` envoie jusqu'à 200 pages (300
  signes et un correspondant de 160 chacune : jusqu'à 100 Ko) en un seul évènement fiable, à chaque ouverture du
  registre. N'envoyer que les 20 pages les plus récentes et le nombre total ; les plus anciennes par un RPC borné
  (curseur sur l'identifiant de page, limite de débit) quand la page les demande.
- Critères : un registre plein s'ouvre avec moins de 12 Ko envoyés ; procédure `docs/tests/magie.md` complétée ;
  README de `vava_magic` à jour ; version montée.
- Fait le 30 octobre 2026 : `vava_magic` 2.7.0, lots de 20 pages et de 7,5 Ko au plus (ouverture d'un registre plein :
  3,2 à 7,1 Ko au lieu de 32 à 193 Ko), RPC `vava_magic:registerPages` à curseur, droit revérifié à chaque lot ;
  compte rendu `docs/plan/rapports/T-048.md` (décisions à confirmer : taille d'un lot, bouton, pas de mémoire entre
  deux ouvertures, débit) ; procédure `docs/tests/magie.md` 8.2-15 à 8.2-22.

### T-010 — Audit sécurité de tout le dépôt
- Agent : vava-securite · Dépend de : — · Statut : à tester en jeu
- Un rapport par module dans `docs/audits/securite-<module>.md` (le core compris). Chaque BLOQUANT ou IMPORTANT
  devient une tâche de correction en tête de phase 1. (Exception à la lecture seule : l'agent écrit ses rapports et
  ses tâches.)
- Fait le 30 octobre 2026 : 20 rapports dans `docs/audits/` (le core, 18 modules, un pour les quatre ressources
  d'exemple), compte rendu `docs/plan/rapports/T-010.md`. Résultat : 2 BLOQUANT (`vava_dev_characters`), 13 IMPORTANT,
  98 MINEUR laissés aux rapports ; corrections ouvertes en tête de phase (T-024 à T-029) ; deux points de la santé
  versés à T-110. Rien à jouer : « à tester en jeu » vaut ici « à relire par le porteur du projet ».

### T-011 — Audit réseau et performance de tout le dépôt
- Agent : vava-reseau-perf · Dépend de : — · Statut : à tester en jeu
- Un rapport par module dans `docs/audits/reseau-<module>.md` : chaque évènement serveur→client (cible, taille,
  fréquence), chaque écriture de GlobalState et de state bag, chaque boucle client et sa fréquence, poids des
  fichiers web. Partir de l'état des lieux de `SECURITE_RESEAU.md`. Mêmes règles pour les tâches de correction.
- Fait le 30 octobre 2026 : 20 rapports dans `docs/audits/` (`reseau-vAvA_core.md`, 18 modules, `reseau-examples.md`),
  compte rendu `docs/plan/rapports/T-011.md` (envois par module, copies des fichiers web chiffrées pour T-012, boucles
  permanentes, mesures pour T-019). Résultat : 1 BLOQUANT (zones de voix envoyées à tous, versé à T-014), 14 IMPORTANT,
  23 MINEUR laissés aux rapports ; corrections ouvertes en tête de phase (T-045 à T-048) et lignes ajoutées à T-012 à
  T-019. Rien à jouer : « à tester en jeu » vaut ici « à relire par le porteur du projet ».

### T-012 — Ressource web commune `vava_ui`
- Agents : vava-architecte → vava-dev-nui · Dépend de : — · Statut : à tester en jeu (**fusion de la suite après le
  test du pilote en jeu**)
- Spec : `docs/plan/specs/T-012.md` (décisions du porteur du projet du 30 octobre 2026 incluses).
- Pilote vava_hud (sur `main`) : `vava_ui` 1.0.0, Chancellerie 1.6.2 (ordre de démarrage), `vava_hud` 1.4.0 ;
  `docs/tests/interfaces.md` § 0. Relu sécurité et réseau (OK).
- Suite (branche `agents/T-012-suite`, à ne fusionner qu'après un § 0 réussi en jeu) : règle de
  `scripts/audit-reseau.sh` (devmock livré, motif `files` qui couvrirait `web/dev/`, police ou texture commune hors de
  `vava_ui`, SVG actif, adresse externe cherchée hors des seuls espaces de noms, cas d'essai), puis les 14 autres
  bascules (`vava_health` 1.2.0 … `vava_magic` 2.8.0), `tests/spec/ui_shared_spec.lua` sur les 15 pages ; poids livré
  4 104 918 o → 1 167 151 o (dépôt LF, − 71,6 %) ; `docs/tests/interfaces.md` § 1 à 6, rapport
  `docs/plan/rapports/T-012.md` § Bascule des 14 modules. Relu sécurité et réseau (OK, mineurs d'outillage appliqués).
- Polices, textures (grain, papier, cadres, séparateurs) et icônes communes dans une ressource unique, référencées
  par `nui://vava_ui/…` ; retirer les copies des autres modules. Démarre juste après `vAvA_core`.
- Chiffres de T-011 (`docs/plan/rapports/T-011.md` § Fichiers web communs) : 4 003 861 o de `web/` livrés aux
  joueurs, dont 2 823 748 o (70,5 %) sont 7 fichiers copiés 73 fois (EB Garamond droit et italique, Cinzel, Cinzel
  Decorative 400 et 700, `grain.png`, `paper.png`) ; environ 1,42 Mo attendus après (− 64 %). Au passage : retirer
  les fichiers livrés jamais chargés (`vava_cameras/web/img/paper.png`, `cinzel_decorative_400.woff2` de
  `vava_cameras` et `vava_voice`), sortir les 14 `web/js/devmock.js` (88 565 o) des `files` livrés et de
  `index.html` en jeu, et passer `grain.png` et `paper.png` en WebP. `chancellerie/web/` garde ses copies (servi par
  Node, jamais téléchargé par les joueurs).
- Critères : aucune police ni texture commune dupliquée ; poids total des dossiers `web/` mesuré avant/après dans le
  rapport ; toutes les interfaces s'affichent (devmock).

### T-013 — Compteur réseau `core.net`
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à tester en jeu
- API du core pour envoyer à un joueur ou à une liste (`core.net.send`, `sendNear(coords, rayon, …)`) qui compte
  par ressource et par évènement le nombre d'envois et une estimation de taille ; commande du Conseil
  `/vava_reseau` (top des évènements de la dernière minute) et affichage dans la Chancellerie si simple.
- Critères : tests unitaires de l'agrégation ; documenté dans `docs/api.md`.
- **IMPORTANT** de T-011 (`docs/audits/reseau-vAvA_core.md`) : `server/core/rpc.lua:97-102`, `:301` et
  `server/players/sync.lua:30`, `:64` envoient tout en évènement fiable, sans mesurer la taille (réponse d'ouverture du
  Codex estimée 10 à 30 Ko, registre des murmures jusqu'à 100 Ko). `core.net` estime la taille sérialisée de chaque
  envoi et de chaque réponse RPC ; au-delà d'un seuil en config (ex. 8 Ko), envoi par `TriggerLatentClientEvent` à
  débit borné, accepté par `client/core/rpc.lua`.
- **IMPORTANT** de T-011 : `scripts/audit-reseau.sh:47-48` ne voit que le littéral `-1`. Signaler aussi une cible qui
  est une constante valant `-1` (`vava_voice/server/zones.lua:23,73`) et les boucles sur tous les joueurs qui envoient
  (`vava_chat/server/api.lua:71`), avec un cas de test ; exceptions à faire relire au porteur du projet (voir T-014).
- Fait le 30 octobre 2026 selon `docs/plan/specs/T-013.md` (décisions du porteur du même jour) : core 0.10.0 —
  `core.net` (`send`, `sendWith`, `sendNear`, `sendNearWith`, `playersNear`, `stats`), jamais `-1`, latent au-delà de
  8 Ko (64 Ko/s, 512 Ko en route par joueur, 256 Ko par message), réponses RPC et `callClient` par `core.net` avec
  préavis, personnage et apparition toujours fiables, compteur d'une minute, `/vava_reseau` et `vava_reseau_essai` ;
  `vava_chat` 1.2.0 (plus de `-1`) ; audit : constante `-1` et boucle sur tous les joueurs, mode `--essai` ; zones de
  voix en exception provisoire (T-014). Compte rendu `docs/plan/rapports/T-013.md`, procédure `docs/tests/reseau.md`.
  La page de la Chancellerie est ouverte à part (T-049).

### T-014 — Abonnements de zone dans le core
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-013 · Statut : à tester en jeu
- Service générique : un module déclare des zones (centre, rayon, marge) et tient leur état dans le core ; le serveur
  tient la liste des joueurs abonnés à chaque zone (entrée **décidée par le serveur** à chaque passage d'après les
  positions qu'il lit, sortie avec une marge, nettoyage à la sélection et à la déconnexion) ; les changements ne partent
  qu'aux abonnés. Voir le modèle de `SECURITE_RESEAU.md` (réécrit) et `docs/plan/specs/T-014.md`. Décision du porteur
  du projet du 30 octobre 2026 : aucun RPC d'abonnement (le client ne demande jamais d'entrer dans une zone : il
  devrait connaître toutes les zones) ; seul `core:zones:resync` redemande l'état d'une zone déjà suivie.
- Y reprendre les zones de voix (`vava_voice/server/zones.lua`) : chaque création, modification ou suppression part
  aujourd'hui à tous les joueurs (`EVERYONE`, seul envoi à tous du module, documenté comme voulu : rare et petit) ;
  avec les abonnements, n'envoyer qu'aux joueurs à portée de la zone (rapport T-008).
- **BLOQUANT** de T-011 (`docs/audits/reseau-vava_voice.md`) : `vava_voice/server/zones.lua:73,75` envoie à
  `EVERYONE` (constante `-1`, `:23`), environ 110 o par édition, et échappe à `audit-reseau.sh`. Seul BLOQUANT de
  l'audit réseau : en attendant cette tâche, le porteur du projet décide d'inscrire l'exception dans
  `scripts/audit-exceptions.txt` (nécessaire dès que T-013 renforce le garde-fou).
- Exception inscrite par T-013 (deux lignes de `scripts/audit-exceptions.txt`, extraits complets) : à retirer ici.
- **IMPORTANT** de la relecture réseau de T-013 (`docs/plan/rapports/T-013.md` § Pour T-014) : un module qui passe par
  `core.net` sérialise deux fois (copie de ses arguments à la traversée de l'export `server/core/api.lua`, puis la
  mesure). Petite bibliothèque chargée par le module (`@vAvA_core/shared/…`) qui mesure et envoie sur place, et ne
  remonte au core qu'un enregistrement de quelques octets (ressource, évènement, octets, cibles, latent) pour le
  compteur. À faire avant que `publish` et la bascule des modules ne la multiplient.
- **IMPORTANT** de la relecture réseau de T-013 : un envoi à une liste ne dit pas quelles cibles ont été sautées (latent
  saturé, `server/core/net.lua` `deliverTo`). Pour les abonnés d'une zone : rendre la liste des sautés, ou règle « le
  client attend la révision + 1, sinon il redemande un instantané ».
- Relecture réseau de T-013, à reprendre ici : positions des joueurs gardées une fois par tour du serveur (aujourd'hui
  le temps d'une même milliseconde) ou grille, pour les portées calculées souvent ; plafond global du volume latent
  (pas seulement par joueur) pour la distribution des catalogues de l'Atelier.
- Fait le 30 octobre 2026 selon `docs/plan/specs/T-014.md` (huit décisions du porteur du même jour) : core 0.11.0 —
  `core.zones` serveur (`define`, `move`, `set`, `replace`, `remove`, `subscribers`, `info`, `list`) et client
  (`watch`, `get`, `list`), passage d'une seconde (grille de 256 m, cercle au sol, hystérésis de 25 m, instances),
  état tenu par le core avec révisions, différences regroupées toujours fiables, état entier latent avec préavis,
  `core:zones:resync` ; `core.net` : positions gardées 50 ms, plafond global de 4 Mo en route, joueurs sautés en
  5e valeur, `sendPacked` / `sendNearPacked` (au lieu d'une bibliothèque par module) ; `/vava_reseau zones [n°]` (durée
  du passage ; consultation d'un joueur au journal) ; `vava_voice` 1.3.0 (zones de voix aux seuls joueurs proches,
  exceptions d'audit retirées). Relu sécurité et réseau, corrigé (plafond de zones suivies sans tri, zone fantôme,
  joueurs immobiles non recalculés, état des zones public sous OneSync). Coût hors jeu par passage, 2 048 zones, 64 /
  128 joueurs : immobiles 0,03 / 0,07 ms ; en mouvement 0,23 / 0,46 ms (zones éparses), 1,7 / 3,3 ms (ville), 6,4 /
  13,9 ms (très dense) ; garder 1 s. Compte rendu `docs/plan/rapports/T-014.md`, procédure `docs/tests/zones.md`.

### T-015 — Récolte : GlobalState → abonnements de zone
- Agent : vava-dev-lua · Dépend de : T-014 · Statut : validée
- Validée le 30 octobre 2026 par le porteur du projet, après essai en jeu. Rapport `docs/plan/rapports/T-015.md`.
- `vava_gathering` (zones et nœuds) n'écrit plus dans GlobalState. Même comportement en jeu.
- Fait le 30 octobre 2026 : `vava_gathering` 1.6.0, une zone du core par zone de récolte (état `zone` → bande et
  cicatrice, `n:<nœud>` → charges ; vitalité plus publiée), aux seuls joueurs proches, en différences. Suites des
  relectures : bornes d'une zone du core vérifiées au démarrage, une récolte = une seule différence, refus durable
  rappelé toutes les 10 min, boucle des props arrêtée loin de toute zone. **À tester en jeu** : `docs/tests/metiers.md`
  § 3.4 (17 étapes : joueur loin sans rien reçu, arrivée au galop et par téléportation, une différence par récolte,
  besace pleine sans envoi, `resmon` loin de tout, zone hors bornes refusée, `profiler record`).
- T-011 (`docs/audits/reseau-vava_gathering.md`) : une récolte coûte deux écritures (zone `server/zones.lua:123-129`,
  nœud `server/nodes.lua:75-79`), environ 140 o chez chaque joueur connecté (64 joueurs, 15 récoltants : environ
  27 Ko/s sortants pour rien). Retirer `vitality` de ce qui est publié (`zones.lua:124`) : le client ne lit que `band`
  et `scarred` (`client/props.lua:76-79`), et la vitalité entière fait partir une écriture à presque chaque récolte et
  à chaque point regagné (passage de 10 s) ; publier zone et nœuds aux seuls abonnés de la zone.
- Voir spec T-014 § 13.2 (une zone du core par zone de récolte, état `zone` + `n:<nœud>`, `core.zones.watch` côté
  client ; `coreVersion = '0.11.0'`).
- Relectures de T-014 : l'état d'une zone est **public** (position déclarée par le client sous OneSync) : rien de
  secret dedans, chaque action revérifie la distance côté serveur ; coût à mesurer par `profiler record` (cases de
  128 m à juger).

### T-016 — Agriculture : GlobalState → abonnements de zone
- Agent : vava-dev-lua · Dépend de : T-014 · Statut : validée
- Validée le 30 octobre 2026 par le porteur du projet, après essai en jeu.
- Rapport : `docs/plan/rapports/T-016.md` (`vava_farming` 1.7.0) ; procédure : `docs/tests/metiers.md` § 5.2.
- Fait le 30 octobre 2026 : une zone du core par parcelle (définition et emplacements à l'arrivée, puis les seuls
  emplacements changés, ~40 o, aux seuls joueurs proches, un envoi par parcelle pour le gel et la croissance). Suite de
  la relecture réseau (IMPORTANT) : une parcelle reçue fait aussitôt un passage du client, sans quoi un cavalier au
  galop voyait les plantes apparaître vers 45-50 m. `zones.share` et `zones.drop` restent à brancher à l'Atelier
  (T-103). **À tester en jeu** : § 5.2 (joueur loin sans rien reçu, plantes à 80 m à pied, au galop et par
  téléportation, un envoi par parcelle la nuit de gel, redémarrage du module, refus `too_far`, `profiler record`).
- T-011 (`docs/audits/reseau-vava_farming.md`) : `server/slots.lua:140-155` republie la **parcelle entière** (470 o pour
  les 12 emplacements du champ communal) à tous les joueurs dès qu'un seul emplacement change de culture, de stade ou
  d'état. Envoyer aux abonnés de la parcelle la seule différence `{ parcelle, n°, crop, stage, state }` (environ 40 o)
  et l'état complet seulement à l'abonnement.
- Voir spec T-014 § 13.3 (une zone du core par parcelle, état `s<n°>` par emplacement ; `coreVersion = '0.11.0'`).
- Relectures de T-014 : l'état d'une zone est **public** (position déclarée par le client sous OneSync) : rien de
  secret dedans, chaque action revérifie la distance côté serveur ; coût à mesurer par `profiler record` (cases de
  128 m à juger).

### T-017 — Artisanat : GlobalState → abonnements de zone
- Agent : vava-dev-lua · Dépend de : T-014 · Statut : validée
- Validée le 30 octobre 2026 par le porteur du projet, après essai en jeu.
- T-011 (`docs/audits/reseau-vava_crafting.md`) : `server/stations.lua:75-82` publie `{ fuel, busy }` à tous, deux fois
  par création au moins (occupée, libre) et à chaque unité de combustible ; `:85-87` réécrit la liste complète des
  stations (110 o par station) à chaque station ajoutée par un module. Envoyer l'état aux abonnés de la zone de la
  station ; la liste des stations devient la définition de zone (plus de clé globale).
- Voir spec T-014 § 13.4 (une zone du core par station, état `def` + `s` ; sons par `core.zones.subscribers` ou
  `sendNear` ; `coreVersion = '0.11.0'`).
- Relectures de T-014 : l'état d'une zone est **public** (position déclarée par le client sous OneSync) : rien de
  secret dedans, chaque action revérifie la distance côté serveur ; coût à mesurer par `profiler record` (cases de
  128 m à juger).
- Fait le 30 octobre 2026 : `vava_crafting` 1.5.0 — une zone du core par station (2 m, marge 100 m), état `def` + `s`
  aux seuls joueurs proches en différences (~34 o), plus aucune clé GlobalState, évènement `vava_crafting:station`
  retiré, boucle des props seulement si une station est connue. Relu sécurité et réseau ; suites : `addStation`
  refuse une station dont le core refuse la zone (`zones_full`), nouvel essai d'une déclaration refusée une fois par
  minute, état non envoyé repris, passage immédiat du client pour chaque station reçue, menu fermé sur une station
  oubliée. Compte rendu `docs/plan/rapports/T-017.md`. **À tester en jeu** : `docs/tests/metiers.md` § 4.1 (19 étapes :
  joueur loin sans rien reçu, stations à 80 m au galop y compris la deuxième d'un trajet, menu qui suit le combustible
  et se ferme quand on s'éloigne, composteur ajouté par l'agriculture, `zones_full`, `resmon`, `profiler record`).

### T-018 — Revue des boucles client
- Agent : vava-dev-lua (avec vava-reseau-perf) · Dépend de : T-011 · Statut : à tester en jeu
- Chacun des 13 fichiers avec `Wait(0)` : la boucle ne tourne que pendant un état actif, sinon intervalle adaptatif.
  Même revue pour toutes les boucles signalées par T-011.
- T-011 (`docs/plan/rapports/T-011.md` § Boucles client permanentes) : les 14 `Wait(0)` sont tous liés à un état qui
  se termine, rien à retirer. **IMPORTANT** : les trois boucles de props tournent à 1 000 ms fixes où que soit le
  joueur et mesurent chaque cible de la config (`vava_gathering/client/props.lua:157-174`,
  `vava_farming/client/props.lua:175-215`, `vava_crafting/client/props.lua:153-170`) ; l'Atelier en multipliera les
  cibles. Mesurer d'abord la distance aux zones (ou parcelles), ne parcourir que les cibles d'une zone à portée,
  allonger l'intervalle à 2-3 s quand rien n'est à moins de `streaming.radius`. Regroupements à décider selon le
  resmon (MINEUR des rapports) : trois boucles de `vava_voice/client/main.lua:119-146`, visibilité du chat en double
  avec le HUD, recherche permanente de `vava_magic/client/ambient.lua:423-440`.
- Fait le 30 octobre 2026 : récolte 1.4.1, agriculture 1.5.2, artisanat 1.3.2 (cibles groupées par zone, parcelle ou
  case de 200 m, seules celles d'un groupe à portée mesurées, 2,5 s au repos au-delà de 80 + 60 m ; règles pures
  `shared/proximity.lua` testées dans `tests/spec/props_proximity_spec.lua`) ; magie 2.7.1 (recherche des effets
  endormie sans magie autour). Les 14 `Wait(0)` relus, tous conformes. Voix et visibilité chat/HUD : propositions pour
  la mesure de T-019. Compte rendu `docs/plan/rapports/T-018.md`, procédure `docs/tests/metiers.md` § 6 et
  `docs/tests/magie.md` § 15-8.

### T-019 — PORTE : mesure après optimisation — **HUMAIN**
- Dépend de : T-010 à T-018 et leurs corrections · Statut : validée
- Validée le 30 octobre 2026 par le porteur du projet : les phases 2 et 3 sont ouvertes. Relevé transmis : resmon
  client au repos, 0,05 ms au total, chaque ressource à 0,00 ms (cible ≤ 0,02 ms). Rester attentif, aux premières
  sessions à plusieurs, aux points « à tester en jeu » de T-012 à T-018 (fusionnées sans test en jeu).
- Refaire les mesures de T-009 (resmon, poids, `/vava_reseau` à 2 joueurs éloignés puis proches). Comparer aux
  objectifs de `SECURITE_RESEAU.md`.
- Mesures détaillées, cibles et scénarios (dont la mémoire des 14 pages NUI et le joueur filmé par les caméras) :
  `docs/plan/rapports/T-011.md` § Mesures à reprendre à la porte T-019.

### T-049 — Chancellerie : page « Réseau »
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-013 · Statut : à tester en jeu
- Décision du porteur du projet (30 octobre 2026, spec T-013, décision 6) : ce que montre `/vava_reseau` aussi dans la
  Chancellerie. Le pont `vava_chancellerie` lit `core.net.stats` (vue d'ensemble, une ressource, un joueur) par une
  route en lecture seule, réservée au droit `tools` vérifié par `webCan` ; une page JS dans `chancellerie/` (sans
  bibliothèque) affiche la dernière minute (évènements les plus lourds, latents, plus gros message) et se rafraîchit à
  la demande ou à intervalle borné. Le suivi d'un joueur évènement par évènement reste lancé par `/vava_reseau joueur`
  (la page lit seulement ce qui est suivi) ; `core.net.stats` suffit, aucun changement du core.
- Critères : route bornée et journalisée côté pont ; procédure `docs/tests/chancellerie.md` complétée ; versions du
  pont et de la Chancellerie montées ; `docs/chancellerie.md` à jour.
- Complément décidé par le porteur du projet (CLAUDE.md, « Compteur réseau ») : tous les joueurs connectés suivis
  d'office par `core.net` (core 0.12.0, mémoire bornée par joueur, plus de suivi de 5 min ni de limite de 4,
  `/vava_reseau joueur` répond tout de suite) ; la page Réseau liste les joueurs avec le nom de leur personnage, un
  clic ouvre le détail (seul inscrit au journal). Pont 1.7.0, Chancellerie 1.8.0. Fait : à tester en jeu
  (`docs/tests/reseau.md` § 3, `docs/tests/chancellerie.md` § 3).

### T-132 — Configs partagées : n'envoyer au client que ce qu'il lit
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à tester en jeu (relu sécurité et réseau, suites appliquées)
- **Priorité : juste après la fusion de T-101** (relecture réseau R-4 de T-101 : la config partagée de `vava_atelier`
  est passée de 10 844 à 25 629 octets, gzip 3 958 → 7 996, téléchargés par chaque joueur ; le client n'en lit
  qu'≈ 2,4 Ko). Commencer par `vava_atelier`.
- Relecture réseau de T-100 : chaque module déclare `config.lua` (et souvent `shared/constants.lua`) en
  `shared_scripts` ; chaque joueur télécharge donc, à chaque version, des réglages que son client ne lit jamais (pour
  `vava_atelier` seul : ~12,8 Ko bruts sur 16,5, ~4,5 Ko compressés ; `vava_arrival` : ~12 Ko). Mesurer module par
  module ce qui part pour rien, puis proposer une règle commune qui garde « tout ce qui est réglable dans
  `config.lua` » (par exemple une section `client` relue par un petit fichier client, ou un découpage serveur / client
  du même fichier) et l'appliquer. Rien de secret n'est en jeu (README de `vava_atelier`, § Sécurité) : c'est une
  question de poids.
- Spec : `docs/plan/specs/T-132.md` (décisions du porteur du projet le 31 octobre 2026 : option B, `config.lua` au seul
  serveur et `config_client.lua` partagé, une valeur à un seul endroit ; T-132 = lot 1 et outillage, puis T-141 à
  T-143 ; installeur de la Chancellerie autorisé).
- Fait le 31 octobre 2026 (branche `agents/T-132`) : règle des deux fichiers de réglages (`config.lua` au seul serveur,
  `config_client.lua` lu par le client, une valeur à un seul endroit ; `CLAUDE.md` et fiches des agents à jour) ;
  outillage : `scripts/lib/manifeste.awk` partagé, `audit-reseau.sh` refuse `config.lua` servi aux joueurs (casse,
  `..`, `ui_page` et `loadscreen` compris), `config_client.lua` au seul serveur, un chemin hors de la ressource et
  une directive à valeur calculée, sans que `audit: ok` les fasse taire (192 cas d'essai) ; 24 exceptions
  transitoires reliées à `PENDING` ; `scripts/poids-client.sh` (Lua, autres, manifeste, `stream/`, core compris) ;
  `tests/spec/config_split_spec.lua` (T0 à T3, alias multiples et `<const>` suivis, fermé par défaut) ;
  `helper.loadClientView`. `vava_atelier` 1.2.0, `vava_arrival` 1.2.0 (`welcome.maxSends` au seul serveur),
  `vava_chancellerie` 1.7.1 (plus aucun script servi), Chancellerie 1.8.5 (`config_client.lua` gardé à la mise à
  jour). Lot 1 : 40 352 octets de moins par joueur, net du manifeste (13 574 compressés). Relu sécurité (OK, 6
  mineurs) et réseau (3 importants, 5 mineurs), suites appliquées (une ligne « Suite : » par point). Rapport
  `docs/plan/rapports/T-132.md`. **À tester en jeu** : `docs/tests/reseau.md` § 7-A, en priorité 7-A-2 (`F8` sans
  `SCRIPT ERROR`), 7-A-3 (`resmon`), 7-A-12 (ancien `config.lua` signalé), 7-A-14 (`resource.rpf` avant et après).

### T-141 — Configs partagées, lot 2 : les métiers
- Agent : vava-dev-lua · Dépend de : T-132 · Statut : à tester en jeu (relu sécurité et réseau, suites appliquées)
- Appliquer la règle de T-132 (`docs/plan/specs/T-132.md` § 2.4 et § 3.3) à `vava_farming`, `vava_crafting`,
  `vava_gathering`, `vava_skills` et à la config de `vava_provisions` ; retirer leurs exceptions transitoires de
  `scripts/audit-exceptions.txt` et leurs entrées `PENDING` de `tests/spec/config_split_spec.lua`. **À faire avant
  T-102** (décision du porteur du projet : T-102 à T-104 partent de fichiers déjà découpés).
- Critères : `config_split_spec` et l'audit passent sans exception pour ces modules ; chaque fonction partagée (`shared/*.lua`) qui reçoit une table de config depuis le client est essayée sur la
  seule vue client (`helper.loadClientView`, relecture réseau R-2 de T-132) ; à défaut, aucune coupe au deuxième niveau
  d'une table passée à la logique partagée ; toute borne dont le client a besoin pour se protéger (longueur ou motif de
  ce qu'il reçoit) reste dans `shared/constants.lua`, jamais dans `config_client.lua` (relecture sécurité S-4) ; rien
  que le seul serveur lit n'est servi, même une feuille d'une table lue par le client (S-5 : `config.x.y = …` dans
  `config.lua`) ; gains mesurés
  par `scripts/poids-client.sh` au rapport (net du manifeste) ; `docs/tests/reseau.md` § 7-B écrit et joué.
- Fait le 31 octobre 2026 (branche `agents/T-141`) : `vava_skills` 1.3.0, `vava_farming` 1.8.0, `vava_crafting` 1.6.0,
  `vava_gathering` 1.7.0, `vava_provisions` 1.1.0 (`config_client.lua` partagé, `config.lua` et la logique du seul
  serveur en `server_scripts`, feuilles du seul serveur ajoutées par `config.lua`, avertissement d'un `config.lua`
  d'avant) ; cinq exceptions transitoires et entrées `PENDING` retirées ; essais sur la vue client
  (`provisions_client_view_spec`, `gathering_fishing_client_spec`, streaming, props). Suites des relectures : contrôle
  T4 dans `config_split_spec` (une feuille de `config_client.lua` qu'aucun fichier client ne lit fait échouer) ; la
  pêche entière au seul serveur (le client ne lit que `holdRatio` de la touche, borné, repli `FISHING_HOLD_RATIO` des
  constantes) ; `verifier.sh` trouve les outils de la copie principale depuis un worktree. Lot 2 : 66 630 octets de
  moins par joueur, net du manifeste (22 348 compressés). Rapport `docs/plan/rapports/T-141.md`. **À tester en jeu** :
  `docs/tests/reseau.md` § 7-B, en priorité 7-B-1 (aucune ligne d'ancienne forme), 7-B-2 et 7-B-6 à 7-B-9 (`F8` sans
  `SCRIPT ERROR` pendant les gestes, barre de tension comprise), 7-B-10 (deux joueurs), 7-B-11 (ancien `config.lua`
  signalé), 7-B-14 (`resource.rpf` avant et après).

### T-142 — Configs partagées, lot 3 : le socle
- Agent : vava-dev-lua · Dépend de : T-132 · Statut : à tester en jeu (relu sécurité et réseau, suites appliquées)
- Même forme que T-141 pour `vava_inventory`, `vava_combat`, `vava_health`, `vava_time`, `vava_codex`, `vava_admin`,
  `vava_voice`, `vava_chat`, `vava_cameras`, `vava_appearance`, `vava_needs`, `vava_world` (spec T-132 § 3.3) ;
  `config.lua` renommé `config_client.lua` dans les trois modules sans partie serveur (`vava_hud`, `vava_loading`,
  `vava_characters_ui`) ; exemples `vava_anim_test`, `vava_dev_characters`, `vava_example_combat`. Retirer leurs
  exceptions transitoires et leurs entrées `PENDING`.
- Relecture réseau R-8 de T-132 : après le renommage, l'installeur de la Chancellerie garde un `config.lua` modifié
  qui n'est plus au manifeste, ignoré sans un mot (`chancellerie/lib/installer.js:156-160`) : prévoir un message de la
  Chancellerie pour un fichier de réglages gardé mais absent de la nouvelle version (« reportez vos réglages dans
  config_client.lua »).
- Critères : comme T-141 (essai sur la vue client, bornes de protection dans les constantes, rien du serveur servi) ;
  `docs/tests/reseau.md` § 7-C.
- Fait le 31 octobre 2026 (branche `agents/T-142`) : `vava_inventory` 1.9.0, `vava_combat` 1.1.0,
  `vava_health` 1.5.0, `vava_time` 1.4.0, `vava_codex` 1.6.0, `vava_admin` 1.9.0, `vava_voice` 1.4.0, `vava_chat` 1.4.0,
  `vava_cameras` 1.5.0, `vava_appearance` 1.1.0, `vava_needs` 1.3.0, `vava_world` 1.2.0 (`config_client.lua` partagé,
  `config.lua` et `shared/grid.lua`, `shared/frost.lua`, `shared/label.lua` au seul serveur, feuilles du seul serveur
  ajoutées par `config.lua`, avertissement d'un `config.lua` d'avant) ; `vava_hud` 1.5.0, `vava_loading` 1.2.0,
  `vava_characters_ui` 1.3.0 (`config.lua` renommé `config_client.lua`) ; exemples `vava_anim_test` 1.2.0,
  `vava_dev_characters` 1.4.0, `vava_example_combat` 1.2.0 ; Chancellerie 1.8.6 (réglage modifié gardé mais absent de
  la nouvelle version signalé au journal de la mise à jour, R-8) ; essais sur la vue client (apparence, temps,
  bouclier) ; `config_split_spec` : une feuille `false` est une valeur pour T1. Dix-huit exceptions transitoires et
  entrées `PENDING` retirées (reste `vava_magic`). Suites des relectures : exception de R6 écrite dans la spec T-132
  (borne que le serveur applique lui-même à ce qu'il relaie, lue dans le même fichier partagé : rien ne bouge) ; refus
  neutres des exemples ; avertissement d'ancienne forme précisé (`vava_time`, `vava_appearance`) ; paragraphe « T-132 »
  retiré de six en-têtes de manifeste ; restes reportés à T-121 (combat), T-143 (alias, bornes de schéma) et T-146
  (ciels du temps, ≈ 4,6 Ko). Lot 3 : 43 568 octets de moins par joueur, net du manifeste (15 889 compressés). Rapport
  `docs/plan/rapports/T-142.md`. **À tester en jeu** : `docs/tests/reseau.md` § 7-C, en priorité 7-C-1 (aucune ligne
  d'ancienne forme), 7-C-2 à 7-C-10 (`F8` sans `SCRIPT ERROR` au chargement, à la sélection et pendant les gestes),
  7-C-11 (deux joueurs), 7-C-12 (ancien `config.lua` signalé), 7-C-15 (mise à jour par la Chancellerie d'un
  `config.lua` modifié de `vava_hud`), 7-C-16 (`resource.rpf` avant et après).

### T-143 — Configs partagées, lot 4 : magie et vivres
- Agent : vava-dev-lua · Dépend de : T-132 · Statut : à tester en jeu (relu sécurité et réseau, suites appliquées)
- Premier passage de `vava_magic` (spec T-132 § 3.3 : `spells` reste partagé jusqu'à T-123 ; `shared/text.lua` et
  `shared/pages.lua` au serveur si aucun fichier client ne s'en sert) ; `vava_provisions/shared/rules.lua` coupé en
  deux (`shared/texts.lua` partagé, `shared/rules.lua` au serveur). Retirer les dernières exceptions transitoires et
  entrées `PENDING`.
- Critères : comme T-141 (essai sur la vue client, bornes de protection dans les constantes, rien du serveur servi,
  contrôle T4 vert) ; `messages.admin` et `messages.journal` de `vava_provisions` (textes du Conseil, ≈ 0,7 Ko,
  servis par T-141 parce que le client passe `messages` entier à `shared/rules.lua`) quittent `config_client.lua` avec
  la coupe de `rules.lua` (relectures de T-141 : sécurité S-1, réseau R-3) ; `docs/tests/reseau.md` § 7-D.
  Relectures de T-142 : T2 échoue sur un alias de la table du module (`local <nom> = <Global>` suivi de `<nom>.config`),
  que le lecteur ne suit pas aujourd'hui (réseau R-6) ; piste pour une borne de schéma du serveur prise dans
  `config_client.lua` (copie gardée sans la clé : nombre non borné) : version dans `clientFile`, ou contrôle au `setup`
  que ces bornes sont des nombres (sécurité, pour information).
- Fait le 31 octobre 2026 (branche `agents/T-143`) : `vava_magic` 2.11.0 (`config_client.lua` partagé, sorts et
  combinaisons entiers jusqu'à T-123 ; `config.lua` au seul serveur, feuilles du seul serveur ajoutées par lui, dont 76
  textes du serveur ; `shared/text.lua`, `shared/pages.lua` au seul serveur ; borne `textMaxBytes` du Murmure contrôlée
  au `setup`, plafonnée à 4 096 octets et à la place d'un lot du registre ; `casting.animLoadMs`, lu par rien, retiré),
  `vava_provisions` 1.2.0 (`shared/texts.lua` partagé, textes lus clé par clé ; `shared/rules.lua` au seul serveur ;
  `messages.admin` et `messages.journal` dans `config.lua` ; refus de démarrer avec un `config.lua` de 1.1.0,
  avertissement pour un `config_client.lua` de 1.1.0) ; outillage : T2 refuse un alias de la table du module, `PENDING`
  retiré, l'audit ne laisse plus rien taire les règles C, S, D, X des manifestes (essai 198 cas), aucune exception
  « T-132 » permise ; borne de schéma : contrôle au `setup` retenu, cas de `vava_voice` (`zones.radius`,
  `zones.height`) à faire après T-145. Lot 4 : 37 180 octets de moins par joueur, net du manifeste (11 316
  compressés). Relu sécurité (OK, 4 mineurs) et réseau (OK, 3 mineurs), suites appliquées sauf R-3 (`kinds.*.reserve`
  des vivres : T2 exige `kinds` entier, reporté à T-103) ; une ligne « Suite : » par point. Rapport
  `docs/plan/rapports/T-143.md`. **À tester en jeu** : `docs/tests/reseau.md` § 7-D, en priorité 7-D-1 (aucune ligne
  d'ancienne forme), 7-D-2 et 7-D-4 à 7-D-8 (`F8` sans `SCRIPT ERROR` pendant les gestes), 7-D-9 (deux joueurs), 7-D-10
  et 7-D-15 (anciens fichiers signalés), 7-D-11 et 7-D-12 (refus de démarrer), 7-D-14 (`resource.rpf` avant et après).

### T-133 — `%c` dépend de la locale : contrôles de texte justes partout
- Agent : vava-dev-lua · Dépend de : — · Statut : à tester en jeu (relu sécurité, suites appliquées)
- Fait le 31 octobre 2026 : core 0.13.1 (`str.sanitize` : contrôles ASCII, C1 en UTF-8, invisibles et marques de sens
  d'écriture remplacés, liste commune `str.hasControl` ; `str.trim` et `str.asciiLower` sans classe de la locale),
  `vava_atelier` 1.0.1, `vava_crafting` 1.5.1, `vava_codex` 1.4.1, `vava_inventory` 1.8.1, `vava_example_atelier`
  1.0.1 ; essais lancés sous une locale Windows (`helper.legacyLocale`) ; `audit-reseau.sh` refuse un `%c` dans une
  chaîne du code Lua. Rapport `docs/plan/rapports/T-133.md`. **À tester en jeu** (serveur Windows) : personnage 2-14
  (« Ída Morvà »), chat 6-12, métiers 4-8b, atelier 5-4, inventaire 10-3b.
- Trouvé pendant T-100 : la classe Lua `%c` suit la locale du système ; sous Windows, elle prend aussi les octets 0x81,
  0x8D, 0x8F, 0x90, 0x9D, 0xAD et fait refuser « Á », « Í », « Ï », « Ð », « Ý », « í » ou le tiret U+2010 dans un
  texte UTF-8. `vava_atelier` utilise désormais `[\0-\31\127]`. Même motif à corriger, avec un test sur U+00A0 à
  U+017F : `shared/lib/string.lua` (core), `vava_chat/shared/text.lua`, `vava_magic/shared/text.lua`,
  `vava_voice/shared/label.lua` (et tout autre `%c` du dépôt).

### T-134 — Motifs d'identifiants et casse sans classes de la locale
- Agent : vava-dev-lua · Dépend de : T-133 · Statut : à faire
- Relecture sécurité de T-133 (défense en profondeur, aucun risque trouvé aujourd'hui) : sous une locale Windows,
  `%w`, `%a`, `%l`, `%d` acceptent des octets ≥ 0x80 (y compris de l'UTF-8 invalide) dans les motifs d'identifiants
  (`config/shared.lua:18`, zones, net, schémas RPC de l'admin, inventory, magic, atelier, crafting, farming, gathering,
  skills, time). Les remplacer par des ensembles explicites (`[A-Za-z0-9_]`, `[a-z0-9_]`), comme `text.isId` de
  l'Atelier, et faire refuser ces classes dans un motif par `audit-reseau.sh`. Même tâche : `text.normalize` de
  l'Atelier ne replie pas la casse du latin étendu (« Ł » et « ł » diffèrent), alors que la clé de nom de l'exemple le
  fait ; `vava_magic/client/controls.lua` (`lower` sur un mot de sort), `vava_codex/client/main.lua` (`%S`, `%s*`),
  `vava_chancellerie/server/link.lua` (`%s` sur un code).

### T-144 — Invite du composteur
- Agent : vava-dev-lua · Dépend de : — · Statut : à tester en jeu (relu sécurité et réseau, suites appliquées)
- Relecture réseau R-6 de T-141 (déjà sur `main`, à confirmer en jeu) : le type `composteur` est déclaré à l'artisanat
  par `vava_farming`, côté serveur seulement ; absent de `cfg.stationTypes` du client, la station n'a ni invite ni menu
  (`vava_crafting/client/interact.lua:122-124` : `props.type(station)` rend nil). Piste : envoyer avec le dessin de la
  station (`stationzone.drawing`) ce que l'invite lit du type (libellé, capacité de combustible), au lieu de le
  chercher dans la config du client.
- Critères : au composteur du champ, l'invite « Composteur » et le menu apparaissent (métiers 5-7) ; essai hors jeu
  d'une station d'un type inconnu de la config du client ; `config_split_spec` vert.
- Fait le 31 octobre 2026 (branche `agents/T-144`) : `vava_crafting` 1.7.0, dessin d'une station avec `typeLabel` et
  `capacity` (borne `FUEL_CAPACITY_MAX`, la même au registre des types), invite lue dans le dessin et qui suit un nom,
  un nom de type ou une réserve changés (R-2), prop gardé quand seuls ces textes changent (R-1), animation prise de la
  réponse du serveur, animation d'un type vérifiée au registre (S-2), `stationTypes` entier dans `config.lua` (le
  client ne le lit plus ; module refusé avant toute déclaration sans cette table, S-3) ; essais hors jeu de la station
  d'un type inconnu du client (`crafting_prompt_client_spec`) et du registre (`crafting_catalog_spec`) ;
  `config_split_spec` vert sans changement. S-1 et `server/signature.lua:55` reportés à T-104. Rapport
  `docs/plan/rapports/T-144.md`. **À tester en jeu** : `docs/tests/metiers.md` 5-7 (invite « Composteur du champ ·
  Composteur » et menu au composteur), invites du bourg inchangées (combustible de la forge et du fourneau), geste avec
  l'animation du type, aucune ligne « animation … inconnue » au démarrage.

### T-146 — Ciel de `vava_time` : cycle au seul serveur
- Agent : vava-dev-lua · Dépend de : T-142 · Statut : à tester en jeu
- Relecture réseau R-1 de T-142 : le temps sert ≈ 4,6 Ko bruts pour le seul serveur, plus que le gain du module au lot
  3 : le cycle des ciels de `config_client.lua` (`weather.next`, `seasons`, `snow`, `durationMinutes`, `durations`,
  ≈ 1,9 Ko) et les fonctions de tirage de `shared/weather.lua` (`weight`, `allowed`, `candidates`, `pick`, `duration`,
  ≈ 2,7 Ko) ; le client n'utilise que `rules.get` et `rules.progress`. Cause : `weather.lua` garde la table entière
  (`local cfg = VavaTime.config.weather`, `(wcfg or cfg).types`). Découpe : `shared/weather.lua` réduit à `get`,
  `ids`, `progress` (partagé) ; le reste dans un fichier en `server_scripts` ; feuilles du serveur de `weather`
  ajoutées par `config.lua` (`config.weather.next = …`), `weather.types` et `fadeSeconds` restant côté client.
- Critères : `config_split_spec` T0 à T4 verts ; essai du ciel sur la vue client (`time_client_view_spec`) et tirages
  inchangés au serveur (`time_weather_spec`) ; comparaison clé par clé de la config ; gain mesuré par
  `scripts/poids-client.sh` ; temps 2-x en jeu (`docs/tests/temps.md`).
- Fait le 31 octobre 2026 (branche `agents/T-146`) : `vava_time` 1.5.0 — `shared/weather.lua` réduit à `get`, `ids`,
  `progress` (ne garde que `weather.types`) ; tirage dans `shared/cycle.lua` au seul serveur ; `weather.next`, `seasons`,
  `snow`, `durationMinutes`, `durations` et `fadeSeconds` posés par `config.lua` (`fadeSeconds` aussi : aucun fichier
  client ne le lit, T4) ; refus de démarrer avec un `config.lua` de 1.4.0, avertissement pour un `config_client.lua` de
  1.4.0, texte de l'ancienne forme précisé (R-5 de T-142). Config du serveur identique à `main` (262 feuilles, 0
  différence), tirages identiques (103 829 comparaisons). 4 844 octets de moins par joueur (1 282 compressés). Rapport
  `docs/plan/rapports/T-146.md`. Relectures sécurité et réseau à faire. **À tester en jeu** : `docs/tests/reseau.md`
  § 7-E.

### T-151 — Envois de `vava_admin` par `core.net.send`, avec repli
- Agent : vava-dev-lua (cette tâche autorise à toucher `vava_admin`) · Dépend de : — · Statut : à faire
- Trouvé pendant T-138 (relecture réseau R-2) : tous les envois de `vava_admin` au client (`notify`, `reportNew`,
  `toolsReset`) passent par `TriggerClientEvent` direct, vers un seul joueur, et ne sont pas comptés par
  `/vava_reseau`. Les faire passer par une fonction d'envoi au seul joueur sur le modèle de
  `vava_arrival/bridge/server.lua:127-140` (`core.net.send`, repli `TriggerClientEvent` vers ce même joueur si
  `core.net` manque). `vava_admin:announcement` reste l'exception `-1` documentée (l'objet même d'une proclamation).
- Critères : aucun `TriggerClientEvent` direct hors du repli et de l'annonce ; essai du repli ; `/vava_reseau` montre
  les envois du Registre.

### T-148 — Fichiers `shared/` absents du manifeste
- Agent : vava-dev-lua · Dépend de : T-132 · Statut : à faire
- Trouvé pendant T-146 : rien ne vérifie qu'un `shared/*.lua` présent dans un module est bien listé à son manifeste ;
  sans la ligne de `shared/cycle.lua`, `vava_time` tomberait au premier tirage du ciel. Ajouter le contrôle à
  `config_split_spec` (T0) ou à l'audit, avec un cas d'essai.

### T-150 — Métadonnées de la pile dans le hook `vava_inventory:use`
- Agent : vava-dev-lua (cette tâche autorise à toucher `vava_inventory`) · Dépend de : — · Statut : à faire
- Trouvé pendant T-135 : le payload de `vava_inventory:use` ne porte pas les métadonnées de la pile, qui disparaît
  avec sa dernière unité ; `vava_provisions` relève le palier par un abonné `before` (relecture sécurité S-2 : suppose
  que rien ne cède la main entre `before` et `after`). Joindre une copie bornée des métadonnées au payload, puis
  simplifier `vava_provisions` (retirer le relevé).

## Phase 2 — Arrivée

### T-020 — Écran de chargement `vava_loading`
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui (cette tâche autorise à toucher le core, `vava_characters_ui`, `chancellerie/`, `scripts/verifier.sh` et `scripts/audit-exceptions.txt`, dans les limites de la spec) · Dépend de : T-012 · Statut : validée
- Validée le 30 octobre 2026 par le porteur du projet, après essai en jeu (« tout fonctionne en jeu »).
- Fait le 30 octobre 2026 : `vava_loading` 1.0.0 (≈ 222 Ko livrés, aucun RPC ni évènement réseau), core 0.13.0,
  `vava_characters_ui` 1.2.0, Chancellerie 1.8.1. Rapport `docs/plan/rapports/T-020.md`. **À tester en jeu** :
  `docs/tests/chargement.md`, en priorité aucune image noire au passage à la sélection (3-2), messages réellement
  reçus et seuils des feux recalibrés avec le journal sur le serveur de test (1-4, à publier avec T-021), runes
  lisibles (2-3), coût sur une petite machine (5-1). Reste pour T-021 : rappel dans les README de `vava_codex`,
  `vava_inventory`, `vava_voice`, `vava_chat` qu'un changement de touche par défaut retouche `strings.js` (décision 12).
- Spec : `docs/plan/specs/T-020.md` (treize décisions retenues telles que proposées, sur délégation du porteur du projet,
  le 30 octobre 2026 : core 0.13.0 qui laisse l'écran à `vava_loading` avec un filet de 30 s, hook
  `vava_characters_ui:shown`, polices embarquées, aucune musique livrée, ouverture à chaque connexion).
- Ressource dédiée : `loadscreen` + `loadscreen_manual_shutdown 'yes'`, fermée par le client quand la sélection de
  personnage est prête (coordination avec `vava_characters_ui`). Progression réelle (messages `loadProgress`),
  extraits du lore en rotation, conseils, nom du serveur ; musique facultative coupable, désactivée par défaut.
  Identité visuelle des autres interfaces. Aucune ressource externe.
- Critères : poids total ≤ 1,5 Mo (contrôlé par `scripts/audit-reseau.sh`) ; ouvrable hors jeu avec un devmock qui
  simule la progression ; aucun écran noir entre le chargement et la sélection.
- **Maquette validée par le porteur du projet** (30 octobre 2026) : `docs/maquettes/Chargement.html`, la référence
  visuelle à suivre. Ouverture d'environ 3 s, qu'on peut passer : une étincelle trace un filet, les lettres
  d'« Eldoria » s'embrasent une à une avec des étincelles, puis le rideau se lève. Paysage de nuit peint par le code,
  sans image : quatre plans de crêtes et de forêts, un château aux fenêtres qui vacillent, une lune, des étoiles, de la
  brume, une étoile filante. Parallaxe à la souris et caméra lente. Titre en métal doré avec un reflet, devant un sceau
  de runes qui tourne. Extraits du lore à gauche, conseils à droite. Six feux de veille, un par étape du chargement
  (les six étapes de la maquette correspondent aux phases de `loadProgress`), puis un éclair qui passe à la sélection.
  À l'adaptation :
  - polices de `vava_ui` (la maquette les prend sur Google Fonts pour l'aperçu, et demande Cinzel Decorative en 900,
    que `vava_ui` n'a pas : 700, ou ajouter le 900 à `vava_ui`) ;
  - panneau « Prototype » retiré ;
  - textes provisoires remplacés par ceux de T-021 ;
  - coût de l'animation mesuré pendant un vrai chargement, avec des effets réductibles (braises, brume) si elle le
    ralentit sur une petite machine.

### T-021 — Textes de l'écran de chargement et du premier pas
- Agent : vava-gardien-lore · Dépend de : T-020 · Statut : à tester en jeu (textes seuls, poids mesuré ; relu par le gardien du lore)
- 20 à 30 extraits courts du lore, 15 conseils de jeu, textes d'accueil.
- Fait le 31 octobre 2026 : `vava_loading` 1.1.0, 28 extraits et 15 conseils dans `web/js/strings.js` (+ 4 Ko),
  « Ressources du royaume » ; touches citées seulement si elles sont à la même place en QWERTY et en AZERTY (F1, I,
  T, K, G, O ; la voix renvoie au Codex) ; rappel de la décision 12 dans les README de `vava_codex`, `vava_chat`,
  `vava_voice`, `vava_skills`, `vava_health`, `vava_gathering` et la config de `vava_inventory` ; messages de
  `vava_arrival` relus, inchangés. **À tester en jeu** : `docs/tests/chargement.md` 1-5 et 1-6 (plus long conseil en
  1280 × 720, chaque touche citée). Reste à faire : calibrer les seuils des feux (1-4) et les publier avec ces textes.

### T-022 — Arrivée d'un nouveau personnage
- Agents : vava-architecte → vava-dev-lua (cette tâche autorise à toucher `config/server.lua` pour un commentaire, `vava_codex`, `chancellerie/lib/resources.js`, `.luacheckrc`, dans les limites de la spec) · Dépend de : — · Statut : validée
- Validée le 30 octobre 2026 par le porteur du projet, après essai en jeu (« tout fonctionne en jeu »).
- Fait le 30 octobre 2026 : `vava_arrival` 1.0.0, `vava_codex` 1.4.0, Chancellerie 1.8.2 (ordre de démarrage). Rapport
  `docs/plan/rapports/T-022.md`. **À tester en jeu** : `docs/tests/accueil.md`, en priorité accueil et Codex qui prend
  le clavier (2), notifications lisibles par-dessus le Codex, aucune seconde dotation (3, 4, 8), `nil` reçus en `NULL`
  par oxmysql (9, 18), limite du compte, `redoter`, `rejouer`, remise « incertaine » (10, 12, 13, 15), anciens
  personnages à `play_seconds = 0`.
- Spec : `docs/plan/specs/T-022.md` (nouveau module `vava_arrival` ; décisions 1 à 9 retenues telles que proposées sur
  délégation du porteur du projet le 30 octobre 2026, la 10 laissée en piste, core gardé en 0.12.0).
- Point d'arrivée en config (PLACEHOLDER), dotation de départ minimale en config (besace, vêtements simples, pain,
  eau), message d'accueil, ouverture du Codex au chapitre « Premiers pas » à la première connexion. Rien de plus :
  le reste s'obtient auprès des autres joueurs.

### T-023 — Codex : chapitre « Premiers pas » et guide des métiers
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui + vava-gardien-lore · Dépend de : T-022 · Statut : à tester en jeu (relu sécurité, réseau et lore, suites appliquées)
- Pages de lecture dans le Codex (pas seulement les commandes) : vivre à Eldoria, troquer, apprendre un métier,
  la magie, le Conseil.
- Fait le 31 octobre 2026 : `vava_codex` 1.5.0, onglet « Lecture » en tête du livre, trois chapitres et douze pages
  (une réservée au Conseil) dans `content/*.lua` servis au seul serveur, texte balisé léger analysé au démarrage,
  index sous l'empreinte du contenu, page envoyée à la demande (RPC `vava_codex:page`) et gardée par la page ;
  `openAt('premiers_pas')` ouvre « Vivre à Eldoria » à la première venue ; commande console `vava_codex_pages`.
  Page du livre 95,5 Ko (+26 Ko). Spec `docs/plan/specs/T-023.md`, rapport `docs/plan/rapports/T-023.md`. **À tester
  en jeu** : `docs/tests/codex.md` § 16 (16-1, 16-2, 16-3, 16-8 à 16-13, 16-15, 16-16), `docs/tests/accueil.md` 20.

### T-130 — Eau potable
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui (cette tâche autorise à toucher `vava_arrival`, `examples/vava_example_items`, `vava_loading` (un conseil), `chancellerie/lib/resources.js` et `config.js`, `.luacheckrc`, dans les limites de la spec) · Dépend de : T-022 · Statut : à tester en jeu (relu sécurité, réseau et lore, suites appliquées)
- Fait le 31 octobre 2026 : nouveau module `vava_provisions` 1.0.0, propriétaire de `eau` et `outre` ; puits, fontaines
  et sources (réserve en mémoire, recalculée à la lecture, jamais envoyée ; fontaine sans fond), transmis aux seuls
  proches par `core.zones` ; `E` remplit les outres vides ou fait boire, l'outre bue revient vide et se fend une fois sur
  dix ; outres faites à la tannerie (1 cuir → 2) ; `/eau` pour le Conseil (`metiers`). `vava_arrival` 1.1.0 et
  `vava_example_items` 1.3.0 ne déclarent plus `eau` (dotations dues reprises quand `vava_provisions` arrive),
  `vava_loading` 1.1.1 (conseil du pain et de l'eau), Chancellerie 1.8.4. Spec `docs/plan/specs/T-130.md`, rapport
  `docs/plan/rapports/T-130.md`. **À tester en jeu** : `docs/tests/eau.md` (27 tests, en priorité gestes, `z` des points
  au sol, aucune autre invite `E` à moins de 2 m, deux joueurs sur la dernière unité, recette de la tannerie, dotation
  reprise après `stop` puis `ensure vava_provisions`), accueil 21-22, besoins 3-7, développement 4-1.
- Relecture lore de T-022 : aucun module livré ne produit de boisson ; une fois bues les deux outres de la dotation
  (`vava_arrival`), aucun joueur ne peut en désaltérer un autre, et l'objet `eau` n'appartient qu'à `vava_arrival` et à
  l'exemple de développement. Donner à l'eau une source commune dans l'esprit du royaume : remplir une outre au puits
  (les puits de `vava_farming` remplissent déjà le seau), boire à une fontaine, ou une recette d'artisanat ; un module
  propriétaire de l'objet `eau` (et, à terme, du `pain`). Rien qui rende un joueur autosuffisant.

### T-135 — Usure de l'outre selon la qualité du tanneur
- Agent : vava-dev-lua · Dépend de : T-130 · Statut : à tester en jeu (relu sécurité, suites appliquées)
- Relecture lore de T-130 : une outre se fend une fois sur dix quel que soit son palier, alors qu'une outre « Soignée »
  s'affiche à part. Lier `tearChance` au palier (moins pour une outre Soignée ou Excellente) en gardant le palier sur
  l'outre rendue vide, sans casser l'empilement : le savoir du tanneur doit compter.
- Fait le 31 octobre 2026 (branche `agents/T-135`), sans RPC, évènement, state bag, boucle ni interface (relecture
  réseau non requise) : `vava_provisions` 1.3.0 garde le palier `{ tier }` de `vava_crafting` de l'outre vide à l'Outre
  d'eau (remplissage pile par pile, retraits par identifiant, eau regroupée par palier) et à l'outre rendue (palier
  relevé par un abonné `before` de `vava_inventory:use`, priorité 1000, jamais de refus) ; risque de fente par palier
  (`containers.eau.tearChanceByTier`) : Grossière 15 %, Commune 10 %, Soignée 5 %, Excellente 2,5 %, Chef-d'œuvre 1 %,
  sans palier 10 % (valeurs retenues par le porteur du projet). Empilement par palier essayé sur l'inventaire réel
  (`provisions_outre_tier_spec`). Relecture sécurité OK, trois mineurs appliqués (relevé effacé si l'inventaire ne
  répond pas, condition « rien ne cède la main entre `before` et `after` » écrite, avertissement en console au plus
  une fois par minute). Suite proposée : métadonnées dans le payload de `vava_inventory:use` (tâche à ouvrir). Rapport
  `docs/plan/rapports/T-135.md` ; à tester en jeu : `docs/tests/eau.md` § 4 bis (tests 28 à 35).

### T-136 — Recettes de `vava_farming` déclarées aux compétences
- Agent : vava-dev-lua · Dépend de : — · Statut : à tester en jeu
- Trouvé pendant T-130 : `vava_farming` déclare sa recette `compost` à l'artisanat mais pas à `vava_skills:recipes` ;
  le composteur devrait la refuser comme « recette inconnue » (à vérifier en jeu d'abord). Déclarer la recette et la
  redéclarer au retour de `vava_skills`, comme `vava_provisions` le fait pour l'outre.
- Fait le 31 octobre 2026 (branche `agents/T-136`), sans RPC, évènement, boucle ni interface (relectures sécurité et
  réseau non requises) : refus constaté hors jeu sur 1.8.0 (code
  `not_known` de `vava_crafting`, « Vous ne connaissez pas cette recette. ») ; `vava_farming` 1.9.0 déclare `compost`
  à `vava_skills:recipes` (libre, Agriculture, niveau 0) et la redéclare au retour de `vava_skills`. Rapport
  `docs/plan/rapports/T-136.md` ; à tester en jeu : `docs/tests/metiers.md` § 5.3.

### T-147 — Artisanat : recette libre inconnue des compétences signalée
- Agent : vava-dev-lua · Dépend de : — · Statut : à faire
- Trouvé pendant T-136 : `vava_crafting` affiche au menu une recette déclarée à l'artisanat mais inconnue de
  `vava_skills:recipes`, puis la refuse au clic (`not_known`), sans rien en console. Un module qui oublie la
  déclaration aux compétences retombe dans ce piège sans signe : avertir au démarrage de `vava_crafting` (et au
  retour de `vava_skills`) pour chaque recette de l'artisanat absente des compétences, et la montrer verrouillée.
- Critères : essai hors jeu d'une recette déclarée à l'artisanat seul (avertissement, recette verrouillée) ;
  métiers en jeu.

### T-145 — Menu pause `vava_pause` (la bannière)
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui (cette tâche autorise à toucher `vava_codex`, `vava_admin`,
  `vava_hud`, `vava_voice` et `chancellerie/lib/resources.js`, dans les limites de la spec) · Dépend de : T-012 ·
  Statut : à tester en jeu (relu sécurité, réseau et lore, suites appliquées)
- Fait le 31 octobre 2026 (branches `agents/T-145` et `agents/T-145-nui`, fusionnées, puis `main` après T-142) :
  `vava_pause` 1.0.0 (interception d'Échap et de P par la seule boucle par image permanente, blocage seul ; porte pure ;
  une seule demande à l'ouverture ; bannière réduite à terre ; fenêtre de combat de 10 s par `vava_health:hit` ; demande
  au Conseil ; quitter ; Codex en panneau ; carte et paramètres du jeu ; réglages du joueur en stockage local ; aucun
  évènement serveur → client ; page ≈ 96 Ko), `vava_codex` 1.7.0 (`openDocked`, `closeDocked`, crochet
  `vava_codex:closed`, mode panneau de la page), `vava_admin` 1.10.0 (natures, position lue par le serveur, témoins,
  deux demandes ouvertes par compte, `submitRequest`, `requestOf`, Registre), `vava_hud` 1.6.0 (masqué pendant la
  bannière, taille et durée des notifications), `vava_voice` 1.5.0 (cercle de portée réglable) ; ordre de démarrage
  (README, Chancellerie). Rapports `docs/plan/rapports/T-145.md` (Lua) et `docs/plan/rapports/T-145-nui.md` (page).
  **À tester en jeu** : `docs/tests/pause.md`, en priorité menu de GTA jamais visible et resmon au repos (1-1, 1-6),
  délai de grâce (1-5), refus en combat et bannière réduite à terre (2-1, 2-2), Codex en panneau (4-1 à 4-4), menus
  natifs (5-1 à 5-3), signalement à trois joueurs (7-6), quitter le jeu (8-3).
- Spec : `docs/plan/specs/T-145.md`, avec les décisions du porteur du projet du 31 octobre 2026 (bannière réduite à
  terre : Paramètres du jeu et Quitter ; auteur d'un signalement visible du Conseil, jamais du joueur signalé ;
  fenêtre de combat de 10 s).
- Référence visuelle : canevas « Menu pause d'Eldoria », section « La bannière, version finale avec le thème du
  serveur » (écrans Personnage, Réglages, Le Conseil, Quitter : `docs/maquettes/menu-pause/HD_*.dc.html`) ; écrans
  B1 Codex, B2 Carte et B6 bannière de confrérie (`Codex.dc.html`, `Carte.dc.html`, `Confrerie.dc.html`) pour ce qui
  n'est pas dans la version finale. L'interface réalisée doit leur ressembler.
- Interception : le menu pause natif de GTA est remplacé par la bannière (touches Échap et P). Bloquer ces touches
  impose une boucle par image permanente : c'est une **exception documentée** à la règle « pas de Wait(0) », limitée
  à ce seul blocage (aucune autre logique dans cette boucle). Pas d'ouverture pendant un combat, à terre, ligoté ou
  dans une autre interface ; fermeture par Échap et par « Reprendre ».
- Bannière : tringle et pommeaux de laiton, tissu tissé, broderie, queue fourchue, blason, « Eldoria » en Cinzel
  Decorative ; rubrique active en bande de parchemin qui pointe vers le panneau ; ouverture en déroulé de 250 ms
  (opacité et transformation uniquement) ; navigation au clavier et à la manette.
- Couleurs de confrérie : si le joueur appartient à une confrérie (`vava_guilds`, via le bridge, facultatif), la
  bannière prend sa teinte et son blason ; sinon bannière royale.
- Rubriques :
  - Personnage : médaillon, nom, tampons de rang et de confrérie, fiche, jauges santé, faim, soif, registre des
    savoir-faire (`vava_skills`), bouton vers la fiche complète.
  - Codex : ouvre `vava_codex` dans le panneau (chapitres, recherche, lecture).
  - Carte : bouton vers la carte de GTA en attendant la carte médiévale ; filtres par type de lieu prévus pour quand
    les lieux viendront de l'Atelier.
  - Réglages : signets Interface, Voix, Touches ; leviers et tampons ; préférences gardées **côté client** (stockage
    local de FiveM), rien n'est envoyé au serveur ; touches lues depuis le registre `core:commands`.
  - Le Conseil : type de demande (question, signaler un joueur, bug, autre), message sur papier ligné, position
    jointe en option, suivi de la demande en cours ; passe par le système de requêtes de `vava_admin`. Le joueur
    signalé ne voit jamais le nom de celui qui signale.
  - Paramètres du jeu : ouvre les paramètres natifs de GTA.
  - Quitter : confirmation (« enregistré là où il se trouve », « à terre au retour si vous l'êtes », « un échange en
    cours sera annulé ») ; Rester (laiton), Se déconnecter (encre), Quitter le jeu (cire).
- Plaque du royaume en bas à droite : heure, saison (quand `vava_time` existe), nombre d'habitants présents.
- Réseau : **une seule** demande à l'ouverture (personnage, confrérie, royaume, état de la demande au Conseil), mise
  en cache le temps de la pause ; rien n'est envoyé en continu ; la demande au Conseil est un RPC borné avec une
  limite de débit stricte.
- Thème : uniquement les ressources de `vava_ui` (polices, `grain.webp`, `paper.webp`, `frame.svg`, `divider.svg`,
  `diamond.svg`) et les composants du Registre du Conseil ; aucun flou ni filtre CSS ; pas de `color-mix` ni de
  fonction CSS récente non garantie dans le navigateur de FiveM.
- Critères : resmon au repos ≤ 0,02 ms malgré la boucle de blocage ; ouverture en moins de 300 ms ; devmock qui
  montre chaque rubrique hors jeu ; impossible d'ouvrir le menu en combat ou ligoté ; relectures sécurité, réseau et
  lore OK.

## Phase 3 — L'Atelier : socle et créateurs du monde

Référence : `docs/plan/ATELIER.md` et les maquettes `docs/maquettes/`. Les écrans réalisés doivent ressembler aux
maquettes.

### T-100 — Ressource `vava_atelier` : cadre, accueil, droits
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-012 · Statut : validée
- Validée le 30 octobre 2026 par le porteur du projet, après essai en jeu (« tout fonctionne en jeu »).
- Fait le 30 octobre 2026 : `vava_atelier` 1.0.0 (page ≈ 99 Ko), `vava_example_atelier` 1.0.0, Chancellerie 1.8.3
  (ordre de démarrage). Rapport `docs/plan/rapports/T-100.md`. **À tester en jeu** : `docs/tests/atelier.md`, en
  priorité redémarrages (7-2, 7-3), appels directs refusés et révocation en direct (2-3, 2-4, 4-9), fiche et « Vérifier »
  sur l'exemple (3-3, 3-4, 4-3), journal recopié au Registre et filtré (6-1, 6-5), caractères invisibles (4-10), config
  de droits fausse et descripteur trop lourd (7-6, 7-7), tailles réseau (8-2, 8-4). Reportés : bouton du Registre
  (tâche qui touchera `vava_admin`), configs partagées (T-132), `%c` ailleurs dans le dépôt (T-133).
- Spec : `docs/plan/specs/T-100.md` (onze décisions retenues sur délégation du porteur du projet le 30 octobre 2026 :
  `F9` et `/atelier`, planchers `metiers` pour le monde et `staff` pour la société et les arts, `vava_admin`
  obligatoire, journal propre gardé 365 jours, rien d'enregistré avant T-101 ; bouton du Registre reporté).
- Interface NUI unique (accueil selon la maquette `Main` : familles, recherche, brouillons, journal), ouverture par
  touche et commande déclarées au registre `core:commands`, registre `vava_atelier:editors`, droits par éditeur via
  `vava_admin`, journal du Conseil. Formulaire générique piloté par schéma (widgets `slider`, `segmented`, `select`,
  `toggle`, `text`, `duration`, `item`, `model`).
- Critères : un éditeur d'exemple (module `examples/`) s'affiche sans code d'interface propre ; devmock de chaque
  écran ; relectures sécurité et réseau OK.

### T-101 — Définitions : stockage, versions, cycle de vie
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-100, T-014 · Statut : à tester en jeu
- Fait le 31 octobre 2026 (branche `agents/T-101`) : `vava_atelier` 1.1.0, `vava_example_atelier` 1.1.0. Rapport
  `docs/plan/rapports/T-101.md` (écarts à la spec 1 à 14). Relectures sécurité et réseau refaites à la reprise, toutes
  leurs suites faites ou justifiées (une ligne « Suite : » par point), contre-relectures OK et leurs suites faites ;
  lore OK. `verifier.sh` passe. **À tester en jeu** : `docs/tests/atelier.md` § 10 à 17, en priorité publication puis
  retour en arrière vus d'un joueur proche sans redémarrage (12-2, 13-2), rien chez un joueur loin (12-3), essai vu de
  son seul auteur (11-2, 11-8), `validateLot` (12-8), reprise de brouillon (14-2), base qui fait foi (15-1), archives
  (16-7 à 16-9), redémarrages et refus d'`apply` (17-2, 17-4, 17-5), transactions et `WHERE id IN (…)` réels
  d'oxmysql. **Ensuite, en priorité : T-132** (config partagée de `vava_atelier` passée à ≈ 25,6 Ko, relecture réseau
  R-4), puis T-102 (qui adopte le contrat `ctx.bundle` / `validateLot` et les consignes de diffusion de `docs/api.md`).
- Table `vava_atelier_definitions` (une ligne par version), statuts brouillon / essai / publié / archivé, import
  de la config comme version 1 au premier démarrage (la base fait foi ensuite), réimport explicite par commande,
  retour à une version, export et import JSON, rechargement à chaud chez le module (`apply`), diffusion aux joueurs
  concernés seulement.
- Critères : tests unitaires du cycle de vie et de la validation ; publier puis revenir en arrière en jeu sans
  redémarrage.

### T-102 — Outil de placement et créateur de récolte
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-101, T-015, T-141 · Statut : à faire
- Outil de placement commun (point, point orienté avec modèle, cercle, polygone ; aperçu vert/rouge ; molette,
  `Maj`, clic droit, `Ctrl+Z`, `Échap` ; barre des touches) sur le modèle de l'éditeur de `vava_voice`.
- `vava_gathering` déclare ses éditeurs zone et point (maquette `Recolte`) ; « Tester la récolte » en essai.
- Critères : créer une zone et 5 points en jeu, publier, un autre joueur proche les voit apparaître sans
  redémarrage, un joueur loin ne reçoit rien (vérifié avec `/vava_reseau`).
- Relectures de T-141 (sécurité S-3, réseau R-3) : `tools`, `resources`, `zones` et `nodes` de la récolte restent
  entiers dans `config_client.lua` (le client les lit par identifiant ou les parcourt) ; ≈ 1,7 Ko n'y sert que le
  serveur (`resources.*` : objet, compétence, difficulté, XP, rendement, pièce en plus, 1 045 o ; `tools.*` : puissance,
  bonus, usure, 285 o ; `zones` et `nodes` : coût, régénération, cicatrice, charges, 411 o). En passant ces données à
  l'Atelier, donner à chaque entrée une part client et une part serveur (contrôle T4 de `config_split_spec` vert).

### T-103 — Créateur d'agriculture
- Agent : vava-dev-lua (+ vava-dev-nui si widget) · Dépend de : T-102, T-016 · Statut : à faire
- Parcelles en polygone (communale ou privée), emplacements, puits, greniers, composteurs.
- Relectures de T-141 (sécurité S-3, réseau R-3) : `crops` de l'agriculture reste entier dans `config_client.lua`
  (le client le lit par culture) ; ≈ 0,7 Ko n'y sert que le serveur (durée, eau, fertilité, famille, graine, produit,
  rendement, XP, difficulté, `frostHardy` : 660 o ; `actions.harvest.sickleFactor`, 20 o). Même chose pour `kinds` de
  `vava_provisions` (réserves des points d'eau, ≈ 250 o ; relecture réseau R-3 de T-143 : impossible sans cela, le
  client passe `kinds` à `pointzone.book` et T2 l'exige entier), si les points d'eau passent à l'Atelier avec les puits
  (aucune autre tâche ne les reprend aujourd'hui). Donner à chaque entrée une part client et une part serveur
  (contrôle T4 vert).

### T-104 — Créateur d'artisanat
- Agent : vava-dev-lua · Dépend de : T-102, T-017 · Statut : à faire
- Stations (type, qualité, combustible, recettes disponibles, publique ou privée).
- Relectures de T-141 (sécurité S-3, réseau R-3) : `stationTypes` de l'artisanat reste entier dans
  `config_client.lua` (le client le lit par type) ; ≈ 0,4 Ko n'y sert que le serveur (compétences, réserve de
  combustible, 416 o), dont `prop`, jamais lu par le client (le dessin de la station porte déjà son modèle). Donner une
  part client et une part serveur (contrôle T4 vert) ; voir aussi T-144 (invite du composteur). Fait par T-144
  (`vava_crafting` 1.7.0) : `stationTypes` entier dans `config.lua`, le client n'en lit plus rien.
- Relecture sécurité S-1 de T-144 : un type modifié après l'indexation n'est pas republié (le dessin des stations de ce
  type garde l'ancien nom, l'ancienne réserve, l'ancien modèle ; affichage seulement). Sur `core:registry:added` (et
  retrait) de `vava_crafting:stations`, rafraîchir `def.type` des stations du type et rappeler `stations.share(def)`
  pour chacune (le client ne recrée le prop que si le lieu ou le modèle changent, R-1 de T-144).
- Relecture sécurité de T-144, pour information (antérieur) : `server/signature.lua:55` (`craftingSkills`, rang du
  poinçon) ne parcourt que `cfg.stationTypes`, pas les types du registre : la compétence d'un type déclaré par un autre
  module (Agriculture, par le composteur) n'est pas comptée parmi celles d'artisanat. Lire le registre quand les types
  passeront à l'Atelier.

### T-105 — Confréries et leur créateur `vava_guilds` (remplace l'ancienne T-042)
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-102 · Statut : à faire
- L'équivalent des « jobs » du RP classique, sans salaire. Créateur selon la maquette `Confrerie` : nom, blason,
  type (rôle de la cité nommé par le Conseil, ou confrérie libre validée par le Conseil), grades ordonnés, grille
  grades × droits, lieux posés en jeu (coffre = conteneur ancré de `vava_inventory`, vestiaire, point de service),
  tenue (PLACEHOLDER). Côté joueurs : recruter, promouvoir, renvoyer, quitter ; registre des membres ; coffre
  journalisé. Droits fournis par les autres modules au registre (`lier`, `fouiller`, `cachot`, `coffre`…) pour que
  la grille s'enrichisse sans toucher à `vava_guilds`.
- Bannière du royaume (T-145) : export serveur `bannerOf(source)` → `nil` ou `{ label (≤ 48 o), short (≤ 16 o), grade?
  (≤ 32 o), cloth, clothDark, field ('#rrggbb'), charge (≤ 24 o) }` (`docs/api.md`, § `vava_pause`). Relecture lore de
  T-145 : le pied « Bannière des <label> » casse avec un article ou « Confrérie… » ; le module fournit la **tournure
  complète** du pied de bannière (« Bannière de la Garde ») dans un champ ajouté au contrat, revalidé par
  `vava_pause` (`shared/snapshot.lua`) et lu par la page (`guildFoot`).
- Critères : créer la Garde et les Guérisseurs en jeu, recruter un second joueur, vérifier qu'un droit décoché est
  refusé par le serveur même en appelant le RPC directement.

### T-106 — Portes, serrures, clés et leur créateur `vava_doors` (remplace l'ancienne T-035)
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-102 · Statut : à faire
- Viser une porte du décor pour la déclarer ; verrouillée ou non ; état décidé par le serveur, envoyé aux joueurs
  proches seulement ; clés = objets avec métadonnées ; copie de clé chez un artisan (recette) ; crochetage lié à une
  compétence ; une porte peut appartenir à une confrérie (droit) ou à un logis.

### T-109 — PORTE : l'Atelier du monde en jeu — **HUMAIN**
- Dépend de : T-100 à T-106 · Statut : à faire
- Avec un second membre du staff qui ne connaît pas l'Atelier : lui faire créer une zone de récolte, une forge et
  une confrérie **sans explication**. Noter chaque hésitation : ce sont des tâches de correction d'interface.

## Phase 4 — Combat v1

Référence : `docs/plan/COMBAT_V1.md`. Ordre à respecter : chaîne de dégâts, moteur, défense, réglages, puis
seulement l'éditeur (phase 6).

Ouverte le 31 octobre 2026 avant la porte T-109, sur décision du porteur du projet (« si il reste des tokens tu peux
faire tout le système de combat ») : la porte T-119 reste à passer en jeu.

### T-110 — Chaîne de dégâts commune
- Agents : vava-architecte → vava-dev-lua (cette tâche autorise à toucher `vava_needs`, `docs/plan/COMBAT_V1.md` § 1, dans les limites de la spec) · Dépend de : — · Statut : à tester en jeu (relu sécurité et réseau, suites appliquées)
- Fait le 31 octobre 2026 : `vava_health` 1.3.0 (vie tenue par le serveur, export `hit` au paquet fermé signé par le
  serveur, registre `vava_health:modifiers` en six étapes, hook `vava_health:hit`, pertes natives lues, dégâts natifs
  entre joueurs annulés côté serveur, ped lu d'office 20 s après l'ordre d'apparition, `damage` enveloppe de `hit`,
  journal `vava_health_hits`), `vava_needs` 1.2.1 (privation par `hit`), `vava_example_combat` 1.0.0 (développement
  seulement). Spec `docs/plan/specs/T-110.md`, rapport `docs/plan/rapports/T-110.md`. **À tester en jeu** :
  `docs/tests/combat.md` (31 tests, dont 16 à deux joueurs : coups et mise à terre 1-2, 1-3 ; modificateurs 1-8 à 1-13 ;
  natifs annulés 1-15 à 1-17 ; `/tricher` corrigé 1-21 ; mesures réseau 1-22, 1-27 à 1-31).
- Export serveur `vava_health:hit(target, paquet)`, registre de modificateurs ordonnés, hooks `vava_health:hit` ;
  annulation des dégâts natifs de GTA entre joueurs.
- La vie GTA appartient au client : `vava_health:set` (soin, blessure, dégâts des sorts appliqués par
  `vava_health:damage`) est appliqué par le client, et un client modifié qui l'ignore ignore les dégâts des sorts (le
  serveur ne relit la vie que pour mettre à terre). La chaîne doit tenir la vie côté serveur (ou la revérifier après
  chaque coup) pour qu'aucun client ne puisse refuser un dégât (rapport T-006).
- La porte `entry.spawned` de `vava_health` (`server/life.lua:239,213,302,341`) repose sur une déclaration du client
  (RPC `core:characters:spawned`) : un client qui fait apparaître son ped sans la confirmer n'est jamais lu ni mis à
  terre, `setHealth`/`heal`/`damage` lui répondent `not_spawned`. Ne pas conditionner la vie à cette déclaration
  (joueur « apparu » dès que son ped existe après l'ordre d'apparition, avec le délai de grâce), ou faire confirmer
  `spawned` par le core quand le ped existe (audit T-010, `securite-vava_health.md`).
- Critères : tests unitaires de l'ordre des modificateurs ; aucun dégât entre joueurs possible hors de la chaîne.

### T-111 — Armes de corps à corps
- Agent : vava-dev-lua · Dépend de : T-110 · Statut : à tester en jeu
- **À tester en jeu (31 octobre 2026)** : `vava_combat` 1.0.0 (six armes et un bouclier, qualité ±15 %, usure par coup
  qui touche relue après le coup, arme émoussée, bouclier au bras ou au dos par statebag gardé par le serveur et montré
  à 120 m, `strike` réservé à ses appelants et refusé d'une instance à l'autre, `/armes`), `vava_example_combat` 1.1.0
  (`/frapper_arme` ; autorisé par le porteur du projet le 31/10). Relu sécurité, réseau et lore, suites appliquées
  (rapport `docs/plan/rapports/T-111.md`). Procédure `docs/tests/combat.md` § 2 (2-1 à 2-30). Ensuite : T-140 (mains
  vides pour incanter), T-112. Chancellerie : `vava_combat` absent de `chancellerie/lib/resources.js` (`ensure` à la
  main en attendant une tâche qui l'autorise).
- Objets armes (catégories, dégâts de base, qualité de forge, usure), correspondance vers modèles vanilla
  (PLACEHOLDER), bouclier accroché, contrôles natifs du corps à corps et armes à feu coupés. Recettes de forge
  ajoutées à `vava_crafting`.

### T-112 — Moteur de techniques `vava_combat`
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-111 · Statut : à faire
- Techniques en données (format de `COMBAT_V1.md`), 4 techniques d'épée en config, RPC `vava_combat:use`, fenêtre
  de frappe tenue par le serveur, positions serveur et tolérances, enchaînement, réactions envoyées aux proches
  seulement ; verrouillage de cible repris de `vava_magic`.
- Critères : tests unitaires de la géométrie ; impossible de toucher hors portée ou à travers le délai ; resmon au
  repos inchangé.
- Suites de T-140 (31 octobre 2026) : **(réseau, R-1)** dans `vava_combat`, `Bridge.HandItem()` client en cache local
  (mis à jour par `core:character:loaded`, `fieldChanged` du champ `vava_inventory:hands`, `unloaded`) au lieu de copier
  tout le personnage à chaque `armed()` ; **(lore)** prévoir une vraie durée pour dégainer et rengainer, ou un court
  délai avant d'incanter après avoir rangé une arme, sinon la règle « le mage a besoin d'un garde » ne tient pas
  (l'incantation est déjà brisée dès qu'une arme passe en main, `vava_inventory:hold`).

### T-113 — Blocage, parade, esquive
- Agent : vava-dev-lua · Dépend de : T-112 · Statut : à faire

### T-114 — Endurance et HUD
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : T-112 · Statut : à faire

### T-115 — Styles, compétences de combat, XP
- Agent : vava-dev-lua · Dépend de : T-113, T-114 · Statut : à faire
- Styles par catégorie d'arme, compétences de combat dans `vava_skills`, déblocage par rang, XP sur vraie cible,
  mentorat du maître d'armes ; techniques de hache, masse, dague, bâton et bouclier en config.

### T-116 — La magie sur la chaîne de dégâts
- Agent : vava-dev-lua · Dépend de : T-110 · Statut : à tester en jeu (relu sécurité et réseau, contre-relecture
  sécurité, suites appliquées)
- Fait le 31 octobre 2026 (branche `agents/T-116`) : `vava_magic` 2.9.0 (chaque blessure d'un sort est un coup de
  `exports.vava_health:hit` avec sa source, son type et ses étiquettes, mêmes dégâts qu'avant pour les onze sorts ;
  boucliers, résistances et zones de paix en modificateurs déclarés avec leurs types ; incantation brisée par le hook
  `vava_health:hit` et non plus par la vie du ped ; plus aucun repli chez le client ; `/magie proteger` d'essai réglé sur
  les rangs du Conseil ; effets sans dégâts soumis à `chain.pvp`, aux zones de paix et au personnage du lanceur ; états
  des combinaisons posés après un coup qui a porté), `vava_health` 1.4.0 (coup déjà lancé : un sort lancé debout porte
  encore si le lanceur tombe avant l'impact, `launched` et `launchedAt`, 4 s au plus, décision du porteur du projet ;
  `vocabulary()` donne `pvp`). Rapport `docs/plan/rapports/T-116.md`, avenant spec T-110 § 14. **À tester en jeu** :
  `docs/tests/magie.md` § 18 (28 tests : montants des sorts 2 à 5, protections et rangs 6 à 9 quater, zones de paix 10
  à 10 ter, combats coupés et lanceur à terre 11 à 13, incantation brisée 14 à 17, vava_health arrêté 18, réseau et
  temps de tour 19, 19 bis), `combat` 1-19, 1-32, 1-33.
- Suite : spec T-111 (point 1), exiger les mains vides pour incanter (`exports.vava_combat:armed()`) après T-111 ;
  suites de `vava_health` R-3 et R-6 (rapport).
- Les dégâts de `vava_magic` passent par `hit` ; les boucliers et résistances deviennent des modificateurs ; même
  comportement en jeu pour les 11 sorts.
- Relecture sécurité de T-110 : `vava_magic` juge encore la blessure sur la vie du ped (`server/world.lua:43-47`,
  `casting.lua:202` et `254-264`, `interruptOnHurt`) : un client qui garde sa vie GTA au maximum n'est jamais
  interrompu. Lire la vie par `exports.vava_health:get` ou s'abonner à `vava_health:hit` `after`. Les sorts passent
  aujourd'hui par `damage` sans `source` et contournent donc `chain.pvp` : leur donner leur `source` (spec T-110 § 12.2).

### T-138 — Invulnérabilité du Registre tenue par le serveur
- Agent : vava-dev-lua (cette tâche autorise à toucher `vava_admin`) · Dépend de : T-110 · Statut : à tester en jeu
  (relu sécurité, contre-relu, relu réseau ; suites appliquées)
- Spec T-110 § 13 : l'invulnérabilité du Registre n'est que locale (`SetEntityInvincible`) ; les sorts la traversent
  déjà, les coups de la chaîne aussi. `vava_admin` garde l'état côté serveur et déclare un modificateur d'annulation
  `vava_admin:invulnerabilite` au registre `vava_health:modifiers`.
- Fait le 31 octobre 2026 (branche `agents/T-138`) : `vava_admin` 1.11.0 — état en mémoire par joueur (personnage,
  compte, raisons `godmode`, `noclip` et `spectate`, chacune avec son instant et le membre qui l'a posée), posé par
  l'intention `tool` (refusée sans personnage, journal inchangé) et par l'observation ; retiré par le levier ou `F2`, à
  la fin de la dernière observation, au déchargement du personnage et au départ ; modificateur d'annulation (étape
  `annulation`, priorité 10, `kinds` de la chaîne sauf `monde`) déclaré au démarrage et redéclaré au retour de
  `vava_health` par un appel isolé ; il ne lit que la mémoire et ne protège plus un compte qui a perdu le droit. Aucun
  RPC, évènement ni boucle ajouté. Essais `admin_invulnerability_spec` (15). Rapport `docs/plan/rapports/T-138.md`.
  Relecture sécurité faite (à corriger, aucun bloquant), suites appliquées : observation bornée (corps près de
  l'ancrage, `spectateMaxMs`, au journal), raisons au droit perdu retirées au changement de rang et évènement
  `vava_admin:toolsReset` au seul joueur, `tool(nom, false)` sans droit, export `isInvulnerable`, doc « tout coup et
  tout sort qui blessent », faim et soif écrites comme décision. Relecture réseau OK (3 mineurs), contre-relecture
  sécurité (C-1 à C-4), suites appliquées : l'observation ne protège que le corps caché sous l'observé (distance
  horizontale au plus 20 m et au moins 6 m sous lui), réglages contrôlés au démarrage, 60 s entre deux protections
  d'observation, une seule échéance par joueur ; la RPC `tool` essayée par le vrai `core.rpc`. 30 essais.
  **À tester en jeu** : `docs/tests/registre.md` § 9 bis (22 tests).
- Pour T-149 (entrée sur la branche `agents/T-112`, relecture réseau R-3 de T-138) : appeler
  `exports.vava_admin:isInvulnerable(src)` une fois par effet, au moment où il touche sa cible, jamais en boucle ni à
  chaque image.
- Suite : T-151 (envois de `vava_admin` par `core.net.send`), trouvée pendant T-138.

### T-139 — Apparition confirmée par le core
- Agent : vava-dev-lua (cette tâche autorise à toucher le core, `server/players/`) · Dépend de : — · Statut : à faire
- Spec T-110 § 13, option B : le temps de jeu, les positions, `vava_arrival` et les envois de proximité croient encore
  la déclaration `core:characters:spawned` du client. Le core la confirme lui-même quand le ped existe après l'ordre
  d'apparition (délai de grâce), et expose l'état confirmé.

### T-140 — Mains vides pour incanter
- Agent : vava-dev-lua (cette tâche autorise à toucher `vava_magic`) · Dépend de : T-111, T-116 · Statut : à tester en
  jeu (relu sécurité, réseau et lore, suites appliquées)
- Décision du porteur du projet (31/10, spec T-111 § 13-1) : impossible d'incanter avec une arme ou un bouclier en
  main. Le serveur refuse le lancer par `exports.vava_combat:armed(src)` (le texte `errors.armed` existe dans la config
  de la magie) ; le client le montre par `armed()` sans en décider. Sans `vava_combat`, aucune restriction. Un bâton de
  mage (focaliseur) viendra plus tard.
- Fait le 31 octobre 2026 (branche `agents/T-140`) : `vava_magic` 2.10.0 (le serveur refuse une incantation, la brise
  dès qu'une arme ou un bouclier passe en main — hook `vava_inventory:hold` — et la revérifie à sa fin, quand une arme
  de GTA est sortie, que `vava_combat:armed` rend une arme ou que le bouclier est au bras, `shield().ready` ; le dos ne
  gêne pas ; brisée, elle ne coûte ni mana ni recharge ; sans `vava_combat`, pas prêt ou en erreur, aucune restriction
  pour les armes de l'inventaire, une ligne de console par minute au plus ; le client le montre tôt : mode magie
  endormi, roue, `/lancer`, un rappel par arme sortie aux touches, viser l'arme en main ne réveille plus le mode ; texte
  `shielded`). Rapport `docs/plan/rapports/T-140.md`. **À tester en jeu** : `docs/tests/magie.md` § 19 (15 tests :
  roue et touches 3 à 6, arme prise pendant l'incantation 7 et 7 bis, outil 8, bouclier 9 à 11, `vava_combat` arrêté
  12, resmon 13, réseau 14), `combat` 2-28.
- Suite : cache de `HandItem` dans `vava_combat` et durée de dégainage (lore) inscrits à T-112 ; incantation brisée sans
  coût (antérieure, toutes interruptions) et libellé `hud.asleep` laissés au porteur du projet.

### T-119 — PORTE : sensations du combat — **HUMAIN**
- Dépend de : T-110 à T-116 · Statut : à faire
- Au moins 4 joueurs, latences différentes. Régler les tolérances et fenêtres en config jusqu'à ce que les coups
  « portent ». Chaque réglage retenu est noté dans `COMBAT_V1.md`.

## Phase 5 — Interactions RP

### T-030 — Troc face à face `vava_trade`
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-014 · Statut : à faire
- Proposer un échange à un joueur proche ; fenêtre partagée où chacun dépose des objets de sa besace ; toute
  modification annule les validations ; double validation ; exécution **atomique** par `vava_inventory` (tout ou
  rien, place vérifiée des deux côtés) ; annulation si l'un s'éloigne, meurt, se déconnecte ; journal du Conseil.
  Fiche d'objet visible (qualité, provenance, artisan) pour juger la valeur.
- Critères : impossible de dupliquer (tests à 2 joueurs avec spam, déconnexion pendant la validation, objet déplacé
  pendant l'échange) ; verdicts sécurité et réseau OK.

### T-031 — Donner un objet de la main à la main
- Agent : vava-dev-lua · Dépend de : T-030 · Statut : à faire
- Glisser un objet vers un joueur proche → il accepte ou refuse ; animation de don.

### T-032 — Interactions physiques `vava_interact`
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- Menu d'interaction sur un joueur proche : lier et délier les mains (objet corde), escorter, porter, fouiller
  (consentement, ou personne liée ou à terre), aider à se relever (réutiliser `vava_health`). Chaque état est décidé
  par le serveur et bloque les actions incompatibles dans les autres modules (hook).

### T-034 — Parchemins et lettres
- Agent : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à faire
- Objet parchemin qu'on écrit (texte borné en métadonnées, signé du personnage, scellable), qu'on lit, qu'on donne.
  Interface de lecture/écriture. Texte inséré avec `textContent` uniquement.

### T-036 — Se présenter
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- On ne connaît pas le nom des inconnus : description courte affichée à la place, « se présenter » révèle son nom à
  un joueur proche (mémorisé par personnage). Utilisé par le chat de proximité et l'affichage au-dessus des têtes.

### T-131 — L'arrivée d'un voyageur vue des joueurs proches
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-022 · Statut : à faire
- Relecture lore de T-022 (décision 10, laissée en piste) : l'accueil reste un message système, rien ne crée encore de
  rencontre. Prévenir discrètement les joueurs proches du point d'arrivée qu'un voyageur arrive (`core.net.sendNear`,
  ~30 m, une ligne), ou donner au Conseil la liste des nouveaux venus du jour ; branché sur le hook
  `vava_arrival:arrived`, sans toucher à `vava_arrival`. Aucun envoi à tous.

### T-137 — Props sans clignotement et points hors des instances
- Agent : vava-dev-lua · Dépend de : — · Statut : à faire
- Relectures de T-130 : un joueur qui reste à la limite de portée voit un prop créé puis supprimé à chaque passage
  (`vava_provisions/client/points.lua`, `vava_crafting/client/props.lua:143`, `vava_gathering/client/props.lua:158`,
  `vava_farming`) : créer à `radius`, retirer à `radius + 10` m. Et aucun point de récolte, station ou point d'eau ne
  vérifie l'instance (routing bucket) du joueur : un joueur dans une instance, aux coordonnées d'un puits, peut puiser.
  Ajouter `bucket` aux zones concernées et le contrôle dans `near`.

### T-039 — PORTE : soirée RP de test — **HUMAIN**
- Dépend de : phase 5 · Statut : à faire
- 4 à 8 joueurs, une soirée : arrivée, présentations, troc, apprentissage, interactions. Noter les manques.

## Phase 6 — Les arts de l'Atelier

### T-120 — Atelier des gestes
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-101 · Statut : à faire
- Recherche d'animations côté serveur (liste de GTA + dictionnaires `.ycd` diffusés), aperçu sur soi ou sur un
  mannequin, options en cases à cocher (boucle, haut du corps, garder la main, figer), accessoires placés avec
  l'outil de placement, enchaînement de clips, gestes à deux (position du partenaire), catégories (émote, métier,
  incantation, combat). Les métiers peuvent référencer un geste par son id. Dépôt d'un `.ycd` par la Chancellerie
  (compte maître seulement, fichier vérifié) : tâche séparée si nécessaire.

### T-033 — Émotes et animations partagées `vava_emotes`
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-120 · Statut : à faire
- Menu d'animations RP : les gestes publiés dans l'Atelier des gestes (catégorie « émote »), raccourcis, animations à deux avec consentement (poignée de main,
  accolade, révérence). Synchronisation sans broadcast (les autres voient l'animation par le moteur).

### T-121 — Éditeur de techniques de combat
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : T-120, T-119 · Statut : à faire
- Maquette `Combat` : frise des phases réglable à la souris, aperçu au ralenti, zone touchée dessinée au sol,
  essai contre un mannequin ; les techniques de la config sont importées comme version 1.
- Relectures de T-142 (réseau R-2 et R-3, sécurité S-2) : `weapons` de `vava_combat` reste entier dans
  `config_client.lua` (≈ 1,9 Ko : `damage`, `durability`, `block`, `reachBonus`) alors que le client n'en lit que
  `category` et `family`, et `shield` y sert les délais du serveur (`toggleMs`, `verifyMs`, `missesToDrop`,
  `pedCheckMs`, `guard*`, ≈ 0,6 Ko), parce que le client passe ces tables à `shared/shield.lua` ; `shield.guardDelay`
  (`shared/shield.lua:115-128`) n'est appelé que par le serveur. À donner une part client et une part serveur en
  reprenant le module.

### T-122 — Atelier des effets
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-101 · Statut : à faire
- Calques (particules du catalogue de GTA, taille, couleur quand la particule le permet, lumière, son, attache à un
  os, durée) ; aperçu en direct ; le niveau de détail et les plafonds de `vava_magic/client/fx.lua` s'appliquent.

### T-123 — Atelier des sorts
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-122, T-120, T-116 · Statut : à faire
- Maquettes `Sort` et `Protection` : forme, cibles, élément, geste, valeurs, liste d'effets de jeu avec conditions
  (familles de `ATELIER.md`), effets visibles par moment (lancement, trajet, impact, sur la cible, rupture, fin),
  règle de cumul des protections, comparaison avec un sort existant, essai par le seul créateur, versions.
  Moteur générique qui réutilise les noyaux de `vava_magic` ; les 11 sorts existants gardent leur code.
- Relecture réseau R-2 de T-143 : `spells` (45 957 o) et `combos` (6 961 o) sont servis entiers par
  `vava_magic/config_client.lua` ; la part qu'y lit le seul serveur (dégâts, XP, résultats des combinaisons) est
  d'≈ 3,5 Ko et ≈ 270 o. Donner à chaque sort une part client et une part serveur : gain attendu ≈ 5 à 7 Ko bruts,
  1,5 à 2 Ko compressés par joueur (contrôle T4 vert).

### T-124 — Invocations
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-123 · Statut : à faire
- Créatures créées par le serveur (exception contrôlée au monde sans PNJ de `vava_world`), modèles provisoires,
  comportements simples (suivre, défendre, attaquer), durée, plafonds par mage et par serveur, disparition si le mage
  s'éloigne, tombe ou se déconnecte.

### T-125 — Transformations
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-123, T-036 · Statut : à faire
- Forme animale (modèles de GTA), déguisement qui rend **méconnaissable** (jamais l'apparence d'un autre joueur ;
  nom remplacé par une description d'inconnu, voir T-036), taille ; durée ; restauration exacte de l'apparence ;
  actions impossibles sous forme animale bloquées côté serveur ; déconnexion pendant une transformation gérée.

### T-129 — PORTE : les arts en jeu — **HUMAIN**
- Dépend de : T-120 à T-125, T-033 · Statut : à faire

## Phase 7 — Société

### T-041 — Équipement porté `vava_equipment`
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- Emplacements d'équipement (tête, torse, jambes, pieds, mains, cape) ; un vêtement est un objet qui applique des
  composants via `vava_appearance` (PLACEHOLDER) ; armures avec protection et solidité.

### T-043 — Habitat `vava_housing`
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-106 · Statut : à faire
- Logis attribués par le Conseil (pas achetés : pas de monnaie), coffre privé (conteneur ancré), clés partagées.

### T-044 — Cachot et registre des sentences
- Agent : vava-dev-lua · Dépend de : T-105, T-032 · Statut : à faire
- La Garde peut enfermer une personne liée dans une cellule (zone) pour une durée bornée ; registre consultable.

## Phase 8 — Monde

### T-050 — Temps, saisons, météo `vava_time`
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à tester en jeu
- Heure du royaume et calendrier (GlobalState : usage légitime), saisons qui modulent la croissance de
  `vava_farming` et les ressources de `vava_gathering` (hooks), météo cohérente avec la saison.
- Avancée en phase 0 à la demande du porteur du projet ; contrôle par le Registre et la Chancellerie.
- Relectures de la 1.0.0 corrigées et décisions du porteur du projet appliquées (saisons de quatorze jours, nuits de gel
  et geste « Couvrir » dans `vava_farming`, débit commun des décisions du Conseil) : `vava_time` 1.1.0, `vava_farming`
  1.4.1, `vava_gathering` 1.3.2, Chancellerie 1.5.1 — voir les sections « Relecture » et « Seconde relecture » du
  rapport ; détails du gel à confirmer (objet qui couvre, probabilité, cultures résistantes).
- Spec : `docs/plan/specs/T-050.md` · rapport : `docs/plan/rapports/T-050.md` · test en jeu : `docs/tests/temps.md`
  et `docs/tests/metiers.md` § 5.1.

### T-051 — Montures, squelette `vava_mounts`
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-043 · Statut : à faire
- Écurie (lieux posés avec l'outil de placement de l'Atelier), propriété, nom, nourriture, santé, appel, persistance ; animal de remplacement ; la monte attend l'asset.

### T-052 — Région de remplacement
- Agent : vava-dev-lua · Dépend de : T-022 · Statut : à faire
- Déplacer tous les lieux d'exemple (autour de −269, −955, en ville) vers une région rurale choisie, uniquement en
  config. **Décision à confirmer** par le porteur du projet avant de commencer.

### T-059 — PORTE : test du monde — **HUMAIN**
- Dépend de : phases 7 et 8 · Statut : à faire

## Phase 9 — Version jouable

### T-060 — Session de charge — **HUMAIN**
- Dépend de : T-059 · Statut : à faire
- Le plus de joueurs possible (objectif 32) pendant une heure ; mesures resmon, `/vava_reseau`, requêtes lentes,
  temps de tick serveur ; chaque problème devient une tâche.

### T-061 — Liste de mise en ligne
- Agent : vava-testeur · Dépend de : T-060 · Statut : à faire
- `docs/mise-en-ligne.md` : sauvegardes de la base, Chancellerie, liste blanche, règlement (journaux gardés),
  ordre de démarrage final, inventaire des PLACEHOLDER restants.

### T-062 — PORTE : 1.0.0-alpha — **HUMAIN**
- Dépend de : T-061 · Statut : à faire
