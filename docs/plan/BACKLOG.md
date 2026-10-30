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
- Agent : vava-dev-lua (cette tâche autorise à toucher `chancellerie/`) · Dépend de : — · Statut : à faire
- **IMPORTANT** (`securite-vava_chancellerie.md`) : la clé du pont est passée à FXServer par
  `+set vava_chancellerie_token …` (`chancellerie/lib/bridge.js:30-34`, `lib/process.js:205`, lue par
  `modules/vava_chancellerie/server/auth.lua:20-22`) : lisible par tout utilisateur de la machine (`ps`,
  `/proc/<pid>/cmdline`, Gestionnaire des tâches), elle permet d'appeler `/request` avec un acteur de rang `souverain` et
  `/staff/sync`. La transmettre par l'entrée standard de FXServer après le lancement (déjà masquée par `secrets()`) ou
  par un fichier à droits restreints lu au démarrage puis effacé ; en défense en profondeur, réserver `/staff/sync` et
  les actions de rang élevé à une liste de comptes connus du pont ou à un second secret.
- Critères : la clé n'apparaît plus dans la ligne de commande ni dans les journaux ; tests de la Chancellerie (faux
  FXServer) à jour ; `docs/chancellerie.md` et README du pont à jour ; versions montées.

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
  au journal), porte gardée par le core tant que le Registre démarre ou a échoué ; une offre par caméra ; case refusée
  sans mur ouvert depuis moins de 2 h (`wall_closed`) ; depuis le web, case sans mur inscrite au journal (choix motivé
  dans le rapport). Relecture sécurité et réseau appliquée. Procédure : registre 7-13 à 7-19, 10-9 à 10-14.

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
- Agent : vava-dev-lua · Dépend de : — · Statut : à faire
- **IMPORTANT** (`securite-vava_gathering.md`) : la réussite de la barre de tension est calculée par la page
  (`web/js/view-tension.js:81`) et transmise par le client (`client/fishing.lua:50`, `server/fishing.lua:50`) : un
  client modifié prend un poisson à chaque touche. Faire tirer la réussite par le serveur (chance selon le niveau de
  Pêche et la bande, comme `quality.failed`), la barre ne pouvant que faire rater. **Décision** inverse possible :
  inscrire l'exception dans « Décisions déjà prises » de CLAUDE.md.
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

Corrections issues de l'audit réseau T-011 (30 octobre 2026). Son seul BLOQUANT (zones de voix envoyées à tous) est
versé à T-014 ; les autres points déjà couverts sont précisés dans T-012 à T-019.

### T-045 — Inventaire : objet en main vu des seuls joueurs proches, et dès leur arrivée
- Agent : vava-dev-lua (vava-architecte pour le choix du support) · Dépend de : — · Statut : à faire
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
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à faire
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
- Agent : vava-dev-lua (+ vava-dev-nui pour la répartition dans la page) · Dépend de : T-026 · Statut : à faire
- **IMPORTANT** (`docs/audits/reseau-vava_cameras.md`) : `config.lua:17-21`, `:28-29`, un encodeur et un débit par
  spectateur, jusqu'à 6 : jusqu'à 7,2 Mbit/s pris sur la connexion montante d'un joueur filmé (le jeu et la voix
  passent par la même). Budget total par joueur filmé en config (**décision** : 1 500 kbit/s proposés), une seule vue
  pleine à la fois, refus `budget` (message en français) au-delà, côté serveur (`server/sessions.lua`).
- Critères : test de la règle de répartition ; procédure `docs/tests/registre.md` complétée avec la mesure des images
  par seconde et du ping du joueur filmé par 1, 3 et 6 membres ; README à jour ; version montée.

### T-048 — Magie : registre des murmures envoyé par pages
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : — · Statut : à faire
- **IMPORTANT** (`docs/audits/reseau-vava_magic.md`) : `server/registers.lua:154-167` envoie jusqu'à 200 pages (300
  signes et un correspondant de 160 chacune : jusqu'à 100 Ko) en un seul évènement fiable, à chaque ouverture du
  registre. N'envoyer que les 20 pages les plus récentes et le nombre total ; les plus anciennes par un RPC borné
  (curseur sur l'identifiant de page, limite de débit) quand la page les demande.
- Critères : un registre plein s'ouvre avec moins de 12 Ko envoyés ; procédure `docs/tests/magie.md` complétée ;
  README de `vava_magic` à jour ; version montée.

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
- Agents : vava-architecte → vava-dev-nui · Dépend de : — · Statut : à faire
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
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
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

### T-014 — Abonnements de zone dans le core
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-013 · Statut : à faire
- Service générique : un module déclare des zones (centre, rayon) ; le serveur tient la liste des joueurs abonnés
  à chaque zone (entrée demandée par le client, sortie vérifiée côté serveur, nettoyage à la déconnexion) ;
  `publish(zone, différence)` n'envoie qu'aux abonnés. Voir le modèle de `SECURITE_RESEAU.md`.
- Y reprendre les zones de voix (`vava_voice/server/zones.lua`) : chaque création, modification ou suppression part
  aujourd'hui à tous les joueurs (`EVERYONE`, seul envoi à tous du module, documenté comme voulu : rare et petit) ;
  avec les abonnements, n'envoyer qu'aux joueurs à portée de la zone (rapport T-008).
- **BLOQUANT** de T-011 (`docs/audits/reseau-vava_voice.md`) : `vava_voice/server/zones.lua:73,75` envoie à
  `EVERYONE` (constante `-1`, `:23`), environ 110 o par édition, et échappe à `audit-reseau.sh`. Seul BLOQUANT de
  l'audit réseau : en attendant cette tâche, le porteur du projet décide d'inscrire l'exception dans
  `scripts/audit-exceptions.txt` (nécessaire dès que T-013 renforce le garde-fou).

### T-015 — Récolte : GlobalState → abonnements de zone
- Agent : vava-dev-lua · Dépend de : T-014 · Statut : à faire
- `vava_gathering` (zones et nœuds) n'écrit plus dans GlobalState. Même comportement en jeu.
- T-011 (`docs/audits/reseau-vava_gathering.md`) : une récolte coûte deux écritures (zone `server/zones.lua:123-129`,
  nœud `server/nodes.lua:75-79`), environ 140 o chez chaque joueur connecté (64 joueurs, 15 récoltants : environ
  27 Ko/s sortants pour rien). Retirer `vitality` de ce qui est publié (`zones.lua:124`) : le client ne lit que `band`
  et `scarred` (`client/props.lua:76-79`), et la vitalité entière fait partir une écriture à presque chaque récolte et
  à chaque point regagné (passage de 10 s) ; publier zone et nœuds aux seuls abonnés de la zone.

### T-016 — Agriculture : GlobalState → abonnements de zone
- Agent : vava-dev-lua · Dépend de : T-014 · Statut : à faire
- T-011 (`docs/audits/reseau-vava_farming.md`) : `server/slots.lua:140-155` republie la **parcelle entière** (470 o pour
  les 12 emplacements du champ communal) à tous les joueurs dès qu'un seul emplacement change de culture, de stade ou
  d'état. Envoyer aux abonnés de la parcelle la seule différence `{ parcelle, n°, crop, stage, state }` (environ 40 o)
  et l'état complet seulement à l'abonnement.

### T-017 — Artisanat : GlobalState → abonnements de zone
- Agent : vava-dev-lua · Dépend de : T-014 · Statut : à faire
- T-011 (`docs/audits/reseau-vava_crafting.md`) : `server/stations.lua:75-82` publie `{ fuel, busy }` à tous, deux fois
  par création au moins (occupée, libre) et à chaque unité de combustible ; `:85-87` réécrit la liste complète des
  stations (110 o par station) à chaque station ajoutée par un module. Envoyer l'état aux abonnés de la zone de la
  station ; la liste des stations devient la définition de zone (plus de clé globale).

### T-018 — Revue des boucles client
- Agent : vava-dev-lua (avec vava-reseau-perf) · Dépend de : T-011 · Statut : à faire
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

### T-019 — PORTE : mesure après optimisation — **HUMAIN**
- Dépend de : T-010 à T-018 et leurs corrections · Statut : à faire
- Refaire les mesures de T-009 (resmon, poids, `/vava_reseau` à 2 joueurs éloignés puis proches). Comparer aux
  objectifs de `SECURITE_RESEAU.md`.
- Mesures détaillées, cibles et scénarios (dont la mémoire des 14 pages NUI et le joueur filmé par les caméras) :
  `docs/plan/rapports/T-011.md` § Mesures à reprendre à la porte T-019.

## Phase 2 — Arrivée

### T-020 — Écran de chargement `vava_loading`
- Agents : vava-architecte → vava-dev-nui · Dépend de : T-012 · Statut : à faire
- Ressource dédiée : `loadscreen` + `loadscreen_manual_shutdown 'yes'`, fermée par le client quand la sélection de
  personnage est prête (coordination avec `vava_characters_ui`). Progression réelle (messages `loadProgress`),
  extraits du lore en rotation, conseils, nom du serveur ; musique facultative coupable, désactivée par défaut.
  Identité visuelle des autres interfaces. Aucune ressource externe.
- Critères : poids total ≤ 1,5 Mo (contrôlé par `scripts/audit-reseau.sh`) ; ouvrable hors jeu avec un devmock qui
  simule la progression ; aucun écran noir entre le chargement et la sélection.

### T-021 — Textes de l'écran de chargement et du premier pas
- Agent : vava-gardien-lore · Dépend de : T-020 · Statut : à faire
- 20 à 30 extraits courts du lore, 15 conseils de jeu, textes d'accueil.

### T-022 — Arrivée d'un nouveau personnage
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
- Point d'arrivée en config (PLACEHOLDER), dotation de départ minimale en config (besace, vêtements simples, pain,
  eau), message d'accueil, ouverture du Codex au chapitre « Premiers pas » à la première connexion. Rien de plus :
  le reste s'obtient auprès des autres joueurs.

### T-023 — Codex : chapitre « Premiers pas » et guide des métiers
- Agents : vava-dev-lua + vava-gardien-lore · Dépend de : T-022 · Statut : à faire
- Pages de lecture dans le Codex (pas seulement les commandes) : vivre à Eldoria, troquer, apprendre un métier,
  la magie, le Conseil.

## Phase 3 — L'Atelier : socle et créateurs du monde

Référence : `docs/plan/ATELIER.md` et les maquettes `docs/maquettes/`. Les écrans réalisés doivent ressembler aux
maquettes.

### T-100 — Ressource `vava_atelier` : cadre, accueil, droits
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-012 · Statut : à faire
- Interface NUI unique (accueil selon la maquette `Main` : familles, recherche, brouillons, journal), ouverture par
  touche et commande déclarées au registre `core:commands`, registre `vava_atelier:editors`, droits par éditeur via
  `vava_admin`, journal du Conseil. Formulaire générique piloté par schéma (widgets `slider`, `segmented`, `select`,
  `toggle`, `text`, `duration`, `item`, `model`).
- Critères : un éditeur d'exemple (module `examples/`) s'affiche sans code d'interface propre ; devmock de chaque
  écran ; relectures sécurité et réseau OK.

### T-101 — Définitions : stockage, versions, cycle de vie
- Agents : vava-architecte → vava-dev-lua · Dépend de : T-100, T-014 · Statut : à faire
- Table `vava_atelier_definitions` (une ligne par version), statuts brouillon / essai / publié / archivé, import
  de la config comme version 1 au premier démarrage (la base fait foi ensuite), réimport explicite par commande,
  retour à une version, export et import JSON, rechargement à chaud chez le module (`apply`), diffusion aux joueurs
  concernés seulement.
- Critères : tests unitaires du cycle de vie et de la validation ; publier puis revenir en arrière en jeu sans
  redémarrage.

### T-102 — Outil de placement et créateur de récolte
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-101, T-015 · Statut : à faire
- Outil de placement commun (point, point orienté avec modèle, cercle, polygone ; aperçu vert/rouge ; molette,
  `Maj`, clic droit, `Ctrl+Z`, `Échap` ; barre des touches) sur le modèle de l'éditeur de `vava_voice`.
- `vava_gathering` déclare ses éditeurs zone et point (maquette `Recolte`) ; « Tester la récolte » en essai.
- Critères : créer une zone et 5 points en jeu, publier, un autre joueur proche les voit apparaître sans
  redémarrage, un joueur loin ne reçoit rien (vérifié avec `/vava_reseau`).

### T-103 — Créateur d'agriculture
- Agent : vava-dev-lua (+ vava-dev-nui si widget) · Dépend de : T-102, T-016 · Statut : à faire
- Parcelles en polygone (communale ou privée), emplacements, puits, greniers, composteurs.

### T-104 — Créateur d'artisanat
- Agent : vava-dev-lua · Dépend de : T-102, T-017 · Statut : à faire
- Stations (type, qualité, combustible, recettes disponibles, publique ou privée).

### T-105 — Confréries et leur créateur `vava_guilds` (remplace l'ancienne T-042)
- Agents : vava-architecte → vava-dev-lua + vava-dev-nui · Dépend de : T-102 · Statut : à faire
- L'équivalent des « jobs » du RP classique, sans salaire. Créateur selon la maquette `Confrerie` : nom, blason,
  type (rôle de la cité nommé par le Conseil, ou confrérie libre validée par le Conseil), grades ordonnés, grille
  grades × droits, lieux posés en jeu (coffre = conteneur ancré de `vava_inventory`, vestiaire, point de service),
  tenue (PLACEHOLDER). Côté joueurs : recruter, promouvoir, renvoyer, quitter ; registre des membres ; coffre
  journalisé. Droits fournis par les autres modules au registre (`lier`, `fouiller`, `cachot`, `coffre`…) pour que
  la grille s'enrichisse sans toucher à `vava_guilds`.
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

### T-110 — Chaîne de dégâts commune
- Agents : vava-architecte → vava-dev-lua · Dépend de : — · Statut : à faire
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
- Agent : vava-dev-lua · Dépend de : T-110 · Statut : à faire
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

### T-113 — Blocage, parade, esquive
- Agent : vava-dev-lua · Dépend de : T-112 · Statut : à faire

### T-114 — Endurance et HUD
- Agents : vava-dev-lua + vava-dev-nui · Dépend de : T-112 · Statut : à faire

### T-115 — Styles, compétences de combat, XP
- Agent : vava-dev-lua · Dépend de : T-113, T-114 · Statut : à faire
- Styles par catégorie d'arme, compétences de combat dans `vava_skills`, déblocage par rang, XP sur vraie cible,
  mentorat du maître d'armes ; techniques de hache, masse, dague, bâton et bouclier en config.

### T-116 — La magie sur la chaîne de dégâts
- Agent : vava-dev-lua · Dépend de : T-110 · Statut : à faire
- Les dégâts de `vava_magic` passent par `hit` ; les boucliers et résistances deviennent des modificateurs ; même
  comportement en jeu pour les 11 sorts.

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
