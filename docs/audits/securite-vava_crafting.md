# Audit sécurité — vava_crafting 1.2.3 — 29 octobre 2026 (T-010)

## Périmètre

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/quality.lua`,
`server/main.lua`, `server/core.lua`, `server/api.lua`, `server/commands.lua`, `server/admin.lua`, `server/journal.lua`,
`server/catalog.lua`, `server/stations.lua`, `server/signature.lua`, `server/crafting.lua`, `server/repair.lua`,
`bridge/server.lua`, `client/main.lua`, `client/interact.lua`, `client/nui.lua`, `client/props.lua`, `client/core.lua`,
`web/index.html`, `web/js/app.js`, `bridge.js`, `ui.js`, `view-menu.js`, `view-naming.js`, `view-prompt.js`,
`strings.js` (table `errors` et `errorMessage`), `sql/0001_crafting.sql`, `README.md`. Lus pour comprendre les
garanties dont le module dépend : `vava_inventory/server/operations.lua` (`matches`, `validRemovals`, `plan`,
`exchange`), `vava_inventory/shared/constants.lua` (liste des RPC : aucune écriture de métadonnées par le client),
`vava_health/server/api.lua` (`isDowned` ne cède pas la main), `vava_admin/server/api.lua` (`can`, `log`),
`server/players/fields.lua` et `characters.lua` du core (les champs de personnage ne s'écrivent que par export serveur).

Rôle : l'artisanat — stations publiques ou privées, recettes à paliers choisis, qualité, objets signés, poinçon,
baptême, réparation, leçons ; le serveur décide de tout, le client montre, joue le geste et demande.

Non lu : `web/css/style.css`, polices, images (aucune logique) ; `web/js/devmock.js` (hors jeu) ; `web/js/quality.js`
(aperçu client, sans effet serveur : la qualité est recalculée dans `server/crafting.lua:427-430`).

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_crafting:open` | RPC | `STATION` : chaîne 1–32, motif `^[%l%d_]+$` (`server/main.lua:27,62`) | 3 puis 0,5/s (`config.lua:77`) | personnage chargé, pas à terre, station connue, distance lue sur le ped serveur (`stations.lua:115-121`, 2,5 + 1,5 m), accès propriétaire (`crafting.lua:192-201`) | renvoie seulement la besace du demandeur (piles, réparables) |
| `vava_crafting:craft` | RPC | `STATION`, `RECIPE` (1–64, même motif), `CHOICES` : map ≤ 12, clés chaîne 1–64 `^[%w_]+$`, valeurs entier 1–5, facultative (`main.lua:27-29,63`) | 3 puis 0,5/s | personnage, à terre, station, une seule session par joueur, distance, accès, station libre, recette du type de la station, recette connue (vava_skills), niveau, outil en main du bon genre non brisé, combustible, palier par ingrédient ≥ minimum et possédé en quantité, place, hook `before`, puis session et station revérifiées après le hook (`crafting.lua:328-378`) | clé de palier inconnue ignorée (`resolveChoices:306-317`) ; rien n'est consommé au début |
| `vava_crafting:cancel` | RPC | `TOKEN` entier 1–2³¹−1 (`main.lua:30,64`) | 4 puis 1/s | jeton de sa propre session (`crafting.lua:268-272`) | toujours vrai |
| `vava_crafting:finish` | RPC | `TOKEN` | 4 puis 1/s | jeton, durée écoulée à l'horloge serveur (tolérance 400 ms), à terre ; puis distance, outil, combustible, piles relues et retirées par instance au palier de la session, qualité et aléa serveur, échange atomique (`crafting.lua:481-492`, `397-474`) | aucun point de cession entre la relecture des piles et `Exchange` : pas de double fin |
| `vava_crafting:fuel` | RPC | `STATION`, `QUANTITY` entier 1–10 000 (`main.lua:31,66`) | 3 puis 0,5/s | personnage, à terre, station à combustible, distance, accès, réserve restante, possession (`Count`), retrait tout ou rien (`crafting.lua:500-524`) | quantité ramenée à la place libre avant le retrait |
| `vava_crafting:repair` | RPC | `STATION`, `INSTANCE` entier 1–2⁵³ (`main.lua:32,67`) | 3 puis 0,5/s | personnage, à terre, station, session, distance, accès, libre, objet **dans sa besace**, signé (`quality`), recette servie par la station, niveau ≥ moitié, usé ou brisé, coût possédé (`repair.lua:99-140`) ; à la fin : distance, objet encore là, échange puis `patchMetadata` (`repair.lua:146-187`) | le créateur n'est pas touché (patch de `durability`, `max_durability`, `history`, retrait de `broken`) |
| `vava_crafting:setMark` | RPC | `GLYPH` chaîne 1–8 octets (`main.lua:33,68`) | 2 puis 0,2/s | personnage, glyphe dans la liste de la config, rang Compagnon dans une compétence d'artisanat lu chez vava_skills (`signature.lua:84-92`) | champ `vava_crafting:mark`, schéma chaîne 1–8, visibilité `owner` (`bridge:262-264`) |
| `vava_crafting:name` | RPC | `INSTANCE`, `NAME` chaîne 1–128 octets (`main.lua:34,69`) | 2 puis 0,2/s | baptême en attente pour **cet** objet et ce joueur, fenêtre de 5 min à l'horloge serveur, nom validé (2–32 signes, lettres et séparateurs de la config seulement, UTF-8 valide), personnage, objet dans la besace, `crafter_id` = soi, pas déjà nommé (`signature.lua:166-225`) | aucun signe HTML possible dans un nom |
| `core:character:unloading`, `core:player:dropped` | hook | — | — | session et baptême oubliés, station libérée (`main.lua:76-77`, `crafting.lua:528-531`) | déconnexion en plein geste : rien n'a été consommé |
| `core:registry:*`, `core:module:ready` | hook | — | — | caches invalidés, objets et recettes redéclarés (`catalog.lua:236-250`) | — |
| `getStation`, `getStations`, `addStation`, `setFuel`, `registerAccess`, `getRecipe`, `recipesOf`, `getSession`, `getMark` | export | types vérifiés (`api.lua:36-96`) | — | `setFuel` journalisé au nom du module appelant (`api.lua:53`) | ressources serveur seulement |
| `codexList('stations')` | export | — | — | — | identifiants et libellés des stations (`commands.lua:54-63`) |
| `/artisanat stations · station · carburant` | commande | arguments texte | — | droit `metiers` par vava_admin, ACE `metiers.admin` sans lui, console toujours (`admin.lua:39`, `bridge:285-292`) ; combustible borné à la capacité (`stations.lua:179-186`) ; journal du module + Registre du Conseil (`admin.lua:58-59`) | déclarée `scope = 'admin'` au Codex (`commands.lua:27`) |
| `craft`, `repair`, `fuel`, `setMark`, `name`, `nameLater`, `refresh`, `close` | NUI | données relues par le Lua client, types forcés | — | chaque geste à effet passe par un des RPC ci-dessus (`client/main.lua:98-124`) ; `nameLater` et `close` sont locaux | — |
| `vava_crafting:stations`, `vava_crafting:station:<id>` | GlobalState | écrits par le serveur seul (`stations.lua:81,86`) | — | lus par le client pour l'affichage uniquement (`client/props.lua:197-211`) ; aucun state bag n'est lu côté serveur | voir MINEUR (T-015 à T-017) |
| `vava_crafting:notify`, `crafted`, `station` | évènement serveur → client | — | — | toujours vers le seul joueur concerné (`bridge:317`, `crafting.lua:468,522`, `repair.lua:184`) | aucun `-1` |

## BLOQUANT

Aucun.

## IMPORTANT

- `modules/vava_crafting/server/signature.lua:138-147` et `bridge/server.lua` (aucun abonnement au hook
  `vava_inventory:metadata` : `grep` sur tout `modules/` ne trouve d'abonné que dans l'inventaire) — **Signature
  `crafter_*` non protégée contre les écritures des autres modules** — aujourd'hui aucun client ne peut écrire une
  métadonnée (l'inventaire n'a pas de RPC pour cela), mais tout module serveur qui appelle `setMetadata` ou
  `patchMetadata` avec des clés venues de son propre client (un futur éditeur de l'Atelier, une gravure, un outil
  d'inventaire) peut réécrire `crafter_id`, `crafter_name`, `crafted_at`, `mark`, `quality`, `tier` ou
  `max_durability` ; le baptême se fie à `crafter_id` (`signature.lua:210`) et la réparation à `max_durability`
  (`repair.lua:55-59,170-171`) ; le README annonce un « créateur figé » et `docs/api.md` décrit ce hook comme le moyen
  de le garantir. — Correction : dans `bridge/server.lua`, s'abonner en `before` à `vava_inventory:metadata` et refuser
  (`false, 'signature_locked'`) tout `set`/`patch` qui change `crafter_id`, `crafter_name`, `crafted_at`, `mark`,
  `quality`, `tier` ou augmente `max_durability` quand l'écriture ne vient pas de vava_crafting (les appels étant
  synchrones, un drapeau local posé autour des propres `PatchMetadata` du module suffit à reconnaître ses écritures).

## MINEUR

- `server/signature.lua:195-225` — **baptême sans lieu ni état** : le README dit « baptiser depuis la station pendant
  5 min », mais le RPC `name` ne vérifie ni la distance à la station ni `IsDowned`. Doc et code à mettre d'accord :
  garder la station dans `pendingNames` et exiger `stations.near`, ou corriger le README.
- `server/repair.lua:162-178` — **coût consommé avant l'écriture de la réparation** : `Exchange` (ligne 164) retire les
  matières, puis `PatchMetadata` (ligne 173) peut être refusé (hook d'un autre module, `invalid_metadata`) ; le joueur
  reçoit `not_found` et a perdu son coût. Vérifier d'abord que le patch passe (ou rendre le coût par `Add` et
  journaliser si le patch échoue).
- `server/repair.lua:74-78` contre `repair.lua:129-133,163` — **trois comptages différents du coût** : la liste compte
  les seules piles sans `quality`, `begin` compte toutes les piles (`Count` sans filtre), la fin retire par objet sans
  palier ni filtre (les plus anciennes piles, quel que soit leur palier). Aucun gain pour un tricheur ; un seul index
  (`indexPiles`) et un retrait par instance, comme pour une pièce, rendraient le coût prévisible.
- `server/stations.lua:115-121`, `bridge/server.lua:94-109` — **distance sans instance** : un joueur d'une autre
  instance (routing bucket) aux mêmes coordonnées compte comme proche de la station ou comme élève d'une leçon.
  Portée nulle tant que le serveur n'a qu'une instance ; comparer `GetPlayerRoutingBucket` comme le fait vava_codex
  (`vava_codex/bridge/server.lua:95-99`).
- `server/crafting.lua:369` et `web/js/strings.js:127-129` — **raison d'un hook affichée telle quelle** : la raison
  rendue par un module tiers au hook `vava_crafting:crafting` part au client comme code d'erreur et s'affiche si elle ne
  contient pas de `_`. Rendu par `textContent` (aucune injection), mais un texte interne peut être montré. N'afficher
  que les codes connus ou borner la raison.
- `server/signature.lua:84-92`, `server/crafting.lua:500-524` — **poinçon et combustible non journalisés** : actions de
  faible valeur ; à inscrire seulement si le journal doit suivre tout ce qui touche aux objets signés (le poinçon
  apparaît sur chaque pièce).
- `server/main.lua:29` — motif des clés de paliers `^[%w_]+$` plus large que `ID_PATTERN` ; sans effet (clé inconnue
  ignorée), à aligner.
- `server/stations.lua:81,86` — GlobalState pour la liste des stations et l'état de chacune : connu, tâches T-015 à
  T-017.

## Points solides

- Toutes les entrées passent par `core.rpc.register` avec des schémas bornés et des motifs ancrés ; aucun
  `RegisterNetEvent` serveur, aucun `TriggerClientEvent(-1)` ; le bridge isole chaque export par `pcall` et refuse par
  défaut quand un module manque (`KnowsRecipe` → faux, `Items` → vide).
- Rien n'est consommé au début d'un geste : la fin relit les piles, retire **par instance** au palier choisi et ajoute
  le produit dans un seul `exchange` ; de la relecture à l'échange aucune fonction ne cède la main, donc deux `finish`
  simultanés ne produisent qu'une pièce ; une déconnexion, une chute ou un éloignement abandonnent la pièce sans
  perte et libèrent la station (expiration à 2 min ou durée + 30 s).
- Qualité, aléa, palier, signature, durée et fenêtre de baptême sont décidés à l'horloge et aux données du serveur ;
  l'aperçu du client n'est qu'un affichage.
- Nom de baptême en liste blanche de lettres (`utf8.len` strict, séparateurs ni en tête ni doublés) : aucun signe
  HTML possible ; l'interface ne construit que par `textContent` (`web/js/ui.js:9-15`, aucun `innerHTML` dans le
  module).
- Droits du Conseil revérifiés par le serveur (`/artisanat`), actions journalisées au module et au Registre ; SQL
  uniquement par `core.db` et paramétré (`journal.lua:16`, `stations.lua:20-22,68`).

VERDICT : À CORRIGER
