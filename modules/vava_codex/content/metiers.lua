--[[
    vava_codex/content/metiers.lua
    Rôle : pages du chapitre « Les métiers » (texte provisoire, sobre : le texte définitif est celui du gardien du
           lore). Chaque page dit le jeu tel qu'il est codé : une règle qui change dans un module cité fait relire la
           page (voir les sources en tête de chaque page). Aucun nombre réglable en config n'est cité ; seuls les
           nombres fixés par le jeu le sont (niveaux 0 à 100, paliers des rangs).
    Dépendances : content/chapters.lua (VavaCodex.seed)
]]

local pages = VavaCodex.seed.pages

-- Sources : vava_skills (touche vava_skills et onglets du livre ; treize compétences et leurs familles ; niveaux et
-- rangs ; XP selon la difficulté ; budget, choix ↑ = ↓ ; pénurie ; mentorat, Renommée ; savoirs : leçons,
-- fragments, lignée ; Arcanes auprès du mentor)
pages[#pages + 1] = {
    id = 'apprendre', chapter = 'metiers', order = 10,
    title = 'Apprendre un métier', summary = 'Compétences, rangs, maîtres et apprentis.',
    audience = 'player', permission = '', requires = 'vava_skills',
    body = [==[
Personne ne naît artisan. Un métier s’apprend en le pratiquant, et mieux encore auprès de ceux qui le savent.

## Le livre des compétences
Il s’ouvre avec [[touche:vava_skills]] et compte quatre parties : Compétences, Mentorat, Savoirs, Pénurie.

Treize compétences, en quatre familles :
- *Récolte* : bûcheronnage, minage, herboristerie, pêche, chasse ;
- *Terre* : agriculture ;
- *Transformation* : forge, menuiserie, tissage et couture, tannerie, alchimie, cuisine ;
- *Savoir* : arcanes.

## Niveaux et rangs
Chaque compétence va de 0 à 100. Les rangs : Novice, Apprenti (20), Compagnon (40), Artisan (60), Maître (80) et
Grand Maître (95). On progresse en pratiquant ; une tâche trop facile n’apprend presque plus rien.

## Nul ne peut tout pousser
Les premiers points de chaque compétence sont libres ; au-delà, un même budget vaut pour toutes. Chaque compétence
porte l’un de trois choix :
- ↑ : elle progresse ;
- = : elle est verrouillée ;
- ↓ : elle peut s’effacer pour payer un point gagné ailleurs.

Un métier rare dans le royaume progresse plus vite : c’est la *pénurie*.

## Maîtres et apprentis
Un Maître propose, depuis son livre, à un joueur proche de devenir son apprenti. L’apprenti progresse plus vite
quand il travaille près de son maître et que celui-ci a pratiqué peu avant. Le maître y gagne de la Renommée,
davantage en formant plusieurs personnes.

## Les savoirs
Certaines recettes ne s’apprennent qu’en regardant faire celui qui les connaît, en trois leçons espacées, ou en
réunissant les fragments d’un savoir perdu. Le livre garde la lignée de chaque savoir jusqu’à son fondateur. Les
Arcanes ne progressent qu’auprès de son mentor.

## Les métiers
- [[page:recolte]]
- [[page:artisanat]]
- [[page:agriculture]]
]==],
}

-- Sources : vava_gathering (zones et carte, panneau : touche vava_gathering_zones, invite et touche
-- vava_gathering_interact, mouvement qui interrompt, outils tenus en main, usure, qualité et provenance, fatigue et
-- cicatrice des zones, repousse, saisons, pêche à la tension, chasse au couteau, rien à terre) ;
-- vava_inventory (emplacement Mains) ; vava_crafting (réparation)
pages[#pages + 1] = {
    id = 'recolte', chapter = 'metiers', order = 20,
    title = 'La récolte', summary = 'Bois, minerai, herbes, poissons et gibier, sur une terre qui se fatigue.',
    audience = 'player', permission = '', requires = 'vava_gathering',
    body = [==[
Forêts, mines, prairies, eaux et pistes de gibier sont marquées sur la carte. Le panneau des zones
([[touche:vava_gathering_zones]]) dit leur état et pose un repère.

## Récolter
Près d’un arbre, d’un filon, d’une plante ou d’une eau, l’invite dit quoi tenir en main ; récoltez avec
[[touche:vava_gathering_interact]]. Bouger interrompt le geste.
- Les outils se tiennent en main (emplacement Mains de la besace) : hache, pioche, faucille, couteau, canne.
- Certaines herbes se cueillent à la main.
- Les outils s’usent et finissent par se briser ; un artisan les répare : voir [[page:artisanat]].

La qualité vient de la main, de l’outil et de la santé de la terre ; chaque pile garde son palier et sa provenance.

## Une terre qui se fatigue
Une zone trop prise se voit (souches, filons ternes) et rapporte peu. Poussée à bout, elle garde une cicatrice qui
guérit lentement : laissez-la souffler et allez plus loin. Ce qui a été pris revient avec le temps. Les saisons
pèsent sur les herbes, le gibier, le poisson et le bois.

## Pêche et chasse
- Pêche : lancer la ligne, attendre la touche, puis tenir la tension en gardant l’aiguille dans la zone. Un pêcheur
  novice perd plus de prises qu’un maître.
- Chasse : couteau en main sur une piste ; on en tire de la viande, et parfois une peau.

> À terre, rien ne se récolte.
]==],
}

-- Sources : vava_crafting (stations publiques ou privées, une pièce à la fois, touche vava_crafting_interact,
-- recettes libres ou transmises, palier de chaque matière et qualité attendue, plafond de qualité, outil en main et
-- combustible, premiers pas du forgeron, signature : créateur, poinçon dès Compagnon, nom d'un chef-d'œuvre,
-- histoire des réparations, réparation : part des matières et solidité maximale, leçon aux élèves proches, rien à
-- terre) ; vava_skills (rangs, leçons)
pages[#pages + 1] = {
    id = 'artisanat', chapter = 'metiers', order = 30,
    title = 'L’artisanat', summary = 'Stations, recettes, qualité, poinçon et réparations.',
    audience = 'player', permission = '', requires = 'vava_crafting',
    body = [==[
On façonne aux stations : forge, établi, métier à tisser, alambic, tannerie, fourneau, table d’arcanes. Elles sont
publiques ou privées, et ne travaillent qu’une pièce à la fois. Près d’une station, [[touche:vava_crafting_interact]]
ouvre ses recettes.

## Les recettes
- Libres : connues par le niveau, montrées verrouillées tant qu’il manque.
- Transmises : par des leçons ou des fragments, voir [[page:apprendre]].

On choisit le palier de chaque matière et l’on voit la qualité attendue. La qualité ne dépasse jamais son propre
niveau. Certaines recettes demandent un outil en main (le marteau de forge) ou du combustible (du charbon pour la
forge, du bois de pin pour le fourneau).

## Les premiers pas d’un forgeron
1. Du charbon au fourneau.
2. Des lingots à la forge.
3. Un marteau à l’établi : la forge s’ouvre alors vraiment.

## Des objets signés
Un objet garde son créateur et, dès le rang Compagnon, son poinçon. Un chef-d’œuvre peut recevoir un nom peu après
sa naissance. L’objet garde aussi l’histoire de ses réparations.

## Réparer
À la station, une réparation demande une part des matières, et l’objet perd un peu de sa solidité maximale à chaque
fois.

Réaliser une recette transmise devant des élèves proches leur vaut une leçon.

> À terre, rien ne se façonne.
]==],
}

-- Sources : vava_farming (parcelles communales ou privées, touche vava_farming_interact, semer, arroser au seau rempli
-- au puits, compost, récolte et faucille, arracher, humidité, flétrissement, fatigue de la terre et familles de
-- culture, composteur, jachère, qualité, graines récupérées, saisons, gel annoncé par /date et prévenu le soir,
-- couverture, chou, récolte communale dans la besace, grenier inscrit, parcelle privée)
pages[#pages + 1] = {
    id = 'agriculture', chapter = 'metiers', order = 40,
    title = 'L’agriculture', summary = 'Semer, arroser, récolter, et laisser la terre se refaire.',
    audience = 'player', permission = '', requires = 'vava_farming',
    body = [==[
Les parcelles sont communales (à tous) ou privées. Près d’un emplacement, d’un puits ou d’un grenier, agissez avec
[[touche:vava_farming_interact]].

## Le travail de la terre
- Semer, en choisissant le palier de la graine.
- Arroser, avec un seau tenu en main et rempli au puits.
- Fertiliser au compost.
- Récolter, plus vite avec une faucille ; ou arracher.

La plante pousse tant que la terre est humide et s’arrête à sec. Si personne ne vient, elle flétrit puis meurt ;
arroser une plante flétrie la fait repartir.

## Une terre qui se refait
Chaque récolte fatigue la terre. Changer de famille de culture la repose ; la même famille l’épuise. Le compost
(fait au composteur avec des déchets végétaux) et la jachère la refont.

La qualité vient de la graine, de la main, d’un arrosage régulier et de la terre. On récupère parfois des graines.

## Les saisons
Tout pousse lentement l’hiver, mais l’arrosage tient ; l’été sèche vite. Certaines nuits d’hiver gèlent :
[[commande:date]] l’annonce, et les cultivateurs concernés sont prévenus le soir. Couvrir une plante en automne ou
en hiver la protège (déchets végétaux ou compost) ; le chou résiste au froid.

## Le champ communal
Sa récolte va dans votre besace : à chacun d’en porter une part au grenier, où tout dépôt et tout retrait est
inscrit. Une parcelle privée n’est travaillée que par celui à qui elle appartient ; les autres s’y entendent dire
qu’elle ne leur appartient pas.
]==],
}
