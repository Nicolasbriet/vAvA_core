# Eau potable — procédure de test en jeu

Procédure pour vérifier en jeu `vava_provisions` 1.0.0 (« Vivres » : points d'eau, outres, eau potable, T-130) avec
ses voisins : `vava_inventory` 1.8.0 (échange, hook d'utilisation), `vava_needs` (soif), `vava_crafting` (tannerie),
`vava_arrival` 1.1.0 (dotation reprise). Comptez une heure ; les tests à deux joueurs sont marqués **(2 joueurs)**.
Chaque test dit quoi faire et ce qui doit se passer ; si ce n'est pas le cas, notez l'étape, ce que vous avez vu, et la
ligne de console correspondante. Un test se cite « eau 11 ».

## 0. Préparation

1. **Préparation commune** : [LISEZMOI.md](LISEZMOI.md) (ordre de démarrage avec `vava_provisions` après
   `vava_farming`, compte du Conseil, catalogue, consoles, resmon, remontée des écarts).
2. **Rôles** : A est Sénéchal (console : `vava_conseil <compte de A> senechal`) ; B n'a aucun rang.
3. **Outils de test** (serveur de test seulement) : `set vava_env dev` au `server.cfg`, `vava_dev_characters` démarré
   (`/besoins <faim> <soif>`, `/objet <nom> [quantité]`, `/aterre`) ; réservés au Souverain ou à l'ACE `vava.dev`
   (B : `add_ace identifier.license:<licence> vava.dev allow` en console). `vava_example_items` peut rester arrêté :
   il ne déclare plus l'eau.
4. **Consoles** : celle du serveur et celle du client (`F8`) ouvertes.
5. **Points d'eau de la config** (exemples autour du point d'apparition par défaut, `-- PLACEHOLDER`) :
   Fontaine du bourg (-250, -960, sans fond), Puits du lavoir (-300, -985, 40 puisages, + 1 par minute), Source de la
   Rivière Claire (-118, -876, 15 puisages, + 1 toutes les 3 min). Tannerie du bourg (`vava_crafting`) : -280, -925.

## 1. Démarrage, dotation, outre rendue

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur. | Console : `module 'vava_provisions' v1.0.0 prêt`, aucune ligne « recette de l'outre non déclarée », aucun avertissement d'objet ; `vava_arrival` v1.1.0 prêt. |
| 2 | B crée un personnage. | Besace : 2 Outre d'eau, image de l'outre ; fiche « Soif +40 », description nouvelle (« … l'outre vide vous reste, si la couture tient. »). |
| 3 | B : `/besoins 100 50`, boit une Outre d'eau. | Geste de boire, soif vers 90 ; une **Outre vide** apparaît dans la besace (ou, une fois sur dix, l'avis « La couture cède : l'outre se fend… » et rien). |

## 2. Au point d'eau

| # | Faire | Attendu |
|---|---|---|
| 4 | B marche vers la Fontaine du bourg depuis 200 m. | Le prop apparaît vers 80 m ; à 2 m : invite « [E] Puiser ou boire — Fontaine du bourg » ; elle disparaît en s'éloignant. |
| 5 | B, une Outre vide : `E`. | Geste de puiser (~2,5 s) ; « Vous remplissez une outre. » ; besace : l'Outre vide est devenue une Outre d'eau. |
| 6 | B, aucune Outre vide, `/besoins 100 50` : `E`. | Geste de boire ; « Vous buvez quelques gorgées d'eau fraîche. » ; soif vers 70. |
| 7 | B : `/besoins 100 96`, aucune Outre vide : `E`. | « Vous n'avez pas soif. Pour emporter de l'eau, il vous faut une outre vide. » ; rien ne change. |
| 8 | B : `E` deux fois en moins de 3 s (soif 50). | La seconde : « Patientez un instant. » ; une seule gorgée comptée. |
| 9 | B : `/objet outre 7` (deux piles), `E`, puis `E` après 3 s. | 5 remplies, puis 2. |

## 3. Réserves et Conseil

| # | Faire | Attendu |
|---|---|---|
| 10 | A : `/eau points`. | Un seul message (les lignes regroupées) dans le chat de A seul, une ligne par point : « Puits du lavoir (puits_lavoir, puits) : 40 / 40 puisages. », « Fontaine du bourg (fontaine_bourg, fontaine) : sans fond. ». Registre : rien (lecture seule). |
| 11 | A : `/eau reserve puits_lavoir 2` ; B au Puits du lavoir avec 5 Outres vides, soif 99 : `E`, puis `E`. | Chat de A : « Réserve de Puits du lavoir : 2 / 40. » ; Registre (`F10`) → Journal : « Réserve d'eau fixée » (point, réserve 2, ancienne 40). B : 2 remplies, puis « Le seau racle le fond : le puits doit se remplir (environ 1 min). » |
| 12 | B (même puits à sec, 3 Outres vides) : `/besoins 100 50`, `E`. | « Trop peu d'eau pour remplir une outre, mais assez pour boire quelques gorgées. » ; soif vers 70. |
| 13 | Attendre 1 min, `E` (soif 99). | Une outre remplie. |
| 14 | **(2 joueurs)** A : `/eau reserve puits_lavoir 1` ; A et B au puits, chacun une Outre vide, soif 99 ; appuyer sur `E` au même moment. | Un seul « Vous remplissez une outre. » ; l'autre : « Le seau racle le fond… ». |
| 15 | **(2 joueurs)** B puise devant A. | A voit le geste de B ; ni notification ni objet chez A. |

## 4. Besace pleine, outre fendue, tannerie

| # | Faire | Attendu |
|---|---|---|
| 16 | B charge sa besace près de 25 kg avec 5 Outres vides, soif 99 : `E`. | « Votre besace serait trop lourde. » ; les outres restent vides ; `/eau points` : réserve inchangée. |
| 16 bis | Même besace, `/besoins 100 50` : `E` au même puits. | « Votre besace serait trop lourde. Vous buvez quelques gorgées d'eau fraîche. » ; geste de boire, soif vers 70 ; outres toujours vides ; réserve inchangée. |
| 17 | B, besace pleine sauf la place de ses Outres d'eau (pile de 2), boit une Outre d'eau. | « Votre besace est pleine : l'outre vide est perdue. » ; soif remontée. |
| 18 | `tearChance = 1` dans la config, `restart vava_provisions` ; B boit une Outre d'eau. Remettre `0.1`. | « La couture cède : l'outre se fend… » ; aucune Outre vide. |
| 19 | B, 1 Cuir tanné (`/objet cuir 1`) à la Tannerie du bourg : recette « Outre ». | 2 Outres vides (palier noté) ; XP de Tannerie. |

## 5. À terre, Codex, réseau, coût

| # | Faire | Attendu |
|---|---|---|
| 20 | B : `E` à terre près de la fontaine (`/aterre`). | Pas d'invite ; `E` ne sert qu'à rendre l'âme. |
| 21 | B : `F1`. | Chapitre « Vivres » : la touche `E`. `/eau` absent chez B, présent chez A avec ses deux actions. |
| 22 | **(2 joueurs)** A à la fontaine, B à plus de 500 m. `/vava_reseau joueur <B>`, puis `/vava_reseau joueur <A>`. | Chez B : aucune ligne `vava_provisions`. Chez A : un `vAvA:zone:state` (~160 o) à son arrivée, `rpc vava_provisions:draw` à chaque appui, rien d'autre. |
| 23 | `resmon` de B loin de tout point, puis à la fontaine. | `vava_provisions` à 0,00 ms loin ; ≤ 0,01 ms à la fontaine. |

## 6. Redémarrages

| # | Faire | Attendu |
|---|---|---|
| 24 | B à la fontaine : `restart vava_provisions`. | Le prop disparaît puis revient ; les Outres d'eau et vides de B disparaissent un instant de la besace puis reviennent à leur place. |
| 25 | `stop vava_provisions` ; C crée un personnage ; `ensure vava_provisions`. | Accueil de C sans la ligne de la besace (console : objet `eau` inconnu, dotation reportée) ; au retour du module, en quelques secondes : 2 pains et 2 outres dans la besace de C, sans nouvel accueil. |
| 26 | `restart vava_inventory`, puis `restart vava_crafting`. | Outres retrouvées dans les besaces ; la recette « Outre » de nouveau à la tannerie. |
| 27 | Console du serveur : `eau points`. | Les lignes s'écrivent dans la console. |

## 7. Ce qui reste à confirmer (README de `vava_provisions`)

- Le geste `WORLD_HUMAN_GARDENER_PLANT` (puiser) et `mp_player_intdrink` (boire) tiennent 2,5 s et s'arrêtent net
  (tests 5 et 6).
- Le prop `prop_barrel_01a` posé au sol (`PlaceObjectOnGroundProperly`) aux coordonnées d'exemple ; `z` des points au
  niveau du sol, sinon le serveur répond « Approchez-vous davantage. » (test 4).
- Aucune autre invite sur `E` à moins de 2 m des trois points d'exemple : stations de l'artisanat, puits de
  l'agriculture, nœuds de récolte (la Source de la Rivière Claire est à 10 m du nœud de truite le plus proche).
- Sans `vava_chat`, la réponse de `/eau` arrive en notification au seul membre (test 10, `stop vava_chat`).
