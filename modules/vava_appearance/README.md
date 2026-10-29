# vava_appearance — l'apparence des personnages

Le visage, les cheveux, la peau et la tenue de chaque personnage : gardés dans un champ du personnage, validés par le
serveur, posés sur le ped à chaque apparition, écran encore noir. Le module n'a pas d'interface : il fournit les
fonctions d'apparence à celles qui en ont une (l'éditeur de `vava_characters_ui` aujourd'hui, un barbier ou une
couturière demain).

Ordre de démarrage : après `vAvA_core` (≥ 0.3.0), avant `vava_characters_ui`, qui en dépend. Aucune autre
dépendance ; aucune table en base (l'apparence vit dans `vava_characters.data`).

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Emplacements de vêtements proposés (id GTA) | haut, sous-haut, bras, bas, chaussures : `11, 8, 3, 4, 6` | `components` |
| Accessoires proposés (id GTA) | couvre-chef, lunettes, boucles d'oreilles : `0, 1, 2` | `props` |
| Bornes des vêtements, côté serveur | modèle 0 à 2 000, variante 0 à 255 (larges : les packs de vêtements ajoutés plus tard passent) | `maxDrawable`, `maxTexture` |
| Créations par joueur | 2 d'affilée, puis une toutes les 20 s | `createRateLimit` |
| Apparence de départ, par sexe | héritage (mère 21, père 0), coupe 4, sourcils, tenue de base ; le reste à 0 ou « aucun » | `defaults.m`, `defaults.f` |

Les bornes fixées par le jeu (46 visages d'héritage, 20 traits du visage, 32 couleurs d'yeux, 64 couleurs, overlays
de tête) sont dans `shared/constants.lua` : elles ne se règlent pas.

## L'apparence

Un champ de personnage, `vava_appearance:data`, de visibilité `owner` : il ne part qu'au joueur concerné, et c'est le
jeu qui synchronise l'aspect du ped chez les autres joueurs. Format (listes pures et tables à clés nommées, pour une
sérialisation sans perte) :

| Partie | Contenu |
|---|---|
| `heritage` | `mother`, `father` (visages 0 à 45), `shapeMix`, `skinMix` (mélanges 0 à 1) |
| `features` | 20 traits du visage, de −1 à 1 |
| `hair` | `style`, `texture`, `color`, `highlight` |
| `eyeColor` | 0 à 31 |
| `overlays` | `{ id, style, opacity, color }` : imperfections, barbe, sourcils, rides, maquillage des yeux, fard à joues, teint, marques du soleil, rouge à lèvres, taches de rousseur, pilosité du torse ; `style` 255 = aucun |
| `components` | `{ id, drawable, texture }` pour chaque emplacement de `components` |
| `props` | `{ id, drawable, texture }` pour chaque accessoire de `props` ; `drawable` −1 = aucun |

- **Création** : la RPC `vava_appearance:create(prénom, nom, sexe, apparence)` crée le personnage et son apparence en
  une seule intention. L'apparence passe un schéma strict (aucune clé inconnue, chaque nombre et chaque liste bornés) ;
  le prénom, le nom et le sexe sont validés par le core avec ses propres règles (`characters.name`). La création est
  « tout ou rien » : jamais un personnage sans apparence par ce chemin.
- **Application** : à chaque apparition (hook client `core:character:spawning`, écran noir), puis à chaque
  changement du champ. Un personnage sans apparence (créé par un autre chemin, voir plus bas) garde le ped par défaut.
- **Modifier** l'apparence d'un personnage chargé (barbier, couturière…) :
  `core.characters.set(id, 'vava_appearance:data', apparence)` côté serveur ; le client concerné la réapplique.

## Pour les autres ressources (exports client)

| Export | Rôle |
|---|---|
| `defaultAppearance(sexe)` | apparence de départ d'un sexe (`config.defaults`) |
| `apply(ped, apparence)` | pose une apparence complète |
| `applyPart(ped, partie, valeur)` | pose une seule partie (`heritage`, `feature` `{ index, value }`, `hair`, `eyeColor`, `overlay`, `component`, `prop`) : c'est ce qui rend un aperçu fluide ; une valeur mal formée est ignorée (rend `false`) |
| `limits(ped)` | bornes réelles du modèle : nombre de coupes, de vêtements par emplacement, de styles par overlay, de couleurs |
| `textureCount(ped, genre, id, modèle)` | variantes d'un vêtement, d'un accessoire ou d'une coupe |
| `palettes()` | couleurs réelles des cheveux et du maquillage (pastilles fidèles), calculées une fois |

Format complet et API : `docs/api.md`, section `vava_appearance`.

## Sécurité et coût

- Le serveur ne croit que ce qui passe le schéma (`server/schema.lua`) : un client modifié ne peut écrire qu'une
  apparence aux bornes du jeu, pour son propre personnage, au moment de sa création.
- Aucune boucle, aucun évènement envoyé par le module : la valeur part avec le personnage (champ `owner`), une fois.
- Le RPC du core `core:characters:create` reste ouvert aux clients à côté de `vava_appearance:create` : un client
  modifié peut créer un personnage **sans apparence** (ped par défaut ; le maximum par compte et les règles de nom
  s'appliquent toujours). C'est une décision en attente du porteur du projet (compte rendu de T-004).

## Assets à brancher

Rien n'est marqué `-- PLACEHOLDER` ici, mais les vêtements proposés sont ceux de GTA : quand les packs médiévaux
arriveront, seules `components`, `props`, `defaults` et, si besoin, `maxDrawable` changeront.

## Fichiers

| Fichier | Rôle |
|---|---|
| `config.lua` | emplacements proposés, bornes serveur, débit des créations, apparences de départ |
| `shared/constants.lua` | bornes du jeu, overlays et leur type de couleur, nom du champ |
| `shared/appearance.lua` | apparence de départ d'un sexe, normalisation des nombres (entiers arrivés en flottants) |
| `server/schema.lua` | schéma strict d'une apparence (champ et argument réseau) |
| `server/main.lua` | déclaration du champ et de la RPC de création |
| `client/apply.lua` | application complète ou par partie, limites du modèle, palettes |
| `client/main.lua` | application à chaque apparition, exports |

## À vérifier en jeu

Procédure complète : `docs/tests/personnage.md`, section 3 (apparence) et tests 9-4, 9-5 (redémarrage). En priorité :

1. Créer un personnage avec une apparence travaillée : le personnage en jeu est identique à l'aperçu, et aucun ped
   par défaut n'apparaît avant l'apparence (elle est posée écran noir).
2. Se reconnecter : apparence identique.
3. **(2 joueurs)** Chacun voit l'autre tel qu'il s'est créé (synchronisation assurée par le jeu, pas par le module).
4. `restart vava_appearance` en jeu : le ped garde son apparence ; `vava_characters_ui` s'arrête avec lui (il en
   dépend) et se relance par `ensure vava_characters_ui`.
