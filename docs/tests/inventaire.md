# Inventaire — procédure de test en jeu

Procédure pour vérifier en jeu `vava_inventory` 1.6.3 : besace, grille, poids, piles, ceinture, objets utilisés, sacs
au sol, conteneur ancré (grenier), catalogue de développement, et ce qui se joue à deux. Comptez une heure et demie
seul, une demi-heure de plus à deux ; les tests à deux joueurs sont marqués **(2 joueurs)**. L'emplacement **Mains**
et l'affichage des métadonnées (palier, provenance, signature, solidité) sont déjà dans [metiers.md](metiers.md),
section 1.1 : ne pas les refaire ici. Préparation commune, consoles, resmon et remontée des écarts :
[LISEZMOI.md](LISEZMOI.md).

## 0. Préparation

1. **Démarrage** : la console du serveur affiche `module 'vava_inventory' v1.6.4 prêt`, précédé de l'avertissement
   `catalogue de développement activé (/catalogue) : …` (attendu sur ce dépôt).
2. **Les deux joueurs** : A, vous, Souverain ; B, le second, sans droit. Seul A agit depuis le Registre (`F10`).
3. **Objets** : tout se prend au catalogue (`/catalogue`, double-clic), section par section. Ce qu'on dépose dans le
   catalogue disparaît au changement de page : c'est la corbeille du test, pour vider la besace entre deux sections
   (un onglet de petite catégorie laisse de la place pour déposer).
   Pour 4-9 seulement : quelques bûches récoltées (métiers 3.2), qui portent un palier.
4. **Lieu** : grenier commun du champ communal (−222, −885), ouvert par `E` ; `vava_farming` doit tourner.
   Registre → Déplacer vers un lieu.
5. **Réglages pour aller vite** (`vava_inventory/config.lua`, à remettre ensuite) : `drop.lifetimeMs = 60000`
   (défaut `600000`, 10 min) pour 8-8 ; `drop.maxPerPlayer = 2` (défaut `10`) pour 8-9. Les appliquer par
   `restart vava_inventory`, personnages en jeu ou non (les besaces se rechargent complètes : voir 14-2). Ne pas
   toucher `character` (taille et poids de la besace) : ils sont réécrits en base à chaque besace chargée.
6. **Base** : le numéro de votre besace sert au § 16 :
   `SELECT id FROM vava_inventory_containers WHERE kind = 'character' AND owner_id = '<n° du personnage>'`.

## 1. Ouvrir et fermer la besace

| # | Faire | Attendu |
|---|---|---|
| 1 | `I`. | Le curseur apparaît avec le panneau « Besace » : grille 10 × 6, poids « x,x / 25,0 kg » avec sa barre ; la section Mains et Ceinture (cinq emplacements numérotés 1 à 5) ; en bas la légende : Glisser déplacer, R pivoter, Maj diviser, Double-clic utiliser ou tenir, Clic droit actions, Échap fermer. |
| 2 | `I` à nouveau ; rouvrir, puis `Échap`. | Chacune ferme l'inventaire et rend la main au jeu. |
| 3 | Clic droit sur un objet, puis `Échap` deux fois. | Le premier ferme le menu seul, le second l'inventaire. |
| 4 | `I` pendant la sélection de personnage, puis menu pause ouvert. | Rien ne s'ouvre. |
| 5 | Inventaire ouvert, essayer de marcher. | Le personnage ne bouge pas : l'interface prend le clavier (à confirmer). D'où les éloignements faits par un tiers au § 11. |
| 6 | Paramètres → Raccourcis → FiveM : « Ouvrir l'inventaire » sur `Tab`. `Tab` ; dans l'interface, `I`, puis `Tab`. Recommencer avec `K`, puis `F5`. | `Tab` ouvre ; dans l'interface, `I` ne fait rien et `Tab` ferme : la touche de fermeture suit celle choisie pour ouvrir, relue à chaque ouverture. Même chose avec `K` et `F5`. À confirmer pour `Tab` et `F5`, que le jeu désigne par un code d'icône traduit par l'inventaire : s'ils ne ferment pas, le noter (seul `Échap` ferme alors, jamais `I`). `Échap` ferme toujours. Remettre `I`. |

## 2. Grille et déplacement

| # | Faire | Attendu |
|---|---|---|
| 1 | Glisser une bûche de chêne (1 × 2) vers une case libre. | Copie sous le pointeur, aperçu cerné de laiton à l'emplacement visé ; lâchée, la bûche y reste ; poids inchangé. |
| 2 | Pendant le glisser, `R`. | La copie pivote en 2 × 1 ; posée couchée, elle le reste après fermeture et réouverture. |
| 3 | `R` en glissant un charbon de bois (1 × 1) ou un seau (2 × 2). | Rien : un objet carré ne pivote pas. |
| 4 | Lâcher sur un objet d'un autre type, puis à cheval sur le bord de la grille. | Aperçu hachuré rouge sang, copie teintée ; au lâcher rien ne bouge, aucun message. |
| 5 | `Échap` pendant un glisser. | Le glisser s'annule, l'objet reste en place, l'inventaire reste ouvert. |
| 6 | Fermer, rouvrir. | Mêmes places, mêmes orientations. |

## 3. Poids et place

Besace vide au départ.

| # | Faire | Attendu |
|---|---|---|
| 1 | Prendre dix vestes de cuir (2 × 3, 2,5 kg) au catalogue, par double-clic. | Elles se rangent seules, cinq par rangée sur deux rangées : grille pleine, « 25,0 / 25,0 kg », barre rouge sang (au-delà de 90 %). |
| 2 | Double-clic sur une onzième veste, puis sur une pile de lavande. | « Pas assez de place. » ; rien ne change. |
| 3 | Ôter une veste (au catalogue, ou jetée au sol). | « 22,5 / 25,0 kg » : la barre reprend sa teinte (90 % tout juste n'est pas « au-delà »). |
| 4 | Double-clic sur la pile pleine de minerai de fer (30 × 0,8 kg = 24,0 kg). | « Trop lourd. » ; rien ne change. |
| 5 | La même pile glissée sur la place libre. | Aperçu refusé (hachures), rien n'est envoyé, aucun message. |

## 4. Empilement et séparation

Besace vide au départ.

| # | Faire | Attendu |
|---|---|---|
| 1 | Prendre une pile de charbon de bois (40). Clic droit → « Diviser… ». | Boîte « Diviser la pile : Charbon de bois », curseur et champ de 1 à 39, 20 proposé ; « Annuler » et « Diviser ». |
| 2 | Saisir 15, `Entrée`. | Pile de 25, et pile de 15 à la première place libre. |
| 3 | Glisser la pile de 15 sur celle de 25. | Aperçu de fusion (cadre laiton appuyé) ; une pile de 40, l'autre disparaît. |
| 4 | Prendre une seconde pile de charbon et la glisser sur la première (40 / 40). | Aperçu refusé, rien ne bouge. |
| 5 | Diviser pour obtenir 30 et 25 ; glisser la pile de 30 sur celle de 25. | Fusion partielle : 40 d'un côté, 15 restent sur la pile d'origine. |
| 6 | `Maj` enfoncée, glisser la pile de 40 vers une case libre. | 20 posées à la case visée, 20 restent en place. |
| 7 | « Diviser… » : saisir 0, puis la quantité entière de la pile. | La boîte se ferme sans rien diviser. |
| 8 | Reposer le charbon au catalogue ; prendre deux épées courtes, glisser l'une sur l'autre ; puis `Maj`-glisser une épée. | Refus : objet non empilable. Avec `Maj`, simple déplacement. |
| 9 | Bûches du catalogue (sans palier) sur des bûches récoltées (avec palier). | Pas de fusion : métadonnées différentes, la case est vue occupée. |

## 5. Ceinture

| # | Faire | Attendu |
|---|---|---|
| 1 | Glisser une pile de carottes sur l'emplacement 1. | L'emplacement montre la carotte et sa quantité ; la pile reste dans la besace. |
| 2 | Glisser la même pile sur l'emplacement 3. | 1 se vide, 3 la montre : une pile n'occupe qu'un raccourci. |
| 3 | Clic droit sur 3 → « Vider le raccourci ». | 3 se vide. |
| 4 | Carotte remise sur 1 ; fermer l'inventaire ; `1` (faim sous 95). | Une carotte mangée (geste) sans ouvrir l'interface ; à la réouverture, une unité de moins. |
| 5 | Inventaire ouvert : `1`, puis clic gauche sur l'emplacement 1. | La touche ne fait rien ; le clic utilise la carotte. |
| 6 | Glisser un objet d'un sac ou du catalogue sur la ceinture. | Rien : seule la besace garnit la ceinture. |
| 7 | Jeter au sol la pile du raccourci 1 ; fermer, `1` ; rouvrir près du sac et la ramasser. | Tant qu'elle est au sol, l'emplacement 1 est vide et `1` ne fait rien ; ramassée, elle y revient : c'est la même pile. |
| 8 | Manger la dernière carotte de la pile. | La pile disparaît, l'emplacement se vide. |

## 6. Utiliser un objet

| # | Faire | Attendu |
|---|---|---|
| 1 | Double-clic sur une carotte (faim sous 95). | Une unité de moins, geste de manger ; faim + 8. |
| 2 | Double-clic à nouveau dans les 3 s. | « Vous n'avez pas encore fini. » ; rien consommé. |
| 3 | Registre → Joueurs → vous → Nourrir ; double-clic sur un ragoût de lièvre. | « Vous n'avez plus faim. » (au-delà de 95) ; rien consommé. |
| 4 | Clic droit sur la pile de ragoûts. | Menu : Utiliser, Diviser…, Jeter. |
| 5 | Registre → vous → Soigner ; double-clic sur une potion de soin. | « Vous n'êtes pas blessé. » ; rien consommé. |
| 6 | Double-clic sur une pierre ; clic droit. | Rien ; menu sans « Utiliser » (Diviser… si la pile en a plus d'une, Jeter). |
| 7 | Double-clic sur une carotte posée dans un sac au sol. | Ramassée, pas mangée : on n'utilise que ce qu'on porte. |

## 7. Fiche d'objet

| # | Faire | Attendu |
|---|---|---|
| 1 | Survoler un quart de seconde une pile pleine de carottes, dans la besace. | Fiche : « Carotte », « Nourriture », « Croquante, encore terreuse. », Poids 2,4 kg (« 0,1 kg l'unité »), Taille 1 × 1, Pile 20 / 20, Faim +8, « Double-clic utiliser ». |
| 2 | Survoler la hache de bûcheron. | « Outil », Poids 2,2 kg, sans « l'unité » ni « Pile » ; « Double-clic tenir en main » (« En main » et « Double-clic reposer » quand elle est tenue). |
| 3 | Survoler une potion de soin. | Aucune ligne d'effet : la fiche ne montre que Faim et Soif. |
| 4 | Survoler un objet du catalogue ou d'un sac. | Même fiche, sans ligne de geste. |
| 5 | Survoler un objet près du bord droit de l'écran. | La fiche passe à gauche de l'objet, jamais hors de l'écran. |
| 6 | Commencer à glisser. | La fiche disparaît. |

## 8. Jeter au sol, sacs, ramasser

| # | Faire | Attendu |
|---|---|---|
| 1 | Glisser une pile de lavande hors de l'inventaire. | Bandeau « Relâcher pour jeter au sol » ; au lâcher, un sac apparaît aux pieds et le panneau « Sac au sol » (6 × 4, « 2,0 / 60,0 kg ») s'ouvre à côté de la besace. On jette toujours la pile entière. |
| 2 | Clic droit sur une autre pile → « Jeter ». | Même sac (moins de 1,5 m). |
| 3 | Clic droit sur une pile du sac ; puis la glisser hors de l'inventaire. | Menu : Ramasser (et Diviser…), pas de Jeter ; hors de l'inventaire, rien. |
| 4 | Double-clic sur une pile du sac. | Elle va à la première place libre de la besace. |
| 5 | Glisser la dernière pile du sac vers une case précise. | Posée là ; le sac vidé disparaît, prop et panneau. |
| 6 | Jeter, fermer, s'écarter de 3 m, `I` ; puis revenir à 2 m, `I`. | À 3 m, la besace seule (2,5 m au plus, vérifiés par le serveur) ; à 2 m, le sac s'ouvre avec elle. |
| 7 | À 2 m de ce sac, jeter. | Un second sac est posé (le premier est à plus de 1,5 m) ; les deux panneaux restent ouverts. |
| 8 | Attendre 10 min après la pose d'un sac (1 min avec le réglage), son panneau ouvert. | Le sac disparaît avec son contenu ; son panneau se ferme. Le délai court depuis la pose, pas depuis le dernier dépôt. Un objet lâché sur le sac à l'instant où il disparaît : « Cet objet n'est plus là. », l'objet reste dans la besace. |
| 9 | Poser des sacs à plus de 1,5 m les uns des autres jusqu'au plafond (10, ou 2 avec le réglage), puis un de plus. | « Trop de sacs au sol. » ; l'objet reste dans la besace. Jeter à moins de 1,5 m d'un sac existant reste possible. |

## 9. Conteneur ancré : le grenier

| # | Faire | Attendu |
|---|---|---|
| 1 | Au grenier commun, `E`. | Notification « Grenier commun ouvert. » ; la besace et le panneau « Grenier commun » (10 × 8, « … / 200,0 kg »). |
| 2 | Déposer une pile, en reprendre une autre. | Comme avec un sac. Double-clic sur un objet du grenier : rien (on glisse). |
| 3 | Clic droit sur une pile du grenier. | Diviser… et Jeter ; Jeter la pose dans un sac au sol, directement depuis le grenier. |
| 4 | `Échap`, puis `I`. | `I` n'ouvre que la besace : le grenier se rouvre par `E`. |

L'éloignement se teste à deux : 11-7.

## 10. Catalogue de développement

Actif sur ce dépôt par choix (`config.catalog.enabled = true`), réservé au droit `staff` du Conseil.

| # | Faire | Attendu |
|---|---|---|
| 1 | `/catalogue`. | À côté de la besace, « Catalogue (développement) » 16 × 10, une pile pleine de chaque objet, par catégorie puis nom, poids sans plafond. Bandeau : onglets « Tout » et une par catégorie avec leur compte, « Rechercher… », « n objets », « ‹ 1 / p › ». Message « Catalogue : n objet(s), page 1/p. », suivi de « Suite : /catalogue 2. » s'il y a plusieurs pages, et de « Catégories : … ». Journal du Registre : « Catalogue de développement ». |
| 2 | Onglet « Outil » ; flèches de page. | Page 1 de la catégorie ; flèches grisées aux bornes. |
| 3 | Rechercher `chene`, puis `zzz`. | « Bûche de chêne » (accents et casse ignorés, nom technique compris) ; puis grille vide, « Aucun objet ne répond à cette recherche. », « 0 objet ». |
| 4 | `Échap` dans le champ, puis `Échap`. | Le premier quitte le champ, le second ferme l'inventaire. |
| 5 | Double-clic (ou clic droit → « Prendre ») sur la lavande. | Une pile pleine (40) dans la besace ; la même revient aussitôt au catalogue. |
| 6 | `Maj`-glisser une pile du catalogue vers la besace. | La moitié dans la besace ; la pile du catalogue est regarnie. |
| 7 | Déposer un objet de la besace au catalogue, puis changer d'onglet. | Il y apparaît, puis disparaît au changement de page. |
| 8 | `/catalogue materiau 9`, puis `/catalogue 9 materiau`, puis `/catalogue inconnue`. | Les deux premiers ouvrent la dernière page des matériaux (page ramenée dans les bornes, arguments dans n'importe quel ordre) ; le troisième : « Aucun objet de catégorie « inconnue ». Catégories : … ». |
| 9 | Fermer, `I`. | La besace revient sans le catalogue ; `/catalogue` le rouvre. |
| 10 | Console du serveur : `catalogue <n° de joueur> outil`, puis `catalogue`. | Le catalogue s'ouvre à l'écran du joueur, la console répond par le même message (rien au journal du Registre) ; sans numéro : `usage : catalogue <joueur> [catégorie] [page]`. |

## 11. À deux

A et B au grenier commun, chacun `E`.

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** A dépose une pile de charbon au grenier. | Elle apparaît aussitôt chez B ; le poids du grenier change chez les deux. |
| 2 | **(2 joueurs)** B reprend cette pile. | Elle disparaît du grenier chez A. |
| 3 | **(2 joueurs)** A et B déplacent chacun un objet différent du grenier au même moment. | Les deux gestes passent. |
| 4 | **(2 joueurs)** Au même signal, A et B lâchent chacun un objet de leur besace sur les mêmes cases libres du grenier. | Un seul passe ; l'autre lit « Pas assez de place. » et son objet revient dans sa besace, tandis que l'objet du gagnant reste affiché chez lui, dans le grenier, sur les cases disputées. |
| 5 | **(2 joueurs)** Au même signal, A et B tirent la même pile du grenier dans leur besace. | Une seule besace la reçoit ; l'autre lit « Cet objet n'est plus là. » (la pile est dans une besace qu'il ne regarde pas, ou fondue dans une pile), son aperçu revient en arrière et la pile ne réapparaît pas dans le grenier chez lui. |
| 6 | **(2 joueurs)** A déplace une pile dans le grenier pendant que B la tire dans sa besace. | Selon l'ordre d'arrivée au serveur : B la reçoit et A la voit partir, ou A lit « Cet objet n'est plus là. » et ne la voit plus dans le grenier. Jamais deux exemplaires. |
| 7 | **(2 joueurs)** B, grenier ouvert. A, à plus de 10 m : Registre → Joueurs → B → Amener. | Chez B, le panneau du grenier se ferme en 2 s au plus (rayon 3,5 m : 2 m d'interaction et 1,5 m de tolérance) ; la besace reste ouverte. Un geste sur le grenier avant la fermeture : « Hors de portée. » ; un objet lâché sur le grenier à l'instant où il se ferme (déjà fermé par le serveur) : « Cet objet n'est plus là. » et l'objet revient dans la besace. Revenu, `E` le rouvre. |
| 8 | **(2 joueurs)** A jette une pile. | B voit le sac au sol ; `I` à moins de 2,5 m : le panneau du sac s'ouvre aussi chez lui. |
| 9 | **(2 joueurs)** Au même signal, A et B double-cliquent la même pile du sac. | Un seul la reçoit ; l'autre lit « Cet objet n'est plus là. » et ne la voit ni dans sa besace ni dans le sac. Si le sac est vidé, il disparaît chez les deux, prop et panneau. |
| 10 | **(2 joueurs)** B, sac ouvert. A : Registre → B → Amener. | Chez B, le panneau du sac reste affiché (un sac ne se ferme pas à distance), mais tout geste sur lui : « Hors de portée. ». |
| 11 | **(2 joueurs)** B, besace ouverte, hache en main. A : Registre → Joueurs → B → Fouiller (fermer le Registre s'il reste devant). | Chez A, un second panneau « Besace », celle de B, quelle que soit la distance. A prend une pile : elle disparaît chez B en direct. A prend la hache : la main de B se vide. |
| 12 | **(2 joueurs)** B : `/catalogue`. | Notification « Le catalogue est réservé au Conseil. » ; le catalogue de A n'apparaît que chez A. |
| 13 | **(2 joueurs)** Après chacun de ces tests, chacun ferme et rouvre. | Même affichage qu'avant la réouverture, chaque objet en un seul exemplaire (et en base, § 16). |

**À regarder dans les tests 4 à 6 et 9** (1.6.3) : quand le serveur refuse un geste, l'interface du perdant ne remet
en arrière que son propre geste ; ce que l'autre vient de prendre ou de poser reste affiché tel que le serveur l'a
envoyé pendant l'attente. Après chaque refus, le perdant ferme et rouvre : l'affichage ne doit pas changer. Un objet
affiché à tort ou manquant jusqu'à la réouverture est un écart : le noter avec le numéro du test.

## 12. Tentatives de triche

| # | Faire | Attendu |
|---|---|---|
| 1 | Ouvrir et fermer la besace le plus vite possible (`I` répété). | Au-delà de 4 ouvertures en rafale, `I` reste sans effet environ une seconde (4, puis 1 par seconde) ; console : `joueur n : limite dépassée sur vava_inventory:open` (à confirmer : il faut aller vite). Pas d'écriture en base à chaque fermeture : une toutes les 3 s au plus. |
| 2 | Dix double-clics de suite sur une carotte (faim sous 95). | Une seule mangée, puis « Vous n'avez pas encore fini. » ; au-delà de 4 demandes en rafale, « Doucement… ». |
| 3 | Même chose avec `1`, carotte en raccourci, inventaire fermé. | Une seule mangée, notifications « Vous n'avez pas encore fini. » ; au-delà de la rafale, plus rien, et `limite dépassée sur vava_inventory:hotbarUse` en console. |
| 4 | Glisser sur Mains une pierre, puis une hache prise dans un sac ou au catalogue. | L'emplacement marque le refus ; rien ne se passe. |
| 5 | Se faire mettre à terre (chute d'un toit, ou coups de B), puis `I`. | La besace s'ouvre ; tout geste (déplacer, diviser, fusionner, jeter, utiliser, prendre en main, prendre au catalogue) : « Vous êtes à terre. ». Registre → vous → Soigner pour se relever. |
| 6 | À terre, inventaire fermé : `1` avec une carotte en raccourci, puis avec la hache (en main, puis reposée avant la chute). | Carotte : notification « Vous êtes à terre. ». Hache : la même notification, qu'il s'agisse de la prendre ou de la reposer ; la main ne change pas. |
| 7 | Ouvrir la besace à 3 m d'un sac, puis prendre dans un sac après en avoir été éloigné (11-10). | Le sac ne s'ouvre pas ; « Hors de portée. ». |

## 13. Déconnexion

| # | Faire | Attendu |
|---|---|---|
| 1 | Glisser une pile sans la lâcher, fermer le jeu (Alt+F4) bouton enfoncé ; revenir. | La pile est à son ancienne place, aucun sac au sol : rien ne part avant le lâcher. |
| 2 | Déplacer une pile, en diviser une autre, puis aussitôt, inventaire ouvert : `F8` → `quit` ; revenir. | Les deux changements sont là : le départ du personnage écrit tout aussitôt. |
| 3 | **(2 joueurs)** A jette une pile, se déconnecte ; B prend dans le sac ; A revient avant 10 min. | B a pu prendre ; A retrouve le sac et ce qu'il y reste. Le sac compte dans les sacs de A jusqu'à sa disparition. |
| 4 | Ceinture garnie, hache en main ; changer de personnage puis revenir, ou se reconnecter. | Ceinture identique ; la hache toujours en main, accessoire visible. |
| 5 | **(2 joueurs)** A fouille B (11-11) ; B se déconnecte. | Le panneau de B se ferme chez A ; sa propre besace reste. |
| 6 | **(2 joueurs)** A et B au grenier ; A se déconnecte grenier ouvert. | Rien ne change chez B ; aucune erreur en console. |

## 14. Redémarrage du module

| # | Faire | Attendu |
|---|---|---|
| 1 | Besace ouverte, hache en main, carotte sur la ceinture, un sac posé à côté, catalogue ouvert ; B au grenier. Console : `restart vava_inventory`. | Les interfaces d'inventaire disparaissent chez A et B, la main est rendue au jeu (à confirmer) ; l'accessoire en main disparaît ; le sac disparaît avec son contenu (voulu : les sacs ne sont pas conservés). Console : `registre 'vava_inventory:items' supprimé avec son propriétaire 'vava_inventory' : n entrée(s) d'autres modules perdue(s)`, `module 'vava_inventory' arrêté : vava_crafting, vava_farming, vava_gathering, vava_skills en dépend(ent)…`, puis `module 'vava_inventory' v1.6.4 prêt` et l'avertissement du catalogue. `vava_skills`, `vava_gathering`, `vava_crafting`, `vava_farming` tournent toujours (à confirmer : FXServer peut arrêter ce qui déclare `dependency 'vava_inventory'` ; sinon `ensure`). `n objet(s) d'inventaire non écrits à l'arrêt` signale une écriture perdue : à noter. |
| 2 | `I`. | La besace avec tout son contenu, chaque pile à sa place d'avant le redémarrage, la ceinture garnie ; la hache toujours en main (emplacement Mains), son accessoire de nouveau visible chez A et chez B. Console : pendant le démarrage, `conteneur #n : objet #m (…) sans place ou sans définition, conservé à part` pour chaque pile d'un objet des métiers ou de la magie (leurs besaces sont rechargées avant que ces modules redéclarent leurs objets), puis, dès leur redéclaration, `conteneur #n : k pile(s) de '…' replacée(s)` pour chaque objet. Une ligne `… toujours sans place` ou une pile manquante est un écart à noter. |
| 3 | Fermer, attendre 3 s ; en base, `SELECT id, item, x, y, rotated, quantity FROM vava_inventory_items WHERE container_id = <n° de la besace>` (relevé aussi avant le 1). Puis se reconnecter. | Mêmes lignes qu'avant le redémarrage (une pile replacée ailleurs que sa place d'origine a ses nouvelles `x`, `y`) ; l'écran correspond. Après reconnexion, tout est au même endroit, hache en main. |
| 4 | `/catalogue` ; B : `E` au grenier. | Le catalogue fonctionne ; le grenier se rouvre avec son contenu, relu en base. |
| 5 | `restart vava_inventory` avec tous les joueurs à la sélection de personnage, puis choisir son personnage. | Besace complète : elle se charge à la sélection, quand les objets sont déjà déclarés. |
| 6 | **(2 joueurs)** A et B en jeu, chacun avec des objets des métiers (bûches à palier, charbon, hache en main pour A, pioche sur la ceinture de B) ; relever leurs besaces en base (3). Console : `restart vava_inventory` ; dès `module 'vava_inventory' v1.6.4 prêt`, A et B ouvrent leur besace (`I`). | Chez chacun, tout revient sans reconnexion, en un seul exemplaire ; aucun objet perdu ni recouvert (deux piles jamais sur les mêmes cases) ; la hache en main de A, la pioche sur la ceinture de B. En base : mêmes piles qu'avant, aux mêmes quantités. |
| 7 | Une miche et une bande de lin (`vava_example_items`) dans la besace ; `restart vava_inventory` ; `I`. | Elles sont à leur place sans reconnexion : le module d'exemple redéclare ses objets dès que l'inventaire est prêt (1.1.1), comme les modules du royaume ; console : `conteneur #n : k pile(s) de 'pain' replacée(s)`. |

## 15. Resmon

Ressource `vava_inventory`, console du client (`resmon 1`).

| Situation | Attendu |
|---|---|
| Au repos, rien d'ouvert, personne autour. | 0,00 ms : aucune boucle. |
| Besace ouverte, gestes, glisser. | 0,01 ms au plus : l'interface travaille hors du Lua (à confirmer). |
| Près d'un sac au sol. | 0,00 ms : aucune boucle de proximité. |
| Un joueur proche tient un objet en main. | 0,01 ms au plus : une boucle d'une seconde, active seulement tant que quelqu'un tient quelque chose. |

Cibles : 0,02 ms au repos, 0,15 ms en action. Côté serveur, aucune boucle permanente : l'écriture groupée passe
toutes les 3 s, le contrôle d'éloignement des conteneurs ancrés toutes les 2 s, seulement tant qu'un est ouvert.

## 16. Ce qu'il faut regarder dans la base

- `vava_inventory_containers` : une ligne par besace (`kind = 'character'`, `owner_type = 'character'`, `owner_id` =
  n° du personnage, `width` 10, `height` 6, `max_weight` 25000, `label` « Besace »), créée avec le personnage (ou à
  son premier chargement s'il est plus ancien que le module) ; une pour le grenier (`kind = 'granary'`,
  `owner_type = 'parcel'`, `owner_id = 'champ_communal'`). Aucune pour les sacs ni le catalogue.
- `vava_inventory_items` : une ligne par pile (`id`, `container_id`, `item`, `x`, `y` comptés depuis 0 en haut à
  gauche, `rotated` 0 ou 1, `quantity`, `metadata` à `{}` sans métadonnées).
- Quand : une transaction toutes les 3 s (`flushIntervalMs`) ; aussitôt au départ d'un personnage (déconnexion,
  changement de personnage) ; à la fermeture d'un inventaire, une fois toutes les 3 s au plus par joueur ; à l'arrêt
  du module, une dernière écriture lancée sans attendre. Un arrêt brutal du serveur perd au plus les 3 dernières
  secondes. Attendre 3 s avant de lire.
- Lignes créées et effacées : pile jetée dans un sac → effacée ; ramassée → réécrite (même `id` pour la pile entière,
  nouvel `id` pour une part) ; déposée au catalogue → effacée ; prise au catalogue → nouvelle ligne ; fusion → la pile
  absorbée effacée ; division → nouvelle ligne ; dernière unité mangée → effacée. Les changements de page du
  catalogue n'écrivent rien.
- `vava_characters.data` (JSON) : `vava_inventory:hotbar` (cinq `id` de piles, 0 pour vide) et `vava_inventory:hands`
  (pile en main), écrits par le core au départ du personnage et toutes les 5 min.
- `vava_farming_granary_log` : dépôts et retraits du grenier, regroupés par minute, écrits toutes les 10 s par
  `vava_farming`.
- `vava_admin_logs` : `action = 'Catalogue de développement'`, détails joueur, catégorie, page, à chaque `/catalogue`
  tapé en jeu (ni la console ni les clics du bandeau).
- Contrôle après chaque section : `SELECT item, quantity, x, y, rotated FROM vava_inventory_items WHERE container_id =
  <n° de la besace>` correspond à l'écran.

## 17. Ce que je ne peux pas avoir vérifié hors jeu

- Le rendu dans CEF : polices `nui://`, images des objets (`nui://<module>/web/items/*.svg`), hachures et teintes.
  Hors jeu : `modules/vava_inventory/web/index.html` (`?drop=1` ajoute un sac, `?catalog=1` le catalogue).
- Que l'inventaire ouvert empêche de marcher, et que le curseur est rendu quand le module redémarre interface ouverte.
- La hauteur du sac sur une pente ou un escalier (`drop.groundOffset = 0.98` sous le centre du ped) : il peut flotter
  ou s'enfoncer.
- La réception de l'identifiant d'un sac (state bag de l'entité) par un joueur qui arrive après la pose ou revient de
  loin : il doit pouvoir l'ouvrir avec `I`.
- Ce que fait FXServer des ressources qui déclarent `dependency 'vava_inventory'` quand on le redémarre (14-1).
- Le Registre et l'inventaire ouverts ensemble à la fouille (11-11) : lequel garde le clavier.
- Les limites de débit atteintes à la main (12-1 à 12-3).
- Le nom que le jeu donne à une touche choisie par le joueur (1-6) : le texte des touches ordinaires (« I », « K »)
  est sûr, les codes d'icône de `Tab`, `Entrée`, `Espace` et des touches `F1` à `F12` (`client/main.lua`, `ICON_KEYS`)
  sont à confirmer.
- Le retour des piles après `restart vava_inventory` est vérifié hors jeu sur un faux core (harnais) : l'ordre réel des
  redéclarations (récolte, artisanat, agriculture, magie) et l'accessoire revenu en main restent à voir (14-2, 14-6).
- Un client modifié qui vise le conteneur d'un autre (déplacer ou diviser vers un numéro de besace, de coffre ou de sac
  qu'il n'a pas ouvert) reçoit « Cet objet n'est plus là. », que ce conteneur existe ou non (vérifié hors jeu) ;
  « Hors de portée. » ne répond qu'à un conteneur ouvert dont on s'est éloigné.
