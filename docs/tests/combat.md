# Combat — procédure de test en jeu

Procédure pour vérifier en jeu le combat de la phase 4 (`docs/plan/COMBAT_V1.md`). Section 1 : la **chaîne de dégâts
commune** de `vava_health` 1.4.0 (T-110 ; coup déjà lancé et `vocabulary().pvp` : T-116), éprouvée avec la ressource
d'essai `vava_example_combat` 1.0.0 et `vava_needs` 1.2.1. Section 2 : les **armes** de `vava_combat` 1.0.0 (T-111),
essayées avec `/frapper_arme` de `vava_example_combat` 1.1.0. Section 3 : les **techniques** de `vava_combat` 1.2.0
(T-112 : coups à la souris jugés par le serveur, enchaînement, chancellement, mode combat, dégainer et rengainer).
Section 4 : la **défense** de `vava_combat` 1.3.0 (T-113 : parade, garde, pas de côté, garde brisée) ;
section 6 : la **magie et le mode combat** (`vava_magic` 2.12.0, T-149) ; section 7 : les **chiffres des coups**
(`vava_combat` 1.4.0, `vava_hud` 1.7.0, T-155) ; section 8 : les **mannequins d'entraînement** (`vava_combat` 1.5.0,
`vava_health` 1.6.0, `vava_magic` 2.14.0, T-156). L'endurance (T-114) viendra ensuite.
Comptez 1 h par section, presque tout à deux ; les tests à deux joueurs sont marqués **(2 joueurs)**. Un test se cite
« combat 1-8 ».

## 0. Préparation

1. **Préparation commune** : [LISEZMOI.md](LISEZMOI.md) (ordre de démarrage, compte du Conseil, consoles, resmon,
   remontée des écarts).
2. **Mode développement** : `set vava_env dev` au `server.cfg` du serveur de test, puis `ensure vava_example_combat`
   **après** `vava_health` (et `vava_dev_characters`, `vava_example_items` comme en [sante 0.2](sante.md)). A est
   Souverain (droit `staff`), B a l'ACE `vava.dev` (`add_ace identifier.license:<licence de B> vava.dev allow`).
3. **Outils** : ceux de [sante 0](sante.md) — `/vie`, `/vie <pour cent>`, `/besoins`, vol libre (`F2`, droit `tools`)
   pour tomber ; et ceux de l'essai (README de `examples/vava_example_combat`) : `/frapper <n°> <points> [type]
   [partie]`, `/esquive`, `/bouclier <points> | erreur | non`, `/resistance <type> <pour cent> | non`, `/chaine`,
   `/arme pistolet | couteau | non`, `/explosion`, `/tricher`. Le n° d'un joueur se lit dans le Registre (`F10`).
4. **Consoles** : `F8` chez A et chez B, console du serveur ouverte ; une requête SQL sous la main
   (`SELECT * FROM vava_health_hits ORDER BY id DESC LIMIT 5`).
5. **Invulnérabilité** du Registre éteinte chez les deux, vol libre et observation compris : depuis `vava_admin` 1.11.0
   (T-138), elles annulent tout coup et tout sort qui blessent (`invulnerable`, `spectating` ; essai :
   [registre 9 bis](registre.md)) ; depuis `vava_magic` 2.12.0 (T-149), les effets sans dégâts des sorts (recul,
   mouillé, ralenti) les épargnent aussi.
   `/chaine` montre alors aussi `vava_admin:invulnerabilite` en tête de liste, à l'étape annulation.
6. **Armes** (section 2) : `ensure vava_combat` **après** `vava_health` et `vava_crafting`, et `vava_example_combat`
   1.1.0 (`/frapper_arme`). A est Souverain ; `/metiers niveau <A> forge 60` et `/metiers niveau <A> menuiserie 30` ;
   matières par `/catalogue materiau` (lingots de fer de palier 3, chêne, pin, cuir) et un marteau de forge. Outils :
   `/armes liste | voir <n°> | user <n°> <points>` (droit `metiers`), `/frapper_arme <n°> [multiplicateur]
   [technique]`.
7. **Techniques** (section 3) : la préparation 0.2 à 0.6, `vava_combat` 1.2.0. A et B ont chacun une Épée courte
   (`/catalogue arme`) ; A est mage (`/magie` du Conseil) et connaît la Boule de feu ; `vava_example_combat` 1.1.0 pour
   `/esquive`, `/bouclier`, `/vie`. Un troisième joueur C pour les tests 13 et 27. Touches par défaut : clic gauche
   (attaque légère), clic droit (attaque lourde), clic molette (verrouiller ; maintenu : relâcher).
8. **Défense** (section 4) : la préparation 0.7, `vava_combat` 1.3.0. A et B ont chacun une Épée courte (`/catalogue
   arme`), B aussi un Bouclier rond (« utiliser » pour l'accrocher) ; `vava_example_combat` pour `/vie`, `/chaine`. Un
   troisième joueur C pour les tests 24 et 25. Noter le ping de chacun (F8 : `netgraph`). Touches : **R** (appui bref :
   parer ; maintenu : se garder), **Espace** (pas de côté, mode combat actif seulement).
9. **Mannequins** (section 8) : la préparation 0.8, `vava_combat` 1.5.0, `vava_health` 1.6.0, `vava_magic` 2.14.0 ;
   T-155 en place (`vava_hud` 1.7.0, « Chiffres des coups » à « Donnés et reçus ») ; A et B ont une Épée courte, A est
   mage (Boule de feu niveau 3, Nova ardente, Secousse : `/magie` du Conseil) ; aller à la cour provisoire de Paleto
   (`dummies.list` de `config_client.lua` de `vava_combat`) ; `/armes voir <A>` pour la solidité ; un troisième joueur
   C témoin.

## 1. Chaîne de dégâts


La vie est tenue par le serveur : un coup la baisse aussitôt, le client applique. Les modificateurs s'appliquent dans
l'ordre annulation → esquive → parade → blocage → bouclier → résistance. Les coups natifs entre joueurs sont annulés
par le serveur ; la chute et la noyade restent, lues sur le ped.

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur. | Console : migration `0001_hits.sql` de `vava_health` appliquée, `vava_health` v1.3.0 prêt, puis `vava_example_combat` prêt, sa ligne « mode développement : … » (voulue) et trois lignes « modificateur 'vava_example_combat:…' déclaré » (plus trois lignes de `vava_health` « … déclaré par vava_example_combat »). Aucun autre avertissement. |
| 2 | **(2 joueurs)** B `/vie 60` ; A `/frapper <B> 25`. | Médaillon de B à 35 % dans la demi-seconde ; `/vie` de B → 35 % ; chez A seul : « appliqué 25, bloqué 0, absorbé 0, résisté 0, ajouté 0 — vie 35 % ». |
| 3 | **(2 joueurs)** A `/frapper <B> 40`. | B s'effondre **aussitôt** (sans attendre 500 ms), écran à terre. `SELECT * FROM vava_health_hits ORDER BY id DESC LIMIT 2` : deux lignes, `origin = vava_example_combat`, `kind = tranchant`, la seconde `applied = 35.0`, `downed = 1`, position remplie. |
| 4 | **(2 joueurs)** B à terre ; A `/frapper <B> 10`. | Chez A : « annulé : à terre ». Rien chez B, aucune nouvelle ligne de journal. |
| 5 | B relevé (Registre → Soigner), `/vie 50` ; chute de quelques mètres (vol libre). | Le médaillon baisse ; `/vie` donne la même valeur à 2 % près ; aucune ligne de journal. |
| 6 | Chute mortelle. | À terre ; une ligne de journal `origin = vava_health`, `kind = monde`, `source_id` vide, `downed = 1`. |
| 7 | B relevé ; `/vie 40`, puis une bande de lin. Puis, à observer : `/vie 40`, une bande, et une petite chute dans la seconde qui suit ; recommencer avec la chute 3 s après la bande. | 60 %, et **reste** 60 % trois secondes plus tard (le soin n'est pas pris pour une perte). À noter : une chute faite avant que le client ait appliqué le soin peut être effacée par lui (au profit du joueur, fenêtre d'application de 1,5 s + 2 × ping) ; une chute 3 s après est toujours comptée. |
| 8 | **(2 joueurs)** B `/bouclier 20` ; A `/frapper <B> 30` deux fois. | 1er : « absorbé 20 », B perd 10 ; chez B « bouclier brisé. ». 2e : B perd 30. |
| 9 | **(2 joueurs)** B `/vie 100`, `/esquive` ; A `/frapper <B> 30` dans les 3 s, puis après. | 1er : « annulé : esquive », B ne perd rien ; 2e : appliqué 30. |
| 10 | **(2 joueurs)** B `/esquive` puis `/bouclier 20` ; A `/frapper <B> 30` dans les 3 s ; B `/chaine`. | Annulé par l'esquive ; `/chaine` : `esquive` avant `bouclier` avant `resistance`, et chez B « bouclier 20 » (le bouclier n'a pas été appelé). |
| 11 | **(2 joueurs)** B `/vie 100`, `/bouclier 20`, `/resistance feu 40` ; A `/frapper <B> 60 feu`, puis `/frapper <B> 30 tranchant`. | 1er : absorbé 20, résisté 16, appliqué 24. 2e : appliqué 30 (la résistance ne vaut que pour le feu). |
| 12 | **(2 joueurs)** B `/vie 100`, `/resistance feu -50` ; A `/frapper <B> 20 feu`. | « ajouté 10 », appliqué 30. B `/resistance non`. |
| 13 | **(2 joueurs)** B `/vie 100`, `/bouclier erreur` ; A `/frapper <B> 10` trois fois. | Appliqué 10 à chaque fois ; console du serveur : **une** ligne d'erreur du modificateur `vava_example_combat:bouclier` (pas trois). B `/bouclier non`. |
| 14 | `restart vava_example_combat`, puis `/chaine` ; `restart vava_health`, puis `/chaine`. | Après chaque redémarrage, les trois modificateurs reviennent, dans le même ordre. Vie de B inchangée par les redémarrages. |
| 15 | **(2 joueurs)** A frappe B au poing (attaque native) dix fois. | B ne perd rien, ne tombe pas (A ne parvient sans doute même pas à le viser : tir ami coupé). Console du serveur : au plus une ligne « joueur A : dégâts natifs annulés : … » par minute. |
| 16 | **(2 joueurs)** A `/arme pistolet`, tire sur B ; puis `/arme couteau`, frappe B ; `/arme non`. | Aucune perte chez B, jamais à terre. A peut voir du sang ou un tressaillement chez lui seul (prédiction de son client) : à noter, sans conséquence. Avec `vava_combat` démarré, l'arme de `/arme` est retirée en moins d'une seconde (combat 2-5) : faire ce test après `stop vava_combat`. |
| 17 | **(2 joueurs)** A `/explosion` près de B (B à 5 m devant A). | B ne perd rien (l'explosion n'arrive pas chez B) ; console : annulation comptée (« explosion(s) »). |
| 18 | B nage sous l'eau jusqu'à la noyade. | Perte de vie puis à terre (natif, lu par le serveur) ; une ligne de journal `kind = monde`, `downed = 1`. |
| 19 | **(2 joueurs)** Magie (personnage mage) : A lance une Boule de feu sur B. | Mêmes dégâts qu'avant (README de `vava_magic`). Depuis `vava_magic` 2.9.0 (T-116), le sort appelle `hit` lui-même : une ligne `vava_health_hits` par coup (`origin = vava_magic`, `ref = boule_de_feu`, `kind = feu`, `source_id` = personnage de A) ; plus rien dans `vava_magic_damage_log`. Détail : [magie 18](magie.md). |
| 20 | B relevé, vie 20 % ; faim et soif à 0 (`/besoins 0 0`). | Perte à chaque passage (une minute), puis à terre ; ligne de journal `kind = privation`, `origin = vava_needs`, `downed = 1` à la chute seulement. |
| 21 | B relevé, `/vie 30`, puis `/tricher` (remet sa vie GTA au maximum sur son seul client, comme un client modifié). | Médaillon de B un instant plein, puis revenu à 30 % en 2 à 3 s ; `/vie` → 30 % tout du long ; console du serveur : « joueur B : vie du client au-dessus de celle du serveur (1 fois), remise ». Un client qui insisterait serait corrigé de plus en plus rarement (4, 8, 16, puis 30 s). |
| 22 | **(2 joueurs)** Après les tests 2 à 4 : `/vava_reseau joueur <B>`, puis `/vava_reseau joueur <A>`. | Chez B : `vava_health:set` (≈ 26 o par coup), `vava_health:down`. Chez A : **aucun** évènement `vava_health`. Un troisième joueur à 50 m : rien. |
| 23 | B à 35 % : `restart vava_health`. | Médaillon de retour à 35 % ; ni baisse ni remontée dans les 5 s qui suivent. |
| 24 | **(2 joueurs)** A `/frapper <B> 20` puis B quitte dans la seconde ; B revient. | Vie au retour = valeur après le coup (écrite au départ). |
| 25 | `resmon 1` chez B, au repos puis pendant les tests 8 à 12. | `vava_health` ≤ 0,02 ms au repos, inchangé pendant les coups (aucune boucle client ajoutée) ; `vava_example_combat` 0,00 ms. |
| 26 | Arrêt : `stop vava_health` pendant que B est à 70 % après des coups ; `ensure vava_health`. | Vie de B à 70 % (écrite à l'arrêt) ; `vava_health_hits` contient les coups d'avant l'arrêt. Pendant l'arrêt, plus aucune chaîne ni annulation native (comme toute la santé) : à ne jamais faire sur un serveur ouvert. |
| 27 | **(2 joueurs)** Mesure : B debout, 10 min sans combat ni soin ; puis `/vava_reseau joueur <B>`. | **0** `vava_health:set` sur la minute (rien n'est envoyé à un client d'accord avec le serveur). |
| 28 | **(2 joueurs)** Mesure : console du serveur, une seule ligne `frapper <B> 2; frapper <B> 2; frapper <B> 2; frapper <B> 2; frapper <B> 2` (cinq coups en moins de 100 ms ; un joueur est limité à une commande par 0,5 s) ; puis `/vava_reseau joueur <B>`. | B perd 10 ; les coups d'un même tour ne coûtent qu'**un** `vava_health:set`. Si la console les étale sur plusieurs tours, noter le nombre de messages (jamais plus que de coups). |
| 29 | Mesure : B change de modèle (créateur d'apparence, ou reprise de personnage) à 60 %. | Au plus **une** ligne « vie du client au-dessus de celle du serveur » ; vie de retour à 60 %. |
| 30 | Mesure : personnage féminin (`mp_f_freemode_01`) ; F8 `GetEntityMaxHealth(PlayerPedId())` (ou noter le médaillon) et `/vie` après `/vie 50`. | La vie maximale lue par le serveur est la même que celle du client (200) : `/vie 50` → médaillon 50 %, aucune correction ni perte dans les 5 s. |
| 31 | **(2 joueurs, facultatif)** Renversement : A en véhicule (ou plus tard en monture) roule sur B. | Noter ce qui se passe : perte de B lue comme perte native (`kind = monde` au hook, aucune ligne de journal sauf mise à terre) ou coup annulé (`weaponDamageEvent` compté chez A dans la console). À me remonter dans les deux cas. |
| 32 | **(2 joueurs)** Coup déjà lancé (1.4.0, avec `vava_magic` 2.9.0, A mage) : B garde `/frapper <A> 100` tapé d'avance. A lance un Projectile de roche N1 sur B à 15 m (1,2 s de vol) ; B valide dès le lancer. Puis réglage `chain.launchedMaxMs = 500` (`restart vava_health`), recommencer ; remettre 4000. | 1er essai : A tombe pendant le vol, la roche blesse B quand même (−14, ligne `vava_health_hits` `ref = projectile_de_roche`). 2e essai : la roche arrive plus de 0,5 s après le lancement, B ne perd rien (`source_downed`, aucune ligne). Un sort ne peut pas être lancé à terre (« Vous êtes à terre. »). |
| 33 | `chain.pvp = false` (`restart vava_health` : la magie relit le réglage à son retour) ; A (mage) lance une Vague et un Trait de glace sur B. | B n'est ni poussé, ni mouillé, ni ralenti, ne perd rien : la magie lit `pvp` dans `vocabulary()` et coupe aussi ses effets sans dégâts. Remettre `chain.pvp = true`. |

## 2. Armes

On ne se bat qu'avec ce que le royaume a façonné : l'arme en main est l'objet tenu de l'inventaire, sa qualité de forge
règle le coup (± 15 %), chaque coup qui touche l'use, à 0 elle est émoussée (coups à moitié) jusqu'à la réparation. Le
bouclier s'accroche par « utiliser ». Aucun coup donné par un joueur avant T-112 : `/frapper_arme` essaie la brique
serveur `strike`. Préparation : 0.6.

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur. | Console : `vava_combat` v1.0.0 « prêt : 6 objets et 6 recettes déclarés, 7 armes au catalogue », aucun avertissement (l'Épée courte adoptée, solidité 150 d'accord avec sa recette). |
| 2 | A `/armes liste`. | Deux messages de chat (huit lignes en tout) : « Armes du royaume (7) : » puis Épée courte, Hache d'armes, Masse d'armes, Épée longue, Dague, Bâton ferré, Bouclier rond (par catégorie), chacune « modèle provisoire ». |
| 3 | A `/catalogue arme`. | Les six armes nouvelles ont leur image ; fiche : catégorie arme, aucune solidité (pile du catalogue). |
| 4 | **(2 joueurs)** A prend l'Épée longue dans les Mains. | Machette en main droite chez A ; B, à 10 m, la voit dans la seconde. |
| 5 | A clic gauche, `R`, `Q`, `F` près de B, mains vides puis Dague en main ; puis `/arme pistolet` (exemple). | Aucun coup de poing ni de lame natif, aucune animation d'attaque ; le pistolet disparaît en moins d'une seconde, aucun tir ; F8 : une ligne « arme de GTA retirée ». Aucune erreur. |
| 6 | A (non mage) maintient `Tab`. | Rien, ou une roue des armes vide sans effet : noter ce qui s'affiche (§ 5). |
| 7 | A à la forge, marteau en main. | Recettes : Dague (15), Hache d'armes (25), Masse d'armes (25), Épée courte (30, si apprise) ; l'Épée longue (50) absente tant qu'elle n'est pas apprise. |
| 8 | A forge une Hache d'armes. | Pièce signée « Façonné par A », poinçon, qualité ≤ 60, solidité 140 / 140. |
| 9 | Console `vava_fondateur <A> forge 90 epee_longue`, puis A forge une Épée longue ; **(2 joueurs)** B à 8 m, forge 50. | L'Épée longue apparaît dans la forge, se forge (160 / 160) ; B reçoit une leçon (1 / 3). |
| 10 | A à l'établi : Bâton ferré, puis Bouclier rond. | Les deux recettes listées, pièces signées (120 et 150). |
| 11 | A, Épée courte de qualité q en main, `/armes voir <A>`. | « en main : Épée courte, qualité q, … coup 12 → c » avec c = 12 × (0,85 + 0,003 × q) arrondi au dixième ; journal du Registre « Combat : armes consultées ». |
| 12 | **(2 joueurs)** B `/vie 100` ; A, Épée courte en main, à 2 m, `/frapper_arme <B>`. | B perd le coup effectif du test 11 ; chez A seul : « appliqué …, — vie … % — Épée courte, solidité 149 / 150 » (ou 150 / 150 : pièce de qualité, usure épargnée). Une ligne `vava_health_hits` avec `weapon = epee_courte`, `origin = vava_example_combat`. |
| 13 | **(2 joueurs)** A mains vides, puis Hache de bûcheron en main, `/frapper_arme <B>`. | « refusé : aucune arme en main » les deux fois ; B ne perd rien. |
| 14 | **(2 joueurs)** B à 8 m ; A `/frapper_arme <B>`. | « refusé : trop loin » ; solidité inchangée. |
| 15 | **(2 joueurs)** B `/esquive` ; A `/frapper_arme <B>` dans les 3 s. | « annulé : esquive — Épée courte, solidité … » ; solidité **inchangée**. |
| 16 | A `/armes user <A> 110` (Épée courte à 149). | « Épée courte : solidité 149 → 39 » ; puis `/frapper_arme <B>` jusqu'à ce qu'elle passe de 38 à 37 : à ce coup-là, et à lui seul, **une** notification « l'arme s'émousse ». |
| 17 | `/armes user <A> 37`, puis `/frapper_arme <B>`. | Notification « l'arme est émoussée » à 0 ; le coup suivant fait la **moitié** du coup du test 12 (« , émoussée ») ; la solidité reste 0. |
| 18 | A à la forge, onglet Réparation. | L'Épée courte y figure ; réparée : 145 / 145, histoire « Réparation par A » ; `/frapper_arme <B>` : coup plein. |
| 19 | **(2 joueurs)** A « utilise » le Bouclier rond, mains vides. | « Bouclier rond accroché, prêt à servir. » ; B voit le bouclier **dans le dos** de A. Le bouclier reste dans la besace (poids compté). |
| 20 | **(2 joueurs)** A prend l'Épée courte en main ; puis l'Épée longue ; puis la repose. | Bouclier au **bras gauche** dans la seconde, chez A et chez B ; avec l'Épée longue, de nouveau dans le dos ; mains vides : dos. |
| 21 | **(2 joueurs)** A « utilise » encore le bouclier ; puis le raccroche et le jette au sol. | Décroché : il disparaît chez A et B. Jeté : il disparaît aussitôt chez les deux, il est dans le sac au sol. |
| 22 | **(2 joueurs)** A, bouclier accroché, se déconnecte et revient ; puis `restart vava_combat`. | Au retour, bouclier en place. Pendant l'arrêt : aucun bouclier fantôme ; au redémarrage, de nouveau en place, un seul. |
| 23 | **(2 joueurs)** B s'éloigne à 600 m puis revient près de A (bouclier accroché) ; puis B s'arrête à 150 m de A (vol libre, `F2`), avance à 100 m. | Au retour, le bouclier de A apparaît avec son ped. À 150 m, B voit A **sans** bouclier ; à 100 m, il réapparaît dans la seconde (`shield.showRadius`, 120 m). |
| 24 | A à terre (`/vie 0`), tente d'utiliser le bouclier. | Refusé (l'inventaire refuse tout geste à terre, ou « Vous ne pouvez pas faire cela à terre. »). |
| 25 | **(2 joueurs)** Après 12 à 21 : `/vava_reseau joueur <A>` puis `<B>`. | Chez A : `vava_combat:notify` aux seuils seulement, `vava_health:set` jamais (A ne reçoit pas de coup). Chez B : `vava_health:set` par coup. Aucun évènement `vava_combat` chez un troisième joueur loin. |
| 26 | `resmon 1` chez B au repos, puis avec A armé et bouclier accroché à côté. | `vava_combat` ≤ 0,01 ms dans les deux cas (aucune boucle par image). |
| 27 | `stop vava_combat`, puis `ensure vava_combat`. | Arrêt : armes « gardées à part » par l'inventaire, recettes absentes des stations, bouclier retiré des peds, coups de poing natifs revenus mais sans dégâts (annulés par `vava_health`). Retour : tout revient, sans perte. |
| 28 | Mage : A, Épée courte en main, lance une Boule de feu. | Refusé : « Il vous faut les mains libres pour incanter : rangez votre arme. » (`vava_magic` 2.10.0, T-140 : détail en [magie 19](magie.md)). |
| 29 | Un membre du Conseil sans le droit `metiers` (ni l'ACE `combat.admin`) : `/armes user <A> 5`. | « Ce registre est réservé au Conseil. » ; solidité inchangée, rien au journal. |
| 30 | **(2 joueurs, si un outil d'instance existe)** B placé dans une autre instance (routing bucket) au même endroit que A ; A `/frapper_arme <B>`. | « refusé : trop loin » ; B ne perd rien, solidité inchangée. |

## 3. Techniques

L'épée à la main, on frappe à la souris : clic gauche pour la Taille descendante, puis l'Estoc rapide et le Revers qui
s'enchaînent pendant la récupération, clic droit pour le Fendant qui fait chanceler. Le geste part tout de suite ; le
**serveur** juge le coup au moment où la lame passe, sur les positions et le cap qu'il lit lui-même (portée de la
technique + 0,25 m, demi-angle + 10°, aucun contrôle des murs). Dégainer prend 0,8 s, rengainer 1,5 s (pas de sort
avant). Préparation : 0.7.

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur. | Console : `vava_combat` v1.2.0 « prêt : 6 objets et 6 recettes déclarés, 7 armes au catalogue, 4 techniques, 1 style(s) » ; aucun avertissement. |
| 2 | A ouvre le Codex (`F1`). | Chapitre Combat : attaque légère (Clic gauche), attaque lourde (Clic droit), verrouiller (Clic molette), et `/armes`. |
| 3 | A prend l'Épée courte en main, et clique aussitôt. | Geste de dégainer ; dans les 0,8 s : rien, ou « Vous n'avez pas encore l'arme en garde. » ; après : la Taille part. |
| 4 | A clic gauche dans le vide, seul. | Geste aussitôt ; aucune notification ; `/vava_reseau joueur <A>` : seulement `rpc vava_combat:use`. |
| 5 | **(2 joueurs)** B `/vie 100`, face à A à 2 m ; A clic gauche. | B perd 12 (qualité 50) au moment où la lame passe ; B tressaille ; effet d'impact chez A et chez B ; solidité de l'épée − 1 ou inchangée. |
| 6 | **(2 joueurs)** A clic gauche ×3 en rythme, puis clic droit. | Taille, Estoc, Revers, Fendant enchaînés sans pause ; 4 coups chez B (12 ; 9,6 ; 10,8 ; 21,6). |
| 7 | **(2 joueurs)** A martèle le clic gauche (10 / s) pendant 5 s. | Pas plus d'un coup par cycle ; jamais plus de 4 coups de suite sans la pause de la récupération ; aucun message d'erreur ; F8 propre. |
| 8 | **(2 joueurs)** B à 3,5 m devant A ; A clic gauche ; puis B à 2 m. | À 3,5 m : le geste, **aucun** dégât ; à 2 m : dégâts. |
| 9 | **(2 joueurs)** B à 1,5 m sur le côté (90°), A ne se tourne pas (sans verrou, caméra ailleurs que vers B). | Aucun dégât ; avec le verrou (clic molette sur B) : A se tourne vers B, dégâts. |
| 10 | **(2 joueurs)** A clic droit (Fendant, 0,65 s de préparation) ; B recule aussitôt de 2 m. | Le Fendant manque si B est sorti de portée avant la frappe. |
| 11 | **(2 joueurs)** A Fendant sur B. | B chancelle (geste, secousse), ne peut pas frapper 0,9 s (« Vous chancelez. ») ; un second Fendant dans les 3 s suivantes : dégâts sans chancellement ; plus tard : chancelle de nouveau. |
| 12 | **(2 joueurs)** B prépare un Fendant, A le touche d'un Fendant avant la frappe de B ; B reclique dès la fin du chancellement. | Le Fendant de B est coupé, aucun dégât chez A. B ne repart qu'à la fin du cycle de son Fendant coupé (≈ 1,5 s après son départ), sans geste refusé entre-temps : un coup coupé compte comme donné. |
| 13 | **(3 joueurs)** A clic molette avec B et C en vue. | Anneau sous le plus proche du centre de l'écran ; second clic : l'autre ; maintenu : relâché ; B s'éloigne à 8 m : relâché. Rien chez B ni chez C. |
| 14 | **(2 joueurs)** B `/esquive` puis A frappe. | Aucun dégât, aucun sang ; `/vava_reseau joueur <B>` : **aucun** `vava_combat:hit` (une esquive ne se montre pas). |
| 15 | **(2 joueurs)** B `/bouclier 50` puis A frappe. | Dégâts absorbés (B ne perd rien), aucun sang ; depuis 1.4.0 (T-155), un `vava_combat:hit` (`absorb`) aux seuls A et B, « Absorbé » (7-12). |
| 16 | **(2 joueurs)** B à terre (`/vie 0`) devant A ; A frappe. | Aucun dégât, aucun `vava_combat:hit`. |
| 17 | A à terre, clic gauche. | Rien (mode combat endormi). |
| 18 | **(2 joueurs)** `chain.pvp = false` (config de `vava_health`, redémarrage) ; A frappe B trois fois. | Une seule notification « Les combats entre habitants sont suspendus : votre lame s'arrête. » ; B ne perd rien. |
| 19 | Mage : A, Épée en main, la range, puis clic gauche (Boule de feu prête) dans la seconde. | Geste de rengainer ; pendant 1,5 s, un avis « Vous rengainez votre arme : vos mains seront libres dans un instant. » (`vava_magic` 2.12.0 ; avant : « … rangez votre arme. ») ; ensuite le mode magie s'éveille (clic droit), le sort part. |
| 20 | Mage : A lance une Boule de feu, puis prend l'épée et frappe aussitôt. | Pas de coup avant 0,8 s après la prise en main. |
| 21 | Mage : A incante, prend l'épée pendant l'incantation. | Incantation brisée sans coût (T-140, inchangé). |
| 22 | A, Épée longue en main, clic gauche (plusieurs fois). | « Vous ne connaissez aucune technique pour cette arme. » une fois ; rien d'autre. |
| 23 | A, l'épée en main, ouvre l'inventaire (`I`) et clique ; puis le referme et appuie sur Échap, puis sur `P`. | Aucun coup pendant que l'inventaire est ouvert ; la bannière (Échap) s'ouvre normalement hors combat ; `P` aussi. |
| 24 | **(2 joueurs)** Juste après un coup porté, B appuie sur Échap. | « Pas de répit au cœur d'un combat… » (fenêtre de 10 s de `vava_pause`). |
| 25 | **(2 joueurs)** Ping : B à 150 ms (ou loin du serveur). Coups de A sur B immobile, puis sur B qui recule. | Immobile : chaque coup porte ; qui recule à portée limite : manques plausibles. Noter les sensations (porte T-119). |
| 26 | **(2 joueurs)** A frappe B à travers un mur fin (porte fermée) à 1,5 m. | Noter si le coup porte (aucun contrôle des murs : décision du porteur du projet). |
| 27 | **(3 joueurs)** A frappe B ; C à 50 m. | `/vava_reseau joueur <C>` : aucun évènement `vava_combat`. Chez B : `vava_combat:hit` et `vava_health:set` par coup. |
| 28 | `resmon 1` chez A : au repos l'épée en main, puis en mêlée. | `vava_combat` ≤ 0,01 ms au repos (mode endormi) ; ≤ 0,15 ms en mêlée ; 10 s après le dernier coup, de nouveau au repos. |
| 29 | **(2 joueurs)** A se déconnecte pendant la préparation d'un Fendant. | Aucun coup chez B ; console sans erreur. |
| 30 | `restart vava_combat` pendant une mêlée. | Coups en cours perdus sans erreur ; techniques de nouveau jouables au retour (arme à reprendre en main si l'inventaire l'a gardée à part). |
| 31 | Console : `debug.logSamples = true` (config.lua), redémarrage, coups à portée limite. | Une ligne par relevé (`coup <n> <technique> relevé <k> : <joueur> d=… a=… portée … → issue`) : base des réglages de T-119. |
| 32 | A clic droit (Fendant), range l'épée aussitôt, la reprend et clique de nouveau, plusieurs fois. | Aucun coup avant la fin du cycle du Fendant coupé (1,55 s après son départ) ni avant 0,8 s de dégainer : couper son propre coup ne fait pas frapper plus vite. |

## 4. Défense

Une épée à la main, on lève la garde en maintenant **R** : les coups de face sont amortis (bien mieux au bouclier),
jusqu'à ce que la garde cède. Un appui bref sur **R** au bon moment **pare** : la lame est détournée, l'attaquant
chancelle. **Espace** fait un pas de côté. Le **serveur** tient chaque fenêtre ; le client ne fait que demander.
Préparation : 0.8.

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur ; `/chaine`. | Console : `vava_combat` v1.3.0 prêt, « 7 techniques, 1 style(s), 3 modificateur(s) de la défense » ; `/chaine` : `vava_combat:esquive`, `vava_combat:parade`, `vava_combat:blocage` à leurs étapes (esquive, parade, blocage). |
| 2 | A ouvre le Codex, chapitre Combat. | Deux touches de plus : « parer (appui bref) ou se garder (maintenir) » (R), « pas de côté (mode combat actif) » (Espace). |
| 3 | A, épée en main, maintient R 5 s, seul, puis relâche. | Geste de parade puis garde tenue (on marche, on ne court pas). `/vava_reseau joueur <A>` : un `use` à l'appui, un `use` à la garde, un `lower` au relâchement, **rien** pendant la tenue. |
| 4 | **(2 joueurs)** B `/vie 100`, garde levée face à A ; A Taille. | B perd 7,2 (pas 12) ; étincelles, pas de sang, B ne tressaille pas ; l'épée de B s'use le plus souvent (`/armes voir <B>`, 4 fois sur 5 à qualité 50). |
| 5 | **(2 joueurs)** Idem, B bouclier accroché (au bras) et épée en main. | B perd 3,6 ; la solidité du **bouclier** baisse (`/armes voir <B>`), pas celle de l'épée. |
| 6 | **(2 joueurs)** A frappe B de dos, garde levée. | 12 perdus, sang ; la garde reste levée. |
| 7 | **(2 joueurs)** A enchaîne 4 coups légers sur la garde de B (épée), en moins de 3 s entre deux. | Au 4e : B chancelle, « Votre garde est brisée. » ; R maintenue ne relève rien pendant 1,2 s (il faut relâcher et ré-appuyer). |
| 8 | **(2 joueurs)** Même chose, B au bouclier. | La garde tient 5 coups, cède au 6e. |
| 9 | **(2 joueurs)** A deux Fendants sur la garde de B. | Le premier : bloqué (8,6 arrêtés à l'épée), B ne chancelle pas ; le second brise la garde. |
| 10 | **(2 joueurs)** B appuie brièvement R quand la lame de A arrive (Taille). | Aucun dégât ; A chancelle (geste, secousse) et ne frappe plus 0,9 s ; étincelles chez les deux. |
| 11 | **(2 joueurs)** B pare trop tôt, puis ré-appuie aussitôt R. | La seconde parade ne part pas avant 0,6 s après la fin de la première (rien n'est dit) ; la Taille porte. |
| 12 | **(2 joueurs)** B pare un Fendant. | Le Fendant porte et B chancelle : il faut le bloquer ou l'esquiver. |
| 13 | **(2 joueurs)** B martèle R (10 / s) pendant les coups de A. | Pas plus d'une fenêtre utile par cycle ; A n'est pas paré à chaque coup ; F8 propre. |
| 14 | **(2 joueurs)** B Espace au moment de la Taille de A. | Aucun dégât, aucun effet ; l'arme de A ne s'use pas. |
| 15 | **(2 joueurs)** B martèle Espace, puis clique et maintient R aussitôt après un pas. | Un pas de côté toutes les 1,5 s au plus ; `/vava_reseau joueur <B>` : aucun `use` entre deux pas ; l'attaque et la garde partent sans attendre la fin du délai du pas. |
| 16 | **(2 joueurs)** Mage : A lance une Boule de feu sur B qui fait un pas de côté au bon moment ; puis un Mur de flammes. | La Boule de feu est évitée ; le mur (zone, effet qui dure) blesse quand même. |
| 17 | A, épée en main, mode combat endormi (10 s sans rien), Espace. | Saut normal de GTA, pas de roulade. |
| 18 | A garde levée, clic gauche. | Aucun coup ; après le relâchement (garde tenue plus de 0,2 s), la Taille part 0,25 s plus tard. |
| 19 | A garde levée, ouvre l'inventaire (`I`). | Garde abaissée (`lower` dans `/vava_reseau joueur <A>`). |
| 20 | A garde levée, range l'épée. | Garde tombée, geste de rengainer. |
| 21 | **(2 joueurs)** B garde levée ; A Fendant de dos. | B chancelle, garde tombée ; il doit ré-appuyer R. |
| 22 | **(2 joueurs)** B pare, puis riposte (clic gauche) aussitôt que A chancelle. | La Taille de B part au plus tôt 0,39 s après la parade et touche A ; un Fendant de B dans les 3 s ne refait pas chanceler A (immunité). |
| 23 | **(2 joueurs)** Ping : B à 150 ms ; parades sur des Tailles de A. | Noter la réussite à 30, 80, 150 ms (porte T-119 : fenêtre, préparation). |
| 24 | **(3 joueurs)** B pare ; A et C frappent ensemble, C de dos. | Le coup de face est paré ; celui de C, de dos, porte. |
| 25 | **(3 joueurs)** A frappe B en garde ; C à 50 m. | `/vava_reseau joueur <C>` : rien de `vava_combat`. Chez B : un `vava_combat:hit` (`block`) par coup, pas de `hit` en plus. |
| 26 | `chain.pvp = false` (vava_health), redémarrage ; A frappe la garde de B. | Une notification « Les combats entre habitants sont suspendus… » ; rien de bloqué, rien d'usé. |
| 27 | **(2 joueurs)** B se déconnecte garde levée ; A frappe l'endroit. | Aucune erreur console ; `restart vava_combat` ensuite propre. |
| 28 | `restart vava_health` pendant que B tient sa garde ; A frappe. | Console : « vava_health de retour : 3 modificateur(s) de la défense redéclaré(s) » ; la garde de B bloque de nouveau aussitôt. |
| 29 | `resmon 1` chez B : au repos armé, garde tenue 10 s, mêlée. Serveur : `profiler record 300` pendant une mêlée à six (dont un en garde), puis `profiler view`. | Client : au repos ≤ 0,01 ms ; garde ≈ inchangé ; mêlée ≤ 0,15 ms. Serveur : `vava_combat` (modificateurs) ≈ 1 ms par seconde de mêlée au plus ; noter la valeur (relecture réseau R-2). |
| 30 | `restart vava_combat` garde levée. | Garde perdue sans erreur ; R la relève au retour (arme à reprendre en main si l'inventaire l'a gardée à part). |
| 31 | **(2 joueurs)** Mage : B gelé ou renversé par un sort de A pendant qu'il tient sa garde ; A frappe. | Le coup porte entièrement (aucune défense sous un contrôle dur de la magie) ; un coup de B demandé alors est refusé. |

## 5. Ce que je ne peux pas avoir vérifié hors jeu

- L'annulation de `weaponDamageEvent` (champ `hitGlobalId` ou liste `hitGlobalIds` selon la version de FXServer : les
  deux sont lus) : B ne voit ni perte ni réaction ; ce que voit A (sang, tressaillement prédits) est à noter.
- `NetworkSetFriendlyFireOption(false)` et `SetCanAttackFriendly` : A ne parvient plus à viser B au poing (confort ; sans
  eux, l'annulation serveur suffit).
- La fenêtre d'application (1,5 s + 2 × ping) : jamais un soin pris pour une perte, même à 150 ms de ping (1-7) ; une
  ligne « vie du client au-dessus » sans client modifié est à me remonter.
- Une apparition non confirmée (client qui n'envoie pas sa confirmation) : la console dit « apparition non confirmée
  après 20 s, vie lue d'office » ; ne doit jamais apparaître pour un client normal.
- `vava_needs` 1.2.1 avec un `vava_health` plus ancien : repli sur `damage` (facultatif).
- `explosionEvent` annulé : l'explosion ne doit plus apparaître du tout chez les autres (son, flammes) ; l'explosion
  d'un PNJ ou du décor n'est pas concernée.
- Armes (T-111) : le drapeau de ped 122 (`DisableMelee`) coupe-t-il coups de poing, attaques au couteau natives et
  exécutions furtives ? Sinon les gestes restent visibles mais sans dégâts (filet de `vava_health`) ; le mode combat de
  T-112 les coupera image par image.
- La roue des armes (`Tab`) sans arme et sans HUD natif : invisible, ou vide et sans effet (2-6).
- Modèles provisoires (`w_me_dagger`, `w_me_hatchet`, `w_me_poolcue`, `w_me_bat`, `prop_ballistic_shield`) présents ;
  placements en main et du bouclier au bras et au dos à régler (`offset`, `rotation` de la config).
- Le bouclier change de place en moins d'une seconde quand la main change, chez le porteur et chez un voisin (2-20).
- Techniques (T-112) : noms des gestes provisoires (`melee@large_wpn@streamed_core`, `melee@knife@streamed_core`,
  `reaction@intimidation@1h`, `reaction@shove`, `melee@unarmed@streamed_variations`) et des effets (`blood_stab`,
  `bang_sparks` de `core`) présents dans le jeu (`/anim <dict> <clip>` de `examples/vava_anim_test`) ; un nom absent
  ne joue rien et écrit une ligne en F8 par minute.
- `TaskPlayAnim` d'un geste joué sur son propre ped : vu des autres joueurs (3-5, 3-11) ; effet d'impact
  (`StartParticleFxNonLoopedOnPedBone`, identifiant d'os 24818) au bon endroit.
- Boutons de la souris partagés avec la magie : depuis `vava_magic` 2.12.0 (T-149), arme en main, la magie ne dit plus
  rien et ne pose plus son anneau (section 5).
- Cap lu par le serveur pendant un virage (3-9) : le serveur juge sur le cap répliqué ; un virage très rapide au départ
  du coup peut arriver après l'ouverture de la frappe (noter si un coup tourné vers B manque).
- Secousse de caméra (`SMALL_EXPLOSION_SHAKE`, `effects.shakeName`) : sensible sans gêner (3-5, 3-11).
- Défense (T-113) : noms des gestes provisoires de garde et de parade (`anim@melee@machete@streamed_core@`,
  `plyr_block_idle`, `plyr_block_react`) et de roulade (`move_strafe@roll`, `combatroll_fwd_p1_00`, `_-90`, `_90`,
  `combatroll_bwd_p1_180`) présents (`/anim`) ; la garde en boucle (flag 49, haut du corps) vue des autres joueurs et
  synchronisée ; R et Espace sur AZERTY ; une touche liée (R, Espace) répond-elle encore quand recharger (45) et le saut
  (22) sont coupés en mode combat (4-3, 4-14) ; le sprint coupé garde levée ; parade au dernier moment à 150 ms de ping
  (4-23) ; la direction du pas de côté lue à l'appui (`GetControlNormal` 30 et 31).

## 6. La magie et le mode combat (`vava_magic` 2.12.0, T-149)

La magie se tait quand une arme du royaume est en main (mêmes boutons que le combat), dit « Vous rengainez… » pendant
le rengainement, et refuse de frapper à qui un sort a gelé, renversé ou fait chanceler (export `hardControl` de la
magie, lu par `vava_combat` à l'étape 13 de l'admission : refus `controlled`). **Aucun changement de code dans
`vava_combat`** (1.2.0) : il lisait déjà l'export s'il existe. Préparation : 0.7 ; A et B mages avec tous les sorts
(`/magie tous`), chacun une Épée courte. Le détail côté magie : [magie 20](magie.md).

| # | Faire | Attendu |
|---|---|---|
| 1 | A, Boule de feu prête, l'Épée courte en main : clic gauche, clic droit, clic molette sur B. | Taille, Fendant, verrou du combat ; **aucun** mot de la magie, **un seul** anneau (celui du combat). |
| 2 | **(2 joueurs)** B, l'épée en main, gelé par A (Trait de glace sur B mouillé) ; B clique pendant le gel. | « Vous ne pouvez pas frapper ainsi. » à chaque clic refusé ; aucun geste de coup accepté, aucun dégât chez A ; `/vava_reseau joueur <B>` : seulement `rpc vava_combat:use`. |
| 3 | **(2 joueurs)** B renversé (Vague N4), puis chancelant (Secousse) ; B clique. | Même refus tant que dure l'état (1,5 à 2 s) ; les coups repartent ensuite. |
| 4 | **(2 joueurs)** B chancelant par le Fendant de A (chancellement du combat, 0,9 s) ; B clique. | « Vous chancelez. » (`staggered`), pas `controlled` : le chancellement du combat reste distinct de celui de la magie (spec T-112 § 13-4). |
| 5 | `stop vava_magic` ; B frappe ; `ensure vava_magic`. | Les coups partent ; aucune ligne de console de `vava_combat` sur la magie. |

Prouvé hors jeu : `tests/spec/magic_combat_mode_spec.lua` (export réel de la magie lu par le bridge de `vava_combat`)
et `tests/spec/combat_use_spec.lua` (`MagicHardControl` → `controlled`).

## 7. Chiffres des coups (`vava_combat` 1.4.0, `vava_hud` 1.7.0, `vava_pause` 1.1.0, T-155)

Le montant de chaque coup monte au-dessus de la cible et s'efface en moins d'une seconde : en laiton chez l'attaquant
(ce qu'il inflige), en rouge chez la cible (ce qu'elle reçoit) ; une parade, un pas de côté, un bouclier de magie se
lisent en un mot ; une garde, en un mot sous ce qui a passé. **Les témoins ne voient aucun chiffre.** Le chiffre est celui du coup après modificateurs, jamais la
vie retirée. Préparation : 0 (A et B une Épée courte, B un Bouclier rond ; `/vie`, `/bouclier` de
`vava_example_combat`) ; un troisième joueur C, témoin. Réglage « Chiffres des coups » à « Donnés et reçus » chez tous.

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer ; A ouvre la bannière, Réglages > Interface. | `vava_hud` v1.7.0, `vava_combat` v1.4.0 prêts, aucun avertissement ; « Chiffres des coups » : Donnés et reçus, Donnés seulement, Aucun ; aide d'une ligne. |
| 2 | **(2 joueurs)** B `/vie 100` ; A frappe B d'une Taille. | Chez A : « 12 » de laiton monte au-dessus de la tête de B et s'efface en moins d'une seconde. Chez B : « 12 » rouge au-dessus de lui. |
| 3 | **(3 joueurs)** C regarde à 10 m. | C voit le sang et la réaction de B, **aucun chiffre** ; `/vava_reseau joueur <C>` : `vava_combat:hit` de la même taille qu'en 1.3.0 (3 valeurs, ≈ 23 à 29 o comptés par `core.net`). |
| 4 | **(2 joueurs)** A enchaîne Taille, Estoc, Revers sur B. | Trois chiffres en cascade (décalés, sans se couvrir, même avec un mot dessous), chacun s'efface seul. |
| 5 | **(2 joueurs)** A Fendant sur B. | Chiffre plus grand (« 22 ») et « Chancelle » dessous, chez A et chez B. |
| 6 | **(2 joueurs)** B `/vie 10` ; A frappe. | Chiffre le plus grand et « À terre » en rouge ; le chiffre est celui du coup (12), pas la vie restante. |
| 7 | **(3 joueurs)** B garde levée (épée) ; A Taille de face. | « 7 » et « Bloqué » dessous, chez les deux ; C : étincelles, aucun mot. |
| 8 | **(2 joueurs)** B bouclier au bras, garde levée ; A Taille. | « 4 » et « Bloqué » (ou « Bloqué » seul si rien ne passe). |
| 9 | **(2 joueurs)** A brise la garde de B (4 coups). | Au 4e : chiffre et « Garde brisée ». |
| 10 | **(2 joueurs)** B pare une Taille. | « Paré » chez les deux ; A chancelle comme en 1.3.0. |
| 11 | **(3 joueurs)** B fait un pas de côté au bon moment. | « Esquivé » chez A et chez B ; C ne reçoit **rien** (`/vava_reseau joueur <C>` : aucun `vava_combat:hit`). |
| 12 | **(3 joueurs)** `/bouclier 50` sur B ; A frappe. | « Absorbé » chez les deux, rien chez C. |
| 13 | **(2 joueurs)** B règle « Donnés seulement » ; A frappe B, B frappe A. | B voit les chiffres de ses coups sur A, mais plus ceux qu'il reçoit ; A voit tout. |
| 14 | **(2 joueurs)** B règle « Aucun ». | Plus rien chez B ; ses réactions, sons et étincelles restent. |
| 15 | **(2 joueurs)** `numbers.attacker = false` (`config.lua` de `vava_combat`, redémarrage). | A ne voit plus ses chiffres (ni « Paré ») ; B voit les siens ; une esquive de B : « Esquivé » chez B seulement. |
| 16 | `numbers.enabled = false`. | Plus aucun chiffre ; tout le reste comme en 1.3.0 (esquive et absorbé : aucun `vava_combat:hit`). |
| 17 | **(2 joueurs)** B frappe A pendant que la bannière de A est déployée. | Rien ne s'affiche chez A tant qu'elle est ouverte ; aucun reste à la fermeture. |
| 18 | **(2 joueurs)** A en vue subjective, B le frappe. | Le chiffre reçu apparaît au milieu de l'écran, un peu sous le centre. |
| 19 | **(2 joueurs)** A frappe B et tourne la caméra vite. | Le chiffre suit la tête de B (léger retard, sans saut). |
| 20 | **(2 joueurs)** `/vava_reseau joueur <A>` pendant 10 coups. | `vava_combat:hit` ≈ 23 à 32 o comptés par `core.net` (nom + charge) ; 4e valeur : 1 o pour `false` ou jusqu'à 127 dixièmes, 2 o jusqu'à 255, 3 o au-delà ; aucun autre évènement nouveau. |
| 21 | `resmon 1` chez A : au repos, puis pendant une rafale. | `vava_hud` au repos ≤ 0,01 ms ; pendant ≤ 0,03 ms. |
| 22 | `restart vava_hud` pendant une rafale. | Aucune erreur ; les chiffres reviennent au coup suivant. |
| 23 | `stop vava_hud`, A frappe B. | Aucune erreur F8 ; pas de chiffres ; le combat est inchangé. |
| 24 | Mettre `stackStepVh = 30` (hors bornes) dans `config_client.lua` de `vava_hud`, redémarrer, frapper. | Une ligne de console « chiffres des coups coupés : numbers.stackStepVh… » ; aucun chiffre, rien d'autre ne change. Remettre la valeur. |

Prouvé hors jeu : `tests/spec/combat_numbers_spec.lua` (montant envoyé, destinataires : participants désignés,
témoins, esquive et absorbé aux seuls participants, instance de l'attaquant, `enabled = false`), `combat_use_spec.lua`
et `combat_defense_spec.lua` (envois de la frappe et de la défense), `combat_hands_client_spec.lua` (4e valeur →
`hitText` chez l'attaquant et la cible seulement), `hud_numbers_spec.lua` et `hud_numbers_client_spec.lua` (mise en
forme, réglage, cascade, plafonds, suivi à 100 ms sans attente de 0 ms, effacement). À voir en jeu seulement : la
projection de la tête (`GetPedBoneCoords` 31086 + 0,45 m), la vue subjective, la lisibilité à 720p et en 4K, le rendu de
la page (T-119 : durée, montée, cascade, couleurs, tailles).

## 8. Mannequin d'entraînement (`vava_combat` 1.5.0, `vava_health` 1.6.0, `vava_magic` 2.14.0, T-156)

Dans la cour d'armes, des mannequins de paille (pour l'heure un sac de frappe de GTA) encaissent sans jamais tomber : le
chiffre de chaque coup monte au-dessus d'eux chez celui qui frappe, ils se balancent et se redressent seuls. Personne
n'est blessé ; la lame s'use un peu (un coup sur quatre) ; aucune XP. Les témoins voient le balancement, jamais le
chiffre. Préparation : 0.9.

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer ; console. | `vava_combat` v1.5.0 prêt, « … 3 mannequin(s) » ; `vava_health` v1.6.0 ; `vava_magic` v2.14.0 ; aucune erreur. |
| 2 | A arrive à 80 m de la cour, puis à 55 m. | Rien à 80 m ; les trois mannequins apparaissent vers 60 m, à leur place, droits. |
| 3 | A s'éloigne à 65 m, puis à 75 m. | Toujours là à 65 m ; disparus au-delà de 70 m ; pas de clignotement en restant entre 60 et 70 m. |
| 4 | A frappe le mannequin 1 d'une Taille. | « 12 » de laiton au-dessus du mannequin ; il se balance en s'écartant de A et se redresse seul en moins d'une seconde ; éclats. |
| 5 | A enchaîne Taille, Estoc, Revers. | Trois chiffres en cascade ; le mannequin repart à chaque coup ; jamais à terre. |
| 6 | A Fendant. | Chiffre plus grand (« 22 ») et « Chancelle » ; le mannequin ne fait rien de plus ; A peut frapper aussitôt après sa récupération. |
| 7 | A frappe le mannequin de dos, à 3 m, puis perché à 3 m au-dessus. | Aucun chiffre, aucun balancement. |
| 8 | **(2 joueurs)** B se tient devant le mannequin ; A frappe dans leur direction. | B est frappé (12 chez A, sang), le mannequin n'a rien. |
| 9 | **(3 joueurs)** C regarde à 10 m pendant que A frappe vite. | C voit le mannequin se balancer, **aucun chiffre** ; `/vava_reseau joueur <C>` : `vava_combat:dummy` ≈ 22 o, pas plus d'un par 0,8 s. |
| 10 | **(3 joueurs)** C à 20 m. | C ne reçoit rien de `vava_combat` (le balancement n'est pas vu). |
| 11 | A frappe 40 fois ; `/armes voir <A>`. | La solidité a baissé d'environ 8 points (un tirage : entre 4 et 12). |
| 12 | A frappe le mannequin avec une arme émoussée (`/armes user <A> 1000`). | Chiffre ≈ moitié (6). |
| 13 | A Boule de feu sur le mannequin 2. | Chiffre de laiton au-dessus de lui, balancement ; aucun état, aucune flamme qui reste. |
| 14 | A Boule de feu niveau 3 entre deux mannequins (sur l'un). | Le visé et l'autre (éclats, plus petit) montrent un chiffre chacun. |
| 15 | A Nova ardente au milieu de la cour. | Un chiffre sur chaque mannequin du rayon ; aucun n'est repoussé. |
| 16 | A Secousse sur les mannequins. | Chiffres au moment où le sol se soulève. |
| 17 | A Mur de flammes sur un mannequin. | Rien (hors v1), aucune erreur. |
| 18 | `/vie` de A avant et après 20 coups ; `/chaine`. | Vie inchangée ; `SELECT * FROM vava_health_hits ORDER BY id DESC LIMIT 5` : aucune ligne nouvelle. |
| 19 | A frappe le mannequin puis ouvre aussitôt la bannière (Échap). | La bannière s'ouvre (s'entraîner n'est pas combattre). |
| 20 | **(2 joueurs)** A incante une Boule de feu ; B frappe le mannequin à côté de lui. | L'incantation de A n'est pas brisée. |
| 21 | `chain.pvp = false` (`config.lua` de `vava_health`, redémarrage) ; A frappe le mannequin. | Le chiffre s'affiche ; aucun avis « combats suspendus ». Remettre `true`. |
| 22 | A, à terre (`/vie 0`), tente de frapper. | Rien ne part (refus du mode combat) ; une Boule de feu lancée debout juste avant porte encore. |
| 23 | A martèle le clic gauche 10 s. | Pas plus d'un coup par cycle de technique ; F8 propre ; resmon ≤ 0,03 ms. |
| 24 | `/vava_reseau joueur <A>` pendant 10 coups. | `rpc vava_combat:use` et `vava_combat:dummy` ≈ 28 o par coup ; rien d'autre de nouveau. |
| 25 | `resmon 1` chez A : loin de la cour, près sans frapper, en frappant. | Loin ≈ 0 ; près ≤ 0,01 ms ; en frappant ≤ 0,03 ms. |
| 26 | `restart vava_combat` près de la cour. | Mannequins retirés puis recréés ; aucun reste dans le monde. |
| 27 | `restart vava_health` pendant que A frappe. | Pendant l'arrêt : ni chiffre ni balancement (aucun envoi), une ligne de console par minute (`health_unavailable`) ; dès son retour, les chiffres reviennent. |
| 28 | Mettre `model = 'inconnu_xyz'` sur `paleto_1` (`config_client.lua` de `vava_combat`), redémarrer. | Une ligne de console, botte de foin à sa place ; les autres inchangés. |

Prouvé hors jeu : `tests/spec/health_trial_spec.lua` (coup d'essai : rien d'appliqué, ni hook, ni journal, ni numéro, ni
débit des vrais coups, ni `chain.pvp`, modificateurs inscrits seulement ; chaque garde avec son contre-essai par `hit`),
`combat_dummies_spec.lua` (liste, issue « comme si », relevés réels : après les joueurs, portée, angle, hauteur,
instance, une fois par coup, Fendant, usure 1 sur 4, hook `trained`, envois et témoins au plus un par 0,8 s ;
`dummyHit`, `dummiesNear`, `dummies()`), `combat_dummies_client_spec.lua` (props à 60 / 70 m, cadence 0,5 / 2 s, repli
du modèle, déchargement et arrêt, chiffre chez l'attaquant seul, balancement qui s'arrête de lui-même) et
`magic_dummies_spec.lua` (projectiles, éclats, rempart, Nova, Secousse, zone de paix, autre personnage, `vava_combat`
absent). À voir en jeu seulement : les modèles provisoires et leur pose au sol, le sens du balancement, l'effet
d'éclats, le rayon du client qui touche le prop local d'un mannequin (Boule de feu), la mesure réseau et resmon.
