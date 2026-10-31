# L'Atelier du Conseil — procédure de test en jeu

Procédure pour vérifier en jeu `vava_atelier` 1.1.0 avec son exemple `vava_example_atelier` 1.1.0. § 1 à 9 (T-100, le
socle) : ouverture et fermeture, ce que chacun voit selon son rang, la liste et la fiche d'un atelier, « Vérifier », la
recherche, le journal du Conseil, les redémarrages, ce qui passe sur le réseau. § 10 à 17 (T-101, les définitions
gardées) : brouillon, essai, publication, retour en arrière, deux membres sur une fiche, la config et la base, les
archives, les redémarrages. Comptez une heure pour T-100, une heure et demie pour T-101 ; les tests à plusieurs joueurs
sont marqués **(2 joueurs)**. Un test se cite « atelier 3-4 ». Préparation commune, mesure du resmon et remontée des
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

## 17. Redémarrages (T-101)

| # | Faire | Attendu |
|---|---|---|
| 1 | A en essai ; `restart vava_example_atelier`. | Fin de l'essai (« atelier retiré »), notification « L'essai de « … » a pris fin. » ; après redémarrage : le panneau est « Brouillon », le magasin de l'exemple a l'état de la base (`lire` : texte publié, pas celui de la config). |
| 2 | A en essai ; `restart vava_atelier`. | Page fermée ; au retour, brouillon (jamais « Essai ») ; console : `… 0 rapprochée(s) …` (l'exemple était déjà à l'état de la base). |
| 3 | Base arrêtée (MySQL coupé) ; enregistrer. | « Les registres de l'Atelier ne répondent pas : réessayez dans un instant. » ; rien ne change en jeu. Base relancée : tout refonctionne. |
| 4 | Un `apply` qui refuse : console `set vava_example_refuse 1`, publier. | « Refus d'essai demandé. » ; la fiche reste « Brouillon », la version publiée est intacte en jeu (`lire`), console : `refus du module (…), base rendue, resynchronisation`. Remettre `set vava_example_refuse 0`. |

## 18. Fin du test

Remettre `log.level = 'info'`, retirer B du Conseil s'il n'en était pas (`vava_conseil <B> aucun`), arrêter
`vava_example_atelier` si le serveur doit servir à autre chose. Les lignes de test restent au journal (365 jours) :
`DELETE FROM vava_atelier_journal WHERE editor LIKE 'vava_example_atelier:%';` pour les retirer. T-101 :
`DELETE FROM vava_atelier_definitions WHERE editor LIKE 'vava_example_atelier:%';` pour repartir de la config, et
supprimer les fichiers `.json` de `modules/vava_atelier/echanges/`.
