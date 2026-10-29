# L'Atelier du Conseil — référence de conception

Les éditeurs en jeu d'Eldoria. Ce document est la référence des agents pour toutes les tâches de la phase 3
(socle et créateurs du monde) et de la phase 6 (arts : gestes, techniques, effets, sorts). Les maquettes validées
par le porteur du projet sont dans `docs/maquettes/` (et sur le canevas « L'Atelier du Conseil ») : **l'interface
réalisée doit leur ressembler**, écran par écran.

## Pourquoi

1. Faire vivre le serveur sans développeur : ajouter une mine, une forge, une confrérie, un sort se fait en jeu.
2. Préparer l'arrivée de la carte médiévale : toutes les coordonnées seront à refaire ; avec l'Atelier, le staff
   replace tout en jeu, sans toucher au code.
3. Régler le jeu vite : une fenêtre de frappe, une repousse, un coût de mana se changent en quelques secondes,
   sans redémarrer.

## Architecture

### Une ressource `vava_atelier`

Elle porte ce qui est commun à tous les éditeurs, une seule fois :
- **l'interface NUI unique** (accueil, cadre des écrans, formulaires, frise, grille de droits, calques), dans le
  style des maquettes et de `vava_ui` ;
- **l'outil de placement** côté client (voir plus bas) ;
- **le cycle de vie des définitions** côté serveur (brouillon, essai, publié, versions, journal) ;
- **le registre des éditeurs** `vava_atelier:editors`, que chaque module remplit.

Elle ne connaît **aucune règle de jeu**. Chaque module reste maître de ses données : c'est lui qui valide et
applique une définition.

### Ce que déclare un module

```lua
-- dans vava_gathering/server/atelier.lua (exemple de forme, la spec T-101 fixe la forme exacte)
core.registry.add('vava_atelier:editors', {
    id = 'vava_gathering:zones',
    family = 'monde',                       -- monde | societe | arts
    label = 'Récolte',
    description = 'Forêts, mines, prairies et coins de pêche, arbres et filons un par un.',
    right = 'metiers',                      -- droit vava_admin requis
    kinds = {                               -- types de définitions éditables
        zone = { schema = ZONE_SCHEMA, placement = 'circle' },
        node = { schema = NODE_SCHEMA, placement = 'prop', parent = 'zone' },
    },
    validate = function(kind, def) ... end, -- règles du module (renvoie true ou false, err)
    apply = function(kind, def, version) ... end, -- recharge à chaud
    remove = function(kind, id) ... end,
})
```

Le **schéma** d'un champ porte aussi ce qu'il faut pour l'afficher simplement : `label` en mots du jeu
(« Récoltes avant repos », pas `charges`), `help` (une phrase), `unit`, bornes, `widget` (`slider`, `segmented`,
`select`, `toggle`, `text`, `duration`, `item`, `model`, `gesture`, `effect`). L'interface générique sait afficher
80 % des éditeurs à partir du schéma seul. Les **widgets spéciaux** vivent dans `vava_atelier` : frise des phases
(combat), grille grades × droits (confréries), calques d'effets (magie), liste d'effets de jeu (sorts).

### Où vivent les définitions

- **La config reste la graine** : au premier démarrage, ce qui est en config est importé en base comme version 1.
  Ensuite **la base fait foi**. Une valeur de config modifiée après coup ne remplace jamais une définition en base
  (sinon on écraserait le travail du staff) ; une commande du Conseil permet de réimporter explicitement.
- Table commune `vava_atelier_definitions` : `editor`, `kind`, `id`, `version`, `status` (`draft`, `trial`,
  `published`, `archived`), `data` (JSON validé), `author`, `created_at`. Une ligne par version : l'historique est
  gratuit et le retour arrière est une publication de l'ancienne version.
- **Export / import JSON** d'un éditeur ou de tout l'Atelier : sauvegarde, et passage du serveur de test au serveur
  de jeu.

### Cycle de vie

| Statut | Qui le voit | Usage |
|---|---|---|
| Brouillon | l'auteur et les membres du Conseil ayant le droit | on construit, rien n'existe en jeu pour les joueurs |
| Essai | l'auteur, en jeu, réellement | « Tester la récolte », « Essayer contre un mannequin », sort lançable par son seul créateur |
| Publié | tout le monde | rechargé à chaud par le module, envoyé aux joueurs concernés |
| Archivé | le Conseil | ancienne version, restaurable |

Publier demande une confirmation qui résume le changement (« 2 points ajoutés, 1 retiré »). Tout passage d'un
statut à l'autre est inscrit au journal du Conseil.

## L'outil de placement

Commun à tous les éditeurs qui touchent le monde (zones, points, stations, parcelles, portes, lieux de confrérie,
accessoires des gestes) :
- visée au sol depuis la caméra, aperçu fantôme du modèle (vert : valide, rouge : refusé, avec la raison) ;
- molette pour tourner, `Maj` pour le placement précis (pas fin), clic droit pour choisir un objet existant,
  `Ctrl+Z` pour annuler, `Échap` pour quitter ; barre des touches toujours visible (voir maquette « Récolte ») ;
- formes : point, point orienté avec modèle, cercle (centre + rayon à la molette), polygone (parcelle), porte
  (sélection d'un objet du décor) ;
- **le serveur revérifie chaque placement** : droit, distance du membre du Conseil à l'endroit posé (il doit y
  être), bornes du schéma, chevauchements interdits par le module ;
- la boucle de dessin par image ne vit que pendant l'édition, chez le seul éditeur (modèle : éditeur des zones de
  voix de `vava_voice`, qui fait déjà exactement ça).

## Règles d'interface (tirées des maquettes)

1. Les mots du jeu, jamais les noms de la config. Chaque réglage a une phrase d'aide.
2. Un écran = une chose. Les étapes réelles sont numérotées (« La zone, Les points, Publier »).
3. Toujours un bouton pour essayer avant de publier, et il dit ce qu'il fait (« Tester la récolte »).
4. Les valeurs proches d'un réglage existant sont montrées pour comparer (« Pour comparer : Boule de feu »).
5. Les modèles provisoires sont signalés (« modèle provisoire, remplacé automatiquement plus tard »).
6. Les droits sont vérifiés par le serveur ; l'interface n'affiche que ce que le rang permet.

## Sécurité et réseau

- Toute action d'édition est un RPC `vava_atelier:*` avec schéma borné et limite de débit, réservé aux droits du
  Conseil, journalisé. Le client d'un éditeur ne décide de rien.
- Les définitions publiées sont envoyées aux joueurs **concernés seulement** : par abonnement de zone (T-014) pour
  ce qui est posé dans le monde, une fois au chargement avec numéro de version pour les catalogues (gestes, effets,
  sorts, techniques), puis uniquement les différences.
- Le catalogue complet des animations et des particules de GTA ne quitte jamais le serveur : la recherche se fait
  côté serveur, seuls les résultats partent vers l'éditeur.
- Limites dures en config : nombre de points par zone, de calques par effet, d'effets par sort, d'invocations par
  mage et sur le serveur.

## Les éditeurs et leurs maquettes

| Éditeur | Tâche | Maquette | Ce qu'il édite |
|---|---|---|---|
| Accueil | T-100 | `Main` | familles, recherche, brouillons, journal |
| Récolte | T-102 | `Recolte` | zones (type, rayon, repos de la terre, cicatrice), points (ressource, modèle, récoltes avant repos, repousse) |
| Agriculture | T-103 | — (mêmes principes) | parcelles (polygone, communale ou privée), emplacements, puits, greniers, composteurs |
| Artisanat | T-104 | — | stations (type, qualité, combustible, recettes disponibles, publique ou privée) |
| Confréries | T-105 | `Confrerie` | nom, blason, type (rôle de la cité ou confrérie libre), grades ordonnés, grille grades × droits, lieux (coffre, vestiaire, cachot…), tenue |
| Portes et clés | T-106 | — | porte (objet du décor visé), verrou, clés, crochetage |
| Gestes | T-120 | — | animation (recherche), options en cases à cocher, accessoires placés, enchaînement, gestes à deux |
| Techniques de combat | T-121 | `Combat` | voir `COMBAT_V1.md` : geste, arme, phases sur frise, portée, angle, effets, déblocage |
| Effets | T-122 | `Sort`, `Protection` (bas d'écran) | calques par moment (lancement, trajet, impact, sur la cible, rupture, fin) |
| Sorts | T-123 | `Sort`, `Protection` | forme, cibles, élément, geste, valeurs, liste d'effets de jeu avec conditions, règle de cumul |
| Invocations | T-124 | — | créature (modèle provisoire), comportement, durée, plafonds |
| Transformations | T-125 | — | forme animale, déguisement (rend méconnaissable, jamais l'apparence d'un autre joueur), taille, durée |

### Familles d'effets de jeu d'un sort (menu « Ajouter un effet »)

Attaquer (dégâts, dégâts sur la durée, drain de vie) · Soigner (soin, soin sur la durée, purifier) · Protéger
(bouclier, résistance à un élément, renvoi) · Renforcer (vitesse, force et endurance, régénération de mana) ·
Affaiblir (ralentir, fragiliser, silence) · Contrôler (renverser ou geler, repousser ou attirer, bond) · Révéler et
aider (lumière, murmure, révéler les traces) · Invoquer (créature alliée, esprit éclaireur, totem) · Transformer
(forme animale, déguisement, taille). Chaque effet peut porter une **condition** (« si la cible est mouillée »,
« quand le porteur est frappé au corps à corps »). Règle de cumul des protections : garder la plus forte /
remplacer / refuser, et **3 renforts au plus par personnage**.

Les 11 sorts existants de `vava_magic` gardent leur code. Les nouveaux sorts sont des données lues par un moteur
générique qui réutilise les noyaux existants (projectiles, zones, obstacles, états, combinaisons).
