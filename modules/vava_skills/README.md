# vava_skills — les compétences du royaume

Fondation des métiers d'Eldoria. Treize compétences de 0 à 100, six rangs, et trois idées du lore rendues jouables :
on ne sait pas tout faire (budget de points et rouille), la connaissance se transmet (mentorat, leçons, lignées,
Arcanes de maître à apprenti), et le royaume a besoin de tous les métiers (pénurie). Les modules métiers — récolte,
artisanat, agriculture — **ne calculent jamais l'XP** : ils appellent ce module avec un contexte, et le serveur décide.

Ordre de démarrage : après `vAvA_core` (≥ 0.6.0), `vava_ui` (≥ 1.0.0, polices et textures du livre ; à ne jamais
arrêter sur un serveur ouvert) et `vava_inventory` (≥ 1.4.0), avant les modules métiers.
Facultatifs : `vava_hud` (notifications), `vava_admin` (droits `metiers` et `staff`, journal du Conseil), `vava_chat`
(réponses des commandes dans le chat).

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Compétences et catégories | 13 compétences, 4 catégories | `skills`, `categories` |
| Rangs | Novice 0, Apprenti 20, Compagnon 40, Artisan 60, Maître 80, Grand Maître 95 | `ranks` |
| XP d'un niveau au suivant | `floor(50 + 1,5 × n²)` : 50 au niveau 0, 5 450 au niveau 60, 14 751 au niveau 99 | `xp.base`, `xp.square` |
| Savoir commun | 20 points libres par compétence | `levels.commonKnowledge` |
| Budget | 200 points au-delà du savoir commun, toutes compétences confondues (à augmenter, jamais baisser) | `levels.budget` |
| Rendements décroissants | plein tant que niveau − difficulté ≤ 10 ; décroît jusqu'à 10 % à 40 d'écart | `xp.diminishing` |
| Rouille | la compétence `down` la plus haute paie (`highest`, `recent` ou `random`) | `rust.pick` |
| Pénurie | < 2 personnages actifs (14 j) de rang Compagnon → × 1,5 ; aucune pénurie sous 10 personnages actifs dans le royaume ; recompte toutes les 30 min | `shortages` |
| Mentorat | Maître + 10 h de jeu ; 3 apprentis par compétence ; +50 % à 20 m d'un maître actif depuis < 10 min ; proposition valable 60 s à 10 m | `mentoring` |
| Renommée | 10 % de l'XP bonifiée ; 100 par jour UTC et par compétence ; ÷ 2 tous les 200 points du même apprenti | `mentoring.renown` |
| Arcanes | aucune progression sans son mentor en Arcanes à moins de 30 m | `arcanes.masterRadius`, `skills[].mentoredOnly` |
| Leçons | 3 leçons, 1 h au moins entre deux, élève à moins de 10 m | `lessons` |
| Journal | 180 jours | `logRetentionDays` |

### Modes et plafond (↑ = ↓)

Chaque compétence porte un mode choisi par le joueur dans le livre :

- `up` (↑) : progresse ;
- `keep` (=) : **verrouillée**, ni gain ni perte, même sous le plafond ;
- `down` (↓) : peut s'effacer pour payer un point gagné ailleurs ; ne gagne pas.

Les 20 premiers points de chaque compétence sont libres. Au-delà, le total est borné par le budget : quand il est
atteint, chaque point gagné en `up` retire un point à une compétence `down` (jamais sous le savoir commun). Sans
compétence `down`, l'XP se fige juste sous le seuil : rien n'est perdu, le joueur est prévenu une fois.

### Progression

`addXp(source, { skill, source, difficulty, amount })` : `amount` (défaut 10, au plus `xp.maxPerAction`) ×
rendement (difficulté) × pénurie × bonus de mentorat, borné à `xp.maxGainPerAction`. Puis autant de passages de
niveau que l'XP le permet, chacun soumis au plafond. Le joueur reçoit la vue de la compétence (`vava_skills:skill`) et
une notification au passage de niveau ou de rang.

### Mentorat et Renommée

Un Maître propose depuis le livre à un joueur à portée (comptes différents : une license, un compte) ; la proposition
arrive chez l'autre (notification + livre), expire au bout d'une minute. L'apprenti gagne le bonus quand il pratique
près de son maître **et** que le maître a pratiqué la compétence récemment : un maître qui travaille à côté de son
apprenti. La Renommée du maître croît avec l'XP bonifiée de ses apprentis, avec un plafond journalier et un rendement
décroissant par apprenti : former dix personnes rapporte plus que former dix fois la même.

### Savoirs

Une recette (`vava_skills:recipes`, déclarée par l'artisanat) est **libre** (connue par le niveau) ou **transmise**
(`transmission = true`). Une recette transmise s'apprend :

- par **leçons** : celui qui la connaît la réalise devant l'élève (l'artisanat appelle `recordLesson` au moment où la
  recette est produite) ; trois leçons espacées d'au moins une heure, du même professeur ou non ;
- par **fragments** (savoirs perdus) : la recette déclare `fragments = { … }` ; chaque objet-fragment consommé appelle
  `addFragment` ; la recette est apprise quand tous sont réunis ;
- de la main d'un **fondateur** ou du Conseil.

Chaque apprentissage garde son professeur (`taught_by` : celui de la leçon qui achève) : la lignée d'un savoir se
remonte depuis le livre jusqu'au fondateur.

## Base de données (sql/0001_skills.sql)

`vava_skills_skills` (une ligne par compétence pratiquée : niveau, XP, mode, Renommée, dernière pratique),
`vava_skills_mentorships` (en cours et terminés), `vava_skills_recipes` (recettes transmises connues, professeur),
`vava_skills_lessons` (une ligne par leçon), `vava_skills_fragments`, `vava_skills_log`. Les fiches des personnages en
jeu vivent en mémoire et s'écrivent par lots toutes les 10 s et au départ ; leçons, mentorats, fondateurs et journal
s'écrivent aussitôt. Les propositions de mentorat ne sont jamais écrites.

## Pour les modules métiers

```lua
local skills = exports.vava_skills
-- une récolte réussie
local ok, result = skills:addXp(source, { skill = 'bucheronnage', source = 'chene', difficulty = 25, amount = 12 })
-- une recette d'artisanat
if not skills:knowsRecipe(source, 'epee_courte') then return false, 'recette_inconnue' end
local level = skills:getLevel(source, 'forge')
-- … produire l'objet, puis : les élèves présents reçoivent une leçon
for _, student in ipairs(studentsNearby) do skills:recordLesson(source, student, 'epee_courte') end
```

Exports complets, hooks (`vava_skills:xp` annulable, `levelChanged`, `mentorship`, `recipeLearned`) et registres :
`docs/api.md`, section `vava_skills`.

## Conseil

- `vava_fondateur <joueur> <compétence> <niveau> [recette ...]` — console ou droit `staff` : nomme un fondateur (niveau
  hors des règles de progression, recettes transmises initiales).
- `/metiers niveau <joueur> <compétence> <niveau>`, `/metiers recette <joueur> <recette>`, `/metiers voir <joueur>` —
  droit `metiers` (Sénéchal), ou ACE `metiers.admin` sans vava_admin.

Toute action est inscrite au journal du module et, avec vava_admin, au Registre du Conseil.

## Livre des compétences (client)

Touche `K` (réglable dans Paramètres > Raccourcis > FiveM). Quatre onglets : Compétences (budget, modes ↑ = ↓, barres
d'XP, pénurie, mentor et apprentis), Mentorat (propositions reçues, maîtres, apprentis, proposer à un joueur proche),
Savoirs (recettes connues et lignées, apprentissages en cours), Pénurie. Le client n'a aucune donnée propre : la fiche
est demandée au serveur à chaque ouverture, les évènements ciblés la tiennent à jour. Polices, grain, papier et coins de
laiton viennent de `vava_ui` (`nui://vava_ui/…`). Rendu hors jeu : `web/index.html?tab=competences` (ou `mentorat`,
`savoirs`, `penurie`) dans un navigateur, depuis le dépôt (option `--allow-file-access-from-files` pour les polices),
avec les données simulées de `web/dev/devmock.js` (jamais livré).

## Tests en jeu

1. **Progression** : `vava_fondateur 1 forge 0` puis, en passant la forge en ↑ dans le livre, une action d'un module
   métier (ou, en attendant, un `addXp` depuis une ressource de test) : l'XP monte, niveau 1 à 50 XP, notification.
2. **Verrouillage** : compétence en = → aucune progression, message « verrouillée » une fois par 30 s.
3. **Plafond** : trois compétences à 100, 100 et 60 (`/metiers niveau`), aucune en ↓ → l'XP se fige, message
   « plafond atteint » ; passer l'une en ↓ → le point gagné en ↑ lui est retiré (journal `rust`).
4. **Rendements** : niveau 60, action de difficulté 10 → 10 % de l'XP.
5. **Pénurie** : seul joueur du serveur → tous les métiers en pénurie, × 1,5 ; onglet Pénurie.
6. **Mentorat** : un Maître (≥ 80 et 10 h de jeu) propose à un joueur à 10 m ; l'autre accepte dans la minute ;
   bonus +50 % seulement si le maître a pratiqué depuis moins de 10 min et se tient à 20 m ; Renommée du maître ;
   rupture par l'un ou l'autre ; proposition expirée au bout de 60 s.
7. **Arcanes** : sans mentor en Arcanes à portée, aucune XP (« ne progresse qu'auprès de votre maître ») ; avec son
   mentor à 30 m, elle monte.
8. **Leçons** : une recette `transmission` (registre) connue du professeur ; trois réalisations devant l'élève (1 h
   d'écart, ou `lessons.minIntervalMs` abaissé pour l'essai) ; la recette apparaît dans Savoirs avec sa lignée.
9. **Fragments** : deux objets-fragments consommés → recette apprise, source « fragments ».
10. **Départ et retour** : se déconnecter en cours de progression ; au retour, niveaux, XP et modes sont ceux de la
    dernière seconde (écriture au départ) ; `restart vava_skills` en cours de partie reprend les fiches des joueurs
    présents.
