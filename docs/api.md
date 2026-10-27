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
| `type` | tous | `string`, `number`, `integer`, `boolean`, `table`, `array`, `map`, `function`, `any` |
| `optional` | tous | `nil` accepté |
| `min` / `max` | string (longueur), number/integer (valeur), array/map (nombre d'éléments) | bornes incluses |
| `pattern` | string | motif Lua (ancrer avec `^` et `$`) |
| `enum` | string, number, integer | liste des valeurs autorisées |
| `fields` / `strict` | table | champs attendus ; `strict` (défaut `true`) refuse les clés inconnues |
| `items` | array | schéma de chaque élément |
| `key` / `value` | map | schémas des clés (string ou integer) et des valeurs |

`function` accepte une fonction locale ou venant d'une autre ressource (callbacks d'entrées de registre).

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
| `core:character:loaded` | `{ source, accountId, characterId }` — chargez vos données ici (avant l'apparition) |
| `core:character:spawned` | `{ source, accountId, characterId }` — apparition confirmée par le client (chaque apparition, réanimation comprise) : le ped est en place, sa vie et sa position sont lisibles |
| `core:character:unloading` | `{ source, accountId, characterId, reason }` — sauvez vos données ici (le core attend) |
| `core:character:deleted` | `{ source, accountId, characterId }` |
| `core:character:fieldChanged` | `{ characterId, field, value }` |

#### Hooks before du core (annulables)

| Nom | Payload | Effet d'un refus `false, raison` |
|---|---|---|
| `core:player:connecting` | `{ source, license, name, accountId? }` | connexion refusée ; `raison` est affichée au joueur (ban, whitelist, file). `accountId` : compte déjà connu de cette license (absent à la première venue, aucun compte n'étant créé avant l'accord des hooks) |
| `core:character:creating` | `{ source, accountId, firstName, lastName, sex }` | création refusée ; `raison` renvoyée au client |
| `core:character:deleting` | `{ source, accountId, characterId }` | suppression refusée ; `raison` renvoyée au client |

`source` dans `core:player:connecting` est l'identifiant **temporaire** de connexion. La `license` et le pseudo
ne sont transmis qu'aux hooks serveur : le core ne les stocke pas (seule la license l'est, comme clé de compte).

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
| `getActive(source)` | `{ id, accountId, source, firstName, lastName, sex }` ou `nil` |
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

Persistance et positions :

- La position est lue **côté serveur** (OneSync obligatoire), seulement après confirmation de l'apparition.
- Sauvegarde groupée des personnages modifiés toutes les `persistence.saveIntervalMs`, et immédiate au
  déchargement ou à la déconnexion. Une écriture en échec est retentée sans perte.
- FiveM n'attend pas les écritures à l'arrêt du serveur : **lancer `vava_saveall` avant `quit`**.

Apparition : le core remplace `spawnmanager`. Ne pas démarrer `spawnmanager`, `basic-gamemode` ni de carte
`mapmanager` avec vAvA_core.

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

### `core.rpc`

```lua
core.rpc.register('vava_shop:buy', {
    args = {
        { type = 'string', max = 32, pattern = '^[%w_]+$' },
        { type = 'integer', min = 1, max = 100 },
    },
    rateLimit = { capacity = 5, refillPerSecond = 1 },   -- optionnel
}, function(source, itemName, amount)
    return true, newBalance
end)
```

- `args` est **obligatoire** (`{}` si aucun argument) : aucun RPC n'accepte de données non décrites.
- Contrôles avant le handler : source réseau, limite globale du joueur, RPC connu, limite du RPC, nombre de
  requêtes simultanées du joueur, schéma des arguments.
- Le handler reçoit `source` puis les arguments validés. Ses valeurs de retour sont envoyées **au seul
  joueur appelant**.

| Fonction | Retour |
|---|---|
| `register(name, options, handler)` | `true` ou `false, err` |
| `unregister(name)` | `true` ou `false, err` |
| `callClient(target, name, ...)` | `true, ...valeurs` ou `false, code` |
| `callClientWith({ timeout?, returns? }, target, name, ...)` | idem, avec timeout et schéma de retour |

Ce que renvoie un client est **déclaratif et non fiable** : toujours fournir `returns` et ne jamais s'en servir
comme source de vérité.

#### Codes d'erreur RPC

| Code | Sens |
|---|---|
| `timeout` | pas de réponse dans le délai |
| `rate_limited` | limite du RPC atteinte pour ce joueur |
| `busy` | trop de requêtes simultanées pour ce joueur |
| `unknown_rpc` | aucun RPC de ce nom |
| `invalid_args` | arguments refusés par le schéma (détail dans la console serveur uniquement) |
| `server_error` | le handler serveur a levé une erreur (détail dans la console serveur uniquement) |
| `saturated` | trop d'appels en attente |
| `invalid_target` / `invalid_name` / `invalid_options` | appel mal formé |
| `dropped` | joueur déconnecté pendant l'attente |
| `owner_stopped` | ressource appelante arrêtée pendant l'attente |
| `client_error` / `invalid_response` | le client a échoué ou a renvoyé des valeurs refusées par `returns` |

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
| `rpc.register(name, handler)` | `true` ou `false, err` — handler appelable par `callClient` |
| `rpc.unregister(name)` | `true` ou `false, err` |

`rpc.call` distingue le **transport** (premier retour) de la **réponse métier** (retours suivants) :

```lua
local ok, success, result = core.rpc.call('vava_example:postNote', 'annonce', 'Foire au château demain')
if not ok then --[[ success contient le code de transport ]] end
```

Le client n'est jamais une source de vérité : un RPC exprime une intention que le serveur valide et décide.

### `core.characters` (client)

Base d'un écran de sélection. Chaque fonction RPC renvoie `ok` (transport), puis `success`, `résultat | code`.

| Fonction | Résultat en cas de succès |
|---|---|
| `current()` | `{ id, firstName, lastName, sex, fields }` du personnage actif, ou `nil` (local, sans appel réseau) |
| `awaitingSelection()` | `true` si le joueur attend de choisir un personnage (local) |
| `list()` | liste `{ id, firstName, lastName, sex }` des personnages du compte, puis le maximum par compte |
| `create(firstName, lastName, sex)` | résumé du personnage créé |
| `select(characterId)` | — ; le personnage arrive ensuite par le hook `core:character:loaded` |
| `unload()` | — ; retour à l'écran noir de sélection |
| `delete(characterId)` | — |

Hooks client (locaux, émis par le core) :

| Nom | Payload | Moment |
|---|---|---|
| `core:character:selection` | `{}` | le joueur est mis en attente (écran noir) : une interface de sélection prend la main |
| `core:character:loaded` | le personnage | données reçues, avant l'apparition |
| `core:character:spawning` | `{ modelChanged }` | ped placé, écran encore noir : appliquer l'apparence ici |
| `core:character:fieldChanged` | `{ field, value }` | champ `owner`/`public` modifié |
| `core:character:unloaded` | `{ id }` | retour à la sélection |

Codes de refus : `no_session`, `busy`, `wrong_state`, `not_owner`, `not_found`, `too_many_characters`,
`invalid_name`, `invalid_sex`, `name_taken`, `refused`, `db_error`, `corrupted_data`, `no_character`, ou la
raison donnée par un hook `before`.

Noms : `characters.name` dans `config/server.lua` (longueur en caractères, lettres accentuées autorisées,
séparateurs `'`, `-` et espace jamais en tête, en fin ni doublés).

## Modules officiels

Ressources séparées, dans `modules/` : à copier (ou lier) dans le dossier `resources` du serveur, dans cet ordre :
`ensure vAvA_core`, `ensure vava_world`, `ensure vava_appearance`, `ensure vava_characters_ui`, `ensure vava_hud`,
`ensure vava_inventory`, `ensure vava_needs`, `ensure vava_health`, `ensure vava_admin`, `ensure vava_voice`,
`ensure vava_chancellerie`, puis les modules qui déclarent des objets.

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
  médiévaux ne demanderont que ces réglages.

### `vava_characters_ui`

Écran de sélection et éditeur de création (NUI, sans framework). S'ouvre sur `core:character:selection`, se ferme
sur `core:character:loaded`. Aperçu sur un ped **local** (invisible des autres joueurs). Scène et caméras :
`config.lua`. Pour travailler le rendu sans le jeu, ouvrir `web/index.html` dans un navigateur
(`?screen=creator&tab=hair&sex=f`) : des données simulées remplacent le jeu.

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
effets ne s'appliquent que si l'unité est consommée). `effects` : 8 effets au plus, nombres entre −1000 et 1000. La
fiche d'objet affiche les effets qu'elle connaît (`web/js/strings.js` → `effects`).

**Catégories** : l'interface teinte l'objet et sa fiche selon `category`. Teintes prévues : `nourriture`,
`boisson`, `arme`, `armure`, `outil`, `materiau`, `valeur`, `soin`, `divers`. Une autre catégorie s'affiche
telle quelle, sans teinte. **Images** : un dessin au format de l'objet (2 × 1 → rapport 2:1), fond transparent,
ombre portée comprise dans l'image : l'interface n'applique aucun filtre.

**Exports serveur** (cible : un joueur, ou `{ container = id }`) :

| Export | Retour |
|---|---|
| `add(cible, objet, quantité, métadonnées?)` | `true` ou `false, code` — tout ou rien, complète d'abord les piles existantes |
| `remove(cible, objet, quantité)` | `true` ou `false, code` — tout ou rien |
| `exchange(cible, retraits, ajouts)` | `true` ou `false, code` — recette, achat : rien ne change si une partie échoue |
| `canCarry(cible, objet, quantité, métadonnées?)` | `true` ou `false, code` (`no_space`, `too_heavy`) |
| `count(cible, objet)` | quantité totale |
| `getItems(cible)` | liste `{ id, item, x, y, rotated, quantity, metadata }` |
| `setMetadata(cible, idObjet, métadonnées)` | `true` ou `false, code` (`not_found`, `invalid_request`) — remplace les métadonnées d'un objet (`nil` les retire), sauvegardé et montré aux inventaires ouverts ; depuis 1.3.0 |
| `createContainer({ kind, ownerType?, ownerId?, width, height, maxWeight?, label? })` | id d'un conteneur conservé (coffre…) |
| `open(source, containerId)` | ouvre un conteneur au joueur ; **l'appelant a vérifié le droit d'accès** |
| `containerOf(source)` | id du conteneur porté par le personnage actif d'un joueur (fouille, administration), ou `nil, code` |

**Hooks** (`before` annulable, puis `after`) : `vava_inventory:move`, `split`, `merge`, `drop`, `use`, `add`,
`remove`. Payload : `{ source, instanceId, item, quantity, from, to }` pour les gestes du joueur,
`{ container, removals, additions, owner }` pour les échanges. `use` transmet aussi `category` et `effects` de
l'objet, et `consumed` en phase `after`. Un refus `false, 'raison'` est montré au joueur, dans l'interface ou en
notification s'il utilisait un raccourci.

**Garanties** :
- Le serveur décide de tout : place, poids, distance d'un sac (lue côté serveur), droit d'accès.
- Chaque opération s'exécute d'un bloc en mémoire, sans attendre la base : pas de duplication par concurrence.
  Les identifiants d'objets sont attribués en mémoire (**un seul serveur par base de données**).
- Écriture groupée toutes les 3 s et à chaque fermeture ou déchargement. Les sacs au sol ne survivent pas à un
  redémarrage (ni leur contenu).
- Le client ne reçoit que les conteneurs qu'il a ouverts, puis leurs différences.

Touches par défaut (réglables par le joueur dans Paramètres > Raccourcis > FiveM) : `I` ouvre l'inventaire,
`1` à `5` utilisent les raccourcis. Dans l'interface : glisser pour déplacer, `R` pour pivoter, `Maj` pour
diviser en deux, double-clic pour utiliser ou ramasser, clic droit pour les actions, relâcher hors de
l'inventaire pour jeter au sol.

Polices de l'interface : Cinzel et EB Garamond, embarquées dans `web/fonts` (licence SIL Open Font License, textes
joints). Pour travailler le rendu sans le jeu, ouvrir `web/index.html` dans un navigateur (`?drop=1` ajoute un sac
au sol).

### `vava_needs`

Faim et soif, de 0 (épuisé) à 100. Champ `vava_needs:state` `{ hunger, thirst }` (visibilité `owner`), sauvegardé
avec le personnage. Les besoins, durées, paliers, messages et gestes sont dans `config.lua` : ajouter un besoin
à `needs` suffit pour qu'il baisse, s'affiche et se mange.

- **Baisse** : décidée par le serveur, une boucle pour tous les personnages actifs (`tickMs`, 60 s). Faim de 100 à 0
  en 4 h de jeu, soif en 3 h ; × 1,5 pour la part du temps passée à courir (vitesse lue côté serveur ; un véhicule
  ne compte pas). Aucune baisse hors connexion ni pendant la sélection.
- **Paliers** : sous 30, un message ; sous 10, un message et l'endurance maximale réduite ; à 0, perte de vie à chaque
  passage (2 points pour la faim, 4 pour la soif). Avec `vava_health`, le joueur finit à terre (puis peut être
  relevé) et la baisse s'arrête tant qu'il y est ; sans lui, la vie ne descend jamais sous `health.floor` (10 % de la
  vie au-dessus du seuil de mise à terre), pour que personne ne reste mort sans recours.
- **Manger, boire** : objets de l'inventaire déclarant `effects = { hunger = …, thirst = … }`. Refusés au-delà de 95
  (« Vous n'avez plus faim. ») et pendant le geste en cours (3 s). Geste selon la catégorie (`nourriture` : manger,
  `boisson` : boire), sans accessoire en main. Un objet portant aussi l'effet d'un autre module n'est jamais refusé
  pour cause de satiété.
- **Réseau** : un envoi par joueur et par minute (son champ), à lui seul ; aucun RPC (l'utilisation d'un objet passe
  par l'inventaire). La perte de vie est appliquée par le client (la vie d'un joueur lui appartient dans GTA).

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

- `id` : `<ressource>:<nom>` ; un module ne gère que ses jauges, retirées à son arrêt.
- `icon` : image `nui://<ressource>/<chemin>` listée dans les `files` du module (aucune adresse externe).
- `low`, `critical` (0 à 1) : paliers où l'anneau passe à l'ambre puis au rouge, avec une lueur au palier critique.
- Les notifications GTA étant retirées, un module affiche ses messages par `notify` ; sans `vava_hud`, il revient à
  celles de GTA (c'est ce que font l'inventaire, les besoins et la santé).
- Pour travailler le rendu sans le jeu : `web/index.html?values=0.8,0.62,0.08` dans un navigateur.

### `vava_health`

Santé, mise à terre et réanimation. Champ `vava_health:state` `{ health, downed, downedFor }` (visibilité `owner`) :
`health` de 0 à 1, part de la vie au-dessus du seuil où GTA met un joueur à terre. Lieux de soins, délais, distances,
touches et messages : `config.lua`. Demande le core 0.4.0 (hook `core:character:spawned`).

- **Vie** : lue côté serveur toutes les 10 s et enregistrée avec le personnage ; restaurée à chaque apparition. La
  récupération automatique de GTA est coupée : on se soigne par objets (`effects = { health = 20 }` : +20 %, refusé
  si l'on n'est pas blessé) ou en se faisant relever.
- **Mise à terre** : décidée par le serveur, qui lit la vie de chaque joueur apparu toutes les 500 ms (le client n'a
  rien à déclarer) ; cause et auteur lus côté serveur. Le joueur reste au sol, l'écran « wasted » de GTA est remplacé
  par l'écran « Vous êtes à terre ». À terre : aucun geste sur les objets, faim et soif figées ; un client qui se
  relève seul est remis à terre.
- **Relever** (touche G par défaut) : le serveur choisit la personne à terre la plus proche (2 m, positions lues côté
  serveur, rien n'est diffusé) ; geste de 8 s, distance revérifiée à la fin ; relevé avec 25 %. La personne à terre
  lit « Quelqu'un vous relève » : son nom n'est pas révélé.
- **Rendre l'âme** (touche E maintenue 3 s) : après 3 minutes à terre ; porté au lieu de soins le plus proche avec 50 %.
  D'office au bout de 10 minutes. Se déconnecter à terre ne sert à rien : on revient à terre, avec le temps restant.

**Exports serveur** (cible : un joueur, son personnage actif) :

| Export | Retour |
|---|---|
| `get(source)` | `{ health, downed, downedFor }` ou `nil, code` — `health` lue côté serveur |
| `isDowned(source)` | booléen |
| `setHealth(source, vie)` | `true` ou `false, code` — de 0 à 1 ; 0 fait tomber |
| `heal(source, part)` / `damage(source, part)` | `true` ou `false, code` — à partir de la vie actuelle |
| `down(source, cause?)` | `true` ou `false, code` — mise à terre décidée par un module (`cause` libre : 'piege'…) |
| `revive(source, vie?)` | `true` ou `false, code` — relève sur place (25 % par défaut) |

Codes : `not_ready`, `invalid_target`, `no_character`, `invalid_amount`, `invalid_cause`, `downed`, `not_spawned`,
`already_downed`, `not_downed`.

**Hooks** :
- `vava_health:downed` (`after`) : `{ source, characterId, reason, cause?, killer? }` — `reason` = `death` (vie lue sous
  le seuil, `cause` = arme GTA) ou `api` ; `killer` = joueur à l'origine, s'il y en a un ;
- `vava_health:reviving` (`before`, annulable) : `{ source, target }` — exiger un métier, un objet… ; la raison du refus
  est montrée au joueur ;
- `vava_health:revived` (`after`) : `{ source, characterId, reason, by? }` ;
- `vava_health:respawned` (`after`) : `{ source, characterId, reason, point }` — `reason` = `choice` (il a rendu l'âme)
  ou `timeout` ; point d'appui des pénalités à venir.

**Export client** : `get()` — `{ health, downed }` du joueur local, ou `nil`.

Pour travailler le rendu sans le jeu : `web/index.html?state=downed` (ou `ready`, `patient`, `holding`, `assist`).

### `vava_admin`

Administration du royaume : le **Conseil** (rangs et droits), le panneau **Registre du Conseil** (F10 ou `/conseil`,
réglable), les bans vérifiés à la connexion, le journal des actions, les signalements des joueurs (`/signaler`).
Rangs, droits, durées, textes : `config.lua`. Demande le core 0.5.0 (compte connu transmis au hook de connexion).

**Rangs** (cumulatifs ; on n'agit jamais sur un membre de rang égal ou supérieur) :

| Rang | Droits |
|---|---|
| Gardien | `view`, `teleport`, `freeze`, `heal`, `message`, `warn`, `kick`, `reports`, `watch` (écran des joueurs) |
| Sénéchal | + `ban` (7 jours au plus), `inventory`, `give`, `announce`, `tools`, `spectate`, `logs`, `bans` |
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
- Les données des joueurs ne partent qu'au personnel, et à la demande ; le pseudo FiveM n'est jamais enregistré.
- Bans par compte, vérifiés au hook `core:player:connecting` : un banni voit le motif, la fin et le numéro du ban.
  Aucun compte n'est créé pour une connexion refusée.
- Déplacer et immobiliser passent par les natives serveur (OneSync). Le vol libre est la seule boucle par image du
  module, active seulement pendant son usage ; l'observation place le membre, invisible, sous le joueur observé.
- Vol libre d'une touche (F2 par défaut, réglable dans les raccourcis FiveM) : chaque appui est accordé par le serveur
  (droit `tools`, inscrit au journal) ; sans droit, la touche ne fait rien. Pendant le vol, le membre est invisible
  des autres joueurs (il se voit lui-même) et retrouve ensuite sa visibilité d'avant.

**Exports serveur** :

| Export | Retour |
|---|---|
| `isStaff(source)` | booléen |
| `can(source, droit)` | booléen |
| `rankOf(source)` | `{ name, label, level }` ou `nil` |
| `ban(compte, heures, motif)` | `true, n° du ban` ou `false, code` — au journal sous le nom du module appelant |
| `kick(source, motif)` | `true` ou `false, code` |
| `log(source, libellé, détails?)` | `true` ou `false, code` — inscrit au journal une action d'un membre du Conseil faite dans un module (libellé lu tel quel, 32 caractères ; détails `{ clé = texte ou nombre }`, 8 au plus) ; depuis 1.1.0 |

**Outils des modules** (depuis 1.1.0) : un module ajoute un bouton à la page Outils du Registre par le registre du core
`vava_admin:tools` — clé `<ressource>:<nom>`, `{ label, hint?, permission }` (un droit des rangs). Le bouton n'apparaît
qu'aux membres qui ont ce droit ; un clic revérifie le droit côté serveur, ferme le Registre et déclenche chez ce
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
« Chancellerie : <compte> ». Seule exception à la règle du rang : l'écran des joueurs (droit `watch`, tout le Conseil),
que chacun regarde chez tout le monde, membres du Conseil de tout rang compris. Exports réservés à la ressource-pont (`config.web.bridge`, `vava_chancellerie`) :

| Export | Retour |
|---|---|
| `webRequest({ label, rank }, nom, arguments)` | `true, résultat` ou `false, code` — arguments revalidés avec le schéma de la demande |
| `webCan({ label, rank }, droit)` | booléen |
| `webRanks()` | liste `{ name, label, level }` |
| `webLog({ label, rank }, libellé, détails?)` | `true` ou `false, code` — action d'un compte du panneau faite dans un autre module |

Hook `vava_admin:report` (serveur, `after` : `{ action = created|claimed|closed, id, author }`) : tient le panneau
web à jour.

Pour travailler le rendu sans le jeu : `web/index.html?tab=players` (ou `reports`, `bans`, `logs`, `staff`, `tools`,
`announce`), avec `&dialog=ban`, `&proclaim=1` ou `&watch=1`.

### `vava_voice`

Chat vocal de proximité, sur la voix intégrée à FiveM (Mumble de FXServer, son 3D du jeu) : aucune autre ressource.
Portées, touche, zones, textes : `config.lua`. Demande le core 0.5.0 ; facultatifs : `vava_hud` ≥ 1.2.0 (médaillon),
`vava_health` (portée à terre), `vava_admin` ≥ 1.1.0 (zones de voix).

À poser dans le `server.cfg` (son 3D du jeu, voix envoyée aux seuls joueurs à portée) :

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
  joueur hors de tout salon : il n'entend personne. Le micro s'ouvre à l'apparition confirmée du personnage.
- **À terre** (`vava_health`) : Chuchoter et Parler seulement ; la portée d'avant revient après la réanimation. Relu à
  chaque apparition (déconnecté puis reconnecté à terre : toujours limité).
- **Zones de voix** : lieux où la voix porte plus (tribune, place : ×1,5 à ×3) ou moins loin (bibliothèque, crypte :
  ×0,5, ×0,75) ; cylindre centré sur les pieds de qui le crée (rayon et hauteur, pour séparer les étages). Si des zones
  se chevauchent, la plus petite l'emporte. Créées en jeu par le Conseil (droit `tools`) : outil « Zones de voix » du
  Registre ou `/zonesvoix`. L'éditeur dessine les zones proches dans le monde (teinte selon l'effet) et l'aperçu suit
  les réglages ; centre lu côté serveur, valeurs bornées, chaque action revérifiée et inscrite au journal du Registre.
  « S'y rendre » demande le droit `teleport`. Gardées en base (`vava_voice_zones`, 200 au plus).
- **Fonctionnement** : chaque joueur en jeu écoute son propre salon (`1000 + numéro de joueur`) ; sa parole part vers
  les salons des seuls joueurs à portée, recalculés toutes les 250 ms (Mumble n'est sollicité que si la liste change).
  Aucune boucle par image, sauf pendant le cercle au sol et l'éditeur ouvert.
- **Limite** : la portée est réglée par le client, comme toute voix FiveM ; un client modifié pourrait l'agrandir.
  Le serveur impose ce qu'il peut imposer : la coupure du micro.

| Export serveur | Retour |
|---|---|
| `isActive(source)` | booléen — personnage en jeu, micro ouvert |
| `limitRange(source, raison, maximum)` | `true` ou `false, code` — portée limitée au numéro `maximum` (1 = Chuchoter) pour cette raison (préfixée par la ressource appelante) ; la plus basse des limites s'applique |
| `releaseRange(source, raison)` | `true` ou `false, code` |
| `getZones()` | liste `{ id, label, x, y, z, radius, height, multiplier }` |
| `webUpdateZone(id, nom, rayon, hauteur, effet)` | `true, zone, détails` ou `false, code` — pont de la Chancellerie seulement (1.1.0) ; sans recentrage |
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

### `vava_cameras`

L'écran des joueurs, pour le Conseil : tout membre (droit `watch` de vava_admin, sans règle de rang) regarde tout le
monde, en jeu (**mur des caméras** : outil du Registre ou `/cameras`) ou depuis la Chancellerie (par son pont).
Demande le core 0.5.0 ; facultatifs : `vava_admin` ≥ 1.2.0 (droit, journal, outil du Registre ; sans lui, personne ne
regarde en jeu), `vava_chancellerie` ≥ 1.1.0 (caméras depuis le web). Qualités, limites, adresse STUN : `config.lua`.

- **Capture** : à l'ordre du serveur seulement, le jeu du joueur filmé relie une texture WebGL à l'image du jeu
  (séquence de screenshot-basic : ni Windows, ni Discord, ni les interfaces du jeu) et la dessine hors de l'écran,
  au rythme de la capture (960 × 540, 20 images/s). **Une seule capture**, partagée par tous ceux qui regardent ; chacun
  a sa connexion WebRTC et sa qualité : `tile` (case d'un mur : 480 × 270, 10 images/s, 250 kb/s) ou `full` (vue en
  grand : 960 × 540, 20 images/s, 1,2 Mb/s). Personne ne regarde : ni dessin ni capture.
- **Réseau** : l'image va **directement** du jeu du joueur au spectateur (jeu d'un membre ou navigateur) ; le serveur
  ne relaie que la négociation (une offre et une réponse de quelques Ko par caméra). La connexion montante du joueur
  filmé porte le débit de chaque spectateur ; WebRTC le baisse de lui-même si elle sature. Adresse STUN publique de
  Google par défaut (aucun coût pour le serveur ; elle voit passer l'adresse IP des joueurs à la connexion).
- **Mur en jeu** : grille 1 × 1 à 4 × 4 (touches 1 à 4), pages (flèches), un clic ouvre en grand (flèches : joueur
  précédent ou suivant ; Échap : retour, puis fermeture). Seules les cases de la page affichée ont une caméra, ouvertes
  une à une (150 ms d'écart : un mur 4 × 4 reste sous la limite de messages du core) ; en grand, seule la vue en grand
  reste. Liste des joueurs relue toutes les 5 s, mur ouvert seulement ; caméra perdue retentée après 10 s.
- **Limites** : 6 caméras par joueur filmé, 96 en tout, 2 h au plus ; sans réponse du spectateur en 30 s, la caméra
  s'éteint. Elle s'éteint aussi quand le joueur filmé n'est plus en jeu (sélection, départ) ou que son spectateur ferme
  le mur, revient à la sélection ou part.
- **Journal** du Conseil : l'ouverture du mur et chaque vue en grand (les cases d'un mur sont couvertes par
  l'ouverture). Le joueur n'est pas prévenu : à mentionner dans le règlement du serveur.
- **Sécurité** : chaque demande du membre est une RPC à schéma strict et à débit limité, droit revérifié à chaque
  caméra ; seul le joueur filmé envoie l'offre de sa caméra, seul son spectateur y répond (une fois) ou la ferme.
  Identifiants de caméra tirés au hasard (24 chiffres hexadécimaux). Le WebRTC direct révèle l'adresse IP du joueur
  filmé au spectateur (et inversement) ; derrière certains pare-feux, la connexion directe échoue (aucun relais TURN).
  Avec le DLSS activé, l'image peut inclure les interfaces du jeu.

| Export serveur | Retour |
|---|---|
| `count()` | nombre de caméras ouvertes |
| `webPlayers()` | liste `{ source, label, active }` — pont de la Chancellerie seulement |
| `webStart(joueur, qualité)` | `true, { session, label, iceServers }` ou `false, code` — pont seulement (droit vérifié par le pont auprès du Registre) |
| `webAnswer(session, sdp)` · `webStop(session)` | `true` ou `false, code` — pont seulement |

Hook `vava_cameras:web` (serveur, `after` : `{ session, offer? , ended? }`) : offre et fin des caméras regardées
depuis le web, relayées par le pont à la Chancellerie.

Pour travailler le rendu du mur sans le jeu : `web/index.html?players=11&layout=3` (ou `&focus=<numéro>`) dans un
navigateur ; chaque case est une vraie connexion WebRTC locale filmant une scène dessinée.

### `vava_magic`

La magie : fiche magie par personnage (champ privé `vava_magic:sheet` : mage ou non, sorts et leur XP, sigils gardés,
sigil unique dans tout le royaume), mana (100, +3 toutes les 5 s, jamais sauvegardée), 5 niveaux par sort, incantation
commune, sorts **Murmure** (messages), **Lueur** (lumière) et **Boule de feu** (offensif), grimoire et registre
(objets), commandes du Conseil (`/magie`). Tout le détail, la config et la liste des tests en jeu :
`modules/vava_magic/README.md`. Demande le core 0.5.0 ; facultatifs : `vava_inventory` ≥ 1.3.0 (objets), `vava_hud`
(mana, notifications), `vava_health` (blessures, à terre), `vava_admin` (droit `tools` et journal ; sans lui, ACE
`magie.admin`).

- **Bridge** : `bridge/server.lua` et `bridge/client.lua` sont les seuls fichiers qui appellent le core et les autres
  modules ; les réécrire suffit pour un autre core (avec un équivalent de `core.rpc`).
- **Incantation** : RPC `vava_magic:begin:<sort>` puis `vava_magic:finish:<sort>` (numéro d'incantation). Le serveur
  revérifie à la fin la durée, le déplacement et la vie (lus côté serveur) ; la mana est réservée avant l'effet, rendue
  si le sort refuse. Recharges tenues par personnage. Effets vus des autres : state bags posés par le serveur sur le
  ped (`vava_magic:casting`, `glow`, `light`, `burn`) ou sur l'objet d'un orbe ancré (`vava_magic:orb`).
- **Murmure** : fragments envoyés aux seuls joueurs à moins de 3 m ; registre des murmures en base sous le numéro porté
  par l'objet (métadonnée `registre`), l'historique suit l'objet.
- **Boule de feu** : impact signalé par le client du lanceur, validé par le serveur (portée, axe, délai, cible réelle,
  zones protégées) avant les dégâts, appliqués par `vava_health:damage` ; journal `vava_magic_damage_log`.
- **Verrouillage** (sorts `lockOn`) : touche Tab côté client ; la cible part avec le début de l'incantation, revérifiée
  par le serveur, qui prévient la seule cible (évènement `vava_magic:targeted`) et calcule lui-même la direction ;
  virage vers la cible aux niveaux 4 et 5 (`homing`, pris en compte dans le contrôle d'axe de l'impact).

| Export serveur | Retour |
|---|---|
| `isMage(source)` | booléen — personnage en jeu |
| `spellLevel(source, sort)` | niveau (1 à 5) d'un sort connu, ou `nil` |
| `mana(source)` | mana actuelle, maximum (0 pour un non-mage) |

**Hooks** : `vava_magic:castStarting` (`before`, annulable : `{ source, characterId, spell, level }` — prison, zone…),
`vava_magic:castDone` (`after` : `+ success`), `vava_magic:levelUp` (`after` : `{ source, characterId, spell, level }`),
`vava_magic:mageChanged` (`after` : `{ source, characterId, isMage }`), `vava_magic:murmur:unreachable` (`before` :
`{ source, characterId, reason = offline|too_far, sigil, text }` — renvoyer `false, 'handled'` pour prendre le message en
charge : pigeon voyageur, relais…).

**Ajouter un sort depuis un autre module** : registre du core `vava_magic:spells`, clé = nom du sort.

```lua
core.registry.add('vava_magic:spells', 'echo', {
    config = { label = 'Écho', baseCost = 5, xp = 5, levels = { -- 5 niveaux
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

Pour travailler le rendu sans le jeu : `web/index.html?view=grimoire` (ou `composer`, `offer`, `naming`, `confirm`,
`lueur`, `sealed`, `register`, `messages`, `broken`) dans un navigateur.

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
- **Envoi** : RPC `vava_chat:send` (genre, texte, numéro de joueur | 0, conversation | 0) ; destinataires choisis par le
  serveur, jamais `-1`. Un `/mp` désigne son correspondant par un numéro de conversation jamais réutilisé.

| Export serveur | Retour |
|---|---|
| `addMessage(cible, message)` | `true` ou `false, code` — `cible` : joueur connecté, ou `-1` pour tous les joueurs en jeu ; `message` : texte, `{ author?, text, color? }` ou `{ args, color? }` |

**Hooks** : `vava_chat:sending` (`before`, annulable : `{ source, characterId, kind, text, target? }` — sourdine,
prison… ; la raison du refus est montrée au joueur), `vava_chat:sent` (`after` : `+ recipients`).

### `vava_chancellerie`

Le pont entre la Chancellerie (panneau web, programme à part : voir `docs/chancellerie.md`) et le serveur de jeu.
Serveur seulement (rien n'est envoyé aux joueurs). Demande vava_admin 1.2.0 ; vava_voice 1.1.0 pour les zones de voix,
vava_cameras 1.0.0 pour l'écran des joueurs.

- **Entrée** : l'adresse HTTP du serveur de jeu (`http://127.0.0.1:<port>/vava_chancellerie/…`). N'accepte que les
  requêtes venues de la machine elle-même, portant la clé tirée par la Chancellerie à chaque lancement de FXServer et
  passée en `+set vava_chancellerie_token` (jamais dans le `server.cfg`, masquée dans la console). Sans cette clé
  (serveur lancé sans la Chancellerie), le pont reste fermé.
- **Demandes** : passées telles quelles au Registre (`webRequest`), qui vérifie tout et tient le journal ; zones de voix
  lues, modifiées et supprimées auprès de vava_voice, droit vérifié et journal tenu par le Registre.
- **Caméras** (1.1.0) : ouvertes auprès de vava_cameras une fois le droit `watch` accordé — la vue en grand par la
  demande « écran du joueur » du Registre (`watchScreen` : cible vérifiée, inscrite au journal), les cases d'un mur sur
  le seul droit, l'ouverture du mur étant inscrite au journal (« Mur des caméras ouvert »). Routes : `/cameras/wall`,
  `/cameras/players`, `/camera/start` (`{ actor, target, quality }`), `/camera/answer`, `/camera/stop`.
- **Évènements** vers la Chancellerie (requête HTTP locale, avec la clé) : signalements, arrivées et départs des joueurs,
  offre et fin des caméras du web (hook `vava_cameras:web`), arrêt du module des caméras (`{ type = 'camera', reset }`).
