# Audit sécurité — vava_appearance 1.0.1 — 29 octobre 2026 (T-010)

## Périmètre

Rôle : l'apparence des personnages — champ de personnage `vava_appearance:data` (visibilité `owner`), schéma strict,
RPC de création « personnage + apparence » en une intention, application sur le ped à chaque apparition, exports client
pour les interfaces (création, coiffeur, couturière).

Fichiers lus en entier : `fxmanifest.lua`, `config.lua`, `shared/constants.lua`, `shared/appearance.lua`,
`server/schema.lua`, `server/main.lua`, `client/apply.lua`, `client/main.lua`, `README.md`. Côté core, ce que la
RPC déclenche : `server/players/characters.lua` (`create`, `encodeInitialFields`, `validateName`), `server/players/
fields.lua` (visibilités), `shared/lib/schema.lua` (compilation réseau).

Non lus : aucun fichier du module n'a été laissé de côté (le module n'a ni NUI ni SQL).

## Points d'entrée

| Entrée | Type | Schéma et bornes | Limite de débit | Revérifications serveur | Remarque |
|---|---|---|---|---|---|
| `vava_appearance:create(firstName, lastName, sex, appearance)` | RPC (`server/main.lua:42-45`) | noms 1..96 o (`:19`, = 24 caractères × 4 octets du core), sexe 1..8 o (`:20`), apparence = `VavaAppearance.SCHEMA` strict (`server/schema.lua:19-63`) : héritage 0..45 et mélanges 0..1, 20 traits exactement dans [−1, 1], coupe 0..2000 et variante 0..255, couleurs 0..63, yeux 0..31, ≤ 11 overlays `{id 0..12, style 0..255, opacity 0..1, color 0..63}`, ≤ 12 vêtements `{id 0..11, drawable 0..2000, texture 0..255}`, ≤ 8 accessoires `{id 0..7, drawable −1..2000, texture 0..255}` ; toute clé inconnue refusée (réseau : `strict` obligatoire, `shared/lib/schema.lua:139-142`) | 2 puis 1/20 s (`config.lua:21`) | `core.characters.create` : session en état `joined` sous verrou (`characters.lua:518-521`, `:202-221`), maximum par compte (`:290-292`), noms et sexe revalidés (`:294-296`), champ initial revalidé par le schéma du champ (`:227-242`), tout ou rien avant l'écriture | `NaN`/`±inf` refusés par le core ; les entiers arrivés en flottant sont normalisés par le RPC puis par `VavaAppearance.normalize` (`shared/appearance.lua:76-86`) |
| champ `vava_appearance:data` | champ de personnage (`server/main.lua:37-40`) | même schéma | — | écrit seulement par le serveur (`core.characters.set`) ou à la création ; **aucun RPC client ne l'écrit** (seuls `core:characters:*` existent : `shared/init.lua:47-54`) ; visibilité `owner` : envoyé au seul propriétaire (`fields.lua:111-116`) | le jeu synchronise lui-même le ped pour les autres joueurs |
| `core:character:spawning`, `core:character:fieldChanged` | hooks client | — | — | — | applique la valeur reçue du serveur (`client/main.lua:20-29`) |
| `defaultAppearance`, `apply`, `applyPart`, `limits`, `textureCount`, `palettes` | exports client (locaux) | `applyPart` vérifie la forme de chaque partie (`client/apply.lua:118-140`, `:157-164`) | — | — | n'agissent que sur un ped du client appelant |

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `modules/vava_appearance/server/schema.lua:42` et `shared/constants.lua:22` — `overlays[].id` est borné à 12 alors
  que le module n'en définit que 0 à 10 (`constants.lua:33-45`) : les identifiants 11 et 12 (imperfections du corps,
  valides pour GTA) passent le schéma et sont appliqués sans type de couleur. Sans danger ; borner à `#OVERLAYS − 1`
  ou déclarer les deux entrées manquantes, pour que le schéma dise la même chose que la table.
- `modules/vava_appearance/server/schema.lua:38-62` — aucune unicité des `id` dans `overlays`, `components`, `props` :
  douze entrées `{ id = 11 }` passent (la dernière gagne). Taille bornée par les `max`, donc sans coût ; une
  vérification d'unicité dans `createWithAppearance` (`server/main.lua:27-31`) fermerait la bizarrerie.
- `modules/vava_appearance/config.lua:18-19` — `maxDrawable = 2000` et `maxTexture = 255` sont volontairement larges
  (packs à venir, documenté `README.md:17`) : un client modifié pose un `drawable` inexistant, que le jeu ignore ou
  affiche mal, chez lui comme chez les autres (synchronisation du jeu). Cosmétique ; resserrer quand les packs seront
  connus, ou faire valider par `GetNumberOfPedDrawableVariations` côté client au moment de l'affichage.
- `modules/vava_appearance/server/main.lua:20` — `SEX_ARG` admet 8 octets quelconques alors que le core n'accepte que
  `m`/`f` (`config/server.lua:59`) : le refus arrive bien (`invalid_sex`), mais un `enum = cfg.sexes` dans le schéma
  réseau éviterait l'aller-retour (les sexes sont dans la config serveur du core, non partagée : à défaut, `max = 1`).
- Décision encore à prendre, notée sans trancher (`README.md:67-69`) : `core:characters:create` reste ouvert aux
  clients à côté de cette RPC ; un client modifié crée un personnage sans apparence (ped par défaut), tout le reste
  (maximum, noms) s'appliquant.

## Points solides

- Un seul chemin d'écriture, entièrement validé : le schéma réseau est le même que celui du champ, strict, borné
  nombre par nombre et liste par liste ; les valeurs négatives sont refusées partout sauf le `−1` « aucun » des
  accessoires ; le core revalide encore le champ avant l'insertion et refuse la création entière en cas d'échec
  (`characters.lua:297-298`).
- Le champ n'est jamais écrit par un client : aucun RPC d'écriture n'existe ; `owner` garantit qu'il ne part qu'au
  propriétaire (≈ 1,5 Ko une fois, à l'apparition).
- Aucun calcul client cru : le client applique ce que le serveur lui a envoyé ; les exports ne touchent que des peds
  locaux et rejettent une partie mal formée au lieu de laisser une native lever.
- Aucune boucle, aucun évènement émis par le module, aucun SQL propre, aucune interface : surface réseau réduite à une
  RPC à débit très bas.

VERDICT : OK
