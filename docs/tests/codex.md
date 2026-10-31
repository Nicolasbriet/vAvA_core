# Le Codex — procédure de test en jeu

Procédure pour vérifier en jeu `vava_codex` 1.5.0 : toutes les commandes et toutes les touches du serveur dans un
livre (`F1` ou `/codex`), la recherche, les formulaires selon le type de chaque argument, « Lancer », ce que chacun
voit selon ses droits, les signets, les dernières pages, la greffe du chat et le contenu gardé par la page entre deux
ouvertures (§ 12, 1.2.0), les pages de lecture et l'onglet Lecture (§ 16, 1.5.0). Elle reprend les douze tests de la section « Tests en jeu » du README (repérés
« README n ») et les complète d'après le code. Comptez trois quarts d'heure ; les
tests à deux joueurs sont marqués **(2 joueurs)**. Un test se cite « codex 3-4 ». Préparation commune, mesure du
resmon et remontée des écarts : [LISEZMOI.md](LISEZMOI.md).

## 0. Préparation

1. **Deux joueurs** : **A** (vous, Souverain par la préparation commune) et **B** (second client, hors du Conseil),
   chacun avec un personnage. `<B>` est le numéro de compte de B, `<idA>` le numéro de session de A (Registre →
   Joueurs, « n° » en tête de ligne).
2. **Modules dont les formulaires servent d'exemple** : `vava_gathering` (liste des zones), `vava_skills` (registre des
   compétences), `vava_magic` (choix fixe), `vava_chat` (greffe des dernières pages), `vava_admin` (droits), `vava_hud`
   (notifications). Le Codex démarre après eux et avant `vava_chancellerie`.
3. **Réglages pour aller vite** (facultatif, `modules/vava_codex/config.lua` puis `restart vava_codex`, à remettre
   après) : `favorites.max = 2` (défaut `24`) pour atteindre la limite des signets (un personnage qui en a déjà plus
   voit ses signets ramenés aux deux premiers : test 5-7) ; `recent.max = 3` (défaut `12`) pour voir les dernières
   pages se tasser. Le Codex n'a aucun délai à raccourcir.
4. **Nombres** : un champ numérique n'a aucune valeur d'office (1.1.2). Obligatoire, il manque tant qu'il n'est pas
   choisi (curseur déplacé ou valeur tapée) : `/recolte vitalite <zone>` ou `/metiers niveau` ne partent jamais avec un
   0 que personne n'a choisi.
5. **Ce qui part à chaque ouverture** (§ 12) : dans `config/server.lua` du core, `log.level = 'debug'` le temps du
   § 12 (redémarrage du serveur), à remettre à `'info'` après. La console écrit alors à chaque ouverture
   `[vava_codex] ouverture (joueur N, X entrées visibles) : contenu envoyé | gardé par la page, préférences
   envoyées | gardées`.

## 1. Ouvrir et fermer (README 1)

| # | Faire | Attendu |
|---|---|---|
| 1 | `F1`. | Le livre « Codex » s'ouvre sur l'onglet Commandes : onglets Lecture, Commandes et Touches (1.5.0) ; curseur dans la recherche (« Rechercher une commande… ») ; « N entrées » ; l'index à gauche ; à droite « Choisissez une commande à gauche, ou tapez pour chercher. » ; sur la tranche « Tout » puis un onglet par chapitre ; en bas « Rester ouvert après « Lancer » », coché (`keepOpenDefault = true`) ; légende sous le livre : `↑ ↓` parcourir, `Entrée` choisir, lancer, `Tab` champ suivant, `Échap` retour, fermer. |
| 2 | `Échap`. | Le livre se ferme ; souris et clavier reviennent au jeu. |
| 3 | `/codex` dans le chat. | Le livre s'ouvre. |
| 4 | Livre ouvert : `F1`. | Rien : le livre a le clavier ; on le ferme par `Échap` (à confirmer). |
| 5 | Menu pause ouvert, ou pendant la sélection de personnage : `F1`. | Rien ne s'ouvre. |
| 6 | Paramètres › Raccourcis › FiveM → « Ouvrir le Codex (commandes et touches) » → `J`. Puis `J`, `F1`, onglet Touches. | `J` ouvre le Codex, `F1` non ; dans Touches, « Ouvrir le Codex » porte `J`, son détail dit « Par défaut : F1 ». Prendre une lettre : pour une touche spéciale, le Codex peut montrer le défaut (à confirmer). Remettre `F1`. |

## 2. Recherche et index (README 4)

| # | Faire | Attendu |
|---|---|---|
| 1 | Sans recherche, chapitre « Tout ». | Sections « Signets » et « Dernières pages » (si elles ont des lignes), puis un chapitre par module (« Agriculture », « Chat », « Conseil »…). Chaque ligne : la syntaxe (`/recolte vitalite <zone> <vitalité>`), les sceaux (« Conseil », « Console », cabochon de la touche liée, « interface »), le libellé (« Zones et nœuds de récolte › Fixer la vitalité d'une zone »). |
| 2 | Taper `recolte`, puis `RÉCOLTE`. | Mêmes résultats sous « Résultats » (accents et casse ignorés), filtrés à chaque lettre sans attente ; la première ligne est choisie d'office et son détail s'affiche. |
| 3 | Taper `vital`. | Deux résultats : « … › État des zones » (sa description parle de vitalité) puis « … › Fixer la vitalité d'une zone » ; la première est choisie d'office, `↓` choisit la seconde (comme le dit le README, test 4). Taper `vitalité d'une` ne garde que la seconde. |
| 4 | `Échap` dans la recherche remplie, puis `Échap`. | Le premier vide la recherche ; le second ferme le livre. |
| 5 | Cliquer « Récolte » sur la tranche, puis « Tout ». | Seules les lignes de la récolte, sans Signets ni Dernières pages ; « Tout » rend l'index complet. |
| 6 | `↑` `↓` dans l'index ; puis taper une lettre alors que le curseur est ailleurs. | La sélection suit l'ordre affiché ; la lettre ramène dans la recherche. |

## 3. Formulaires, ligne composée, « Lancer » (README 4, 5)

| # | Faire | Attendu |
|---|---|---|
| 1 | A : choisir `/recolte vitalite`, `Entrée`. | Détail : « Récolte », titre, « 0 marque une cicatrice, 100 remet la zone à neuf. », « Syntaxe », le formulaire, « Ligne lancée », « Mettre en signet », « Lancer ». Le curseur passe dans « zone » ; la liste des zones arrive du serveur : vrais noms (« Forêt de Brume ») avec l'identifiant en petit (`foret_brume`) ; taper filtre la liste. |
| 2 | `↓` puis `Entrée` dans la liste, puis `Tab`. | La zone est choisie ; champ « vitalité » « de 0 à 100 » : nombre vide (« — »), curseur pâle à gauche, rien choisi ; la ligne s'écrit en direct : `/recolte vitalite foret_brume` ; « Il manque « vitalité ». » et « Lancer » grisé ; `Entrée` ne lance rien. |
| 3 | Régler la vitalité à 100, `Entrée`. | Le curseur reprend sa couleur ; chat : « Forêt de Brume : vitalité 100 %. » ; mot « Lancé : /recolte vitalite foret_brume 100 » ; la ligne monte en tête des Dernières pages ; Registre → Journal : « Vitalité fixée ». |
| 4 | Taper `150` dans le nombre ; puis `Tab` ; puis taper `42,7` ; puis vider le nombre. | `150` : la ligne porte déjà 100 et le curseur se cale à 100 ; en quittant le champ, il affiche 100. `42,7` : la ligne porte 43 (entier arrondi). Vidé : « Il manque « vitalité ». » de nouveau, « Lancer » grisé. Une valeur choisie au curseur, 0 compris, part telle quelle. |
| 5 | Vider le champ « zone ». | « Il manque « zone ». » sous la ligne ; « Lancer » grisé ; `Entrée` ne lance rien. |
| 6 | `/metiers niveau` (README 5). | « joueur » : tous les joueurs en jeu, « Prénom Nom (n° X) », triés par nom ; « compétence » : les compétences du registre par leur nom ; « niveau » « de 0 à 100 » (`levels.max`), vide d'office ; ligne `/metiers niveau <n°> <compétence>` en direct, « Il manque « niveau ». » et « Lancer » grisé tant que le niveau n'est pas choisi. Pour ne rien changer, lancer plutôt `/metiers voir`, qui écrit la fiche dans le chat. |
| 6b | `/catalogue` (A), sans toucher à « page » (facultatif) ; puis taper `0` dans « page ». | Sans valeur : ligne `/catalogue`, « Lancer » actif (un facultatif vide est omis). `0` : la ligne porte `/catalogue 1` (borne `min`). |
| 7 | Choix fixe : `/magie donner`. | « joueur » marqué « facultatif », aide « sinon vous-même » ; « objet » en pastilles « grimoire » et « registre » ; avant le choix : « Il manque « objet ». ». Pastille « grimoire », joueur vide : ligne `/magie donner grimoire` ; « Lancer » met un grimoire dans votre besace. |
| 8 | Choix avec libellés : `vava_conseil` (commande de console). | « compte » en texte libre ; « rang » en pastilles Gardien, Sénéchal, Souverain, Révoquer ; « Lancer » grisé et « Cette commande ne se lance que depuis la console du serveur ; elle est montrée pour mémoire. ». |
| 9 | Texte : `/me`, écrire « tire son épée ». | Aide « ex. : tire son épée » ; ligne `/me tire son épée` ; « Lancer » : l'action paraît dans le chat. |
| 10 | Commande qui ouvre une interface (sceau « interface ») : `/conseil`. | Le Codex se ferme d'abord, puis le Registre du Conseil s'ouvre. |
| 11 | Double-clic sur une ligne sans argument : `/sigils`. | Lancée aussitôt ; réponse de la magie dans le chat. |

## 4. Ce que chacun voit (2 joueurs, README 2, 3, 5)

Le serveur décide de ce que chacun voit, à chaque ouverture ; et il revérifie le droit au moment de « Lancer ».

| # | Faire | Attendu |
|---|---|---|
| 1 | B (hors du Conseil) : `F1`. | Commandes publiques (Chat, Magie, Chancellerie, `/codex`, et `/signaler` seul sous « Conseil ») et touches. Aucun sceau « Conseil » ni « Console », pas de « Non décrites », ni chapitre « Caméras » ni « Core ». Touches : ni `F10` ni `F2`. |
| 2 | A (Souverain) : `F1`. | En plus, sous le sceau « Conseil » : `/conseil` (cabochon `F10`, « interface »), `/staff`, `/cameras`, `/recolte`, `/metiers`, `/artisanat`, `/agriculture`, `/magie`, `/zonesvoix`, `/catalogue`. Sous le sceau « Console », non lançables : `vava_conseil`, `vava_ban`, `vava_unban`, `vava_kick` (Conseil), `vava_fondateur` (Compétences), `vava_saveall` (Core). Touches : en plus `F10` et `F2` « Vol libre (Conseil) ». |
| 3 | Console : `vava_conseil <B> gardien` ; B rouvre le Codex. | B voit `/conseil`, `/staff`, `/cameras` et les commandes de console ; ni `/recolte`, `/metiers`, `/artisanat`, `/agriculture` (droit `metiers`), ni `/magie`, `/zonesvoix`, `F2` (droit `tools`), ni `/catalogue` (droit `staff`). |
| 4 | `vava_conseil <B> senechal` ; B rouvre. | En plus les commandes `metiers` et `tools`, et `F2` dans Touches ; toujours pas `/catalogue`. |
| 5 | B (Sénéchal) lance `/recolte zones` depuis le Codex. | Les zones s'écrivent dans son chat ; la ligne entre dans ses Dernières pages. |
| 6 | **Refus du serveur** : B rouvre le Codex, choisit `/recolte zones` et laisse le livre ouvert. Console : `vava_conseil <B> aucun`. B : « Lancer ». | Mot « Cette commande ne vous est pas ouverte. » ; rien dans le chat : la ligne n'est pas lancée. |
| 7 | `vava_conseil <B> senechal`, B rouvre et choisit `/recolte vitalite` sans entrer dans « zone ». Console : `vava_conseil <B> aucun`. B entre dans « zone ». | Aucune liste : le serveur refuse les valeurs. Une zone tapée à la main reste possible, mais « Lancer » est refusé comme en 6. |
| 8 | B (hors du Conseil) rouvre le Codex. Puis `vava_conseil <B> senechal` et B rouvre encore. | D'abord plus rien du Conseil, et `/recolte` absent des Dernières pages ; ensuite `/recolte zones` y revient : la ligne était gardée, seul l'affichage est filtré. `vava_conseil <B> aucun` ensuite. |
| 9 | `/mp` chez B, champ « joueur », A à 10 m (README 5). | La liste ne propose que B lui-même (et les joueurs à 5 m au plus, `players.nearbyRadius`, même instance) ; A n'y est pas. Taper `<idA>` à la main, un message, « Lancer » : le message part. |
| 10 | A s'approche à 3 m de B ; B ferme et rouvre le Codex, `/mp`. | A est proposé (valeurs relues à chaque ouverture). Chez A (Conseil) : tous les joueurs en jeu, à toute distance. |
| 11 | « Non décrites » (README 3) : A, chapitre « Tout », sans recherche. | En bas de l'index, section « Non décrites » (au survol : « Enregistrées auprès du jeu, pas encore décrites au registre : lançables en texte libre. ») pour chaque commande serveur d'une ressource `vava…` ou `vAvA…` absente du registre, avec un seul champ « arguments » facultatif. Aujourd'hui tous les modules déclarent leurs commandes serveur : la section est absente, c'est attendu. Pour la voir : démarrer la ressource d'exemple `vava_example` si elle est installée (commande `example_ping`) (à confirmer). Chez B : jamais. |

## 5. Signets (README 6)

| # | Faire | Attendu |
|---|---|---|
| 1 | Détail de `/recolte zones` → « Mettre en signet ». | Un ruban « /recolte » apparaît en haut du livre ; le bouton devient « Retirer le signet » ; la section « Signets » apparaît en tête et liste toutes les sous-commandes de `/recolte` (le signet vaut pour la commande), chacune marquée ❧. |
| 2 | Cliquer le ruban depuis un autre chapitre, avec une recherche en cours. | Onglet Commandes, recherche et chapitre remis à zéro, première sous-commande de `/recolte` choisie. |
| 3 | Onglet Touches → « Chat : écrire » → « Mettre en signet ». Revenir à Commandes, cliquer le ruban. | Le ruban porte « Chat : écrire » ; le clic rouvre l'onglet Touches sur cette touche. |
| 4 | Signet sur une commande de console (`vava_saveall`). | Accepté : elle est montrée pour mémoire. |
| 5 | Poser des signets jusqu'à `favorites.max` (24, ou 2 avec le réglage du § 0), puis un de plus. | Mot « Vous avez atteint le nombre de signets permis : retirez-en un. » ; aucun ruban de plus. |
| 6 | « Retirer le signet ». | Le ruban disparaît, la section « Signets » aussi s'il n'en reste aucun. |
| 7 | Personnage avec quatre signets et cinq dernières pages ; `favorites.max = 2`, `recent.max = 3`, `restart vava_codex` ; `F1`, puis lancer `/sigils`, poser et retirer un signet. | Deux rubans (les deux premiers posés), trois Dernières pages (les plus récentes) ; « Lancer », signet et réglage fonctionnent, aucun « Action impossible. ». En base, après la sauvegarde du personnage : deux signets et trois dernières pages. Remettre les valeurs par défaut. |

## 6. Dernières pages et greffe du chat (README 9)

| # | Faire | Attendu |
|---|---|---|
| 1 | Lancer `/sigils` puis `/me salue` depuis le Codex. | Aussitôt en tête des Dernières pages, la plus récente d'abord. |
| 2 | Fermer ; taper `/me lève son verre` dans le chat ; rouvrir. | `/me <action>` en tête des Dernières pages. |
| 3 | Taper deux fois `/mp <idA> bonjour` dans le chat ; rouvrir. | Une seule ligne « Message privé » ; rien du message n'est gardé. |
| 4 | A : `/metiers voir <idA>` puis `/chat reinit` dans le chat ; rouvrir. | Deux lignes distinctes : « Compétences d'un joueur › Lire la fiche » et « Réglages du chat › Remettre le chat à sa place » (sous-commandes déclarées). |
| 5 | Dans `F8` : `me test` ; rouvrir. | N'entre pas aux Dernières pages : seul le chat les signale. |
| 6 | **(2 joueurs)** B hors du Conseil : `/recolte zones` dans le chat ; rouvrir. | Rien dans le chat (la commande se tait devant qui n'a pas le droit) ; rien aux Dernières pages (le serveur ignore ce que B ne peut pas lancer). |
| 7 | Lancer treize commandes différentes (quatre avec `recent.max = 3`) ; rouvrir. | Douze lignes (trois) au plus, sans doublon ; la plus ancienne est sortie. Pendant la même ouverture aussi, jamais plus que `recent.max` : la page suit la config. |

## 7. « Rester ouvert après Lancer » (README 7)

| # | Faire | Attendu |
|---|---|---|
| 1 | Décocher ; lancer `/sigils`. | Le livre se ferme et la commande part. Rouvrir : la case est décochée. |
| 2 | Cocher ; lancer `/sigils`. | Le livre reste ouvert, mot « Lancé : /sigils », et garde le clavier. |
| 3 | Case cochée ; lancer `/conseil` (A). | Le livre se ferme d'abord, le Registre s'ouvre : une commande « interface » ferme toujours le Codex. |

## 8. Onglet Touches (README 8)

| # | Faire | Attendu |
|---|---|---|
| 1 | Onglet Touches. | Recherche « Rechercher une touche… » ; une ligne par touche (cabochon et libellé) chapitre par chapitre, y compris les commandes liées à une touche (`/codex` `F1`, `/conseil` `F10` pour A) ; sceau « maintenir » sur les touches à maintenir (« Chat : écrire » `T`, « Récolter (nœud proche) » `E`, roue des sorts `Tab`). |
| 2 | Cliquer « Chat : écrire ». | Cabochon en grand, « Par défaut : T », « À maintenir : agit à l'appui et au relâchement. », « Chaque touche se change dans Paramètres › Raccourcis › FiveM. Le Codex montre la vôtre. », bouton de signet ; pas de « Lancer », `Entrée` ne fait rien. |
| 3 | Chercher `tab`, puis `F10`. | La recherche porte aussi sur la touche affichée. |

## 9. Par personnage, déconnexion (README 10)

| # | Faire | Attendu |
|---|---|---|
| 1 | Poser deux signets, lancer deux commandes, décocher « Rester ouvert » ; se déconnecter et revenir sur le même personnage. | Signets, Dernières pages et réglage retrouvés. |
| 2 | Poser un signet et quitter dans les deux secondes ; revenir. | Le signet est là (le personnage est écrit au départ). |
| 3 | Revenir sur un autre personnage du même compte. | Ses propres préférences : aucun signet, aucune dernière page, case cochée. |

## 10. Redémarrages

| # | Faire | Attendu |
|---|---|---|
| 1 | Livre ouvert : `restart vava_codex` (README 11). | Le livre disparaît ; console `module 'vava_codex' v1.2.0 prêt` ; souris et clavier reviennent au jeu aussitôt (le module rend la main à l'arrêt). `F1` rouvre ; signets, Dernières pages et réglage intacts. |
| 2 | `stop vava_codex` ; `F1` ; `/me essai` dans le chat ; `start vava_codex` ; `F1`. | `F1` sans effet pendant l'arrêt ; `/me` ne figure pas aux Dernières pages. |
| 3 | `stop vava_admin` ; A : `F1`. | Plus de chapitre « Conseil » (ses entrées partent avec le module, `/signaler` compris), plus aucune commande du Conseil ni de la console, sauf si A a l'ACE `vava_codex.staff` ou l'ACE propre à la commande (`metiers.admin`…). |
| 4 | `start vava_admin` ; A : `F1`. | Tout revient sans redémarrer le Codex. |

## 11. Tentatives de triche simples

| # | Faire | Attendu |
|---|---|---|
| 1 | `F1` puis `Échap`, six fois très vite. | Vers la quatrième ouverture : notification « Le Codex est indisponible pour le moment. » (trois ouvertures d'affilée, puis une toutes les deux secondes : `rateLimits.open`) ; un instant après, `F1` rouvre. |
| 2 | Case cochée, `/sigils` choisi : garder `Entrée` enfoncée. | La commande part à chaque répétition puis « Doucement… » et elle ne part plus (dix d'affilée, puis deux par seconde : `rateLimits.prefs`). |
| 3 | « Mettre en signet » / « Retirer le signet » quinze fois très vite. | « Doucement… » au-delà d'une dizaine. |
| 4 | **(2 joueurs)** B hors du Conseil tape `/vava_kick <idA> essai` dans le chat. | Rien : la commande ne vaut qu'en console ; elle n'entre pas aux Dernières pages. |
| 5 | Valeur hors bornes dans un formulaire | Voir 3-4 : la valeur part ramenée dans les bornes de l'argument ; tapée à la main dans le chat, la commande garde ses propres contrôles. |
| 6 | À terre (`vava_health`) : `F1`. | Le Codex s'ouvre (à confirmer) ; chaque commande lancée garde ses propres refus. |

## 12. Contenu gardé par la page (1.2.0, README 12)

La page garde le contenu et les préférences ; à chaque ouverture, le serveur ne renvoie que ce qui a changé. Console
au niveau `debug` (§ 0.5). Mesuré hors jeu avec les déclarations du dépôt : contenu complet 7,5 Ko (joueur) à 17 Ko
(Souverain), ouverture sans changement 56 octets.

| # | Faire | Attendu |
|---|---|---|
| 1 | A, juste après l'arrivée en jeu : `F1`. | Console : `contenu envoyé, préférences envoyées` (première ouverture). Le livre est complet. |
| 2 | `Échap`, `F1`, `Échap`, `F1` (en laissant deux secondes entre deux ouvertures : `rateLimits.open`). | Console, à chaque fois : `contenu gardé par la page, préférences gardées`. Le livre est identique : mêmes chapitres, signets, Dernières pages, réglage, touches. |
| 3 | Poser un signet, fermer, rouvrir. | `contenu gardé par la page, préférences envoyées` ; le ruban est là. Rouvrir encore : `préférences gardées`. |
| 4 | Lancer `/sigils` depuis le Codex, fermer, rouvrir ; puis taper `/me essai` dans le chat, rouvrir. | Les deux fois : `contenu gardé par la page, préférences envoyées` ; la ligne est en tête des Dernières pages. |
| 5 | Paramètres › Raccourcis › FiveM : « Ouvrir le Codex » sur `J` ; rouvrir par `J`, onglet Touches. | `contenu gardé par la page` ; « Ouvrir le Codex » porte `J` (les touches sont relues par le client à chaque ouverture). Remettre `F1`. |
| 6 | **(2 joueurs)** B ouvre, ferme. Console : `vava_conseil <B> senechal`. B rouvre. | Chez B : `contenu envoyé` ; les commandes du Conseil et du droit `metiers` apparaissent aussitôt, sans reconnexion. Rouvrir : `contenu gardé par la page`. |
| 7 | Console : `vava_conseil <B> aucun`. B rouvre. | `contenu envoyé` ; plus rien du Conseil (comme 4-8). |
| 8 | A ouvre, ferme. `restart vava_gathering`. A rouvre. | `contenu envoyé` ; `/recolte` est là (le module l'a redéclaré). `stop vava_gathering`, A rouvre : `contenu envoyé`, plus de chapitre « Récolte » ; `start vava_gathering` : il revient. |
| 9 | A ouvre, ferme ; B ouvre, ferme ; rien ne change ; chacun rouvre. | `gardé` pour l'un comme pour l'autre : chacun a sa propre version, calculée avec ses droits. |
| 10 | Revenir à la sélection de personnage, prendre un autre personnage du même compte, `F1`. | `contenu gardé par la page, préférences envoyées` : les signets et Dernières pages sont ceux du nouveau personnage (9-3). |
| 11 | Livre ouvert, `restart vava_codex`, puis `F1`. | `contenu envoyé, préférences envoyées` : la page repart de rien. |

Secours (jamais attendu, non provoquable en jeu) : si la page n'a pas la version que le client annonce, elle garde son
contenu et fait oublier les versions au client, sans appel au serveur (la prochaine ouverture renvoie tout) ; si elle
n'a encore aucun contenu, elle le redemande aussitôt, et cette ouverture compte alors pour deux dans
`rateLimits.open`. Vérifié hors jeu sous jsdom.

## 13. Resmon

| Situation | Attendu (`resmon 1`, ligne `vava_codex`) |
|---|---|
| Au repos, livre fermé | 0,02 ms au plus (aucune boucle : 0,00 attendu). |
| Livre ouvert, recherche, formulaires | 0,02 ms au plus côté Lua : tout se fait dans la page ; 0,15 ms au plus au moment de « Lancer ». |
| Serveur, à chaque ouverture (`resmon` côté serveur ou profiler) | Pointe brève : environ 1 ms pour un joueur, 2 ms pour un Souverain (contenu recalculé et son empreinte, mesurés hors jeu) ; rien entre deux ouvertures. **Plus de 3 ms chez un Souverain** : à noter dans la remontée (suite prévue, voir le rapport T-046). |

## 14. Ce qu'il faut regarder dans la base

- Les préférences vivent dans le personnage : `vava_characters.data`, clé `vava_codex:prefs` (`favorites`, `recent`
  avec `name`, `action`, `at`, et `keepOpen`). Exemple : `SELECT id, JSON_EXTRACT(data, '$."vava_codex:prefs"') FROM
  vava_characters WHERE id = <n>;`
- Écrites avec le personnage : sauvegarde groupée toutes les 5 min (`saveIntervalMs` du core), au départ du joueur, ou
  `vava_saveall` en console. Depuis 1.2.0, le champ est lu du seul serveur : il ne part plus vers le client à chaque
  écriture (le client les reçoit à l'ouverture du Codex).
- `vava_admin_logs` : les commandes lancées depuis le Codex y laissent la trace que laisse leur module (« Vitalité
  fixée »…) ; le Codex lui-même n'écrit rien.

## 15. Ce que je ne peux pas avoir vérifié hors jeu

- Le rendu du livre dans CEF (polices, rubans, onglets de tranche) : `web/index.html` dans un navigateur, `?staff=0`
  pour la vue d'un simple joueur ; les listes y sont simulées.
- La touche réellement liée lue par `GetControlInstructionalButton` : sûre pour une lettre, incertaine pour une touche
  de fonction ou spéciale (repli sur la touche par défaut).
- Le retour du clavier au Codex 150 ms après « Lancer » (`IsNuiFocused`) quand une commande affiche quelque chose.
- `ExecuteCommand` d'une commande du serveur depuis le client (elle doit arriver comme si elle était tapée).
- Le focus après l'arrêt de la ressource livre ouvert (10-1).
- La taille réelle des réponses `open` (estimée hors jeu en msgpack, sans l'enveloppe du core) : à lire au compteur
  réseau quand T-013 existera.
- La page qui garde son contenu entre deux ouvertures dans CEF (vérifié sous jsdom : contenu, signets et touches
  gardés ; préférences seules remplacées ; version inconnue → tout redemandé).

## 16. Pages de lecture (1.5.0)

L'onglet Lecture : trois chapitres et douze pages écrits côté serveur (`modules/vava_codex/content/*.lua`), l'index
dans le contenu du Codex (même empreinte), le texte d'une page demandé quand on l'ouvre (RPC `vava_codex:page`) et gardé
par la page. Préparation : A Souverain, B hors du Conseil (§ 0) ; tous les modules du dépôt démarrés ;
`log.level = 'debug'` pour lire « contenu envoyé | gardé » (§ 0.5).

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur. | Console : `pages de lecture : 12 chargées, 0 refusées`, puis `module 'vava_codex' v1.5.0 prêt`. |
| 2 | Console : `vava_codex_pages`. | Une ligne par page (id, chapitre, poids entre 1 700 et 7 500 octets avec les textes définitifs, `public` ou `Conseil`, module requis) ; aucune ligne « introuvable au registre ». |
| 3 | B : `F1`, onglet « Lecture ». | Trois onglets, Lecture en premier ; le livre s'est ouvert sur Commandes comme avant. Lecture : sommaire en trois chapitres, onze pages, aucun sceau « Conseil » ; tranche « Tout », « Premiers pas », « Les métiers », « Le royaume » ; la première page s'affiche. |
| 4 | B : cliquer « Troquer et partager », puis un lien vers une autre page, puis « Page suivante › ». | Le texte s'affiche aussitôt (première lecture : « Le Codex tourne la page… » à peine visible) ; le lien ouvre la page citée ; la navigation suit l'ordre du sommaire. |
| 5 | B : dans « Vivre à Eldoria », regarder le cabochon du Codex ; Paramètres › Raccourcis › FiveM : « Ouvrir le Codex » sur `J` ; rouvrir. | Le cabochon montre `F1`, puis `J` : la page cite la touche du joueur. Remettre `F1`. |
| 6 | B : cliquer `/me` dans « Se parler ». | Onglet Commandes, la ligne « /me » choisie, son formulaire prêt. |
| 7 | B : taper « grenier » dans la recherche de l'onglet Lecture. | Les pages dont le titre ou le résumé parle de grenier restent (ou aucune : « 0 page ») ; `Échap` vide la recherche. |
| 8 | **(2 joueurs)** A : `F1`, Lecture. | Douze pages : « Siéger au Conseil » porte le sceau « Conseil ». Ses liens de commandes (`/recolte zones`…) ouvrent les lignes du Conseil. |
| 9 | **(2 joueurs)** B lit les onze pages une fois ; A : `/vava_reseau joueur <B>`. | Chez B : `rpc vava_codex:page`, onze messages de 1 à 4 Ko chacun (un par page lue pour la première fois), et rien de plus ; le plus gros envoi de B reste `rpc vava_codex:open`. La page réservée ne peut pas être demandée par B (vérifié hors jeu : `codex_reading_spec.lua`, `unknown_page`). |
| 10 | B : fermer, rouvrir le Codex, relire une page déjà lue. | Console : `contenu gardé par la page` ; aucune nouvelle ligne `rpc vava_codex:page` pour cette page. |
| 11 | Console : `stop vava_magic` ; B rouvre. | `contenu envoyé` ; la page « La magie » a disparu du sommaire ; un lien qui y menait s'affiche en texte brut. `start vava_magic`, rouvrir : elle revient. |
| 12 | **(2 joueurs)** Console : `vava_conseil <B> senechal` ; B rouvre ; puis `vava_conseil <B> aucun` pendant que B a « Siéger au Conseil » ouvert, et B clique « Page suivante › » puis revient. | Sénéchal : la page réservée apparaît. Révoqué : la page déjà affichée reste à l'écran jusqu'à la fermeture, mais une nouvelle demande est refusée (« Cette page n'est plus dans le Codex. ») ; à la réouverture, elle a disparu. |
| 13 | Créer un nouveau personnage (accueil de `vava_arrival`). | Le Codex s'ouvre seul sur Lecture, chapitre « Premiers pas », page « Vivre à Eldoria » (`docs/tests/accueil.md` 20). |
| 14 | `F1` ensuite. | Le livre s'ouvre là où il a été laissé (Lecture, même page), sans nouvel appel pour cette page. |
| 15 | Cliquer très vite dix pages jamais lues. | Les six premières s'affichent, puis « Doucement… » ; une seconde plus tard, la suivante passe (`rateLimits.page`). |
| 16 | Dans `content/premiers_pas.lua`, écrire `[[foo:bar]]` dans une page ; `restart vava_codex`. | Console : `page « … » refusée : jeton mal formé … (ligne N)` ; les pages qui la citent sont refusées aussi (`lien vers une page absente…`), les autres sont là ; le Codex démarre. Annuler la modification. |
| 17 | Livre ouvert sur une page : `restart vava_codex`, puis `F1`. | Souris et clavier rendus ; `contenu envoyé` ; la page se relit (nouvel appel). |
| 18 | `resmon 1`, livre fermé puis en lisant. | `vava_codex` 0,00 ms au repos, au plus 0,02 ms en lisant ; côté serveur, l'ouverture coûte comme avant (+0,1 ms au plus). |
| 19 | Rendu hors jeu : `web/index.html?focus=premiers_pas`, puis `?staff=0&focus=troquer`. | Le livre s'ouvre sur la page voulue ; tous les blocs et jetons rendus (cabochons, liens, note, listes) ; pas de page réservée avec `staff=0`. |

Ce qui ne se voit pas hors jeu : la lisibilité d'une page longue dans CEF (défilement, police, liens au survol) ; le
cabochon d'une touche de souris (`[[touche:vava_magic_viser]]`, nom donné par `GetControlInstructionalButton`, sinon
`keyDisplay`) ; la première ouverture d'un joueur partie en latent (aucune attente visible à l'arrivée).
