# vAvA_core — API publique v1

Destinée aux développeurs de modules. Le core n'expose **qu'un seul export** : `getApi`.
Tout le reste (hooks, registres, RPC, base de données) passe par la table qu'il renvoie.

```lua
local core, err = exports.vAvA_core:getApi(1)   -- 1 = version majeure de l'API
```

- La table renvoyée est liée à la ressource appelante : tout ce qu'elle enregistre porte son nom et est
  **purgé automatiquement** à l'arrêt de la ressource (ou à l'échec du module).
- Une version majeure inconnue renvoie `nil, err`. Une nouvelle majeure n'est créée que pour un changement
  incompatible ; les anciennes restent servies tant qu'elles sont déclarées.
- Les fonctions qui attendent une réponse (`db.*`, `rpc.callClient*`, `rpc.call*`) **bloquent le thread
  courant** : à appeler depuis `setup`, un handler d'event/RPC/hook, ou un `CreateThread`.

## Points communs

### Convention de retour

Aucune fonction de l'API ne lève d'erreur. Elles renvoient `valeur` ou `false/nil, err`.

### Espaces de noms

Les hooks déclenchés, RPC et registres d'un module doivent commencer par `<nom_de_la_ressource>:`.
Exemple pour la ressource `vava_inventory` : `vava_inventory:items`, `vava_inventory:move`.
On peut **s'abonner** à n'importe quel hook, mais on ne **déclenche** que les siens.
Le préfixe `core:` est réservé au core.

### Copies entre ressources

Toute valeur qui traverse un export est sérialisée (msgpack). Conséquences :

- un hook reçoit une **copie** du payload : le modifier n'a aucun effet sur l'appelant (lecture seule par contrat) ;
- `registry.get` / `registry.all` renvoient des copies : lire une fois, garder en cache, se tenir à jour via
  les hooks `core:registry:*` ;
- chaque appel d'API coûte quelques microsecondes : à éviter dans une boucle serrée ;
- une table **mixte** (liste + clés nommées, ex. `{ 'a', 'b', label = 'x' }`) est sérialisée comme une liste :
  ses clés nommées sont **perdues**. Utiliser soit une liste pure, soit une table à clés nommées uniquement.

### Schémas

Utilisés par les arguments de RPC, les retours client et les entrées de registre.

| Champ | Types concernés | Effet |
|---|---|---|
| `type` | tous | `string`, `number`, `integer`, `boolean`, `table`, `array`, `map`, `function`, `any` ; `integer` n'accepte un flottant que s'il a un équivalent entier Lua (`3.0` oui, `1e300` non), et un RPC le convertit en entier avant le handler, à tout niveau (argument, champ de table, élément de liste, valeur de map ; 0.8.1) |
| `optional` | tous | `nil` accepté |
| `min` / `max` | string (longueur en octets), number/integer (valeur), array/map (nombre d'éléments) | bornes incluses ; entières pour string, array et map ; jamais `NaN` |
| `pattern` | string | motif Lua (ancrer avec `^` et `$`) |
| `enum` | string, number, integer | liste des valeurs autorisées (sans `NaN`) |
| `fields` / `strict` | table | champs attendus ; `strict` (défaut `true`) refuse les clés inconnues |
| `items` | array | schéma de chaque élément |
| `key` / `value` | map | schémas des clés (string ou integer) et des valeurs |

`function` accepte une fonction locale ou venant d'une autre ressource (callbacks d'entrées de registre).
Une définition qui se contient elle-même, directement ou non (`def.items = def`), est refusée à la compilation (0.8.1) ;
une même table de définition reprise à plusieurs endroits distincts reste permise.

Pour une **entrée réseau** : `any`, `function` et `strict = false` sont refusés, et les chaînes, listes et maps sans `max`
reçoivent la borne de `config/server.lua` (`schema.*`). `NaN` et `±inf` sont toujours refusés.

```lua
{ type = 'table', fields = {
    slot = { type = 'integer', min = 1, max = 40 },
    note = { type = 'string', max = 120, optional = true },
} }
```

## Serveur

### `core.modules`

```lua
local ok, err = core.modules.register({
    version = '1.0.0',                          -- version du module
    coreVersion = '0.1.0',                      -- version minimale du core
    dependencies = { vava_inventory = '1.2.0' },-- modules vAvA requis et leur version minimale
    setup = function()                          -- appelé une fois tout prêt ; false[, raison] pour refuser
        return true
    end,
})
```

- Le nom du module est **imposé** : c'est celui de la ressource.
- `register` ne bloque pas. Les erreurs de forme sont renvoyées tout de suite ; le reste est asynchrone :

```
declared → waiting → migrating → starting (setup) → ready
                 ↘ failed (message explicite dans la console, tout ce que le module a enregistré est purgé)
```

- `waiting` : attend que le core soit prêt, puis chaque dépendance (`config/server.lua` →
  `modules.dependencyTimeoutMs`). Échec immédiat si la ressource dépendante est absente ou arrêtée, si sa version
  est insuffisante, ou en cas de dépendance circulaire.
- Déclarer aussi les dépendances dans le fxmanifest (`dependency 'vava_inventory'`) pour l'ordre de démarrage.
- À l'arrêt de sa ressource, un module passe par `stopping` et ne disparaît qu'au **tour suivant** (0.8.1) : son propre
  gestionnaire `onResourceStop` garde l'API (`core.db` pour un journal, par exemple), quel que soit l'ordre des
  gestionnaires d'arrêt entre le core et lui. Une ressource redémarrée dans le même tour se redéclare sans attendre.
- **Toute l'API (hors `log`, `modules` et `version`) est refusée tant que le module n'est pas en `starting` ou
  `ready`** : enregistrer hooks, registres et RPC dans `setup`.

| Fonction | Retour |
|---|---|
| `register(def)` | `true` ou `false, err` |
| `get(name)` | `{ name, version, state, error?, dependencies }` ou `nil` |
| `list()` | liste triée des modules connus |

### `core.log`

`debug(fmt, ...)`, `info`, `warn`, `error` — préfixés par le nom du module, formatés seulement si le niveau
est affiché (`config/server.lua` → `log.level`).

### `core.hooks`

| Fonction | Retour |
|---|---|
| `before(name, handler, priority?)` | `id` ou `nil, err` |
| `after(name, handler, priority?)` | `id` ou `nil, err` |
| `off(id)` | `true` ou `false, err` (seulement ses propres hooks) |
| `runBefore(name, payload)` | `true`, ou `false, raison` |
| `runAfter(name, payload)` | `true` ou `false, err` |

- Ordre : priorité croissante (défaut 100, bornes 0–1000), puis ordre d'inscription.
- `before` : renvoyer `false, 'raison'` annule l'action ; toute autre valeur la laisse continuer.
- **Un handler `before` en erreur annule l'action** (raison `'hook_error'`) et l'erreur est journalisée.
- Un handler `after` en erreur est journalisé ; les suivants s'exécutent quand même.
- Les handlers lents (`config/shared.lua` → `hooks.slowHandlerMs`) sont signalés.

```lua
local allowed, reason = core.hooks.runBefore('vava_inventory:move', payload)
if not allowed then return false, reason end
-- … effectuer l'action …
core.hooks.runAfter('vava_inventory:move', payload)
```

#### Hooks émis par le core (phase after)

| Nom | Payload |
|---|---|
| `core:module:ready` | `{ name, version }` |
| `core:module:failed` | `{ name, version, reason }` |
| `core:module:stopped` | `{ name, version, dependents }` |
| `core:registry:added` | `{ registry, key, owner }` |
| `core:registry:removed` | `{ registry, key, owner, reason }` — `reason` : `removed` ou `owner_stopped` |
| `core:registry:dropped` | `{ registry, owner }` — registre supprimé avec son propriétaire |
| `core:ratelimit:exceeded` | `{ source, key, suppressed }` — au plus un par intervalle et par (joueur, clé) |
| `core:player:joined` | `{ source, accountId }` |
| `core:player:dropped` | `{ source, accountId, reason }` — après déchargement et sauvegarde du personnage |
| `core:character:created` | `{ source, accountId, characterId, firstName, lastName, sex }` — inventaire de départ, compte… |
| `core:character:loaded` | `{ source, accountId, characterId, playSeconds }` — chargez vos données ici (avant l'apparition) |
| `core:character:spawned` | `{ source, accountId, characterId }` — apparition confirmée par le client (chaque apparition, réanimation comprise) : le ped est en place, sa vie et sa position sont lisibles |
| `core:character:unloading` | `{ source, accountId, characterId, reason, playSeconds }` — sauvez vos données ici (le core attend) ; `playSeconds` : temps de jeu total, cette session comprise |
| `core:character:deleted` | `{ source, accountId, characterId }` |
| `core:character:fieldChanged` | `{ characterId, field, value }` |

#### Hooks before du core (annulables)

| Nom | Payload | Effet d'un refus `false, raison` |
|---|---|---|
| `core:player:connecting` | `{ source, license, name, accountId? }` | connexion refusée ; `raison` est affichée au joueur (ban, whitelist, file). `accountId` : compte déjà connu de cette license (absent à la première venue, aucun compte n'étant créé avant l'accord des hooks). Depuis 0.9.1, un `accountId` absent veut toujours dire « première venue » : si la base ne répond pas à la recherche du compte, la connexion est refusée (`players.messages.unavailable`) avant les hooks |
| `core:character:creating` | `{ source, accountId, firstName, lastName, sex }` | création refusée ; `raison` renvoyée au client |
| `core:character:deleting` | `{ source, accountId, characterId }` | suppression refusée ; `raison` renvoyée au client |

`source` dans `core:player:connecting` est l'identifiant **temporaire** de connexion. La `license` et le pseudo
ne sont transmis qu'aux hooks serveur : le core ne les stocke pas (seule la license l'est, comme clé de compte).
Une connexion pendant le démarrage du core attend au plus `players.coreWaitTimeoutMs` (60 s par défaut, 0.7.2), puis
reçoit `players.messages.stillStarting` (« réessayez dans un instant ») ; les modules, eux, attendent le core sans
limite. Une connexion acceptée puis abandonnée pendant le chargement (FiveM fermé) libère sa license dès que FXServer
ne connaît plus son identifiant temporaire (0.7.3) : relevé toutes les `players.connectCheckMs` (5 s), license libérée
après deux relevés manquants, au plus tard après `players.connectTimeoutMs` (120 s). Un joueur qui charge
normalement n'est jamais concerné.

**Porte gardée** (0.9.1) : un module qui vérifie chaque arrivant par un hook (les bans de `vava_admin`) se déclare
dans `players.connectionGuards` (`{ 'vava_admin' }` par défaut). Tant que son module n'est pas `ready` — démarrage,
redémarrage, échec du `setup`, ou ressource arrêtée (`stopped`, `uninitialized`) —, ses hooks n'existent pas : la
connexion est refusée avec `players.messages.guardNotReady` (« Le royaume s'éveille : réessayez dans un instant. ») et
une ligne d'erreur à la console, vérifiée avant les hooks puis de nouveau après (garde arrêté pendant la chaîne). Pour
une ressource arrêtée, la console ajoute « ensure <ressource>, ou retirez-le de players.connectionGuards si le serveur
n'a pas de Registre » : un `restart vAvA_core` arrête `vava_admin` (qui en dépend) sans le relancer, et la porte reste
fermée jusqu'à `ensure vava_admin`. Seule une ressource absente du serveur (`missing`) n'est pas attendue : la
connexion passe, avec un avertissement à la console à chaque fois (ce que le garde vérifie ne l'est pas). Une entrée de
la liste qui n'est pas un nom de ressource est ignorée et signalée à la console. Un garde arrêté ou en échec garde donc
la porte fermée jusqu'à ce qu'il soit relancé, réparé ou retiré de la liste.

### `core.players`

| Fonction | Retour |
|---|---|
| `get(source)` | `{ source, accountId, state, characterId }` ou `nil` |
| `getByAccount(accountId)` | `source` ou `nil` |

États d'une session : `connecting` → `joined` (en sélection) → `loading` → `active` → `unloading` → `joined`.

### `core.characters`

| Fonction | Retour |
|---|---|
| `defineField(name, { schema, default?, visibility? })` | `true` ou `false, err` |
| `create(source, { firstName, lastName, sex }, initialFields?)` | `true, résumé` ou `false, code` — création par un module, avec des valeurs de champs déclarés (validées par leur schéma, sinon `invalid_fields`) |
| `getActive(source)` | `{ id, accountId, source, firstName, lastName, sex, playSeconds }` ou `nil` |
| `playSeconds(characterId)` | temps de jeu en secondes entières (temps en cours compris), ou `nil, 'not_loaded'` — compté côté serveur entre l'apparition confirmée et le déchargement, la sélection exclue ; relevé toutes les `persistence.positionSampleMs`, écrit avec le personnage (colonne `play_seconds`) ; depuis 0.6.0 |
| `get(characterId, field)` | valeur (défaut si jamais écrite), ou `nil, 'not_loaded' \| 'unknown_field'` |
| `set(characterId, field, value)` | `true` ou `false, err` — validé, sauvegardé, diffusé |
| `unload(source)` | `true` ou `false, code` — retour à la sélection |
| `spawn(source, coords?)` | `true` ou `false, code` — `{ x, y, z, heading? }` ; sans coordonnées : dernière position |

Champs de personnage :

```lua
core.characters.defineField('mon_module:reputation', {
    schema = { type = 'integer', min = 0, max = 100 },
    default = 50,
    visibility = 'owner',
})
local reputation = core.characters.get(character.id, 'mon_module:reputation')
core.characters.set(character.id, 'mon_module:reputation', reputation + 5)
```

| Visibilité | Qui reçoit la valeur |
|---|---|
| `private` (défaut) | personne : serveur uniquement |
| `owner` | le seul joueur du personnage ; plusieurs `set` d'un même tick partent en un seul event |
| `public` | tous les clients (statebag du joueur répliqué) : à réserver à ce qui doit vraiment être vu |

- Les valeurs sont stockées dans la colonne JSON `data` du personnage. Les données volumineuses (inventaire,
  comptes…) vont dans les tables du module, qui référencent `vava_characters.id`.
- Seuls les personnages **chargés** sont accessibles ; un `set` identique à la valeur actuelle ne coûte rien.
- À l'arrêt du module, sa définition disparaît mais les valeurs restent dans `data` et réapparaissent à son
  redémarrage.
- Rien ne part vers un joueur pour un personnage qui n'est plus le sien (0.9.0) : un `set` fait pendant le hook
  `core:character:loaded` part avec l'envoi complet qui suit ; après le déchargement ou le départ du joueur (hook
  `core:character:unloading` compris), la valeur est enregistrée mais n'est plus envoyée, ni par event ni par statebag.

**Champ `public` : la valeur lue sur un client n'est pas authentique.** Le statebag d'un joueur peut être réécrit par
son propre client, et les autres clients voient alors la valeur forgée. Le serveur ne relit jamais ce statebag (il
fait foi par `characters.get`) et, depuis 0.9.0, garde les champs publics : à chaque changement d'un champ public
qu'il voit sur le statebag d'un joueur et qui diffère de la valeur qu'il a publiée, il remet la sienne après
`sync.publicGuardDelayMs` (250 ms ; les réécritures d'un même joueur dans ce délai ne coûtent qu'une remise) et le
signale en console (`[sync] joueur N : champ(s) public(s) réécrit(s) par son client`). Entre la réécriture et la
remise, les autres clients voient la valeur forgée ; si le serveur ne voit pas la réécriture, elle reste. Un client
ne décide donc jamais rien d'après `Player(x).state[champ]` d'un autre joueur, sinon de ce qui ne se voit que chez
lui ; il le recoupe avec une donnée publiée par le serveur ailleurs (comme `vava_inventory` le fait du statebag du ped
avec `GlobalState['vava_inventory:heldModels']`). Les statebags qu'un module pose lui-même (entité, joueur) ne sont pas
gardés par le core : même règle, et le module les garde lui-même s'il le faut (voir l'objet en main de
`vava_inventory` 1.7.0). Un champ `public` part chez **tous** les joueurs connectés : ce que seuls les joueurs proches
doivent voir va plutôt sur le statebag du ped, répliqué aux seuls joueurs qui l'ont à portée.

Détails de la garde (0.9.0) :
- La comparaison tolère l'arrondi du réseau sur les nombres non entiers (`sync.publicFloatTolerance`, écart relatif
  de 1e-6) ; entiers, chaînes et booléens sont comparés à l'identique.
- Après `sync.publicMaxCorrections` (3) remises d'un même champ sans nouvelle publication du serveur, les remises
  s'espacent (délai doublé à chaque fois, jusqu'à `sync.publicGuardMaxDelayMs` = 10 s) et une ligne unique le dit en
  console (`remis 3 fois de suite sans nouvelle publication`) : une valeur qui ne reviendrait jamais égale coûte au
  plus une écriture par 10 s, un client qui insiste est toujours remis, de plus en plus tard. Toute publication remet
  le compte à zéro.
- Le schéma d'un champ `public` est compilé **comme une entrée réseau** (ni `any`, ni `function`, ni table
  `strict = false` ; chaînes, listes et maps bornées par `schema.*` de la config du core) et ne peut pas avoir plus de
  `sync.publicCompareDepth` (16) niveaux de tables imbriquées : `defineField` refuse sinon. Les champs `private` et
  `owner` ne changent pas.

Persistance et positions :

- La position est lue **côté serveur** (OneSync obligatoire), seulement après confirmation de l'apparition.
- Sauvegarde groupée des personnages modifiés toutes les `persistence.saveIntervalMs`, et immédiate au
  déchargement ou à la déconnexion. Une écriture en échec est retentée sans perte.
- FiveM n'attend pas les écritures à l'arrêt du serveur : **lancer `vava_saveall` avant `quit`**.

Apparition : le core remplace `spawnmanager`. Ne pas démarrer `spawnmanager`, `basic-gamemode` ni de carte
`mapmanager` avec vAvA_core. Un personnage sans position enregistrée (donc tout nouveau personnage) apparaît à
`spawn.defaultPoint` de `config/server.lua` : c'est le **point d'arrivée** des nouveaux venus (`vava_arrival`, T-022),
marqué `-- PLACEHOLDER` jusqu'à la carte du royaume. Aucune API ne permet à un module de choisir ce point (le
personnage est encore en chargement pendant `core:character:loaded`) : un point d'arrivée géré par l'Atelier demandera
une petite API du core.

### `core.registry`

| Fonction | Retour |
|---|---|
| `define(name, { schema, validator?, maxEntries? })` | `true` ou `false, err` |
| `add(name, key, data)` | `true` ou `false, err` |
| `remove(name, key)` | `true` ou `false, err` (auteur de l'entrée ou propriétaire du registre) |
| `get(name, key)` | donnée (copie) ou `nil` |
| `has(name, key)` / `exists(name)` | booléen |
| `all(name)` | `{ [key] = data }` (copie) ou `nil` |

- Les clés suivent le motif d'identifiant (`config/shared.lua` → `identifiers`). Une clé prise est refusée.
- `validator(key, data)` doit renvoyer **`true`** pour accepter ; `false, raison` ou une erreur refusent l'entrée.
- À l'arrêt du propriétaire d'un registre, le registre disparaît avec toutes ses entrées.

#### Registre des commandes `core:commands` (core 0.7.0)

Le core tient un registre où **chaque module déclare ses commandes et ses touches** ; le Codex (`vava_codex`) le lit
pour les afficher, composer leurs arguments et les lancer, et le chat pour ses suggestions. Déclarer ne remplace pas
`RegisterCommand` : la commande reste enregistrée et contrôlée par son module. La clé est le nom de la commande
(sans `/`, sans `+`). Convention : un fichier `server/commands.lua` par module, `VavaX.commands.declare()` appelé en
tête du `setup`, noms tirés de la config, et `core.registry.exists('core:commands')` vérifié d'abord (core plus ancien :
rien n'est déclaré).

```lua
core.registry.add('core:commands', 'recolte', {
    kind = 'command',                 -- ou 'key' : une touche (RegisterKeyMapping), avec `key`
    module = 'vava_gathering', chapter = 'Récolte',
    label = 'Zones et nœuds de récolte', description = '…',
    scope = 'admin',                  -- 'player' (tout le monde), 'admin' (Conseil), 'console'
    permission = 'metiers', ace = 'metiers.admin',   -- scope admin : droit vava_admin, repli ACE
    actions = {                       -- sous-commandes ; une action sans `id` est la forme nue
        { id = 'zones', label = 'État des zones' },
        { id = 'vitalite', label = 'Fixer la vitalité', args = {
            { name = 'zone', type = 'list', list = 'zones' },
            { name = 'vitalité', type = 'integer', min = 0, max = 100 },
        } },
    },
})
core.registry.add('core:commands', 'vava_gathering_interact', {
    kind = 'key', scope = 'player', module = 'vava_gathering', chapter = 'Récolte',
    label = 'Récolter (nœud proche)', key = 'E', hold = true,   -- keyDevice, keyDisplay (« Clic droit », « 1 à 5 »)
})
```

Une commande sans sous-commande porte ses `args` directement. Types d'argument : `player` (joueur en jeu), `account`
(numéro de compte), `integer` / `number` (bornés par `min`, `max`, `step`), `text` (`rest = true` : tout le reste de
la ligne, en dernière position), `choice` (`choices`, libellés dans `labels`), `registry` (clés d'un registre du core,
affichées par `labelField`, défaut `label`) et `list` : valeurs rendues par l'export **`codexList(list)`** du module
déclarant, `{ { value, label }, … }` (zones, stations, parcelles…). `optional`, `hint`, `hidden` (commande technique)
complètent. Le validateur refuse une touche sans `key`, `actions` et `args` ensemble, deux actions nues, une
sous-commande en double, un `choice` sans `choices`, un `rest` ailleurs qu'en dernier texte.

### `core.rpc`

```lua
core.rpc.register('vava_shop:buy', {
    args = {
        { type = 'string', max = 32, pattern = '^[%w_]+$' },
        { type = 'integer', min = 1, max = 100 },
    },
    rateLimit = { capacity = 5, refillPerSecond = 1 },   -- optionnel
    latent = 'auto',                                      -- optionnel (0.10.0) : 'auto' ou 'never'
}, function(source, itemName, amount)
    return true, newBalance
end)
```

- `args` est **obligatoire** (`{}` si aucun argument) : aucun RPC n'accepte de données non décrites.
- Contrôles avant le handler : source réseau, limite globale du joueur, RPC connu, limite du RPC, nombre de
  requêtes simultanées du joueur, schéma des arguments.
- Le handler reçoit `source` puis les arguments validés. Ses valeurs de retour sont envoyées **au seul
  joueur appelant**, et seulement s'il est toujours là : un joueur parti pendant un handler lent (attente de la base)
  ne reçoit rien, pas plus que celui qui aurait repris son numéro entre-temps (0.9.0).
- Depuis 0.10.0, réponses et appels serveur → client passent par `core.net` : mesurés, comptés sous la ressource du
  RPC (`rpc <nom>`, `callClient <nom>` ; un RPC inconnu sous `vAvA_core`, `rpc <inconnu>`, jamais sous le nom reçu),
  bornés à `net.maxBytes` (256 Ko). Une réponse de plus de `net.latent.threshold` (8 Ko) part **en latent**
  (64 Ko/s), précédée d'un préavis fiable `vAvA:rpc:latent` (id, octets, débit, délai) : le client repousse l'attente
  de l'appel du délai jusqu'à l'arrivée de la réponse (latents déjà en route vers lui compris, au moins le transfert
  de la réponse seule) plus `rpc.latentMarginMs` (3 s), au plus `rpc.maxLatentExtendMs` (30 s), et rien ne
  change pour le module client (`rpc.call` rend les mêmes valeurs). `latent = 'never'` garde la réponse fiable quelle
  que soit sa taille : pour un état que des différences suivront aussitôt (voir l'ordre, § `core.net`). Toute autre
  valeur fait échouer `register`. Un `callClient` dont les arguments dépassent le seuil part aussi en latent, et
  l'attente du serveur est allongée selon la même règle.

| Fonction | Retour |
|---|---|
| `register(name, options, handler)` | `true` ou `false, err` |
| `unregister(name)` | `true` ou `false, err` |
| `callClient(target, name, ...)` | `true` ou `false, code` — ordre sans valeur de retour : une réponse qui en porte est refusée (`invalid_response`) |
| `callClientWith({ timeout?, returns }, target, name, ...)` | `true, ...valeurs` ou `false, code` — `returns` **obligatoire** (`{}` si aucune valeur attendue), sinon `invalid_options` sans rien envoyer |

```lua
local ok, timer = core.rpc.callClientWith({
    timeout = 5000,
    returns = { { type = 'integer', min = 0 } },
}, source, 'vava_example:ping')
```

Ce que renvoie un client est **déclaratif et non fiable** : depuis 0.9.0, aucune valeur non décrite ne remonte
(`returns` est exigé comme `args` l'est pour un RPC, avec les mêmes bornes réseau) ; une valeur validée ne sert
jamais de source de vérité.

#### Codes d'erreur RPC

| Code | Sens |
|---|---|
| `timeout` | pas de réponse dans le délai |
| `rate_limited` | limite du RPC atteinte pour ce joueur |
| `busy` | trop de requêtes simultanées pour ce joueur |
| `unknown_rpc` | aucun RPC de ce nom |
| `invalid_args` | arguments refusés par le schéma (détail dans la console serveur uniquement) |
| `server_error` | le handler serveur a levé une erreur (détail dans la console serveur uniquement) |
| `saturated` | trop d'appels en attente ; ou (0.10.0) plus de 512 Ko d'envois latents déjà en route vers ce joueur : la réponse, ou la demande de `callClient`, n'est pas partie |
| `too_large` | (0.10.0) réponse, ou arguments de `callClient`, au-delà de `net.maxBytes` (256 Ko) : rien n'est parti que ce code ; nom du RPC et taille dans la console serveur |
| `unserializable` | (0.10.0, `callClient`) arguments impossibles à envoyer (fonction, cycle, profondeur au-delà de 32) ; une réponse de handler dans ce cas arrive au client en `server_error` |
| `invalid_target` / `invalid_name` / `invalid_options` | appel mal formé (`invalid_options` : timeout hors bornes, `returns` absent, refusé ou de plus de `rpc.maxReturns` = 16 valeurs ; détail dans la console serveur) |
| `dropped` | joueur déconnecté pendant l'attente |
| `owner_stopped` | ressource appelante arrêtée pendant l'attente |
| `client_error` / `invalid_response` | le client a échoué ou a renvoyé des valeurs refusées par `returns` (toute valeur pour `callClient`) |

### `core.net` (core 0.10.0)

Envois serveur → client **mesurés et comptés** : à un joueur, à une liste, ou aux joueurs proches d'un point calculés
par le serveur. Jamais à tous (`-1`), jamais un évènement d'un autre module ou du core. Les gros messages partent en
latent sans bloquer le reste ; le Conseil voit qui envoie quoi par `/vava_reseau`. `TriggerClientEvent` direct reste
permis dans un module, mais il n'est pas compté.

| Fonction | Retour |
|---|---|
| `send(target, event, ...)` | `true, envoyés, octets, latent` ou `false, code` |
| `sendWith({ latent? }, target, event, ...)` | idem |
| `sendNear(coords, radius, event, ...)` | idem |
| `sendNearWith({ latent?, from?, exclude?, bucket? }, coords, radius, event, ...)` | idem |
| `sendPacked(options, target, event, payload)` | idem (0.11.0) — `payload` : chaîne produite par `msgpack.pack_args(...)` dans le module |
| `sendNearPacked(options, coords, radius, event, payload)` | idem (0.11.0) |
| `playersNear(coords, radius, { from?, exclude?, bucket? }?)` | liste de numéros de joueurs (copie), ou `nil, code` |
| `stats({ limit?, resource?, target?, players? }?)` | `{ mode, windowMs, total, events }` (+ `name` avec `target`, + `players`, `playerCount` avec `players`, 0.12.0), ou `nil, code` |

```lua
-- un bruit de forge entendu à 30 m, sauf par le forgeron, et seulement dans son instance
local ok, count = core.net.sendNearWith({ from = source }, coords, 30.0, 'vava_crafting:sound', 'marteau')
```

- **Cible** : un numéro de joueur (entier > 0 qui existe), ou une **liste pure** d'entiers > 0 (1 à 256) ; dans une
  liste, les doublons sont retirés et un joueur parti entre-temps est sauté (non compté dans `envoyés`). `-1`, `0`, un
  flottant, une chaîne, une liste vide, trop longue ou mixte : `invalid_target` (`-1` écrit aussi en console « envoi à
  tous refusé »).
- **Évènement** : identifiant (64 caractères) préfixé par `<ressource appelante>:`, jamais `vAvA:` ni `core:`, sinon
  `invalid_event`. `chat:addMessage` reste un `TriggerClientEvent` direct (évènement de `vava_chat`).
- **Valeurs** : au plus 16 (`invalid_args`), sérialisables (`unserializable` : fonction, cycle, profondeur au-delà de
  32), 256 Ko au plus par message (`too_large`, rien n'est envoyé, erreur en console).
- **Options** (table à clés connues, sinon `invalid_options`) : `latent` = `'auto'` (défaut : latent strictement
  au-delà de 8 Ko) | `'never'` (toujours fiable) | `'always'` ; pour `sendNear*` et `playersNear` : `exclude`
  (numéro de joueur à sauter), `bucket` (entier ≥ 0 : seulement ce routing bucket ; défaut : **tous**) et `from`
  (joueur d'origine, qui existe : sauté, et seul son routing bucket compte ; `exclude` ou `bucket` donnés
  l'emportent).
- **Instances** : sans `bucket` ni `from`, un joueur d'une autre instance (routing bucket) au même endroit reçoit le
  message. Dès qu'un module a des instances (intérieurs, cachots, essais), il fournit `from` (l'auteur de l'action)
  ou `bucket` à chaque envoi de proximité.
- **Proches** : personnages chargés **et apparus**, ped existant, distance 3D ≤ rayon (0 < rayon ≤ 1 000 m, sinon
  `invalid_radius`), positions lues par le serveur (gardées 50 ms, `net.near.positionCacheMs`, 0.11.0 : un passage
  des zones et les envois qui le suivent ne relisent rien) ; `coords` : `vector3` ou `{ x, y, z }` finis
  (`invalid_coords`). Personne à portée : `true, 0, 0, false`, rien n'est sérialisé.
- **Retour** : `envoyés` = joueurs servis, `octets` = taille d'**un** message (charge msgpack + nom de l'évènement),
  `latent` = booléen ; pour une liste ou un rayon (0.11.0), 5e valeur : la **liste des joueurs sautés** (latent refusé),
  `nil` s'il n'y en a aucun — à renvoyer plus tard, ou à oublier si l'envoi n'a de sens que maintenant.
- **Latent** : 64 Ko/s par envoi (`net.latent.bytesPerSecond`) ; au plus 512 Ko en route vers un même joueur et 4 Mo
  tous joueurs confondus (`net.latent.maxTotalInFlightBytes`, 0.11.0 : catalogues de l'Atelier) : au-delà, `saturated`
  pour une cible seule (console : « plus de … octets déjà en route », ou « plafond global du latent atteint ») ; dans une
  liste, la cible saturée est sautée (5e valeur) et les autres reçoivent. Le premier envoi latent vers un joueur qui
  n'a rien en route passe toujours le plafond global (personne n'est privé de tout gros envoi par les autres).
- **Ordre** : deux messages fiables vers un même joueur arrivent dans l'ordre d'envoi ; un message latent peut être
  **dépassé** par tout message envoyé après lui, et l'ordre entre deux latents n'est pas garanti. Un module dont l'état
  suit un envoi (instantané puis différences) choisit `latent = 'never'`, ou numérote ses révisions.
- **Mesure** : exacte quand le runtime offre `msgpack.pack_args` et les envois internes (une seule sérialisation pour
  toutes les cibles : console `[net] mesure exacte`), sinon estimée sans sérialiser (`[net] estimation`) ;
  `net.mode = 'estimate'` dans `config/server.lua` force l'estimation. Un module paie en plus la copie de ses arguments
  à la traversée de l'export (§ Copies) : deux sérialisations pour un joueur, deux au lieu de N pour N joueurs proches.
- **`sendPacked` / `sendNearPacked`** (0.11.0) : le module sérialise lui-même (`msgpack.pack_args(...)`) ; une seule
  chaîne traverse l'export (copie d'un bloc d'octets, sans parcours) et le core l'envoie telle quelle, après les mêmes
  contrôles que `send` / `sendNear` (cible, préfixe, options, rayon, plafonds, compteur). Chaîne vide ou autre chose :
  `invalid_args` ; message (chaîne + nom) au-delà de 256 Ko : `too_large`. En estimation (fonctions du runtime
  absentes, ou repli après une erreur) : `false, 'unsupported'`, rien n'est envoyé — le module renvoie alors par
  `send`. Un envoi interne en échec ne peut pas être rejoué (le core n'a pas les valeurs) : erreur en console, cible
  sautée (`unsupported` pour une cible seule).

```lua
-- dans le bridge d'un module (forme recommandée)
local function sendTo(target, event, ...)
    if type(msgpack) == 'table' and type(msgpack.pack_args) == 'function' then
        local ok, code = core.net.sendPacked(nil, target, event, msgpack.pack_args(...))
        if ok or code ~= 'unsupported' then return ok, code end
    end
    return core.net.send(target, event, ...)
end
```

- Un module qui s'en sert déclare `coreVersion = '0.10.0'` (`0.11.0` pour `sendPacked` et la 5e valeur), ou teste
  `core.net` dans son `bridge/server.lua` et garde `TriggerClientEvent` en repli.

`stats` lit le compteur de la dernière minute (12 cases de 5 s ; mémoire bornée : 512 couples ressource, évènement,
au-delà cumulés sous `*`, `<autres>`). Depuis 0.12.0, **chaque joueur connecté est suivi d'office**, évènement par
évènement, sur la même fenêtre : ses `net.counter.playerKeys` (6) évènements les plus lourds, le reste cumulé sous
`*`, `<autres>` (un nouveau message plus gros que tout ce qu'a envoyé l'évènement le plus léger du joueur dans la minute
prend sa place, sans allocation : l'anneau écarté est vidé et réutilisé) ; tout est oublié à la sortie du joueur (et
de nouveau après son déchargement). Il n'y a plus de suivi à lancer (`watched` et le suivi de 5 min de 0.10.0
disparaissent). Mémoire au pire, mesurée hors jeu : part des joueurs 1,16 Mo pour 128 joueurs (6 évènements chacun, plus
`<autres>` et leur total) ; compteur général (512 couples pleins) 0,64 Mo ; en tout, au pire, 1,8 Mo.
- `limit` : 1 à 50 (défaut 10) ; `resource` : seulement cette ressource ;
- `target` : ce que reçoit ce joueur : `total` du joueur, ses `events` (filtrés par `resource` si elle est donnée) et
  `name`, prénom et nom de son personnage (absent sans personnage chargé) ;
- `players = true` (0.12.0, ni `resource` ni `target`) : `players`, les joueurs connectés du plus chargé au moins
  chargé (128 au plus, ceux qui n'ont rien reçu compris) : `{ source, messages, bytes, latent, name? }`, et
  `playerCount`, le nombre de joueurs connectés ; seul le `total` du royaume l'accompagne (`events` vide : rien n'est
  construit ni trié). Runtime sans `GetPlayers` : `nil, 'unsupported'`.
- **`target` et `players` sont réservés aux outils du Conseil** (ce que reçoit un joueur, le nom des personnages
  connectés) : tout appelant qui les montre à une personne vérifie son droit et inscrit la consultation du détail d'un
  joueur au journal du Registre (comme `/vava_reseau joueur` et la page Réseau de la Chancellerie).

```lua
{
    mode = 'exact',            -- ou 'estimate'
    windowMs = 60000,
    total = { messages = 1234, bytes = 421888, latent = 3 },
    events = {                 -- triés par octets décroissants, puis messages, puis ressource et évènement
        { resource = 'vava_codex', label = 'rpc vava_codex:open', messages = 12, bytes = 245760, latent = 9, largest = 28672 },
    },
    -- avec players = true
    players = { { source = 3, name = 'Aldric Morn', messages = 140, bytes = 61440, latent = 1 } },
    playerCount = 37,
}
```

Coût du suivi de tous les joueurs (0.12.0, mesuré hors jeu, `server/core/net.lua` réel, 128 joueurs) : environ
0,3 µs de plus par cible servie (liste de 128 joueurs : 73 → 111 µs ; un joueur : 3,4 → 4,0 µs ; `sendNear` de 50 m
sur une place de 120 m, 49 cibles : 58 → 76 µs ; en ville, `sendNear` de 30 m à 150 m : autour de 45 µs, la recherche
des proches dominant). Un remplacement du plus léger coûte de 4 à 7 µs par cible (pire cas : un nouvel évènement plus
lourd à chaque envoi), sans allocation.

Ce que le core envoie lui-même par `core.net` : réponses RPC et préavis, demandes de `callClient`, personnage chargé,
champs, déchargement et ordre d'apparition (**toujours fiables** : l'ordre chargement → champs → apparition compte ;
au-delà de 8 Ko, alerte en console une fois par minute et par évènement), sortie de `/vava_reseau`. Non comptés :
GlobalState, state bags, envois directs des modules. Si le personnage chargé ou l'ordre d'apparition ne peut pas
partir (trop gros, valeur non sérialisable), la console écrit le compte, le personnage et la cause, et le joueur est
déconnecté avec `players.messages.sendFailed` plutôt que laissé sur un écran noir ; `characters.spawn` rend alors
`false, code`.

**Commandes** (registre `core:commands`, chapitre Core) :
- `/vava_reseau` (Conseil, droit `tools` de `vava_admin`, repli ACE `vava.reseau`, 2 s entre deux) : en-tête, les 10
  plus gros envois de la minute, pied ; `joueur <n°>` : totaux du joueur et ses évènements les plus lourds, tout de
  suite (0.12.0 : chaque joueur est suivi d'office ; inscrit au journal du Registre, « Réseau d'un joueur consulté »,
  numéro et compte de jeu) ; `ressource <nom>` : les envois d'un module ;
  `zones` (0.11.0) : zones déclarées par module, abonnements, durée du passage (dernier, moyen et plus long de la
  minute) ; `zones <n°>` : zones suivies par un joueur (20 noms au plus ; inscrit au journal du Registre, « Zones d'un
  joueur consultées »). Sortie dans le chat du seul membre, ou dans la console.
- `vava_reseau_essai <n° du joueur> <Ko 1-256> [rayon]` (console du serveur seulement) : un message fiable, un message
  latent de la taille voulue, un message fiable (au joueur, ou aux joueurs à portée de lui si un rayon est donné) ; la
  console F8 du joueur écrit le débit réel du latent et l'ordre d'arrivée, celle d'un joueur proche « message de
  proximité reçu ».

### `core.zones` (core 0.11.0)

Abonnements de zone : un module déclare des **zones** (cercle au sol, marge) et tient leur **état** dans le core (paires
clé → valeur). Le serveur décide seul qui les reçoit : à chaque passage (`zones.passMs`, 1 s), il lit une fois la
position de chaque personnage apparu, cherche dans une grille (cases de 256 m) les zones proches, envoie l'état aux
joueurs qui entrent dans le **cercle d'intérêt** (rayon + marge) et l'oublie pour ceux qui en sortent au-delà de
rayon + marge + 25 m (pas d'aller-retour en bordure). Ensuite, seuls les changements partent, regroupés par tour, aux
seuls abonnés. Le client ne demande jamais d'entrer dans une zone. Fait pour ce qui est **local et partagé** : charges
des filons, cultures d'une parcelle, forge occupée, zone de voix. Ce qui est privé part par `core.net.send` au seul
intéressé ; ce qui est commun à tous et rare (heure, saison) reste en GlobalState.

| Fonction (serveur) | Retour |
|---|---|
| `define(id, area, state?)` | `true, numéro` ou `false, code` |
| `move(id, area)` | `true` ou `false, code` — lieu changé ; état et abonnés gardés, réévalués au passage suivant |
| `set(id, changes, removed?)` | `true` ou `false, code` — `changes` : clé → nouvelle valeur ; `removed` : liste de clés retirées ; part aux abonnés en fin de tour, regroupé avec les autres changements de la zone du même tour |
| `replace(id, state)` | `true` ou `false, code` — tout l'état remplacé, envoyé entier aux abonnés (rechargement, publication de l'Atelier) |
| `remove(id)` | `true` ou `false, code` — les abonnés reçoivent la sortie |
| `subscribers(id)` | liste triée des joueurs abonnés, ou `nil, code` — pour viser un son, un effet, un message de lieu |
| `info(id)` | `{ handle, revision, subscribers, keys, bytes }` ou `nil, code` |
| `list()` | identifiants locaux des zones du module, triés |

```lua
-- une zone de récolte (vava_gathering 1.6.0, T-015)
core.zones.define('foret_brume', { x = -320.0, y = -880.0, radius = 140.0, margin = 100.0 },
    { zone = { band = 'normal', scarred = false }, ['n:chene_1'] = 3 })
-- une récolte : un seul envoi aux abonnés, en fin de tour, pour les deux clés
core.zones.set('foret_brume', { ['n:chene_1'] = 2 })
core.zones.set('foret_brume', { zone = { band = 'reduced', scarred = false } })
```

- **Zones du module seulement** : `id` local (identifiant de 48 octets au plus, motif `^[%w_%-%.:]+$`, sinon
  `invalid_id`) devient `<ressource>:<id>` ; déjà pris : `exists` ; inconnu : `unknown_zone`. Deux modules peuvent
  avoir le même `id`. Le numéro rendu par `define` n'est jamais redonné pendant la vie du core.
- **`area`** : table à clés connues `x`, `y`, `z`, `radius`, `margin`, `bucket`, nombres finis ; `|x|, |y| ≤ 50 000` ;
  `0 < radius ≤ 500` ; `0 ≤ margin ≤ 500` (défaut 50 : la zone arrive avant le joueur) ; `bucket` entier ≥ 0 (seuls
  les joueurs de ce routing bucket ; absent : **tous**) ; `z` accepté et ignoré : distance **au sol** (mines, étages,
  collines restent dans la zone ; une autre forme donne son cercle englobant). Sinon `invalid_area`.
- **État** : table à clés chaînes (motif ci-dessus, 48 octets ; jamais de clé entière : `invalid_key`) → valeurs
  sérialisables (`invalid_value` : fonction, cycle, profondeur au-delà de 32), 4 Ko au plus chacune (`too_large`) ;
  au plus 64 clés changées ou retirées par appel et 256 clés dans l'état (`too_many_keys`) ; 32 Ko par état
  (`too_large`) ; 8 Mo pour tous les états, 2 048 zones dont 1 024 par module (`full`). **Tout ou rien** : un seul
  élément refusé, rien n'est appliqué. Une même clé changée et retirée dans le même appel : `invalid_key`.
- Une valeur **scalaire** égale à l'actuelle ne part pas ; une **table** part toujours (comparer soi-même si besoin).
  Une clé changée puis retirée dans le même tour ne part que retirée, et l'inverse.
- **Révisions** : chaque envoi porte la révision de la zone (1 à la déclaration, + 1 par différence ou remplacement) ;
  le client applique la révision attendue, ignore les anciennes et redemande l'état entier en cas de trou (RPC du core
  `core:zones:resync`, limité). Aucune révision passée n'est gardée.
- **Envois** (tous par `core.net`, comptés, jamais à tous) : l'état entier (`vAvA:zone:state`, une seule sérialisation
  pour tous les entrants d'un passage ; latent au-delà de 8 Ko, annoncé par un préavis `vAvA:zone:pending`) et les
  différences (`vAvA:zone:diff`, **toujours fiables**) sont comptés sous la ressource de la zone ; les sorties
  (`vAvA:zone:leave`) sous `vAvA_core`. Une différence regroupée de plus de 8 Ko part comme un état entier. Un joueur
  dont l'état entier n'a pas pu partir (latent saturé) ne reçoit aucune différence et l'aura au passage suivant.
- **Arrivée dans un lieu chargé** : au plus 32 Ko d'états entiers par joueur et par passage, les zones les plus
  proches d'abord (une zone plus grosse part seule) ; au plus 256 zones suivies par joueur (les plus lointaines
  attendent, alerte en console une fois par minute).
- **Qui est abonné** : personnage chargé, toujours celui de son joueur, **apparu** (un personnage renvoyé à une
  apparition garde ses abonnements, seules les nouvelles entrées attendent) ; ped existant ; position lue par le
  serveur. Retour à la sélection, déchargement, départ : tout est oublié sans envoi (le client vide ses zones). Arrêt du
  module : ses zones sont oubliées, sans envoi (le client oublie celles de la ressource arrêtée) ; module en échec dont
  la ressource tourne encore : ses abonnés reçoivent la sortie. Un joueur qui n'a pas bougé de plus de 1 m
  (`zones.stillDistance`), dans la même instance, sans zone déclarée, déplacée ou retirée depuis, n'est pas recalculé.
- **L'état d'une zone est public** pour quiconque peut s'y rendre. Sous OneSync, la position du ped que lit le serveur
  est **déclarée par son client** : un client modifié peut se dire n'importe où et recevoir l'état de n'importe quelle
  zone. L'abonnement n'est donc **ni un droit ni une preuve de présence** : n'y mettre rien de secret (récompense
  cachée, qualité d'une récolte à venir, contenu d'un grenier), et revérifier à chaque action, côté serveur et au
  moment de l'action, la distance réelle et le reste (possession, droit, délai) sans se fier à l'abonnement ; un module
  qui en a besoin ajoute un contrôle de vitesse plausible.
- **Atelier** (T-101, T-102) : une définition publiée → `define`, `move`, `replace` ou `set` ; une définition **en
  essai** n'entre pas dans l'état de la zone (sinon tous les abonnés la verraient) : elle part par `core.net.send` à
  son seul auteur.
- **Réglages** (`config/server.lua` → `zones`) : tous modifiables. `passMs` (1 000 ms) : à 2 000 ms le coût est divisé
  par deux et la marge par défaut de 50 m reste sûre (un cavalier au galop, environ 15 m/s, parcourt 30 m entre deux
  passages) ; au-delà, une zone peut arriver après le joueur. **Recommandé : garder 1 s.** Coût mesuré hors jeu par
  passage (Lua seul, 2 048 zones, 64 / 128 joueurs) : joueurs immobiles 0,03 / 0,07 ms ; en mouvement, zones éparses
  0,23 / 0,46 ms, ville (1,5 × 1,5 km, rayons 2 à 30 m) 1,7 / 3,3 ms, ville très dense 6,4 / 13,9 ms ; plus quatre
  natives par joueur ; passage qui suit le redémarrage d'un module (tout le monde y rentre) : 8 à 38 ms, une fois. En
  jeu : `profiler record` de la console du serveur (`/vava_reseau zones` donne un ordre de grandeur).
- Un module qui s'en sert déclare `coreVersion = '0.11.0'`.

### `core.db`

| Fonction | Retour |
|---|---|
| `query(sql, params)` | lignes, ou en-tête de résultat |
| `single(sql, params)` | première ligne ou `nil` |
| `scalar(sql, params)` | première colonne de la première ligne ou `nil` |
| `insert(sql, params)` | identifiant inséré |
| `update(sql, params)` | lignes affectées |
| `transaction({ { query = sql, values = params }, ... })` | `true` |

- En cas d'échec : `nil, err`. **Vérifier `err`**, car `single`/`scalar` renvoient aussi `nil` quand il n'y a
  pas de ligne.
- `params` est **obligatoire** (`{}` si aucun). Ne jamais concaténer de valeur dans le SQL : utiliser `?`.
- Requêtes lentes (`config/server.lua` → `database.slowQueryMs`) signalées avec le module à l'origine.

### Migrations

Déclarées dans le fxmanifest du module, appliquées par le core **avant `setup`** :

```lua
vava_migration 'sql/0001_create_items.sql'
vava_migration 'sql/0002_add_item_weight.sql'
```

- Nom de fichier : `<numéro>_<description>.sql`. Les numéros sont uniques ; l'ordre d'application est numérique.
- Une migration appliquée n'est **jamais rejouée**. Si son fichier change, le module refuse de démarrer :
  ajouter une nouvelle migration au lieu de modifier l'ancienne.
- MySQL/MariaDB valide automatiquement chaque DDL (`CREATE`, `ALTER`…) : une migration n'est pas annulable.
  Une migration = un changement logique, DDL idempotents (`IF NOT EXISTS`) recommandés. Elle n'est enregistrée
  qu'après la réussite de toutes ses instructions ; en cas d'échec, l'erreur indique le fichier et l'instruction.
- Non supportés : `DELIMITER` (procédures, triggers) et le caractère `?` hors placeholder (oxmysql
  l'interprète comme paramètre).
- Le suivi est indexé par nom de ressource : renommer une ressource fait rejouer ses migrations.

## Client

```lua
local core = exports.vAvA_core:getApi(1)
```

| Fonction | Retour |
|---|---|
| `log.debug/info/warn/error(fmt, ...)` | — |
| `hooks.*` | identiques au serveur, locaux au client |
| `rpc.call(name, ...)` | `true, ...valeurs du handler` ou `false, code` |
| `rpc.callWith({ timeout? }, name, ...)` | idem |
| `rpc.emit(name, ...)` | `true` — intention sans réponse, mêmes contrôles côté serveur |
| `rpc.register(name, handler)` | `true` ou `false, err` — handler appelable par `callClient` ; il renvoie exactement ce que décrit le `returns` de l'appel serveur (rien du tout pour `callClient`, pas même `nil`), sinon le serveur reçoit `invalid_response` |
| `rpc.unregister(name)` | `true` ou `false, err` |

`rpc.call` distingue le **transport** (premier retour) de la **réponse métier** (retours suivants) :

```lua
local ok, success, result = core.rpc.call('vava_example:postNote', 'annonce', 'Foire au château demain')
if not ok then --[[ success contient le code de transport ]] end
```

Le client n'est jamais une source de vérité : un RPC exprime une intention que le serveur valide et décide.

Une grosse réponse (au-delà de 8 Ko, 0.10.0) arrive en latent, annoncée par un préavis qui repousse le délai
d'attente de l'appel (temps de transfert + 3 s, 30 s de plus au plus) : `rpc.call` n'a rien à faire de plus.

### `core.zones` (client, core 0.11.0)

Les zones que le serveur a choisi d'envoyer à ce joueur (§ `core.zones` serveur). Le core tient une réplique de chacune
(révisions, état entier redemandé s'il manque une révision ou si un état annoncé n'arrive pas) et prévient le module
propriétaire. Un module ne voit que **ses** zones.

| Fonction | Retour |
|---|---|
| `watch(handler)` | `true` ou `false, err` — un gestionnaire par ressource (un second appel remplace le premier) |
| `get(id)` | état de la zone (copie) et sa révision, ou `nil` si elle n'est pas suivie et à jour — chaque appel copie tout l'état à la traversée de l'export : jamais dans une boucle, garder sa propre copie tenue par `watch` |
| `list()` | identifiants locaux des zones du module suivies et à jour, triés |

```lua
core.zones.watch(function(kind, id, a, b)
    if kind == 'enter' then         -- a : état entier (zone suivie, ou de nouveau entière après un trou)
    elseif kind == 'change' then    -- a : clés changées (table, vide au besoin), b : clés retirées (liste)
    elseif kind == 'leave' then     -- éloigné, zone retirée, déchargement ou sélection
    end
end)
```

- `enter` peut revenir pour une zone déjà suivie (état renvoyé entier) : le traiter comme un remplacement.
- Un module qui appelle `watch` (démarrage, redémarrage) reçoit au tour suivant un `enter` pour chacune de ses zones
  déjà à jour. Un gestionnaire en erreur est isolé (console, une fois par intervalle).
- Aucune boucle : quatre gestionnaires d'évènement, une minuterie par état attendu, un thread par demande d'état en
  cours (essais à 5 s, puis doublés jusqu'à 60 s ; `config/shared.lua` → `zones`). Ligne `debug` en `F8` :
  « instantané redemandé : <nom> (…) ».
- Le core ignore : les évènements de zone déclenchés localement par une autre ressource ; un état entier latent annoncé
  puis doublé par une sortie de la zone ou par un déchargement (arrivé ensuite, il ne recrée rien, 60 s au plus) ; tout
  ce qui arrive entre un déchargement et le chargement suivant. Jusqu'à 64 changements sont gardés par zone en
  attendant un état entier.
- Un module ne nomme jamais les évènements `vAvA:zone:*` (l'audit le refuse dans `modules/`) : il passe par
  `core.zones`.

### `core.characters` (client)

Base d'un écran de sélection. Chaque fonction RPC renvoie `ok` (transport), puis `success`, `résultat | code`.

| Fonction | Résultat en cas de succès |
|---|---|
| `current()` | `{ id, firstName, lastName, sex, fields }` du personnage actif, ou `nil` (local, sans appel réseau) |
| `awaitingSelection()` | `true` si le joueur attend de choisir un personnage (local) |
| `list()` | liste `{ id, firstName, lastName, sex }` des personnages du compte, puis le maximum par compte, puis les règles de nom `{ minLength, maxLength, letters, separators }` (0.8.0) |
| `create(firstName, lastName, sex)` | résumé du personnage créé |
| `select(characterId)` | — ; le personnage arrive ensuite par le hook `core:character:loaded` |
| `unload()` | — ; retour à l'écran noir de sélection |
| `delete(characterId)` | — |

Hooks client (locaux, émis par le core) :

| Nom | Payload | Moment |
|---|---|---|
| `core:character:selection` | `{}` | le joueur est mis en attente (écran noir) : une interface de sélection prend la main ; depuis 0.13.0, à la **première** mise en attente, l'écran de chargement n'est plus fermé si `spawn.loadingScreen.resource` tourne (ci-dessous) |
| `core:character:loaded` | le personnage | données reçues, avant l'apparition |
| `core:character:spawning` | `{ modelChanged }` | ped placé, écran encore noir : appliquer l'apparence ici |
| `core:character:fieldChanged` | `{ field, value }` | champ `owner`/`public` modifié |
| `core:character:unloaded` | `{ id }` | retour à la sélection |

Écran de chargement (0.13.0, `config/shared.lua` → `spawn.loadingScreen`) : à la première mise en attente, si la
ressource `resource` (défaut `vava_loading`) est démarrée, le core fait son fondu au noir **sous** l'écran de chargement
et lui en laisse la fermeture (`ShutdownLoadingScreenNui`), qu'il fait lui-même au plus tard `maxHoldMs` (30 s) plus
tard ; `resource = ''` ou ressource arrêtée : fermeture aussitôt (comportement de 0.12.0). L'apparition d'un personnage
ferme toujours l'écran. Les mises en attente suivantes (retour à la sélection) ne changent pas.

Codes de refus : `no_session`, `busy`, `wrong_state`, `not_owner`, `not_found`, `too_many_characters`,
`invalid_name`, `invalid_sex`, `name_taken`, `refused`, `db_error`, `corrupted_data`, `no_character`, ou la
raison donnée par un hook `before`. `busy` vaut aussi pour la sélection d'un personnage qui termine encore son
déchargement d'une session précédente (reconnexion rapide) : il suffit de réessayer. Une déconnexion attend la fin de
l'action de personnage en cours avant de décharger ; une modification faite pendant l'écriture du déchargement est
gardée et écrite au cycle suivant. Avec `characters.uniqueNames = true`, l'unicité ignore la casse et les accents
(collation de la base) et deux créations simultanées du même nom sont départagées (0.7.2) : la seconde reçoit
`name_taken`. Pas d'index unique : des homonymes déjà en base sont conservés.

Noms : `characters.name` dans `config/server.lua` (longueur en caractères, lettres accentuées autorisées,
séparateurs `'`, `-` et espace jamais en tête, en fin ni doublés). Depuis 0.8.0, ces règles partent avec `list()` :
une interface de création vérifie la saisie comme le serveur (espaces de bord retirés, longueur comptée en caractères,
chaque caractère pris dans `letters` ou dans `separators`) sans en garder de copie ; le serveur revérifie à la création.

## Modules officiels

Ressources séparées, dans `modules/` : à copier (ou lier) dans le dossier `resources` du serveur, dans cet ordre (le
même que `README.md` à la racine, et celui qu'écrit la Chancellerie) :
`ensure oxmysql`, `ensure vAvA_core`, `ensure vava_ui`, `ensure vava_loading`, `ensure vava_chat` (à la place de
`ensure chat`), `ensure vava_world`, `ensure vava_time`, `ensure vava_appearance`, `ensure vava_characters_ui`,
`ensure vava_hud`, `ensure vava_inventory`, `ensure vava_needs`, `ensure vava_health`, `ensure vava_admin`,
`ensure vava_atelier`, `ensure vava_voice`, `ensure vava_cameras`, `ensure vava_magic`, `ensure vava_skills`,
`ensure vava_gathering`, `ensure vava_crafting`, `ensure vava_combat`, `ensure vava_farming`, `ensure vava_provisions`, `ensure vava_codex`,
`ensure vava_arrival`, `ensure vava_chancellerie`, puis les modules qui déclarent des objets.

Réglages d'un module (T-132, aucune API du core) : chaque module lit sa config par sa table globale
(`VavaXxx.config`). Un module basculé la tient en deux fichiers, chaque valeur écrite une fois : `config_client.lua`
(`shared_scripts`, téléchargé par chaque joueur) ouvre la table avec ce que lit le client et pose `clientFile = true` ;
`config.lua` (en tête des `server_scripts`, jamais téléchargé) la complète avec ce que lit le seul serveur. Basculés :
`vava_atelier` 1.2.0, `vava_arrival` 1.2.0 ; `vava_chancellerie` 1.7.1 ne sert plus rien aux joueurs ; les autres
suivent (T-141 à T-143). Règle complète : `docs/plan/specs/T-132.md` § 2.4.

### `vava_ui`

Polices, textures et ornements communs des interfaces, servis par `nui://vava_ui/web/…` (aucun script, aucun export,
aucun hook, rien à régler). Démarre juste après `vAvA_core`. Contrat public (règles complètes, poids et jetons :
`modules/vava_ui/README.md`) :

- feuille `nui://vava_ui/web/css/vava_ui.css`, liée par la page **avant** sa propre feuille ; ligne hors jeu à la place
  de l'ancien `<script src="js/devmock.js">` (en jeu elle ne fait rien ; `web/dev/` n'est jamais dans `files`) :
  `<script>typeof GetParentResourceName === 'function' || document.write('<script src="../../vava_ui/web/dev/horsjeu.js"><\/script><script src="dev/devmock.js"><\/script>');</script>` ;
- familles `"Cinzel"`, `"EB Garamond"` (droit et italique, 400 à 700), `"Cinzel Decorative"` (400, 700) ;
- jetons `--ui-*` sur `:root` : images `--ui-grain`, `--ui-paper`, `--ui-frame`, `--ui-divider`, `--ui-diamond`,
  **toujours** employées avec un repli (`var(--ui-grain, none)`) ; polices `--ui-font-display`, `--ui-font-body`,
  `--ui-font-decorative` ; couleurs des fonds clairs (`--ui-ink*`, `--ui-rule`, `--ui-page*`, `--ui-field*`) et du cuir
  (`--ui-edge`, `--ui-brass*`, `--ui-text*`) ;
- toute ressource dont la page l'emploie déclare `dependency 'vava_ui'` : FXServer démarre alors `vava_ui` d'office, et
  arrêterait la ressource avec lui (**jamais** de `stop` ni de `restart vava_ui` sur un serveur ouvert) ;
- évolution : version mineure = ajout d'un fichier ou d'un jeton ; majeure = retrait ou renommage, avec toutes les
  pages qui l'emploient dans le même chantier. Un fichier y entre dès que deux ressources l'emploient.

Adopté par les quinze interfaces (T-012) : `vava_hud` 1.4.0 (pilote), `vava_health` 1.2.0, `vava_characters_ui`
1.1.0, `vava_inventory` 1.8.0, `vava_codex` 1.3.0, `vava_chat` 1.3.0, `vava_skills` 1.2.0, `vava_gathering` 1.5.0,
`vava_crafting` 1.4.0, `vava_farming` 1.6.0, `vava_time` 1.3.0, `vava_voice` 1.3.0, `vava_cameras` 1.4.0,
`vava_admin` 1.8.0, `vava_magic` 2.8.0. Aucune ne livre plus de copie commune ni ses données simulées : leur rendu hors
jeu (`web/index.html?…` dans un navigateur, depuis le dépôt) passe par la ligne ci-dessus, qui charge
`web/dev/devmock.js`. Garde-fous : `tests/spec/ui_shared_spec.lua` (chaque page) et `scripts/audit-reseau.sh`
(BLOQUANT : police ou texture commune hors de `vava_ui`, `devmock.js` livré, motif `files` qui couvrirait `web/dev/`).

### `vava_loading`

Écran de chargement d'Eldoria (`loadscreen`, `loadscreen_manual_shutdown`, `loadscreen_cursor`) : progression réelle
sur six feux, puis passage sans écran noir à la sélection. Ressource cliente uniquement : **aucun RPC, aucun évènement,
aucun state bag, aucun hook émis, aucun export**. Contrat (règles complètes : `modules/vava_loading/README.md`) :

- **Ordre** : `ensure vava_loading` juste après `vava_ui`, pour que son script client tourne avant celui de
  `vava_characters_ui` ; s'il tourne après (redémarrage), l'export `isShown()` de la sélection rattrape le hook manqué.
- **Core** ≥ 0.13.0 : `spawn.loadingScreen` (§ `core.characters` client) ne ferme plus l'écran à la première mise en
  attente quand `vava_loading` est démarré ; filet du core à 30 s.
- **Écoute** les hooks client `core:character:selection` (attente, filet de 20 s), `core:character:loaded` (fermeture
  immédiate) et `vava_characters_ui:shown` (passage) ; nommés dans `config.lua` (`selection.*`) pour un autre écran de
  sélection.
- **Messages locaux** à la page (`SendLoadingScreenMessage`, aucun réseau, ≤ 80 octets) : `vava_loading:resources`
  (script client lancé), `vava_loading:waiting` (mise en attente), `vava_loading:handoff` `{ ms }` (sélection affichée :
  éclair de `ms` millisecondes, bornées de 300 à 5 000, puis `ShutdownLoadingScreenNui`). La page lit aussi les messages
  du jeu (`loadProgress`, fonctions d'initialisation, fichiers de données) et ignore tout le reste.
- **Fichiers de la page** : textes dans `web/js/strings.js` (seul fichier touché par T-021), rythmes, seuils des feux,
  effets, musique et journal dans `web/js/config.js` ; jamais d'image ni de ressource externe ; polices embarquées
  (exception d'audit `modules/vava_loading/web/fonts/`).
- **Poids** : ≈ 222 Ko livrés (1.0.0), plafond 300 Ko (700 Ko avec une musique, test unitaire) ; dossier entier ≤ 1,5 Mo
  (`scripts/audit-reseau.sh`).

### `vava_appearance`

Apparence des personnages : champ `vava_appearance:data` (visibilité `owner` ; le jeu synchronise lui-même
l'aspect du ped pour les autres joueurs), appliqué à chaque apparition par le hook `core:character:spawning`.

Format (listes pures et tables nommées uniquement, pour une sérialisation sans perte) :

```lua
{
    heritage = { mother = 21, father = 0, shapeMix = 0.5, skinMix = 0.5 },  -- visages 0 à 45, mélanges 0 à 1
    features = { 0.0, ... },              -- 20 traits du visage, de -1 à 1
    hair = { style = 4, texture = 0, color = 0, highlight = 0 },
    eyeColor = 0,
    overlays = { { id = 2, style = 0, opacity = 1.0, color = 0 }, ... },  -- style 255 = aucun
    components = { { id = 11, drawable = 0, texture = 0 }, ... },
    props = { { id = 0, drawable = -1, texture = 0 }, ... },               -- drawable -1 = aucun
}
```

- RPC `vava_appearance:create(firstName, lastName, sex, appearance)` : crée le personnage et son apparence en
  une seule intention, validée par un schéma strict.
- Exports client (pour un coiffeur, un magasin de vêtements…) : `defaultAppearance(sex)`, `apply(ped, appearance)`,
  `applyPart(ped, part, value)` (`heritage`, `feature` `{ index, value }`, `hair`, `eyeColor`, `overlay`,
  `component`, `prop`), `limits(ped)`, `textureCount(ped, kind, id, drawable)`, `palettes()`.
- Modifier l'apparence d'un personnage chargé : `core.characters.set(id, 'vava_appearance:data', appearance)`
  côté serveur ; le client concerné la réapplique.
- Vêtements proposés et apparences de départ : `config.lua` (`components`, `props`, `defaults`). Les packs
  médiévaux ne demanderont que ces réglages. Règles, installation et vérifications en jeu :
  `modules/vava_appearance/README.md`.

### `vava_characters_ui`

Écran de sélection et éditeur de création (NUI, sans framework). S'ouvre sur `core:character:selection`, se ferme
sur `core:character:loaded`. Aperçu sur un ped **local** (invisible des autres joueurs). Scène et caméras :
`config.lua` ; la scène est distincte du point d'apparition du core (sinon les nouveaux arrivants entreraient dans la
scène de ceux qui créent) et reste provisoire (`-- PLACEHOLDER`). Les noms sont vérifiés à la saisie avec les règles
du serveur (`characters.name`, reçues avec la liste des personnages, core ≥ 0.8.0) ; le serveur revérifie à la
création. À l'arrêt de la ressource écran ouvert, ped d'aperçu, caméra, mise au point de la carte, radar et focus sont
rendus, et l'écran redevient noir comme l'attente de sélection. Détails : `modules/vava_characters_ui/README.md`. Pour
travailler le rendu sans le jeu, ouvrir `web/index.html` dans un navigateur (`?screen=creator&tab=hair&sex=f`) : des
données simulées remplacent le jeu.

1.2.0 : hook client `vava_characters_ui:shown` (`{}`, à la fin de l'ouverture : scène, caméra, liste, page et focus en
place, fondu d'entrée lancé ; une fois par ouverture) et export client `isShown()` (`true` de la fin de l'ouverture à la
fermeture), lus par `vava_loading` pour passer à la sélection sans écran noir.

### `vava_inventory`

Inventaire en grille. Ordre de démarrage : après `vAvA_core`, avant les modules qui déclarent des objets.

**Déclarer un objet** (dans le `setup` d'un module qui dépend de `vava_inventory`) :

```lua
core.registry.add('vava_inventory:items', 'pain', {
    label = 'Miche de pain', description = 'Encore tiède.',
    width = 2, height = 1,            -- cases occupées (pivotable en jeu)
    weight = 400,                     -- grammes par unité
    stack = 10,                       -- 1 = non empilable
    image = 'nui://mon_module/web/items/pain.svg',  -- fichier listé dans `files` du module
    category = 'nourriture',
    effects = { hunger = 35 },        -- optionnel : rend l'objet utilisable ; une unité consommée, effets appliqués
                                      -- par les modules qui les lisent (vava_needs : hunger, thirst)
})

core.registry.add('vava_inventory:items', 'parchemin', {
    label = 'Parchemin scellé', width = 1, height = 1, weight = 10, stack = 1,
    onUse = function(source, item)    -- optionnel : usage particulier, écrit par le module
        return true, 'Vous brisez le sceau.'  -- true = une unité consommée ; message affiché au joueur
    end,
})
```

Un objet est utilisable s'il a `effects` ou `onUse` (les deux à la fois : `onUse` décide de la consommation, les
effets ne s'appliquent que si l'unité est consommée). **`onUse` ne doit pas céder la main** (pas de `Wait`, d'attente
de la base ni d'export qui attend) : l'objet pourrait être jeté ou consommé entre-temps, et ce que la fonction a déjà
fait resterait acquis sans unité retirée ; un geste qui dure se lance dans son propre thread (`CreateThread`), comme le
fait vava_magic. `effects` : 8 effets au plus, nombres entre −1000 et 1000. La
fiche d'objet affiche les effets qu'elle connaît (`web/js/strings.js` → `effects`).

**Objet qui se tient en main** (depuis 1.4.0) : `held = { model = 'prop_tool_fireaxe', bone?, offset?, rotation? }`
(`bone` : os du ped, main droite par défaut ; `offset` et `rotation` : `{ x, y, z }` en mètres et degrés). Le joueur le
prend dans l'emplacement **Mains** de son inventaire (glisser, clic droit, ou double-clic / raccourci s'il n'a pas d'autre
usage) ; une seule pile en main, qui reste dans la besace (place et poids). La main se vide d'elle-même quand la pile
quitte la besace (jetée, déposée, consommée, retirée par un module). Ce que tient un joueur (1.7.0) :

- côté serveur, l'export `held(source)` fait foi ;
- le champ de personnage `vava_inventory:hands` (`owner` : `{ id, item }` ou rien) va au **seul** joueur, gardé en base
  (le client le lit par `core.characters.current().fields['vava_inventory:hands']`) ; il était `public` jusqu'en 1.6.x
  et portait aussi le placement ;
- le serveur l'écrit sur le **statebag du ped** du porteur, `Entity(ped).state['vava_inventory:inHand']`
  (`{ id, item }`, environ 25 o), que OneSync ne réplique qu'aux joueurs qui ont ce ped dans leur zone de pertinence
  (environ 424 m) et qu'il renvoie à chacun quand le ped apparaît chez lui (arrivée de loin) ; un nouveau ped
  (réapparition, changement de modèle) est repéré en une seconde au plus et la main y est réécrite. Les peds de tous
  les joueurs sont vidés au démarrage du module (avant la relecture des besaces) et à son arrêt. Chaque client en fait un
  accessoire local (aucune entité réseau), sur un ped de joueur seulement ;
- le placement n'est jamais publié avec la main : chaque client le lit dans la déclaration `held` de l'objet, publiée
  par le serveur dans `GlobalState['vava_inventory:heldModels']` (`{ [objet] = { model, bone, offset, rotation } }`,
  valeurs par défaut comprises, une écriture par tick au plus et aucune quand rien ne change, objet redéclaré à
  l'identique compris ; clé interne, que les modules n'écrivent pas) ; un objet qui n'y figure pas n'est pas montré ;
- le ped étant possédé par son client, celui-ci peut réécrire ce statebag : le serveur retient la valeur qu'il a écrite
  sur chaque ped et remet la sienne (`hands.guardDelayMs`, 250 ms, une remise pour toutes les réécritures du délai ;
  après 3 remises sans nouvelle publication, délai doublé jusqu'à `hands.guardMaxDelayMs`, 1 s) : une fausse main
  reste visible **au plus une seconde environ** ; une main écrite sur toute autre entité (ou sur une entité qui a repris
  le numéro réseau d'un ped) est effacée ; ligne en console limitée à une par joueur et par 10 s. Comme pour un champ
  public, un client ne décide jamais rien d'après ce statebag : il ne fait que montrer un objet ;
- le RPC `vava_inventory:hold` (prendre ou reposer depuis l'interface) a sa propre limite (`rateLimits.hold` : 4 d'avance,
  puis 2 par seconde), chaque geste réécrivant le statebag du ped ; la ceinture passe par la limite `use`.

**Affichage des métadonnées** (depuis 1.4.0) : la fiche et la case d'un objet montrent les métadonnées du **contrat
standard** — `tier` (badge et liseré de la teinte du palier ; libellés `strings.js` → `metadata.tiers`), `quality`
(0–100), `durability` / `max_durability` (filet de solidité sous la case), `broken` (case rayée, « Brisé »), `name`
(nom propre, remplace le libellé), `crafter_name`, `mark` (poinçon) et `crafted_at` (secondes, signature « Façonné par… »),
`origin`, `history` (liste `{ at, kind, by?, note? }`, cinq dernières entrées, natures `strings.js` →
`metadata.historyKinds`) — plus `lines` (`{ { label, value } }`) pour ce qu'un module veut montrer d'autre. Une clé hors
contrat n'est pas affichée. Les modules métiers (récolte, artisanat) écrivent ces clés ; l'inventaire ne leur donne aucun
sens au-delà de l'affichage.

**Catégories** : l'interface teinte l'objet et sa fiche selon `category`. Teintes prévues : `nourriture`,
`boisson`, `arme`, `armure`, `outil`, `materiau`, `valeur`, `soin`, `divers`. Une autre catégorie s'affiche
telle quelle, sans teinte. **Images** : un dessin au format de l'objet (2 × 1 → rapport 2:1), fond transparent,
ombre portée comprise dans l'image : l'interface n'applique aucun filtre.

**Métadonnées** (depuis 1.4.0) : chaque pile porte un objet JSON libre (`{}` si rien), écrit par les modules : palier
d'une matière (`tier`, `origin`), qualité et signature d'un objet d'artisan (`quality`, `crafter_name`, `durability`…).
Règles tenues par l'inventaire :

- toujours un **objet** JSON : clés texte à la racine, tables imbriquées objets ou listes sans trou, valeurs texte,
  nombre fini ou booléen ; bornes dans `config.lua` → `metadata` (`maxEntries` par table, `maxDepth`,
  `maxStringLength`) ; refus `invalid_metadata` ;
- une pile ne se complète (`add`, fusion par le joueur) qu'avec des métadonnées **strictement identiques** : dix ajouts
  de bois `{ tier = 2 }` font une pile, un bois `{ tier = 3 }` en fait une autre ;
- un retrait **filtré** (`metadata = { tier = 2 }`) consomme les seules piles qui portent ces clés avec ces valeurs
  (sous-ensemble : une pile `{ tier = 2, origin = 'foret' }` convient), les plus anciennes d'abord ; un retrait **par
  instance** vise une pile précise ;
- `setMetadata` et `patchMetadata` s'appliquent à toute la pile (toutes ses unités).

**Exports serveur** (cible : un joueur, ou `{ container = id }`) :

| Export | Retour |
|---|---|
| `add(cible, objet, quantité, métadonnées?)` | `true` ou `false, code` — tout ou rien, complète d'abord les piles aux métadonnées identiques |
| `remove(cible, objet, quantité, métadonnées?)` | `true` ou `false, code` — tout ou rien ; `métadonnées` filtre les piles consommées (1.4.0) |
| `exchange(cible, retraits, ajouts)` | `true` ou `false, code` — recette, achat : rien ne change si une partie échoue. Retrait : `{ item, quantity, metadata? }` ou `{ instanceId, quantity? }` (toute la pile sans `quantity` ; 1.4.0) ; ajout : `{ item, quantity, metadata? }` |
| `canCarry(cible, objet, quantité, métadonnées?)` | `true` ou `false, code` (`no_space`, `too_heavy`) |
| `count(cible, objet, métadonnées?)` | quantité totale, limitée aux piles portant `métadonnées` (1.4.0) |
| `getItems(cible, filtre?)` | liste `{ id, item, x, y, rotated, quantity, metadata }`, de la plus ancienne pile à la plus récente ; `filtre` `{ item?, metadata? }` (1.4.0) |
| `setMetadata(cible, idObjet, métadonnées)` | `true` ou `false, code` (`not_found`, `invalid_request`, `invalid_metadata`, refus d'un hook) — remplace les métadonnées d'un objet (`nil` les retire), sauvegardé et montré aux inventaires ouverts ; depuis 1.3.0 |
| `patchMetadata(cible, idObjet, patch, retirées?)` | `true` ou `false, code` — écrit ou remplace les clés de `patch`, retire les clés listées dans `retirées`, conserve le reste (une réparation touche `durability` et `history` sans pouvoir écraser le créateur) ; depuis 1.4.0 |
| `createContainer({ kind, ownerType?, ownerId?, width, height, maxWeight?, label? })` | id d'un conteneur conservé (coffre…) |
| `open(source, containerId, ancrage?)` | ouvre un conteneur au joueur ; **l'appelant a vérifié le droit d'accès**. `ancrage` `{ x, y, z, radius }` (1.4.0) : distance vérifiée côté serveur à l'ouverture (`too_far`) et à chaque opération, conteneur fermé chez le joueur qui s'éloigne (vérification toutes les `anchor.sweepMs`, seulement tant qu'un conteneur ancré est ouvert) ; `radius` ≤ `anchor.maxRadius` sinon `invalid_anchor`. **À donner pour tout conteneur qui a un lieu** (coffre, grenier, station) |
| `containerOf(source)` | id du conteneur porté par le personnage actif d'un joueur (fouille, administration), ou `nil, code` ; ouvert chez un autre joueur, il s'y ferme quand son porteur quitte le jeu ou change de personnage |
| `close(source, containerId?)` | `true` ou `false, code` (`not_open`, `invalid_target`) — ferme chez un joueur tout ce qu'il regarde, son interface comprise (`vava_health` l'appelle à la mise à terre) ou, avec `containerId`, ce seul conteneur (accès retiré à un grenier, un coffre) ; depuis 1.6.4 |
| `held(source)` | pile tenue en main par le personnage actif (`{ id, item, x, y, rotated, quantity, metadata }`), ou `nil` ; depuis 1.4.0 |
| `hold(source, idObjet)` | `true` ou `false, code` (`not_found`, `not_holdable`, refus d'un hook) — fait prendre en main une pile de la besace, ou reposer (`0`) : outil brisé, désarmement… ; depuis 1.4.0 |

**Hooks** (`before` annulable, puis `after`) : `vava_inventory:move`, `split`, `merge`, `drop`, `use`, `add`,
`remove`, `metadata`, `hold`. Payload : `{ source, instanceId, item, quantity, from, to }` pour les gestes du joueur,
`{ container, removals, additions, owner }` pour les échanges (les retraits y gardent leur forme, `item` ou
`instanceId`), `{ container, instanceId, item, owner, reason = set | patch, before, after }` pour `metadata`
(`before` et `after` sont des copies : un module peut y refuser qu'un autre touche `crafter_*`, ou journaliser les
objets de valeur), `{ source, instanceId, item?, previous, owner? }` pour `hold` (`instanceId = 0` : reposer ; en
phase `after` seulement, `reason = 'gone'` quand la main s'est vidée parce que la pile a quitté la besace). `use`
transmet aussi `category` et `effects` de l'objet, et `consumed` en phase `after` (vrai seulement si une unité a
réellement été retirée : un `onUse` qui cède la main peut voir l'objet jeté ou consommé entre-temps, alors aucun effet
n'est à appliquer). Un refus `false, 'raison'` est
montré au joueur, dans l'interface ou en notification s'il utilisait un raccourci.

**Garanties** :
- Le serveur décide de tout : place, poids, distance d'un sac (lue côté serveur), droit d'accès.
- Chaque opération s'exécute d'un bloc en mémoire, sans attendre la base : pas de duplication par concurrence.
  Les identifiants d'objets sont attribués en mémoire (**un seul serveur par base de données**).
- Écriture groupée toutes les 3 s, et aussitôt au déchargement d'un personnage ; à la fermeture d'un inventaire, au
  plus une fois toutes les 3 s par joueur (1.6.1) ; à l'arrêt du module, une dernière écriture lancée sans attendre
  (signalée en console si elle n'a pas pu partir). Les sacs au sol ne survivent pas à un
  redémarrage (ni leur contenu).
- Sacs au sol plafonnés (1.6.0) : au plus `config.drop.maxPerPlayer` (10) sacs posés par un même personnage et
  `config.drop.maxTotal` (300) sur le serveur ; un sac compte jusqu'à sa disparition (vidé, expiré), même après le
  départ de son auteur. Au-delà, le jet qui poserait un nouveau sac est refusé (`too_many_drops`) ; remplir un sac
  existant reste possible.
- Le client ne reçoit que les conteneurs qu'il a ouverts, puis leurs différences.
- Déchargement d'un personnage (1.6.4) : ce qu'un module note sur sa besace, par son numéro de conteneur, pendant
  l'écriture qui précède le déchargement (objet retiré…) part aussi avant que le conteneur quitte la mémoire ; et un
  conteneur relu en base dont des écritures attendent encore les fait partir d'abord. Un retour du personnage dans
  les 3 s ne fait donc jamais revenir un objet retiré.
- Pile d'un objet sans définition au chargement d'un conteneur (module arrêté, ou pas encore redéclaré après un
  `restart vava_inventory`) : gardée à part, sa ligne en base intacte, puis replacée dès que l'objet est déclaré
  (1.6.3) : à sa place d'origine si elle est libre, sinon à la première place libre ; sans place, elle reste à part.
  Aucune pile n'est recouverte. Une pile tenue en main ainsi gardée à part retrouve la main à son retour. Redéclarer
  ses objets à l'annonce `core:module:ready` de `vava_inventory` suffit donc à tout rendre aux joueurs en jeu.

Touches par défaut (réglables par le joueur dans Paramètres > Raccourcis > FiveM) : `I` ouvre l'inventaire, et la
touche choisie pour l'ouvrir le ferme aussi (1.6.3 ; `Échap` toujours),
`1` à `5` utilisent les raccourcis (un objet qui se tient en main sans autre usage y est pris ou reposé). Dans
l'interface : glisser pour déplacer (sur la ceinture : raccourci ; sur les Mains : prendre en main), `R` pour pivoter,
`Maj` pour diviser en deux, double-clic pour utiliser, prendre en main ou ramasser, clic droit pour les actions,
relâcher hors de l'inventaire pour jeter au sol.

Polices de l'interface : Cinzel et EB Garamond, prises dans `vava_ui` avec le grain, les coins, le filet et le losange
(dépendance déclarée depuis 1.8.0 ; licence SIL Open Font License dans `modules/vava_ui/web/fonts/`) ; les cases et la
balance restent dans le module. Pour travailler le rendu sans le jeu, ouvrir `web/index.html` dans un navigateur
(`?drop=1` ajoute un sac au sol, `?catalog=1` le catalogue de développement) : données simulées de
`web/dev/devmock.js`, jamais livré.

**Catalogue de développement** (1.5.0, `config.catalog`, désactivé par défaut) : `enabled = true` ajoute la commande
`/catalogue [catégorie] [page]` (droit vava_admin `staff` ; sans vava_admin, ACE `vava_inventory.catalogue` ; en
console : `catalogue <joueur> [catégorie] [page]`). Elle ouvre, à côté de la besace, un conteneur temporaire garni
d'une pile pleine de chaque objet connu du registre, par catégorie puis libellé, découpé en pages de 16 × 10 cases.
Son panneau porte un bandeau : onglets des catégories (avec leur compte), champ de recherche sur le nom (accents et
casse ignorés, envoyé après une courte pause de frappe ou sur Entrée ; Échap quitte le champ, un second ferme
l'inventaire), flèches de page ; chaque geste passe par le RPC `vava_inventory:catalog`, qui revérifie le droit et
renvoie le panneau garni. Un double-clic ou « Prendre » met l'objet dans la besace. Ce qu'on en prend est regarni
aussitôt (stock sans fin), ce qu'on y dépose disparaît au remplissage suivant, rien n'est écrit en base (pas même aux
changements de page, 1.6.1 : un objet pris s'écrit comme tout objet de la besace, un objet de la besace déposé est
effacé de la base), et le catalogue disparaît avec le personnage. Chaque ouverture par la commande est inscrite au journal du Conseil. À
n'activer que sur un serveur de test : le module l'annonce par un avertissement au démarrage.

### `vava_needs`

Faim et soif, de 0 (épuisé) à 100. Champ `vava_needs:state` `{ hunger, thirst }` (visibilité `owner`), sauvegardé
avec le personnage. Les besoins, durées, paliers, messages et gestes sont dans `config.lua` : ajouter un besoin
à `needs` suffit pour qu'il baisse, s'affiche et se mange.

- **Baisse** : décidée par le serveur, une boucle pour tous les personnages actifs (`tickMs`, 60 s). Faim de 100 à 0
  en 4 h de jeu, soif en 3 h ; × 1,5 pour la part du temps passée à courir (vitesse lue côté serveur ; un véhicule
  ne compte pas). Aucune baisse hors connexion ni pendant la sélection.
- **Paliers** : sous 30, un message ; sous 10, un message et l'endurance maximale réduite ; à 0, perte de vie à chaque
  passage (2 points pour la faim, 4 pour la soif). Avec `vava_health` (1.2.0), **le serveur décide et applique** la
  perte : rapportée à la vie au-dessus du seuil d'après la vie maximale du ped lue côté serveur
  (`starvation.share` de `shared/starvation.lua`), passée par `bridge/server.lua` à la chaîne de dégâts
  (`exports.vava_health:hit`, type `privation`, sans source ; 1.2.1 avec `vava_health` 1.3.0, repli sur `damage` avec
  une version plus ancienne) ;
  `vava_health` tient la vie et prévient le client ; à 0 le joueur est mis à terre, puis peut être relevé, et la
  baisse s'arrête tant qu'il y est (à terre, pas encore apparu ou `vava_health` en démarrage : rien n'est retiré).
  Sans lui, seul repli : l'évènement `vava_needs:starve` part vers le seul joueur, dont le client l'applique sans
  descendre sous `health.floor` (10 % de la vie au-dessus du seuil de mise à terre), pour que personne ne reste mort
  sans recours. L'endurance réduite reste un effet du client. Détail et tests en jeu : `modules/vava_needs/README.md`.
- **Manger, boire** : objets de l'inventaire déclarant `effects = { hunger = …, thirst = … }`. Refusés dès 95 (à 95 et
  au-dessus pour chaque besoin que l'objet remplit : « Vous n'avez plus faim. ») et pendant le geste en cours (3 s).
  Geste selon la catégorie (`nourriture` : manger,
  `boisson` : boire), sans accessoire en main. Un objet portant aussi l'effet d'un autre module n'est jamais refusé
  pour cause de satiété.
- **Réseau** : un envoi par joueur et par minute (son champ), à lui seul ; aucun RPC (l'utilisation d'un objet passe
  par l'inventaire). La perte de vie n'est envoyée au client que sans `vava_health` (repli).

**Exports serveur** (cible : un joueur, son personnage actif) :

| Export | Retour |
|---|---|
| `get(source)` | `{ hunger, thirst }` ou `nil, code` |
| `set(source, { hunger?, thirst? })` | `true, valeurs` ou `false, code` — un besoin absent est inchangé |
| `add(source, { hunger?, thirst? })` | `true, valeurs` ou `false, code` — écarts de −100 à 100, résultat borné |
| `setModifier(source, clé, { hunger?, thirst? })` | `true` ou `false, code` — multiplicateurs de baisse (0 à 10), cumulés |
| `removeModifier(source, clé)` | `true` ou `false, code` — seulement ses propres modificateurs |

Un modificateur (maladie, auberge, sort…) ne vit que le temps du personnage chargé et disparaît à l'arrêt du module
qui l'a posé. Codes : `not_ready`, `invalid_target`, `no_character`, `invalid_values`, `invalid_key`, `key_taken`,
`not_found`, `not_owner`.

**Hooks** : `vava_needs:decay` (`before`, annulable : `{ source, characterId, elapsedMs }` — prison, zone protégée ;
le temps suspendu n'est pas rattrapé) et `vava_needs:changed` (`after` : `{ source, characterId, values, previous,
reason, resource? }`, `reason` = `decay`, `consume` ou `api`).

**Export client** : `get()` — valeurs du personnage local, ou `nil`.

### `vava_hud`

Affichage en jeu (ressource cliente). **Retire l'interface native de GTA** : minimap (et ses barres de vie), HUD
(argent, noms de rue et de véhicule, munitions, notifications…) ; réappliqué si le jeu la réaffiche ; le menu pause
et le chat restent (`config.lua` → `native`). La remplace par des jauges et des notifications pour tous les modules.
Jauges affichées quand un personnage est en jeu ; masquées pendant la sélection, le menu pause et les fondus au noir.

| Export client | Retour |
|---|---|
| `defineGauge(id, { label, icon, order?, low?, critical? })` | `true` ou `false, code` |
| `setGauge(id, valeur)` | `true` ou `false, code` — de 0 à 1 ; rien n'est envoyé à l'interface si la valeur ne change pas |
| `setGaugeActive(id, actif)` | `true` ou `false, code` — lueur de laiton autour du médaillon (le joueur parle, un effet est en cours…) ; depuis 1.2.0 |
| `removeGauge(id)` | `true` ou `false, code` |
| `notify(message, nature?)` | `true` ou `false, code` — nature `info` (défaut), `warning` ou `danger` ; texte brut, 200 caractères au plus |
| `progress(id, { label, durationMs, cancelable? })` | `true` ou `false, code` (`invalid_id`, `invalid_options`, `busy`) — barre de progression d'une action longue (récolte, artisanat, réparation, leçon…) au centre bas de l'écran, de 0 à 100 % sur `durationMs` (entier, 250 à 120 000 ms) ; `label` texte brut, 60 caractères au plus ; **une seule à la fois** ; depuis 1.3.0 |
| `cancelProgress(id)` | `true` ou `false, code` (`not_found`, `not_owner`) — interrompt la progression en cours ; seule la ressource qui l'a lancée le peut ; depuis 1.3.0 |
| `currentProgress()` | `{ id, label, endsAt }` (`endsAt` : horloge `GetGameTimer`) ou `nil` ; depuis 1.3.0 |

- `id` : `<ressource>:<nom>` ; un module ne gère que ses jauges et sa progression, retirées à son arrêt.
- `icon` : image `nui://<ressource>/<chemin>` listée dans les `files` du module (aucune adresse externe).
- `low`, `critical` (0 à 1) : paliers où l'anneau passe à l'ambre puis au rouge, avec une lueur au palier critique.
- Les notifications GTA étant retirées, un module affiche ses messages par `notify` ; sans `vava_hud`, il revient à
  celles de GTA (c'est ce que font l'inventaire, les besoins et la santé).
- La barre de progression est **purement visuelle** : le serveur reste maître du temps et revérifie la durée à la fin
  de l'action (comme l'incantation de `vava_magic`). Le HUD n'écoute aucune touche : interrompre (touche, déplacement,
  coup reçu) est l'affaire du module, qui appelle `cancelProgress` ; `cancelable` n'ajoute qu'un indice discret sous la
  barre (`config.lua` → `progress.cancelHint`). Le menu pause et les fondus masquent la barre sans l'interrompre ; une
  page d'interface rechargée en cours d'action reprend à la bonne avancée.
- Hooks client (émis par le HUD) : `vava_hud:progressDone` (`{ id }`) à la fin ; `vava_hud:progressCancelled`
  (`{ id, reason }`) à l'interruption, `reason` = `module` (`cancelProgress`, ou arrêt de la ressource qui l'avait
  lancée) ou `hidden` (retour à la sélection, déchargement du personnage).
- Pour travailler le rendu sans le jeu : `web/index.html?values=0.8,0.62,0.08` dans un navigateur ; `&progress=1`
  (barre de 8 s menée à son terme) ou `&progress=cancel` (interrompue à 60 %). Depuis 1.4.0, polices et grain viennent
  de `vava_ui` (dépendance déclarée) et les données simulées de `web/dev/devmock.js`, jamais livré.

### `vava_health`

Santé, mise à terre, réanimation, et **chaîne de dégâts commune** (1.3.0 ; coup déjà lancé et `vocabulary().pvp` :
1.4.0 ; `docs/plan/COMBAT_V1.md` § 1). Champ
`vava_health:state` `{ health, downed, downedFor }` (visibilité `owner`) : `health` de 0 à 1, part de la vie au-dessus
du seuil où GTA met un joueur à terre. Lieux de soins, délais, distances, touches, chaîne et messages : `config.lua`.
Demande le core 0.10.0 (`core.net.send` : tous les envois du module sont comptés dans `/vava_reseau`).

- **Vie tenue par le serveur** (1.3.0) : la valeur du serveur fait foi pour tout (`hit`, `isDowned`, `get`, soins, mise
  à terre) ; le client l'applique (`vava_health:set`, à la seule cible, une fois par tour au plus). Le serveur lit le
  ped de chaque joueur toutes les 500 ms, après la fenêtre d'application d'un ordre (1,5 s + 2 × ping, 1 s au plus) :
  ped plus bas = perte native (chute, noyade, feu du décor…) acceptée sans modificateurs ; ped au seuil (vie GTA 100)
  ou dessous = mise à terre ; ped plus haut = client en retard ou modifié, vie du serveur renvoyée après 2 s, puis
  après un délai doublé à chaque correction restée sans effet (jusqu'à 30 s ; 2 s de nouveau dès l'accord), console.
  Un client qui garde son ped au maximum ne gagne rien face aux coups, aux sorts et à la faim, mais échappe aux pertes
  natives (chute, noyade, PNJ) : les attaques de PNJ hostiles devront passer par `hit`. Aucune écriture de la vie ne dépend plus de la confirmation d'apparition du client : sans elle, le ped
  est lu d'office 20 s après l'ordre d'apparition. Vie écrite dans le personnage à chaque transition et à chaque soin,
  au plus toutes les 10 s après des coups, au départ et à l'arrêt du module ; restaurée à chaque apparition. La
  récupération automatique de GTA est coupée : on se soigne par objets (`effects = { health = 20 }` : +20 %, refusé
  si l'on n'est pas blessé) ou en se faisant relever.
- **Mise à terre** : décidée par le serveur, aussitôt que sa vie atteint 0 (coup, `setHealth(0)`), ou quand le ped est
  lu au seuil ou dessous (cause et auteur lus côté serveur). Le serveur ordonne toujours au client de coucher son ped
  (vie GTA 0) : ce que GTA fait d'une vie posée exactement sur le seuil ne compte pas (règle pure :
  `shared/vitality.lua`). Le joueur reste au sol, l'écran « wasted » de GTA est remplacé par l'écran « Vous êtes à
  terre », qui montre la touche « rendre l'âme » choisie par le joueur. À terre : aucun geste sur les objets (prendre en
  main compris ; un module peut encore faire reposer l'objet tenu), l'inventaire ouvert se ferme à la chute (grenier,
  coffre, fouille, sac ; export `close` de l'inventaire 1.6.4, 1.1.4), faim et soif figées, ni récolte, ni artisanat,
  ni agriculture (refusés par ces modules), aucun coup ni sort ne le touche ; un ped resté au seuil ou au-dessus
  (client qui se relève seul) est remis à terre.
- **Relever** (touche G par défaut) : le serveur choisit la personne à terre la plus proche (2 m, positions lues côté
  serveur, rien n'est diffusé) ; geste de 8 s, distance revérifiée à la fin ; relevé avec 25 %. La personne à terre
  lit « Quelqu'un vous relève » : son nom n'est pas révélé.
- **Rendre l'âme** (touche E maintenue 3 s) : après 3 minutes à terre ; porté au lieu de soins le plus proche avec 50 %.
  D'office au bout de 10 minutes. Se déconnecter à terre ne sert à rien : on revient à terre, avec le temps restant.
  Se déconnecter juste après un coup mortel non plus : le ped est relu au départ si le jeu le donne encore.
- **Dégâts natifs** : coups d'arme ou de poing d'un joueur sur un autre joueur (ou sur une victime introuvable côté
  serveur), explosions, feux et projectiles lancés par un joueur : annulés par le serveur (`weaponDamageEvent`,
  `explosionEvent`, `fireEvent`, `startProjectileEvent`, réglables dans `natives`) ; une ligne de console par joueur et
  par minute. Tir ami coupé côté client à chaque apparition (confort).

#### La chaîne de dégâts

**Tous** les dégâts d'un module passent par l'export serveur `hit`, après les vérifications du module (portée, arme,
technique, sort, délai). Aucun RPC ne peut demander un dégât.

```lua
local result, code = exports.vava_health:hit(target, {
    amount = 12,                  -- obligatoire : points avant modificateurs (100 = une vie pleine), 0 < amount ≤ 200
    kind = 'tranchant',           -- obligatoire : tranchant | contondant | percant | feu | eau | terre | lumiere |
                                  --   esprit | pur | privation | monde (réservé aux pertes natives)
    source = attackerSrc,         -- facultatif : joueur à l'origine (1 à 65535) ; nil : le monde, la faim…
    sourceCharacter = 42,         -- facultatif : personnage à l'origine, quand le joueur a pu partir
    part = 'torse',               -- facultatif : tete | torse | bras | jambes
    weapon = 'epee_longue',       -- facultatif : objet qui a frappé (identifiant, 64 octets)
    technique = 'taille_descendante', -- facultatif : technique (identifiant, `<éditeur>:<id>` accepté)
    spell = 'boule_de_feu',       -- facultatif : sort
    tags = { melee = true, parryable = true },  -- facultatif : melee, ranged, spell, area, overTime, native, legacy,
                                  --   reflected, parryable, unblockable, undodgeable, launched (8 au plus, valeur true)
    launchedAt = 123456,          -- avec tags.launched seulement (1.4.0) : GetGameTimer() du serveur au lancement
})
-- → { id, amount (après modificateurs), applied, blocked, absorbed, resisted, added, cancelled?, stage?, downed,
--     health (0 à 1 après le coup) } ou nil, code
```

- **Paquet fermé** : toute autre clé est refusée (`unknown_field`), `origin` compris : le serveur pose lui-même
  `origin` = ressource appelante (`GetInvokingResource`), le numéro du coup et le personnage de la source s'il est en
  jeu. Listes fermées lisibles par `vocabulary()`.
- **Ordre** : garde-fous (`kind = 'monde'` réservé à `vava_health` : `invalid_kind` ; 20 coups par seconde d'une
  même source sur une même cible, les coups sans source partageant un compte : `too_many_hits` ; un coup lancé pendant
  un autre permis une fois : `too_deep` au-delà) ; préconditions, sans hook ni journal : cible à terre, annulé
  `downed` ; `chain.pvp = false` et source ≠ cible, annulé `pvp_off` ; source à terre (hors `tags.overTime` et
  `tags.reflected`, et hors coup **déjà lancé** debout, 1.4.0 : `tags.launched` avec `launchedAt`, la source tombée
  après le lancement, lancé depuis au plus `chain.launchedMaxMs` = 4 s), annulé `source_downed` ; hook `before` (refus volontaire : `cancelled` = raison,
  `stage = 'before'` ; un abonné **en erreur** ne refuse pas : le coup passe, une ligne de console par minute) ; modificateurs
  dans l'ordre fixe **annulation → esquive → parade → blocage → bouclier → resistance**, puis `priority`, puis clé ;
  application (cible relue, vie du serveur baissée, mise à terre aussitôt à 0, `reason = 'hit'`) ; hook `after` ;
  journal. Aucune attente entre la lecture de la vie et son écriture.
- `downed` du résultat : ce coup a mis la cible à terre. `stage` : étape de l'annulation (`before`, une étape,
  `application` si la cible est partie ou tombée entre-temps).
- Codes (`nil, code`) : `not_ready`, `invalid_target`, `no_character`, `invalid_packet`, `invalid_amount`,
  `invalid_kind`, `invalid_source`, `invalid_part`, `invalid_ref`, `invalid_tags`, `invalid_launch` (1.4.0 :
  `launchedAt` sans `tags.launched` ou l'inverse, ou pas un entier positif), `unknown_field`, `too_many_hits`,
  `too_deep`, `hit_error` (erreur interne, console).
- **Coup déjà lancé** (1.4.0) : un projectile en vol, le présage d'un sort, une flèche… lancés par un joueur debout
  portent encore s'il tombe à terre avant l'impact. Le module serveur qui frappe pose `tags.launched` et `launchedAt`
  (son `GetGameTimer()` au lancement, jamais une valeur venue d'un client) ; `vava_health` compare à l'instant de la
  mise à terre de la source, qu'il tient lui-même. Ce n'est pas `overTime` (réservé aux effets qui durent).

**Registre `vava_health:modifiers`** (défini par `vava_health`, 32 entrées) : un module y déclare ses modificateurs,
**au plus un par étape** (un second à la même étape est retiré aussitôt, console), sous son nom (`<ressource>:<nom>` ;
une clé au nom d'une autre ressource est retirée aussitôt), dans son `setup` si `core.registry.exists('vava_health:modifiers')`, et de nouveau sur `core:module:ready`
quand `name == 'vava_health'` (le registre disparaît avec lui). Le modificateur lit ses propres données (protections
actives, fenêtres ouvertes, définitions de l'Atelier) : elles changent sans toucher au registre.

```lua
core.registry.add('vava_health:modifiers', 'vava_magic:protections', {
    stage = 'bouclier',           -- annulation | esquive | parade | blocage | bouclier | resistance
    priority = 50,                -- facultatif : 0 à 99 dans l'étape (défaut 50), plus petit = plus tôt
    label = 'Protections magiques', -- 1 à 48 octets
    kinds = { 'feu', 'eau' },     -- facultatif : appelé seulement pour ces types
    apply = function(ctx) return nil end,
})
```

`apply(ctx)` reçoit une copie du coup (`id`, `target`, `targetCharacter`, `source?`, `sourceCharacter?`, `origin`,
`kind`, `amount` courant, `base`, `stage`, `part?`, `weapon?`, `technique?`, `spell?`, `tags`, `health` en points) et
**rend un résultat** : `nil` ou `true` (rien) ; `{ cancel = 'raison' }` (montant à 0, raison `^[A-Za-z0-9_]+$` de 32
octets, sinon `cancelled` ; arrêt de la chaîne) ; sinon `{ blocked = n }`, `{ absorbed = n }`, `{ resisted = n }`
(retirés, au plus le montant courant) puis `{ added = n }` (au plus `base`, total au plus 200). Un nombre négatif ou
non fini, ou un autre type : tout le rendu est ignoré. Erreur : modificateur **ignoré pour ce coup**, les suivants
s'exécutent (une ligne de console par minute) ; plus de 5 ms : signalé, jamais coupé. Contrat : ne jamais céder la main
(ni `Wait`, ni base, ni `callClient`) ni lancer `hit` (un renvoi part du hook `after`). Exemple vivant :
`examples/vava_example_combat` (développement seulement).

**Journal des coups** `vava_health_hits` : tout coup venu d'un autre joueur qui a atteint la chaîne (annulé compris) et
toute mise à terre par la chaîne ou par une perte native (personnages, ressource appelante, type, technique ou sort,
arme, points, annulation, position) ; écrit par lots (un lot refusé par la base est réessayé ligne à ligne, une ligne
refusée est abandonnée et comptée en console), purgé après 30 jours.

**Exports serveur** (cible : un joueur, son personnage actif) :

| Export | Retour |
|---|---|
| `hit(cible, paquet)` | résultat ou `nil, code` (ci-dessus) |
| `vocabulary()` | copie `{ healthPoints, maxAmount, kinds, parts, tags, stages, pvp, launchedMaxMs }` : listes pour les éditeurs de l'Atelier et les modules ; `pvp` (1.4.0) : interrupteur `chain.pvp`, pour qu'un module coupe aussi ses effets sans dégâts (poussées, gel…) quand les combats entre joueurs sont coupés |
| `modifiers()` | liste ordonnée `{ { key, stage, priority, label, kinds? } }` (sans les fonctions) |
| `get(source)` | `{ health, downed, downedFor }` ou `nil, code` — `health` : vie du serveur (0 à terre) |
| `isDowned(source)` | booléen — à appeler (isolé, `pcall`) par tout module qui refuse une action à terre, plutôt que de recopier la règle ; module absent : pas à terre |
| `setHealth(source, vie)` | `true` ou `false, code` — de 0 à 1 ; 0 met à terre aussitôt (`reason = 'api'`, `cause = 'set'`) |
| `heal(source, part)` | `true` ou `false, code` — à partir de la vie du serveur (ce n'est pas un dégât : aucune chaîne) |
| `damage(source, part)` | `true` ou `false, code` — **déprécié** pour les coups et les sorts : enveloppe de `hit` (`amount = part × 100`, `kind = 'pur'`, `tags.legacy`, sans source) ; un coup annulé rend `false, raison` |
| `down(source, cause?)` | `true` ou `false, code` — mise à terre décidée par un module (`cause` : identifiant ASCII `^[A-Za-z0-9_-]+$` de 32 octets au plus, 'piege'… ; sinon `invalid_cause`) |
| `revive(source, vie?)` | `true` ou `false, code` — relève sur place (25 % par défaut) |

Codes : `not_ready`, `invalid_target`, `no_character`, `invalid_amount`, `invalid_cause`, `downed`, `already_downed`,
`not_downed`, plus ceux de `hit`. `not_spawned` n'est plus rendu (1.3.0).

**Hooks** :
- `vava_health:hit` (`before`, annulable, refus seul) : `{ id, target, targetCharacter, source?, sourceCharacter?,
  origin, kind, amount, part?, weapon?, technique?, spell?, tags, health }` (points) — prison, trêve, évènement du
  Conseil ;
- `vava_health:hit` (`after`) : même charge + `base`, `amount` (final), `applied`, `blocked`, `absorbed`, `resisted`,
  `added`, `cancelled?`, `stage?`, `downed`, `health` (part après le coup) — pour tout coup qui a atteint la chaîne
  (annulé compris), et pour chaque perte native (`origin = 'vava_health'`, `kind = 'monde'`, `tags.native`, sans
  source). Usages : « quand le porteur est frappé au corps à corps » (`tags.melee`), interrompre une incantation
  (`applied > 0`), XP sur une vraie cible, renvoi (`hit` sur `source` avec `tags.reflected`) ;
- `vava_health:downed` (`after`) : `{ source, characterId, reason, cause?, killer?, origin?, hitId?, claimedKiller?,
  killerUnverified? }` — `reason` = `hit` (vie du serveur vidée par la chaîne : `cause` = type, `killer` = source,
  vérifiée par le module qui frappe), `death` (ped lu au seuil : `cause` = arme GTA ; aussi émis au départ du joueur
  quand un coup mortel y est lu) ou `api` ; `origin` et `hitId` pour une mise à terre par la chaîne ou par une perte
  native. Pour `death`, l'auteur lu sur le ped (`GetPedSourceOfDeath`) est **déclaré par le client de la victime** :
  jamais `killer`, seulement `claimedKiller` avec `killerUnverified = true` (1.3.0) ;
- `vava_health:reviving` (`before`, annulable) : `{ source, target }` — exiger un métier, un objet… ; la raison du refus
  est montrée au joueur ;
- `vava_health:revived` (`after`) : `{ source, characterId, reason, by? }` ;
- `vava_health:respawned` (`after`) : `{ source, characterId, reason, point }` — `reason` = `choice` (il a rendu l'âme)
  ou `timeout` ; point d'appui des pénalités à venir.

**Export client** : `get()` — `{ health, downed }` du joueur local, ou `nil` (les métiers le lisent pour taire leur
invite à terre).

Pour travailler le rendu sans le jeu : `web/index.html?state=downed` (ou `ready`, `patient`, `holding`, `assist`).
Détail et tests en jeu : `modules/vava_health/README.md`, `docs/tests/sante.md`, `docs/tests/combat.md`.

### `vava_admin`

Administration du royaume : le **Conseil** (rangs et droits), le panneau **Registre du Conseil** (F10 ou `/conseil`,
réglable), les bans vérifiés à la connexion, le journal des actions, les signalements des joueurs (`/signaler`).
Rangs, droits, durées, textes : `config.lua`. Demande le core 0.5.0 (compte connu transmis au hook de connexion).

**Rangs** (cumulatifs). Les actions qui contraignent un joueur (amener à soi, renvoyer, déplacer, immobiliser,
avertir, expulser, bannir, fouiller, observer) ne visent jamais un membre de rang égal ou supérieur. Rejoindre,
Soigner, Nourrir, Écrire et Donner l'aident ou ne le touchent pas : elles ne sont pas protégées par le rang, et c'est
voulu (l'écran des joueurs non plus, voir plus bas).

| Rang | Droits |
|---|---|
| Gardien | `view`, `teleport`, `freeze`, `heal`, `message`, `warn`, `kick`, `reports`, `watch` (écran des joueurs) |
| Sénéchal | + `ban` (7 jours au plus), `inventory`, `give`, `announce`, `tools`, `spectate`, `logs`, `bans`, `metiers` (zones et nœuds de récolte, stations, parcelles, correction d'une compétence) |
| Souverain | + `unban`, `staff`, bans définitifs |

**Amorçage** : le premier membre ne se nomme que depuis la console serveur, jamais en jeu.

| Commande (console) | Effet |
|---|---|
| `vava_conseil <compte> <rang\|aucun>` | nomme ou révoque un membre |
| `vava_ban <compte> <heures\|0> <motif>` | bannit un compte, connecté ou non (0 = définitif) |
| `vava_unban <compte>` | lève les bans d'un compte |
| `vava_kick <id> <motif>` | expulse un joueur connecté |

**Garanties** :
- Chaque intention du panneau est une RPC à schéma strict et à débit limité ; le serveur revérifie le droit, la cible et
  le rang. Le panneau n'affiche que ce que le rang permet : simple confort.
- Toute action (panneau, console, module) est écrite au journal (`vava_admin_logs`, 90 jours) et publiée par le hook
  `vava_admin:action` (`after` : `{ actor = { accountId, label, rank }, action, target?, details }`).
- Les données des joueurs ne partent qu'au personnel, et à la demande ; le pseudo FiveM n'est jamais enregistré. Les
  identifiants d'un joueur (license, discord, steam…, jamais l'adresse IP) ne partent qu'à la Chancellerie, qui les
  affiche : la fiche du Registre en jeu ne les reçoit pas (1.7.0).
- Bans par compte, vérifiés au hook `core:player:connecting` : un banni voit le motif, la fin et le numéro du ban.
  Aucun compte n'est créé pour une connexion refusée. Second contrôle au hook `core:player:joined` (compte alors
  toujours connu, hors du fil du core) : un compte banni pendant son chargement est expulsé avec le même texte et le
  journal l'inscrit (« Banni écarté par le Registre », au nom de la Console, `moment : à son arrivée`) (1.7.1). Au
  démarrage du module (redémarrage du Registre ou du core), chaque joueur déjà en jeu est relu de la même façon
  (`moment : au démarrage du Registre`) ; un joueur que le core n'a pas encore repris est relu au tour suivant
  (`banRecheck.sweepAttempts` tours, `sweepRetryMs` d'écart).
- **Registre absent** (1.7.1, avec le core 0.9.1) : `vava_admin` est un garde de connexion du core
  (`players.connectionGuards`, voir « Porte gardée ») : en démarrage, en redémarrage, en échec ou arrêté (`stop
  vava_admin`, ou `restart vAvA_core`, qui l'arrête sans le relancer), la porte est fermée (« Le royaume s'éveille :
  réessayez dans un instant. ») jusqu'à `ensure vava_admin` ; la relecture de son démarrage passe alors sur les joueurs
  déjà en jeu. Le module échoue au démarrage si la table des bans est illisible (lecture d'essai). Seul un serveur où la
  ressource n'existe pas laisse entrer sans vérification de ban (signalé à la console à chaque connexion) : un serveur
  sans Registre retire `vava_admin` de `players.connectionGuards`, et **renommer la ressource oblige à mettre cette
  liste à jour** (sinon l'ancien nom est absent et la porte s'ouvre sans bans).
- **Base en panne** (1.7.1, avec le core 0.9.1) : un compte n'entre jamais sans qu'une lecture de ses bans ait réussi.
  Si la base ne répond pas pendant la recherche du compte, le core refuse la connexion (« Le serveur est momentanément
  indisponible, réessayez dans un instant. ») ; si elle ne répond pas pendant la lecture des bans à la connexion, le
  joueur est refusé avec « Le registre des bans ne peut être consulté pour l'instant : réessayez dans une minute. »
  (`messages.banCheckUnavailable`), et la console l'écrit. À l'arrivée en jeu ou à la relecture du démarrage, une
  lecture en échec est refaite après `banRecheck.retryMs` (5 s) ; si elle échoue encore, `banRecheck.onError` décide :
  `keep` (défaut, décision du 30 octobre 2026 : le joueur reste en jeu, la console écrit « compte n° N … : bans
  illisibles, joueur gardé (cause) » ; à l'arrivée, la lecture de la connexion avait réussi, et un hoquet de base au
  démarrage du Registre n'expulse pas tout le serveur) ou `kick` (expulsé avec le même message). Personne n'est refusé
  tant que la base répond. Une première venue (aucun compte encore) n'a rien à vérifier ; une base injoignable bloque de
  toute façon la création du compte. Pendant une panne de la base, plus personne ne se connecte : c'était déjà vrai
  (le compte et les personnages se lisent en base), le message dit maintenant pourquoi.
- Déplacer et immobiliser passent par les natives serveur (OneSync). L'état « immobilisé » vit en mémoire : à l'arrêt
  (ou au redémarrage) du module, chaque joueur immobilisé est libéré et prévenu, jamais laissé figé sans Registre pour
  le libérer (1.7.0). Le vol libre est la seule boucle par image du module, active seulement pendant son usage ;
  l'observation place le membre, invisible, sous le joueur observé. Sa place de départ, lue par le serveur quand
  l'observation est accordée, est gardée dans le champ privé `vava_admin:spectateReturn` de son personnage. Chaque
  observation reçoit un numéro ; seule la fin de la dernière (RPC `vava_admin:spectateEnd(numéro)`, entier borné)
  efface la place, et une observation remplacée n'annonce pas sa fin. S'il part avant, la place est marquée « parti »
  au déchargement ; à son retour, il y est replacé dès l'apparition confirmée de ce même personnage, et la place n'est
  effacée qu'une fois le replacement accordé (redémarrage du module compris) : jamais sous terre (1.7.0).
- Vol libre d'une touche (F2 par défaut, réglable dans les raccourcis FiveM) : chaque appui est accordé par le serveur
  (droit `tools`, inscrit au journal) ; sans droit, la touche ne fait rien. Pendant le vol, le membre est invisible
  des autres joueurs (il se voit lui-même) et retrouve ensuite sa visibilité d'avant, arrêt du module compris
  (collision, gravité et vulnérabilité rétablies sur-le-champ).

**Exports serveur** :

| Export | Retour |
|---|---|
| `isStaff(source)` | booléen |
| `can(source, droit)` | booléen |
| `rankOf(source)` | `{ name, label, level }` ou `nil` |
| `isFrozen(source)` | booléen — immobilisé par le Conseil (Registre) ; lecture seule : un module qui fige et libère un ped (gel d'un sort) ne libère pas celui que le Conseil retient ; depuis 1.6.0 |
| `ban(compte, heures, motif)` | `true, n° du ban` ou `false, code` — au journal sous le nom du module appelant |
| `kick(source, motif)` | `true` ou `false, code` |
| `log(source, libellé, détails?)` | `true` ou `false, code` — inscrit au journal une action d'un membre du Conseil faite dans un module (libellé lu tel quel, 32 caractères ; détails `{ clé = texte ou nombre }`, 8 au plus) ; depuis 1.1.0 |

**Outils des modules** (depuis 1.1.0) : un module ajoute un bouton à la page Outils du Registre par le registre du core
`vava_admin:tools` — clé `<ressource>:<nom>`, `{ label, hint?, permission }` (un droit des rangs). Le bouton n'apparaît
qu'aux membres qui ont ce droit, même sans le droit `tools` des outils du Registre : la page Outils s'affiche dès
qu'un outil y est ouvert au membre (le Gardien y trouve le mur des caméras, droit `watch`), avec les seuls outils de
modules s'il n'a pas `tools` (1.7.0). Un clic revérifie le droit côté serveur, ferme le Registre et déclenche chez ce
membre le hook client `vava_admin:toolOpened` (`{ key }`) : le module ouvre alors son interface et **revérifie chaque
action côté serveur**. Le Registre déclenche le hook serveur `vava_admin:toolsReady` quand son registre est prêt
(démarrage ou redémarrage : les entrées d'avant ont disparu avec lui) : y rajouter son outil.

```lua
local function addTool()
    if core.registry.exists('vava_admin:tools') and not core.registry.has('vava_admin:tools', 'mon_module:outil') then
        core.registry.add('vava_admin:tools', 'mon_module:outil', { label = 'Mon outil', permission = 'tools' })
    end
end
core.hooks.after('vava_admin:toolsReady', addTool)
addTool()
```

**Depuis le web** (1.2.0) : le catalogue des demandes du Conseil (`server/requests.lua`) sert le Registre en jeu et la
Chancellerie. Chaque demande déclare son droit, son schéma et où elle a un sens : en jeu seulement (rejoindre, amener à
soi, observer, outils, fouiller en ouvrant l'inventaire), au web seulement (`moveToPlayer`, `moveToCoords`,
`inventoryView` en lecture, `watchScreen`) ou les deux. Un compte du panneau agit comme un membre du rang que lui a
donné le compte maître, sans personnage : mêmes droits, mêmes contrôles de cible et de rang, journal au nom de
« Chancellerie : <compte> ». Outre les actions qui aident (plus haut), l'écran des joueurs échappe aussi à la règle du
rang (droit `watch`, tout le Conseil) : chacun le regarde chez tout le monde, membres du Conseil de tout rang compris. Exports réservés à la ressource-pont (`config.web.bridge`, `vava_chancellerie`) :

| Export | Retour |
|---|---|
| `webRequest({ label, rank }, nom, arguments)` | `true, résultat` ou `false, code` — arguments revalidés avec le schéma de la demande |
| `webCan({ label, rank }, droit)` | booléen |
| `webRanks()` | liste `{ name, label, level }` |
| `webLog({ label, rank }, libellé, détails?)` | `true` ou `false, code` — action d'un compte du panneau faite dans un autre module |

Hook `vava_admin:report` (serveur, `after` : `{ action = created|claimed|closed, id, author }`) : tient le panneau
web à jour.

Pour travailler le rendu sans le jeu : `web/index.html?tab=players` (ou `reports`, `bans`, `logs`, `staff`, `tools`,
`announce`), avec `&dialog=ban`, `&proclaim=1`, `&watch=1` ou `&rank=gardien` (données simulées de
`web/dev/devmock.js`, jamais livré). Polices (Cinzel Decorative comprise), grain, papier et coins du Registre viennent de
`vava_ui` (dépendance déclarée depuis 1.8.0 : `vava_ui` démarre avant `vava_admin`).

### `vava_voice`

Chat vocal de proximité, sur la voix intégrée à FiveM (Mumble de FXServer, son 3D du jeu) : aucune autre ressource.
Portées, touche, zones, textes : `config.lua`. Demande le core 0.11.0 (abonnements de zone, 1.3.0) ; facultatifs :
`vava_hud` ≥ 1.2.0 (médaillon),
`vava_health` (portée à terre), `vava_admin` ≥ 1.1.0 (zones de voix).

À poser dans le `server.cfg` (son 3D du jeu, voix envoyée aux seuls joueurs à portée), par `setr` (un `set` n'est pas
transmis aux joueurs) ; la Chancellerie (1.4.2) les écrit d'elle-même, et les ajoute avant chaque lancement à un
`server.cfg` qui ne les pose pas par `setr` (une valeur posée est gardée ; fichier qui inclut d'autres fichiers par
`exec`, ou qui n'est pas en UTF-8 : rien d'écrit, un avertissement — voir `docs/chancellerie.md`) :

```
setr voice_useNativeAudio true
setr voice_useSendingRangeOnly true
```

- **Portées** : Chuchoter (1,5 m), Parler (5 m, par défaut), Crier (15 m), Déclamer (25 m). La touche **W d'un clavier
  AZERTY** (en bas à gauche ; `Z` pour FiveM, qui nomme les touches par leur place sur un clavier QWERTY ; réglable dans
  Paramètres > Raccourcis > FiveM) passe à la suivante ; le choix est gardé sur la machine du joueur. Parler se fait avec
  la touche de GTA (N par défaut), le chat vocal activé dans les réglages du jeu. Changer la touche par défaut demande
  de renommer la commande (`command`) : FiveM garde sinon, chez chaque joueur, celle déjà enregistrée.
- **Repères** : médaillon « Voix » dans le HUD (un quart par portée), qui s'illumine quand le joueur parle ; cercle au sol
  à la distance de la voix pendant 1,5 s, au seul changement de portée, vu du seul joueur.
- **Hors du jeu** (sélection, chargement) : micro coupé par le serveur (`MumbleSetPlayerMuted`, rien à contourner) et
  joueur hors de tout salon : il n'entend personne. Le micro s'ouvre à l'apparition confirmée du personnage. À l'arrêt
  du module (1.2.1), aucun micro n'est rendu : un joueur en sélection reste muet pendant un `restart` ; un arrêt sans
  redémarrage le laisse muet jusqu'à sa reconnexion.
- **À terre** (`vava_health`) : Chuchoter et Parler seulement ; la portée d'avant revient après la réanimation. Relu à
  chaque apparition (déconnecté puis reconnecté à terre : toujours limité).
- **Zones de voix** : lieux où la voix porte plus (tribune, place : ×1,5 à ×3) ou moins loin (bibliothèque, crypte :
  ×0,5, ×0,75) ; cylindre centré sur la position de qui le crée : hauteur comptée depuis ses hanches, la zone descend
  aussi d'un mètre sous elles (`zones.baseOffset`), de quoi séparer les étages. Si des zones se chevauchent, la plus
  petite l'emporte. Créées en jeu par le Conseil (droit `tools`) : outil « Zones de voix » du Registre ou
  `/zonesvoix`. L'éditeur dessine les zones proches dans le monde (teinte selon l'effet) et l'aperçu suit les
  réglages ; nom de 40 signes (un « é » compte pour un, dans le champ comme sur le serveur : 160 octets au plus sur le
  réseau), centre lu côté serveur, valeurs bornées, un seul enregistrement à la fois, chaque action revérifiée et
  inscrite au journal du Registre. « S'y rendre » demande le droit `teleport`. Gardées en base (`vava_voice_zones`,
  200 au plus). Module arrêté éditeur ouvert : clavier et souris rendus au jeu.
- **Fonctionnement** : chaque joueur en jeu écoute son propre salon (`1000 + numéro de joueur`) ; sa parole part vers
  les salons des seuls joueurs à portée, recalculés toutes les 250 ms (Mumble n'est sollicité que si la liste change).
  Chaque zone de voix est une zone du core (`core.zones`, 1.3.0 : nom local `z<numéro>`, état `{ zone = { id, label,
  x, y, z, radius, height, multiplier } }`, marge `zones.subscribeMargin` = 40 m) : elle n'est envoyée qu'aux joueurs à
  moins de rayon + 40 m d'elle, et chaque changement à eux seuls (plus d'envoi à tous : l'évènement
  `vava_voice:zone` n'existe plus). L'éditeur reçoit la liste complète à son ouverture (au seul membre qui l'ouvre),
  puis suit les zones proches changées par un autre membre ; une zone lointaine changée par un autre l'est à la
  réouverture. Le client redemande la limite de portée (RPC `vava_voice:zones`, qui ne renvoie plus que `true`) à
  l'apparition et au redémarrage du module, avec quelques essais si le serveur n'est pas prêt ; elle revient par
  `vava_voice:limit`, au seul demandeur, s'il est en jeu. Aucune boucle par image, sauf pendant le cercle au sol et
  l'éditeur ouvert.
- **Limite** : la portée est réglée par le client, comme toute voix FiveM ; un client modifié pourrait l'agrandir.
  FXServer n'a pas non plus de contrôle d'accès aux salons Mumble : un client modifié peut rejoindre le salon d'un
  autre joueur (et entendre ce qui se dit près de lui) ou viser tous les salons (parler à tout le serveur), hors de
  toute portée. Aucune parade technique fiable, comme pour toutes les voix FiveM : à traiter par le règlement du
  serveur et la modération. Le serveur impose ce qu'il peut imposer : la coupure du micro hors du jeu.

| Export serveur | Retour |
|---|---|
| `isActive(source)` | booléen — personnage en jeu, micro ouvert |
| `limitRange(source, raison, maximum)` | `true` ou `false, code` — portée limitée au numéro `maximum` (1 = Chuchoter) pour cette raison (préfixée par la ressource appelante) ; la plus basse des limites s'applique |
| `releaseRange(source, raison)` | `true` ou `false, code` |
| `getZones()` | liste `{ id, label, x, y, z, radius, height, multiplier }` |
| `webUpdateZone(id, nom, rayon, hauteur, effet)` | `true, zone, détails` ou `false, code` — pont de la Chancellerie seulement (1.1.0) ; sans recentrage ; nom refusé par `invalid_label` (vide), `label_unreadable` (signe de contrôle ou invisible, 1.2.2) ou `label_too_long` (40 signes, 1.2.1) |
| `webDeleteZone(id)` | `true, nil, détails` ou `false, code` — pont de la Chancellerie seulement (1.1.0) |

| Export client | Retour |
|---|---|
| `getRange()` | `{ index, name, label, distance }` (distance avec l'effet de la zone), ou `nil` hors du jeu |
| `isTalking()` | booléen |

Hooks : `vava_voice:zonesChanged` (serveur, `after` : `{ action = set|remove, id, zone?, source }`),
`vava_voice:rangeChanged` (client, `after` : `{ index, name, distance }`).

Pour travailler le rendu de l'éditeur sans le jeu : `web/index.html` (ou `?zone=1` pour le formulaire) dans un
navigateur ; le médaillon : `vava_hud/web/index.html?values=0.8,0.6,0.3,0.75&talking=1`.

### `vava_world`

Le monde du royaume. La carte de GTA est **vidée de sa population** : aucun PNJ (passants, PNJ de scénario, police,
secours), aucun véhicule (circulation, véhicules garés, bateaux, trains, avions), aucun animal. Décidé par le serveur
(OneSync, `SetRoutingBucketPopulationEnabled`) pour chaque instance préparée, sans travail chez les joueurs ; au
démarrage, ce que le jeu avait déjà créé est retiré (joueurs, véhicules qu'ils conduisent et entités des scripts
gardés). Chez chaque joueur, réglés une fois et à chaque apparition : budgets de population à zéro, ni avis de
recherche ; **sons de la ville coupés** (depuis 1.1.0) : ambiance de circulation et de foule (scène de mixage de GTA
`FBI_HEIST_H5_MUTE_AMBIENCE_SCENE`), véhicules lointains, sirènes au loin, radio de police, musiques d'avion et d'avis de
recherche, et les émetteurs fixes listés (`config.audio.staticEmitters`). Si la nature (oiseaux, vent) se taisait
aussi, retirer la scène de `config.audio.scenes`. Réglages : `config.lua`.

| Export serveur | Retour |
|---|---|
| `prepareBucket(instance)` | `true` ou `false, code` — une instance (routing bucket) créée par un module suit les règles du monde |

Le gibier d'une future chasse sera créé par son module : la population du jeu n'en fournit plus.

### `vava_time`

L'heure, les saisons et le ciel du royaume (1.1.0), les mêmes pour tous les joueurs. Demande le core 0.7.0 (registre des
commandes) ; facultatifs : `vava_admin` (droit `tools`, outil du Registre, journal ; sans lui, personne ne règle rien),
`vava_hud` (notifications), `vava_chancellerie` ≥ 1.4.0 (page Ciel et heure). Ordre de démarrage : juste après
`vava_world`. Détail, config et tests : `modules/vava_time/README.md` et `docs/tests/temps.md`.

- **Heure** : celle de Paris (heure d'été du dernier dimanche de mars au dernier dimanche d'octobre, à 01:00 UTC),
  calculée depuis l'heure UTC du serveur, au rythme réel (une minute du jeu = une minute). Le Conseil la décale (± 12 h),
  la met à une heure voulue, la fige, la laisse reprendre (depuis l'heure figée) ou rend l'heure réelle.
- **Calendrier** (1.1.0) : par défaut, cycle de 14 jours réels par saison (`calendar.cycle`), ancré à minuit (Paris) du
  26 octobre 2026, printemps de l'an 1 ; l'an change à chaque nouveau printemps (une année du royaume : huit semaines).
  Au choix, vrai calendrier (`calendar.mode = 'real'` : printemps 20 mars, été 21 juin, automne 22 septembre, hiver
  21 décembre, heure de Paris). La date et la saison suivent l'heure réelle, pas le décalage du Conseil. L'ère et le
  format de date ne sont écrits qu'une fois, dans la config (`messages.year` : « an %d du royaume », `messages.dateText`).
  `/date` la donne en mots du jeu ; chaque début de saison est annoncé chez chaque joueur en jeu, lu sur
  `vava_time:calendar` (aucun envoi de plus).
- **Ciel** : cours pondéré par saison (successeurs plausibles, durées de 25 à 50 min, transition de 90 s) ; aucune neige
  hors de l'hiver ; « neige au sol » jamais tirée. Le Conseil impose un ciel (transition de 20 s ; il tient le temps d'un
  ciel puis reprend son cours, même hors saison), le fige, ou le rend à son cours.
- **Nuits de gel** (1.1.0 ; réglages décidés le 30 octobre 2026) : l'hiver, chaque nuit gèle avec la probabilité de
  `frost.seasons` (0,4), tirée une fois par jour. Au soir (`frost.warnHour`, 17 h du royaume) le hook
  `vava_time:frostWarning`, à la tombée de la nuit (`frost.hour`, 21 h) le hook `vava_time:frost` ; aucun évènement
  envoyé aux joueurs par `vava_time` (l'agriculture prévient elle-même ses cultivateurs). Ce qui est déjà passé au
  démarrage du module ne se rejoue pas. **Annonce** (1.2.0) : du tirage jusqu'au gel, `vava_time:calendar` porte
  `frost = true` ; `/date` ajoute alors `messages.frostTonight` (« La nuit sera froide. »).
- **Conseil** : outil « Ciel et heure » (registre `vava_admin:tools`, clé `vava_time:ciel`, droit `tools`) et `/ciel`
  (sous-commandes nommées dans `commands.actions` : `heure`, `decaler`, `figer`, `reprendre`, `reelle`, `imposer`,
  `garder`, `rendre`). Chaque décision est revérifiée, soumise au **débit commun** (`council.rate` : 6 coup sur coup,
  puis une toutes les deux secondes, jeu et Chancellerie confondus, code `rate_limited`), publiée, écrite en base
  (`vava_time_state`) et inscrite au journal du Registre si elle change quelque chose.

**GlobalState** (petit, rare, utile à tous ; retiré à l'arrêt du module) :

| Clé | Valeur | Écrite |
|---|---|---|
| `vava_time:clock` | `{ shift, frozen }` — décalage (s) sur l'heure de Paris ; seconde du jour figée, ou `false` | démarrage, décision sur l'heure |
| `vava_time:weather` | `{ id, from, at, fade, forced, frozen }` — ciel visé, ciel d'avant, début de la transition (secondes UTC du serveur), durée (s), imposé, figé | démarrage, chaque ciel (25 à 50 min), décision |
| `vava_time:calendar` | `{ season, day, year, frost? }` — `frost = true` (1.2.0) quand une nuit de gel est annoncée (tirée, pas encore tombée), absent sinon | démarrage, changement de jour (une écriture avec la nuit tirée au même passage), gel tombé (nuits de gel seulement) |

**RPC** : `vava_time:sync` (`{}` → secondes UTC du serveur ; à l'arrivée puis toutes les 30 min ; 6, 0,1/s),
`vava_time:open` (`{}` → vue de l'outil ; droit `tools` ; 5, 1/s), `vava_time:clock` (`action` ∈ `set`, `shift`,
`freeze`, `resume`, `real` ; `value` entier −1440…1440 : minute du jour pour `set`, minutes à ajouter pour `shift`
(± 720, jamais 0), sinon 0 ; 6, 0,5/s), `vava_time:weather` (`action` ∈ `impose`, `freeze`, `release` ; ciel de la
config, pour `impose` ; `hold` booléen ; 6, 0,5/s). Codes : `forbidden`, `invalid_value`, `unknown_weather`,
`not_ready`, `rate_limited` (débit commun des décisions). Si le module serveur n'est pas prêt, le client relance `sync`
quatre fois (après 2, 5, 10 et 30 s) puis attend que `vava_time:clock` soit publié pour redemander.

| Export serveur | Retour |
|---|---|
| `getSeason()` | `printemps`, `ete`, `automne`, `hiver`, ou `nil` avant le démarrage — lu par `vava_farming` et `vava_gathering` |
| `getCalendar()` | `{ season, label, name, day, year, yearText, text, length }` — `yearText` et `text` écrits par la config ; `length` : jours d'une saison en mode cycle (1.1.0) |
| `getClock()` | `{ hour, minute, seconds, frozen, shift }` |
| `getFrost()` | `{ tonight, warned, struck, warnHour, hour }` — la nuit du jour (1.1.0) |
| `getWeather()` | `{ id, label, forced, frozen }` |
| `webState()` | `true, vue` ou `false, code` — pont de la Chancellerie seulement |
| `webClock(action, minutes)` · `webWeather(action, ciel?, figer?)` | `true, vue, libellé du journal (nil : rien n'a changé), détails` ou `false, code` — pont seulement, mêmes règles que les RPC (droit vérifié par le pont auprès du Registre) |

La vue : `{ clock = { seconds, real, shift, frozen }, calendar = { season, label, name, day, year, yearText, text,
length }, frost = { tonight, warned, struck, warnHour, hour }, weather = { id, label, from, fromLabel, fading, forced,
frozen, endsIn, inSeason }, weathers = { { id, label, inSeason } }, limits }`.

| Export client | Retour |
|---|---|
| `getClock()` | `{ hour, minute, frozen }`, ou `nil` avant la première réponse du serveur |
| `getSeason()` · `getWeather()` | identifiant, ou `nil` |

**Hooks** (serveur, `after`) : `vava_time:seasonChanged` (`{ season, previous, day, year }`), `vava_time:dayChanged`
(`{ season, day, year }`), `vava_time:weatherChanged` (`{ weather, previous, forced, frozen, by }`),
`vava_time:clockChanged` (`{ shift, frozen, by }`) ; `by` : `cycle`, `council` ou `web` ; `vava_time:frostWarning` (au
soir d'une nuit de gel) et `vava_time:frost` (le gel tombe) : `{ season, day, year, warnHour, hour }` (1.1.0).

Un module lit la saison par son `bridge/server.lua` (appel isolé, saison gardée quelques secondes), s'abonne aux hooks
du gel s'il en a l'usage, et garde ses réglages par saison dans sa propre config : `vava_time` absent ou arrêté = aucun
effet. Rendu hors jeu de l'outil : `web/index.html` (`?frozen=1`, `?forced=1`, `?struck=1`, `?refused=1`).

### `vava_cameras`

L'écran des joueurs, pour le Conseil : tout membre (droit `watch` de vava_admin, sans règle de rang) regarde tout le
monde, en jeu (**mur des caméras** : page Outils du Registre — Gardien compris depuis vava_admin 1.7.0, qui l'ouvre
avec le seul droit `watch` — ou `/cameras`) ou depuis la Chancellerie (par son pont).
Demande le core 0.5.0 ; facultatifs : `vava_admin` ≥ 1.2.0 (droit, journal, outil du Registre ; sans lui, personne ne
regarde en jeu), `vava_chancellerie` ≥ 1.1.0 (caméras depuis le web). Qualités, limites, adresse STUN : `config.lua`.

- **Capture** : à l'ordre du serveur seulement, le jeu du joueur filmé relie une texture WebGL à l'image du jeu
  (séquence de screenshot-basic : ni Windows, ni Discord, ni les interfaces du jeu) et la dessine hors de l'écran,
  au rythme de la capture (960 × 540, 20 images/s). **Une seule capture**, partagée par tous ceux qui regardent ; chacun
  a sa connexion WebRTC et sa qualité : `tile` (case d'un mur : 480 × 270, 10 images/s, 250 kbit/s au plus) ou `full` (vue en
  grand : 960 × 540, 20 images/s, 1,2 Mbit/s au plus). Personne ne regarde : ni dessin ni capture.
- **Réseau** : l'image va **directement** du jeu du joueur au spectateur (jeu d'un membre ou navigateur) ; le serveur
  ne relaie que la négociation (une offre et une réponse de quelques Ko par caméra ; l'offre part au membre en jeu en
  envoi latent, 32 000 octets par seconde, 1.3.0). Adresse STUN publique de Google par défaut (aucun coût pour le
  serveur ; elle voit passer l'adresse IP des joueurs à la connexion).
- **Débit montant du joueur filmé** (1.3.0) : borné pour tous ses spectateurs ensemble, jeu et web (`budget.uplinkKbps`,
  1 500 kbit/s), avec **une seule vue en grand** à la fois. Admission par le serveur, après la limite de spectateurs :
  une seconde vue en grand, ou des planchers (`qualities.*.minKbps` : case 120, vue en grand 600) dont la somme
  dépasserait le budget → refus `budget` (`vava_cameras:watch` comme `webStart`). Répartition (règle pure
  `shared/budget.lua`) : plancher pour chacun, puis le reste à la vue en grand jusqu'à son plafond (1 200), enfin aux
  cases à parts égales jusqu'au leur (250). La part d'une caméra nouvelle part avec son ordre de capture ; les parts
  changées des autres partent au seul joueur filmé (évènement `vava_cameras:rates`, `{ rates = { { session, kbps } } }`),
  qui les applique par `setParameters`, sans nouvelle offre. Le mur et la Chancellerie retentent une caméra refusée
  `budget` (« Débit du joueur déjà pris, nouvel essai bientôt »). Détail et tableau : README du module.
- **Mur en jeu** : grille 1 × 1 à 4 × 4 (touches 1 à 4), pages (flèches), un clic ouvre en grand (flèches : joueur
  précédent ou suivant ; Échap : retour, puis fermeture). Seules les cases de la page affichée ont une caméra, ouvertes
  une à une (150 ms d'écart : un mur 4 × 4 reste sous la limite de messages du core) ; en grand, seule la vue en grand
  reste. Liste des joueurs relue toutes les 5 s, mur ouvert seulement ; caméra perdue retentée après 10 s.
- **Limites** : 6 caméras par joueur filmé, 96 en tout, 2 h au plus ; sans réponse du spectateur en 30 s, la caméra
  s'éteint. Elle s'éteint aussi quand le joueur filmé n'est plus en jeu (sélection, départ) ou que son spectateur ferme
  le mur, revient à la sélection, part, ou perd le droit de regarder (rang donné ou retiré, relu au hook
  `vava_admin:action` ; son mur affiche « Droit refusé »). Depuis le web, à chaque rang donné ou retiré, le pont
  demande à la Chancellerie de revérifier chaque compte qui regarde, avec son rang actuel : sans le droit (ou compte
  supprimé), ses caméras s'éteignent (« Droit refusé » dans le navigateur, capture arrêtée en jeu). Un rang changé
  dans le panneau (compte relié ou non) fait la même revérification.
- **Journal** du Conseil : l'ouverture du mur et chaque vue en grand. Les cases d'un mur sont couvertes par
  l'ouverture, que le serveur exige (1.2.0) : il tient pour chaque membre en jeu un état « mur ouvert », posé par
  `vava_cameras:wall` et levé par `vava_cameras:leave`, le retour à la sélection, le départ ou le droit retiré, caduc
  après `wall.maxOpenMs` (2 h : il faut rouvrir le mur, nouvelle ligne au journal) ; sans lui,
  `vava_cameras:watch(joueur, 'tile')` répond `wall_closed`. Au premier refus, le mur cesse de demander des cases et
  chacune affiche « Mur à rouvrir », sans nouvel essai, jusqu'à sa réouverture.
  Depuis le web, voir `vava_chancellerie` (case sans mur inscrite au journal). Le joueur n'est pas prévenu : à
  mentionner dans le règlement du serveur.
- **Sécurité** : chaque demande du membre est une RPC à schéma strict et à débit limité, droit revérifié à chaque
  caméra ; seul le joueur filmé envoie l'offre de sa caméra, **une seule fois** (`already_offered` ensuite, 1.2.0 : une
  renégociation passe par une nouvelle caméra), seul son spectateur y répond (une fois) ou la ferme.
  Identifiants de caméra tirés au hasard (24 chiffres hexadécimaux). Le WebRTC direct révèle l'adresse IP du joueur
  filmé au spectateur (et inversement) ; derrière certains pare-feux, la connexion directe échoue (aucun relais TURN).
  Avec le DLSS activé, l'image peut inclure les interfaces du jeu.

| Export serveur | Retour |
|---|---|
| `count()` | nombre de caméras ouvertes |
| `webPlayers()` | liste `{ source, label, active }` — pont de la Chancellerie seulement |
| `webCheck(joueur, qualité)` | `true` ou `false, code` : la caméra serait-elle accordée maintenant (rien n'est ouvert) — pont seulement, avant de faire inscrire une vue en grand au journal (1.3.0) |
| `webStart(joueur, qualité)` | `true, { session, label, iceServers }` ou `false, code` (dont `budget`, 1.3.0) — pont seulement (droit vérifié par le pont auprès du Registre) |
| `webAnswer(session, sdp)` · `webStop(session)` | `true` ou `false, code` — pont seulement |

Hook `vava_cameras:web` (serveur, `after` : `{ session, offer? , ended? }`) : offre et fin des caméras regardées
depuis le web, relayées par le pont à la Chancellerie.

Pour travailler le rendu du mur sans le jeu : `web/index.html?players=11&layout=3` (ou `&focus=<numéro>`,
`&budget=<numéro>`) dans un navigateur ; chaque case est une vraie connexion WebRTC locale filmant une scène dessinée.

### `vava_combat`

Les armes de corps à corps (1.0.0, T-111 ; squelette que T-112 complétera, `docs/plan/COMBAT_V1.md` § 2) : catalogue des
armes (fiches en config : catégorie parmi `une_main`, `deux_mains`, `dague`, `baton`, `bouclier` — liste fermée —,
famille, type de dégâts, dégâts, bonus de portée, solidité, blocage, modèle provisoire), six objets déclarés à
l'inventaire (Épée longue, Hache d'armes, Masse d'armes, Dague, Bâton ferré, Bouclier rond) et l'Épée courte de
`vava_crafting` adoptée sans être redéclarée, six recettes signées déclarées à `vava_crafting:recipes` et
`vava_skills:recipes` (redéclarées à leur annonce `core:module:ready`), dégâts = fiche × qualité de forge (0,85 à 1,15)
× usure (émoussée : × 0,5) × multiplicateur de la technique, usure d'un point par coup **qui touche** (chance de
l'épargner : 40 % × qualité), arme émoussée à 0 et réparée par l'artisanat, bouclier accroché au bras ou au dos, combat
natif de GTA coupé sans boucle par image, commandes du Conseil `/armes liste | voir | user` (droit `metiers`, journal).
Demande le core 0.10.0, `vava_inventory` 1.7.0 et `vava_health` 1.3.0 ; facultatifs : `vava_crafting` ≥ 1.5.0 et
`vava_skills` ≥ 1.0.0 (recettes), `vava_hud`, `vava_admin` (sans lui, ACE `combat.admin`), `vava_chat`. Ordre de
démarrage : après `vava_health` et `vava_crafting`. **Aucun RPC, aucune NUI, aucune table SQL.** Détail, valeurs et
tests en jeu : `modules/vava_combat/README.md`, `docs/tests/combat.md` § 2.

- **Arme en main** = l'objet tenu de l'inventaire (`held`, T-045), jamais une arme GTA ; le serveur lit
  `vava_inventory:held(src)`. Modèles vanilla provisoires dans `items[…].held` (`-- PLACEHOLDER`). Les outils ne sont pas
  des armes.
- **Métadonnées** : `vava_combat` n'écrit que `durability` (à la baisse) et, sur une pile qui n'en porte pas,
  `max_durability` (= fiche), par `patchMetadata` ; jamais `broken`, jamais `history`.
- **Bouclier** : « utiliser » l'accroche ou le décroche (`onUse` posé par le module, jamais consommé, 1 s entre deux
  gestes, refusé à terre) ; le serveur écrit `{ id, item }` sur le statebag de ped **`vava_combat:shield`** (≈ 30 o,
  répliqué par OneSync aux seuls joueurs qui ont ce ped à portée) et le **garde** (valeur réécrite par un client remise
  après 250 ms, espacée jusqu'à 1 s ; entité non suivie : effacée). Placement lu dans la config de chaque client, position
  (bras ou dos) déduite de `vava_inventory:inHand` du même ped : au bras avec une arme `une_main` ou `dague` ; montré à
120 m au plus (`shield.showRadius`). Une même pile ne s'accroche qu'à un porteur. Décroché
  dès que la pile quitte la besace (hooks `move`, `drop`, `remove` ; relevé de 5 s en filet) ; champ privé
  `vava_combat:hungShield` (retrouvé à la reconnexion).
- **Combat natif** : drapeau de ped 122 (corps à corps désactivé), `SetPedCanSwitchWeapon(false)`, armes GTA retirées,
  réappliqués à 1 Hz côté client ; rendus à GTA à l'arrêt du module. Le filet reste l'annulation serveur de
  `vava_health`.
- **Réseau** : `vava_combat:notify` (`core.net.send`) au seul porteur dont l'arme passe un seuil (quart de la solidité,
  émoussée) ou au seul membre du Conseil sans `vava_chat` ; le statebag du bouclier au changement seulement ; + ≈ 450 o
  une fois dans `GlobalState['vava_inventory:heldModels']` (mécanisme de l'inventaire). Aucun envoi à tous.

| Export serveur | Retour |
|---|---|
| `weapon(item)` | copie de la fiche `{ item, label, category, family, kind, damage, reachBonus, durability, block, provisional }`, ou `nil` |
| `weapons()` | liste ordonnée (catégorie, puis libellé) des fiches — pour l'éditeur des techniques (T-121) |
| `armed(src)` | `{ instanceId, item, category, family, kind, damage, factor, amount, reachBonus, quality, durability, maxDurability, dull }` (`amount` : coup à × 1,0) ou `nil, code` (`not_ready`, `no_character`, `no_weapon`) |
| `shield(src)` | `{ instanceId, item, block, durability, maxDurability, dull, position, ready }` (`ready` : bouclier au bras) ou `nil` — rien d'accroché, inventaire muet, ou pile partie de la besace (décrochée aussitôt) ; lu par T-113 |
| `strike(src, cible, opts?)` | résultat de `vava_health:hit` complété de `weapon = { item, durability, maxDurability, worn, dull }`, ou `nil, code` |

**`strike`** : brique serveur d'un coup d'arme, réservée aux ressources de `config.strike.callers` (`GetInvokingResource` ;
sinon `not_allowed`, une ligne de console par minute et par ressource) ; T-112 appelle la fonction interne
`VavaCombat.strike.run`. Vérifie dans l'ordre : module prêt (`not_ready`), joueurs entiers et différents
(`invalid_target`), personnages actifs (`no_character`), attaquant debout (`downed`), `opts` = `nil` ou table aux seules
clés `technique` (identifiant de 64 octets, `^[A-Za-z0-9_%-%.:]+$`), `damage` (multiplicateur 0,1 à 3, défaut 1), `tags`
(map → `true` de `parryable`, `unblockable`, `undodgeable`, 3 au plus ; `melee` toujours posé), `part`
(`invalid_options`) ; pile **réellement tenue**, arme du catalogue connue de l'inventaire avec un `held`, pas un bouclier
(`no_weapon`) ; même instance (routing bucket) et positions lues par le serveur à 6 m au plus (`too_far`). Puis paquet `{ amount, kind, source, weapon,
technique?, part?, tags }` → `vava_health:hit` (refus rendu tel quel, sans usure ; `health_unavailable` s'il ne répond
pas), puis usure si le coup a touché (résultat sans `cancelled`, ou annulé aux étapes `parade`, `blocage`, `bouclier`),
calculée sur la pile **relue** après le coup (un abonné de la chaîne qui céderait la main ne fait ni user deux fois au
même point ni frapper gratuitement) ; pile partie ou inventaire muet : aucune usure.

| Export client | Retour |
|---|---|
| `armed()` | `{ item, category, family }` de l'arme du personnage local (champ `vava_inventory:hands`), ou `nil` — pour la règle « mains vides » de la magie et le mode combat ; jamais une décision |
| `shieldHung()` | objet du bouclier accroché sur son propre ped, ou `nil` |

**Hooks** : `vava_combat:shieldHang` (`before`, annulable, accroche seule : `{ source, characterId, instanceId, item }` ;
la raison du refus est montrée au joueur — prison, interdiction ; `after` : `+ hang, reason` = `use` | `gone` |
`restored`), `vava_combat:dulled` (`after` : `{ source, characterId, instanceId, item }`, une arme vient d'atteindre 0).

### `vava_magic`

La magie (2.10.0) : fiche magie par personnage (champ privé `vava_magic:sheet` : mage ou non, sorts et leur XP, sort
prêt dans les mains, combinaisons découvertes, sigils gardés, sigil unique dans tout le royaume), mana (100, +3 toutes
les 5 s, jamais sauvegardée) et sa barre, 5 niveaux par sort, incantation commune avec délai global (1 s), roue des
sorts (Tab) et mode magie à la souris (clic droit viser, clic gauche lancer, clic molette verrouiller), états
élémentaires (brûlure, mouillé, ralenti, chancelant, renversé, gelé ; immunité de 6 s aux contrôles durs), zones au sol
tenues par le serveur (flammes, brume, sol mouillé, présage), obstacles (rempart), sorts de feu (**Boule de feu**, **Mur
de flammes**, **Nova ardente**), d'eau (**Trait de glace**, **Vague**, **Brume**) et de terre (**Projectile de roche**,
**Secousse**, **Rempart**), combinaisons entre éléments décidées par le serveur d'après `config.combos` (vapeur,
dissipation, boue, gel, séchage, extinction, roche ardente ; inscrites au grimoire à la première découverte,
`discoveredCombos` de la fiche), **Lueur** et **Murmure**, grimoire et registre (objets), traces au sol, sons fabriqués
par l'interface ou remplacés par des fichiers `.ogg` et des sons natifs (`config.sounds`), commandes du Conseil (`/magie`, numéro de joueur facultatif). Tout le détail, la config et la liste des tests en jeu :
`modules/vava_magic/README.md`. Demande le core 0.5.0 ; facultatifs : `vava_inventory` ≥ 1.3.0 (objets), `vava_hud`
(notifications), `vava_health` ≥ 1.3.0, 1.4.0 conseillé (blessures par la chaîne de dégâts — sans lui, aucun sort ne blesse
personne —, à terre : un joueur à terre ne subit plus aucun effet des sorts — ni Mouillé, ni recul, ni Renversé, ni
Ralenti), `vava_admin` (droit `tools` et journal ; sans lui, ACE `magie.admin` ;
≥ 1.6.0 : la fin d'un Gel ne libère pas un joueur immobilisé par le Registre), `vava_combat` ≥ 1.0.0 (mains vides pour
incanter ; sans lui, aucune restriction).

- **Bridge** : `bridge/server.lua` et `bridge/client.lua` sont les seuls fichiers qui appellent le core et les autres
  modules ; les réécrire suffit pour un autre core (avec un équivalent de `core.rpc`).
- **Mains vides** (2.10.0, T-140) : le serveur refuse le début d'une incantation (après les recharges), la brise dès
  qu'une arme ou un bouclier passe en main (hook `vava_inventory:hold` after) et la revérifie à sa fin, quand une arme
  de GTA est sortie (`GetSelectedPedWeapon` sur le ped, OneSync), que `exports.vava_combat:armed(source)` rend une arme
  (code `armed`) ou que `shield(source).ready` dit un bouclier au bras (code `shielded`) ; un bouclier dans le dos ne
  gêne pas. Brisée : ni mana ni recharge. vava_combat absent, pas prêt ou en erreur : aucune restriction pour les armes
  de l'inventaire (une ligne de console par minute au plus, aussi quand `not_ready` dure). Le client lit `armed()` pour
  le montrer tôt (mode magie endormi, roue, touches, incantation interrompue), sans en décider.
- **Incantation** : RPC `vava_magic:begin:<sort>` puis `vava_magic:finish:<sort>` (numéro d'incantation). Le serveur
  revérifie à la fin la durée, le déplacement (positions serveur) et la blessure (2.9.0 : un coup de la chaîne ou une
  perte native qui a retiré de la vie au lanceur, hook `vava_health:hit` after, ou sa vie de `vava_health:get` plus
  basse qu'au début ; jamais la vie du ped) ; la mana est réservée avant l'effet, rendue
  si le sort refuse. Recharges tenues par personnage. Effets vus des autres : state bags posés par le serveur sur le
  ped (`vava_magic:casting`, `glow`, `light`, `conditions`) ou sur l'objet d'un orbe ancré (`vava_magic:orb`) ;
  évènements ciblés aux seuls joueurs proches (`vava_magic:projectile`, `projectileEnd`, `zone`, `zoneEnd`, `burst`) ;
  `vava_magic:combo` (nom) au seul lanceur d'une combinaison réussie.
- **Murmure** : fragments envoyés aux seuls joueurs à moins de 3 m ; registre des murmures en base sous le numéro porté
  par l'objet (métadonnée `registre`), l'historique suit l'objet. Il s'envoie par lots au seul lecteur (2.7.0) :
  `vava_magic:openRegister` `{ id, pages, more, count, max }` à l'ouverture (pages les plus récentes, 20 et 7 500 octets
  estimés au plus, `config.registers`), puis RPC `vava_magic:registerPages` `(registre, avant)` → `true, { pages, more }`
  pour le lot qui précède la page `avant` (curseur : la plus ancienne reçue), refusé `no_register` si le joueur ne porte
  plus ce registre (revérifié à chaque lot). Sigils : après un refus, le donneur attend
  `sigils.refusedMs` (60 s) avant de retendre son sigil au même joueur (`vava_magic:sigilOffer` répond alors
  `false, 'offer_refused', secondes`). Boue : Ralenti reposé au plus toutes les 2 s
  (`combos.boue.result.slow.refreshMs`), chaque pose couvrant l'intervalle ; 1 à 3 s encore à la sortie.
- **Projectiles** (Boule de feu, Trait de glace, Projectile de roche, même noyau) : impact signalé par le client du
  lanceur (RPC `vava_magic:projectileImpact`), validé par le serveur (portée, axe, délai, cible réelle, zones protégées,
  rempart sur le trajet) avant les dégâts (en points de vie sur `combat.healthPoints`) ; bonus d'XP au toucher si le
  coup a blessé et que le lancer a rapporté.
- **Blessures** (2.9.0, T-116) : chaque blessure d'un sort est un coup de la chaîne de dégâts (`exports.vava_health:hit`,
  § `vava_health`) : `amount` = points du sort (une vie pleine au plus, mêmes dégâts qu'avant), `kind` = type de son
  élément (`combat.kinds` : `feu`, `eau`, `terre`, `lumiere`, `esprit` ; brûlure : `feu`), `source` = le lanceur (même
  parti ; s'il joue un autre personnage, le coup est refusé), `sourceCharacter`, `spell` (ou la combinaison, `vapeur`),
  `tags` : `spell` et `ranged` (impact), `area` (éclats, nova, secousse), `area` + `overTime` (mur de flammes, vapeur),
  `overTime` (brûlure) ; `launched` et `launchedAt` (instant du lancement, horloge du serveur) pour un impact, des éclats
  ou une secousse, si `vava_health` ≥ 1.4.0. Les sorts respectent donc `chain.pvp`, le débit par paire et le lanceur à
  terre (`source_downed`, sauf `overTime` et un sort lancé debout dont le lanceur tombe avant l'impact, 4 s au plus) ;
  `chain.pvp = false` (lu dans `vocabulary()`) coupe aussi poussées, gel et Ralenti ; réaction, brûlure, états qui
  suivent un coup et bonus d'XP seulement si `applied > 0`. Plus aucun
  appel à `damage`, plus d'évènement `vava_magic:damage` au client : sans `vava_health`, les sorts ne blessent personne
  (le lanceur le lit au plus une fois par minute). Journal : `vava_health_hits` (`origin = vava_magic`) ;
  `vava_magic_damage_log` n'est plus écrit, purgé des lignes de plus de `combat.log.retentionDays` jours (30).
- **Modificateurs** (registre `vava_health:modifiers`, redéclarés à chaque démarrage de `vava_health`) :
  `vava_magic:zones` (étape `annulation`, seulement si `combat.protectedZones` en compte : personne n'est blessé dans une
  zone de paix, ni par un sort ni par une lame, et personne n'en blesse un autre depuis l'intérieur ; annulé
  `zone_protegee` ; la faim, si), `vava_magic:protections` (étape
  `bouclier` : boucliers du joueur touché, le plus proche de sa fin d'abord, jusqu'à leur réserve ; sorts et lames, pas
  la faim), `vava_magic:resistances` (étape `resistance` : la plus forte résistance et la plus forte faiblesse au type
  du coup, jamais cumulées). Protections en mémoire du serveur (4 boucliers de 200 points et 4 résistances par joueur,
  10 min au plus, `protections`), posées pour l'essai par `/magie proteger` (sur un rang plus bas que le sien au
  Conseil ; soi-même et les faiblesses : `staff`) ; aucun des onze sorts n'en pose encore. Chaque modificateur est
  déclaré avec ses `kinds` : ni la faim, ni la soif, ni les pertes natives ne les appellent.
- **Rempart** : blocs de pierre créés par le serveur (objets réseau figés), jamais sur un joueur ni un véhicule,
  retirés à leur fin, à l'arrêt du module et par `/magie nettoyer`.
- **Verrouillage** (sorts `lockOn`) : clic molette côté client (lu par `Bridge.GetLockedTarget`), à la portée du sort
  prêt dans les mains (celle que le serveur juge) ; la cible part avec le début de l'incantation, revérifiée
  par le serveur, qui prévient la seule cible (évènement `vava_magic:targeted`, une fois l'incantation acceptée — mana,
  recharges, contrôles —, au plus une fois toutes les 3 s par lanceur et par cible, `targeting.warnIntervalMs`) et
  calcule lui-même la direction ;
  virage vers la cible aux niveaux 4 et 5 (`homing`, pris en compte dans le contrôle d'axe de l'impact).

| Export serveur | Retour |
|---|---|
| `isMage(source)` | booléen — personnage en jeu |
| `spellLevel(source, sort)` | niveau (1 à 5) d'un sort connu, ou `nil` |
| `mana(source)` | mana actuelle, maximum (0 pour un non-mage) |

**Hooks** : `vava_magic:castStarting` (`before`, annulable : `{ source, characterId, spell, level }` — prison, zone…),
`vava_magic:castDone` (`after` : `+ success`), `vava_magic:levelUp` (`after` : `{ source, characterId, spell, level }`),
`vava_magic:mageChanged` (`after` : `{ source, characterId, isMage }`), `vava_magic:stateApplying` (`before`, annulable :
`{ source, state, durationMs, caster?, spell? }` — résistance, objet protecteur…), `vava_magic:murmur:unreachable` (`before` :
`{ source, characterId, reason = offline|too_far, sigil, text }` — renvoyer `false, 'handled'` pour prendre le message en
charge : pigeon voyageur, relais…).

**Ajouter un sort depuis un autre module** : registre du core `vava_magic:spells`, clé = nom du sort. Sa config
demande `element` (feu, eau, terre, lumiere, esprit), `type` (projectile, zone, utilitaire), `icon` et `aim.kind`
(projectile, point, self, none).

```lua
core.registry.add('vava_magic:spells', 'echo', {
    config = { label = 'Écho', element = 'esprit', type = 'utilitaire', icon = 'echo', aim = { kind = 'none' },
        baseCost = 5, xp = 5, levels = { -- 5 niveaux
        { castMs = 1500, cooldownMs = 10000, description = '…', unlock = '…' }, --[[ … ]]
    } },
    beginArgs = {},                                    -- schémas des arguments du début (RPC à schéma strict)
    finishArgs = {},                                   -- schémas des arguments de la fin
    begin = function(ctx) return true, {} end,         -- ctx = { source, characterId, spell, level, origin, cost }
    finish = function(ctx) return { success = true } end, -- { success, refund? (part de mana rendue), result? }
})
```

Le noyau ouvre ses RPC (`vava_magic:begin:echo`, `vava_magic:finish:echo`), tient la mana, la recharge, l'XP et les
contrôles de l'incantation. Côté client, le module externe appelle lui-même ces deux RPC et gère sa barre et son
animation (`VavaMagic.casting.start` n'existe qu'à l'intérieur de vava_magic).

Pour travailler le rendu sans le jeu : `web/index.html?view=grimoire` (ou `wheel`, `wheelfire`, `wheelwater`,
`wheelearth`, `hud`, `aim`, `states`, `frost`, `mist`, `hits`, `combo`, `combos`, `composer`, `offer`, `naming`,
`confirm`, `lueur`, `sealed`, `register`, `registerlong`, `messages`, `broken`) dans un navigateur, servi en HTTP (les
icônes sont des masques CSS, refusés depuis `file://`).

### `vava_skills`

Les compétences du royaume (1.1.3), fondation des métiers : treize compétences de 0 à 100 (Récolte : Bûcheronnage,
Minage, Herboristerie, Pêche, Chasse · Terre : Agriculture · Transformation : Forge, Menuiserie, Tissage et couture,
Tannerie, Alchimie, Cuisine · Savoir : Arcanes) et six rangs (Novice, Apprenti 20, Compagnon 40, Artisan 60, Maître 80,
Grand Maître 95). Tout est en `config.lua` ; le détail des règles et la liste des tests en jeu sont dans
`modules/vava_skills/README.md`. Demande le core 0.6.0 (temps de jeu) et `vava_inventory` 1.4.0 ; facultatifs :
`vava_hud` (notifications), `vava_admin` (droits `metiers` et `staff`, journal du Conseil), `vava_chat` (réponses des
commandes).

- **Progression** : les modules métiers **ne calculent jamais l'XP** ; ils appellent `addXp` avec un contexte
  (compétence, action, difficulté, XP de base) et le serveur applique tout : mode de la compétence, rendements
  décroissants quand la difficulté est très inférieure au niveau, pénurie, bonus de mentorat, savoir commun (20 premiers
  points libres par compétence), budget (200 points au-delà, toutes compétences confondues, à augmenter et jamais
  baisser), rouille.
- **Rouille** (↑ = ↓) : chaque compétence est marquée par le joueur `up` (progresse), `keep` (verrouillée : ni gain ni
  perte) ou `down` (peut s'effacer, ne gagne pas). Au plafond, un point gagné en `up` retire un point à la compétence
  `down` la plus haute au-dessus du savoir commun (`rust.pick` : `highest`, `recent`, `random`) ; sans compétence `down`,
  l'XP se fige sous le seuil, rien n'est perdu.
- **Pénurie** : compétence où moins de 2 personnages actifs (joués depuis 14 jours) atteignent Compagnon → XP × 1,5 ;
  aucune pénurie tant que le royaume compte moins de 10 personnages actifs (`shortages.minActivePlayers`) ; recomptée
  toutes les 30 min, affichée dans le livre et exposée pour un panneau en jeu.
- **Mentorat** : un Maître (rang et 10 h de jeu) propose à un joueur proche (comptes différents, 3 apprentis au plus
  par compétence, un maître par apprenti et par compétence), qui accepte dans la minute. L'apprenti gagne +50 % quand il
  pratique à moins de 20 m de son maître qui a lui-même pratiqué la compétence depuis moins de 10 min ; le maître en
  tire de la **Renommée** (10 % de l'XP bonifiée, 100 par jour UTC et par compétence, divisée par deux tous les 200 points
  déjà rapportés par le même apprenti). Chacun peut rompre.
- **Arcanes** (et toute compétence `mentoredOnly`) : aucune progression sans **son mentor** dans cette compétence à
  moins de 30 m.
- **Savoirs** : une recette libre se connaît par le niveau ; une recette `transmission` s'apprend par trois leçons (celui
  qui la connaît la réalise à moins de 10 m de l'élève, qui a le niveau requis ; une heure au moins entre deux), en
  réunissant ses fragments (savoirs perdus), ou de la main d'un fondateur. Chaque apprentissage garde son professeur :
  la **lignée** se remonte jusqu'au fondateur.
- **Livre des compétences** (touche `K`, réglable) : compétences et modes, budget, mentorat (propositions, maîtres,
  apprentis, proposer à un joueur proche), savoirs et lignées, métiers en pénurie. Pour travailler le rendu sans le jeu :
  `web/index.html?tab=competences` (ou `mentorat`, `savoirs`, `penurie`).
- **Journal** `vava_skills_log` (180 jours) : leçons, mentorats, fondateurs, corrections, rouille, savoirs appris,
  Arcanes refusées.

**Registres** (définis par ce module ; schéma validé par le core) :

```lua
-- une compétence de plus (un module tiers) : catégorie parmi celles de la config
core.registry.add('vava_skills:skills', 'joaillerie', { label = 'Joaillerie', category = 'transformation', order = 20 })
-- une recette (vava_crafting, ou tout module qui enseigne un savoir)
core.registry.add('vava_skills:recipes', 'epee_courte', {
    label = 'Épée courte', skill = 'forge', level = 30,
    transmission = true,                          -- ne s'apprend que par leçon, fragments ou fondateur
    fragments = { 'page_une', 'page_deux' },      -- optionnel : fragments (objets) qui la reconstituent
})
```

**Exports serveur** (cible : un joueur, son personnage actif ; `false/nil, code` sinon) :

| Export | Retour |
|---|---|
| `addXp(source, { skill, source?, difficulty?, amount? })` | `true, { gained, level, rank, leveledUp, blocked? }` — `blocked` : `locked`, `no_master`, `cap`, `max` ; `false, code` : `unknown_skill`, `invalid_amount` (0 à `xp.maxPerAction`), `invalid_difficulty`, refus d'un hook |
| `getLevel(source, skill)` | niveau, nom du rang |
| `hasRank(source, skill, rang)` | booléen |
| `getSkill(source, skill)` | `{ id, label, category, level, xp, xpToNext, rank, mode, renown, practicedAt, shortage?, mentoredOnly, canMentor, mentor?, apprentices }` |
| `getSkills(source)` | liste des vues, puis `{ used, total }` (budget) |
| `knowsRecipe(source, recette)` | booléen |
| `recordLesson(professeur, élève, recette)` | `true, { count, required, learned }` ou `false, code` (`not_transmitted`, `teacher_unknown`, `too_young`, `same_account`, `student_level`, `too_far`, `too_soon`, `already_known`) — à appeler quand le professeur a réalisé la recette |
| `addFragment(source, recette, fragment)` | `true, { found, total, learned }` ou `false, code` |
| `grantRecipe(source, recette)` | `true` ou `false, code` — recette transmise donnée au nom du module appelant (journalisée) |
| `getMentor(source, skill)` | `{ mentorshipId, characterId, name, since, online }` ou `nil` |
| `getApprentices(source, skill)` | liste de la même forme |
| `isMentoredNow(source, skill)` | booléen — le joueur pratique sous le bonus de son maître en ce moment |
| `getRenown(source, skill)` | entier |
| `getLineage(source, recette)` | `{ recipe, label, chain = { { characterId, name, learnedAt, source } } }` du joueur au fondateur |
| `getShortages()` | `{ { skill, label, count, multiplier } }` |
| `shortageMultiplier(skill)` | nombre (1 sans pénurie) |

**Hooks** : `vava_skills:xp` (`before`, annulable : `{ source, characterId, skill, action, difficulty, amount }` — zone,
état, objet… ; `after` : `+ gained, level, leveledUp, blocked?`), `vava_skills:levelChanged` (`after` : `{ source,
characterId, skill, from, to, rank, reason = xp | rust | admin_set | founder }`), `vava_skills:mentorship` (`after` :
`{ action = started | ended, mentorshipId, skill, masterId, apprenticeId, endedBy? }`), `vava_skills:recipeLearned`
(`after` : `{ characterId, recipe, skill, source, taughtBy? }`).

**Commandes** : `vava_fondateur <joueur> <compétence> <niveau> [recette ...]` (console, ou droit `staff`) nomme un
fondateur ; `/metiers niveau <joueur> <compétence> <niveau>`, `/metiers recette <joueur> <recette>`, `/metiers voir
<joueur>` (droit `metiers` ; sans vava_admin, ACE `metiers.admin`). Cibles : joueurs connectés avec un personnage en jeu.

### `vava_gathering`

La récolte (1.6.0) : zones à **vitalité** 0–100 (plein rendement au-dessus de 60, réduit entre 60 et 25 avec chance
d'échec, **épuisée** sous 25 avec props remplacés et rendement effondré, **cicatrice** à 0 : régénération × 0,2 pendant
la durée de la zone), nœuds à charges (arbres, filons, buissons, bancs de poissons, pistes de gibier) qui se
régénèrent par le temps (recalcul à la demande, aucune boucle), outils **en main** (`vava_inventory:held`) du genre
requis, non brisés, usés par `patchMetadata` (brisés à 0), qualité de la récolte (niveau, outil, vitalité, aléa) en
palier 1–5 et provenance sur la pile (`{ tier, origin }`), pêche à la barre de tension, réaction de la terre aux
épuisements répétés, commandes du Conseil. L'XP passe par `vava_skills:addXp`. Tout le détail, la config et les tests en
jeu : `modules/vava_gathering/README.md`. Demande le core 0.11.0 (abonnements de zone, 1.6.0), `vava_inventory` 1.4.0 et
`vava_skills` 1.0.0 ; facultatifs : `vava_hud`, `vava_admin` (droit `metiers`), `vava_chat`, `vava_health` (à terre),
`vava_time` (saisons).

- **Données** en `config.lua` : zones (centre, rayon, coût, régénération, cicatrice), nœuds (position, ressource, charges,
  délai, props normal et épuisé — tous les nœuds ont un prop créé par le client), ressources (objet, compétence, outil,
  difficulté, XP, fourchette, durée, animation, pièce supplémentaire), outils, objets déclarés à l'inventaire. Les zones
  livrées sont des exemples.
- **État** (1.6.0) envoyé aux seuls joueurs proches par les abonnements de zone du core (§ `core.zones`) : une zone du
  core par zone de récolte (nom local = identifiant de la zone ; centre de la zone, rayon qui englobe ses nœuds au sol,
  marge `streaming.radius` + `streaming.subscribeSlack` = 100 m) ; état `zone` → `{ band, scarred }` et `n:<nœud>` →
  charges, changé au seul changement (une récolte : une différence, relue toutes les 10 s pour une zone qui se remet).
  La vitalité n'est jamais envoyée (export `getZone` et panneau `vava_gathering:zones` pour la lire). Plus aucune clé
  GlobalState (les anciennes `vava_gathering:zone:<id>` et `vava_gathering:node:<id>` sont effacées une fois au
  démarrage). État public (rien de secret) : chaque action revérifie la distance côté serveur. Identifiants : zone
  48 octets au plus, nœud 46.
- **Serveur maître** : distance lue côté serveur au début et à la fin, durée revérifiée, jeton par geste, cooldown,
  une récolte à la fois. Pêche (1.4.0, décision du 30 octobre 2026 : le serveur tire la réussite) : le booléen « a
  tenu la tension » de `vava_gathering:reel` ne peut que faire rater (`false` : code `escaped`) ; à `true`, le serveur
  tire la prise d'après le seul niveau de Pêche (`fishing.catch`, règle pure `shared/catch.lua` :
  25 % de poissons décrochés au niveau 0, 2 % au niveau 100 ; supplément de bande `catch.bands` à 0 depuis la
  décision du 30 octobre 2026 ; code
  `escaped`, rien de consommé), puis l'échec de la bande comme pour toute récolte (zones de `waterKinds` : textes de
  l'eau pour l'échec, l'épuisement et l'invite). À terre (`vava_health:isDowned`,
  lu par le bridge), ni début ni fin (code `downed`) ; côté client, ni invite ni demande.
- **Saisons** (1.3.0) : la saison de `vava_time` (export `getSeason`, lu par le bridge, gardée 5 s) donne deux facteurs
  par compétence de la ressource, réglés dans `config.seasons` : `regen` (vitesse à laquelle les nœuds rendent leurs
  charges ; 0 : rien ne repousse et le temps ne s'accumule pas ; au changement de facteur, l'avance prise sur la
  prochaine charge est gardée et recomptée au nouveau rythme, nœud réécrit — 1.3.1) et `yield` (unités récoltées, au
  moins une). Par défaut : herbes lentes et maigres en hiver, gibier abondant à l'automne, poissons au printemps,
  minage sans saison. `vava_time` absent, arrêté ou en échec : facteur 1. Facteurs contrôlés par `shared/season.lua`
  (fini, ramené dans [0, 10], sinon 1 ; 1.3.2). Saison en attente pendant le démarrage de `vava_time` (1.3.2) : facteur
  `false`, jamais gardé en cache ; aucun nœud ne repousse ni ne déplace sa date, le rendement compte pour 1.

**Registre** `vava_gathering:tools` (objet → `{ kind, power, yieldBonus?, qualityBonus?, wear? }`) : rempli par la
config, ouvert aux autres modules (une hache d'artisan de phase 3 s'y déclare, ou hérite du genre de son objet).

| Export serveur | Retour |
|---|---|
| `getZone(id)` | `{ id, label, kind, vitality, band, scarred, x, y, z, radius }` ou `nil, code` |
| `getZones()` | liste, dans l'ordre de la config |
| `setVitality(id, valeur)` | `true` ou `false, code` — 0 à 100, lève la cicatrice si > 0 ; journalisé au nom du module |
| `nodeState(id)` | `{ id, zone, resource, charges, max }` |
| `getResource(id)` · `getTool(objet)` | définitions, ou `nil` |
| `getSession(joueur)` | `{ token, node, resource, kind, startedAt, durationMs }` ou `nil` |

**Hooks** : `vava_gathering:harvesting` (`before`, annulable : `{ source, characterId, node, zone, resource, item }` —
terre sacrée, nuit, état…), `harvested` (`after` : `+ quantity, tier, band, extra?`), `zoneDepleted` (`after` :
`{ zone, vitality }`), `zoneScarred` (`{ zone, scarredUntil, depletions }`), `earthReaction` (`{ zone, depletions }`).

**Commande** `/recolte zones | zone <id> | noeud <id> | vitalite <zone> <0-100> | recharger <noeud>` (droit `metiers`).
Touches : `E` récolter, `O` panneau des zones (« Marquer » y pose le repère de la carte sur une zone). Carte : un blip
nommé par zone et le cercle de son rayon, posés par le client depuis la config (`map`). Rendu hors jeu :
`web/index.html?view=prompt` (ou `tension`, `zones`).

### `vava_crafting`

L'artisanat (1.5.0) : **stations** (forge, établi, métier à tisser, alambic, tannerie, fourneau, table d'arcanes)
publiques ou privées, avec leur qualité et parfois leur combustible (forge : charbon ; fourneau : bois ; réserve
alimentée par les joueurs), une pièce à la fois ; **recettes** à ingrédients par **palier choisi** (consommés par pile,
les plus anciennes d'abord, échange atomique), outil requis en main, durée, XP par `vava_skills` ; **qualité** =
matériaux × 0,5 + niveau × 0,4 + station × 0,1 ± 5, plafonnée par le niveau, palier dérivé ; **objets signés**
(`quality`, `tier`, `durability` = `max_durability`, `crafter_id`, `crafter_name` figé, `mark`, `crafted_at`,
`history` création + 5 dernières) ou produits simples (`tier`) ; **poinçon** (glyphe parmi la config, dès Compagnon,
champ `vava_crafting:mark`) ; **baptême** d'un chef-d'œuvre pendant 5 min ; **réparation** (25 % des ingrédients,
solidité rendue, maximale − 5, histoire, jamais le créateur) ; **leçons** aux élèves à 10 m quand une recette
transmise est réalisée (`vava_skills:recordLesson`). Une pièce ou une réparation commencée occupe la station jusqu'à
sa fin, son annulation, ou au plus 2 min (ou sa durée + 30 s si c'est plus long, `interact.expireMarginMs`) ; finie
trop loin ou à terre, elle est abandonnée (rien n'est consommé) et la station libérée aussitôt. À terre
(`vava_health:isDowned`, lu par le bridge) : ni menu, ni pièce, ni réparation, ni combustible (code `downed`). Détail,
config et tests : `modules/vava_crafting/README.md`.
Demande le core 0.11.0 (abonnements de zone, depuis 1.5.0), `vava_inventory` 1.4.0, `vava_skills` 1.0.0,
`vava_gathering` 1.0.0 ; facultatifs : `vava_hud`, `vava_admin` (droit `metiers`), `vava_chat`, `vava_health` (à terre).

**Registres** : `vava_crafting:stations` (types : `{ label, skills, fuel?, anim, prop }`) et `vava_crafting:recipes`
(`{ label, skill, level, station, tool?, durationMs, difficulty, xp, signed?, signedIfQuality?, durability?,
transmission?, fragments?, ingredients = { { item, quantity, minTier? } }, output = { item, quantity } }`), remplis par
la config, ouverts aux autres modules ; chaque recette est aussi déclarée à `vava_skills:recipes`. Les armes de
`vava_combat` (Épée longue, Hache d'armes, Masse d'armes, Dague, Bâton ferré, Bouclier rond) y sont ajoutées par ce module,
signées, solidité tirée de sa fiche ; l'Épée courte reste une recette de l'artisanat (§ `vava_combat`).

**Stations chez les joueurs** (depuis 1.5.0) : chaque station placée est une zone du core (`core.zones`, nom = son
identifiant, cercle de 2 m, marge de 100 m : `streaming.zoneRadius`, `streaming.radius` + `streaming.subscribeSlack`) ;
état `def` → `{ type, label, x, y, z, heading, prop }` (dessin, ni qualité ni propriétaire) et `s` → `{ fuel, busy }`,
reçus des seuls joueurs proches, puis en différences. Plus aucune clé GlobalState (les anciennes
`vava_crafting:station:<id>` et `vava_crafting:stations` sont effacées une fois au démarrage) ni d'évènement
`vava_crafting:station` (le menu ouvert suit la zone). L'état est public : chaque action revérifie distance, accès et
occupation côté serveur. Un son ou un effet de station vise `core.zones.subscribers(id)` ou `core.net.sendNear`.

| Export serveur | Retour |
|---|---|
| `getStation(id)` · `getStations()` | `{ id, label, type, typeLabel, quality, busy, x, y, z, fuel?, owner? }` |
| `setFuel(id, n)` | `true` ou `false, code` — journalisé au nom du module |
| `addStation({ id, type, label?, x, y, z, heading?, quality?, owner?, prop? })` | `true` ou `false, code` — place une station d'un type déjà déclaré au registre (un module pose son composteur…) ; les joueurs proches la reçoivent par sa zone du core au passage suivant (1 s), sans reconnexion ; hook `vava_crafting:stationAdded` ; depuis 1.1.0. Depuis 1.5.0 : `invalid_id` au-delà de 32 octets, `invalid_position` (position non finie), `invalid_label` (nom qui n'est pas une chaîne de 1 à 128 octets), `invalid_prop` (modèle qui n'est pas une chaîne de 1 à 64 octets), `zones_full` (le core refuse sa zone : trop de zones ; la station n'est pas placée), `zone_refused` (autre refus du core) |
| `registerAccess(kind, fn)` | branche un genre de propriétaire de station : `fn(ownerId, characterId)` → booléen (foyer, guilde…) |
| `getRecipe(id)` · `recipesOf(type)` | définitions |
| `getSession(joueur)` | `{ token, kind = craft \| repair, station, recipe, startedAt, durationMs }` ou `nil` |
| `getMark(personnage)` | glyphe ou `nil` |

**Hooks** : `vava_crafting:crafting` (`before`, annulable : `{ source, characterId, station, recipe, item }`),
`crafted` (`after` : `+ quantity, quality, tier, signed, instanceId`), `repaired` (`after` : `{ source, characterId,
station, recipe, item, instanceId, maxDurability }`).

**Signature protégée** (depuis 1.3.0) : abonné `before` à `vava_inventory:metadata`, l'artisanat refuse l'écriture
d'un autre module (`setMetadata`, `patchMetadata`) qui changerait, poserait ou retirerait `crafter_id`,
`crafter_name`, `crafted_at`, `mark` ou `quality` sur n'importe quel objet (`false, 'signature_locked'`) ; sur un objet
signé (`crafter_id` présent), qui changerait `tier` ou poserait, changerait ou retirerait `name` (le baptême seul
nomme une pièce) (`signature_locked`), ferait monter, retirerait ou remplacerait par autre chose qu'un nombre
`max_durability` ou `durability`, retirerait `broken`, ou donnerait à un objet signé qui n'en avait pas une solidité
négative, non numérique, au-dessus du plafond (`config.guard.bornDurability`, 100, ou la solidité de sa recette si
elle est plus haute) ou une courante au-dessus de sa maximale (`false, 'durability_locked'`). Une solidité qui baisse
(usure, dommage) ou qui naît dans ces bornes, `history`, `lines` et toute autre clé restent libres ; un objet ordinaire
n'est touché que s'il recevait une de ces cinq clés (signature contrefaite). Un `setMetadata` sur un objet signé doit
donc reporter ces clés telles quelles. Sont seules admises les écritures que l'inventaire attribue à `vava_crafting`
(`owner`) et qui partent de son bridge (réparation, baptême). Un refus est toujours rendu au module ; il est journalisé
(`vava_crafting_log`, nature `signature_locked` ou `durability_locked`) et signalé en console une fois par fenêtre de
60 s pour un même module, objet et clé (`config.guard.windowMs`, au plus `maxTracked` = 500 refus suivis ; les refus
tus sont comptés et annoncés avec le suivant, depuis 1.3.1). La garde tombe avec le module ; un objet **créé** déjà
signé (`add`, `exchange`) n'est pas de son ressort.

**Commande** `/artisanat stations | station <id> | carburant <id> <n>` (droit `metiers`). Touche `E` près d'une
station. Rendu hors jeu : `web/index.html?view=menu` (ou `menu&tab=reparation`, `menu&tab=poincon`, `name`).

### `vava_farming`

L'agriculture (1.7.0) : **parcelles** communales ou privées (`owner = { kind = 'character', id }`, autres genres par
`registerAccess`) faites d'emplacements en grille ; **croissance par dates** (humidité qui baisse, pousse au-dessus
d'un seuil, pause à sec, flétrie après 6 h, morte après 18 h ; aucune boucle, republication des stades toutes les
10 s) ; **fertilité** (coût par récolte, rotation par famille, compost, jachère) ; **qualité** de la récolte (graine ×
0,35 + compétence × 0,35 + régularité d'arrosage × 0,15 + fertilité × 0,15 ± 5) en palier avec provenance, graines
récupérées au même palier ; gestes semer / arroser (seau en main rempli aux puits) / fertiliser / récolter (faucille :
plus vite) / couvrir (contre le gel, 1.4.0) / arracher (déchets), tous validés et appliqués par le serveur après un geste chronométré (fini trop loin
ou à terre, le geste est abandonné ; à terre, `vava_health:isDowned` lu par le bridge : ni menu, ni geste, ni puits,
ni grenier, code `downed` ; un emplacement qui vient de donner ou de consommer des objets — semis, récolte, compost,
couverture, arrachage — est écrit aussitôt, le reste par lots ; récolte et arrachage vident l'emplacement avant tout
ajout à la besace, qui peut céder la main : de deux cultivateurs sur la même plante, un seul est servi ; une récolte
refusée par la besace rend la plante (couverture payée comprise), sauf semis fait entre-temps, sans effacer un compost
posé entre-temps, et un gel tombé pendant l'attente la frappe ; parcelle republiée aussitôt — 1.5.1) ; **grenier
commun** (conteneur `vava_inventory` conservé, ouvert ancré à qui a accès à la parcelle — communale : tous ; privée :
son propriétaire ou le genre branché par `registerAccess` —, dépôts et retraits journalés par minute : une ligne par
minute, grenier, personnage, objet et sens, quantités additionnées, attente bornée par `persistence.granaryLogMax` ;
migration 0002 : colonne `minute` et clé unique, les lignes d'avant restent une par geste ; hook `granary` toujours
par geste) ; **composteur** (type de
station et recette ajoutés aux registres de `vava_crafting`, station placée par `addStation`). Détail, config et tests :
`modules/vava_farming/README.md`. Demande le core 0.11.0 (abonnements de zone, 1.7.0), `vava_inventory` 1.4.0, `vava_skills` 1.0.0, `vava_gathering`
1.0.0, `vava_crafting` 1.1.0 ; facultatifs : `vava_hud`, `vava_admin` (droit `metiers`), `vava_chat`, `vava_health`
(à terre), `vava_time` (saisons, nuits de gel).

**Saisons** (1.3.0) : la saison de `vava_time` (export `getSeason`, lu par le bridge, gardée 5 s) règle, par
`config.seasons`, la vitesse de pousse (`growth` : printemps × 1,25, été × 1, automne × 0,75, hiver × 0,25) et celle à
laquelle la terre sèche (`drying` : × 1 ; × 1,5 ; × 0,75 ; × 0,25 : l'hiver, un arrosage tient quatre fois plus). Une
valeur absente, négative, infinie ou invalide compte pour 1, et une valeur au-delà de 10 compte pour 10 (1.4.1, même
règle que la récolte). La croissance garde ses fractions de seconde en mémoire et s'écrit entière en base. `vava_time`
absent, arrêté ou en échec : aucun effet, croissance identique à la 1.2.2. **Saison en attente** (1.4.1) : tant que
`vava_time` démarre (module déclaré, en attente, en migration ou en `setup`, `getSeason` encore `nil`), le bridge rend
`false`, jamais gardé en cache, et rien n'avance (`growth.advance` ne touche ni la pousse, ni l'humidité, ni la date de
calcul) : le temps est compté ensuite, à la bonne saison. Quand les effets de saison changent, chaque emplacement planté
est marqué à écrire, pour qu'un redémarrage ne recompte pas d'un bloc tout le temps passé depuis son dernier geste.

**Gel** (1.4.0 ; règles décidées le 30 octobre 2026, 1.5.0) : branchée par le bridge sur les hooks `vava_time:frostWarning` et
`vava_time:frost`, l'agriculture avertit au soir d'une nuit de gel les seuls cultivateurs concernés (propriétaire en jeu
d'une parcelle privée où une plante est exposée, joueurs à `frost.warnRadius` m d'une parcelle commune exposée,
positions lues côté serveur) puis, quand le gel tombe, fait mourir toute plante vivante ni couverte ni d'une culture
`frostHardy` (état « morte » existant), journalise (une ligne `frost` par nuit : plantes perdues par parcelle, 1.4.1)
et prévient les mêmes. Geste **Couvrir**
(action `cover` de `vava_farming:begin`, codes `off_season` (1.5.0), `covered`, `frost_hardy`, `no_cover`) : en
saison de `frost.coverSeasons` seulement (automne et hiver ; saison revérifiée au début et à la fin du geste ; sans
`vava_time`, jamais), plante vivante, non couverte, d'une culture qui craint le froid ; consomme le premier objet de
`frost.cover` que le cultivateur possède en quantité — 2 déchets végétaux, sinon 1 compost (1.5.0) — (revérifié et
retiré par `exchange` à la fin du geste) ; l'emplacement reste couvert jusqu'à la récolte ou l'arrachage (colonne
`covered`, migration 0003, écrite aussitôt ; journal `covered`). Sans `vava_time`, rien ne gèle. Réponse du menu d'un
emplacement (RPC `vava_farming:open`) : `cover = { season, options, use }` (`season` faux : « Couvrir » n'est pas
proposé, `options` vide) et `frost = { tonight }` (1.5.0 : nuit de gel annoncée par `getFrost` de `vava_time`, lue pour
un emplacement planté), `rules.frostTonight` (texte de la fiche, `messages.frostTonight`).

**Registre** `vava_farming:crops` (`{ label, family, seed, product, growMinutes, waterPerHour, fertilityCost, yield,
xp, difficulty, stages, wilted, dead, frostHardy? }` ; `stages` : modèles par stade, le dernier réservé à la plante
mûre ; `frostHardy` : résiste au gel, 1.4.0), rempli par la config, ouvert aux autres modules.

**Parcelles vues des joueurs** (1.7.0, T-016) : chaque parcelle est une zone du core (`core.zones`, identifiant local
= id de la parcelle ; centre de la parcelle, rayon qui couvre ses emplacements et son grenier, marge
`streaming.radius` + `streaming.subscribeSlack` = 100 m). État : `def` → `{ label, x, y, z, heading, rows, cols,
spacing, granary? = { label, x, y, z, heading, prop } }` (ce qu'il faut pour placer les props, ni propriétaire ni
contenu du grenier) et `s<n°>` → `{ crop, stage, state }` (chaînes vides : emplacement libre). Un joueur qui arrive
reçoit l'état entier (environ 600 o pour le champ communal) ; ensuite, seuls les emplacements dont la culture, le stade
ou l'état change partent aux abonnés (environ 40 o par emplacement), regroupés par parcelle et par tour (une nuit de gel
ou un passage de croissance : un envoi par parcelle touchée). Plus de state bag global : l'ancien
`vava_farming:parcel:<id>` est effacé au démarrage s'il traîne encore. Une parcelle créée, déplacée ou changée en jeu
(Atelier, T-103) passe par `server/zones.lua` (`share` : déclarée, ou déplacée et état remplacé ; `drop` : retirée) et
arrive chez les joueurs proches sans reconnexion. Comme toute zone, l'état est public : chaque geste (menu, début et fin
de geste, puits, grenier) revérifie la distance côté serveur.

| Export serveur | Retour |
|---|---|
| `getParcel(id)` · `getParcels()` | `{ id, label, x, y, z, count, communal, owner?, granary?, slots = { vue… } }` |
| `getSlot(parcelle, n)` | `{ parcel, index, crop, cropLabel, state, stage, stages, progress, moisture, fertility, waterings, dryHours, plantedAt, covered, frostHardy }` |
| `getCrop(id)` | définition ou `nil` |
| `granaryOf(parcelle)` | id du conteneur du grenier, ou `nil` |
| `registerAccess(kind, fn)` | genre de propriétaire de parcelle : `fn(ownerId, characterId)` → booléen |
| `getSession(joueur)` | `{ token, parcel, slot, action, startedAt, durationMs }` ou `nil` |

**Hooks** : `vava_farming:acting` (`before`, annulable : `{ source, characterId, parcel, slot, action, crop? }`),
`harvested` (`after` : `+ item, quantity, quality, tier, seeds`), `granary` (`after` : `{ parcel, action = deposit |
withdraw, source, characterId, item, quantity }`).

**Commande** `/agriculture parcelles | parcelle <id> | fertilite <id> <n> <0-100> | pousser <id> <n> | arroser <id>`
(droit `metiers`). Touche `E` près d'un emplacement, d'un puits ou d'un grenier. Rendu hors jeu :
`web/index.html?view=menu&state=growing` (ou `empty`, `ripe`, `wilted`, `dead`, `view=prompt` ; `&covered=1` : plante
couverte ; `&frost=1` : gel annoncé ; `&season=ete` : « Couvrir » non proposé ; `&besace=compost` ou `vide`).

### `vava_provisions`

Les vivres du royaume (1.0.0, T-130) : objets `eau` (Outre d'eau) et `outre` (Outre vide), points d'eau (puits,
fontaines, sources) où l'on remplit ses outres et où l'on boit, outre rendue vide qui se fend parfois, outres faites à la
tannerie. Ordre de démarrage : après `vava_farming`, avant `vava_codex` et `vava_arrival`. Demande le core 0.11.0
(`core.zones`, `core.net`, registre `core:commands`), `vava_ui` et `vava_inventory` 1.8.0 ; facultatifs : `vava_needs`
(boire au point d'eau), `vava_crafting` et `vava_skills` (recette de l'outre, avant ou après), `vava_health` (rien à
terre), `vava_hud`, `vava_admin` (droit `metiers`, journal du Registre), `vava_chat` (réponses de `/eau`). Aucune table
SQL. Détail et réglages : `modules/vava_provisions/README.md`.

- **Objets** déclarés s'ils manquent (le premier déclaré l'emporte, avertissement en console) : `eau` garde la
  définition de `vava_arrival` 1.0.0 (1 × 2, pile de 5, 700 g, soif + 40, `boisson`), seule l'image
  (`nui://vava_provisions/web/items/eau.svg`) et la description changent ; `outre` (1 × 2, pile de 5, 150 g, `divers`).
  Redéclarés à l'annonce de `vava_inventory` (les piles gardées à part reviennent). Recette `outre` (Tannerie, 1 cuir →
  2 outres) ajoutée aux registres `vava_crafting:recipes` et `vava_skills:recipes` si la station `tannerie` est
  déclarée, à l'annonce de `vava_crafting` ou de `vava_skills` au besoin.
- **Points d'eau** : une zone du core par point (identifiant local = identifiant du point, cercle de 2 m, marge 100 m),
  état `{ def = { kind, label, x, y, z, heading?, model? } }` (~130 o, une fois à l'arrivée ; `heading` absent s'il
  vaut 0, `model` absent s'il est celui de la sorte, que le client lit dans sa config) ; **la réserve n'est jamais
  publiée**. Réserve en mémoire par point des sortes qui en ont une (puits 40, + 1 par minute ; source 15, + 1 toutes
  les 3 min ; fontaine sans fond), pleine à chaque démarrage. `rules.validatePoint` est le seul juge d'un point ;
  `points.put` et `points.drop` sont prêts pour l'éditeur de l'Atelier.
- **Outre rendue** : hook `vava_inventory:use` (after) ; seulement si `consumed`, pour un objet de `containers` ; dans
  un thread, pour le même personnage : `add(outre, 1)`, sauf une fois sur dix (`tearChance`) où elle se fend ; sans
  place, elle est abandonnée. Avis au seul buveur.

| RPC | `args` | `rateLimit` | Réponse |
|---|---|---|---|
| `vava_provisions:draw` | `{ { type = 'string', min = 1, max = 32, pattern = '^[a-z0-9_]+$' } }` (identifiant du point) | `{ capacity = 3, refillPerSecond = 0.5 }` | `true, { action = 'fill', count }` ; `true, { action = 'drink', dry, blocked? }` (`blocked` : `no_space` ou `too_heavy`, remplissage refusé par la besace, le joueur assoiffé a bu sur place) ; `false, code` (`no_character`, `downed`, `unknown_point`, `too_far`, `wait`, `busy`, `not_thirsty`, `no_container`, `no_space`, `too_heavy`, `unavailable`) ; `false, 'dry', secondes` ; `false, 'refused', raison` (texte d'un hook, 200 octets au plus) |

Le client ne dit ni ce qu'il veut faire, ni ce qu'il porte, ni sa soif : le serveur revérifie personnage, une demande à
la fois, délai (3 s), à terre, point connu, distance réelle du ped (3,5 m, 3D), outres vides possédées, soif, réserve,
puis choisit ; après le hook `drawing`, personnage et distance sont relus. Remplir : au plus 5 outres, puisages
réservés **avant** l'échange tout ou rien, rendus s'il échoue (besace pleine ou trop lourde et soif : gorgées sur place).
Boire : soif + 20, refusé dès 95.

| Évènement serveur → client | Valeurs | Cible |
|---|---|---|
| `vava_provisions:notice` | `torn` ou `lost` | le seul joueur qui vient de boire une outre d'eau fendue ou sans place (`core.net.send`) |
| `vava_provisions:notify` | texte | le seul membre du Conseil qui a tapé `/eau`, quand `vava_chat` manque (sinon son chat) |

| Export serveur | Retour |
|---|---|
| `getPoints()` | liste `{ id, kind, label, x, y, z, reserve? = { level, capacity } }` dans l'ordre de la config ; `nil, 'not_ready'` |
| `getPoint(id)` | une entrée de la même forme, ou `nil, 'unknown_point'` |
| `pointNear(source, radius?)` | `id, distance` du point le plus proche à au plus `radius` (défaut 3,5 m, au plus 10) de la position du ped lue côté serveur, ou `nil` ; `nil, 'invalid_target'` hors joueur |
| `codexList(name)` | `points` → `{ { value = id, label } }` triés par nom |

**Hooks émis** : `vava_provisions:drawing` (`before`, annulable : `{ source, characterId, point, kind, action = fill |
drink, count }`, `count` 0 pour boire ; la raison d'un refus est montrée au joueur) et `vava_provisions:drawn` (`after` :
le même payload, plus `reserve`, entier après le geste, absent pour une sorte sans fond). Aucun export client.

**Conseil** : `/eau points | reserve <point> <nombre>` (droit `metiers`, repli ACE `metiers.admin`, console permise,
1 s entre deux commandes d'un membre ; chapitre « Vivres » du Codex). `points` : lignes regroupées en messages de
480 octets au plus, 60 points au plus. `reserve` va au journal du Registre (« Réserve d'eau fixée », point, réserve et
ancienne réserve `before`). Touche `E` près d'un point d'eau (« Puiser ou boire »). Rendu hors jeu de l'invite :
`web/index.html?label=Puits%20du%20lavoir&verb=Puiser&key=E`.

### `vava_codex`

Le Codex : toutes les commandes et toutes les touches du serveur, lues dans le registre `core:commands` (voir
« Registre des commandes »). Ordre de démarrage : après les modules (il lit le registre à chaque ouverture, l'ordre
n'est donc pas critique), avant `vava_chancellerie`. Dépend du core ≥ 0.7.0 ; vava_admin (rangs et droits), vava_hud
(notifications) et vava_chat (dernières pages des commandes tapées) sont facultatifs.

**Touche `F1`** (réglable par le joueur) ou `/codex` : un livre ouvert. Page de gauche : recherche (focus à
l'ouverture, filtrage local sans aller-retour, accents et casse ignorés), index par sections — **Signets**,
**Dernières pages**, puis les chapitres (un par module, onglets colorés sur la tranche), et pour le Conseil **Non
décrites** (commandes des ressources vAvA enregistrées auprès du jeu mais absentes du registre, lançables en texte
libre). Page de droite : détail de la ligne choisie, **formulaire selon le type de chaque argument** (joueur en jeu,
clé d'un registre, liste d'un module, choix fixe, nombre, texte), **ligne composée en direct**, « Lancer ». Onglet
**Touches** : toutes les touches par chapitre, avec la touche réellement liée par le joueur (lue dans le jeu).
Clavier : `↑ ↓` parcourir, `Entrée` choisir puis lancer, `Tab` champ suivant, `Échap` retour puis fermer. Un
argument nombre (`integer`, `number`) n'a **aucune valeur d'office** (1.1.2) : obligatoire, il manque tant que le
joueur ne l'a pas choisi (curseur déplacé ou valeur tapée) ; la valeur tapée part bornée par `min` et `max`, arrondie
au `step` (compté depuis `min`) et à l'entier pour un `integer`. Si la ressource s'arrête livre ouvert, souris et
clavier sont rendus au jeu.

**Ce que chacun voit** est décidé par le serveur : public → tous ; Conseil → le droit vava_admin déclaré avec la
commande (ou tout membre du Conseil si aucun), repli ACE sans vava_admin (`ace` de la commande, sinon
`config.staff.ace`) ; console → les membres du Conseil, en lecture seule. Une sous-commande peut porter son propre
droit. Le Codex ne donne aucun pouvoir : la ligne est lancée par `ExecuteCommand` chez le joueur, comme si elle
était tapée, et chaque commande garde ses propres contrôles.

**Contenu gardé par la page** (1.2.0) : à chaque ouverture, le serveur recalcule ce que le joueur peut voir avec ses
droits du moment, puis en prend l'**empreinte** (FNV-1a 64 bits d'un codage canonique, `shared/fingerprint.lua`) ;
le client envoie les empreintes du contenu et des préférences que sa page garde, et le serveur ne renvoie que ce qui
a changé. Une seconde ouverture sans changement coûte 56 octets au lieu de 7 à 17 Ko (mesurés avec les déclarations
du dépôt, joueur et Souverain). Tout ce qui change le contenu change l'empreinte : module démarré ou arrêté, rang
donné ou retiré, droit d'un rang, ACE, commande non décrite apparue. Les touches du joueur sont relues par le client à
chaque ouverture, sans le serveur.

**Préférences par personnage** (champ `vava_codex:prefs`, lu du seul serveur depuis 1.2.0 : le client les reçoit à
l'ouverture, et seulement si elles ont changé) : signets (`favorites.max`),
dernières pages (`recent.max`, sans doublon, les plus récentes en tête — depuis le Codex, et depuis le chat via
l'export client `noteCommand(line)`), réglage « rester ouvert après Lancer » (`keepOpenDefault`). Un maximum abaissé
dans la config tronque les listes déjà enregistrées (premiers signets, dernières pages les plus récentes) à la
lecture, et la prochaine écriture garde la version courte : rien n'est bloqué (1.1.2). Une commande
déclarée `ui = true` (ouvre une interface) ferme toujours le Codex d'abord ; sinon le Codex reprend le focus si
aucune autre interface ne l'a pris.

RPC : `vava_codex:open(version, versionPréférences)` (empreintes gardées, 16 chiffres hexadécimaux au plus, `''` :
aucune ; rend `{ version, prefsVersion, content?, prefs? }`), `options(nom, sous-commande, rang)` (valeurs d'un argument dynamique : joueurs en jeu avec
leur nom, clés d'un registre par `labelField`, export `codexList` du module déclarant), `favorite(nom, posé)`,
`recent(nom, sous-commande)`, `keepOpen(bool)`, `page(id)` (1.5.0, texte d'une page de lecture, voir plus bas) —
schémas stricts, débits dans `config.rateLimits`. Une sous-commande
à droit propre est refusée (`refused`) à qui n'a pas ce droit, pour ses valeurs (`options`) comme pour les dernières
pages ; `recent` ne retient que le nom et une sous-commande déclarée, jamais le reste de la ligne tapée.

**Arguments « joueur »** (dont `/mp`) : le Conseil reçoit tous les joueurs en jeu ; les autres, les seuls joueurs à
portée de voix (lui compris) — positions lues par le serveur, même instance (routing bucket), rayon
`config.players.nearbyRadius` (5 m par défaut : la portée « Parler » de vava_voice, recopiée sans en dépendre). Taper
un numéro à la main reste possible.

| Export | Retour |
|---|---|
| serveur `suggestions(source)` | `{ { name, help, params = { { name, help } } } }` : les suggestions du chat pour ce joueur (ses commandes, une par sous-commande en deux mots, sans les touches ni la console) ; `vava_chat` l'appelle avec le profil |
| client `noteCommand(ligne)` | — : une commande tapée ailleurs (chat) est inscrite aux dernières pages ; le serveur ignore ce que le joueur ne peut pas lancer |
| client `openAt(chapitre)` | `true` (ouverture lancée, même chemin que `F1`) ou `false, code` : `invalid_chapter` (pas un identifiant du core de 64 octets au plus), `no_character`, `busy` (livre ouvert, menu pause, autre interface au focus) — 1.4.0 ; la page résout l'identifiant dans cet ordre (1.5.0) : page de lecture (onglet Lecture, cette page), chapitre de lecture (onglet Lecture, première page du chapitre), chapitre de commandes (onglet Commandes) ; inconnu : le livre reste à son index, sans message |

**Ouvrir à un chapitre** (1.4.0) : le chapitre part dans le message `open` de la page (`focus`, 64 octets au plus,
absent pour `F1` et `/codex`) ; rien de plus sur le réseau. Un chapitre de commandes porte le nom du module qui les
déclare (`openAt('vava_inventory')`) ; depuis 1.5.0, un identifiant de page ou de chapitre de lecture est résolu
d'abord (les ids de lecture ne commencent jamais par `vava`, aucune collision). `openAt('premiers_pas')`, appelé par
`vava_arrival` à la première venue, ouvre l'onglet Lecture au chapitre « Premiers pas », page « Vivre à Eldoria »
(`bienvenue`). Hors jeu : `?focus=<identifiant>`.

**Pages de lecture** (1.5.0, T-023) : un onglet « Lecture » (premier des trois onglets ; `F1` ouvre toujours le livre
sur Commandes) porte des chapitres et des pages écrits dans `content/*.lua` du module, chargés comme
`server_scripts` : jamais téléchargés par les clients (une page du Conseil ne part qu'aux membres). Au setup, chaque
page est analysée et validée (`shared/pages.lua`, pur, testé) ; une page fautive est écrite en console avec son code et
sa ligne et écartée seule. `config.reading.enabled = false` : ni onglet, ni index, RPC `page` refusé (`disabled`).

- **Chapitre** `{ id, label, order }` ; **page** (table plate, le `data` de l'Atelier demain) `{ id, chapter, order,
  title, summary, audience, permission, requires, body }` : `id` au motif `^[a-z][a-z0-9_]*$`, 32 octets au plus, jamais
  `vava…`, unique parmi pages et chapitres ; `order` entier de 0 à 999 ; `title` 48 octets, `summary` 120, `label` 32,
  UTF-8, sans contrôle ni `<` `>` ; `audience` `'player'` (tous) ou `'admin'` (Conseil) ; `permission` `''` ou un droit
  `vava_admin` (seulement avec `admin` ; une page à droit est cachée tant que `vava_admin` n'est pas démarré, sans
  repli ACE) ; `requires` `''` ou une ressource : la page n'est montrée que si elle est démarrée. 8 chapitres et 40 pages au plus ; un chapitre sans page visible n'apparaît pas.
- **Corps** (texte balisé léger, 6 000 octets au plus) : paragraphes séparés par une ligne vide ; `## Intertitre` ;
  `- élément` et `1. élément` (suite d'un élément : deux espaces en tête de ligne ; 12 éléments au plus) ; `> note` ;
  jetons `[[F1]]` (touche écrite telle quelle, 16 octets), `[[touche:nom]]` (touche **liée par le joueur** à l'entrée
  `nom` du registre `core:commands`), `[[commande:nom]]` ou `[[commande:nom action]]` (lien vers la ligne de l'onglet
  Commandes), `[[page:id]]` ou `[[page:id|libellé]]`, `*italique*` ; 40 blocs, 40 jetons ; paragraphe ou note 1 200
  octets, élément 400, intertitre 80. Refusés : `<` partout, `>` ailleurs qu'en tête de ligne, octets de contrôle
  (sauf le saut de ligne), UTF-8 invalide. Un lien vers une page absente, ou vers une page que tous les lecteurs de
  la page qui le porte ne peuvent pas lire (page du Conseil depuis une page publique, page à droit depuis une page qui
  n'a pas ce droit), fait refuser la page qui le porte. Codes d'erreur et leurs textes : `config.reading.errors`.
- **Blocs envoyés** (listes pures) : `{ 'h', texte }`, `{ 'p', segment… }`, `{ 'note', segment… }`, `{ 'ul', { segment… },
  … }`, `{ 'ol', … }` ; segment : chaîne, `{ 'kbd', touche }`, `{ 'key', nom }`, `{ 'cmd', nom, action|'' }`,
  `{ 'page', id, libellé|'' }`, `{ 'em', texte }`. La page les rend par éléments et `textContent`, jamais de HTML.
- **Index** dans le contenu de l'ouverture : `content.reading = { chapters = { { id, label } }, pages = { { id, chapter,
  title, summary, hash, staff? } } }` (absent si les pages sont fermées), calculé avec les droits du moment (module
  requis démarré ; page du Conseil : membre, et le droit de la page s'il y en a un), dans l'empreinte du contenu : il ne
  repart que s'il change. `staff = true` seulement sur une page du Conseil. `hash` : empreinte du titre et des blocs.
  Quand l'Atelier éditera les pages à chaud, l'index aura besoin de sa propre empreinte (aujourd'hui, une page
  changée renverrait tout le contenu du Codex à la prochaine ouverture).
- **Texte à la demande** : RPC `vava_codex:page(id)` (id au motif ci-dessus, `rateLimits.page` : 6 puis 1 par seconde) →
  `{ id, hash, body }` (chapitre et titre sont dans l'index ; 7 500 o au plus hors enveloppe du core, sous le seuil
  latent) ; `no_character`, `disabled`, ou
  `unknown_page` pour une page absente, refusée au chargement, réservée ou dont le module est arrêté (un seul code :
  rien ne trahit une page réservée). Les droits sont relus à chaque appel. La page garde le texte par empreinte.
- **Console** : `vava_codex_pages` (déclarée `scope = 'console'`) : une ligne par page (poids réseau, public), puis
  chaque touche ou commande citée absente du registre à cet instant.

Hors jeu : `web/index.html` dans un navigateur (`?staff=0` pour la vue d'un simple joueur) ; les listes des
formulaires y sont simulées.

### `vava_arrival`

L'arrivée d'un nouveau personnage (1.0.0, T-022 ; 1.1.0, T-130). Ordre de démarrage : après `vava_provisions` et
`vava_codex`, avant `vava_chancellerie`.
Demande le core 0.10.0 (`core.net`, `playSeconds` du hook `loaded`, registre `core:commands`) et `vava_inventory`
1.4.0 (`exchange`, registre des objets) ; facultatifs : `vava_codex` 1.4.0 (`openAt`), `vava_hud` (notifications),
`vava_admin` (droit `give`, journal du Registre), `vava_chat` (réponses de `/accueil`). Détail et réglages :
`modules/vava_arrival/README.md`.

- **Point d'arrivée** : `spawn.defaultPoint` du core (voir « Apparition », § `core.characters`) ; le module ne recopie
  aucune coordonnée.
- **Première venue** reconnue par le serveur seul, au hook `core:character:loaded` : aucune ligne dans `vava_arrival`
  **et** temps de jeu mesuré par le core nul → ligne « à donner ». Un personnage ancien (temps de jeu non nul) n'est
  jamais suivi. Aucune entrée réseau ne la demande : le client ne se déclare jamais nouveau.
- **Dotation** (`config.kit.items`, défaut 2 `pain` et 2 `eau` ; `pain` déclaré par le module s'il manque, `eau` par
  `vava_provisions` depuis 1.1.0), donnée à
  l'apparition par **un** `exchange(source, {}, objets)` : objets connus vérifiés, limite par compte (3 dotations sur
  30 jours glissants, personnages supprimés compris : au-delà, accueil sans dotation), **réservation conditionnelle en
  base** (`UPDATE … WHERE kit = 'due'`, une ligne touchée), personnage actif relu juste avant l'échange sans céder la
  main, état écrit ; échec (besace pleine, inventaire absent, personnage changé) → de nouveau « à donner », nouvel essai
  à l'apparition suivante, au retour de l'inventaire ou à l'annonce d'un module de `kit.providers` (`vava_provisions` :
  objet de la dotation inconnu tant qu'il n'a pas démarré, dotation reportée puis reprise, sans second accueil). Une ligne relue « réservée » (serveur tombé pendant la remise)
  passe « incertaine » et n'est **jamais** redonnée d'office (console, journal ; le Conseil vérifie et redote).
- **Accueil** : évènement `vava_arrival:welcome` (`kitGiven`, ~25 o) au **seul** nouveau venu par `core.net.send`, au
  plus 3 fois sans accusé (une fois par session) ; le client attend un écran calme (4 s, puis essais d'une seconde,
  30 s au plus), montre deux notifications du HUD, ouvre le Codex au chapitre `codex.chapter` (`premiers_pas`, `config_client.lua`) par
  `openAt`, puis accuse lecture. Rien n'est envoyé aux autres joueurs, rien aux personnages anciens ; aucun
  GlobalState, aucun state bag, aucune boucle client au repos.

| RPC | `args` | `rateLimit` | Réponse |
|---|---|---|---|
| `vava_arrival:welcomed` | `{}` | `{ capacity = 2, refillPerSecond = 0.05 }` | `true` ; `false, 'no_character'` ; `false, 'not_expected'` (aucun accueil envoyé à ce personnage pendant cette session, ou déjà accusé) ; `false, 'db_error'` |

| Évènement serveur → client | Valeurs | Cible |
|---|---|---|
| `vava_arrival:welcome` | `kitGiven` (booléen) | le seul joueur dont le personnage nouveau vient d'apparaître, ou celui visé par `/accueil rejouer` |
| `vava_arrival:notify` | texte | le seul membre du Conseil qui a tapé `/accueil`, quand `vava_chat` manque (sinon son chat) |

**Hook émis** `vava_arrival:arrived` (`after`) : `{ source, characterId, accountId, kit }` au **premier** accueil envoyé
à un nouveau personnage (`kit` : état après la dotation — `given`, `withheld`, `due` si elle a échoué, `uncertain`) ;
point d'appui des modules à venir (annonce aux proches, confrérie d'accueil). Aucun export.

**Conseil** : `/accueil etat | redoter | rejouer <n° de joueur>` (droit `give`, repli ACE `vava_arrival.admin`, console
permise, 2 s entre deux commandes d'un membre ; chapitre « Accueil » du Codex). `redoter` ignore l'état et la limite du
compte ; `rejouer` renvoie l'accueil (sans la ligne de la dotation). Chaque action va au journal du module
(`vava_arrival_log`, 90 jours) et au Registre du Conseil.

### `vava_atelier`

L'Atelier du Conseil (T-100, socle) : une interface unique où le Conseil crée et règle le royaume en jeu. Ordre de
démarrage : juste après `vava_admin` (l'ordre n'est pas critique : les modules redéclarent leurs éditeurs au hook
`vava_atelier:editorsReady`). Dépend du core ≥ 0.11.0 et de `vava_ui` ; `vava_admin` ≥ 1.8.0 est relu à chaque appel
(sans lui, refus `not_ready`), volontairement pas en `dependency` du manifeste (FiveM arrêterait l'Atelier avec le
Registre). Touche `F9` (réglable ; `keys.open` de `config_client.lua` depuis 1.2.0) et `/atelier`, déclarées au registre `core:commands` (droit `metiers`). Depuis 1.1.0
(T-101), un atelier dont le module déclare `apply` et `remove` est **gardé** : ses fiches vivent en base (une ligne par
version), avec brouillon, essai, publication groupée, retour en arrière, retrait, historique ; la config du module est
la graine, la base fait foi. Un atelier sans `apply` reste en lecture (comportement de 1.0.0). Le placement en jeu vient
avec T-102.

**Déclarer un éditeur** (registre `vava_atelier:editors`, 32 entrées au plus ; clé `<ressource>:<nom>` au motif
`^[%w_]+:[%w_]+$`, 64 octets ; une clé dont le préfixe n'est pas la ressource qui l'ajoute est retirée aussitôt). Un
module l'ajoute dans son `setup` si `core.registry.exists('vava_atelier:editors')`, **et** au hook
`vava_atelier:editorsReady`. Toutes les tables sont des listes pures ou des tables à clés nommées ; toute clé inconnue
est refusée, avec son chemin (« kinds[1].form.fields[3].max : doit dépasser min »).

```lua
core.registry.add('vava_atelier:editors', 'vava_gathering:zones', {
    family = 'monde',                -- monde | societe | arts (config.families)
    label = 'Récolte',               -- 1 à 32 octets
    description = 'Forêts, mines…',  -- 1 à 120
    icon = 'recolte',                -- recolte, agriculture, artisanat, porte, confrerie, logis, geste, combat, effet,
                                     -- sort, parchemin
    order = 10,                      -- facultatif, 0 à 999 : rang dans la famille, après les cartes de la config
    right = 'metiers',               -- metiers | staff ; le droit effectif peut être plus fort (plancher de la famille)
    texts = { trial = 'Tester la récolte', publish = 'Publier la zone', publishHint = '…' },  -- 32, 32, 120 (facultatif)
    kinds = {                        -- 1 à 8 types ; le premier est le principal (étiquette « 4 zones » de l'accueil)
        { id = 'zone', noun = 'zone', nounPlural = 'zones', article = 'la',   -- article : le | la | l'
          newLabel = 'Nouvelle zone', layout = 'side',                          -- page (cadre centré) | side (volet)
          creatable = true, steps = { 'La zone', 'Les points', 'Publier' },     -- facultatifs (0 à 4 étapes de 24)
          placement = 'circle', parent = nil,                                   -- T-102, acceptés et ignorés en T-100
          form = ZONE_FORM },
    },
    index = function(kind) end,              -- → { { id, title, hint? } } : entrées en vigueur
    read = function(kind, id) end,           -- → data (table plate) ou nil
    validate = function(kind, data, ctx) end,-- → true | false, 'texte' | false, { { field, text } } ; ctx { source, accountId, id? }
    options = function(source) end,          -- facultatif (obligatoire si un champ a une `source`) → { { value, label, provisional? } }
    compare = function(kind, data) end,      -- facultatif → { title, text } (« Pour comparer : … »)
    -- T-101 (atelier gardé) : voir « Définitions gardées » plus bas
    format = 1,                               -- facultatif, 1 à 65535 : format de `data`
    apply = function(kind, def, info) end,    -- avec remove → true | false, 'texte' (≤ 160), sans rien avoir changé
    remove = function(kind, id, info) end,    -- avec apply
    trial = function(kind, def, ctx) end,     -- facultatif, avec endTrial (et seulement avec apply)
    endTrial = function(kind, id, ctx) end,
    diff = function(kind, before, after) end, -- facultatif → texte ≤ 160 ou nil
    upgrade = function(kind, data, from) end, -- facultatif → data au format en vigueur, ou nil, 'texte'
    validateLot = function(lot, ctx) end,     -- facultatif, avec apply : le lot entier, une fois (comme validate)
})
```

**Formulaire** : `{ titleField, groups?, fields }` — `titleField` : un champ `text` sur une ligne, non facultatif
(nom de l'entrée) ; `groups` : 0 à 8 `{ id, label, help?, folded? }` ; `fields` : 1 à 40, dont 24 au plus en chaînes et
24 au plus en booléens. Chaque champ : `id` (`^[%a][%w_]*$`, 32, unique, jamais `id`, `place`, `version`, `status`,
`parent`), `widget`, `label` (1 à 40, **obligatoire**, mots du jeu), `help` (1 à 140, **obligatoire**), `group`, `width`
(`full` | `half`), `optional` (text, select, item, model), `default`.

| Widget | Clés et bornes | Valeur dans `data` |
|---|---|---|
| `slider` | `min` < `max` finis (\|v\| ≤ 1e9), `step` > 0, (max − min) / step entier et ≤ 2 000 ; `integer`, `unit` (8), `prefix` (4), `decimals` (0 à 3) | nombre sur un pas |
| `segmented` | `options` : 2 à 8 `{ value, label }` (`value` `^[%w_%-]+$` 32, `label` 24) | une `value` |
| `select` | soit `options` (1 à 64, `label` 40), soit `source` (liste rendue par `options(source)`) | une `value` |
| `toggle` | `default` booléen **obligatoire** | booléen |
| `text` | `charset` = `name` (lettres accentuées, chiffres, espace, `'`, `-`, `,`, `.`) \| `id` (`^[a-z0-9_]+$`) \| `free` (sans `<` ni `>`) ; `max` 1 à 80, ou 1 à 300 avec `multiline` (8 lignes) ; `min` | chaîne nettoyée (bords retirés) |
| `duration` | `min` ≥ 1, `max` ≤ 31 536 000 (secondes) ; `units` parmi `s`, `min`, `h`, `j` | secondes entières |
| `item` | `category` (filtre) | nom d'un objet de `vava_inventory:items`, ou `''` si facultatif |
| `model` | soit `choices` (1 à 32 `{ value, label, provisional? }`, `value` 64), soit `source` ; `free` (nom tapé à la main) | nom de modèle |

**Valeurs** : `data` est une table plate `{ [champ] = nombre | chaîne | booléen }`, exactement les champs du formulaire
(un champ facultatif vide vaut `''`) : ce que `read` rend, ce que `validate` reçoit, ce que T-101 stockera. Un module qui
garde ses données sous une autre forme (millisecondes, tables imbriquées) convertit lui-même dans `read` et `validate`.
Une valeur rendue par `read` hors bornes est remplacée par le défaut du champ et signalée à la page.

**« Vérifier »** (aucune écriture) : forme (clés, bornes, pas, choix, jeux de caractères, longueurs en caractères), puis
monde (objet existant et de la sorte demandée, valeur rendue par la source), puis `validate` du module, **seul juge**.
Toute fonction d'un module est appelée isolée (`pcall`) et chronométrée (alerte au-delà de 50 ms) : une erreur, une
réponse d'une autre forme ou un module arrêté donnent `editor_error`. Les listes `index` et les sources sont gardées
5 s.

**Droits** : un droit `vava_admin` par atelier, `metiers` ou `staff` ; droit effectif = surcharge de
`config.rights.overrides` si elle est permise, sinon le plus fort du droit déclaré et du plancher de la famille
(`monde` : `metiers` ; `societe`, `arts` : `staff`). Ouvrir l'Atelier demande `metiers`. Tout est relu auprès de
`vava_admin` à chaque appel.

**Plafond d'un descripteur** : la déclaration (sans ses fonctions ni son droit, défauts ajoutés) pèse au plus
`limits.descriptorBytes` (32 768 octets de codage canonique, celui de l'empreinte) ; au-delà, l'atelier est refusé au
chargement et retiré du registre, avec une ligne en console. Un plancher de famille, une surcharge ou `rights.open` hors
de `rights.allowed` : l'Atelier refuse de démarrer.

RPC (schémas stricts et bornés, débits dans `config.rateLimits`) : `home(version)` → `{ version, content?, tags,
drafts, journal, rank }` (ouvre la session), `editor(atelier, version)` → `{ version, descriptor? }`, `list(atelier,
type, page, filtre)`, `read(atelier, type, id)` → `{ id, title, values = { n?, s?, b? }, labels, warnings?, compare?,
state, footer }`, `check(atelier, type, id | '', values)` → `{ valid, errors? | compare? }`, `options(atelier, type,
champ, filtre, page)`, `search(texte)`, `journal(curseur, atelier | '')` → `{ lines, more, next }`, `close()`. Refus :
`not_ready`, `no_character`, `not_allowed`, `not_open`, `unknown_editor`, `unknown_kind`, `unknown_entry`,
`unknown_field`, `busy`, `editor_error`, `db_error`. Évènements (`core.net`, jamais à tous) : `vava_atelier:revoked` au
seul membre qui perd le droit d'ouvrir l'Atelier, `vava_atelier:editorGone` (identifiant) aux seuls membres dont la
session est sur l'atelier retiré.

Trois formes de réponse évitent d'envoyer deux fois la même chose :

- `home` : `content = { families, cards, footnote }` (carte `{ editor, family, label, description, icon, upcoming }`)
  ne porte que la partie stable et ne part que si son empreinte diffère de `version` (comme le Codex) ; les étiquettes
  des cartes partent **à chaque fois**, à part : `tags = { [atelier] = { text, tone? } }` (« 2 panneaux » ; `tone`
  absent vaut `count`, sinon `trial`, `draft`… ; ateliers visibles seulement, aucun pour une carte « Bientôt » ni pour
  un atelier qui ne répond pas).
- `read` : `labels = { [champ] = { label, image?, provisional? } }` nomme la valeur courante de chaque champ à liste
  distante (`select` ou `model` à `source`, `item`), tirée de la source gardée 5 s et des objets du royaume ; une
  valeur vide, inconnue ou dont la liste ne répond pas n'en a pas. La page n'appelle pas `options` pour ouvrir une
  fiche.
- `journal` : ligne `{ id, lead, title, summary?, actor, when, editor? }` ; `editor` est omis quand la demande est
  filtrée sur un atelier.

**Journal** (table `vava_atelier_journal`, 365 jours, recopié au journal du Registre) : actions `created`, `saved`,
`trial`, `published`, `archived`, `restored`, `removed`, `imported` (original rétabli), `placed`, `moved`, `note`.
Chaque ligne garde le droit effectif de l'atelier au moment de l'écriture : un membre ne lit que les lignes des droits
qu'il détient. La recopie au Registre et le hook `vava_atelier:journal` partent une fois la ligne écrite.

| Export | Retour |
|---|---|
| serveur `journal(source, { editor, kind, id?, action, title, summary?, version? })` | `true` (ligne acceptée, écrite ensuite ; sans numéro) ou `false, code` (`invalid_args`, `unknown_editor`, `not_owner`, `not_allowed`, `flood`) — atelier de la ressource appelante seulement ; `source` : membre qui a le droit effectif de l'atelier, ou `0` (console, sans recopie) ; `title` 1 à 64 octets, `summary` 160, `version` entier de 1 à 4 294 967 295 ; 60 lignes par 10 s et par ressource ; l'écriture en base ne fait pas attendre (numéro de la ligne dans le hook) |
| serveur `can(source, atelier)` | booléen : atelier déclaré et droit effectif détenu (pour les RPC propres d'un module) |
| serveur `isOpen(source)` | booléen : session ouverte |
| client `isOpen()` | booléen |

| Hook | Côté, phase | Payload |
|---|---|---|
| `vava_atelier:editorsReady` | serveur, after | `{}` — fin du démarrage : (re)déclarer ses éditeurs |
| `vava_atelier:session` | serveur, after | `{ source, accountId, open }` |
| `vava_atelier:journal` | serveur, after | `{ id, editor, kind, defId?, action, title, summary?, version?, actor = { accountId?, label } }` |
| `vava_atelier:state` | client, local | `{ open }` |

#### Définitions gardées (T-101, `vava_atelier` 1.1.0)

**Déclaration** (en plus de T-100, contrôlée par le validateur) : `format` (1 à 65535, défaut 1) ; `texts.trialLine`
(0 à 80 octets, bandeau pendant l'essai) ; par type `feminine` (booléen ; défaut : vrai pour l'article `la`) ;
`apply` et `remove` **ensemble** (atelier gardé), `trial` et `endTrial` ensemble et seulement avec `apply` ; `upgrade` ;
`validateLot` (seulement avec `apply`) ;
chaîne des `parent` sans cycle, trois types au plus. Le descripteur gagne `stored`, `hasTrial`, `format` et
`feminine` sur chaque type.

**Contrat du module gardé** :
- `index(kind, ctx?)` et `read(kind, id, ctx?)` gardent leur forme et ne servent plus qu'à la graine et à la
  synchronisation ; `read` peut rendre les clés réservées `place` (lieu) et `parent`. Aller-retour : après
  `apply(kind, def)`, `read(kind, def.id)` rend la même data, le même `place`, le même `parent`. **Écart à la spec,
  T-101** : avec `ctx = { original = true }`, ils rendent l'**original de la config** (avant tout `apply`), pour
  `/atelier_archives original` ; un module qui l'ignore rend ce qui est en vigueur (rien ne paraît alors à rétablir).
- `validate(kind, data, ctx)` : `ctx` gagne `action` (`check`, `save`, `trial`, `publish`, `remove`, `restore`,
  `import`), `parent`, `place`, `bundle` : **références légères** des fiches publiées ensemble, `{ { kind, id,
  parent?, removal } }` (≈ 90 octets par fiche, **sans data ni lieu** : seule la fiche validée a les siens, en `data`
  et `ctx.place`). À l'import, `bundle` n'est donné que si le lot n'est pas plus gros qu'une publication groupée
  (`bundle.maxChildren` + 1 fiches) ; au-delà il est absent (un module ne doit pas compter dessus pour un import). Sur `save`, un refus n'empêche pas d'enregistrer (avertissements) ; avec `remove`, `data` est la publiée
  et le module peut refuser un retrait qui détruirait des objets de joueurs.
- `validateLot(lot, ctx)` (facultatif, atelier gardé seulement) : pour un module qui doit **croiser** les fiches d'un
  lot (deux enfants d'un même parent, une somme…). Appelé **une fois par lot** de plus d'une fiche (essai, publication
  groupée, retrait en cascade, retour en arrière en cascade, import), après les `validate` de chaque fiche et seulement
  s'ils n'ont rien à redire ; `lot = { { kind, id, data, parent?, place?, removal } }` (la fiche principale d'abord ;
  seul endroit où le module voit les lieux du lot ensemble),
  `ctx = { source?, accountId?, kind, id, action }` (fiche principale ; `action` comme pour `validate`). Même retour
  que `validate` ; un champ nommé dans une erreur est un champ de la fiche principale. Ne jamais faire passer un lot
  entier par `ctx.bundle` : chaque appel à une fonction d'un module resérialise ses arguments (un lot de 200 fiches
  à 2 Ko croisé par chaque `validate` ≈ 80 Mo). À l'import, `validateLot` reçoit d'un bloc toutes les fiches qui
  changent d'un atelier (jusqu'à 4 Mo, le plafond d'un fichier : 40 à 160 ms, une fois par import) ; un module qui
  ne croise rien ne le déclare pas.
- `apply(kind, def, info)` : `def` = data normalisée + `id`, `version`, `parent?`, `place?` (jamais `status`) ;
  `info = { reason, last, previous? }`, `reason` ∈ `publish`, `restore`, `reimport`, `import`, `sync` ; `last` : dernier
  appel d'un lot. Crée ou remplace, idempotente, tout ou rien.
- `remove(kind, id, info)` : `info = { reason, last }` ; ne détruit jamais d'objet de joueur.
- `trial(kind, def, ctx)` : montre la fiche **à son seul auteur** ; `ctx = { source, accountId, children = { { kind, def
  } }, reason = 'start' | 'save' }`. Avec `reason = 'save'` (relance après une sauvegarde de la fiche ou de l'un de
  ses enfants), `def` est la fiche essayée et `children` ne porte **que** l'enfant sauvegardé (vide si c'est la fiche) :
  le module garde les autres tels qu'il les montre déjà (différence, jamais tout le lot à chaque sauvegarde). `endTrial(kind, id, ctx)` : `ctx = { source?, accountId, children = { { kind, id }
  }, reason }` (`stop`, `publish`, `discard`, `taken`, `session`, `dropped`, `timeout`, `editor`), retour ignoré.
- `diff(kind, avant, après)` → texte ≤ 160 ou nil ; `upgrade(kind, data, from)` → data, ou nil (version illisible).
- Toutes sont appelées isolées et chronométrées ; une erreur levée vaut un refus.

**Diffusion** : l'Atelier n'envoie **aucune définition** aux joueurs. Consignes pour un module qui diffuse ce que
`apply` change (T-102, T-120) : **regrouper** ses différences pendant le lot et ne les envoyer qu'à l'appel marqué
`info.last` (un message par lot et par joueur concerné), jamais à chaque `apply` ni sur le hook
`vava_atelier:published` (un par fiche) ; une zone du core par fiche ne tient pas pour des centaines de nœuds (2 048
zones en tout, tous modules confondus) : une zone par secteur, l'état portant les fiches du secteur. Ce qui est posé dans le monde passe par l'état de
zone du module (`core.zones` : `define`, `move`, `replace`, `remove`) ; les arts par un catalogue versionné envoyé en
différences (T-120) ; un essai par `core.net.send` au seul auteur, jamais dans l'état de zone.

**Lieux** (`place`, arrondis au centimètre, cap au dixième de degré dans [0, 360)) : `point { x, y, z }`, `oriented
{ x, y, z, h }`, `circle { x, y, z, r }` (0 < r ≤ 500), `polygon { z, points = { { x, y } } }` (3 à 32 sommets, 5 cm
entre deux consécutifs, aire non nulle), `door { x, y, z, h, model }` ; \|x\|, \|y\| ≤ 50 000, \|z\| ≤ 5 000.

**Base** : `vava_atelier_definitions` (`sql/0002_definitions.sql`), une ligne par version : `draft`, `trial` (version
NULL, numérotés à la publication), `published` (une par fiche), `archived` (anciennes versions et versions de retrait,
`removal = 1`) ; `origin` `seed` | `atelier` | `restore` | `import`. 16 Ko par fiche, 1 000 fiches vivantes par type,
20 brouillons par membre, 20 versions gardées par fiche (jamais la publiée ni la dernière d'une fiche retirée).

**Synchronisation** (à chaque déclaration d'un atelier gardé, dans un fil ; l'atelier rend `syncing` pendant ce temps) :
graine des identifiants de `index` jamais vus en base (version 1, `origin = seed`, auteur « Console »), puis
rapprochement par empreintes (`apply` de ce qui diffère chez le module, `remove` de ce qu'il a sans version publiée).

RPC ajoutés (schémas stricts, débits `write`, `preview`, `publish`, `read`) — réponse d'écriture `{ done = true, … }`,
refus jugé par le module `{ done = false, errors = { { field?, text } } }`, refus de structure `false, code` :

| RPC | Arguments | Réponse |
|---|---|---|
| `save` | atelier, type, fiche (`''` : nouvelle), révision lue, valeurs | `{ done, id, rev, title, state, footer, warnings? }` |
| `trial` | atelier, type, fiche, révision | `{ done, rev, state, footer, children }` |
| `endTrial` | atelier, type, fiche | `{ done, rev, state, footer }` |
| `preview` | atelier, type, fiche, `publish` \| `restore`, révision ou version visée | `{ title, lines, warnings, token, valid, errors? }` |
| `publish` | atelier, type, fiche, révision, jeton (16 hexadécimaux) | `{ done, version, state, footer }` |
| `restore` | atelier, type, fiche, version, jeton | `{ done, version, state, footer }` |
| `discard` | atelier, type, fiche, révision | `{ done, state, footer }` ou `{ done, gone = true }` |
| `retire` | atelier, type, fiche | `{ done, rev, state, footer }` (brouillon jamais publié : `{ done, gone = true }`) |
| `take` | atelier, type, fiche, révision vue | `{ done, rev, state, footer }` |
| `history` | atelier, type, fiche, avant la version (0 : récentes) | `{ versions = { { version, status, removal, restoredFrom?, summary?, author, when } }, more }` (sans `origin` : la page ne s'en sert pas) |
| `version` | atelier, type, fiche, version | `{ id, title, version, values, labels, warnings?, state, footer }` |
| `removed` | atelier, type, page | `{ total, page, pages, entries = { { id, title, hint } } }` |

`read` d'un atelier gardé lit la base : brouillon s'il y en a un, sinon la publiée ; réponse de T-100 plus `rev`,
`version`, `holder = { label, mine, at }?` (`at` : « il y a 3 min »), `removal`, `stale`. Une ligne de `list` porte
`hint` et `tone` (`draft`, `trial`, `removal`, `new`, `refused`) vus par l'appelant. `state = { label, tone, line? }`
(`tone` : `new`, `draft`, `trial`, `live`, `archived`, `removal`, `refused`) ; `footer = { { id, label, primary?, link?
} }`. **Écart à la spec, T-101** : un type enfant reçoit son parent dans `values.s.parent` (identifiant d'une fiche du
type parent) ; sans lui, la fiche est enregistrée sans parent et sa publication seule rend `parent_missing`.

Refus ajoutés : `stale`, `draft_taken`, `draft_open`, `not_holder`, `no_draft`, `not_stored`, `too_large`, `full`,
`parent_missing`, `trial_busy`, `no_trial`, `syncing`, `unknown_version`, `not_archived`, `unchanged`, `unreadable`.

Évènement ajouté : `vava_atelier:entryChanged` (`atelier, type, fiche, ce qui a changé` — `saved`, `published`,
`restored`, `removed`, `discarded`, `taken`, `trialEnded` —, plus le titre pour `trialEnded`) aux seuls membres dont la
séance a **cette fiche** ouverte (droit de l'atelier relu), sauf l'auteur du changement, au tenant d'un essai qui prend
fin sans qu'il l'ait demandé et à l'ancien tenant d'un brouillon repris.

| Hook (T-101) | Côté, phase | Payload |
|---|---|---|
| `vava_atelier:published` | serveur, after | `{ editor, kind, id, version, previous?, action, actor = { accountId?, label } }` — `action` : `publish`, `remove`, `restore`, `reimport`, `import` ; un par fiche du lot |
| `vava_atelier:trial` | serveur, after | `{ editor, kind, id, accountId, source?, on, reason? }` |

| Export (T-101) | Retour |
|---|---|
| serveur `codexList(list)` | `list = 'ateliers'` : `{ { value, label } }` des ateliers gardés ; toute autre liste : `{}` |

Journal : actions ajoutées `discarded`, `taken`, `trial_ended`, `exported`, `received` ; une ligne sans fiche (`def_id`
NULL) porte sur l'atelier entier (« A rétabli l'original de l'atelier Récolte »).

**Archives** (`/atelier_archives` ; `etat` : droit d'ouvrir l'Atelier (`metiers`), ateliers visibles seulement ;
`original_fiche` : droit de l'atelier ; `original`, `exporter`, `importer` : Souverain ou console ; `confirmer` : le
droit de l'opération, relu ; personnage chargé et nom au Registre exigés, une commande à la fois par membre ; fichiers
dans `vava_atelier/echanges/`, nom `^[A-Za-z0-9_-]+\.json$` de 64 octets au plus, 4 Mo au plus à la lecture comme à
l'écriture, un export par minute tous membres confondus, jamais servis aux joueurs) :

```json
{ "atelier": 1, "exported_at": "2026-10-30T14:05:00Z",
  "editors": { "vava_example_atelier:panneaux": { "format": 1, "kinds": { "panneau": [
    { "id": "place_du_marche", "version": 3, "place": { "x": -250.0, "y": -930.0, "z": 31.2, "h": 90.0 },
      "data": { "titre": "Panneau de la place", "texte": "…", "taille": 1.5 } } ] } } } }
```

Seules les versions publiées partent. Un import contrôle la forme (ateliers connus et gardés, types déclarés,
identifiants, doublons, profondeur d'une fiche ≤ 6, format), chaque fiche comme une saisie (une valeur hors bornes est
refusée avec son chemin), tout ou rien par atelier ; il publie de nouvelles versions (`origin = import`), ne retire
jamais rien et garde les brouillons ; résumé puis `confirmer` sous 60 s.

Exemple complet, sans une ligne d'interface : `examples/vava_example_atelier` (mode développement). Hors jeu :
`web/index.html?screen=home` (puis `list`, `entry`, `entry&layout=side`, `journal`, `confirm`, `keys`…), données
simulées de `web/dev/devmock.js`, jamais livré.

### `vava_chat`

Le chat du royaume, à la place de la ressource `chat` de FiveM (`ensure vava_chat` remplace `ensure chat`, juste après
`vAvA_core`) : `/ooc` et texte sans commande (joueurs à 20 m), `/me` et `/do` (15 m, aussi au-dessus de la tête),
`/mp <n°>` et `/r`, `/staff` (Conseil) ; onglets Général, Actions, Conseil et un par correspondant ; fenêtre
déplaçable. Journal de modération `vava_chat_logs` (`/ooc`, `/mp`, `/staff`, 7 jours). Tout le détail et la liste des
tests en jeu : `modules/vava_chat/README.md`. Demande le core 0.5.0 ; facultatif : `vava_admin` (sans lui, ACE
`vava_chat.staff`).

- **Compatibilité** : `chat:addMessage`, `chatMessage`, `chat:addSuggestion(s)`, `chat:removeSuggestion`, `chat:clear`
  marchent tels quels (local ou depuis le serveur). Texte brut seulement : les modèles HTML ne sont jamais interprétés.
  Les exports de l'ancienne ressource ne sont pas repris.
- **Suggestions du registre** (1.1.0) : avec `vava_codex`, le profil du joueur apporte les suggestions décrites par le
  registre `core:commands` (aide, paramètres nommés avec leur indication, et les sous-commandes en noms à deux mots :
  `/metiers niveau <joueur> <compétence> <niveau>`), filtrées selon ses droits ; à nom égal elles l'emportent sur un
  `chat:addSuggestion`. Taper `/metiers ` montre le paramètre en cours et garde ses sous-commandes proposées ; `Tab`
  complète le nom puis la sous-commande. Toute commande tapée est signalée au Codex (`noteCommand`) pour ses
  « dernières pages ». Sans `vava_codex`, rien ne change. Depuis 1.1.1, un rang donné ou retiré en cours de partie met
  les suggestions à jour sans reconnexion (le serveur prévient le seul joueur visé, qui redemande son profil), et
  `/staff` n'est suggéré qu'aux membres du Conseil.
- **Envoi** : RPC `vava_chat:send` (genre, texte, numéro de joueur | 0, conversation | 0) ; destinataires choisis par le
  serveur, jamais `-1`. Un `/mp` désigne son correspondant par un numéro de conversation jamais réutilisé.

| Export serveur | Retour |
|---|---|
| `addMessage(cible, message)` | `true` ou `false, code` — `cible` : joueur connecté (`-1`, envoi à tous, refusé depuis 1.2.0 : `invalid_target`) ; `message` : texte, `{ author?, text, color? }` ou `{ args, color? }` |

**Hooks** : `vava_chat:sending` (`before`, annulable : `{ source, characterId, kind, text, target? }` — sourdine,
prison… ; la raison du refus est montrée au joueur), `vava_chat:sent` (`after` : `+ recipients`, nombre de joueurs
qui l'ont reçu : auteur compris, sauf pour un `/mp`, qui vaut 1).

### `vava_chancellerie`

Le pont entre la Chancellerie (panneau web, programme à part : voir `docs/chancellerie.md`) et le serveur de jeu.
Serveur seulement (rien n'est envoyé aux joueurs). Demande vava_admin 1.2.0 ; vava_voice 1.1.0 pour les zones de voix,
vava_cameras 1.0.0 pour l'écran des joueurs, vava_time 1.0.0 pour le ciel et l'heure (1.4.0).

- **Entrée** : l'adresse HTTP du serveur de jeu (`http://127.0.0.1:<port>/vava_chancellerie/…`). N'accepte que les
  requêtes venues de la machine elle-même, portant la clé tirée par la Chancellerie à chaque lancement de FXServer.
  Depuis 1.5.0, la clé ne passe plus sur la ligne de commande (lisible par tout utilisateur de la machine) ni dans une
  convar : seule l'adresse de la Chancellerie y est posée (`+set vava_chancellerie_url`) ; le pont demande la clé en
  écrivant `vava_chancellerie:cle?` dans la console, la Chancellerie la lui donne par l'entrée de FXServer
  (`vava_chancellerie_cle <clé>`, commande de la seule console, la première clé reçue gardée en mémoire). Sans
  Chancellerie (aucune adresse posée), le pont ne demande rien et reste fermé ; une ancienne
  `vava_chancellerie_token` est ignorée et signalée.
- **Rangs des comptes reliés** (`/staff/sync`, 1.5.0) : un rang n'est donné qu'à un compte de jeu que le pont a lui-même
  vu relié (code juste tapé en jeu, confirmé par la Chancellerie ; table `vava_chancellerie_links`) ; ailleurs,
  `not_linked_in_game`. Retirer un rang reste toujours permis ; un retrait marqué `unlinked: true` (déliaison) fait
  oublier le compte. Les liaisons en cours sont attendues 5 s au plus par requête (une seule échéance).
- **Adresse de la Chancellerie** (1.5.0) : lue une seule fois au `setup`, seulement `http://127.0.0.1:<port>`.
  **Liste blanche** : tant que la clé n'est pas arrivée sur un serveur lancé par la Chancellerie, connexion refusée.
  **Limite** : une ressource serveur qui donne sa clé avant la Chancellerie garde le pont ; la Chancellerie le repère
  (ligne de refus de sa clé, évènement avec une autre clé, pas de `ready` vérifié) et alerte, sans plus.
- **Demandes** : passées telles quelles au Registre (`webRequest`), qui vérifie tout et tient le journal ; zones de voix
  lues, modifiées et supprimées auprès de vava_voice, droit vérifié et journal tenu par le Registre.
- **Ciel et heure** (1.4.0, `server/time.lua`) : demandes `time` (droit `view`), `timeClock` (`{ action, minutes }`) et
  `timeWeather` (`{ action, ciel?, figer? }`, droit `tools`), transmises à `webState`, `webClock` et `webWeather` de
  vava_time ; droit vérifié par `webCan`, décision inscrite par `webLog` si elle change quelque chose. Code
  `time_unavailable` si vava_time n'est pas lancé. Un fichier du pont ajoute ses demandes à `routes.requests`.
- **Caméras** (1.1.0) : ouvertes auprès de vava_cameras une fois le droit `watch` accordé — la vue en grand par la
  demande « écran du joueur » du Registre (`watchScreen` : cible vérifiée, inscrite au journal), les cases d'un mur sur
  le seul droit, l'ouverture du mur étant inscrite au journal (« Mur des caméras ouvert »). Depuis 1.5.1, la vue en
  grand n'est demandée au Registre qu'après le droit lu (`webCan`) et la caméra jugée accordable (`webCheck` de
  vava_cameras ≥ 1.3.0) : une vue refusée faute de débit chez le joueur filmé (`budget`), que la Chancellerie retente
  toutes les 10 s, ne laisse pas de ligne au journal. Depuis 1.4.1, une case
  demandée par un compte qui n'a ouvert aucun mur depuis `cameras.tileLogMs` (2 h) inscrit sa propre ligne (« Cases du
  mur regardées », numéro du joueur) : aucune case n'échappe au journal, sans refuser le navigateur (le pont ne sait pas
  quand un mur du web se ferme). Une ligne (ouverture ou case) ne compte que si le Registre l'a acceptée (`webLog`
  appelé et réussi) : sinon, la case suivante réessaie. Routes : `/cameras/wall`, `/cameras/players`, `/camera/start`
  (`{ actor, target, quality }`), `/camera/answer`, `/camera/stop`.
- **Évènements** vers la Chancellerie (requête HTTP locale, avec la clé) : signalements, arrivées et départs des joueurs,
  offre et fin des caméras du web (hook `vava_cameras:web`), arrêt du module des caméras (`{ type = 'camera', reset }`),
  rang du Conseil donné ou retiré (`{ type = 'camera', recheck }`, 1.3.1 : la Chancellerie revérifie le droit de chaque
  compte qui regarde).
