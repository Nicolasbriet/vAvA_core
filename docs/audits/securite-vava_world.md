# Audit sécurité — vava_world 1.1.0 — 29 octobre 2026 (T-010)

## Périmètre

Rôle de la ressource : le monde du royaume — la carte de GTA vidée de sa population par le serveur
(`SetRoutingBucketPopulationEnabled` par instance), ce que le jeu avait déjà créé retiré au démarrage, et chez chaque
joueur des réglages locaux (budgets de population à zéro, services d'intervention coupés, sons de la ville coupés).

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `server/core.lua`,
`server/population.lua`, `server/api.lua`, `server/main.lua`, `client/core.lua`, `client/population.lua`,
`client/audio.lua`, `client/main.lua` ; section `vava_world` de `docs/api.md`. Le module n'a pas de README, pas de
`bridge/`, pas de `web/`, pas de `sql/`. Non vérifiable ici : la borne réelle des routing buckets de FXServer
(`server/api.lua:12`) et la valeur de `GetEntityPopulationType` côté serveur pour chaque sorte d'entité.

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `prepareBucket(bucket)` (`server/api.lua:14-19`) | export serveur | entier `0..0x7FFFFFFF` (`:16`), sinon `invalid_args` | — | `VavaWorld.ready` (module démarré) sinon `not_ready` (`:15`) | appelable par les ressources serveur seulement (jamais par un client) ; applique `cfg.enabled` à l'instance (`server/population.lua:23-25`) |
| `setup` (`server/main.lua:15-19`) | cycle de vie du core | — | — | — | prépare les instances de `config.population.buckets` puis nettoie une fois (`population.lua:55-60`) |
| `core:character:spawning` (`client/main.lua:18`) | hook client (local) | — | — | — | réapplique les réglages locaux ; natives seulement |

Aucun RPC, aucun `RegisterNetEvent`, aucune NUI, aucun state bag, aucun `GlobalState`, aucun SQL, aucun
`TriggerClientEvent`. Rien de ce module ne peut être déclenché par un client.

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `server/population.lua:38-44` — **nettoyage qui ignore les passagers** — au démarrage, un véhicule ambiant dont le
  siège conducteur est vide est supprimé même si un joueur y est passager (déposé au sol après un `restart
  vava_world` en cours de partie). Robustesse plutôt que sécurité, relevé au passage. Correction : parcourir tous les
  sièges (`GetPedInVehicleSeat` de `-1` au dernier siège) avant de supprimer.
- `config.lua:13-15`, `server/api.lua:14` — **règle des instances portée par un commentaire** — une instance créée par
  un module sans appel à `prepareBucket` garde la population de GTA (défaut de FXServer) ; la règle n'est écrite que
  dans `config.lua` et `docs/api.md:934`, le module n'ayant pas de README (structure demandée par `CLAUDE.md`).
  Correction : README du module ; le jour où un module crée des instances, un point unique de création d'instance
  (core ou vava_world) qui appelle `prepareBucket` lui-même.

## Points solides

- Ce qui compte est décidé côté serveur : la population est coupée par instance avec `SetRoutingBucketPopulationEnabled`
  (`server/population.lua:24`) ; les réglages clients (`client/population.lua`, `client/audio.lua`) ne sont qu'un
  filet local qu'un client modifié ne peut défaire que pour lui-même.
- Le nettoyage initial ne touche que les types de population ambiante (`shared/constants.lua:11-17`), jamais un
  joueur, un véhicule conduit par un joueur ni une entité de script (`population.lua:40`, `:46`).
- L'export vérifie son argument et refuse tout appel avant le démarrage du module ; l'API du core n'est utilisée
  qu'après `setup`.
- Aucun thread, aucune boucle, aucun envoi réseau : surface d'attaque nulle pour un client.

VERDICT : OK
