# Métiers d'Eldoria — procédure de test en jeu

Procédure pour vérifier en jeu les quatre modules métiers et leurs préalables (inventaire 1.4.0, core 0.6.0, HUD 1.3.0,
droit `metiers`). Elle suit l'ordre des dépendances : ce qui est validé à une étape sert à la suivante. Comptez deux
heures pour tout faire seul ; les tests à deux joueurs sont marqués **(2 joueurs)**. Chaque test dit quoi faire et ce
qui doit se passer ; si ce n'est pas le cas, notez l'étape, ce que vous avez vu, et la ligne de console correspondante.

## 0. Préparation

1. **Ordre de démarrage** (`server.cfg`, ou la Chancellerie qui le fait seule) :
   `oxmysql`, `vAvA_core`, `vava_chat`, `vava_world`, `vava_appearance`, `vava_characters_ui`, `vava_hud`,
   `vava_inventory`, `vava_needs`, `vava_health`, `vava_admin`, `vava_voice`, `vava_cameras`, `vava_magic`,
   `vava_skills`, `vava_gathering`, `vava_crafting`, `vava_farming`, `vava_codex`, `vava_chancellerie`.
2. **Démarrage** : dans la console, chaque module doit afficher `module 'xxx' vY prêt`. Les migrations partent seules
   (`0003_play_seconds` du core, `0001_*` de chaque module). Un module refusé affiche la raison : notez-la, c'est le
   premier retour utile.
3. **Avertissements attendus au premier démarrage** : aucun. Un `WARN … objet 'x' inconnu de l'inventaire` signale
   une recette ou une ressource dont l'objet n'est déclaré nulle part : à me remonter.
4. **Compte du Conseil** : console → `vava_conseil <votre compte> souverain` (numéro de compte : Chancellerie →
   Joueurs → fiche, ou console du serveur à la première connexion, `nouveau compte #n`). Vous avez alors `metiers`
   (via Sénéchal) et `staff`.
5. **Objets de départ** : le plus rapide est le catalogue de développement : `catalog.enabled = true` dans
   `vava_inventory/config.lua`, `restart vava_inventory`, puis `/catalogue` en jeu : un conteneur avec une pile de
   chaque objet s'ouvre à côté de la besace, avec ses onglets de catégories, sa recherche et ses pages ; glissez ou
   double-cliquez ce qu'il vous faut (il se regarnit tout seul). Sinon, Registre du Conseil (`F10`) → Joueurs → vous
   → Donner :
   `hache_fer`, `pioche_fer`, `faucille_fer`, `couteau_fer`, `canne_a_peche`, `seau`, `graine_ble` ×5,
   `graine_carotte` ×5, `charbon` ×10, `compost` ×3. Dans les deux cas, ces objets n'ont ni palier ni créateur :
   c'est voulu (ils en gagneront à l'usage ou par la forge).
6. **Lieux d'exemple** (à remplacer ensuite par ceux du royaume), autour du point d'apparition par défaut
   (−269, −955) : Forêt de Brume (−320, −880), Mine du Val (−180, −1010), Prairie Haute (−380, −1060), Rivière Claire
   (−120, −880), stations du bourg le long de (−255, −945) → (−292, −915), champ communal (−230, −890), jardin privé
   (−240, −905), puits (−236, −897), grenier (−222, −885), composteur (−224, −895). Registre → Déplacer vers un lieu.
7. **Réglages pour aller vite** (facultatif, à remettre après) : `vava_skills/config.lua` → `lessons.minIntervalMs = 0`,
   `mentoring.minTeachPlaySeconds = 0`, `shortages.minActivePlayers = 0` ; `vava_farming/config.lua` →
   `growth.wiltAfterHours = 0.05`, `dieAfterHours = 0.1`, et `growMinutes` des cultures à 2. Un `restart` du module
   suffit.

## 1. Préalables

### 1.1 Inventaire 1.4.0 — métadonnées et Mains

| # | Faire | Attendu |
|---|---|---|
| 1 | Ouvrir l'inventaire (`I`). | L'emplacement **Mains** apparaît à gauche de la ceinture. |
| 2 | Glisser la hache sur Mains. | Elle y apparaît ; un sceau de laiton marque la hache dans la grille ; les autres joueurs voient la hache dans votre main droite. |
| 3 | Clic droit sur Mains → Reposer ; double-clic sur la hache ; touche `1` à `5` avec la hache en raccourci. | Chacun prend ou repose la hache (sans la consommer). |
| 4 | Jeter la hache au sol pendant qu'elle est en main. | La main se vide d'elle-même. |
| 5 | Survoler une pile récoltée plus tard (bûches) et un outil forgé. | Fiche : palier avec sa teinte, provenance, « Façonné par … », solidité, histoire. |

### 1.2 Core 0.6.0 — temps de jeu

| # | Faire | Attendu |
|---|---|---|
| 1 | Jouer quelques minutes puis ouvrir la Chancellerie → Joueurs. | Colonne « Temps de jeu » et ligne dans la fiche, qui augmentent ; figées pendant la sélection de personnage. |
| 2 | Registre du Conseil → Joueurs. | Temps de jeu sous le nom et dans la fiche. |

### 1.3 HUD 1.3.0 — barre de progression

Vérifiée par les gestes des modules (récolte, pièce, semis) : une barre en bas, une seule à la fois, teinte laiton à
la fin, sang à l'interruption. Hors jeu : `modules/vava_hud/web/index.html?progress=1`.

## 2. Compétences — `vava_skills`

| # | Faire | Attendu |
|---|---|---|
| 1 | `K`. | Livre des compétences : 13 compétences par catégorie, budget 0 / 200, toutes en `=`. |
| 2 | Cliquer le mode de Bûcheronnage jusqu'à `↑`. | Mode mémorisé après fermeture / réouverture. |
| 3 | Couper du bois (voir 3.2) avec Bûcheronnage en `=`. | Notification « compétence verrouillée (=) », aucune XP ; la remarque n'est pas répétée à chaque coup. |
| 4 | Même chose en `↑`. | Barre d'XP qui monte ; niveau 1 à 50 XP ; notification de niveau, puis de rang à 20 (Apprenti). |
| 5 | `/metiers niveau <vous> forge 100`, `minage 100`, `cuisine 60`, `bucheronnage 20` ; Bûcheronnage en `↑`, rien en `↓` ; couper. | Budget 200 / 200 (seuls les niveaux au-delà de 20 comptent : 80 + 80 + 40) ; l'XP de Bûcheronnage se fige juste sous le niveau 21 ; « Vous avez atteint votre plafond… ». |
| 6 | Passer Cuisine en `↓` ; couper jusqu'au niveau. | Bûcheronnage passe 21, Cuisine tombe à 59 (notification « oubli ») ; `vava_skills_log` : `rust`. |
| 7 | `/metiers niveau <vous> forge 20` (libère le budget) puis `bucheronnage 60` ; couper un pin (difficulté 5). | XP divisée par 10 (rendement plancher : 55 niveaux au-dessus de la difficulté). |
| 8 | Onglet Pénurie. | Vide tant que le royaume compte moins de 10 personnages actifs (`minActivePlayers`) ; à 0, tous les métiers y sont, × 1,5. |
| 9 | `/metiers voir <vous>`. | Fiche dans le chat. |
| 10 | **(2 joueurs)** Vous : Forge ≥ 80 (`/metiers niveau`) ; à 10 m de l'autre, onglet Mentorat → Proposer → Forge → l'autre. | L'autre reçoit la notification et la proposition dans son livre (compte à rebours 60 s) ; accepter → les deux voient le mentorat. |
| 11 | **(2 joueurs)** Vous forgez un lingot (voir 4), puis l'apprenti forge le sien à moins de 20 m dans les 10 min. | Son XP est × 1,5 ; votre Renommée en Forge monte (10 %). Hors des 20 m ou après 10 min : pas de bonus. |
| 12 | **(2 joueurs)** Rompre depuis l'un des deux livres. | Les deux sont prévenus ; `vava_skills_mentorships.ended_at` renseigné. |
| 13 | **(2 joueurs)** Arcanes en `↑` chez l'apprenti sans mentor en Arcanes → table d'arcanes (talisman, voir 4). | « ne progresse qu'auprès de votre maître » ; avec un mentor en Arcanes à 30 m, l'XP monte. |
| 14 | Console : `vava_fondateur <vous> forge 90 epee_courte`. | Forge à 90, l'épée dans Savoirs (source fondateur) ; journal `founder`. |
| 15 | **(2 joueurs)** Forger l'épée trois fois à moins de 10 m d'un joueur de Forge ≥ 30 (délai `lessons.minIntervalMs`). | Leçons 1/3, 2/3, 3/3 notifiées aux deux ; l'élève voit l'épée dans Savoirs avec sa lignée (lui → vous, fondateur). |
| 16 | Se déconnecter puis revenir. | Niveaux, XP, modes identiques (écriture au départ). `restart vava_skills` en jeu : fiche reprise. |

## 3. Récolte — `vava_gathering`

### 3.1 Props et panneau

| # | Faire | Attendu |
|---|---|---|
| 1 | Aller à la Forêt de Brume. | Chênes et pins (props) aux positions de la config ; invite près d'un arbre. |
| 2 | `O`. | Panneau des zones : nom, genre, vitalité, bande, distance ; `O` ou Échap ferme. |

### 3.2 Récolte au sol

| # | Faire | Attendu |
|---|---|---|
| 1 | Près d'un chêne, rien en main. | « [E] Couper — Chêne · 3 charges » + « Il vous faut une hache en main ». |
| 2 | Hache en main, `E`. | Geste, barre, puis bûches dans la besace avec palier et « Forêt de Brume » ; solidité de la hache 98 / 100 (initialisée à 100) ; charge − 1 dans l'invite ; XP de Bûcheronnage. |
| 3 | `E` à nouveau dans la seconde. | Refusé (cooldown 1,5 s). |
| 4 | Marcher pendant le geste. | Interruption, rien de pris, barre en sang. |
| 5 | Vider un nœud (3 récoltes). | « plus rien à prendre » ; une charge revient après `regenMs` (10 min). |
| 6 | Lavande à la main, sauge avec la faucille, minerai avec la pioche, piste de lièvre au couteau. | Chaque récolte avec le bon outil ; piste : viande et parfois une peau. |
| 7 | `/recolte vitalite foret_brume 20`. | Props remplacés par des souches (bande épuisée), rendement effondré, échecs fréquents (« la terre est fatiguée »). |
| 8 | `/recolte vitalite foret_brume 0`. | « cicatrice » ; `vava_gathering_log` : `scarred` ; `/recolte zone foret_brume` montre la cicatrice ; `/recolte vitalite foret_brume 100` lève tout. |
| 9 | `/recolte recharger foret_brume_chene_1`. | Charges à plein. |
| 10 | Hache en main près d'un chêne : `/aterre` (outil `vava_dev_characters`), puis `E` ; relevé, lancer une récolte et `/aterre` pendant la barre. | À terre : l'invite disparaît, `E` ne fait que rendre l'âme (aucune récolte, aucun message de la récolte). Tombé pendant le geste : rien de pris, charge intacte (« Vous êtes à terre. » à la fin de la barre, ou geste interrompu si le corps a glissé en tombant). |

### 3.3 Pêche

| # | Faire | Attendu |
|---|---|---|
| 1 | Canne en main au bord de la Rivière Claire, `E`. | « Ligne lancée… », animation. |
| 2 | Attendre la touche (4 à 14 s). | Barre de tension : tenir `E` fait monter l'aiguille, relâcher la fait descendre ; la zone dérive. |
| 3 | Tenir l'aiguille dans la zone 60 % du temps. | Truite dans la besace (palier) ; charge du banc − 1. |
| 4 | Ne pas tenir. | « La prise s'est échappée », aucune charge consommée. |
| 5 | Marcher pendant la barre. | Interruption. |

## 4. Artisanat — `vava_crafting`

| # | Faire | Attendu |
|---|---|---|
| 1 | Près du fourneau, `E`. | Menu : bandeau (combustible 0 / 20), onglets Recettes, Réparation, Poinçon. Charbon de bois et Ragoût visibles. |
| 2 | Façonner « Charbon de bois » sans combustible. | Refusé : « manque de combustible ». |
| 3 | Alimenter avec du bois de pin, puis Façonner. | Geste, barre, 2 charbons (palier, qualité plafonnée par le niveau de Cuisine). |
| 4 | Forge : alimenter en charbon, Façonner « Lingot de fer » avec deux piles de minerai de paliers différents. | Le menu propose les deux paliers, l'aperçu de qualité change ; la pile du palier choisi est consommée. |
| 5 | Établi : « Marteau de forge ». | Objet **signé** : fiche avec créateur, date, histoire « Création » ; Grossier à bas niveau. |
| 6 | Forge : « Hache de bûcheron » sans marteau en main. | « Il vous faut un marteau de forge en main ». Marteau en main → hache signée. |
| 7 | Onglet Poinçon sous Compagnon. | Verrouillé. `/metiers niveau <vous> forge 40` → choisir un glyphe → il apparaît sur la pièce suivante. |
| 8 | Chef-d'œuvre : `/metiers niveau <vous> minage 100` et `forge 100`, minerai pris dans une zone à pleine vitalité avec une pioche neuve (palier Excellent ou mieux), lingots, puis Épée courte. | Qualité ≥ 85 → notification « Un chef-d'œuvre ! » et boîte de baptême ; le nom choisi apparaît sur la fiche. « Plus tard » : la station repropose le baptême tant que 5 min ne sont pas passées, plus après. À l'inverse, des matières de palier 5 à bas niveau donnent une qualité plafonnée au niveau. |
| 9 | Hache brisée (la solidité baisse de 2 par coupe : 50 coupes, ou `wear = 50` sur `hache_fer` dans `vava_gathering/config.lua` le temps du test) → onglet Réparation à la forge. | Coût 25 % des ingrédients arrondi au-dessus (1 lingot, 1 bûche), bouton ; après le geste : 95 / 95, plus brisée, histoire « Réparation par … », créateur intact. Une hache réparée deux fois : 90 / 90. |
| 10 | **(2 joueurs)** L'autre lance une pièce à la même forge. | « Quelqu'un travaille déjà ici ». |
| 11 | Station avec `owner = { kind = 'character', id = <autre> }` dans la config. | « ne vous appartient pas ». |
| 12 | `/artisanat station forge_bourg`, `/artisanat carburant forge_bourg 20`. | État et recettes dans le chat ; combustible fixé. |
| 13 | Près du fourneau : `/aterre`, puis `E` ; relevé, lancer une pièce et `/aterre` pendant la barre. | À terre : ni invite ni menu, `E` ne fait que rendre l'âme. Tombé pendant la pièce : rien de consommé, station libérée (« Vous êtes à terre. » à la fin de la barre, ou geste interrompu si le corps a glissé) ; un autre joueur peut s'en servir aussitôt. |

## 5. Agriculture — `vava_farming`

| # | Faire | Attendu |
|---|---|---|
| 1 | Champ communal, près d'un emplacement libre, `E`. | Menu : « Emplacement libre », Planter actif si graines, autres gestes grisés avec la raison. |
| 2 | Planter du blé (choisir le palier si plusieurs). | Geste, semis, prop de semis, graine du palier consommée, XP d'Agriculture (petite). |
| 3 | Attendre (ou `/agriculture pousser champ_communal 1`). | Le prop change de stade sans rien toucher ; « mûr » dans l'invite. |
| 4 | Seau en main vide → Arroser. | « remplissez-le à un puits ». Au puits, `E` → 5 charges ; Arroser → humidité 100, charge − 1. |
| 5 | Laisser une plante sans eau (réglages du § 0.7). | Flétrie (prop), arroser la fait repartir ; plus longtemps → morte : seul Arracher reste, qui rend des déchets végétaux. |
| 6 | Récolter à la main, puis une autre à la faucille. | Plus rapide à la faucille ; produit au palier avec « Champ communal » ; parfois des graines du même palier ; fertilité en baisse ; replanter la même famille coûte 10 de plus, une autre rend 10. |
| 7 | 3 déchets au composteur du champ (station de l'artisanat), puis Fertiliser. | Compost produit ; fertilité + 25. |
| 8 | `E` près du grenier. | L'inventaire s'ouvre sur « Grenier commun » ; déposer, s'éloigner de 4 m → il se ferme ; `vava_farming_granary_log` : dépôt / retrait. |
| 9 | Jardin privé (propriétaire n° 1 dans la config). | Un autre personnage lit « ne vous appartient pas ». |
| 10 | `/agriculture parcelle champ_communal`, `/agriculture arroser champ_communal`. | État des emplacements ; tout arrosé. |
| 11 | `restart vava_farming`. | Emplacements retrouvés, croissance rattrapée d'après les dates. |
| 12 | Près d'un emplacement, puis d'un puits, puis du grenier : `/aterre`, puis `E` ; relevé, lancer un semis et `/aterre` pendant la barre. | À terre : ni invite, ni menu, ni seau rempli, ni grenier ouvert ; `E` ne fait que rendre l'âme. Tombé pendant le semis : graine gardée, emplacement inchangé (« Vous êtes à terre. » à la fin de la barre, ou geste interrompu si le corps a glissé). |
| 13 | Grenier ouvert (`E`), un objet en main de souris : se faire mettre à terre (`/aterre`), puis tenter un dépôt, un retrait, une division, un jet au sol. | Le grenier reste affiché (l'inventaire n'offre aucun moyen de le fermer pour un module), en consultation seulement : chaque geste est refusé, « Vous êtes à terre. » ; rien ne bouge, aucune ligne dans `vava_farming_granary_log`. Relevé, les gestes reprennent ; s'éloigner de plus de 4 m le ferme comme d'habitude. |

## 6. Ce qu'il faut regarder dans la base

- `vava_characters.play_seconds` monte ; `vava_skills_skills`, `vava_skills_mentorships`, `vava_skills_recipes`,
  `vava_skills_lessons`, `vava_skills_log` ; `vava_gathering_zones` (vitalité, `scarred_until`), `vava_gathering_nodes`,
  `vava_gathering_log` ; `vava_crafting_stations` (combustible), `vava_crafting_log` (pièces Excellent+, réparations,
  baptêmes, leçons) ; `vava_farming_slots`, `vava_farming_granaries`, `vava_farming_granary_log`, `vava_farming_log`.
- Les écritures sont groupées (10 s) : attendre un instant, ou arrêter proprement (`vava_saveall` puis `quit`).

## 7. Ce que je ne peux pas avoir vérifié hors jeu

- Le rendu des interfaces dans CEF (polices `nui://`, cadres `border-image`, glyphes des poinçons) : chaque
  `web/index.html` s'ouvre aussi dans un navigateur pour comparer.
- L'existence des modèles de props (arbres, filons, stations, plantes, puits, grenier) et des scénarios d'animation de la
  config : un modèle inconnu est signalé dans la console du client (`modèle inconnu 'x'`) et il n'y a simplement pas de
  prop ; une animation inconnue laisse le personnage immobile.
- L'attache des accessoires en main (os 57005, décalages par modèle) : à régler objet par objet dans `held`.
- La réception des state bags globaux à la connexion (zones, nœuds, stations, parcelles) : si les props ne
  s'affichent pas au premier passage, c'est ce point.

## 8. Comment me remonter un problème

Pour chaque anomalie : le numéro du test (ex. « 3.2-7 »), ce qui s'est passé, la ou les lignes de la console
serveur ou client (F8) au même moment, et si possible l'état en base. Les lignes qui commencent par le nom du module
(`[vava_gathering]`…) sont les plus parlantes.
