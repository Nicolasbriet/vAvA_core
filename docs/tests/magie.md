# Magie d'Eldoria — procédure de test en jeu

Procédure pour vérifier en jeu `vava_magic` 2.6.0 : fiche et commandes du Conseil, roue et mode magie, incantation,
mana, verrouillage, les onze sorts, états élémentaires, zones au sol, combinaisons, effets et sons, triche,
déconnexions, redémarrage et resmon. Le module n'a encore jamais été joué : chaque écart compte, même petit. Comptez
trois heures seul et une heure et demie à plusieurs ; les tests à deux sont marqués **(2 joueurs)**, ceux qui
demandent un témoin ou un voisin **(3 joueurs)**.

Conventions : « N1 » à « N5 » sont les niveaux d'un sort ; les dégâts sont en points de vie sur 100 (« −8 » : B perd
8 % de sa vie, appliqués par vava_health) ; les valeurs citées sont celles de `modules/vava_magic/config.lua`. Il n'y a
pas de fatigue dans le code : seuls la mana, la recharge de chaque sort et le délai global de 1 s bornent le combat.
Aucun sort ne s'apprend en jeu : seul le Conseil en donne (`/magie`) ; le grimoire ne fait que les montrer.

## 0. Préparation

1. **Commune** : ordre de démarrage, compte du Conseil, objets, consoles, mesure du resmon et remontée des problèmes :
   voir [LISEZMOI.md](LISEZMOI.md).
2. **Démarrage** : la console du serveur affiche `module 'vava_magic' v2.6.0 prêt`. La migration `sql/0001_magic.sql`
   crée `vava_magic_sigils`, `vava_magic_registers`, `vava_magic_register_pages` et `vava_magic_damage_log`. Une ligne
   `… non déclaré(e) : …` (un sort refusé au chargement) ou `sort en erreur` est à me remonter telle quelle.
3. **Rôles** : A, membre du Conseil (droit `tools` : Sénéchal ou Souverain) ; B, second joueur sans droits ; C,
   troisième joueur (témoin, voisin). Les commandes `/magie` prennent le **numéro de joueur** (Registre du Conseil,
   `F10` → Joueurs) ; sans numéro, elles visent leur auteur. Dans les tableaux, `<B>` est le numéro de B.
4. **Lieu** : un terrain plat et dégagé, avec un mur ou une maison à portée (ligne de vue, obstacles), un véhicule
   garé, et un toit accessible ; de nuit pour juger les lumières.
5. **Mages** : `/magie tous` (A sur lui-même), `/magie tous <B>` ; puis `/magie niveau [id] <sort> <1-5>` pour chaque
   niveau à tester. Entre deux tests, `/magie mana` et `/magie recharges` remettent la mana et les recharges.
6. **Où regarder** : barre de mana en bas de l'écran, avec le sceau du sort prêt (icône, nom, niveau en chiffres
   romains) ; icônes d'états et leurs secondes à droite de la barre ; mot bref d'une combinaison au-dessus d'elle.
7. **Coût en mana** (coût de base × 1 / 0,9 / 0,8 / 0,7 / 0,6, arrondi ; orbe ancré de la Lueur × 1,5) :

   | Sort | N1 | N2 | N3 | N4 | N5 |
   |---|---|---|---|---|---|
   | Boule de feu | 14 | 13 | 11 | 10 | 8 |
   | Mur de flammes | 24 | 22 | 19 | 17 | 14 |
   | Nova ardente | 30 | 27 | 24 | 21 | 18 |
   | Trait de glace | 12 | 11 | 10 | 8 | 7 |
   | Vague | 26 | 23 | 21 | 18 | 16 |
   | Brume | 22 | 20 | 18 | 15 | 13 |
   | Projectile de roche | 18 | 16 | 14 | 13 | 11 |
   | Secousse | 24 | 22 | 19 | 17 | 14 |
   | Rempart | 28 | 25 | 22 | 20 | 17 |
   | Lueur (orbe ancré) | 8 | 7 | 6 | 6 (8) | 5 (7) |
   | Murmure | 12 | 11 | 10 | 8 | 7 |

8. **Réglages pour aller vite** (`modules/vava_magic/config.lua`, puis `restart vava_magic` ; remettre la valeur par
   défaut après le test). Un redémarrage efface les recharges en cours et les états : c'est sans conséquence ici.

   | Clé | Défaut | Pour le test | Sert à |
   |---|---|---|---|
   | `controls.idleMs` | `20000` | `5000` | endormissement du mode magie (2-12) |
   | `targeting.idleMs` | `20000` | `5000` | verrou relâché sans attaque (4-6) |
   | `progression.antiFarmMs` | `20000` | `0` | XP à chaque lancer |
   | `mana.regenPoints` | `3` | `20` | mana qui remonte vite |
   | `sigils.refusedMs` | `60000` | `10000` | délai après un sigil refusé (8.2-3) |
   | `spells.mur_de_flammes.levels[1].durationMs` | `4000` | `60000` | trois murs à la fois, zone vue en approchant (5.2, 10) |
   | `combos.gel.result.durationMs` | `2500` | `30000` | se déconnecter gelé (14) |
   | `spells.rempart.levels[1].cooldownMs` | `15000` | `120000` | recharge gardée à la reconnexion (13-3) |
   | `zones.maxActive` | `60` | `2` | plafond des zones du royaume (10-3) |
   | `spells.rempart.maxPieces` | `48` | `3` | plafond des remparts (7.3-8) |
   | `combat.protectedZones` | `{}` | `{ { label = 'Essai', x = <x>, y = <y>, radius = 20.0 } }` | zone protégée (position lue dans la fiche du Registre) |
   | `combat.pvp` | `true` | `false` | sorts sans effet sur les joueurs (5.1-8) |

## 1. Fiche, commandes du Conseil, grimoire

| # | Faire | Attendu |
|---|---|---|
| 1 | A, jamais mage : `/magie fiche`. | Dans le chat (préfixe « Arcanes ») : « Fiche magie de <Prénom Nom> (joueur n° x) », « Mage : non · sort choisi : aucun », « — aucun sort », « Sigils gardés : 0 · mana : 0 / 100 », « Combinaisons découvertes : 0 / 7 ». `vava_magic_sigils` a une ligne pour ce personnage (sigil de 12 signes). |
| 2 | `/magie mage oui`. | « La magie s'éveille en vous. » ; « C'est fait. » dans le chat ; aucune barre de mana (elle est pleine). |
| 3 | `/magie apprendre boule_de_feu`, puis `/magie niveau boule_de_feu 3`. | « Un savoir nouveau s'éveille en vous : Boule de feu. » ; puis deux annonces : « Boule de feu, niveau 2 : Votre boule de feu frappe plus fort et plus loin. » et « Boule de feu, niveau 3 : Votre boule de feu éclate à l'impact et touche ceux qui entourent la cible. » ; `/magie fiche` : « — Boule de feu : niveau 3 (300 XP) ». |
| 4 | `/magie xp boule_de_feu 99999`. | XP bornée à 1500 : niveau 5, annonces des niveaux 4 et 5. |
| 5 | `/magie oublier boule_de_feu` ; `/magie vider`. | « Le sort Boule de feu s'efface de votre mémoire. » ; « Tous vos sorts s'effacent de votre mémoire. » ; A reste mage. |
| 6 | `/magie tous`, `/magie fiche`, puis `/magie maitrise`, `/magie fiche`. | « Tous les sorts s'éveillent en vous. » (une seule notification, sans annonce de niveau) ; onze sorts, dans cet ordre : Boule de feu, Mur de flammes, Nova ardente, Trait de glace, Vague, Brume, Projectile de roche, Secousse, Rempart, Lueur, Murmure ; niveau 1 (0 XP), puis niveau 5 (1500 XP). |
| 7 | `/magie tous <B>` ; `/magie donner <B> grimoire` ; `/magie donner <B> registre`. | B : « La magie s'éveille en vous. », « Tous les sorts s'éveillent en vous. » ; un Grimoire et un Registre des murmures dans sa besace ; A : « C'est fait. » |
| 8 | B lance un sort ; A : `/magie mana <B>`, `/magie recharges <B>`. | B : « Votre mana est pleine. » ; « Vos sorts sont tous prêts. » ; le sort n'est plus grisé dans sa roue. |
| 9 | `/magie niveau 999 lueur 2`. | « Aucun personnage en jeu sous ce numéro. » |
| 10 | `/magie niveau lueur 7` ; `/magie apprendre foudre` ; `/magie danse`. | Ligne d'usage (`Usage : /magie <action> [id] … — mage [id] <oui\|non> · …`) ; « Sort inconnu. Sorts : boule_de_feu, mur_de_flammes, … » ; ligne d'usage. |
| 11 | B : `/magie fiche`. | « Ces commandes sont réservées au Conseil. » ; `/magie` n'est pas suggérée dans le chat de B. |
| 12 | Console du serveur : `magie tous <B>`, `magie fiche <B>`, puis `magie fiche` sans numéro. | Réponses dans la console, préfixées `[vava_magic]` ; sans numéro : « Aucun personnage en jeu sous ce numéro. » |
| 13 | Registre du Conseil (`F10`) → journal ; Chancellerie. | Une ligne par commande : « Magie : mage », « Magie : sort appris », « Magie : niveau de sort », « Magie : XP de sort », « Magie : tous les sorts », « Magie : maîtrise de tout », « Magie : sorts retirés », « Magie : mana remplie », « Magie : recharges effacées », « Magie : fiche consultée », « Magie : objet donné », « Magie : nettoyage du monde », avec joueur et personnage. Depuis la console : ligne dans la console du serveur. |
| 14 | **(2 joueurs)** B incante une Lueur N1 ; A : `/magie mage <B> non`. | Chez B : incantation brisée (« La magie ne vous a jamais répondu. »), « La magie s'est retirée de vous. », barre de mana retirée ; Tab n'ouvre plus rien. `/magie mage <B> oui` : mana pleine. |
| 15 | B : `/magie mage <B> non` (par A), puis `/magie apprendre <B> lueur`. | B : « Un savoir nouveau s'éveille en vous : Lueur. » ; Tab n'ouvre rien ; `/lancer lueur` : « La magie ne vous a jamais répondu. » ; le grimoire reste scellé. Remettre B mage. |
| 16 | B, mage, utilise le Grimoire (inventaire) ou tape `/grimoire`. | Pages rangées par groupe (Feu, Eau, Terre, Utilitaires) ; par sort : icône, « Élément : Feu », « Niveau 1 », « 0 / 100 XP », description du niveau, « Au niveau suivant » et ce qu'il débloque, « Mana : 14 », « Recharge : 4 s », « Incantation : instantanée » (Boule de feu, Trait de glace ; Projectile de roche N1 : « 0,5 s »), « Incantation : 2,5 s » pour la Lueur N1, « Verrouiller : Clic molette » pour les trois projectiles, « Roue : Tab · viser : Clic droit · lancer : Clic gauche » (nom de la touche Tab tel que GTA le donne, à confirmer) ; Murmure : « Sigils mémorisables : 10 ». Au N5 : « Maîtrise achevée », « 1500 XP ». |
| 17 | C (non mage) : `/magie donner <C> grimoire`, puis l'utiliser. | « Les pages restent illisibles : les signes se dérobent à votre regard, comme si le livre refusait de vous parler. » |

## 2. Roue des sorts et mode magie

| # | Faire | Attendu |
|---|---|---|
| 1 | Tab maintenu. | La roue s'ouvre au centre, curseur au centre ; la caméra ne tourne plus ; la roue d'armes de GTA n'apparaît pas. Anneau intérieur : Feu, Eau, Terre, Utilitaires (seuls les groupes d'un sort connu) ; au centre : « Annuler ». |
| 2 | Survoler Feu, puis Boule de feu. | L'anneau extérieur montre les sorts du feu (icône, niveau en chiffres romains, coût) ; au centre : « Boule de feu » et « Niveau 1 · Mana : 14 ». |
| 3 | Relâcher Tab sur Boule de feu. | La roue se ferme ; le sceau du sort prêt s'affiche avec la barre de mana ; aucune notification. |
| 4 | Rouvrir la roue. | Le groupe du sort prêt est ouvert d'emblée ; une entrée « Ranger la magie » (main ouverte) s'ajoute à l'anneau intérieur. Relâcher au centre : rien ne change. |
| 5 | Rouvrir, relâcher sur « Ranger la magie ». | Plus de sort prêt ; le clic gauche frappe de nouveau. |
| 6 | Rouvrir, `Échap`. | Roue fermée, rien n'est choisi. |
| 7 | Roue ouverte, clic gauche sur un sort. | Le sort est choisi, sans être lancé. |
| 8 | Lancer un sort, rouvrir la roue aussitôt. | Le sort en recharge est grisé avec ses secondes, qui décroissent. |
| 9 | Boule de feu prête, mains vides, à pied : clic gauche. | La boule part, pas de coup de poing ; la barre de mana se montre et luit pendant l'incantation. |
| 10 | Sortir une arme ; clic gauche ; la ranger ; clic gauche. | L'arme tire normalement, le sort reste prêt ; arme rangée, le clic gauche relance la boule (moins de 20 s après la dernière action). |
| 11 | Monter en véhicule ; clic gauche ; descendre. | Comportement normal de GTA en véhicule ; à pied, le mode magie reprend (s'il ne s'est pas endormi entre-temps). |
| 12 | Ne rien faire 20 s (`controls.idleMs`). | Mode endormi : la barre disparaît si la mana est pleine, sinon son sceau pâlit ; le clic gauche frappe comme d'habitude. Clic droit : réveillé (sceau lumineux). |
| 13 | Boule de feu N1 prête : clic droit maintenu, viser à 10 m puis à 30 m. | Réticule orange au centre, gris au-delà de 20 m ; marche ralentie, course impossible tant qu'on vise. |
| 14 | Même chose avec Mur de flammes, Rempart, Brume, Secousse, Nova ardente, Vague. | Aperçu au sol, vu du seul lanceur : bande en travers du regard (mur, rempart ; deux bras en chevron pour le Rempart N5), disque au point visé (brume, secousse), disque autour de soi (nova), cône devant soi qui suit la caméra (vague) ; les sorts visés au sol passent au gris hors de portée. Pas de réticule pour Nova ni Vague. |
| 15 | Lueur N1 prête, clic droit ; puis Lueur N4. | N1 : ni réticule ni aperçu (la visée ne sert qu'à partir du N4) ; N4 : réticule et petite sphère au point visé (8 m au plus). |
| 16 | Mode magie éveillé, Lueur prête : molette vers le bas, puis vers le haut ; Boule de feu prête : molette vers le bas trois fois. | Lueur → Murmure → Lueur (même groupe Utilitaires) ; Boule de feu → Mur de flammes → Nova ardente → Boule de feu. Endormi, la molette ne change rien. |
| 17 | `/sort trait_de_glace` ; `/sort Vague` ; `/sort aucun` ; `/sort foudre`. | « Sort prêt : Trait de glace. » ; « Sort prêt : Vague. » ; « Vous rangez votre magie. » ; « Usage : /sort <nom> \| aucun. Sorts connus : boule_de_feu, … » |
| 18 | Boule de feu prête : `/lancer` sans viser ; `/lancer mur_de_flammes`. | La boule part droit devant le personnage ; « Visez le sol, à portée. » |
| 19 | Paramètres → Raccourcis → FiveM : « Magie : roue des sorts (maintenir) » sur `G`. | Les sept actions « Magie : … » y figurent ; `G` ouvre et ferme la roue ; le grimoire affiche la nouvelle touche. Remettre Tab. |
| 20 | Se déconnecter, revenir. | Le sort prêt est retrouvé (gardé dans la fiche) ; mode magie endormi jusqu'au premier clic droit. |

## 3. Incantation, mana, recharges, XP

| # | Faire | Attendu |
|---|---|---|
| 1 | Lueur N1 : clic gauche. | Barre d'incantation « Lueur » de 2,5 s, geste de la Lueur, barre de mana qui luit ; à la fin : lumière dans la main, mana 100 → 92 ; la barre reste visible jusqu'à ce que la mana soit pleine (+3 toutes les 5 s). |
| 2 | **(2 joueurs)** B à 10 m, puis à 20 m, pendant deux incantations de A. | À 10 m : « * fait naître une lueur au creux de sa main * » au-dessus de la tête de A ; à 20 m, plus de texte (15 m au plus). |
| 3 | Boule de feu N1 : clic gauche en marchant. | Incantation de 0,45 s sans barre ; on peut marcher (ni courir ni sauter) ; flammes dans les deux mains, vues de B. |
| 4 | Lueur : `X` pendant l'incantation. | « Vous laissez l'incantation s'éteindre. », barre « Incantation brisée » ; mana inchangée, aucune recharge : on peut relancer aussitôt. |
| 5 | Lueur : faire plus d'un mètre pendant l'incantation. | « Vous avez bougé : l'incantation se brise. » ; rien n'est consommé. |
| 6 | **(2 joueurs)** Lueur : B frappe A d'un coup de poing pendant l'incantation. | « La douleur brise votre concentration. » ; rien n'est consommé. |
| 7 | Lueur : se laisser tomber d'un muret pendant l'incantation. | « Votre chute brise l'incantation. » |
| 8 | Boule de feu N1 : recliquer pendant l'incantation, puis dans la seconde qui suit, puis encore. | « Vous incantez déjà. » ; « Laissez la magie retomber un instant. » (délai global 1 s) ; « Le sort n'est pas encore prêt (n s). » (recharge de 4 s, secondes arrondies au-dessus) ; une seule boule, une seule dépense. |
| 9 | Trois Boules de feu sur un mur, à 5 s puis 20 s de la première ; `/magie fiche` entre chaque. | +20 XP, +0, +20 (un même sort rapporte au plus toutes les 20 s). Une boule qui touche B rapporte 10 de plus, seulement si son lancer a rapporté ; une boule éteinte, 10. À 100 XP : « Boule de feu, niveau 2 : … » |
| 10 | Novas N1 (30) à la suite, `/magie recharges` entre chaque. | 100 → 70 → 40 → 10 ; la quatrième : « Votre mana est trop faible. », rien ne part ; sous 25 % la barre prend sa teinte basse. À 30 (environ 35 s plus tard), la nova repart. |
| 11 | Mana pleine, mode magie endormi. | Aucune barre (elle ne se montre que mana entamée, mode éveillé, ou 4 s après un sort). |
| 12 | Se déconnecter avec 10 de mana, revenir. | Mana pleine (jamais sauvegardée) ; sorts, XP, sigils et sort prêt retrouvés. |

## 4. Verrouillage de cible

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** A (Boule de feu N1 connue) regarde B à 10 m : clic molette. | Anneau rouge qui tourne sous B, vu de A seul. |
| 2 | **(3 joueurs)** B et C devant A ; clic molette, puis encore. | L'anneau passe de l'un à l'autre (du plus proche du centre de l'écran au plus excentré, dans un cône de 25°). |
| 3 | Clic molette maintenu au moins 0,6 s. | Verrou relâché. |
| 4 | A connaît tous les sorts au N1 : clic molette sans personne devant, ou B à 30 m. | « Aucune cible en vue. » La portée prise est celle du sort d'attaque connu qui porte le plus loin : 25 m (Trait de glace N1). |
| 5 | B passe derrière un mur ; puis B s'éloigne à plus de 27 m. | Verrou perdu après une seconde sans le voir ; perdu aussi au-delà de cette portée plus 2 m. |
| 6 | Verrouiller B, ne rien lancer pendant 20 s (`targeting.idleMs`). | Verrou relâché. |
| 7 | **(2 joueurs)** Boule de feu N1 sur B verrouillé, A regardant ailleurs. | Dès le début de l'incantation, chez B seul : bord de l'écran rougi 2,2 s et « Un frisson vous parcourt… » ; au jet, A se tourne vers B ; la boule part droit sur B. |
| 8 | B se décale pendant le vol (N1 : 14 m/s). | La boule garde sa ligne : B l'esquive. |
| 9 | `/magie niveau boule_de_feu 5`, même chose ; puis N4 ; puis Trait de glace N4 et N5 ; puis Projectile de roche N5. | Boule : s'incurve vers B et le rattrape (70°/s au N5, 35°/s au N4) ; Trait : un peu (20°/s au N4, 40°/s au N5) ; Projectile de roche : jamais. |
| 10 | A lance une Boule de feu puis un Trait de glace sur B en moins de 3 s. | Un seul frisson (au plus un toutes les 3 s par lanceur et par cible). |
| 11 | A, sans mana, lance sur B verrouillé. | « Votre mana est trop faible. » ; B ne frissonne pas. |
| 12 | A connaît Boule de feu N5 (45 m) et Projectile de roche N1 (18 m) : verrouiller B à 35 m, lancer la roche. | « Votre cible vous échappe. », rien n'est consommé (le serveur juge la portée du sort lancé, le verrou celle du sort qui porte le plus loin). |
| 13 | Projectile de roche N1 sur B verrouillé à 19 m ; B recule de 3 m pendant l'incantation. | Le bloc part là où A vise (droit devant sans viser), sans suivre B. |

## 5. Sorts de feu

### 5.1 Boule de feu

| Niveau | Incantation | Recharge | Vitesse | Portée | Dégâts | En plus |
|---|---|---|---|---|---|---|
| N1 | 0,45 s | 4 s | 14 m/s | 20 m | 8 | s'éteint une fois sur cinq |
| N2 | 0,40 s | 3,5 s | 17 m/s | 26 m | 12 | une fois sur dix |
| N3 | 0,35 s | 3 s | 20 m/s | 32 m | 15 | éclats à 2,5 m (50 %) ; 6 % d'échec |
| N4 | 0,30 s | 2,5 s | 24 m/s | 38 m | 17 | éclats à 2,5 m (50 %) ; Brûlure 4 s, −2/s ; s'incurve 35°/s ; 3 % |
| N5 | 0,25 s | 2 s | 32 m/s | 45 m | 22 | éclats à 3,5 m (60 %) ; Brûlure 5 s, −3/s ; 70°/s ; 1 % |

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** N1 : A vise B à 10 m (clic droit), clic gauche. | Jet vers le réticule ; boule de flammes et lumière orange vues de A et de B ; impact en flammes, son d'impact ; B −8, geste bref de réaction et éclat « brûlure » à l'écran ; aucune explosion de GTA ; A : +20 XP et +10. `vava_magic_damage_log` : `boule_de_feu`, `impact`, `8.000`. |
| 2 | **(2 joueurs)** B à 25 m, N1. | La boule disparaît au bout de 20 m ; aucun dégât. |
| 3 | Dix lancers N1 (`/magie recharges` si besoin). | Environ deux fois : « La boule de feu s'éteint entre vos mains. », vapeur aux mains, son d'extinction ; mana dépensée, recharge posée, 10 XP. |
| 4 | **(3 joueurs)** N3 : B et C à moins de 2,5 m l'un de l'autre ; A touche B. | B −15, C −7,5 ; A n'est jamais touché par ses éclats. |
| 5 | **(2 joueurs)** N3 : tirer au sol à 2 m de B. | B −7,5. |
| 6 | **(2 joueurs)** N4 : toucher B. | B : « Les flammes vous mordent ! », icône Brûlure et ses secondes, bord de l'écran rougi ; flammes sur B vues de tous ; −2 chaque seconde pendant 4 s (lignes `brulure` au journal). |
| 7 | Zone protégée (réglage) : A dedans, puis A dehors et B dedans. | A dedans : « Une paix sacrée règne en ce lieu : la magie offensive ne vous obéit pas. », rien consommé. B dedans : la boule vole et éclate, B ne perd rien. |
| 8 | `combat.pvp = false`. | La boule part et éclate ; B ne perd rien, ne brûle pas ; aucune ligne au journal. |

### 5.2 Mur de flammes

| Niveau | Incantation | Recharge | Portée | Taille | Durée | Au passage | Brûlure laissée |
|---|---|---|---|---|---|---|---|
| N1 | 1,2 s | 14 s | 12 m | 3 × 1,2 m | 4 s | −6 | 3 s, −2/s |
| N2 | 1,1 s | 13 s | 13 m | 4,5 × 1,2 m | 5 s | −7 | 3 s, −2/s |
| N3 | 1,0 s | 12 s | 14 m | 6 × 1,3 m | 6 s | −8 | 3 s, −3/s |
| N4 | 0,9 s | 10 s | 15 m | 8 × 1,4 m | 7 s | −10 | 4 s, −3/s |
| N5 | 0,8 s | 9 s | 16 m | 10 × 1,5 m | 8 s | −12 | 4 s, −4/s |

| # | Faire | Attendu |
|---|---|---|
| 1 | Clic gauche sans viser ; en visant à 15 m (N1). | « Visez le sol, à portée. » dans les deux cas, rien consommé. |
| 2 | Clic droit sur le sol à 8 m. | Bande au sol de 3 × 1,2 m en travers du regard, couleur du feu. |
| 3 | Clic gauche en visant. | Bras levés, barre de 1,2 s ; le mur s'embrase, flammes en boucle le long de la ligne, trois lumières (de nuit, elles éclairent le sol et les passants) ; au bout de 4 s il s'éteint en fumée et le sol reste noirci une vingtaine de secondes. |
| 4 | **(2 joueurs)** B traverse le mur en courant. | B −6 et en Brûlure (3 s), même s'il passe entre deux vérifications du serveur (toutes les 500 ms). |
| 5 | **(2 joueurs)** B reste dans le mur ; A s'y tient aussi. | B : une blessure par seconde au plus, brûlure ravivée ; A : rien. |
| 6 | Réglage `durationMs = 60000` (N1) : trois murs de suite, `/magie recharges` entre deux. | Au troisième, le plus ancien s'éteint en fumée (deux murs par lanceur). `/magie nettoyer` (rien d'autre au sol) : « Nettoyé : 2 effet(s) retiré(s) du monde. » |
| 7 | Viser un toit à plus de 6 m au-dessus de soi. | « Visez le sol, à portée. » |
| 8 | Zone protégée : viser dedans depuis dehors. | « Une paix sacrée règne en ce lieu : la magie offensive ne vous obéit pas. » |

### 5.3 Nova ardente

| Niveau | Incantation | Recharge | Rayon | Dégâts | En plus |
|---|---|---|---|---|---|
| N1 | 1,1 s | 15 s | 3 m | 10 | — |
| N2 | 1,0 s | 14 s | 3,5 m | 12 | — |
| N3 | 1,0 s | 13 s | 4 m | 14 | recul 4 m/s |
| N4 | 0,9 s | 12 s | 5 m | 16 | recul 5 m/s ; Brûlure 3 s, −3/s |
| N5 | 0,8 s | 10 s | 6 m | 20 | recul 6 m/s ; Brûlure 4 s, −3/s |

| # | Faire | Attendu |
|---|---|---|
| 1 | Clic droit. | Disque de 3 m autour de soi (N1), qui suit les pieds ; pas de réticule. |
| 2 | **(3 joueurs)** B à 2 m, C à 5 m ; clic gauche. | Gerbes de flammes en cercle, anneau de feu qui s'élargit, éclat de lumière, son d'impact ; caméra qui tremble à moins de 6 m ; B −10, C rien, A jamais ; sol noirci 20 s ; A : +25 XP et +10. |
| 3 | **(2 joueurs)** N3. | B repoussé loin de A (4 m/s pendant 0,25 s : un mètre environ, à confirmer). |
| 4 | **(2 joueurs)** N4 ; N5. | B brûle 3 s ; au N5, B touché jusqu'à 6 m. |
| 5 | **(2 joueurs)** B dans le rayon, derrière un Rempart de A. | B épargné. |

## 6. Sorts d'eau

### 6.1 Trait de glace

| Niveau | Incantation | Recharge | Vitesse | Portée | Dégâts | Ralenti | Mouillé |
|---|---|---|---|---|---|---|---|
| N1 | 0,30 s | 3 s | 30 m/s | 25 m | 5 | 25 %, 2 s | 8 s |
| N2 | 0,28 s | 2,8 s | 33 m/s | 28 m | 6 | 30 %, 2,5 s | 9 s |
| N3 | 0,25 s | 2,5 s | 36 m/s | 32 m | 8 | 35 %, 3 s | 10 s |
| N4 | 0,22 s | 2,2 s | 40 m/s | 36 m | 10 | 45 %, 3,5 s | 12 s |
| N5 | 0,20 s | 2 s | 45 m/s | 40 m | 12 | 50 %, 4 s | 14 s |

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** N1 sur B à 10 m. | Éclat blanc rapide (petite sphère bleutée), traînée de vapeur, lueur bleue ; son de glace brisée ; B −5, icônes Ralenti (2 s) et Mouillé (8 s), gouttes sur B vues des proches, givre bref à l'écran ; B marche aux trois quarts de son allure. |
| 2 | **(2 joueurs)** N4. | B à 55 % de son allure, mais il peut encore courir : la course n'est coupée qu'à partir d'une force de 50 % (N5). Le grimoire N4 dit « La cible ne peut plus courir » : écart à me remonter. |
| 3 | **(2 joueurs)** N5. | B à 50 %, course impossible 4 s. |
| 4 | **(3 joueurs)** A (N5) touche B, puis C (N1) le touche pendant ce Ralenti. | Le Ralenti de 50 % reste (jamais cumulé, le plus fort l'emporte). |
| 5 | **(2 joueurs)** B en Brûlure (Boule de feu N4) ; A le touche. | A : « Éteint ! » ; la brûlure de B s'arrête. |

### 6.2 Vague

| Niveau | Incantation | Recharge | Portée | Ouverture | Recul | Renversé | Mouillé | Sol mouillé |
|---|---|---|---|---|---|---|---|---|
| N1 | 1,0 s | 12 s | 4 m | 60° | 3 m/s | — | 10 s | 6 s |
| N2 | 0,95 s | 11 s | 5,5 m | 64° | 4 m/s | — | 11 s | 7 s |
| N3 | 0,9 s | 10 s | 7 m | 70° | 5 m/s | — | 12 s | 8 s |
| N4 | 0,85 s | 9 s | 8,5 m | 76° | 6 m/s | 1,5 s | 13 s | 10 s |
| N5 | 0,8 s | 8 s | 10 m | 80° | 7 m/s | 1,8 s | 14 s | 12 s |

| # | Faire | Attendu |
|---|---|---|
| 1 | Clic droit. | Cône bleu au sol devant soi (4 m au N1), qui suit la caméra. |
| 2 | **(3 joueurs)** B dans le cône, C derrière A ; clic gauche en visant. | Bras levés puis poussés ; gerbes d'eau qui balaient le cône de près au loin, son de vague ; A se tourne dans la direction visée ; B repoussé (court : 0,25 s), Mouillé 10 s, éclat « eau » à l'écran ; C rien. Un reflet d'eau reste au sol devant A (disque de 2 m de rayon, à 2 m devant lui) pendant 6 s. |
| 3 | B, puis A, se tiennent sur le reflet. | Mouillés (6 s), reposé toutes les 4 s tant qu'ils y restent (le lanceur aussi : c'est le sol qui mouille). |
| 4 | Clic gauche sans viser. | La vague part droit devant le personnage. |
| 5 | **(2 joueurs)** N4. | B renversé 1,5 s, icône Renversé, puis « Protégé » 6 s. |
| 6 | **(2 joueurs)** B en Brûlure. | « Éteint ! » chez A. |
| 7 | **(2 joueurs)** B dresse un mur de flammes dans le cône, un autre derrière A ; A lance la Vague. | Le premier s'éteint en Vapeur (voir 11-2), l'autre reste. |
| 8 | **(2 joueurs)** B dans le cône, derrière un Rempart. | Rien pour B. |

### 6.3 Brume

| Niveau | Incantation | Recharge | Portée | Rayon | Durée | Voile | Mouillé de qui s'y tient | Sol mouillé à la fin |
|---|---|---|---|---|---|---|---|---|
| N1 | 1,5 s | 15 s | 15 m | 4 m | 8 s | 0,7 | — | — |
| N2 | 1,4 s | 14 s | 16 m | 5,5 m | 10 s | 0,75 | — | — |
| N3 | 1,3 s | 13 s | 18 m | 7 m | 12 s | 0,8 | 8 s | 8 s |
| N4 | 1,2 s | 12 s | 20 m | 8,5 m | 14 s | 0,85 | 10 s | 10 s |
| N5 | 1,1 s | 11 s | 22 m | 10 m | 16 s | 0,9 | 12 s | 12 s |

| # | Faire | Attendu |
|---|---|---|
| 1 | Clic droit au sol, puis clic gauche. | Disque de 4 m au point visé ; puis nappes de brume réparties sur le disque, vues du dehors, pendant 8 s. |
| 2 | **(2 joueurs)** B entre dans la brume, puis en sort. | Voile à l'écran et flou (`hud_def_blur` à 0,7), posés en moins d'un cinquième de seconde, retirés dès la sortie ; rien d'autre au N1-N2. |
| 3 | **(2 joueurs)** N3, B dedans ; A dedans aussi. | Tous deux Mouillés (8 s, reposé toutes les 4 s) ; A gagne 5 XP au premier mouillé qui n'est pas lui ; à la fin naturelle (12 s), un reflet d'eau du même rayon reste 8 s. |
| 4 | N3 : seconde brume avant la fin de la première (`/magie recharges` entre deux). | La première disparaît, sans laisser de sol mouillé. |
| 5 | **(3 joueurs)** C regarde une brume N5 à 10 m, puis à 50 m. | 12 nappes de près, 5 de loin (une brume N1 n'en a que 3, de près comme de loin). |

## 7. Sorts de terre

### 7.1 Projectile de roche

| Niveau | Incantation | Recharge | Vitesse | Portée | Dégâts | En plus |
|---|---|---|---|---|---|---|
| N1 | 0,50 s | 4 s | 12 m/s | 18 m | 14 | — |
| N2 | 0,47 s | 3,8 s | 13 m/s | 20 m | 17 | — |
| N3 | 0,44 s | 3,5 s | 14 m/s | 22 m | 20 | Chancelant 1,2 s |
| N4 | 0,40 s | 3,2 s | 15 m/s | 25 m | 23 | Chancelant 1,5 s |
| N5 | 0,36 s | 3 s | 16 m/s | 28 m | 26 | Chancelant 1,8 s ; éclats à 2,5 m (50 %) |

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** N1 sur B à 12 m. | Barre de 0,5 s (seul projectile qui en a une, au N1) ; bloc de pierre visible qui tournoie, traînée de poussière ; lent (une seconde pour 12 m) : B peut l'esquiver. Touché : B −14, éclats de roche, son d'impact, caméra qui tremble à moins de 12 m. |
| 2 | **(2 joueurs)** N3. | B chancelle 1,2 s (voir 9-5), puis « Protégé » 6 s. |
| 3 | **(3 joueurs)** N5 sur B, C à moins de 2,5 m de l'impact. | B −26 et chancelant ; C −13. |
| 4 | Lancer en marchant. | Permis, à allure bridée ; ni course ni saut. |

### 7.2 Secousse

| Niveau | Incantation | Recharge | Portée | Rayon | Présage | Dégâts | Contrôle |
|---|---|---|---|---|---|---|---|
| N1 | 1,2 s | 14 s | 14 m | 3 m | 1,4 s | 4 | Chancelant 1,2 s |
| N2 | 1,1 s | 13 s | 15 m | 3,5 m | 1,3 s | 5 | Chancelant 1,4 s |
| N3 | 1,0 s | 12 s | 16 m | 4 m | 1,2 s | 6 | Chancelant 1,5 s |
| N4 | 0,95 s | 11 s | 18 m | 4,5 m | 1,1 s | 7 | Renversé 1,5 s |
| N5 | 0,9 s | 10 s | 20 m | 5 m | 1,0 s | 8 | Renversé 1,8 s |

| # | Faire | Attendu |
|---|---|---|
| 1 | Clic gauche en visant le sol à 10 m. | Genou à terre, main au sol, barre de 1,2 s ; puis anneau couleur terre de 3 m au sol, qui palpite et se remplit en 1,4 s, poussière, craquement. |
| 2 | **(2 joueurs)** B sort du cercle pendant le présage. | Rien pour B. |
| 3 | **(2 joueurs)** B reste dans le cercle. | Au choc : éclats sur le cercle, grondement, caméra qui tremble à moins de 7,5 m ; B −4 et chancelant 1,2 s ; fissure sombre au sol 20 s. |
| 4 | A dans son propre cercle. | Rien pour A. |
| 5 | **(2 joueurs)** N4. | B renversé 1,5 s. |
| 6 | `/magie nettoyer` pendant le présage. | Anneau effacé, aucun choc. |

### 7.3 Rempart

| Niveau | Incantation | Recharge | Portée | Longueur | Épaisseur | Hauteur | Blocs | Durée |
|---|---|---|---|---|---|---|---|---|
| N1 | 1,4 s | 15 s | 10 m | 3 m | 1,2 m | 1,8 m | 2 | 8 s |
| N2 | 1,3 s | 15 s | 11 m | 4 m | 1,2 m | 2,0 m | 3 | 10 s |
| N3 | 1,2 s | 15 s | 12 m | 5 m | 1,3 m | 2,2 m | 3 | 12 s |
| N4 | 1,1 s | 15 s | 13 m | 6 m | 1,4 m | 2,4 m | 4 | 14 s |
| N5 | 1,0 s | 15 s | 14 m | 2 × 4 m en chevron (25°) | 1,4 m | 2,4 m | 6 | 16 s |

| # | Faire | Attendu |
|---|---|---|
| 1 | Clic droit au sol à 6 m ; puis au N5. | Ligne de 3 m face au regard ; au N5, deux bras de 4 m partis du point visé et rabattus vers A. |
| 2 | Clic gauche. | Barre de 1,4 s ; les pierres montent du sol en 0,8 s, poussière, grondement, caméra qui tremble à moins de 15 m. |
| 3 | **(2 joueurs)** B veut passer à travers. | Il ne passe pas. |
| 4 | **(2 joueurs)** B derrière le mur ; A lance une Boule de feu sur lui, puis une Vague, puis une Nova. | La boule s'écrase sur le mur ; ni la vague ni la nova ne touchent B ; les éclats d'un impact ne passent pas non plus. |
| 5 | Viser le sol sous B ; près d'un véhicule ; à un mètre devant soi. | « Quelqu'un ou quelque chose occupe cet endroit : la pierre ne peut s'y dresser. » ; rien consommé. |
| 6 | Second rempart (`/magie recharges`). | Le premier s'enfonce et disparaît, avec poussière et grondement. |
| 7 | Attendre 8 s (N1). | Le rempart s'enfonce et disparaît. |
| 8 | **(2 joueurs)** Réglage `maxPieces = 3` : A dresse un rempart N1 (2 blocs), puis B. | B : « Trop de remparts se dressent déjà dans le royaume. », rien consommé ; A peut remplacer le sien. |
| 9 | Zone protégée : viser dedans. | « Une paix sacrée règne en ce lieu : la magie offensive ne vous obéit pas. » (le Rempart y est refusé comme les sorts offensifs). |

## 8. Utilitaires

### 8.1 Lueur

| Niveau | Incantation | Durée | Forme | Portée de la lumière | En plus |
|---|---|---|---|---|---|
| N1 | 2,5 s | 1 min | dans la main | 4 m | vacille |
| N2 | 2,2 s | 3 min | dans la main | 6 m | plus stable |
| N3 | 2,0 s | 5 min | orbe près de l'épaule | 8 m | mains libres |
| N4 | 1,8 s | 7 min | orbe | 9 m | orbe ancré 5 min (8 m de portée) |
| N5 | 1,5 s | 10 min | orbe | 10 m | couleur au choix ; orbe ancré 10 min |

Recharge : 4 s à tous les niveaux.

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** N1 : clic gauche. | Lumière ambrée dans la main droite, qui vacille sans saccade, vue de B jusqu'à 60 m ; au bout d'une minute : « Votre lueur s'éteint. » |
| 2 | Clic gauche, lumière allumée ; puis `/lueur eteindre` sans lumière. | Elle s'éteint aussitôt, sans incantation ni mana : « Votre lueur s'éteint. » ; puis « Aucune lueur à éteindre. » |
| 3 | `/magie niveau lueur 3`, allumer. | Orbe près de l'épaule droite (petite sphère), qui flotte ; mains libres. |
| 4 | **(2 joueurs)** N4 : clic droit (sphère au point visé), clic gauche. | « L'orbe se fige en ce lieu. » ; 8 de mana ; B voit la lumière et la petite sphère, aucun objet ; un second orbe remplace le premier ; `/lueur dissiper` : « Vos orbes se dissipent. » |
| 5 | N4 : viser plus loin que 8 m ; N3 : `/lueur ancrer`. | « C'est trop loin. » ; « Votre maîtrise de ce sort ne va pas encore jusque-là. » |
| 6 | N5 : grimoire → « Couleur de la lumière » → Clair de lune ; puis `/lueur couleur sylve` ; puis `/lueur couleur`. | « Votre lumière prend la couleur « Clair de lune ». », appliquée à la lumière allumée ; idem « Sylve » ; « Couleurs : ambre, lune, aube, sylve, flamme, arcane ». |
| 7 | N4 : `/lueur couleur lune`. | « Votre maîtrise de ce sort ne va pas encore jusque-là. » |
| 8 | `/lueur couleur rouge`. | « La magie se dérobe (invalid_args). » (le texte prévu, « Cette couleur vous est inconnue. », n'est jamais atteint : à me remonter). |
| 9 | `/lueur danse`. | « Usage : /lueur [ancrer \| couleur <nom> \| eteindre \| dissiper] » |

### 8.2 Murmure, sigils et registre

| Niveau | Incantation | Recharge | Signes | Portée | Mots perdus | Mots lisibles au-dessus des mains | Cercle | Position |
|---|---|---|---|---|---|---|---|---|
| N1 | 6 s | 20 s | 60 | 300 m | 30 % | la moitié | 1 | — |
| N2 | 5,5 s | 18 s | 100 | 1 km | 15 % | un tiers | 1 | — |
| N3 | 5 s | 16 s | 160 | sans limite | 7 % | 4 au plus | 1 | oui |
| N4 | 4,5 s | 14 s | 220 | sans limite | 3 % | 2 au plus | 4 | oui |
| N5 | 4 s | 12 s | 300 | sans limite | aucun | aucun | 8 | oui |

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** A et B face à face, à moins de 3 m : A `/sigil offrir`. | A : « Vous tendez votre sigil. » ; B : fenêtre « Un sigil vous est tendu », champ du nom (24 signes), case « Lui confier mon sigil en retour », compte à rebours de 30 s. |
| 2 | **(2 joueurs)** B nomme A, coche la case, accepte ; A nomme B. | B : « Vous gardez ce sigil sous le nom « … ». » ; A : « Votre sigil a été accepté. », puis fenêtre « Un sigil en retour » ; une fois nommé, mêmes messages croisés. `/sigils` : « Vos sigils (1 / 10) : », « 1. <nom> » et la ligne d'aide. |
| 3 | **(2 joueurs)** `/sigil offrir` à 5 m ; puis offre sans réponse 30 s ; puis B refuse et A retend. | « Personne ne se tient assez près de vous. » ; « L'offre de sigil est restée sans réponse. » ; « Votre sigil a été refusé. », puis « Cette personne vient de refuser votre sigil : attendez n s avant de le lui tendre à nouveau. » (60 s) ; B peut toujours tendre le sien à A. |
| 4 | A, Murmure N1 prêt : clic gauche. | Parchemin : contacts, « Votre cercle : 1 contact(s) au plus », compteur « n / 60 signes », « Joindre sa position : niveau 3 » grisé, « Mana : 12 », boutons « Murmurer » et « Fermer ». Sans contact : « Vous ne gardez encore aucun sigil : échangez-en face à face (/sigil offrir). » |
| 5 | **(3 joueurs)** Envoyer à B ; C à 2 m de A, puis à 5 m. | Incantation de 6 s, runes au-dessus des mains de A ; à 2 m, C lit des mots dorés (la moitié environ au N1) ; à 5 m, seulement des runes. |
| 6 | **(3 joueurs)** À la fin de l'incantation. | A : « Votre murmure a trouvé son chemin. » ; B : parchemin « De <nom> » pendant 15 s, carillon ; C, à moins de 15 m de B : « * ses yeux s'illuminent un bref instant * » et une lueur bleue au visage de B ; au N1, environ un mot sur trois arrive en « … ». |
| 7 | **(2 joueurs)** B ne connaît pas A : A murmure à B. | B lit « Une présence inconnue ». |
| 8 | **(2 joueurs)** B déconnecté ; puis B à plus de 300 m (N1). | « Le lien reste silencieux. 6 de mana vous reviennent. » ; « Le lien ne porte pas si loin. 6 de mana vous reviennent. » |
| 9 | **(2 joueurs)** N3 : cocher « Joindre ma position ». | B : point de passage sur sa carte et « Un point de passage est marqué sur votre carte. » |
| 10 | N1 : `/murmure 1,2 Bonjour` ; `/murmure 9 Bonjour` ; `/murmure Bonjour`. | « Votre cercle ne compte pas autant de contacts à ce niveau. » ; « Ce sigil n'est pas dans votre mémoire. » ; « Usage : /murmure, ou /murmure <n°[,n°…]> <message> ». |
| 11 | **(2 joueurs)** N1 : message de 80 signes accentués. | B reçoit les 60 premiers signes, accents intacts. |
| 12 | `/sigil renommer 1 Aldric` ; `/sigil oublier 1`. | « Sigil renommé : « Aldric ». » ; « Vous oubliez le sigil « Aldric ». » |
| 13 | **(2 joueurs)** `/sigil brouiller`, confirmer ; B murmure à A par l'ancien sigil ; second brouillage. | Fenêtre « Brouiller votre sigil » (coût : 60 de mana) → « Votre sigil se brouille : l'ancien n'existe plus. » ; B : « Le lien reste silencieux. … » ; « Le sort n'est pas encore prêt (n s). » (6 h). |
| 14 | **(2 joueurs)** Avec un registre sur soi, envoyer et recevoir ; l'utiliser. | Pages « À … » et « De … », datées (« Le 29 octobre, à 14h05 »), compteur « n / 200 pages » ; sans registre, rien n'est consigné. « Arracher la page » : « Vous arrachez la page. » Donner le registre à B : B lit les mêmes pages. Un registre neuf : « Ce registre est vierge. » |

## 9. États élémentaires et immunité

Sources : Brûlure (Mur, Boule N4-N5, Nova N4-N5, Roche ardente) ; Mouillé (Trait, Vague, Brume N3+, sol mouillé) ;
Ralenti (Trait, Boue) ; Chancelant (Secousse N1-N3, Roche N3+) ; Renversé (Vague N4+, Secousse N4+) ; Gelé (Gel).

| # | Faire | Attendu |
|---|---|---|
| 1 | **(3 joueurs)** B en Brûlure ; C à 10 m puis à 50 m. | Chez B : icône « Brûlure » et ses secondes, bord de l'écran rougi, une perte chaque seconde, puis plus rien. C : flammes et leur lueur sur B ; à 50 m encore (seul état montré au-delà de 30 m). |
| 2 | **(2 joueurs)** B Mouillé. | Icône « Mouillé » ; gouttes sur B vues des proches ; aucun autre effet. |
| 3 | **(2 joueurs)** B en Brûlure marche sur un sol mouillé (ou entre dans une brume N3). | La brûlure s'éteint, sans « Éteint ! » (règle du sol, pas une combinaison). |
| 4 | **(2 joueurs)** B Ralenti. | Icône « Ralenti » ; allure à (1 − force), jamais sous 35 % ; course coupée à partir d'une force de 50 %. |
| 5 | **(2 joueurs)** B Chancelant. | Démarche ivre, caméra qui tangue, ni course ni saut, poussière sur lui ; s'il incante : « Vous chancelez : impossible d'incanter. » |
| 6 | **(2 joueurs)** B Renversé. | Chute (ragdoll) de la durée du contrôle ; s'il incante : « Vous êtes renversé : impossible d'incanter. » |
| 7 | **(2 joueurs)** B Gelé (11-6). | Figé sur place (le serveur fige aussi le personnage), ni course, ni saut, ni attaque, ni visée ; givre au bord de l'écran, vapeur sur lui ; s'il incante : « Le gel vous fige : impossible d'incanter. » |
| 8 | **(2 joueurs)** B incante une Lueur ; A le fait chanceler (Secousse) ou le renverse (Vague N4). | Incantation de B brisée : « Vous chancelez : impossible d'incanter. » ou « Vous êtes renversé : … » (« La douleur brise votre concentration. » ou « Votre chute brise l'incantation. » si son client le voit le premier) ; mana de B inchangée. |
| 9 | **(2 joueurs)** A touche B d'un Trait de glace (Mouillé 8 s), puis lance une Secousse N1 sur lui (Chancelant 1,2 s), aussitôt un Projectile de roche N3, puis un second Trait de glace. | Seul le chancellement passe ; la roche fait ses −20 sans faire chanceler ; le second trait blesse, ralentit et mouille, sans geler (pas de « Gelé ! ») ; l'icône « Protégé » paraît à la fin du chancellement et dure 6 s ; après elle, un contrôle repasse. |
| 10 | **(2 joueurs)** Pendant « Protégé » : Boule de feu N4, Trait de glace. | Brûlure, Ralenti et Mouillé s'appliquent (seuls les contrôles durs sont bloqués). |
| 11 | **(2 joueurs)** A immobilise B depuis le Registre du Conseil, puis le gèle (Gel). | À la fin du gel, B est libre de nouveau (le gel libère le personnage sans tenir compte du Registre) : à me remonter s'il bouge. |

## 10. Zones au sol et ce que voit un témoin

Une zone n'est envoyée qu'aux joueurs à moins de 150 m, y compris à ceux qui s'en approchent ; le serveur vérifie qui
s'y tient toutes les 500 ms. Effets complets à moins de 30 m de la caméra, simplifiés jusqu'à 150 m, rien au-delà.

| # | Faire | Attendu |
|---|---|---|
| 1 | **(3 joueurs)** A dresse un mur long (réglage `durationMs`) ; C le regarde à 20 m, 100 m, 200 m, puis revient. | 20 m : flammes tous les mètres, lumières ; 100 m : flammes tous les 2,5 m ; 200 m : rien ; en revenant, tout reparaît. |
| 2 | **(3 joueurs)** C à plus de 150 m quand le mur naît, puis s'approche. | C le voit en passant sous 150 m, pas avant. |
| 3 | Réglage `zones.maxActive = 2` : mur, brume, puis secousse. | La troisième : « Trop de sortilèges marquent déjà le sol du royaume. », rien consommé. |
| 4 | **(2 joueurs)** B sur un toit à plus de 2,5 m au-dessus d'une brume N3. | B n'est pas mouillé (à confirmer selon le relief). |
| 5 | `/magie nettoyer` avec un mur, une brume, un sol mouillé, un présage, une boue, une vapeur, un rempart et un orbe ancré. | Tout disparaît ; « Nettoyé : n effet(s) retiré(s) du monde. », n égal au nombre d'effets ; la brume nettoyée ne laisse pas de sol mouillé. |
| 6 | **(3 joueurs)** C à 10 m de A pendant un combat, puis à 50 m, puis à 200 m. | 10 m : particules dans les deux mains, texte d'ambiance au-dessus des têtes, projectiles, impacts, sons. 50 m : une seule main, plus de texte (15 m au plus), effets allégés, sons faibles (rien au-delà de 60 m). 200 m : rien. |
| 7 | **(3 joueurs)** Nova, Vague, Secousse, Rempart vus par C à 100 m, puis à 130 m. | À 100 m : vus, simplifiés. À 130 m : plus aucun effet instantané (gerbes de la nova et de la vague, éclats du choc, poussière du rempart : annoncés à 120 m au plus) ; l'anneau du présage (zone, 150 m) et les pierres du rempart (objets) restent visibles. |
| 8 | **(3 joueurs)** A verrouille B ; C regarde. | C ne voit ni l'anneau ni le frisson. |

## 11. Combinaisons

Une combinaison portée par un projectile (Vapeur par un Trait de glace, Dissipation, Roche ardente) ne se décide qu'à
l'impact : le projectile doit toucher quelque chose au-delà de la zone (sol, mur, joueur). Perdu en bout de course, il
ne déclenche rien. Le grimoire qui s'inscrit est celui du lanceur du sort déclencheur.

| # | Faire | Attendu |
|---|---|---|
| 1 | Grimoire avant toute découverte. | Page « Combinaisons » : « Aucune combinaison découverte : mêlez les éléments, et ces pages s'écriront d'elles-mêmes. » |
| 2 | **(2 joueurs)** Vapeur : B dresse un mur de flammes ; A le balaie d'une Vague. | Le mur s'éteint en fumée ; un nuage blanc le remplace 7 s, sifflement ; A : « Vapeur ! » au-dessus de la barre et, la première fois, « Une combinaison s'inscrit dans votre grimoire : Vapeur. » ; qui s'y tient (lanceur compris) : voile et flou, −1 par seconde. |
| 3 | **(2 joueurs)** Vapeur par un Trait de glace qui traverse le mur et touche le sol derrière. | Même effet ; « Vapeur ! » sans nouvelle inscription. |
| 4 | **(2 joueurs)** Dissipation : B pose une Brume ; A tire une Boule de feu à travers, sur le sol au-delà. | La brume disparaît aussitôt, sans sol mouillé ; « Dissipée ! », souffle. |
| 5 | Boue : A lance une Vague (sol mouillé devant lui), puis une Secousse sur ce sol. | Au choc, le reflet d'eau devient un disque brun du même rayon, éclaboussure, son de vague ; « Boue ! » ; qui y marche (A compris) : Ralenti de 60 % (allure à 40 %, pas de course), reposé toutes les 2 s, encore 1 à 3 s à la sortie ; la boue dure 30 s. |
| 6 | **(2 joueurs)** Gel : B mouillé ; A le touche d'un Trait de glace. | B gelé 2,5 s ; A : « Gelé ! », son de glace ; le trait le mouille de nouveau aussitôt (icône Mouillé) ; « Protégé » 6 s après le gel ; un second trait pendant la protection ne gèle pas. |
| 7 | **(2 joueurs)** Séchage : B mouillé ; A le touche d'une Boule de feu N4. | B −8,5 au lieu de −17, plus de Mouillé, pas de brûlure ; « Séché ! ». Même chose au premier passage dans un Mur de flammes N1 (−3 au lieu de −6, pas de brûlure) et sous une Nova. |
| 8 | **(2 joueurs)** Extinction : B en Brûlure ; Vague ou Trait de glace. | « Éteint ! », plus de brûlure. |
| 9 | **(2 joueurs)** Roche ardente : B dresse un mur ; A lance un Projectile de roche N1 à travers, sur B derrière. | Le bloc s'embrase en entrant dans le mur (traînée de feu, lueur, souffle) ; impact en flammes ; B −14, puis −8 de feu et Brûlure 3 s (−2/s) ; « Roche ardente ! » ; le mur reste. |
| 10 | Le même bloc à travers le mur, sans rien toucher ensuite. | Il flambe en vol (prédiction de chaque client), mais rien n'est décidé : ni « Roche ardente ! » ni inscription. |
| 11 | Grimoire après quelques découvertes ; `/magie fiche`. | Page « Combinaisons » après les sorts : chacune avec « Déclencheur », « Résultat » et deux icônes d'éléments ; « n combinaison(s) restent à découvrir. » ; « Combinaisons découvertes : n / 7 ». |
| 12 | `/magie nettoyer` pendant une vapeur et une boue. | Les deux disparaissent. |

## 12. Effets et sons (noms de GTA à vérifier)

Pour chaque ligne : l'effet se voit-il, est-il à la bonne taille et au bon endroit ? Un nom inconnu de GTA ne rend
simplement rien. Le réglage à corriger est entre parenthèses.

| # | Faire | Attendu |
|---|---|---|
| 1 | Incanter une Boule de feu. | Poing serré `anim@mp_player_intupperknuckle_crunch` / `enter` puis `idle_a` ; flammes dans les mains `core` / `ent_amb_torch_fire` (`spells.boule_de_feu.anims`, `elements.feu.hands`). |
| 2 | Jet d'un projectile. | `weapons@projectile@grenade_str` / `throw_m_fb_stand` (`anims.release`). |
| 3 | Mur de flammes. | Bras levés `anim@mp_player_intuppersurrender` / `enter`, `idle_a`, `exit` ; flammes `ent_amb_torch_fire`, embrasement `ent_sht_flame`, extinction `ent_sht_steam` (`spells.mur_de_flammes.fx`). |
| 4 | Nova ardente. | `anim@mp_player_intcelebrationmale@jazz_hands` / `jazz_hands` (à juger) ; gerbes `ent_sht_flame` ; anneau (marqueur 25) ; tremblement `SMALL_EXPLOSION_SHAKE` (`spells.nova_ardente`). |
| 5 | Être touché. | Geste `anim@mp_player_intupperface_palm` / `idle_a` (à juger) et éclat d'écran selon l'élément : brûlure, eau, givre, terre (`combat.reactions`). |
| 6 | États sur un joueur. | Brûlure `ent_amb_torch_fire` ; Mouillé `ent_sht_water` (incertain) ; Gelé `ent_sht_steam` (faute de givre) ; Chancelant `ent_dst_dust` (incertain), démarche `move_m@drunk@verydrunk`, tremblement `DRUNK_SHAKE` (`states.fx`, `states.stagger`). |
| 7 | Mains de l'eau, de la terre. | `ent_amb_waterfall_splash_p` (incertain) ; `ent_dst_dust` (incertain) (`elements.eau.hands`, `elements.terre.hands`). |
| 8 | Trait de glace. | Traînée `ent_sht_steam`, impact `ent_sht_water` (incertain) (`spells.trait_de_glace.fx`). |
| 9 | Vague, sol mouillé. | Bras poussés `anim@mp_player_intcelebrationmale@bro_love` / `bro_love` (à juger) ; gerbes `ent_sht_water` (incertain) ; reflet : marqueur 1 (`spells.vague.fx`, `wetGround`). |
| 10 | Brume. | Nappes `exp_grd_bzgas_smoke` (incertain) ; filtre `hud_def_blur` (`spells.brume.fx`, `spells.brume.screen`). |
| 11 | Projectile de roche. | Objet `prop_rock_1_b` (taille à juger), traînée `ent_dst_dust`, impact `ent_dst_rocks` (incertain) (`spells.projectile_de_roche`). |
| 12 | Secousse, Rempart. | Genou à terre `amb@world_human_gardener_plant@male@enter`, `@base`, `@exit` (à juger) ; présage : marqueurs 25 et 1, `ent_dst_dust` ; choc `ent_dst_rocks` (`spells.secousse.fx`). |
| 13 | Rempart. | Blocs `prop_rock_4_c` (taille, assise, collision) ; montée par 8 paliers en 0,8 s : si elle saccade, `rise.steps = 0` (blocs d'un coup) ; sur une pente, régler `sink` (`spells.rempart`). |
| 14 | Lueur, Murmure. | `amb@world_human_stand_fire@male@base` / `base` ; `anim@mp_player_intupperair_synth` / `idle_a` ; orbe : marqueur 28 et lumière dynamique ; runes `web/img/runes.png` (`spells.lueur.render`, `ambient.runes`). |
| 15 | Vapeur, Boue, Roche ardente. | Nappes `ent_sht_steam` en boucle au sol (à juger) ; éclaboussure `ent_sht_water` et disque brun (marqueur 1) ; traînée `ent_amb_torch_fire` et impact `ent_sht_flame` (`combos.*`). |
| 16 | Sons. | Fabriqués par l'interface, plus faibles avec la distance, muets au-delà de 60 m : carillon (murmure reçu), souffle (jet, dissipation), impact (boule, roche, nova), extinction (boule éteinte), glace brisée (trait, gel), vague (vague, boue), craquement (présage), grondement (choc, rempart), sifflement (vapeur, séchage, extinction). À juger à l'oreille. |
| 17 | Déposer `web/sounds/whoosh.ogg`, déclarer `sounds.files = { whoosh = 'sounds/whoosh.ogg' }`, `refresh` puis `restart vava_magic`. | Le fichier remplace le souffle fabriqué. Un son natif déclaré dans `sounds.native` (`impact = { name = …, set = … }`, noms à chercher) se joue au point de l'impact. |
| 18 | Deux mages, N1 et N5, lancent le même sort côte à côte. | La différence se voit (taille des flammes et de la lumière) ; Boule de feu : facteur 0,75 contre 1,4. |
| 19 | Trois mages et plusieurs murs de flammes de nuit. | Au plus 24 lumières dessinées et 40 particules en boucle : certaines lumières peuvent manquer ; noter tout clignotement. |

## 13. Triche simple

| # | Faire | Attendu |
|---|---|---|
| 1 | Marteler le clic gauche pendant et après une Boule de feu. | Une seule incantation, une seule dépense ; « Vous incantez déjà. », puis « Laissez la magie retomber un instant. », puis « Le sort n'est pas encore prêt (n s). » |
| 2 | Console `F8` : `lueur eteindre`, puis flèche haut + Entrée une dizaine de fois très vite. | Après six environ : « Doucement : laissez la magie respirer. » (6 demandes d'avance, une de plus par seconde). Même chose avec `sigils`. |
| 3 | Réglage `cooldownMs = 120000` du Rempart N1 : le lancer, se déconnecter, revenir en moins de deux minutes, le relancer. | La roue ne le grise pas (le client a oublié), mais le serveur refuse : « Le sort n'est pas encore prêt (n s). » |
| 4 | **(2 joueurs)** A met B à terre (sorts jusqu'à 0 de vie). B : clic gauche, puis `/lancer`. | Clic gauche sans effet ; « Vous êtes à terre. » |
| 5 | **(2 joueurs)** A lance une Boule de feu sur B à terre ; puis une Vague. | Boule : B ne perd rien, ne brûle pas, aucune ligne au journal. Vague : B est encore mouillé, poussé, et renversé au N4 (le serveur ne vérifie pas l'état à terre pour ces effets) : à juger. |
| 6 | En véhicule : `/lancer`. | « Impossible d'incanter ainsi installé. » |
| 7 | Hors de portée (tous les sorts au N1) : Boule de feu sur B à 25 m ; Mur de flammes visé à 15 m ; verrouiller B à 30 m. | La boule disparaît à 20 m sans dégât ; « Visez le sol, à portée. » ; « Aucune cible en vue. » |
| 8 | Sans mana : `/magie mana` puis cinq Murs de flammes N1 (`/magie recharges` entre chaque). | Quatre murs (24 chacun), le cinquième : « Votre mana est trop faible. », rien consommé. |
| 9 | **(2 joueurs)** B chancelant, renversé ou gelé : clic gauche, `/lancer`. | « Vous chancelez : … », « Vous êtes renversé : … », « Le gel vous fige : … ». |
| 10 | Arme en main : `/lancer`. | Le sort part quand même (la commande de secours ne vérifie pas les mains vides) : à juger. |
| 11 | Un non-mage sans sort (C, ou B après `/magie mage <B> non` et `/magie vider <B>`) : `/lancer boule_de_feu`, Tab, `/sigil brouiller`. | « Vous ignorez ce sort. » ; rien ; « La magie ne vous a jamais répondu. » |
| 12 | B, hors du Conseil : `/magie maitrise`. | « Ces commandes sont réservées au Conseil. » |

## 14. Déconnexion et redémarrage

| # | Faire | Attendu |
|---|---|---|
| 1 | **(3 joueurs)** A se déconnecte pendant l'incantation d'un Murmure, C à 2 m. | Les runes et les mots disparaissent ; B ne reçoit rien. A revient : mana pleine, recharge du Murmure non posée (l'incantation n'a pas abouti), sorts, XP et sigils intacts. |
| 2 | **(2 joueurs)** Réglage `combos.gel.result.durationMs = 30000` : geler B, B se déconnecte, revient. | Aucune erreur en console ; B revient libre, sans icône ni effet. |
| 3 | **(2 joueurs)** B se déconnecte en Brûlure ; recommencer dans une boue. | Plus de ligne `brulure` au journal pour B ; rien ne reste à son retour. |
| 4 | **(2 joueurs)** A dresse un mur long (réglage), un Rempart N5, un orbe ancré, allume une Lueur, puis se déconnecte (`F8` → `quit`). | Le mur brûle jusqu'à sa fin et blesse encore B (journal au nom du personnage de A) ; le rempart tombe à son heure (16 s) ; l'orbe et la Lueur disparaissent aussitôt. |
| 5 | **(2 joueurs)** A se déconnecte pendant qu'une offre de sigil attend la réponse de B. | La fenêtre de B se ferme. |
| 6 | **(2 joueurs)** `restart vava_magic` (tapé d'avance dans la console du serveur) avec : un mur long actif, B dans une brume (voile), un rempart debout, B gelé (réglage), un présage de Secousse en cours, un orbe ancré, A en pleine incantation. | Tout disparaît sur-le-champ chez tous : flammes, lumières, brume et voile, filtre flou, pierres, orbe ; B est libre ; l'incantation de A s'éteint sans rien consommer ; le présage ne frappe pas. Au retour, `module 'vava_magic' v2.6.0 prêt` ; `/magie fiche` : fiches intactes (sorts, XP, sigils, sort prêt) ; mana pleine ; recharges effacées ; aucune pierre ni zone ne reparaît. |
| 7 | Même redémarrage juste après quelques coups. | Les dégâts des dix dernières secondes sont au journal (`vava_magic_damage_log`) ; à confirmer : au plus 50 lignes sont écrites à l'arrêt. |
| 8 | `restart vava_inventory`, puis utiliser le grimoire et le registre. | Les deux objets fonctionnent encore (redéclarés au retour de l'inventaire). |
| 9 | `restart vava_chat`. | Les suggestions `/sort`, `/lancer`, `/lueur`, `/murmure`, `/sigil`… reviennent (et `/magie` pour A). |

## 15. Resmon

Console du client (`F8`) → `resmon 1`, ligne `vava_magic`. Cibles : 0,02 ms au plus au repos, 0,15 ms au plus en
action. Au repos, le module ne fait qu'une recherche toutes les 250 ms ; les boucles par image ne tournent que mode
magie éveillé, en visant, cible verrouillée, pendant un vol, une incantation de projectile, sous un état qui touche
le personnage, ou près d'une lumière, d'une zone qui dessine ou d'une trace.

| # | Situation | Attendu |
|---|---|---|
| 1 | Non mage ; puis mage dont le mode magie dort depuis plus de 20 s, sans lumière, zone ni joueur sous un état à moins de 150 m. | ≤ 0,02 ms. |
| 2 | Mode magie éveillé, sans viser. | Quelques centièmes au plus, ≤ 0,15 ms ; retour à la ligne 1 vingt secondes après la dernière action. |
| 3 | En visant un sort au sol (aperçu dessiné à chaque image). | ≤ 0,15 ms. |
| 4 | Cible verrouillée ; Lueur allumée ; debout dans une brume ou sur un sol mouillé. | ≤ 0,15 ms dans chaque cas ; retour au repos quand cela cesse. |
| 5 | **(2 joueurs)** Combat d'une minute à moins de 30 m : boules de feu, traits, un mur, une brume, une secousse, un rempart, une Lueur allumée. Noter la moyenne et la pointe, chez A et chez B. | ≤ 0,15 ms chez chacun, pointe comprise. C'est la mesure la plus importante du module. |
| 6 | **(3 joueurs)** C regarde ce combat à 100 m, puis à 200 m. | ≤ 0,15 ms à 100 m (effets simplifiés) ; à 200 m, comme au repos. |
| 7 | Une minute après la fin du combat (zones éteintes, traces effacées). | Retour à ≤ 0,02 ms. |

## 16. Ce qu'il faut regarder dans la base

- `vava_magic_damage_log` : `at`, `spell`, `caster_id` et `target_id` (personnages), `kind` (`impact`, `zone`,
  `brulure`), `damage` en points de vie (`8.000` pour −8), position de la cible. Écrit par lots toutes les 10 s, ou dès
  50 lignes. Les lignes de plus de 30 jours sont retirées au démarrage puis chaque jour : vieillir une ligne
  (`UPDATE vava_magic_damage_log SET at = at - 31*86400 WHERE id = <n>`), `restart vava_magic`, la console affiche
  `journal des dégâts : 1 ligne(s) de plus de 30 jours retirée(s)`.
- `vava_magic_sigils` : un sigil de 12 signes par personnage, mage ou non ; changé par `/sigil brouiller`.
- `vava_magic_registers` et `vava_magic_register_pages` : `direction` 1 = envoyé, 2 = reçu ; `contact`, `body`.
- La fiche vit dans `vava_characters.data`, clé `vava_magic:sheet` : `isMage`, `sigil`, `spells` (`{ xp }` par sort),
  `sigils`, `selectedSpell`, `discoveredCombos`, `lightColor`, `register`, `scrambledAt`. Écrite au plus toutes les
  15 s si elle a changé et au départ, puis sauvegardée par le core avec le personnage : `vava_saveall` avant de lire.

## 17. Ce que je ne peux pas avoir vérifié hors jeu

- Tous les noms de GTA (section 12) : animations, particules, objets, marqueurs, filtre `hud_def_blur`, tremblements
  de caméra, démarche ivre. Un nom faux ne rend rien, sans erreur.
- La physique sur le personnage local : recul par `SetEntityVelocity` (0,25 s), chute par `SetPedToRagdoll`, allure
  par `SetPedMoveRateOverride`, figement côté serveur et côté client.
- Le Rempart : objets réseau créés et déplacés par le serveur (fluidité de la montée, collision, assise sur une pente).
- La collision des projectiles avec les joueurs (sonde du client du lanceur) et l'acceptation de l'impact par le
  serveur avec la latence réelle (marges de 2,5 m et de 450 ms).
- Les touches : `MOUSE_BUTTON` et `MOUSE_WHEEL` dans les raccourcis de FiveM, et le nom qu'en donne GTA au grimoire.
- La réplication des state bags (incantation, états, lumières) aux joueurs proches, et les sons Web Audio dans CEF.
- L'ordre des messages quand une blessure et un contrôle dur brisent la même incantation (9-8).

Pour remonter un écart : voir [LISEZMOI.md](LISEZMOI.md) (citer « magie 5.2-4 »).
