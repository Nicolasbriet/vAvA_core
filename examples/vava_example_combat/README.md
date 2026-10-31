# vava_example_combat — essai de la chaîne de dégâts

Ressource de **développement** (T-110) : de quoi éprouver la chaîne de dégâts commune de `vava_health` 1.3.0 avant
les armes, les techniques et la défense (T-111 à T-116), et un exemple vivant de modificateur pour ces tâches.
**Jamais sur un serveur ouvert au public** : sans `set vava_env dev`, le module refuse de démarrer (« mode
développement absent ») et n'offre rien ; avec, chaque commande est réservée au droit `staff` du Registre (Souverain)
ou à l'ACE `vava.dev`, revérifiée à chaque appel, et chaque coup ou protection posée est inscrit au journal du Registre
(console du serveur sans lui). Délai de 0,5 s entre deux commandes d'un même joueur. Rien n'est écrit en base.

## Commandes (Codex, chapitre « Essais de combat »)

| Commande | Effet |
|---|---|
| `/frapper <n°> <points> [type] [partie]` | coup par `exports.vava_health:hit` (`source` : soi, type `tranchant` par défaut, `tags = { melee, parryable }`) ; au seul lanceur : « appliqué 9, bloqué 3, absorbé 0, résisté 0, ajouté 0 — vie 41 % », « annulé : esquive », ou le code de refus. Aussi depuis la console du serveur (sans source). |
| `/esquive` | fenêtre de 3 s sur soi : le modificateur `vava_example_combat:esquive` (étape `esquive`) annule un coup `melee` qui n'est pas `undodgeable` |
| `/bouclier <points>` · `/bouclier erreur` · `/bouclier non` | réserve d'absorption sur soi : `vava_example_combat:bouclier` (étape `bouclier`) absorbe jusqu'à la réserve ; à 0, « bouclier brisé. » ; `erreur` le fait lever une erreur à chaque coup (essai d'isolement : le coup passe, une ligne d'erreur par minute) |
| `/resistance <type> <pour cent>` · `/resistance non` | `vava_example_combat:resistance` (étape `resistance`) : résiste à ce type (`resisted`), ou, négatif (−100 à −1), le rend plus fort (`added`, faiblesse) |
| `/chaine` | modificateurs déclarés dans l'ordre d'appel (export `modifiers`), puis ses propres réserves |
| `/arme pistolet` · `/arme couteau` · `/arme non` | client : donne ou retire une arme vanilla (`weapons`, provisoires) — pour vérifier que les coups natifs entre joueurs sont annulés |
| `/explosion` | client : explosion vanilla à 3 m devant soi (`explosion`, provisoire) — annulée par le serveur chez les autres |
| `/tricher` | client : vie GTA du ped local remise au maximum (un client qui refuse la vie du serveur) — corrigée en 2 à 3 s |

Les trois commandes clientes demandent d'abord l'accord du serveur (RPC `vava_example_combat:access`, sans argument,
2 appels puis 1 par seconde).

## Les modificateurs, pour les tâches suivantes

Un module déclare **au plus un modificateur par étape**, sous son nom, et lit ses propres données (ici des réserves
en mémoire par joueur, retirées au départ) : changer une réserve ne touche pas au registre.

```lua
core.registry.add('vava_health:modifiers', 'vava_example_combat:bouclier', {
    stage = 'bouclier', label = "Bouclier d'essai",
    apply = function(ctx)                -- copie du coup : target, kind, amount (courant), base, tags, source…
        local taken = math.min(reserve[ctx.target] or 0, ctx.amount)
        if taken > 0 then return { absorbed = taken } end
    end,
})
```

Déclarés au démarrage si le registre existe, puis de nouveau à chaque démarrage de `vava_health` (hook
`core:module:ready`, `name == 'vava_health'`) : le registre disparaît avec lui. Un modificateur ne cède jamais la main
(ni `Wait`, ni base, ni `callClient`) et ne lance pas `hit` lui-même.

## Installation

Avec `set vava_env dev` au `server.cfg` du serveur de test : `ensure vava_example_combat` après `vava_health`.
`vava_health` n'est volontairement pas en `dependency` du manifeste (FiveM arrêterait l'essai à chaque
`restart vava_health` sans le relancer).

## Fichiers

| Fichier | Rôle |
|---|---|
| `config.lua` | accès, commandes, délais, armes et explosion vanilla (`-- PLACEHOLDER`), libellés du journal |
| `shared/guard.lua` | pur : mode développement et accès (même fichier que `vava_example`, testé : `tests/spec/examples_guard_spec.lua`) |
| `server/main.lua` | commandes, modificateurs d'essai, accord des commandes clientes, journal |
| `client/main.lua` | `/arme`, `/explosion`, `/tricher` |

Contrôles en jeu : [docs/tests/combat.md](../../docs/tests/combat.md) § 1.
