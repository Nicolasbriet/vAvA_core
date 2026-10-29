# Audit sécurité — vava_needs 1.1.2 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : faim et soif des personnages, baisse décidée par une boucle serveur, paliers d'effets, consommation des objets
à effets de l'inventaire par ses hooks, exports pour les autres modules.

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/starvation.lua`,
`server/main.lua`, `server/core.lua`, `server/state.lua`, `server/decay.lua`, `server/consume.lua`,
`server/api.lua`, `client/main.lua`, `client/effects.lua`, `client/hud.lua`, `client/core.lua`. Pour le contexte :
`modules/vava_inventory/server/operations.lua:620-675` (hook `vava_inventory:use`, `consumed`),
`modules/vava_health/server/links.lua:1-40` (garde à terre, priorité 10) et `server/api.lua:58-64` (export
`damage`), `server/players/fields.lua:100-110` (validation des champs), `docs/api.md` § vava_needs.

Non lus : `web/icons/*.svg` (images), `README.md` et `docs/tests/besoins.md` (procédures).

## Points d'entrée

Le module n'enregistre **aucun RPC** et aucun évènement réseau serveur (`server/main.lua:4`, `:19-28`) : le seul
geste du joueur est l'utilisation d'un objet, validée par l'inventaire (schéma, débit `use` 4 en rafale 1/s,
besace propre, hooks). Les deux évènements émis vont au seul joueur concerné (`decay.lua:131`, `consume.lua:81`).

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_inventory:use` (`before`) | hook | payload de l'inventaire `{ source, item, category, effects }`, `effects` déjà borné par le registre (8 entrées, −1000..1000, `vava_inventory/server/items.lua:46-50`) | celle du RPC `use` | geste en cours (`busyUntil`, `consume.lua:48`), satiété à partir de 95 pour chaque besoin que l'objet comble (`:52-63`) ; un objet à effet étranger n'est jamais refusé pour satiété (`:50`) | refus rédigé montré au joueur par l'inventaire |
| `vava_inventory:use` (`after`) | hook | idem + `consumed` | — | n'applique rien si l'unité n'a pas été réellement retirée (`:68`) ; délai de 3 s posé (`:74`) ; valeurs bornées et arrondies à l'écriture (`state.lua:35-45`, `:94-109`) ; geste choisi par le serveur d'après la catégorie (`:80-81`) | — |
| `core:character:loaded` / `unloading` | hook | payload du core | — | personnage actif revérifié après l'attente d'un autre abonné (`decay.lua:62-65`) | — |
| boucle de baisse | interne | — | un passage par minute, échantillon toutes les 15 s (`decay.lua:210-222`) | course lue sur le ped **serveur** (`GetEntityVelocity`, hors véhicule, `:75-81`) ; hook `vava_needs:decay` annulable, temps suspendu non rattrapé (`:104-112`) ; dégâts calculés serveur et envoyés au seul joueur (`:126-131`) | voir IMPORTANT 1 |
| `get`, `set`, `add` | export | cible entier avec personnage suivi (`api.lua:24-30`) ; `{ besoin = nombre fini }` non vide, besoins connus, `set` 0..100, `add` −100..100 (`:37-46`, `:64`, `:74`) | — | `GetInvokingResource` transmis au hook `vava_needs:changed` (`:49-51`) ; résultat borné (`state.lua:35-39`) | — |
| `setModifier`, `removeModifier` | export | clé `^[%w_%-%.:]+$` ≤ 64, multiplicateurs 0..10 (`api.lua:85-86`) | — | une clé n'est reprise ou retirée que par la ressource qui l'a posée (`decay.lua:159-164`, `:171-177`) ; purge à l'arrêt du module poseur (`server/main.lua:41-43`) | — |
| `vava_needs:state` | champ (visibilité `owner`) | `{ hunger?, thirst? }` nombres 0..100 (`state.lua:50-62`) | — | écrit par le seul serveur via le core, envoyé au seul propriétaire ; aucun state bag public, donc rien qu'un client puisse réécrire | — |
| `vava_needs:starve` | évènement serveur → client | nombre | — | **appliqué par le client** (`client/effects.lua:106-112`), borné à la somme des dégâts configurés (`client/main.lua:20-21`, `:64-66`) | voir IMPORTANT 1 |
| `vava_needs:consume` | évènement serveur → client | nom de geste | — | geste pris dans la configuration, sinon ignoré (`client/effects.lua:116-118`) | — |
| `get` (client) | export client | — | — | copie des valeurs locales (`client/main.lua:83-88`) | lecture seule |

## BLOQUANT

Aucun.

## IMPORTANT

- `modules/vava_needs/server/decay.lua:131` et `client/effects.lua:106-112`, `:52-62` — **perte de vie et fatigue d'un besoin épuisé appliquées par le client** — un client modifié qui ignore `vava_needs:starve` (ou rétablit `SetPlayerMaxStamina`) ne perd jamais de vie ni d'endurance par la faim ou la soif : le serveur garde des valeurs justes mais aucune conséquence n'est tenue de son côté, alors que CLAUDE.md § Sécurité 1 et `docs/plan/COMBAT_V1.md` veulent tous les dégâts décidés côté serveur par `vava_health`. `docs/api.md` le documente (« La perte de vie est appliquée par le client »), ce qui n'en fait pas une décision du porteur listée dans CLAUDE.md. Correction : quand `vava_health` est démarré, appliquer la perte côté serveur par `exports.vava_health:damage(src, damage)` (`vava_health/server/api.lua:58-64` → `life.adjust`, qui tient la vie et l'état « à terre » côté serveur et prévient lui-même le client) et ne garder l'évènement client, avec son plancher, que pour le repli sans vava_health ; l'endurance reste un effet GTA purement client, à accepter comme tel ou à doubler d'un modificateur serveur si l'on veut une conséquence incontournable.

## MINEUR

- `modules/vava_needs/server/decay.lua:75-81` — **part de course lue sur une vitesse répliquée par le client** — la vitesse du ped côté serveur vient de son propriétaire : un client qui ment sur sa vitesse obtient la baisse au repos en courant (facteur 1 au lieu de 1,5), aucun gain d'objet. Inhérent à OneSync ; à garder en tête si la part de course prend un jour plus de poids (endurance, fatigue). Correction possible : comparer la distance parcourue entre deux échantillons aux positions serveur plutôt qu'à la vitesse annoncée.
- `modules/vava_needs/server/consume.lua:46-47`, `:72-73` — **joueur sans suivi : objet consommé sans effet ni délai** — si `decay.entry(src)` manque (personnage chargé avant le redémarrage du module sans `adoptActive`, ordre des abonnés de `core:character:loaded`), `before` laisse passer et `after` ne fait rien : une unité perdue pour le joueur, aucun gain. Correction : dans `before`, suivre le personnage à la volée (`decay.track` à partir de `core.characters.getActive`) plutôt que d'ignorer.
- `modules/vava_needs/server/api.lua:92-97` — **`removeModifier` sans borne sur la clé** — `type(key) == 'string'` suffit ; une clé géante n'a d'autre effet qu'une recherche de table. Alignement avec `setModifier` (`:85`) pour la cohérence.

## Points solides

- Aucune entrée réseau propre : tout ce que le joueur peut faire passe par le RPC `use` de l'inventaire, déjà borné et limité ; les deux évènements sortants ne vont qu'au joueur concerné.
- La baisse, les paliers, le délai de 3 s et la satiété sont décidés côté serveur, avec des valeurs bornées et arrondies à chaque écriture (`state.lua:35-45`, `:94-109`) ; la course est lue sur le ped serveur, hors véhicule.
- Les effets ne s'appliquent que si l'inventaire confirme qu'une unité a été retirée (`consume.lua:68`) : pas de double effet quand un `onUse` cède la main.
- Exports défensifs : nombres finis dans leurs bornes, besoins connus, clés de modificateur motif + longueur, propriété par `GetInvokingResource`, purge à l'arrêt du module poseur.
- Le client borne ce qu'il reçoit (`MAX_DAMAGE`, geste pris dans la config) et n'affiche que des textes de configuration.

VERDICT : À CORRIGER
