# L'Atelier du Conseil — procédure de test en jeu

Procédure pour vérifier en jeu `vava_atelier` 1.0.0 (T-100, le socle) avec son exemple `vava_example_atelier` 1.0.0 :
ouverture et fermeture, ce que chacun voit selon son rang, la liste et la fiche d'un atelier, « Vérifier », la
recherche, le journal du Conseil, les redémarrages, et ce qui passe sur le réseau. T-100 n'enregistre encore **aucune
définition** : rien de ce que l'on vérifie ici ne change le royaume. Comptez une heure, dont un quart à deux ou trois ;
les tests à plusieurs joueurs sont marqués **(2 joueurs)**. Un test se cite « atelier 3-4 ». Préparation commune, mesure
du resmon et remontée des écarts : [LISEZMOI.md](LISEZMOI.md).

## 0. Préparation

1. **Mode développement** : `set vava_env dev` au `server.cfg` du serveur de test (voir
   [developpement.md](developpement.md)) ; sans lui, l'exemple ne déclare rien (§ 7-4).
2. **Ordre** : `ensure vava_atelier` juste après `ensure vava_admin`, puis `ensure vava_example_atelier` avec les autres
   ressources de `[vava-dev]`. Console du serveur : `module 'vava_atelier' v1.0.0 prêt`, `journal : aucune ligne de plus
   de 365 jours`, puis `atelier 'vava_example_atelier:panneaux' déclaré par vava_example_atelier (droit metiers)` et la
   même ligne pour `proclamations` (droit `staff`).
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
| 3 | Ouvrir « Panneau de la place ». | Fiche en cadre centré, étiquette « En vigueur » ; groupes « Ce qui est écrit », « Son allure », « Réglages » (replié) ; chaque réglage a sa phrase d'aide ; Hauteur « 1,5 m », Distance de lecture « 3 m » côte à côte ; Reste affiché « 7 jours » ; Apparence avec « Modèle provisoire : il sera remplacé automatiquement… » ; encadré « Pour comparer : Pancarte de la porte nord » (« 2,2 m, lisible à 5 m, 30 jours »). |
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
| 7 | « Créer un panneau ». | Fiche « Nouveau panneau », valeurs par défaut, étiquette « Rien d'enregistré » ; « Vérifier » avec un nom libre : « Tout est en ordre. » ; la liste n'a pas changé (rien n'est enregistré avant T-101). |
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

## 9. Fin du test

Remettre `log.level = 'info'`, retirer B du Conseil s'il n'en était pas (`vava_conseil <B> aucun`), arrêter
`vava_example_atelier` si le serveur doit servir à autre chose. Les lignes de test restent au journal (365 jours) :
`DELETE FROM vava_atelier_journal WHERE editor LIKE 'vava_example_atelier:%';` pour les retirer.
