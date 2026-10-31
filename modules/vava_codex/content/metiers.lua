--[[
    vava_codex/content/metiers.lua
    Rôle : pages du chapitre « Les métiers » (texte du gardien du lore, T-023). Chaque page dit le jeu tel qu'il est
           codé : une règle qui change dans un module cité fait relire la page (voir les sources en tête de chaque
           page). Aucun nombre réglable en config n'est cité ; seuls les nombres fixés par le jeu le sont (niveaux 0 à
           100, paliers des rangs).
    Dépendances : content/chapters.lua (VavaCodex.seed)
]]

local pages = VavaCodex.seed.pages

-- Sources : vava_skills (touche vava_skills et onglets du livre ; treize compétences et leurs familles ; niveaux et
-- rangs ; XP selon la difficulté ; savoir commun, budget, choix ↑ = ↓, progrès figés sans compétence en ↓ ; pénurie
-- et son onglet ; mentorat : proposition d'un Maître à un joueur proche, acceptée dans le livre, bonus près du maître
-- qui a pratiqué récemment, Renommée décroissante pour un même apprenti ; savoirs : trois leçons espacées, fragments,
-- lignée jusqu'au fondateur ; Arcanes auprès du seul mentor)
pages[#pages + 1] = {
    id = 'apprendre', chapter = 'metiers', order = 10,
    title = 'Apprendre un métier', summary = 'Compétences, rangs, maîtres et apprentis.',
    audience = 'player', permission = '', requires = 'vava_skills',
    body = [==[
Personne ne naît artisan. Un métier s’apprend en le pratiquant, et mieux encore auprès de ceux qui le savent.

## Le livre des compétences
Il s’ouvre avec [[touche:vava_skills]] et compte quatre parties : Compétences, Mentorat, Savoirs et Pénurie.

Treize compétences, en quatre familles :
- *Récolte* : bûcheronnage, minage, herboristerie, pêche, chasse ;
- *Terre* : agriculture ;
- *Transformation* : forge, menuiserie, tissage et couture, tannerie, alchimie, cuisine ;
- *Savoir* : arcanes.

## Niveaux et rangs
Chaque compétence va de 0 à 100. Ses rangs : Novice, Apprenti (20), Compagnon (40), Artisan (60), Maître (80) et
Grand Maître (95). On progresse en pratiquant ; une tâche trop facile pour votre main n’apprend presque plus rien :
il faut viser plus haut.

## Nul ne peut tout pousser
Les premiers points de chaque compétence sont libres ; au-delà, un même budget vaut pour toutes. Dans le livre,
chaque compétence porte l’un de trois choix :
- ↑ : elle progresse ;
- = : elle ne bouge plus, ni en bien ni en mal ;
- ↓ : elle peut s’effacer peu à peu pour payer ce que vous gagnez ailleurs.

Le budget atteint, si aucune compétence n’est en ↓, vos progrès s’arrêtent là. Choisir ce que l’on laisse filer,
c’est choisir ce que l’on demandera aux autres.

Un métier qui manque au royaume progresse plus vite : c’est la *pénurie*, et son onglet dit lesquels.

## Maîtres et apprentis
Un Maître propose, depuis son livre, à quelqu’un qui se tient près de lui de devenir son apprenti ; l’autre accepte
dans le sien. L’apprenti progresse plus vite quand il travaille aux côtés de son maître, et que celui-ci a lui-même
pratiqué peu avant. Le maître y gagne de la *Renommée*, davantage en formant plusieurs personnes qu’en formant
toujours la même.

## Les savoirs
Certaines recettes ne s’apprennent pas seul. On les reçoit en regardant faire celui qui les connaît, en trois
leçons espacées, ou en réunissant les fragments d’un savoir perdu. Le livre garde la lignée de chaque savoir, de
maître en élève, jusqu’à son fondateur.

Quant aux *Arcanes*, on n’y progresse qu’aux côtés de son maître.

## Les métiers
- [[page:recolte]]
- [[page:artisanat]]
- [[page:agriculture]]
]==],
}

-- Sources : vava_gathering (zones et blips de la carte ; panneau : touche vava_gathering_zones, état des zones,
-- « Marquer » ; invite et touche vava_gathering_interact ; mouvement qui interrompt sans rien prendre ; outils tenus
-- en main ; herbes à la main ; usure et bris ; qualité : compétence, outil, vitalité ; palier et provenance de chaque
-- pile ; bandes de vitalité, props épuisés, cicatrice à régénération réduite ; repousse des charges ; saisons :
-- herbes, gibier, poissons, bois, minage sans saison ; pêche : touche tirée, barre de tension, zone qui dérive,
-- décrochage selon le niveau de Pêche ; pistes : viande, parfois une peau ; rien à terre) ; vava_inventory
-- (emplacement Mains) ; vava_crafting (réparation, tannerie). Ne pas nommer les zones d'exemple.
pages[#pages + 1] = {
    id = 'recolte', chapter = 'metiers', order = 20,
    title = 'La récolte', summary = 'Bois, minerai, herbes, poissons et gibier, sur une terre qui se fatigue.',
    audience = 'player', permission = '', requires = 'vava_gathering',
    body = [==[
Forêts, mines, prairies, eaux et pistes de gibier sont marquées sur la carte. Le panneau des zones
([[touche:vava_gathering_zones]]) dit l’état de chacune et pose un repère pour s’y rendre.

## Récolter
Près d’un arbre, d’un filon, d’une plante ou d’une eau, l’invite dit quoi tenir en main ; récoltez avec
[[touche:vava_gathering_interact]]. Bouger interrompt le geste, et rien n’est pris.
- Les outils se tiennent en main, dans l’emplacement *Mains* de la besace : hache, pioche, faucille, couteau,
  canne à pêche.
- Certaines herbes se cueillent à la main ; d’autres demandent la faucille.
- Les outils s’usent et finissent par se briser ; un artisan les répare : voir [[page:artisanat]].

La qualité vient de votre main, de l’outil et de la santé de la terre. Chaque pile garde son palier et sa
provenance : on sait toujours d’où vient un bois.

## Une terre qui se fatigue
Une zone trop prise se voit, souches et filons ternes, et rapporte peu. Poussée à bout, elle garde une cicatrice
qui guérit lentement. Laissez-la souffler et allez plus loin : ce qui a été pris revient avec le temps, et la terre
ménagée se remet bien plus vite que la terre blessée.

Les saisons pèsent sur les herbes, le gibier, le poisson et le bois ; la pierre, elle, ne connaît pas l’hiver.

## Pêche et chasse
- Pêche : canne en main au bord de l’eau, lancez la ligne et attendez que le poisson morde. Tenez alors la
  tension, en gardant l’aiguille dans la zone qui dérive. Un pêcheur novice perd plus de prises qu’un maître.
- Chasse : couteau en main sur une piste, on en tire de la viande, et parfois une peau pour le tanneur.

> À terre, rien ne se récolte.
]==],
}

-- Sources : vava_crafting (stations publiques ou privées, une pièce à la fois, touche vava_crafting_interact ;
-- recettes libres montrées verrouillées sous le niveau, transmises invisibles tant qu'inconnues ; palier choisi par
-- matière et aperçu de qualité ; qualité plafonnée par le niveau ; outil en main et combustible ; se déplacer
-- interrompt ; amorçage du forgeron : charbon, lingots sans outil, marteau à l'établi ; objets signés : outils, armes,
-- armures, bijoux, objets magiques, potions de belle qualité ; créateur, poinçon choisi dès Compagnon, baptême d'un
-- chef-d'œuvre peu après sa création, histoire ; réparation d'un objet signé usé ou brisé à une station qui sert sa
-- recette, niveau suffisant, part des matières, solidité maximale réduite, créateur intact ; leçon aux élèves
-- proches qui ont le niveau ; rien à terre) ; vava_skills (rangs, leçons)
pages[#pages + 1] = {
    id = 'artisanat', chapter = 'metiers', order = 30,
    title = 'L’artisanat', summary = 'Stations, recettes, qualité, poinçon et réparations.',
    audience = 'player', permission = '', requires = 'vava_crafting',
    body = [==[
On façonne aux stations : forge, établi, métier à tisser, alambic, tannerie, fourneau, table d’arcanes. Certaines
sont à tous, d’autres à quelqu’un ; chacune ne travaille qu’une pièce à la fois. Près d’une station,
[[touche:vava_crafting_interact]] ouvre ses recettes.

## Les recettes
- *Libres* : connues par le niveau ; celles qui vous restent hors de portée se montrent verrouillées.
- *Transmises* : elles ne paraissent qu’une fois apprises, par des leçons ou des fragments (voir
  [[page:apprendre]]).

Pour chaque matière, vous choisissez le palier que vous y mettez, et vous voyez la qualité attendue. Mais la
qualité d’une pièce ne dépasse jamais votre propre niveau : de belles matières dans une main novice restent un
ouvrage de novice.

Certaines recettes demandent un outil en main, comme le marteau de forge, ou du combustible : du charbon pour la
forge, du bois de pin pour le fourneau. Se déplacer pendant le travail l’interrompt.

## Les premiers pas d’un forgeron
1. Du charbon de bois, au fourneau.
2. Des lingots, à la forge, sans autre outil que ses mains.
3. Un marteau de forge, à l’établi.
4. Marteau en main, la forge s’ouvre enfin à ses vrais ouvrages.

## Des objets signés
Les outils, les armes, les armures, les bijoux et les plus belles potions sont signés : ils gardent le nom de leur
créateur et, s’il en a choisi un dès le rang de Compagnon, son poinçon. Un chef-d’œuvre peut être baptisé par son
artisan, peu après sa naissance. Chaque réparation s’inscrit à son histoire.

## Réparer
À une station qui sait le faire, un artisan qui connaît assez le métier remet en état un objet signé, usé ou
brisé. Il y met une part des matières, et l’objet perd un peu de sa solidité maximale à chaque fois ; son créateur,
lui, reste le même.

## Transmettre
Réaliser une recette transmise devant des élèves proches, qui ont déjà le niveau voulu, leur vaut une leçon.

> À terre, rien ne se façonne.
]==],
}

-- Sources : vava_farming (parcelles communales ou privées, touche vava_farming_interact près d'un emplacement, d'un
-- puits ou d'un grenier ; semer au palier choisi, arroser au seau tenu en main rempli au puits, fertiliser au compost,
-- récolter plus vite faucille en main, arracher ; humidité, pause à sec, flétrie puis morte, reprise à l'arrosage ;
-- fertilité : récolte, famille de culture, compost du composteur (déchets végétaux des plantes arrachées), jachère ;
-- qualité : graine, compétence, régularité, fertilité ; graines au palier de la récolte ; saisons : pousse lente et
-- terre qui sèche peu l'hiver, terre qui sèche vite l'été ; gel : annoncé par /date et sur la fiche de la plante,
-- avertissement le soir au maître d'une parcelle privée exposée et aux proches d'une parcelle commune exposée, mort
-- des plantes ni couvertes ni résistantes ; couvrir en automne et en hiver (déchets végétaux ou compost) ; chou
-- résistant ; récolte communale dans la besace, grenier ouvert à qui a accès à la parcelle, dépôts et retraits
-- inscrits ; parcelle privée réservée à son propriétaire) ; vava_time (/date, nuits de gel)
pages[#pages + 1] = {
    id = 'agriculture', chapter = 'metiers', order = 40,
    title = 'L’agriculture', summary = 'Semer, arroser, récolter, et laisser la terre se refaire.',
    audience = 'player', permission = '', requires = 'vava_farming',
    body = [==[
Les parcelles sont communales, ouvertes à tous, ou privées. Près d’un emplacement, d’un puits ou d’un grenier,
agissez avec [[touche:vava_farming_interact]].

## Le travail de la terre
- Semer, en choisissant le palier de la graine.
- Arroser, un seau en main, rempli au puits.
- Fertiliser, au compost.
- Récolter, plus vite une faucille en main ; ou arracher ce qui est perdu.

La plante pousse tant que la terre est humide, et s’arrête quand elle sèche. Si personne ne vient, elle flétrit,
puis meurt ; arroser une plante flétrie la fait repartir. Un champ se garde mieux à plusieurs.

## Une terre qui se refait
Chaque récolte fatigue la terre. Changer de famille de culture la repose ; semer encore la même l’épuise. Le
compost, fait au composteur avec les déchets végétaux des plantes perdues, et la jachère la refont.

La qualité vient de la graine, de votre main, d’un arrosage régulier et de la santé de la terre. On récupère
parfois des graines, du même palier que la récolte.

## Les saisons
L’hiver, tout pousse lentement, mais un arrosage tient longtemps ; l’été, la terre sèche vite.

Certaines nuits d’hiver gèlent. [[commande:date]] l’annonce dès le jour (« La nuit sera froide. »), la fiche de la
plante aussi ; le soir venu, le maître d’une parcelle privée menacée et ceux qui se trouvent près d’un champ commun
menacé en sont avertis. Une plante découverte meurt dans la nuit ; le chou résiste au froid. En automne et en
hiver, couvrez vos plantes de déchets végétaux ou de compost.

## Le champ communal
Ce que vous y récoltez va dans votre besace : à chacun d’en porter une part au grenier, où tout dépôt et tout
retrait est inscrit. Une parcelle privée, elle, ne se travaille que par celui à qui elle appartient.
]==],
}
