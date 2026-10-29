# vava_crafting — l'artisanat du royaume

Forge, établi, métier à tisser, alambic, tannerie, fourneau et table d'arcanes : des **stations** publiques ou privées,
avec leur qualité et parfois leur combustible, où l'on réalise des **recettes** connues avec les matières de son choix.
La qualité d'une pièce vient des matériaux, de la main de l'artisan et de la station, et ne dépasse jamais son niveau.
Les outils, armes, armures, bijoux, objets magiques et grandes potions sont des **objets signés** : qualité, solidité,
créateur figé, poinçon, baptême d'un chef-d'œuvre, histoire des réparations. Réaliser une recette transmise devant un
élève lui vaut une leçon. Le serveur décide de tout et demande l'XP à `vava_skills`.

Ordre de démarrage : après `vAvA_core` (≥ 0.6.0), `vava_inventory` (≥ 1.4.0), `vava_skills` (≥ 1.0.0) et
`vava_gathering` (≥ 1.0.0 : matières et outils de base). Facultatifs : `vava_hud`, `vava_admin` (droit `metiers`),
`vava_chat`.

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Qualité | matériaux × 0,5 + niveau × 0,4 + station × 0,1 ± 5, plafonnée par le niveau | `quality` |
| Paliers | Grossier < 20, Commun, Soigné 40, Excellent 60, Chef-d'œuvre 85 ; palier de matière → qualité 10, 30, 50, 72, 92 | `tiers` |
| Matériaux | palier **choisi par ingrédient** parmi ceux possédés (défaut : le plus bas ≥ minimum) ; consommés par pile, les plus anciennes d'abord | menu |
| Objet signé | `signed`, ou `signedIfQuality` (potions) ; non empilable ; solidité initiale `durability` | `recipes[]` |
| Chef-d'œuvre | palier 5 ; baptême pendant 5 min depuis la station ; nom de 2 à 32 lettres | `masterpiece` |
| Poinçon | glyphe parmi 18, un par personnage, dès Compagnon dans une compétence d'artisanat | `mark` |
| Histoire | création + 5 dernières entrées | `history` |
| Réparation | 25 % des ingrédients (arrondi au-dessus), solidité rendue, solidité maximale − 5, niveau ≥ moitié de la recette, XP 25 %, 4 s | `repair` |
| Durée | base × (1 − niveau × 0,004), 1,5 s au moins | `duration` |
| Station tenue | une pièce jamais finie libère la station après 2 min, ou après sa durée + 30 s si c'est plus long | `interact.expireMs`, `interact.expireMarginMs` |
| Leçons | élèves à 10 m qui ont le niveau, recette `transmission` | `lessons` |
| Combustible | forge : charbon ; fourneau : bois de pin ; 1 par pièce, réserve 20 | `stationTypes[].fuel` |
| Journal | pièces Excellent+ (palier ≥ 4), réparations, baptêmes, leçons, Conseil ; 180 jours | `logTier`, `logRetentionDays` |

### Stations

Un **type** (compétences servies, combustible, animation, prop) et des **instances** placées (position, nom, qualité
0–100, propriétaire : nulle = publique, `{ kind = 'character', id }` = privée ; d'autres genres — foyer — se branchent
par `registerAccess`). Une seule pièce à la fois par station ; état `{ fuel, busy }` publié par le state bag
`vava_crafting:station:<id>`. Les stations livrées sont des **exemples** avec des props du jeu de base.

### Recettes

`config.recipes` → registre `vava_crafting:recipes` (données complètes) et `vava_skills:recipes` (compétence, niveau,
`transmission`, `fragments`). Une recette : ingrédients (objet, quantité, palier minimal), produit, type de station,
outil requis en main (`tools` : marteau de forge), durée, difficulté, XP, signée ou non, solidité. Une recette transmise
inconnue n'apparaît pas dans le menu ; une recette libre au niveau insuffisant apparaît verrouillée.

**Contenu de départ** : charbon de bois et ragoût (fourneau) ; lingots de fer et de cuivre, hache, pioche, faucille,
couteau, épée courte (transmise) à la forge ; marteau de forge, canne à pêche, anneau de cuivre à l'établi ; cuir et
cuir épais (tannerie) ; veste de cuir (couture) ; potion de soin (alambic, signée à partir de 60) ; talisman (table
d'arcanes, transmis, trois fragments). Amorçage : les lingots se fondent sans outil, le marteau se fait à l'établi
sans outil, puis la forge s'ouvre.

### Une pièce

1. `E` près d'une station → menu : recettes connues ici, paliers possédés par ingrédient avec **aperçu de qualité**,
   réparables, combustible, poinçon.
2. Façonner → le serveur vérifie : station à portée, accessible et libre ; recette connue, au niveau ; outil en main du
   bon genre, non brisé ; combustible ; paliers choisis valides et possédés ; place ; hook `vava_crafting:crafting`.
3. Geste et barre du HUD ; se déplacer interrompt.
4. Fin : durée et distance revérifiées (trop loin : la pièce est abandonnée, rien n'est consommé, la station est
   libérée aussitôt), outil et combustible, piles relues et **consommées par instance** au palier choisi, qualité
   tirée, objet signé (`quality`, `tier`, `durability`, `max_durability`, `crafter_id`, `crafter_name`, `mark`,
   `crafted_at`, `history`) ou produit simple (`tier`), **échange atomique**, combustible, XP, leçons, baptême proposé
   pour un chef-d'œuvre, journal, hook `crafted`.

### Réparation

Depuis le menu, sur un objet signé usé ou brisé dont la recette est servie par la station : une part des ingrédients,
la solidité revient à une maximale réduite de 5, l'histoire garde « réparation par … », `broken` disparaît ; le
créateur n'est jamais touché. Finir trop loin abandonne la réparation (rien n'est consommé) et libère la station.

## Base de données (sql/0001_crafting.sql)

`vava_crafting_stations` (combustible), `vava_crafting_log`. Le poinçon vit dans le champ de personnage
`vava_crafting:mark`. Écriture groupée toutes les 10 s et à l'arrêt.

## API

Exports : `getStation(id)`, `getStations()`, `setFuel(id, n)`, `registerAccess(kind, fn(ownerId, characterId))`,
`getRecipe(id)`, `recipesOf(type)`, `getSession(joueur)`, `getMark(personnage)`. Hooks : `vava_crafting:crafting`
(before, annulable : `{ source, characterId, station, recipe, item }`), `crafted` (after : `+ quantity, quality, tier,
signed, instanceId`), `repaired` (after : `{ source, characterId, station, recipe, item, instanceId, maxDurability }`).
Détail : `docs/api.md`.

## Conseil (droit `metiers`)

`/artisanat stations` · `/artisanat station <id>` · `/artisanat carburant <id> <n>`.

## Tests en jeu

1. **Amorçage** : bois de pin au fourneau (alimenté en bois) → charbon ; minerai → lingots à la forge (alimentée en
   charbon, sans outil) ; lingot + pin à l'établi → marteau de forge **signé** (Grossier à bas niveau).
2. **Outil en main** : hache à la forge sans marteau → « Il vous faut un marteau de forge en main » ; marteau en main
   (emplacement Mains) → la hache se forge, signée, avec créateur et poinçon s'il est choisi.
3. **Paliers** : deux piles de minerai de paliers différents → le menu propose les deux, l'aperçu de qualité change ;
   la pile du palier choisi est consommée.
4. **Plafond** : à bas niveau, matières de palier 5 → qualité plafonnée au niveau.
5. **Poinçon** : onglet Poinçon verrouillé sous Compagnon ; dès 40, choisir un glyphe → il apparaît sur les objets
   suivants (fiche de l'inventaire).
6. **Chef-d'œuvre** : `/metiers niveau <id> alchimie 100` et herbes de palier 5 → potion palier 5, boîte de baptême,
   nom visible sur la fiche ; après 5 min, trop tard.
7. **Leçon** : un joueur qui connaît l'épée (fondateur) la forge à moins de 10 m d'un élève de forge ≥ 30 → leçon
   notifiée aux deux, visible dans le livre des compétences ; trois leçons → l'élève voit la recette au menu.
8. **Réparation** : hache brisée (métadonnées) → onglet Réparation : coût, bouton ; après le geste : 95 / 95, plus
   brisée, histoire « Réparation par … », créateur intact.
9. **Occupation** : deux joueurs sur la même station → le second lit « Quelqu'un travaille déjà ici ».
10. **Privée** : station avec `owner = { kind = 'character', id = n }` → les autres lisent « ne vous appartient pas ».
