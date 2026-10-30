# Audit sécurité — vava_farming 1.2.3 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : l'agriculture (parcelles communales ou privées à emplacements, croissance par dates, humidité et fertilité,
qualité en palier, seau rempli aux puits, grenier commun ancré et journalisé, composteur déclaré à l'artisanat,
commandes du Conseil). Le serveur applique chaque geste à sa fin et demande l'XP à `vava_skills`.

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/geometry.lua`,
`shared/growth.lua`, `server/core.lua`, `server/main.lua`, `server/actions.lua`, `server/slots.lua`, `server/granary.lua`,
`server/admin.lua`, `server/commands.lua`, `server/api.lua`, `server/journal.lua`, `server/catalog.lua`,
`bridge/server.lua`, `client/main.lua`, `client/interact.lua`, `client/nui.lua`, `client/props.lua`, `web/js/app.js`,
`web/js/view-menu.js`, `web/js/view-prompt.js`, `web/js/ui.js`, `web/index.html`, `sql/0001_farming.sql`,
`sql/0002_granary_log_minute.sql`, `README.md`. Lus pour ce que le module délègue : `vava_inventory/server/api.lua`,
`operations.lua` (`exchange`, `use`, `guarded`, `resolve`), `main.lua` (RPC), `config.lua` (`anchor`),
`vava_skills/server/api.lua`, `vava_health/server/links.lua` et `shared/constants.lua`, `server/core/rpc.lua`,
`config/server.lua`, `shared/core/hooks.lua`.

Non lus : `web/css`, `web/fonts`, `web/img`, `web/items`, `web/js/strings.js` (textes), `web/js/devmock.js` (hors jeu
seulement, `bridge.js`), `web/js/bridge.js` (identique à celui de la récolte, relu là-bas). Grep `innerHTML` /
`insertAdjacentHTML` / `eval` sur `web/` : aucune occurrence.

Corrections annoncées, retrouvées dans le code : T-003 O1 (dernier modèle réservé à la plante mûre,
`shared/growth.lua:115-121`) et O3 (`/agriculture pousser` arrose la terre et efface la sécheresse,
`server/slots.lua:226-229`) ; T-006 S2 : refus `downed` au menu (`server/actions.lua:156`), au début (`:230`), à la fin
après la chute de la session (`:364-365`), au puits (`:461`), au grenier (`server/granary.lua:85`) ; 1.2.0 : emplacement
écrit aussitôt après semis, compost, récolte, arrachage (`:381`, `:401`, `:425`, `:446`, `slots.lua:271-296`). Le point
MINEUR de la relecture T-006 (grenier ouvert à la chute) est fermé par `vava_health` 1.1.4 qui appelle
`vava_inventory:close` à la mise à terre (`vava_health/server/links.lua:86-88`).

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_farming:open` | RPC | `PARCEL` chaîne 1–32 motif `^[%l%d_]+$`, `SLOT` entier 1–64 (`server/main.lua:27-29`) | 4, +1/s (`config.lua:75`) | personnage, pas à terre, parcelle connue, index ≤ `parcel.count`, distance lue côté serveur (2 + 1,5 m), accès à la parcelle (`actions.lua:153-161`) | menu : lecture seule, données du seul joueur (graines, seau, compost) |
| `vava_farming:begin` | RPC | `PARCEL`, `SLOT`, `ACTION` enum des 5 gestes, `CROP` chaîne ≤ 32 motif `^[%l%d_]*$`, `TIER` entier 0–5 (`main.lua:27-32`, `:68`) | 4, +1/s | idem, plus : une seule session, état réel de l'emplacement (libre / planté / mort / mûr), graines possédées au palier choisi, seau en main avec charges, compost possédé, place pour le produit, hook `acting` annulable, session relue après le hook (`actions.lua:227-324`) | durée du geste rendue par le serveur (faucille comprise, `:326-327`), jeton, oubli après 30 s (`:334-336`) |
| `vava_farming:cancel` | RPC | `TOKEN` entier 1–2³¹−1 (`main.lua:33`) | 4, +1/s | jeton de la session du joueur (`actions.lua:207-210`) | — |
| `vava_farming:finish` | RPC | `TOKEN` | 4, +1/s | session du joueur, durée − 400 ms écoulée (`:361`), jeton consommé avant toute attente (`:364`), pas à terre, distance (`:365-366`), puis **tout est relu** : emplacement libre pour semer (`:372`), graine du palier encore possédée et retirée par `exchange` (`:374-379`), même seau et charges (`:388-391`), compost retiré par `exchange` (`:396`), plante encore mûre (`:405`) | quantité, qualité, palier, graines rendues, XP tirés par le serveur (`:406-426`) |
| `vava_farming:fill` | RPC | `WELL` chaîne 1–32 motif (`main.lua:28`) | 3, +0,5/s | personnage, pas à terre, puits connu, distance, seau en main, pas déjà plein (`actions.lua:459-472`) | charges = métadonnée `water` écrite par le serveur |
| `vava_farming:granary` | RPC | `PARCEL` | 3, +0,5/s | personnage (`main.lua:75`), parcelle, pas à terre, grenier déclaré, accès à la parcelle, distance, ouverture **ancrée** (rayon 3,5 m ≤ `anchor.maxRadius` 25) (`granary.lua:82-96`) | l'inventaire revérifie la distance à chaque geste et ferme à l'éloignement |
| `/agriculture` | commande (`RegisterCommand(…, false)`, `admin.lua:96`) | arguments texte ; parcelle par le catalogue ; index `tointeger` borné 1–count ; valeur `tonumber` 0–100 (`admin.lua:58-60`, `:68-69`) | aucune (commande) | `Bridge.IsAllowed` : console, `vava_admin:can(src, 'metiers')`, sinon ACE `metiers.admin` (`bridge/server.lua:241-247`), avant toute action (`admin.lua:41`) | `fertilite`, `pousser`, `arroser` : journal + Registre (`:63-64`, `:75-76`, `:86-87`) |
| `vava_farming:notify`, `vava_farming:slot` | évènements serveur → client | — | — | vers le seul joueur (`bridge/server.lua:273`, `actions.lua:349`) | aucun envoi à `-1` |
| `GlobalState['vava_farming:parcel:<id>']` | state bag global (écrit par le serveur) | `{ slots = { { crop, stage, state } } }` (`slots.lua:154`) | au seul changement | le serveur ne lit aucun state bag client | connu : T-016 |
| `vava_inventory:move`, `split`, `merge`, `drop` (after) | hooks écoutés | payload de l'inventaire | — | journal par minute et hook `granary` quand un grenier est le départ ou l'arrivée (`granary.lua:62`, `:104-115`) | `use` ne traverse jamais un grenier : l'inventaire n'utilise que depuis la besace (`vava_inventory/server/operations.lua:620-626`) |
| `core:character:unloading`, `core:player:dropped` | hooks écoutés | — | — | session oubliée (`main.lua:86-87`, `actions.lua:214-216`) | déconnexion en plein geste : rien n'est appliqué |
| `getParcel`, `getParcels`, `getSlot`, `getCrop`, `granaryOf`, `registerAccess`, `getSession`, `codexList` | exports (serveur → serveur) | `getSlot` : index borné (`api.lua:45-50`) ; `registerAccess` : genre non vide, fonction ou table appelable (`:66-72`) | — | `not_ready` avant le setup | — |
| registre `vava_farming:crops` | registre du core | `CROP_SCHEMA` : chaînes, nombres et listes bornés (`catalog.lua:20-37`) | — | validé par le core | `yield` : voir MINEUR |
| `begin`, `refresh`, `close` | callbacks NUI | types revérifiés côté client (`client/main.lua:93-98`) puis schéma du RPC | — | rien côté serveur sans RPC ; handlers isolés (`client/nui.lua:32-40`) | — |

Aucun `RegisterNetEvent` ni `RegisterServerEvent` côté serveur (grep sur `server/` et `bridge/`).

## BLOQUANT

Aucun.

## IMPORTANT

- `modules/vava_farming/server/actions.lua:405-424` — **Récolte : l'emplacement n'est vidé qu'après l'ajout à la
  besace** — la plante mûre est vérifiée (`:405`), puis `bridge.Add` du produit (`:413`) et des graines (`:422`) passent
  par `operations.exchange`, qui exécute les hooks `before` de `vava_inventory:add` (`vava_inventory/server/operations.lua:996`)
  avant que `slots.harvest` (`:424`) ne libère l'emplacement. Si un abonné cède la main, deux joueurs qui finissent le
  même geste sur le même emplacement d'une parcelle communale passent tous deux le test de `:405` : deux récoltes pour
  une plante. Aucun abonné ne cède la main aujourd'hui (`vava_health` ne garde que `move/split/merge/drop/use`,
  `vava_health/shared/constants.lua:38` ; `vava_needs` ne suit que `use`) : garde manquante qu'un module à venir rendrait
  exploitable. Même ordre pour l'arrachage (déchets ajoutés `:443` avant `slots.clear` `:445`). La récolte fait l'inverse
  (charge prise avant tout appel qui peut attendre, `vava_gathering/server/harvest.lua:221-222`). Correction : appliquer
  `slots.harvest` (ou `slots.clear`) avant l'ajout et restaurer l'emplacement si la besace refuse (`no_space`), ou poser
  un drapeau d'occupation sur l'emplacement le temps du geste.

## MINEUR

- `modules/vava_farming/server/granary.lua:82-96` — l'accès au grenier n'est vérifié qu'à l'ouverture ; un genre
  branché par `registerAccess` dont la réponse change (foyer quitté) laisse le grenier ouvert jusqu'à l'éloignement.
  Seul le genre `character`, statique, existe aujourd'hui. L'inventaire 1.6.4 offre `close(source, containerId)` : à
  appeler quand le module propriétaire retire l'accès.
- `modules/vava_farming/server/slots.lua:93-95` — `registerAccess` remplace sans garde un genre déjà connu, `character`
  compris : un module serveur mal écrit peut ouvrir toutes les parcelles privées. Durcissement : refuser de remplacer
  un genre existant (`false, 'duplicate'`).
- `modules/vava_farming/server/catalog.lua:30` — `CROP_SCHEMA.yield` n'impose pas `min ≤ max` : une culture tierce
  `{ 5, 2 }` fait lever `math.random` à la récolte (`actions.lua:410`), capturé par le core (`server/core/rpc.lua:144`,
  réponse `server_error`), sans crash mais récolte impossible. Vérifier à l'indexation, comme la récolte pour ses
  ressources (`vava_gathering/server/catalog.lua:104`).
- `modules/vava_farming/server/actions.lua:396-400` — fertiliser à 100 de fertilité consomme le compost pour rien ; le
  menu laisse le geste possible (`:187`). Confort, pas une faille.
- `GlobalState` par parcelle (`slots.lua:154`) : connu, T-016.

## Points solides

- Six RPC à schéma complet (enum des gestes, index borné par le schéma puis par `parcel.count`, `actions.lua:159`,
  `:233`), débits réglés, aucun évènement réseau brut.
- Rien n'est appliqué avant la fin du geste : durée tenue par le serveur (`:361`), jeton consommé avant toute attente
  (`:364`), distance et à terre revérifiés (`:365-366`), état de l'emplacement et objets relus à la fin (`:372`,
  `:388-391`, `:396`, `:405`) ; retraits atomiques par `exchange` (`:379`, `:396`) ; deux `finish` avec le même jeton :
  le second ne trouve rien.
- Charges du seau en métadonnée écrite par le serveur (`:82`, `:391`, `:472`) ; aucun RPC client de l'inventaire n'écrit
  de métadonnées (`vava_inventory/server/main.lua:38-51`).
- Accès à une parcelle privée vérifié au menu, au début du geste et au grenier (`:161`, `:238`, `granary.lua:89`) ; genre
  inconnu refusé par défaut (`slots.lua:100-103`) ; grenier ouvert ancré, chaque dépôt et retrait journalisé par minute,
  attente bornée (`journal.lua:77-81`) ; impossible de consommer depuis le grenier sans passer par la besace.
- SQL paramétré partout (`slots.lua:23-28`, `journal.lua:20-25`, `granary.lua:27-28`) ; écriture immédiate après les
  gestes qui donnent ou consomment des objets, une seule en route par emplacement ; handler en erreur capturé par le
  core : aucun chemin de crash trouvé.
- NUI sans `innerHTML`, callbacks sans effet serveur hors RPC ; droits du Conseil vérifiés côté serveur, journal et
  Registre.

VERDICT : À CORRIGER (un point IMPORTANT : ordre d'application de la récolte et de l'arrachage)
