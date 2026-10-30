# Audit sécurité — vava_codex 1.1.2 — 29 octobre 2026 (T-010)

## Périmètre

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/prefs.lua`, `server/main.lua`,
`server/core.lua`, `server/catalog.lua`, `server/prefs.lua`, `server/suggestions.lua`, `server/commands.lua`,
`bridge/server.lua`, `client/main.lua`, `client/keys.lua`, `client/nui.lua`, `web/index.html`, `web/js/app.js`,
`model.js`, `bridge.js`, `forms.js`, `view.js`, `strings.js` (`errors`, `errorMessage`, `fold`), `README.md`, section
`vava_codex` et « Registre des commandes » de `docs/api.md`, `docs/plan/rapports/T-007.md`. Lus pour les garanties
extérieures : `server/core/commands.lua` du core (schéma du registre : libellés ≤ 64, descriptions ≤ 240, indications
≤ 120, 8 arguments, 24 sous-commandes), `server/players/characters.lua` et `fields.lua` du core (le champ de personnage
n'est écrit que par export serveur, après validation du schéma), `vava_admin/server/api.lua` (`isStaff`, `can`), et les
gestionnaires des commandes du Conseil que le Codex peut lancer dans le périmètre de cet audit (voir plus bas).

Rôle : le livre des commandes et des touches — lit le registre `core:commands`, filtre par les droits du joueur,
compose une ligne et la lance chez le joueur par `ExecuteCommand` ; signets, dernières pages, réglage dans un champ de
personnage.

Non lu : `web/css/style.css`, polices, images ; `web/js/devmock.js` (hors jeu) ; les gestionnaires des commandes de
`vava_magic`, `vava_admin` et `vava_chancellerie` (hors périmètre, relevés par leurs propres audits).

Corrections de T-007 vérifiées dans le code : aucune valeur d'office pour un nombre (`web/js/forms.js:112-159`,
`value = null` tant que rien n'est choisi), saisie bornée par `min`/`max`, arrondie au `step` et à l'entier
(`forms.js:87-107`), préférences ramenées aux maximums de la config (`shared/prefs.lua:17-35`, `server/prefs.lua:59-62`,
spec `tests/spec/codex_prefs_spec.lua`), `recent.max` transmis par le client (`client/main.lua` → `decorate`), focus
rendu à l'arrêt (`client/main.lua:181-185`). Le Codex borne pour le confort : la borne qui compte reste celle du module
cible (ex. `vava_skills/server/progression.lua:253` pour le niveau).

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_codex:open` | RPC | `{}` (`server/main.lua:64`) | 3 puis 0,5/s (`config.lua:37`) | personnage chargé (`prefs.get`, `main.lua:27-28`) ; chaque entrée filtrée côté serveur : `player` pour tous, `console` pour le Conseil en lecture seule, `admin` selon le droit vava_admin déclaré (sinon tout membre), sous-commandes à droit propre retirées (`catalog.lua:56-57,65-96,103-125`) ; « Non décrites » pour le Conseil seul (`main.lua:30-31`) | les listes dynamiques ne sont jamais envoyées à l'ouverture |
| `vava_codex:options` | RPC | `NAME` chaîne 1–64 `^[%w_%-%.:]+$`, `ACTION` chaîne 0–32 sans motif, `INDEX` entier 1–8 (`main.lua:19-21,65`) | 10 puis 3/s | entrée visible du joueur, sous-commande à droit propre refusée (`refused`), argument existant (`catalog.lua:207-215`) ; joueurs : tous pour le Conseil, sinon à 5 m **dans la même instance**, positions lues par le serveur (`catalog.lua:219`, `bridge:91-104`) ; registre et liste de module tronqués à 200 (`catalog.lua:228`, `bridge:141-152`) | le nom du registre ou de la liste vient de la déclaration du module, jamais du client |
| `vava_codex:favorite` | RPC | `NAME`, `BOOL` (`main.lua:66`) | 10 puis 2/s | pose : `canRun` (visible et permis ; `console` accepté en signet), retrait libre ; 24 au plus (`main.lua:37-47`, `prefs.lua:88-100`) | rien d'arbitraire n'entre dans le champ |
| `vava_codex:recent` | RPC | `NAME`, `ACTION` (`main.lua:67`) | 10 puis 2/s | `canRun` : inconnue → `unknown` (sauf Conseil et commande réellement enregistrée), invisible → `refused`, console → `console`, sous-commande gardée **seulement** si déclarée et permise (`catalog.lua:166-182`) ; 12 au plus, sans doublon (`prefs.lua:110-118`) | le reste de la ligne tapée n'est jamais envoyé ni gardé (`client/main.lua:190-196`) |
| `vava_codex:keepOpen` | RPC | `BOOL` (`main.lua:68`) | 10 puis 2/s | personnage | — |
| `suggestions(src)` | export serveur | — | — | mêmes entrées visibles que `open` (`suggestions.lua:51-80`) | appelé par `vava_chat` ; libellés et aides issus du registre (schéma du core), jamais d'un joueur |
| `noteCommand(line)` | export client | nom et second mot extraits, `+`/`-` ignorés (`client/main.lua:190-196`) | celle du RPC `recent` | tout est revérifié par `recent` | — |
| `options`, `favorite`, `keepOpen`, `run`, `refresh`, `close` | NUI | types forcés par le Lua client (`tostring`, `== true`, `tointeger`) (`client/main.lua:150-171`) | — | `run` : ligne ≤ 256 octets dont le premier mot est la commande montrée, notée par `recent` (refus serveur → rien n'est lancé), puis `ExecuteCommand(line)` **chez le joueur** (`client/main.lua:124-137`) | équivalent à taper la ligne dans le chat : aucun pouvoir ajouté |
| Champ `vava_codex:prefs` | champ de personnage | `favorites` liste ≤ 24 × chaîne 1–64, `recent` liste ≤ 12 × `{ name 1–64, action 1–32?, at ≥ 0 }`, `keepOpen` booléen ; visibilité `owner` (`prefs.lua:32-51`) | — | écrit par le serveur seul après `fitPrefs` (`prefs.lua:71-78`) ; le core ne propose aucun RPC d'écriture de champ (`server/players/characters.lua:560-585`) | — |
| `vava_codex:notify` | évènement serveur → client | — | — | ciblé (`bridge:171-177`) | aucun state bag, aucun GlobalState |

**Un joueur peut-il lancer une commande du Conseil par le Codex ?** Non par le Codex lui-même : l'index ne la lui
montre pas, `options` et `recent` la refusent, et le client n'exécute pas une ligne refusée. Par un client modifié
(`ExecuteCommand` direct), oui, comme depuis le chat : la protection est celle du module cible. Vérifié dans le
périmètre : `/artisanat` (`vava_crafting/server/admin.lua:39`), `/metiers` (`vava_skills/server/admin.lua:96`),
`vava_fondateur` (`vava_skills/server/admin.lua:67` + `RegisterCommand(…, true)` ligne 138), `/recolte`
(`vava_gathering/server/admin.lua:37`), `/agriculture` (`vava_farming/server/admin.lua:41`), `/catalogue`
(`vava_inventory/server/catalog.lua:223-225`) revérifient le droit côté serveur. Les « Non décrites » (Conseil) sont des
commandes enregistrées auprès du jeu avec leurs propres contrôles.

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `server/catalog.lua:56-57` et `bridge/server.lua:125-133` — **droit propre d'une sous-commande sans vava_admin** :
  le repli ACE d'une sous-commande est celui de la commande (`def.ace`), à défaut l'ACE du Conseil ; une sous-commande
  déclarée plus restrictive que sa commande est donc montrée et notée à tout détenteur de l'ACE de la commande quand
  vava_admin est arrêté. La commande cible garde ses contrôles ; sans effet avec vava_admin. Accepter un `ace` par
  action dans le registre, ou refuser l'action à `permission` posée quand vava_admin manque.
- `server/main.lua:20` — `ACTION` sans motif (0–32 octets) : la chaîne n'est comparée qu'aux `id` déclarés et jamais
  gardée telle quelle (`known`), mais un motif d'identifiant (`^[%w_%-]*$`) fermerait la question à la porte.
- `server/catalog.lua:225-230` — **copie entière d'un registre** pour un argument `registry` : `core.registry.all`
  recopie toutes les entrées (ex. `vava_inventory:items`) avant la coupe à 200, 10 puis 3 fois par seconde et par
  joueur. Cache court par registre, invalidé par `core:registry:*`.
- `server/catalog.lua:140-155`, `main.lua:30-31` — **inventaire des commandes internes pour tout le Conseil** : « Non
  décrites » liste les commandes serveur de toutes les ressources vAvA (hors `+`/`-` et `_`) à tout membre, quel que
  soit son rang ; information seulement (les commandes refusent qui n'a pas le droit). Réserver la section à un droit
  (`staff`) si l'on veut que le Gardien ne voie pas les commandes du Souverain.
- `server/prefs.lua:43` — `at` sans `max` dans le schéma du champ ; écrit par le serveur (`time()`), sans effet.

## Points solides

- Le serveur décide de ce que chacun voit, entrée par entrée et sous-commande par sous-commande, avec refus par défaut
  quand vava_admin répond mal (`called and allowed == true`) ; `options`, `favorite` et `recent` appliquent les mêmes
  règles que l'index, donc l'interface ne peut rien demander qu'elle ne montre pas.
- Le Codex ne donne aucun pouvoir : la ligne est exécutée chez le joueur comme si elle était tapée ; aucun RPC ne
  porte d'arguments de commande, le serveur n'exécute rien pour le compte du client.
- Les noms de joueurs proposés hors du Conseil sont limités à 5 m et à la même instance, positions lues par le serveur
  ; la liste du royaume n'est jamais donnée à un simple joueur.
- Préférences dans un champ de personnage à schéma strict, écrites par le serveur seul, tronquées aux maximums
  courants ; aucun texte libre du joueur n'y entre (noms validés par `canRun`, sous-commandes par `actionOf`).
- Interface construite par `textContent` uniquement (`view.js:13-18`, `forms.js:11-16`, aucun `innerHTML` dans le
  module) : libellés des modules, noms de joueurs et messages d'erreur y compris ; aucun secret, aucun `-1`, aucun
  state bag.

VERDICT : OK
