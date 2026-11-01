# L'Atelier du Conseil — procédure de test en jeu

Procédure pour vérifier en jeu `vava_atelier` 1.4.0 avec son exemple `vava_example_atelier` 1.1.0 et
`vava_gathering` 1.8.0. § 1 à 9 (T-100, le socle) : ouverture et fermeture, ce que chacun voit selon son rang, la liste
et la fiche d'un atelier, « Vérifier », la recherche, le journal du Conseil, les redémarrages, ce qui passe sur le
réseau. § 10 à 17 (T-101, les définitions gardées) : brouillon, essai, publication, retour en arrière, deux membres sur
une fiche, la config et la base, les archives, les redémarrages. § 19 à 24 (T-102, l'outil de placement et l'atelier
« Récolte ») : placer une zone, poser des points, essai à blanc, publication vue des proches et non des lointains,
changements, refus. § 25 (T-157) : le code du Conseil livré au seul Conseil. Comptez une heure pour T-100, une heure
et demie pour T-101, une heure et demie pour T-102, une demi-heure pour T-157 ; les
tests à plusieurs joueurs sont marqués **(2 joueurs)** ou **(3 joueurs)**. Un test se cite « atelier 3-4 ». Préparation commune, mesure du resmon et remontée des
écarts : [LISEZMOI.md](LISEZMOI.md).

## 0. Préparation

1. **Mode développement** : `set vava_env dev` au `server.cfg` du serveur de test (voir
   [developpement.md](developpement.md)) ; sans lui, l'exemple ne déclare rien (§ 7-4).
2. **Ordre** : `ensure vava_atelier` juste après `ensure vava_admin`, puis `ensure vava_example_atelier` avec les autres
   ressources de `[vava-dev]`. Console du serveur : `module 'vava_atelier' v1.1.0 prêt`, `journal : aucune ligne de plus
   de 365 jours`, puis `atelier 'vava_example_atelier:panneaux' déclaré par vava_example_atelier (droit metiers,
   gardé)` et la même ligne pour `proclamations` (droit `staff`), chacune suivie de sa synchronisation (§ 10).
3. **Trois joueurs** : **A** Souverain (préparation commune), **B** Sénéchal (`vava_conseil <compte de B> senechal`),
   **C** hors du Conseil. `<B>` est le numéro de compte de B.
4. **Objets** : `vava_inventory` démarré, avec une Miche de pain au registre (`vava_example_items` en mode
   développement) pour le § 3-5.
5. **Ce qui part à chaque ouverture** (§ 8) : `log.level = 'debug'` dans `config/server.lua` du core le temps du § 8 ;
   la console écrit alors `[vava_atelier] accueil (joueur N, X atelier(s) visible(s)) : contenu envoyé | gardé par la
   page`.

## 1. Ouvrir et fermer

| # | Faire | Attendu |
|---|---|---|
| 1 | A : `F9`. | L'accueil s'ouvre comme la maquette `Main` : trois familles ; « Panneaux du bourg (exemple) » dans Le monde avec « 2 panneaux » ; « Proclamations (exemple) » dans La société avec « 1 proclamation » ; Récolte, Agriculture, Artisanat, Portes et clés, Confréries, Logis, Gestes, Techniques de combat, Effets, Sorts marqués « Bientôt », non cliquables ; « Aucun brouillon en cours. » ; curseur dans la recherche. |
| 2 | `Échap`. | L'Atelier se ferme ; souris et clavier reviennent au jeu. |
| 3 | `/atelier`. | Il s'ouvre. Le fermer par le bouton rond. |
| 4 | (Reporté) Bouton de la page Outils du Registre. | Pas de bouton « L'Atelier du Conseil » dans `F10` → Outils en 1.0.0 : il viendra avec une tâche qui touchera `vava_admin`. |
| 5 | Menu pause ouvert, ou à la sélection de personnage : `F9`. | Rien ne s'ouvre. |
| 6 | `F1` (Codex) → chapitre « Atelier ». | `/atelier` y figure, avec la touche `F9`, visible du Conseil seulement (absent chez C). |
| 7 | Paramètres › Raccourcis › FiveM : changer la touche « Ouvrir l'Atelier du Conseil ». | La nouvelle touche ouvre l'Atelier ; `F9` ne fait plus rien. Remettre `F9`. |

## 2. Droits — **(2 joueurs)** pour 2 à 5

| # | Faire | Attendu |
|---|---|---|
| 1 | C : `F9`, puis `/atelier`, plusieurs fois. | Rien ne s'ouvre ; notification « L'Atelier est réservé au Conseil. » ; console du serveur : une seule ligne `joueur N, compte M : vava_atelier:home refusé (droit)` par minute, même en insistant. |
| 2 | B : `F9`. | Seule la famille « Le monde » (Panneaux du bourg, et les cartes « Bientôt » du monde) ; « Proclamations (exemple) » absente ; note du bas lisible : « Un Sénéchal ne voit que le monde ; un Souverain voit tout. » |
| 3 | B, Atelier ouvert : `F8` → `nui_devtools`, onglet Console de la page de l'Atelier : `fetch('https://vava_atelier/editor', { method: 'POST', body: JSON.stringify({ editor: 'vava_example_atelier:proclamations' }) }).then(r => r.json()).then(console.log)`. | Réponse `{ ok: false, error: 'not_allowed' }` : le serveur refuse même appelé directement. Même chose avec `fetch('https://vava_atelier/journal', { method: 'POST', body: JSON.stringify({ before: 0, editor: 'vava_example_atelier:proclamations' }) })…`. |
| 4 | B a l'Atelier ouvert ; console du serveur : `vava_conseil <B> gardien`. | L'Atelier de B se ferme ; notification « Votre place au Conseil a changé : l'Atelier se ferme. » ; `F9` ne l'ouvre plus (« L'Atelier est réservé au Conseil. »). Remettre `vava_conseil <B> senechal`. |
| 5 | A écrit une ligne au journal de l'atelier Proclamations (§ 6-2) ; B ouvre l'Atelier, puis « Tout le journal ». | B ne voit pas cette ligne, ni sur l'accueil ni dans le journal entier ; A la voit. |

## 3. Liste et fiche

| # | Faire | Attendu |
|---|---|---|
| 1 | A : carte « Panneaux du bourg (exemple) ». | Liste en cadre centré : onglets « Panneaux » et « Affiches » ; « Panneau de la place », « Pancarte de la porte nord » ; « Créer un panneau ». |
| 2 | Taper `porte` dans le filtre. | Une seule ligne. |
| 3 | Ouvrir « Panneau de la place ». | Fiche en cadre centré, étiquette « Publiée, version 1 » (T-101) ; groupes « Ce qui est écrit », « Son allure », « Réglages » (replié) ; chaque réglage a sa phrase d'aide ; Hauteur « 1,5 m », Distance de lecture « 3 m » côte à côte ; Reste affiché « 7 jours » ; Apparence avec « Modèle provisoire : il sera remplacé automatiquement… » ; encadré « Pour comparer : Pancarte de la porte nord » (« 2,2 m, lisible à 5 m, 30 jours »). |
| 4 | Ouvrir la liste « Quartier ». | Les quatre quartiers (liste rendue par le module). Revenir à la liste, rouvrir la fiche : le quartier choisi s'affiche aussitôt par son nom, sans attendre ; `/vava_reseau joueur <A>` : aucun `rpc vava_atelier:options` à l'ouverture de la fiche (seulement quand on ouvre la liste). |
| 5 | « Objet au pied du panneau » : chercher `pain`. | Aide du champ : « Un objet posé là pour le décor : nul ne peut l'emporter. » ; l'objet « Miche de pain » avec son image ; le choisir. |
| 6 | Onglet « Affiches » → « Foire d'automne ». | Fiche en volet à droite, jeu visible derrière ; bandeau en haut à gauche « Panneaux du bourg (exemple) », « Mode édition : visible par vous seul » ; pas de barre des touches. |
| 7 | Modifier un champ, puis la flèche de retour. | « Quitter cette fiche ? Rien n'est encore enregistré : vos changements seront perdus. » ; « Rester » garde la fiche, « Quitter » revient à la liste. |

## 4. Vérifier

| # | Faire | Attendu |
|---|---|---|
| 1 | Fiche du panneau de la place, sans changement : « Vérifier ». | « Tout est en ordre. » ; rien ne change en jeu, rien au journal. |
| 2 | Nom vidé, puis « Vérifier ». | « À remplir. » sous « Nom du panneau », focus sur le champ. |
| 3 | Nom « pancarte de la porte nord » (celui de l'autre panneau, en minuscules sans accents). | Erreur du module sous le nom : « Un panneau porte déjà ce nom. » |
| 4 | Nom remis ; Éclairé coché, Reste affiché 2 heures. | « Un panneau éclairé reste au moins un jour : la lanterne doit valoir la peine. » |
| 5 | Langue « Runes », texte de 150 caractères. | « Les runes se gravent lentement : 120 caractères au plus. » |
| 6 | Nom « <b>Essai</b> ». | « Lettres, chiffres, espaces, apostrophes, traits d'union, virgules et points seulement. » ; le texte ne s'affiche jamais en gras nulle part. |
| 7 | « Créer un panneau ». | Fiche « Nouveau panneau », valeurs par défaut, étiquette « Rien d'enregistré » ; « Vérifier » avec un nom libre : « Tout est en ordre. » ; la liste n'a pas changé (« Vérifier » n'enregistre rien). |
| 8 | Cliquer « Vérifier » dix fois très vite. | Quelques réponses puis un message de patience ; aucune erreur en console du serveur hormis la limite de débit. |
| 9 | `nui_devtools` (comme 2-3), A : `fetch('https://vava_atelier/check', { method: 'POST', body: JSON.stringify({ editor: 'vava_example_atelier:panneaux', kind: 'panneau', id: '', values: { s: { intrus: 'x' } } }) }).then(r => r.json()).then(console.log)`. | `{ ok: false, error: 'unknown_field' }`. Puis avec `values: { n: { taille: 99 } }` : réponse `valid: false` avec « Entre 0,5 m et 3,0 m. » pour `taille`. |
| 10 | Nom du panneau : y coller un espace sans largeur (U+200B, copié depuis une table de caractères) entre deux lettres, puis « Vérifier ». | « Un caractère invisible s'est glissé : retirez-le. » sous le nom ; même chose avec une marque de sens (U+200F) ou un séparateur de ligne (U+2028). Les lettres « Ï », « í », « Ý » passent (« Tout est en ordre. »). |

## 5. Recherche

| # | Faire | Attendu |
|---|---|---|
| 1 | Accueil : `pan`. | Les cartes se filtrent à chaque lettre ; « Dans les ateliers » liste les deux panneaux (« Panneaux du bourg (exemple) › panneau »). |
| 2 | `PLACE`, puis `Entrée`. | Accents et casse ignorés ; la fiche « Panneau de la place » s'ouvre. |
| 3 | B (Sénéchal) : `couronnement`. | Aucun résultat : la proclamation n'est pas dans ses ateliers. |
| 4 | (`vava_atelier` 1.0.1, `vava_example_atelier` 1.0.1, T-133) Fiche « Panneau de la place » : nom ` Panneau de la place Š ` (espaces autour), « Vérifier » ; puis fiche « Pancarte de la porte nord » : nom ` PANNEAU DE LA PLACE ` ; puis, sur l'accueil, chercher `voilà`, `Ŧ` et `Š`. | Premier nom : « Tout est en ordre. » (le « Š » final n'est ni coupé ni pris pour un blanc). Second : « Un panneau porte déjà ce nom. ». Recherches : aucune erreur, aucun « � » dans les résultats ni en console du serveur. |

## 6. Journal

| # | Faire | Attendu |
|---|---|---|
| 1 | A : `/atelier_exemple journal panneaux Lettres repeintes`. | Chat : « ligne écrite au journal : « Panneau de la place » ». À la réouverture : « A annoté le panneau **Panneau de la place** — Lettres repeintes », « Souverain <nom de A>, à l'instant ». Le Registre (`F10` → Journal) a la ligne « Atelier : annoté » (atelier, objet, resume), recopiée une fois la ligne de l'Atelier écrite en base. |
| 2 | `/atelier_exemple journal proclamations Sceau changé`. | Ligne de l'atelier Proclamations (« A annoté la proclamation… ») ; voir § 2-5. |
| 3 | B (Sénéchal) : `/atelier_exemple journal proclamations essai`. | « refusé : cet atelier ne vous est pas ouvert. » ; aucune ligne. |
| 4 | Console du serveur : `atelier_exemple journal panneaux Depuis la console`. | La console répond « ligne écrite… » ; la ligne a pour auteur « Console » ; aucune recopie au journal du Registre. |
| 5 | Écrire 30 lignes (commande répétée), puis « Tout le journal ». | 25 lignes, puis « Plus anciens » donne la suite ; filtre « Panneaux du bourg (exemple) » ne garde que les siennes, toujours présentées comme lignes de cet atelier (le serveur ne répète plus l'atelier sur chaque ligne d'une page filtrée). |
| 6 | Redémarrer le serveur. | Les lignes sont toujours là ; console : `journal : aucune ligne de plus de 365 jours`. |
| 7 | En base : `UPDATE vava_atelier_journal SET created_at = NOW() - INTERVAL 400 DAY ORDER BY id LIMIT 1;` puis `restart vava_atelier`. | Console : `journal : 1 ligne(s) de plus de 365 jours retirée(s)`. |

## 7. Redémarrages

| # | Faire | Attendu |
|---|---|---|
| 1 | Fiche d'un panneau ouverte ; console : `restart vava_example_atelier`. | « Cet atelier vient d'être retiré : réessayez plus tard. », retour à l'accueil ; la carte revient à la réouverture (module redéclaré). |
| 2 | Atelier ouvert ; `restart vava_atelier`. | La page disparaît, souris et clavier rendus au jeu ; `vava_example_atelier` reste démarré ; après redémarrage, `F9` rouvre l'accueil avec les deux ateliers d'exemple (redéclarés au hook `vava_atelier:editorsReady`). |
| 3 | `stop vava_admin` ; `F9`. | « Le Registre du Conseil s'éveille : réessayez dans un instant. » ; `vava_atelier` reste démarré. `ensure vava_admin` : l'Atelier s'ouvre de nouveau. |
| 4 | Sans `set vava_env dev` : démarrer le serveur. | `vava_example_atelier` refuse de démarrer (« mode développement absent ») ; l'Atelier n'a que des cartes « Bientôt ». |
| 5 | `stop vava_inventory` ; fiche d'un panneau avec un objet choisi : « Vérifier ». | « La liste des objets du royaume ne répond pas : impossible de vérifier cet objet. » ; `ensure vava_inventory`, puis de nouveau « Tout est en ordre. ». |
| 6 | Serveur arrêté ; dans `modules/vava_atelier/config.lua`, `rights.overrides = { ['vava_magic:sorts'] = 'souverain' }` ; démarrer. | `vava_atelier` refuse de démarrer : « config.lua, droits : rights.overrides['vava_magic:sorts'] = 'souverain' : pas un droit permis (metiers, staff) ». Même refus pour un `floor` de famille ou `rights.open` hors de `metiers`, `staff`. Remettre `overrides = {}`. |
| 7 | Serveur arrêté ; `limits.descriptorBytes = 2000` ; démarrer. | Console : `éditeur 'vava_example_atelier:panneaux' : descripteur de 4… octets, au-delà de 2000 (limits.descriptorBytes), atelier refusé…` ; la carte « Panneaux du bourg (exemple) » n'est pas sur l'accueil ; les Proclamations (≈ 1 Ko) y sont. Remettre `32768`. |

## 8. Réseau et resmon — **(2 joueurs)** pour 1

| # | Faire | Attendu |
|---|---|---|
| 1 | A ouvre et parcourt l'Atelier ; C joue à côté ; `/vava_reseau joueur <C>`. | C n'a rien reçu de `vava_atelier`. |
| 2 | `/vava_reseau joueur <A>` après une première ouverture, puis une seconde. | `rpc vava_atelier:home` ≈ 3 à 4 Ko la première fois, ≈ 1 Ko la seconde (console en debug : « contenu gardé par la page ») ; `rpc vava_atelier:editor` ≈ 60 o à la seconde ouverture du même atelier. |
| 3 | `resmon 1` : au repos, puis Atelier ouvert. | `vava_atelier` à 0,00 ms au repos, ≤ 0,05 ms ouvert. |
| 4 | Seconde ouverture de l'accueil (console en debug : « contenu gardé par la page »). | Les étiquettes « 2 panneaux » et « 1 proclamation » sont affichées : elles partent à chaque ouverture, à part du contenu gardé. |

## 10. Brouillon (T-101)

Préparation : celle du § 0 ; en plus, **A** Souverain et **B** Sénéchal se placent près du « Panneau de la place »
(lieu de `boards[1].place` dans `examples/vava_example_atelier/config.lua`), **C** à plus de 200 m. `/vava_reseau
joueur <n°>` sert à voir ce que chacun reçoit. La première fois, la console écrit `atelier
'vava_example_atelier:panneaux' : 3 fiches en base, 3 venues de la config, 0 rapprochée(s), 0 retirée(s)` (deux
panneaux et une affiche), puis `… proclamations' : 1 fiches en base, 1 venues de la config…` ; le journal a une ligne
« A rétabli l'original de l'atelier **Panneaux du bourg (exemple)** — 3 fiches reprises de l'original » (auteur
Console).

| # | Faire | Attendu |
|---|---|---|
| 1 | A ouvre « Panneau de la place ». | Étiquette « Publiée, version 1 » ; pied : « Enregistrer le brouillon », liens « Historique », « Retirer du royaume », « Vérifier ». |
| 2 | Changer « Ce qui est écrit », « Enregistrer le brouillon ». | « Brouillon » ; liste : « Votre brouillon » ; accueil : « Vos brouillons » montre le panneau, « 1 réglage changé, pas encore publié » ; journal : « A enregistré le brouillon du panneau ». Rien en jeu (B : `/atelier_exemple lire` donne l'ancien texte). |
| 3 | Enregistrer encore deux fois. | Aucune ligne de journal de plus. |
| 4 | « Créer un panneau », nom « Lanterne du port », enregistrer. | Identifiant `lanterne_du_port` (console en debug : `fiche nouvelle 'lanterne_du_port'`), accueil « Nouveau panneau, pas encore publié », journal « A créé le panneau ». |
| 5 | Nom vidé, enregistrer. | « À remplir. » : rien d'enregistré. |
| 6 | Nom « Pancarte de la porte nord » (déjà pris), enregistrer. | Enregistré, avec « Brouillon enregistré. À corriger avant de publier : Un panneau porte déjà ce nom. » |
| 7 | « Abandonner le brouillon » sur « Lanterne du port ». | Confirmation, puis la fiche disparaît de la liste ; journal « A abandonné le brouillon du panneau ». |
| 8 | B ouvre la liste des panneaux. | Ligne « Brouillon de Souverain <nom de A> » sur le panneau de la place. |

## 11. Essai (T-101) — **(2 joueurs)** pour 2

| # | Faire | Attendu |
|---|---|---|
| 1 | A, brouillon du § 10-2 : « Voir le panneau ». | « Essai, version 2 » ; bandeau « Mode essai : vous seul voyez ce changement en jeu » (fiche en volet) ; chat de A : « [Essai] Le panneau « Panneau de la place » porterait : « … » ». Accueil : carte « 1 en essai ». |
| 2 | B : `/atelier_exemple lire`. | L'ancien texte seulement ; B n'a rien reçu de l'essai (`/vava_reseau joueur <B>` : aucune annonce). A : `lire` montre aussi la ligne « [Essai] ». |
| 3 | A change le texte, enregistre. | L'annonce d'essai repart chez A avec le nouveau texte. |
| 4 | A : « Arrêter l'essai ». | « Brouillon » ; chat « [Essai] Fin de l'essai du panneau… » ; journal « A fini l'essai du panneau — arrêté ». |
| 5 | Relancer l'essai, fermer l'Atelier (`Échap`). | Fin de l'essai (journal « fin de la séance ») ; à la réouverture, le panneau est « Brouillon ». |
| 6 | Serveur arrêté ; `trial.maxMinutes = 1` dans `modules/vava_atelier/config.lua` ; démarrer, relancer l'essai, laisser l'Atelier ouvert et attendre une minute. | Fin au bout d'une minute (« délai passé ») ; la fiche ouverte repasse « Brouillon » (évènement `entryChanged`). Remettre 30. |
| 7 | Atelier « Proclamations (exemple) » : un brouillon. | Aucun bouton d'essai. |
| 8 | Essai du panneau qui a une affiche en brouillon (§ 12-6) : l'essai part (« [Essai] Le panneau… » et « [Essai] L'affiche… »). Changer seulement la couleur de l'affiche, enregistrer ; puis son nom, enregistrer. | Couleur : aucune annonce (rien de ce qui se lit n'a changé) ; nom : seule l'annonce de l'affiche repart, pas celle du panneau. |
## 12. Publier (T-101) — **(2 joueurs)** pour 2 à 4

| # | Faire | Attendu |
|---|---|---|
| 1 | A : « Dresser le panneau ». | Boîte « Dresser le panneau ? » : « Panneau de la place : Texte repeint » (résumé du module, prioritaire sur « Retouché : Ce qui est écrit »), « La version 1 sera archivée ; celle-ci deviendra la version 2. », phrase « Dresser le panneau le rend lisible aux passants. » |
| 2 | Confirmer. | « Publiée, version 2 » ; B (proche) reçoit au chat « Le panneau « Panneau de la place » porte désormais : « … » » ; B : `lire` donne le nouveau texte ; journal « A publié le panneau — Texte repeint », Registre « Atelier : publié ». |
| 3 | C (à plus de 200 m) : `/vava_reseau joueur <C>`. | Rien de `vava_example_atelier` ni de `vava_atelier`. C s'approche à 20 m : il reçoit l'état de la zone (compté sous `vava_example_atelier`), pas d'annonce. |
| 4 | A change de nouveau le texte, enregistre, ouvre la boîte de publication sans confirmer ; B reprend le brouillon (§ 14-2) ; A confirme. | A : « Cette fiche a changé depuis que vous l'avez ouverte… » ; rien n'est publié (jeton du résumé périmé). |
| 5 | Publier une fiche identique à la publiée (brouillon sans changement). | « Rien n'a changé depuis la version publiée. » |
| 6 | Affiche enfant : la page de T-101 ne choisit pas de parent ; console de la page (`nui_devtools`) : `fetch('https://vava_atelier/save', { method: 'POST', body: JSON.stringify({ editor: 'vava_example_atelier:panneaux', kind: 'affiche', id: '', rev: 0, values: { s: { titre: "Marché de l'aube", couleur: 'vert', parent: 'place_du_marche' }, n: { duree: 3600 } } }) }).then(r => r.json()).then(console.log)`, puis publier le panneau (après un changement). | Résumé « 1 affiche ajoutée » ; une seule ligne de journal. |
| 7 | Une affiche créée par la page (sans parent) : « Dresser le panneau » sur elle. | « Cette fiche dépend d'une autre qui n'est pas publiée… » |
| 8 | Lot vu une fois (`validateLot`) : comme en 6, une affiche nommée « Foire d'automne » (le nom de l'affiche `foire` de la config, déjà collée sur ce panneau), puis « Dresser le panneau » (après un changement). | Boîte de publication refusée : « Deux affiches d'un même panneau portent le nom « Foire d'automne ». » ; rien n'est publié. Abandonner l'affiche : la publication repasse. |

## 13. Revenir en arrière, sans redémarrage (T-101) — **(2 joueurs)** pour 2 et 4

| # | Faire | Attendu |
|---|---|---|
| 1 | A : « Historique » du panneau. | « Version 2 — Publiée », « Version 1 — Archivée — Console », auteurs et âges. |
| 2 | Version 1 : « Revenir à cette version », confirmer. | « La version 1 sera rétablie et deviendra la version 3. » ; puis B reçoit l'annonce avec l'**ancien** texte ; `lire` le confirme ; journal « A restauré le panneau — version 1 rétablie » ; aucun redémarrage. |
| 3 | Historique. | « Version 3 — Publiée — rétablie de la version 1 ». |
| 4 | « Retirer du royaume », puis « Publier le retrait ». | Résumé « Retrait du panneau », « et de ses 1 affiche » ; B reçoit « Le panneau … a été retiré. » ; sa zone disparaît (`/vava_reseau zones <B>`) ; la fiche passe sous « Retirés du royaume » avec ses affiches. |
| 5 | « Retirés du royaume » → historique → version 3 → « Revenir à cette version ». | Résumé « 1 affiche ajoutée » ; panneau et affiche reviennent ; B reçoit l'annonce. |

## 14. Deux membres sur la même fiche (T-101) — **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | A a un brouillon du panneau ; B (Sénéchal) l'ouvre. | Lecture seule, « Brouillon de Souverain <nom>, enregistré il y a … », « Reprendre le brouillon ». B enregistre via devtools (`fetch('https://vava_atelier/save', …)`) : `draft_taken`. |
| 2 | B : « Reprendre le brouillon ». | Confirmation ; B tient le brouillon ; la fiche de A se relit en lecture seule avec « Cette fiche a changé ailleurs… » ; journal « A repris le brouillon du panneau — de Souverain <nom> ». |
| 3 | A essaie d'enregistrer (page restée ouverte, modifiée). | « Un autre membre du Conseil tient déjà un brouillon de cette fiche… » (ou « Cette fiche a changé… »). |
| 4 | B, console de la page (`nui_devtools`) : `fetch('https://vava_atelier/publish', { method: 'POST', body: JSON.stringify({ editor: 'vava_example_atelier:proclamations', kind: 'proclamation', id: 'couronnement', rev: 1, token: '0000000000000000' }) }).then(r => r.json()).then(console.log)`. | `{ ok: false, error: 'not_allowed' }` (droit `staff`). |

## 15. La config et la base (T-101)

| # | Faire | Attendu |
|---|---|---|
| 1 | Serveur arrêté ; dans la config de l'exemple, changer le texte de « Pancarte de la porte nord » ; démarrer. | La pancarte garde le texte **de la base** (`lire` près d'elle ; fiche « Publiée »). |
| 2 | Ajouter un troisième panneau à la config (`id` nouveau), `restart vava_example_atelier`. | Console « … 1 venues de la config … » ; le panneau est « Publiée, version 1 », auteur Console. |
| 3 | `/atelier_archives original_fiche vava_example_atelier:panneaux panneau porte_nord`. | « panneau « porte_nord » : Retouché : Ce qui est écrit » et « Tapez /atelier_archives confirmer sous 60 s… ». |
| 4 | `/atelier_archives confirmer`. | Nouvelle version avec le texte de la config ; journal « A rétabli l'original du panneau ». |
| 5 | B (Sénéchal) : `/atelier_archives original vava_example_atelier:panneaux`. | « Refusé : réservé au Souverain. » A : résumé de l'atelier entier ; les fiches créées dans l'Atelier ne sont pas comptées. |
| 6 | Retirer un panneau venu de la config, publier, redémarrer le serveur. | Il ne revient pas (une fiche connue n'est jamais réimportée sans commande). |

## 16. Archives (T-101)

| # | Faire | Attendu |
|---|---|---|
| 1 | A : `/atelier_archives exporter tout`. | « Archives écrites : atelier_<date>_<heure>.json (n fiches). » ; le fichier existe dans `modules/vava_atelier/echanges/`, ne contient que les versions publiées ; journal « A copié aux archives l'atelier … ». |
| 2 | Changer un panneau et le publier ; `/atelier_archives importer <fichier>`. | « Panneaux du bourg (exemple) : 1 à reprendre, n inchangées » ; `confirmer` : nouvelle version (`origin` import) ; B reçoit l'annonce ; journal « A repris des archives l'atelier … ». |
| 3 | Fichier modifié à la main : une taille de 99 m. | « Panneaux du bourg (exemple) : refusé — vava_example_atelier:panneaux.kinds.panneau[1].data.taille : valeur refusée pour « Hauteur »… » ; rien d'écrit pour cet atelier. |
| 4 | `importer ../server.json`, `importer a.lua`. | « Nom de fichier refusé… ». |
| 5 | B : `exporter tout`. | « Refusé : réservé au Souverain. » |
| 6 | `/atelier_archives etat`. | Une ligne par atelier gardé : publiées, brouillons, essais, retirées. |
| 7 | A : `exporter tout`, puis de nouveau moins d'une minute après (B Souverain aussi, s'il l'est). | Le second : « Une copie aux archives vient d'être faite : réessayez dans n s. » ; un seul fichier écrit. |
| 8 | B (Sénéchal) revient au choix du personnage, puis tape dans la console F8 `atelier_archives etat` et `atelier_archives original_fiche vava_example_atelier:panneaux panneau porte_nord`. | « Choisissez d'abord un personnage. » les deux fois ; rien au journal, rien de publié. |
| 9 | A : `original_fiche` sur une fiche changée (§ 15-3), puis, avant `confirmer`, B publie un changement de **la même** fiche ; A : `confirmer`. | « Les fiches ont changé depuis le résumé : relancez la commande. » ; la publication de B reste en vigueur. |

## 17. Redémarrages (T-101)

| # | Faire | Attendu |
|---|---|---|
| 1 | A en essai ; `restart vava_example_atelier`. | Fin de l'essai (« atelier retiré »), notification « L'essai de « … » a pris fin. » ; après redémarrage : le panneau est « Brouillon », le magasin de l'exemple a l'état de la base (`lire` : texte publié, pas celui de la config). |
| 2 | A en essai ; `restart vava_atelier`. | Page fermée ; au retour, brouillon (jamais « Essai ») ; console : `… 0 rapprochée(s) …` (l'exemple était déjà à l'état de la base). |
| 3 | Base arrêtée (MySQL coupé) ; enregistrer. | « Les registres de l'Atelier ne répondent pas : réessayez dans un instant. » ; rien ne change en jeu. Base relancée : tout refonctionne. |
| 4 | Un `apply` qui refuse : console `set vava_example_refuse 1`, publier. | « Refus d'essai demandé. » ; la fiche reste « Brouillon », la version publiée est intacte en jeu (`lire`), console : `refus du module (…), base rendue, resynchronisation` puis `… (fiches du lot seulement)` (les autres fiches ne sont pas relues). Remettre `set vava_example_refuse 0`. |
| 5 | `history.keep = 2` dans la config de l'Atelier, redémarrer ; publier quatre fois le même panneau. | Historique : jamais plus de 2 versions après chaque publication (purge des fiches du lot, sans redémarrage) ; au démarrage, la console écrit la purge une minute après « editorsReady » (`history.purgeDelayMs`), après les lignes de synchronisation. Remettre 20. |

## 19. Placer une zone (T-102)

Préparation (§ 19 à 24) : `vava_gathering` 1.8.0 démarré **après** `vava_atelier` 1.3.0 (console : `atelier
'vava_gathering:zones' déclaré par vava_gathering (droit metiers, gardé)`, puis sa synchronisation : 4 zones et
12 points importés en version 1 au premier démarrage). **A** Sénéchal (droit `metiers`), **B** joueur sans rang près de
A, **C** joueur à plus de 400 m ; A tient une hache de bûcheron (emplacement Mains). `/vava_reseau joueur <n°>` (droit
`tools`) pour voir ce que reçoit chacun. Lieu : une clairière libre à plus de 150 m des zones de la graine (Forêt de
Brume, Mine du Val, Prairie Haute, Rivière Claire).

| # | Faire | Attendu |
|---|---|---|
| 1 | A : `F9` → carte « Récolte · 4 zones » → « Nouvelle zone », nom « Bois des Essais », enregistrer. | Volet de la maquette `Recolte` ; étapes « La zone · Les points · Publier », la première en cours ; bloc Lieu « Pas encore placée. » et bouton « Placer la zone ». |
| 2 | « Placer la zone ». | Le volet s'atténue ; bandeau « Atelier de la récolte » / « Mode édition : les cercles et étiquettes ne sont visibles que par vous » ; barre « Clic Poser ici · Molette Rayon · Maj Réglage fin · Ctrl Z Annuler · Échap Quitter » ; anneau vert de 60 m sous la visée, libellé « Bois des Essais, rayon 60 m » ; A peut marcher et tourner la caméra. |
| 3 | Molette ×4 vers le haut, puis `Maj` + molette ×3. | Rayon 80 m, puis 81,5 m. |
| 4 | Viser à plus de 60 m de A. | Anneau rouge, « Bois des Essais — Trop loin de vous (… m) : approchez-vous. » ; un clic ne fait rien. |
| 5 | Viser le ciel. | « Visez le sol. » |
| 6 | Poser près de A. | Retour au volet ; « Posée à … m de vous, rayon 81,5 m » ; étape 1 cochée ; journal « A a créé la zone Bois des Essais » (aucune autre ligne). |
| 7 | « Déplacer la zone », la viser à cheval sur la Forêt de Brume (s'en approcher d'abord), cliquer. | Rouge après le clic : « Cette zone empiète sur « Forêt de Brume » de … m. » (refus du module, `placeCheck`) ; rien d'écrit. |
| 8 | Pendant une visée : `Échap`. | Retour au volet ; la bannière du royaume (`vava_pause`) ne s'ouvre pas. |
| 9 | `resmon` pendant une visée, puis après. | `vava_atelier` ≤ 0,15 ms en visée ; 0,00 ms après. |

## 20. Poser des points (T-102) — **(2 joueurs)** pour 8

| # | Faire | Attendu |
|---|---|---|
| 1 | « Prochain point à poser » : Chêne, 3 récoltes, 10 minutes. | Phrase « Apparence : chêne de GTA, modèle provisoire. Il sera remplacé automatiquement quand le modèle médiéval sera ajouté. » |
| 2 | « Poser des points ». | Barre « Clic Poser ici · Molette Tourner · Maj Placement précis · Clic droit Choisir un point · Ctrl Z Annuler · Échap Quitter » ; chêne fantôme (translucide) sous la visée ; anneau laiton de la zone ; libellé « Chêne 1, emplacement valide » en vert. |
| 3 | Molette ; `Maj` + molette. | Le fantôme tourne de 15°, puis de 1°. |
| 4 | Viser à plus de 5 m hors de l'anneau. | Rouge : « Chêne 1 — Hors de Bois des Essais. » |
| 5 | Poser cinq chênes à 3 m l'un de l'autre. | Cinq fantômes ; liste « 5 points, dont 5 nouveaux », « Chêne 1 » à « Chêne 5 », « 3 récoltes » ; étape 2 cochée ; journal : une ligne « A a enregistré le brouillon de la zone Bois des Essais » si la zone était publiée (brouillon de la zone créé par la première pose), aucune par point. Un point à 1 récolte : « 1 récolte ». |
| 6 | Viser à 1 m de « Chêne 2 ». | Rouge : « Chêne 6 — Trop près de « Chêne 2 » (1 m). » |
| 7 | `Ctrl+Z`. | « Chêne 5 » disparaît (liste et fantôme). Le reposer. |
| 8 | B, près de A : regarder ; `/vava_reseau joueur <B>`. | B ne voit ni chêne, ni anneau, ni étiquette ; rien de `vava_gathering` ni de `vava_atelier` reçu. |
| 9 | A : clic droit sur « Chêne 3 », clic 4 m plus loin ; puis `Ctrl+Z`. | Barre « Clic Déplacer ici · … · Clic droit Lâcher le point », étiquette « Chêne 3 : cliquez à sa nouvelle place » ; « Chêne 3 » déplacé, puis revenu à sa place. |
| 10 | Clavier AZERTY : `Ctrl+Z`. | Même effet (touche `Z` réelle, commande-touche `+vava_atelier_annuler` ; réglable dans Paramètres › Raccourcis › FiveM). |
| 11 | Spam de clics (10 en 1 s). | Six poses au plus, puis « Doucement : patientez un instant. » ; aucune pose en double. |
| 12 | `Échap`, puis corbeille sur « Chêne 5 » (jamais publié), confirmer ; bouton repère « Marquer Chêne 1 sur la carte ». | La ligne disparaît (brouillon abandonné) ; « 4 points, dont 4 nouveaux ». Le reposer. |
| 13 | Ouvrir « Chêne 2 » par son titre ; « Déplacer le point », le poser 2 m plus loin ; « retour ». | Visée de la fiche seule, retour au volet du point après le clic ; « retour » ramène à la zone, liste à jour. |

## 21. Tester la récolte (T-102, essai à blanc) — **(2 joueurs)** pour 3

| # | Faire | Attendu |
|---|---|---|
| 1 | A : « Tester la récolte ». | La page se range ; bandeau seul « Mode essai : vous seul voyez ces points · F9 : revenir à l'Atelier » ; cinq vrais chênes chez A (plus de fantômes). |
| 2 | A récolte « Chêne 1 » à la hache. | Invite « Essai » ; geste et barre normaux ; « [Essai] Chêne : … × Bûche de chêne (…). Rien n'est donné pendant un essai. » ; besace inchangée, aucune XP (fiche de personnage), hache non usée (solidité). |
| 3 | B regarde ; `/vava_reseau joueur <B>` et `/vava_reseau joueur <A>`. | B : rien vu, rien reçu ; A : `vava_gathering:trial` seulement (≈ 0,3 Ko au début, ≈ 0,1 Ko par récolte). |
| 4 | A récolte encore « Chêne 1 » jusqu'au bout. | « Il n'y a plus rien à prendre ici pour le moment. » à la 4e. |
| 5 | A range la hache, tente un chêne. | « Il vous faut une hache en main. » |
| 6 | B tente de récolter là où A voit un chêne d'essai. | Aucune invite chez B (rien n'existe pour lui). |
| 7 | A : `F9`. | Volet rendu tel qu'il était ; étiquette « Essai, version 1 ». « Arrêter l'essai » : les chênes disparaissent chez A. |

## 22. Publier : proches et lointains (T-102) — **(3 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | A : « Publier la zone ». | Boîte « Publier la zone ? » : « Nouvelle zone », « 5 points ajoutés », « Ce sera la version 1. », phrase « Publier rend les nouveaux points visibles aux joueurs proches. » |
| 2 | Confirmer. B regarde. | En une seconde au plus, B voit les cinq chênes sortir de terre, **sans redémarrage** ; `/vava_reseau joueur <B>` : un état de zone (`vAvA:zone:state`) sous `vava_gathering`, ≈ 0,3 Ko. |
| 3 | `/vava_reseau joueur <C>` ; `/vava_reseau zones <C>`. | Rien de `vava_gathering` ni de `vava_atelier` chez C ; la zone `vava_gathering:bois_des_essais` n'est pas suivie par C. |
| 4 | C approche à 150 m du centre de la zone. | C reçoit l'état entier une fois (cercle d'intérêt : rayon + 100 m), puis voit les chênes à 80 m. |
| 5 | B récolte « Chêne 2 ». | Bûches réelles dans la besace, XP de Bûcheronnage, hache usée, vitalité de la zone baissée (`/recolte zone bois_des_essais`). |
| 6 | Journal de l'Atelier. | Une ligne « A a publié la zone Bois des Essais — 5 points ajoutés » ; aucune ligne par pose. |
| 7 | B se reconnecte et ouvre la grande carte. | Blip « Bois des Essais » et son cercle. Se reconnecter encore : `/vava_reseau joueur <B>` ne montre que ≈ 30 o pour `vava_gathering:map`. |

## 23. Changer, retirer, revenir (T-102) — **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | A déplace « Chêne 4 » de 5 m (fiche du point, « Déplacer le point »), publie. | Résumé « Chêne 4 : déplacé de 5 m » ; B voit l'arbre changer de place (≈ 0,1 Ko reçu, une `vAvA:zone:diff`). |
| 2 | A change seulement « Fatigue par récolte » de la zone, publie. | B ne reçoit **rien** (`/vava_reseau joueur <B>`). |
| 3 | A : corbeille sur « Chêne 5 » (publié), « Publier la zone ». | « 1 point retiré » ; l'arbre disparaît chez B. |
| 4 | Historique de la zone → version 1 → « Revenir à cette version ». | Le chêne revient chez B sans redémarrage. |
| 5 | « Retirer du royaume » la zone, publier le retrait. | Zone et points disparaissent chez B ; son blip reste jusqu'à la prochaine connexion de B (liste de la carte gardée). |

## 24. Refus, appels directs, redémarrages (T-102)

| # | Faire | Attendu |
|---|---|---|
| 1 | B (sans droit), par une ressource de test côté client : `core.rpc.call('vava_atelier:place', 'vava_gathering:zones', 'node', '', 0, { x = …, y = …, z = …, h = 0 }, 'bois_des_essais', { s = { ressource = 'chene' } })` à sa position. | `not_open` ou `not_allowed` ; rien d'écrit ; une ligne de refus en console (une par minute). |
| 2 | A, même appel (Atelier ouvert) avec `x` à 500 m de lui. | `done = false`, « Trop loin de vous (… m) : approchez-vous. » ; rien d'écrit. |
| 3 | A, `{ x = 0/0, … }`, puis une clé `r` sur un point. | `invalid_args` (schéma) ; clé `r` : refus de lieu « r : clé inconnue pour un lieu oriented ». |
| 4 | A dans une instance (intérieur, cachot), pose un point. | « Vous êtes hors du monde commun (intérieur, cachot…) : revenez-y pour placer. » |
| 5 | A1 et A2 (deux Sénéchaux) : A2 pose un point dans une zone publiée dont A1 tient le brouillon. | « Un autre membre du Conseil tient déjà un brouillon de cette fiche… » (`draft_taken`) ; rien d'écrit. |
| 6 | Visée en cours ; console : `restart vava_atelier`. | Fantômes retirés, souris et clavier rendus ; `Échap` rouvre normalement la bannière du royaume. |
| 7 | `restart vava_gathering`. | Zones et points de la base (pas de la graine : « Bois des Essais » est là si elle est publiée) ; console : aucun `apply` si rien n'a changé. |
| 8 | Serveur arrêté, base gardée ; démarrer **sans** `vava_atelier`. | La récolte tourne sur sa graine, avec l'avertissement « vava_atelier absent : la récolte tourne sur sa graine… » ; `ensure vava_atelier` : retour à l'état de la base (synchronisation), sans redémarrer la récolte. |
| 9 | Monter à cheval, « Placer la zone ». | « Descendez de votre monture pour placer. » |
| 10 | « Tester la récolte », puis `F9`, puis « Poser des points ». | La visée démarre (les lieux de la zone sont gardés pendant l'essai joué). |
| 11 | « Placer » un enclos (tracé, exemple 1.2.0 quand il existera) ou toute zone : poser un sommet, `Échap`. | « Appuyez encore sur Échap pour abandonner le tracé. » ; libellé « Sommets posés : 1 (Entrée pour fermer le tracé) ». |
| 12 | A en essai joué ; console : `restart vava_atelier` (ou `stop vava_atelier`). | Les chênes d'essai disparaissent chez A dans la seconde (fin de l'essai par la récolte) ; rien chez les autres joueurs. |
| 13 | « Poser des points » dans la Rivière Claire avec « Chêne » comme ressource. | Rouge après le clic : « Une zone d'eau ne porte que des bancs de poissons. » ; rien d'écrit. |
| 14 | A pose des points pendant que A2 a la fiche de la zone ouverte. | Chez A2 : une seule relecture de la fiche après la dernière pose (pas une par pose). |
| 15 | B (sans rang) ouvre `resmon` près d'une zone suivie pendant que A récolte dix fois. | `vava_gathering` reste au plus bas (une récolte ne fait regrouper aucun point chez B). |

## 25. Code livré au seul Conseil (T-157)

Préparation : A Souverain, B Sénéchal, C habitant sans rang ; ressource `vava_atelier` 1.4.0 ; F8 ouvert.

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur. | Console : `paquet du Conseil : 24 fichiers, 248 218 octets, 4 morceaux, empreinte …, SHA-256 …` ; aucun avertissement. Si la ligne dit « directive vava_conseil_lua vide ou absente », FXServer n'a pas lu la forme en table : écrire une ligne par fichier (`vava_conseil_lua 'config_conseil.lua'`, …), même effet. |
| 2 | Hors jeu : `./scripts/poids-client.sh --detail vava_atelier`. | Ligne `vava_atelier` 57 668 o (22 359 compressés) ; ni `placer.lua` ni `app.js` dans le détail du joueur ; ligne `vava_atelier@conseil` 248 218 o. |
| 3 | **(2 joueurs)** C appuie sur F9 ; A lance `/vava_reseau joueur <C>`. | « L'Atelier est réservé au Conseil. » ; chez C : seulement `rpc vava_atelier:code`, ≈ 40 o ; aucun envoi latent. |
| 4 | C ouvre Paramètres › Raccourcis › FiveM. | « Atelier : annuler le dernier placement » n'y est pas ; « Ouvrir l'Atelier du Conseil » y est. |
| 5 | B (stockage vide : première fois) appuie sur F9. | « On apporte les registres de l'Atelier : un instant… », puis l'Atelier s'ouvre en ≈ 4 à 5 s ; `/vava_reseau joueur <B>` : `rpc vava_atelier:code` ≈ 245 Ko, 4 latents. |
| 6 | B ferme puis rouvre (F9 deux fois). | Ouverture immédiate ; aucun `code` de plus. |
| 7 | B se reconnecte, F9. | Ouverture en moins d'une demi-seconde, sans notification ; un seul `code` (≈ 85 o). |
| 8 | B parcourt : accueil, Récolte, une zone, « Placer », molette, Maj, clic droit, Ctrl+Z, Échap, essai joué, F9 retour. | Tout comme en 1.3.0 (§ 19 à 21 en raccourci) ; Ctrl+Z annule (AZERTY compris) ; rendu au pixel près des maquettes `Main` et `Recolte`. |
| 9 | Pendant le téléchargement de l'étape 10 (nouvelle version), B appuie dix fois sur F9. | Un seul téléchargement ; aucune erreur ; l'Atelier s'ouvre une fois. |
| 10 | Changer un commentaire de `client/placer.lua`, `restart vava_atelier`, B F9. | Nouvelle empreinte en console ; B retélécharge une fois (notification), puis 7 redevient vrai. |
| 11 | `restart vava_atelier` Atelier ouvert chez B ; B F9. | Atelier fermé proprement (souris rendue) ; F9 le rouvre depuis le stockage local (pas de téléchargement). |
| 12 | (développeur) Ajouter `error('essai')` à la ligne 30 de `client/drawing.lua`, restart, B F9 ; puis retirer. | F8 : `vava_atelier/client/drawing.lua:30: essai` (sans `@@` ; sinon passer `CHUNK_PREFIX` de `client/loader.lua` à `'@'`) ; « Les registres de l'Atelier n'ont pas pu être ouverts… » ; F9 suivant : même message, aucun RPC. |
| 13 | (développeur) Ajouter `throw new Error('essai')` en tête de `web/js/widgets.js`, restart, B F9 ; puis retirer. | Console F8 : `paquet du Conseil : page : la page signale web/js/widgets.js` ; message `loadFailed`. Dans `nui_devtools`, les sources s'appellent `vava_atelier/web/js/…`. |
| 14 | **(2 joueurs)** B a l'Atelier ouvert ; A retire le rang de B (Registre). | Chez B : « Votre place au Conseil a changé : l'Atelier se ferme. » ; F9 → « réservé au Conseil » ; A rend le rang : B retélécharge (stockage effacé). |
| 15 | **(2 joueurs)** A retire le rang de B pendant le téléchargement de B (étape 5 relancée). | Téléchargement interrompu, rien d'exécuté, « réservé au Conseil ». |
| 16 | **(2 joueurs)** A et B ouvrent l'Atelier en même temps, stockages vides. | Les deux reçoivent le paquet ; chacun ≈ 245 Ko dans `/vava_reseau`. |
| 17 | A (n'a jamais ouvert l'Atelier de la séance) lance `/atelier_archives etat`. | Réponse au chat (« Atelier »), sans téléchargement. |
| 18 | B `resmon 1` : au repos après une ouverture, Atelier fermé ; puis en visée. | `vava_atelier` 0,00 ms au repos ; visée ≤ 0,15 ms (comme T-102). |
| 19 | B sans personnage (sélection) appuie sur F9. | « Choisissez d'abord un personnage. » ; aucun morceau envoyé. |
| 20 | `restart vava_admin` puis aussitôt B F9 (après une reconnexion). | « Le Registre du Conseil s'éveille… » ; F9 quelques secondes plus tard : ouverture normale depuis le stockage local. |
| 21 | (développeur, relecture sécurité S-2) B ouvre l'Atelier ; dans `nui_devtools`, sur la page de `vava_atelier`, poser un point d'arrêt dans `onMessage` de `boot.js` et regarder `event.source` d'un message `hello` (F9 après un `restart vava_atelier`). | Noter ce que vaut `event.source` pour `SendNUIMessage` (la page, son parent ou `null`). Si c'est `null`, la garde de `boot.js` garde la source vide (rien à changer) ; si c'est la page ou son parent, la clause « source vide » peut être retirée. Dans tous les cas l'Atelier s'ouvre. |
| 22 | **(2 serveurs, relecture sécurité S-1)** Sur un second serveur de test (autre adresse) avec une ressource nommée `vava_atelier` qui écrit `SetResourceKvp('paquet:empreinte', 'essai-autre-serveur')` à son démarrage, B se connecte, puis revient sur Eldoria ; dans F8 d'Eldoria, `GetResourceKvpString('paquet:empreinte')` (ressource de débogage, ou ligne ajoutée au chargeur le temps de l'essai). | Noter si la valeur lue est celle du second serveur (stockage partagé entre serveurs : S-1 confirmé) ou celle d'Eldoria. Dans les deux cas, B ouvre l'Atelier sans rien exécuter de faux : avec une valeur étrangère, l'empreinte ne correspond pas et le paquet est retéléchargé ; un faux paquet de même empreinte FNV-1a serait refusé par la SHA-256 (console : « SHA-256 différente de celle annoncée par le serveur, rien n'est exécuté »). |
| 23 | B `resmon 1`, stockage vide puis plein, F9 (relecture réseau R-4). | Pas d'à-coup visible à l'ouverture ; la SHA-256 (≈ 70 ms de Lua en tout) est étalée sur ≈ 16 images. |

## 26. Fin du test

Remettre `log.level = 'info'`, retirer B du Conseil s'il n'en était pas (`vava_conseil <B> aucun`), arrêter
`vava_example_atelier` si le serveur doit servir à autre chose. Les lignes de test restent au journal (365 jours) :
`DELETE FROM vava_atelier_journal WHERE editor LIKE 'vava_example_atelier:%';` pour les retirer. T-101 :
`DELETE FROM vava_atelier_definitions WHERE editor LIKE 'vava_example_atelier:%';` pour repartir de la config, et
supprimer les fichiers `.json` de `modules/vava_atelier/echanges/`. T-102 : retirer « Bois des Essais » par
l'Atelier (§ 23-5) ou, pour repartir de la graine de la récolte, `DELETE FROM vava_atelier_definitions WHERE editor =
'vava_gathering:zones';` serveur arrêté (les lignes de vitalité et de charges de `vava_gathering_zones` et
`vava_gathering_nodes` peuvent rester).
