# Combat — procédure de test en jeu

Procédure pour vérifier en jeu le combat de la phase 4 (`docs/plan/COMBAT_V1.md`). Section 1 : la **chaîne de dégâts
commune** de `vava_health` 1.3.0 (T-110), éprouvée avec la ressource d'essai `vava_example_combat` 1.0.0 et
`vava_needs` 1.2.1. Les sections suivantes viendront avec les armes, les techniques et la défense (T-111 à T-116).
Comptez 1 h, presque tout à deux ; les tests à deux joueurs sont marqués **(2 joueurs)**. Un test se cite
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
| 16 | **(2 joueurs)** A `/arme pistolet`, tire sur B ; puis `/arme couteau`, frappe B ; `/arme non`. | Aucune perte chez B, jamais à terre. A peut voir du sang ou un tressaillement chez lui seul (prédiction de son client) : à noter, sans conséquence. |
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

## 2. Ce que je ne peux pas avoir vérifié hors jeu

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
