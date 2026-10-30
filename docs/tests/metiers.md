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
| 3 | Tenir l'aiguille dans la zone 60 % du temps. | « La ligne a tenu ! » dans la barre, puis le plus souvent truite dans la besace (palier) et charge du banc − 1. |
| 4 | Ne pas tenir. | « La ligne s'est relâchée… » puis « La prise s'est échappée », aucune charge consommée. |
| 5 | Marcher pendant la barre. | Interruption. |
| 6 | Prise tirée par le serveur (`vava_gathering` 1.4.0) : Pêche au niveau 0 (`/metiers niveau <vous> peche 0`), Rivière Claire à pleine vitalité (`/recolte vitalite riviere_claire 100`), réussir la barre une douzaine de fois (`/recolte recharger riviere_claire_truite_1` quand le banc est vide). | Environ une prise sur quatre (25 %) : « La ligne a tenu ! » puis « Au dernier moment, le poisson se décroche. » ; ni charge, ni vitalité, ni solidité de la canne, ni XP pris. Les autres : truite comme au test 3. |
| 7 | Même essai à Pêche 100 (`/metiers niveau <vous> peche 100`). | Presque jamais décroché (2 %). |
| 8 | Eaux fatiguées : `/recolte vitalite riviere_claire 40`, Pêche 0, une douzaine de barres réussies. | Toujours environ 25 % de poissons décrochés (« Au dernier moment, le poisson se décroche. » : l'état de l'eau n'y joue pas, décision du 30 octobre 2026), puis 25 % des restants « Ces eaux sont fatiguées : le poisson vous échappe. » (échec de la bande, canne usée ; jamais le texte de la terre). Remettre `/recolte vitalite riviere_claire 100`. |
| 9 | Eaux épuisées : `/recolte vitalite riviere_claire 26`, puis réussir une prise (coût de la zone : 2) ; s'approcher ensuite du banc ; enfin `/recolte vitalite foret_brume 20` et s'approcher d'un chêne. | Après la prise : « Rivière Claire est épuisée : l'eau a besoin de repos. » ; invite du banc : « Ces eaux sont épuisées : la pêche sera maigre. ». Près du chêne : « La terre est épuisée ici : la récolte sera maigre. » (textes de la terre inchangés hors de l'eau). Remettre les deux zones à 100. |

### 3.4 Joueurs proches seulement (`vava_gathering` 1.6.0, abonnements de zone du core)

Depuis T-015, l'état des zones de récolte (bande, cicatrice) et les charges des nœuds ne partent plus chez tout le monde
par GlobalState : chaque zone est une zone du core, envoyée entière aux seuls joueurs à moins de 100 m (80 m de portée
des props + 20 m) du cercle qui englobe ses nœuds, puis ses seuls changements. La vitalité n'est plus envoyée. Rien ne
doit changer à l'écran. Préparation : A est Sénéchal ou Souverain (droit `tools` pour `/vava_reseau`) ; B sans rang.
Pour « loin de tout », à plus de 500 m de tous les lieux du § 0.6.

| # | Faire | Attendu |
|---|---|---|
| 1 | `restart vava_gathering` (ou démarrage du serveur). | Console : `module 'vava_gathering' v1.6.0 prêt`, aucune ligne « zone '…' non partagée avec les joueurs proches ». A : `/vava_reseau zones` → `vava_gathering 4` dans la liste des zones. |
| 2 | A se tient au milieu de la Forêt de Brume ; `/vava_reseau zones <A>`. | `vava_gathering:foret_brume` dans la liste ; arbres et invite comme avant (§ 3.1). |
| 3 | **(2 joueurs)** B loin de tout ; A récolte trois fois dans la Forêt de Brume, puis `/recolte vitalite foret_brume 20` et `100`. A : `/vava_reseau joueur <B>`. | Aucune ligne `vAvA:zone:*` sous `vava_gathering` chez B ; aucune clé `vava_gathering:*` reçue (plus de GlobalState). |
| 4 | **(2 joueurs)** B s'approche à pied de la Forêt de Brume ; A : `/vava_reseau zones <B>` quand B est à environ 200 m du centre (−320, −880), puis à 230 m. | Suivie à 200 m (cercle d'intérêt de 220 m : rayon 120 m + 100 m) ; plus suivie au-delà de 245 m (25 m de jeu à la sortie). Les arbres n'apparaissent qu'à 80 m, comme avant. |
| 5 | **(2 joueurs)** A et B près du même chêne ; A le récolte. | Chez B, l'invite passe de « 3 charges » à « 2 charges » dans la seconde ; `/vava_reseau joueur <B>` : `vAvA:zone:diff` sous `vava_gathering`, environ 50 o par récolte. |
| 6 | **(2 joueurs)** B dans la forêt ; A (n'importe où) : `/recolte vitalite foret_brume 20`, puis `/recolte recharger foret_brume_chene_1`, puis `/recolte vitalite foret_brume 100`. | Chez B, sans reconnexion : souches dans la seconde, puis l'invite à pleines charges, puis les arbres. |
| 7 | B récolte une dizaine de fois à pleine vitalité (la vitalité passe de 100 à 80, bande inchangée). `/vava_reseau joueur <B>`. | Une seule différence par récolte (les charges) ; aucune différence de la zone tant que la bande ne change pas (avant : une écriture GlobalState à presque chaque récolte, chez tous les joueurs). |
| 8 | B arrive au galop vers la Forêt de Brume depuis 500 m. | Les arbres apparaissent à 80 m, jamais pleins puis en souches quand la zone est épuisée (essai à refaire après `/recolte vitalite foret_brume 20`). |
| 9 | B, loin de tout, se fait déplacer (Registre → Déplacer) au milieu de la Prairie Haute. | Buissons et plantes en une à deux secondes après l'arrivée (avant : jusqu'à 2,5 s). |
| 10 | B dans la forêt ; console : `restart vava_gathering`. | Après `module 'vava_gathering' v1.6.0 prêt`, les arbres reviennent chez B en deux secondes au plus, sans reconnexion ; aucun prop en double. |
| 11 | B retourne à la sélection du personnage, puis rejoue dans la forêt. | À la sélection : aucun prop ; `/vava_reseau zones <B>` : 0 zone. Une seconde après l'apparition : la zone revient, les arbres aussi. |
| 12 | **Mesure** : le plus de joueurs possible, dont une partie qui récolte et une partie qui se déplace entre les zones. Console du serveur : `profiler record 300`, puis `profiler view` ; chercher `vAvA_core` (fonctions `runPass` / `pass` de `zones.lua`, `flushZone`) et `vava_gathering` (`flush`, `share.set`). Noter aussi `/vava_reseau zones`. | `vava_gathering` n'apparaît qu'au passage de sa boucle lente (10 s) et à chaque récolte (quelques microsecondes) ; le passage des zones du core reste de l'ordre de ce que dit `docs/tests/zones.md` § 5-2 (4 zones de récolte en plus : rien de visible). Noter les valeurs avec le nombre de joueurs et de zones. |
| 13 | `./scripts/audit-reseau.sh`. | Plus aucun avertissement « écriture GlobalState » dans `modules/vava_gathering`. |

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
| 8 | Chef-d'œuvre : `/metiers niveau <vous> minage 100`, `bucheronnage 100` et `forge 100` ; minerai et chêne pris dans des zones à pleine vitalité avec des outils neufs ; garder les piles **Chef-d'œuvre** (palier 5), en faire des lingots Chef-d'œuvre, puis l'Épée courte en choisissant le palier 5 pour chaque ingrédient (l'aperçu du menu l'annonce). | Toutes les matières au palier 5 : qualité de 86 à 96 → notification « Un chef-d'œuvre ! » et boîte de baptême ; le nom choisi apparaît sur la fiche. Avec des lingots tirés d'un minerai Excellent, ce n'est pas garanti (environ 40 % avec du chêne Chef-d'œuvre, jamais avec du chêne Grossier) : normal, la formule le veut. « Plus tard » : la station repropose le baptême tant que 5 min ne sont pas passées, plus après. À l'inverse, des matières de palier 5 à bas niveau donnent une qualité plafonnée au niveau. |
| 9 | Hache brisée (la solidité baisse de 2 par coupe : 50 coupes, ou `wear = 50` sur `hache_fer` dans `vava_gathering/config.lua` le temps du test) → onglet Réparation à la forge. | Coût 25 % des ingrédients arrondi au-dessus (1 lingot, 1 bûche), bouton ; après le geste : 95 / 95, plus brisée, histoire « Réparation par … », créateur intact. Une hache réparée deux fois : 90 / 90. |
| 10 | **(2 joueurs)** L'autre lance une pièce à la même forge. | « Quelqu'un travaille déjà ici ». |
| 11 | Station avec `owner = { kind = 'character', id = <autre> }` dans la config. | « ne vous appartient pas ». |
| 12 | `/artisanat station forge_bourg`, `/artisanat carburant forge_bourg 20`. | État et recettes dans le chat ; combustible fixé. |
| 13 | Près du fourneau : `/aterre`, puis `E` ; relevé, lancer une pièce et `/aterre` pendant la barre. | À terre : ni invite ni menu, `E` ne fait que rendre l'âme. Tombé pendant la pièce : rien de consommé, station libérée (« Vous êtes à terre. » à la fin de la barre, ou geste interrompu si le corps a glissé) ; un autre joueur peut s'en servir aussitôt. |
| 14 | Signature protégée (1.3.0) : poser la ressource jetable `test_signature` décrite sous ce tableau, `ensure test_signature`. Hache **signée** en main (test 6) ; en console : `testsig <votre id> crafter_name Truand`, puis `testsig <id> quality 100`, `testsig <id> tier 5`, `testsig <id> mark X`, `testsig <id> name Truand`. | Chaque fois `false signature_locked` en console, avec un `WARN` de `vava_crafting` (« écriture de 'test_signature' refusée … clé '…' protégée ») ; fiche de la hache inchangée (créateur, qualité, palier, poinçon, pas de nom). |
| 15 | Même hache : `testsig <id> max_durability 500`, puis `testsig <id> durability 1`, puis `testsig <id> durability 100`. | `false durability_locked` ; puis `true`, la fiche montre 1 / 100 ; puis `false durability_locked` (pas de réparation hors station). Réparer à la forge (test 9) : 95 / 95 comme d'habitude. |
| 15b | Même hache, au moins une minute après le test 14 : `testsig <id> crafter_name Truand` cinq fois en moins d'une minute ; attendre 60 s ; une sixième fois. | `false signature_locked` à chaque fois ; un seul `WARN` et une seule ligne au journal pour les cinq premiers ; le sixième donne un nouveau `WARN` qui finit par « [4 refus semblable(s) tu(s)] » (et `"untold": 4` dans `details` au journal). |
| 16 | Hache **du catalogue** (non signée) en main : `testsig <id> durability 50`, puis `testsig <id> crafter_name Truand`. | `true` (objet ordinaire, la garde ne s'en mêle pas) ; puis `false signature_locked` (pas de signature contrefaite). |
| 17 | Avec la hache signée : couper du bois (récolte), puis baptiser un chef-d'œuvre (test 8) ; `SELECT kind, details FROM vava_crafting_log WHERE kind IN ('signature_locked','durability_locked')`. | La solidité baisse à chaque coupe, la hache se brise à 0 ; le baptême passe. En base : une ligne par refus distinct des tests 14 à 16 (module `test_signature`, clé, objet), deux pour le 15b. Supprimer ensuite la ressource jetable. |

Ressource jetable des tests 14 à 17 (`resources/test_signature/`, à **ne pas** committer ni garder) : `fxmanifest.lua`
avec `fx_version 'cerulean'`, `game 'gta5'`, `lua54 'yes'`, `server_script 'server.lua'`, et ce `server.lua` :

```lua
-- console seulement : testsig <id du joueur> <clé> <valeur> — écrit une clé sur l'objet tenu en main
RegisterCommand('testsig', function(src, args)
    if src ~= 0 then return end
    local target, key, value = tonumber(args[1]), args[2], tonumber(args[3]) or args[3]
    local held = target and exports.vava_inventory:held(target)
    if not held or not key then return print('testsig : joueur, clé ou objet en main manquant') end
    print('testsig', exports.vava_inventory:patchMetadata(target, held.id, { [key] = value }))
end, true)
```

## 5. Agriculture — `vava_farming`

| # | Faire | Attendu |
|---|---|---|
| 1 | Champ communal, près d'un emplacement libre, `E`. | Menu : « Emplacement libre », Planter actif si graines, autres gestes grisés avec la raison. |
| 2 | Planter du blé (choisir le palier si plusieurs). | Geste, semis, prop de semis, graine du palier consommée, XP d'Agriculture (petite). |
| 3 | Attendre (ou `/agriculture pousser champ_communal 1`). | Le prop change de stade sans rien toucher ; le dernier modèle n'apparaît qu'à 100 %, en même temps que « mûr » dans l'invite (blé : semis, pousse jusqu'à 50 %, plant jusqu'à 100 %, puis mûr). `pousser` arrose aussi la terre : une plante sèche ainsi mûrie ne reflétrit pas dans la foulée. |
| 4 | Seau en main vide → Arroser. | « remplissez-le à un puits ». Au puits, `E` → 5 charges ; Arroser → humidité 100, charge − 1. |
| 5 | Laisser une plante sans eau (réglages du § 0.7). | Flétrie (prop), arroser la fait repartir ; plus longtemps → morte : seul Arracher reste, qui rend des déchets végétaux ; ses heures sèches (menu) ne montent plus après la mort. |
| 6 | Récolter à la main, puis une autre à la faucille. | Plus rapide à la faucille ; produit au palier avec « Champ communal » ; parfois des graines du même palier ; fertilité en baisse ; replanter la même famille coûte 10 de plus, une autre rend 10. |
| 7 | 3 déchets au composteur du champ (station de l'artisanat), puis Fertiliser. | Compost produit ; fertilité + 25. |
| 8 | `E` près du grenier. | L'inventaire s'ouvre sur « Grenier commun » ; déposer, s'éloigner de 4 m → il se ferme ; `vava_farming_granary_log` : dépôt / retrait. |
| 9 | Jardin privé (propriétaire n° 1 dans la config). | Un autre personnage lit « ne vous appartient pas ». |
| 10 | `/agriculture parcelle champ_communal`, `/agriculture arroser champ_communal`. | État des emplacements ; tout arrosé. |
| 11 | `restart vava_farming`. | Emplacements retrouvés, croissance rattrapée d'après les dates. |
| 12 | Près d'un emplacement, puis d'un puits, puis du grenier : `/aterre`, puis `E` ; relevé, lancer un semis et `/aterre` pendant la barre. | À terre : ni invite, ni menu, ni seau rempli, ni grenier ouvert ; `E` ne fait que rendre l'âme. Tombé pendant le semis : graine gardée, emplacement inchangé (« Vous êtes à terre. » à la fin de la barre, ou geste interrompu si le corps a glissé). |
| 13 | Grenier ouvert (`E`), un objet en main de souris : se faire mettre à terre (`/aterre`). Relevé, `E` au grenier, puis `/aterre` de nouveau pendant un glisser vers le grenier. | À la chute, l'inventaire se ferme aussitôt, grenier et besace (export `close` de l'inventaire, appelé par `vava_health`) ; rien n'est déplacé, aucune ligne dans `vava_farming_granary_log`. Relevé, `E` rouvre le grenier et les gestes reprennent ; le second `/aterre` le referme de même ; s'éloigner de plus de 4 m le ferme comme d'habitude. |
| 14 | **(2 joueurs)** Ordre de la récolte (`vava_farming` 1.5.1) : une plante de blé mûre au champ communal ; les deux lancent Récolter dessus et finissent le geste à quelques instants d'écart. | Un seul reçoit le blé (et peut-être des graines) ; l'autre lit « Ce geste n'est plus en cours. » et ne reçoit rien ; l'emplacement est libre ; une seule perte de fertilité ; `vava_farming_log` : au plus une ligne `harvested` (récolte Excellent ou mieux). |
| 15 | Besace pleine à la fin d'une récolte : lancer Récolter sur un blé mûr **couvert** (§ 5.1), puis, pendant la barre, remplir la besace (catalogue de développement) jusqu'à ce que le blé n'y tienne plus. | « Vous ne pouvez rien porter de plus. » ; la plante est toujours là, mûre et **couverte** (fiche), fertilité inchangée ; vider la besace et récolter de nouveau réussit (la couverture part alors avec la plante). |
| 16 | **(2 joueurs)** Une plante morte : les deux lancent Arracher dessus et finissent à quelques instants d'écart. | Un seul arrache et reçoit les déchets végétaux ; l'autre lit « Ce geste n'est plus en cours. » ; une seule ligne `cleared` au journal. |
| 17 | Arracher une plante morte la besace pleine. | La plante est arrachée quand même, et le joueur est prévenu : « Emplacement dégagé. Besace pleine : les déchets végétaux sont perdus. » ; l'emplacement est libre. |

### 5.1 Couvrir et gel (`vava_farming` 1.5.0, `vava_time` 1.2.0)

Règles décidées le 30 octobre 2026 : on couvre d'abord avec **2 déchets végétaux** (un paillis), sinon avec
**1 compost** ; on ne couvre qu'en **automne** et en **hiver** ; la nuit de gel est annoncée par le monde dès qu'elle est
tirée (`/date` et fiche de la plante) ; le chou seul résiste.

Préparer une nuit de gel sans attendre l'hiver : dans `modules/vava_time/config.lua`, `calendar.cycle.first = 'hiver'`
et `frost.seasons = { hiver = 1 }` (toutes les nuits gèlent), puis `restart vava_time` à une heure du royaume avant
17 h (sinon le soir est déjà passé ce jour-là et rien ne se joue). Remettre les valeurs ensuite. Déchets végétaux :
arracher une plante flétrie ou morte (1 à 2), ou le catalogue de développement.

| # | Faire | Attendu |
|---|---|---|
| 1 | Planter du blé au champ communal, avoir 5 déchets végétaux et 2 composts ; `E` sur la plante. | Geste « Couvrir » actif : « avec 2 × Déchets végétaux (5 dans la besace) ». La fiche porte « gel annoncé cette nuit » (marqué comme un danger : la plante est exposée). |
| 2 | Couvrir. | Geste de 3 s ; deux déchets végétaux consommés, les composts gardés ; la fiche de l'emplacement porte « couverte contre le gel » et « gel annoncé cette nuit » (sans marque de danger) ; Couvrir grisé (« Déjà couverte. ») ; `vava_farming_log` : `covered`, `item = dechets_vegetaux`, `quantity = 2`. |
| 3 | Garder un seul déchet végétal (jeter le reste), `E` sur une autre plante de blé, Couvrir. | Détail : « avec 1 × Compost (2 dans la besace) » ; un compost consommé, le déchet gardé ; journal `covered` avec `item = compost`. |
| 3 bis | Un seul déchet végétal et aucun compost, `E` sur une troisième plante de blé. | Couvrir grisé : « Il vous faut de quoi la couvrir (2 × Déchets végétaux ou 1 × Compost). ». |
| 4 | Planter un chou, `E`. | La fiche porte « ne craint pas le gel » et « gel annoncé cette nuit » (sans marque de danger) ; Couvrir grisé. |
| 5 | Lancer Couvrir et `/aterre` pendant la barre ; puis lancer Couvrir et s'éloigner de plus de 4 m avant la fin. | Rien n'est consommé ni couvert (« Vous êtes à terre. » / geste abandonné). |
| 6 | Laisser trois plantes : blé couvert, blé nu, chou. Rester près du champ (moins de 60 m) ; un second joueur loin du champ ; `/ciel heure 16 59`. | À 17 h du royaume : vous seul lisez « Le froid mordra cette nuit (Champ communal) : couvrez les cultures fragiles ou elles gèleront. » ; le second joueur ne reçoit rien. |
| 7 | `/ciel heure 20 59`. | À 21 h : « Le gel a pris 1 plante(s) cette nuit (Champ communal). » ; le blé nu est mort (prop de plante morte, seul Arracher reste) ; le blé couvert et le chou vivent ; `vava_farming_log` : une seule ligne `frost` pour la nuit (`parcelles = { champ_communal = 1 }`, `plantes = 1`) ; console : « le gel a pris 1 plante(s)… ». |
| 8 | Jardin privé (propriétaire n° 1) : une plante nue ; le propriétaire en jeu loin du jardin ; refaire 6 et 7 le lendemain (ou `restart vava_time` avant 17 h). | Le propriétaire est averti et prévenu où qu'il soit ; un joueur près du jardin qui n'en est pas le propriétaire ne reçoit rien. |
| 9 | Récolter le blé couvert, replanter au même endroit. | La nouvelle plante n'est plus couverte. |
| 10 | `restart vava_farming` après 7. | Plantes mortes et couverture retrouvées ; le gel ne retombe pas une seconde fois la même nuit. |
| 11 | **(2 joueurs)** Les deux lancent Couvrir sur la même plante de blé, chacun avec 2 déchets végétaux. | Deux déchets seulement sont consommés, chez celui qui finit le premier ; l'autre lit « Ce geste n'est plus en cours. » et garde les siens. |
| 12 | **(2 joueurs)** A lance Couvrir ; pendant la barre, B arrache la plante et ressème du blé au même endroit. | La couverture de A échoue, ses déchets sont gardés ; la nouvelle plante n'est pas couverte. |
| 13 | `stop vava_time`, une plante nue ; attendre 21 h (heure réelle de Paris). | Aucun avertissement ni gel : sans `vava_time`, les plantes ne gèlent jamais. Le menu ne propose pas « Couvrir » (aucun gel à craindre) et la fiche ne parle pas de gel. |
| 14 | **Arrivée après 17 h** : nuit de gel du § 0, `/ciel heure 18 00` (l'avertissement part) ; un second joueur se connecte **ensuite**, s'approche du champ et ouvre une plante de blé nue. | Le second joueur n'a pas reçu l'avertissement de 17 h, mais sa fiche porte « gel annoncé cette nuit » (et `/date`, « La nuit sera froide. ») ; il peut couvrir. |
| 15 | **Été** : `calendar.cycle.first = 'ete'`, `restart vava_time` ; `E` sur une plante de blé avec des déchets et du compost. | Pas de geste « Couvrir » dans le menu (les autres gestes restent) ; aucune mention du gel sur la fiche. |
| 16 | En été, lancer Couvrir quand même (menu ouvert avant le passage à l'été, ou client modifié). | Refus du serveur : « Aucun gel à craindre en cette saison. » ; rien consommé. Même refus au printemps (`first = 'printemps'`). |
| 17 | **Automne** : `calendar.cycle.first = 'automne'`, `restart vava_time` ; couvrir une plante de blé. | « Couvrir » est proposé et réussit (on se prépare à l'hiver) ; aucune nuit ne gèle en automne. |
| 18 | Hiver : lancer Couvrir, et pendant la barre de 3 s, `restart vava_time` avec `first = 'printemps'` (ou attendre la bascule d'une saison courte). | Si la saison a tourné avant la fin du geste : « Aucun gel à craindre en cette saison. », rien consommé, plante non couverte. |

## 6. Props à distance et resmon (récolte 1.4.1, artisanat 1.3.2, agriculture 1.5.2)

Depuis T-018, chacun des trois modules regroupe ses cibles (nœuds par zone, stations par case de 200 m, parcelle avec
son grenier, puits par case de 200 m), ne mesure que celles d'un groupe à portée, et ne repasse que toutes les 2,5 s
quand rien ne peut être à moins de 140 m (80 m de portée + 60 m de marge d'approche) ; toutes les secondes sinon.
Rien ne doit changer à l'écran. Tous les lieux d'exemple sont à moins de 200 m du point d'apparition : pour « loin de
tout », s'en éloigner d'au moins 500 m (Registre → Déplacer, ou repère sur la carte). Mesure : console du client
(`F8`) → `resmon 1`, lignes `vava_gathering`, `vava_crafting`, `vava_farming`.

| # | Faire | Attendu |
|---|---|---|
| 1 | Personnage debout, rien d'ouvert, à plus de 500 m de tous les lieux du § 0.6 ; regarder le resmon 30 s. | Les trois lignes à ~0,00 ms (≤ 0,02 ms) : un seul passage toutes les 2,5 s, qui ne mesure que les groupes. |
| 2 | Revenir à pied, puis au galop, vers la Forêt de Brume. | Les arbres apparaissent vers 80 m, comme avant : jamais « sous le nez » ni avec retard visible. |
| 3 | Rester debout au milieu de la Forêt de Brume, puis devant les stations du bourg, puis au champ communal, 30 s chaque fois. | Resmon de la ressource concernée ≤ 0,02 ms ; invite qui apparaît en moins d'une seconde près d'un arbre, d'une station, d'un emplacement, du puits, du grenier. |
| 4 | Longer les stations du bourg de (−255, −945) à (−292, −915), puis s'en éloigner à plus de 80 m. | Chaque station a son prop, un seul ; tous disparaissent au-delà de 80 m. |
| 5 | Au champ communal : plantes à différents stades, puits, grenier ; s'éloigner à plus de 80 m puis revenir. | Les plantes, le puits et le grenier disparaissent au-delà de 80 m et reviennent au retour, au bon stade ; une plante qui change de stade pendant qu'on est là change de prop dans la seconde. |
| 6 | `/recolte vitalite foret_brume 20` en étant dans la forêt, puis `100`. | Souches puis arbres, comme avant (dans la seconde). |
| 7 | Depuis un lieu à plus de 500 m, se faire déplacer (Registre → Déplacer) au milieu de la Forêt de Brume. | Les arbres apparaissent au plus 2,5 s après l'arrivée (seul écart connu : avant, 1 s au plus). |
| 8 | `restart vava_farming` (le composteur est une station ajoutée par l'agriculture) près du champ. | Le composteur réapparaît ; les autres stations ne clignotent pas. |
| 9 | Retour à la sélection du personnage, puis `restart vava_gathering`, `restart vava_crafting`, `restart vava_farming` en étant près de leurs lieux. | Aucun prop ne reste au sol à la sélection ; après chaque redémarrage, les props reviennent une seule fois. |

## 7. Ce qu'il faut regarder dans la base

- `vava_characters.play_seconds` monte ; `vava_skills_skills`, `vava_skills_mentorships`, `vava_skills_recipes`,
  `vava_skills_lessons`, `vava_skills_log` ; `vava_gathering_zones` (vitalité, `scarred_until`), `vava_gathering_nodes`,
  `vava_gathering_log` ; `vava_crafting_stations` (combustible), `vava_crafting_log` (pièces Excellent+, réparations,
  baptêmes, leçons) ; `vava_farming_slots`, `vava_farming_granaries`, `vava_farming_granary_log`, `vava_farming_log`.
- Les écritures sont groupées (10 s) : attendre un instant, ou arrêter proprement (`vava_saveall` puis `quit`).

## 8. Ce que je ne peux pas avoir vérifié hors jeu

- Le rendu des interfaces dans CEF (polices `nui://`, cadres `border-image`, glyphes des poinçons) : chaque
  `web/index.html` s'ouvre aussi dans un navigateur pour comparer.
- L'existence des modèles de props (arbres, filons, stations, plantes, puits, grenier) et des scénarios d'animation de la
  config : un modèle inconnu est signalé dans la console du client (`modèle inconnu 'x'`) et il n'y a simplement pas de
  prop ; une animation inconnue laisse le personnage immobile.
- L'attache des accessoires en main (os 57005, décalages par modèle) : à régler objet par objet dans `held`.
- La réception des state bags globaux à la connexion (stations, parcelles) : si les props ne s'affichent pas au premier
  passage, c'est ce point. La récolte n'en utilise plus depuis 1.6.0 (§ 3.4 : abonnements de zone du core).

## 9. Comment me remonter un problème

Pour chaque anomalie : le numéro du test (ex. « 3.2-7 »), ce qui s'est passé, la ou les lignes de la console
serveur ou client (F8) au même moment, et si possible l'état en base. Les lignes qui commencent par le nom du module
(`[vava_gathering]`…) sont les plus parlantes.
