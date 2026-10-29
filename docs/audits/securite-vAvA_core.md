# Audit sécurité — vAvA_core 0.8.1 — 29 octobre 2026 (T-010)

## Périmètre

Rôle de la ressource : le socle du serveur — unique porte réseau (RPC à schémas et limites de débit), accès SQL,
hooks, registres, cycle de vie des modules, comptes (connexion par license), personnages (création, sélection,
champs, persistance, apparition) et côté client le cache du personnage et l'exécution des ordres d'apparition.

Fichiers lus en entier (ligne à ligne) : `fxmanifest.lua`, `config/server.lua`, `config/shared.lua`,
`shared/init.lua`, `shared/lib/{schema,pending,string,table,semver}.lua`, `shared/core/{logger,hooks,api}.lua`,
`server/core/{database,migrations,ratelimit,rpc,registry,commands,modules,api}.lua`,
`server/players/{accounts,fields,sync,persistence,playtime,positions,spawn,characters,api}.lua`, `server/init.lua`,
`server/migrations/0001_accounts.sql`, `0002_characters.sql`, `0003_play_seconds.sql`,
`client/core/{rpc,api}.lua`, `client/players/{session,spawn,api}.lua`, `client/init.lua`.
Documents : `CLAUDE.md`, `docs/plan/SECURITE_RESEAU.md`, `docs/api.md` (sections core), `docs/plan/rapports/T-002.md`
et `T-007.md`.

Non lus, ou lus seulement par recherche ciblée : les modules (grep pour savoir qui appelle `callClient`, qui
déclare un champ `public`, qui s'abonne à `core:player:connecting` et `core:character:unloading`, comment
`vava_health` garde l'état « à terre ») ; les tests `tests/spec/core_*_spec.lua` (noms des cas seulement) ;
`oxmysql` (dépendance externe : le core suppose qu'un échec de requête lève ou rend `nil`, les deux cas sont
traités dans `database.lua:67-77`). Comportements de FiveM que je ne peux pas vérifier ici et que je classe donc
prudemment : taille maximale d'un évènement réseau entrant (seule borne avant la validation des chaînes et tables),
réattribution d'un identifiant de joueur après déconnexion, droit d'un client à réécrire son propre state bag
répliqué, valeur de `source` pour un évènement déclenché localement.

### Corrections annoncées par T-002 et T-007 : présentes dans le code

| Annonce | Où | État |
|---|---|---|
| S1 bornes de longueur entières | `shared/lib/schema.lua:91-94` | présente |
| S2 `NaN` refusé dans `enum` | `schema.lua:152` | présente |
| S3 `validateList` refuse toute clé hors `1..count` | `schema.lua:375-379` | présente |
| C1 `sanitize` retire la suite de `^` avec le chiffre | `shared/lib/string.lua:165` (`'%^+%d'`) | présente |
| borne `NaN` refusée à la compilation | `schema.lua:83-85` | présente |
| définition cyclique refusée (0.8.1) | `schema.lua:62`, `:164-174` | présente |
| entiers convertis à tout niveau (0.8.1) | `schema.lua:273-293`, `server/core/rpc.lua:141` | présente |
| règles de nom envoyées avec `list` (0.8.0) | `server/players/characters.lua:65-68`, `:558` | présente |
| module en `stopping` retiré au tour suivant (0.8.1) | `server/core/modules.lua:344-351`, `:302-305` | présente |

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vAvA:rpc:request` (`server/core/rpc.lua:338`) | évènement serveur (porte unique) | `id` entier `0..0x7FFFFFFF`, `name` chaîne, `count` et `args` par `schema.validateList` (`:133`), métatables refusées, flottants entiers normalisés (`:141`) | global `40` puis `20/s` par joueur (`config/server.lua:92`), consommé avant toute lecture du message (`:343`) ; puis la règle du RPC (`:122`), défaut `10` puis `4/s` | `source > 0` (`:341`), RPC connu (`:115`), au plus `8` requêtes simultanées (`:128`), handler isolé par `xpcall` (`:144`), codes seuls renvoyés au client | avant la limite globale : `tonumber(source)` seulement ; avant la limite du RPC : tests de type de `id`/`name`, recherche dans `handlers`, un avertissement limité à un par 10 s et par joueur (`:78-83`) |
| `vAvA:rpc:clientResponse` (`rpc.lua:347`) | évènement serveur | `id` entier, `ok == true`, `count` `0..16`, `results` table sans métatable (`:182-183`), puis `returns` si fourni (`:188-197`) | global | `entry.meta.source == src` : un client ne répond jamais pour un autre (`:174`) | `returns` facultatif : voir IMPORTANT 1 |
| `core:characters:list` (`server/players/characters.lua:553`) | RPC | `{}` | `5` puis `1/s` | session existante | renvoie résumés du compte, maximum, règles de nom (~200 o) |
| `core:characters:create` (`:560`) | RPC | deux chaînes `1..96` octets (`:548`), `sex` enum `cfg.sexes` | `2` puis `0,05/s` | `withSession(src, 'joined')` + verrou `busy` (`:202-221`), `maxPerAccount` (`:292`), `validateName` : bords retirés, 2–24 caractères, lettres et séparateurs de la config, UTF-8 valide (`:111-129`), hook before `core:character:creating` fail-closed (`:253`), session toujours courante avant l'INSERT (`:257`), réservation du nom si `uniqueNames` (`:305-312`) | reste ouvert aux clients à côté de `vava_appearance:create` : décision du porteur attendue (T-007, « Décisions à confirmer »), non comptée ici |
| `core:characters:select` (`:563`) | RPC | entier `1..0xFFFFFFFF` | `3` puis `0,2/s` | état `joined`, possession en mémoire (`:320`), `busy` si déjà chargé (`:323`), SELECT avec `account_id = ?` (`:45-46`, `:331`), session courante après chaque attente (`:332`, `:353`) | un personnage non sauvegardé repris de `retry` (`:327`) : même contrôle de possession |
| `core:characters:unload` (`:566`) | RPC | `{}` | `2` puis `0,1/s` | état `active` + verrou | aucun hook `before` : voir MINEUR 2 |
| `core:characters:delete` (`:569`) | RPC | entier `1..0xFFFFFFFF` | `2` puis `0,05/s` | état `joined` (jamais le personnage actif), possession (`:391`), hook before `core:character:deleting` (`:393`), UPDATE avec `account_id = ?` et `deleted_at IS NULL` (`:50`, `:395`) | suppression douce, journalisée (`:399`) |
| `core:characters:spawned` (`:572`) | RPC (emit) | `{}` | `3` puis `0,5/s` | état `active`, une fois par ordre d'apparition (`:577`) | simple déclaration du client : voir MINEUR 3 |
| `playerConnecting` (`server/players/accounts.lua:228`, branché `:381`) | évènement FiveM (deferrals) | license obligatoire (`:246`) | celle de FiveM | core prêt ou attente bornée 60 s (`:235-244`), une license = une session vivante (`:252-261`), hook before `core:player:connecting` fail-closed (`:266`), aucun compte créé avant l'accord (`:265`, `:277`), session remplacée détectée (`:267`, `:188`) | le pseudo `name` est transmis brut aux hooks : voir MINEUR 5 |
| `playerJoining` (`:294`) | évènement FiveM | — | — | session en `connecting` avec compte, sinon `DropPlayer` (`:299-302`) | |
| `playerDropped` (`server/init.lua:485`) | évènement FiveM | — | — | purge RPC et débit, fermeture de session qui attend l'action en cours (`characters.lua:427-437`), déchargement + sauvegarde, purge sync | |
| `onResourceStop` (`init.lua:495`) | évènement FiveM | — | — | purge hooks, RPC, registres, champs du propriétaire (`:448-453`), module en `stopping` | voir MINEUR 4 |
| `getApi(major)` (`shared/core/api.lua:77`, exporté `:144`) | export | `major` entier connu | — | propriétaire = `GetInvokingResource()` (`:78`), surface gardée par `modules.isActive` côté serveur (`server/core/api.lua:176-181`) | appelable par des ressources seulement (serveur ou client), jamais par le réseau ; une ressource nommée `core` ne peut pas se déclarer (`modules.lua:273`) |
| `vava_saveall` (`server/players/persistence.lua:176-185`) | commande | — | — | `RegisterCommand(…, true)` : console et ACE seulement | |
| hooks before du core | hook | — | — | `core:player:connecting` (`accounts.lua:266`), `core:character:creating` (`characters.lua:253`), `core:character:deleting` (`:393`) : erreur = refus (`shared/core/hooks.lua:172-175`), ordre par priorité puis inscription (`:48-51`) | les handlers d'autres ressources reçoivent une copie du payload ; le core n'utilise jamais le payload après le hook pour décider (variables locales) |
| state bags du joueur (`server/players/sync.lua:204`, `:216`, `:228`) | state bag | valeurs validées par le schéma du champ | — | écrits seulement, **jamais lus** côté serveur (le serveur lit `character.data`, `fields.lua:88`) | voir IMPORTANT 2 |
| `vAvA:rpc:response`, `vAvA:rpc:clientRequest` (`client/core/rpc.lua:122`, `:131`) ; `vAvA:character:loaded/fields/unloaded` (`client/players/session.lua:40-67`) ; `vAvA:character:spawn` (`client/players/spawn.lua:225-231`) | évènements client | types vérifiés (`spawn.lua:226-229`, `session.lua:41-42`) | — | émis par le serveur seulement ; un autre client ne peut pas les déclencher (pas d'évènement client → client dans FiveM) ; un client peut les déclencher localement chez lui, sans effet ailleurs | |

## BLOQUANT

Aucun.

## IMPORTANT

- `server/core/rpc.lua:188-198`, `docs/api.md:308-311` — **`returns` facultatif dans `callClient`** — sans schéma de
  retour, les valeurs renvoyées par le client (jusqu'à 16, `:182`) sont remises au module telles quelles : forme,
  taille, profondeur et métatables imbriquées ne sont pas contrôlées, alors que `args` est obligatoire et que
  `CLAUDE.md:58` impose « toujours `returns` ». Aucun module n'appelle `callClient` aujourd'hui (recherche dans
  `modules/`) : rien d'exploitable maintenant, mais le premier module qui l'oubliera recevra des données libres d'un
  client. Correction : exiger `returns` comme `args` (`{}` admis, alors toute valeur renvoyée est refusée), ou au
  minimum répondre `invalid_response` quand `returns` est absent et `count > 0`.
- `server/players/sync.lua:204`, `:216`, `docs/api.md:212` — **un champ `public` peut être falsifié chez les autres
  clients** — la valeur est publiée dans le state bag du joueur ; le client propriétaire peut réécrire son propre bag
  avec réplication (`LocalPlayer.state:set(champ, valeur, true)`, usage courant de FiveM, non vérifié ici en jeu), et
  tous les autres clients voient la valeur forgée. Le serveur n'est pas trompé (il ne relit jamais le bag), mais tout
  module qui afficherait ou déciderait côté client d'après `Player(x).state[champ]` d'un autre joueur le serait ;
  `vava_inventory` a dû le contourner seul pour `hands` (`GlobalState['vava_inventory:heldModels']`). Correction :
  écrire dans `docs/api.md` que la valeur d'un champ `public` lue sur un autre client n'est pas authentique ; et, si
  c'est possible dans FiveM (à vérifier : `AddStateBagChangeHandler` côté serveur et l'origine du changement), remettre
  la valeur serveur dès qu'un changement ne vient pas de lui.

## MINEUR

- `server/core/rpc.lua:150-159` — **réponse livrée sans revérifier le joueur** — après un handler lent (attente de la
  base), `reply(src, id, …)` part vers `src` même si le joueur s'est déconnecté entre-temps ; si FXServer réattribue
  cet identifiant à un nouveau venu dont un appel porte le même petit numéro (chaque client compte à partir de 1,
  `shared/lib/pending.lua:40-48`), ce dernier reçoit la réponse de l'autre (par exemple sa liste de personnages). La
  fenêtre est courte et la réattribution n'est pas vérifiée ici. Correction : étendre la comparaison déjà faite ligne
  146 (`playerStates[src] == state`, l'état étant purgé par `rpc.purgePlayer`) pour ne plus répondre si elle échoue ;
  même précaution dans `sync.fieldChanged` (`sync.lua:214-217`, appelé par les hooks de déchargement d'une session
  déconnectée, sans `DoesPlayerExist` contrairement à `clearCharacter`, `:225`).
- `server/players/characters.lua:566-568`, `:367-384` — **aucun hook `before` sur le déchargement** — un client
  modifié appelle `core:characters:unload` n'importe quand (à terre, en incantation, en échange) ; aucun module ne peut
  le refuser, seul `core:character:unloading` (after) permet d'annuler. Sans effet aujourd'hui : `vava_health` garde
  `downed` dans un champ persistant et le relit au chargement (`modules/vava_health/server/life.lua:87-91`, `:303`), et
  l'inventaire n'a pas d'échange en plusieurs temps ; une déconnexion ne pourrait de toute façon pas être refusée.
  Correction si un module le demande un jour : une phase `before` de `core:character:unloading`, raison renvoyée au
  client.
- `server/players/characters.lua:572-582`, `server/players/positions.lua:265-278` — **`spawned` est une déclaration**
  — un client qui ignore l'ordre `vAvA:character:spawn` et confirme quand même fait relever la position de son ped là
  où il est, et démarre le temps de jeu ; le ped étant sous l'autorité du client (OneSync), il n'obtient rien de plus
  qu'un téléport local, mais `core:character:spawned` ne prouve pas que le ped est au point décidé par le serveur.
  Correction : le dire dans `docs/api.md` ; un module qui téléporte par `core.characters.spawn` revérifie la distance
  côté serveur avant d'en tirer une conséquence.
- `server/core/rpc.lua:296-300`, `config/server.lua:32` — **`maxPending` global à tous les joueurs** — un client qui
  ne répond jamais à `callClient` retient chaque entrée jusqu'à son timeout (10 s par défaut, 60 s au plus) ; un module
  qui appellerait `callClient` à chaque intention d'un joueur pourrait se faire saturer le store (4096) par un seul
  client, code `saturated` pour tous. Aucun appelant aujourd'hui. Correction : plafond par cible (`busy` au-delà).
- `server/init.lua:504-506`, `server/core/modules.lua:302-305`, `:356-374` — **API complète pendant `stopping`** — la
  purge (`purgeOwner`) précède le passage en `stopping`, mais le module garde toute l'API jusqu'au tour suivant : un
  `onResourceStop` qui enregistre encore un RPC, un hook ou une entrée de registre laisse une entrée orpheline
  (funcref d'une ressource arrêtée, `server_error` à chaque appel, jamais purgée). Erreur de module, pas d'attaque.
  Correction : rappeler `purgeOwner` dans `finishStop`, ou ne laisser que `db` et `log` pendant `stopping`.
- `server/players/accounts.lua:266` — **pseudo transmis brut** — `name` (choisi librement par le client : longueur,
  codes couleur `^1`, caractères de contrôle, balises) est passé tel quel aux hooks `core:player:connecting` ; le core
  ne le journalise pas, mais un module qui l'écrirait en console ou dans une page sans `sanitize`/échappement serait
  injectable (`vava_admin/server/bans.lua:61` et `vava_chancellerie/server/whitelist.lua:62` s'y abonnent ; aucun ne
  lit `name` d'après la recherche). Correction : le dire dans `docs/api.md`, ou passer un `name` déjà borné
  (`str.sanitize(name, 64)`) et garder le brut sous une autre clé.

## Points solides

- Une seule porte réseau, contrôles du moins au plus coûteux, seau global consommé avant même de regarder le
  message, clés de débit choisies par le serveur, tout l'état d'un joueur purgé à sa déconnexion (`rpc.lua:338-352`,
  `ratelimit.lua:64-110`) ; les avertissements console sont limités à un par 10 s et par joueur ou par RPC.
- Schémas : bornes injectées en réseau, `any`/`function`/`strict = false` interdits, `NaN` et `±inf` refusés,
  métatables refusées à tout niveau, sorties anticipées sur les tables géantes (`schema.lua:236-238`, `:253-255`,
  `:375-379`), profondeur bornée par le schéma lui-même ; le tout couvert par `core_schema_spec` et `core_rpc_spec`.
- Personnages : un verrou `busy` par session, possession revérifiée en mémoire **et** en SQL (`account_id = ?`),
  session courante retestée après chaque attente, fermeture de session qui attend l'action en cours, noms uniques
  réservés en mémoire, création et suppression journalisées.
- Connexion : une license = une session, aucun compte créé avant l'accord des hooks, sessions fantômes et connexions
  abandonnées libérées, seule la license conservée.
- SQL : cent pour cent paramétré derrière `database.lua` (paramètres obligatoires, `:61-64`) ; migrations à empreinte,
  sérialisées, propriétaire = nom de ressource, jamais rejouées.
- Isolation des ressources : propriétaire tiré de `GetInvokingResource`, préfixe `owner:` avec le deux-points
  (`vava_a` ne couvre pas `vava_ab:`), `core` réservé, purge complète à l'arrêt ou à l'échec, réponse d'un client
  comparée à la source attendue.

VERDICT : À CORRIGER (aucun bloquant ; deux points IMPORTANT qui sont des gardes manquantes pour les modules à venir,
le reste est du durcissement).
