# Combat — procédure de test en jeu

Procédure pour vérifier en jeu le combat de la phase 4 (`docs/plan/COMBAT_V1.md`). Section 1 : la **chaîne de dégâts
commune** de `vava_health` 1.3.0 (T-110), éprouvée avec la ressource d'essai `vava_example_combat` 1.0.0 et
`vava_needs` 1.2.1. Section 2 : les **armes** de `vava_combat` 1.0.0 (T-111), essayées avec `/frapper_arme` de
`vava_example_combat` 1.1.0. Les sections suivantes viendront avec les techniques et la défense (T-112 à T-116).
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
5. **Invulnérabilité** du Registre éteinte chez les deux (elle n'est que locale et ne protège pas de la chaîne).
6. **Armes** (section 2) : `ensure vava_combat` **après** `vava_health` et `vava_crafting`, et `vava_example_combat`
   1.1.0 (`/frapper_arme`). A est Souverain ; `/metiers niveau <A> forge 60` et `/metiers niveau <A> menuiserie 30` ;
   matières par `/catalogue materiau` (lingots de fer de palier 3, chêne, pin, cuir) et un marteau de forge. Outils :
   `/armes liste | voir <n°> | user <n°> <points>` (droit `metiers`), `/frapper_arme <n°> [multiplicateur]
   [technique]`.

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
| 19 | **(2 joueurs)** Magie (personnage mage) : A lance une Boule de feu sur B. | Mêmes dégâts qu'avant (README de `vava_magic`) ; une ligne `vava_magic_damage_log` (inchangé jusqu'à T-116). Le sort passe par `damage` (`origin = vava_magic`, `kind = pur`, sans source) : une ligne `vava_health_hits` seulement si B est mis à terre par le sort. |
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
| 6 | A (non mage) maintient `Tab`. | Rien, ou une roue des armes vide sans effet : noter ce qui s'affiche (§ 3). |
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
| 28 | Mage : A, Épée courte en main, lance une Boule de feu. | Aujourd'hui le sort part (la magie ne regarde que l'arme GTA) ; la règle « mains vides » viendra avec T-140 (décision du 31 octobre 2026). |
| 29 | Un membre du Conseil sans le droit `metiers` (ni l'ACE `combat.admin`) : `/armes user <A> 5`. | « Ce registre est réservé au Conseil. » ; solidité inchangée, rien au journal. |
| 30 | **(2 joueurs, si un outil d'instance existe)** B placé dans une autre instance (routing bucket) au même endroit que A ; A `/frapper_arme <B>`. | « refusé : trop loin » ; B ne perd rien, solidité inchangée. |

## 3. Ce que je ne peux pas avoir vérifié hors jeu

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
