--[[
    vava_codex/content/premiers_pas.lua
    Rôle : pages du chapitre « Premiers pas » (texte du gardien du lore, T-023). Chaque page dit le jeu tel qu'il est
           codé : une règle qui change dans un module cité fait relire la page (voir les sources en tête de chaque
           page). Aucun nombre réglable en config n'est cité (durées, distances, quantités) ; les touches et commandes
           sont citées par leur nom au registre `core:commands`.
    Dépendances : content/chapters.lua (VavaCodex.seed)
]]

local pages = VavaCodex.seed.pages

-- Sources : lore (aucune monnaie, réserves communes, accueil des nouveaux) ; vava_skills (budget de compétences) ;
-- vava_crafting (hache : lingot de fer et bois de chêne ; ragoût : viande de lièvre et sauge ; potion de soin :
-- herbes) ; vava_arrival (kit.items sans les quantités, kit.perAccount : « d'ordinaire ») ; vava_codex (touche codex,
-- trois onglets, commandes composées et lancées) ; vava_inventory (touche vava_inventory) ; vava_skills (touche
-- vava_skills) ; vava_time (/date) ; vava_chat (texte sans commande : hors du rôle)
pages[#pages + 1] = {
    id = 'bienvenue', chapter = 'premiers_pas', order = 10,
    title = 'Vivre à Eldoria', summary = 'Une cité sans pièce, où chacun a besoin des autres.',
    audience = 'player', permission = '', requires = '',
    body = [==[
Bienvenue, voyageur. Eldoria ne connaît ni pièce ni échoppe : ce dont on a besoin, on le troque, on le reçoit pour
un service rendu, ou on le prend dans les réserves communes, que chacun remplit à son tour.

Personne ici ne sait tout faire. Le forgeron attend le minerai du mineur et le bois du bûcheron ; le cuisinier, la
viande du chasseur et les herbes de l’herboriste ; l’alchimiste, ces mêmes herbes pour ses potions. Chacun apprend
son métier auprès de ceux qui le savent déjà, et l’enseigne un jour à son tour.

## Votre arrivée
D’ordinaire, le nouveau venu trouve dans sa besace un peu de pain et d’eau, de quoi tenir un soir. Pour la suite,
allez vers les autres : ici, on ne vous demandera pas d’où vous venez, seulement ce que vous savez faire, ou ce que
vous voulez apprendre.

> Vous croisez quelqu’un qui arrive, l’air perdu ? Montrez-lui le chemin : vous étiez à sa place.

## Ce livre
Le Codex s’ouvre avec [[touche:codex]]. Il a trois onglets :
- *Lecture* : ces pages, à lire dans l’ordre ou au gré de vos besoins ;
- *Commandes* : chaque commande qui vous est ouverte, que l’on compose et que l’on lance d’ici ;
- *Touches* : les touches du royaume, telles que vous les avez liées.

## Vos premiers gestes
- Votre besace : [[touche:vava_inventory]].
- Le livre de vos compétences : [[touche:vava_skills]].
- L’heure, la saison et le ciel : [[commande:date]].
- Ce qui s’écrit dans le chat sans commande est dit hors du rôle : voir [[page:se_parler]].

## Pour aller plus loin
- [[page:troquer]]
- [[page:faim_soif]]
- [[page:apprendre]]
- [[page:conseil]]
]==],
}

-- Sources : vava_chat (touche vava_chat_ouvrir ; onglets Général, Actions et conversations privées ; texte sans
-- commande dans Général : hors du rôle, lu des proches, numéro devant chaque message hors du rôle ; /me et /do, lus
-- des proches et montrés au-dessus de la tête ; /mp par numéro, /r ; /ooc, /mp et /staff gardés pour la modération,
-- /me et /do non) ; vava_voice (activation dans les paramètres du jeu, touche de parole de GTA, quatre portées et
-- touche vava_voice_portee, cercle au sol vu du seul joueur, zones où la voix porte plus ou moins) ; vava_health
-- (à terre : chuchoter ou parler) ; vava_magic (Murmure)
pages[#pages + 1] = {
    id = 'se_parler', chapter = 'premiers_pas', order = 20,
    title = 'Se parler', summary = 'Le chat, les gestes, les messages privés et la voix.',
    audience = 'player', permission = '', requires = 'vava_chat',
    body = [==[
À Eldoria, on se parle de vive voix et par gestes, face à face. Le chat sert aussi : il a ses usages.

## Le chat
Il s’ouvre avec [[touche:vava_chat_ouvrir]]. Ce que vous écrivez sans commande dans l’onglet Général est dit hors
du rôle, et seuls ceux qui se tiennent près de vous le lisent.
- [[commande:me]] : un geste de votre personnage, lu des proches et montré un instant au-dessus de sa tête.
- [[commande:do]] : ce qui se voit ou s’entend autour de vous, « la porte est close », « une odeur de pain chaud ».
- [[commande:mp]] : un message privé, hors du rôle, à quelqu’un désigné par son numéro ; ce numéro précède chacun de
  ses messages hors du rôle.
- [[commande:r]] : répondre au dernier message privé reçu.

Chaque conversation privée a son onglet, où l’on écrit sans commande. L’onglet Actions ne montre que les gestes et
les descriptions.

> Les messages hors du rôle et les messages privés sont gardés quelques jours, pour la modération. Les gestes et les
> descriptions ne le sont pas.

## La voix
Pour être entendu, activez le chat vocal dans les paramètres du jeu ; on parle en maintenant la touche de parole,
d’ordinaire [[N]].

Quatre portées : *Chuchoter*, *Parler*, *Crier* et *Déclamer*. [[touche:vava_voice_portee]] passe de l’une à la
suivante ; un cercle au sol, que vous seul voyez, montre alors jusqu’où porte votre voix. Certains lieux la portent
plus loin, d’autres l’étouffent.

À terre, on ne peut que chuchoter ou parler : voir [[page:a_terre]].

## Au loin
Dans le rôle, on ne parle qu’à ceux qui sont là. Pour joindre quelqu’un, on va le trouver, on lui fait porter un
mot par un ami, ou l’on convient d’un lieu et d’une heure. Seule une magie, le *Murmure*, porte la parole au loin,
et elle ne répond pas à tous : voir [[page:magie]].
]==],
}

-- Sources : vava_inventory (fiche d'objet au survol : palier, provenance, créateur, poinçon, histoire ; place et
-- poids de la besace ; jeter par glisser hors de la fenêtre ou clic droit « Jeter » ; sac au sol visible des proches,
-- ouvert avec la besace tout près, ramassé d'un double-clic par quiconque, durée de vie, perdu au redémarrage ; objet
-- tenu en main visible) ; vava_crafting (objets signés, poinçon, histoire des réparations) ; vava_gathering (truites) ;
-- vava_health (relever) ; vava_skills (enseigner) ; vava_farming (grenier commun, dépôts et retraits inscrits).
-- Décision 9 de la spec T-023 : rien du troc face à face (T-030), aucun prix, aucun don à distance.
pages[#pages + 1] = {
    id = 'troquer', chapter = 'premiers_pas', order = 30,
    title = 'Troquer et partager', summary = 'Ici rien ne s’achète : on donne, on rend service, on partage.',
    audience = 'player', permission = '', requires = 'vava_inventory',
    body = [==[
Ici, nul ne compte en pièces. Ce qui vaut, c’est ce que l’on sait faire et ce que l’on est prêt à donner. On
s’entend de vive voix : trois truites contre une hache réparée, une journée aux champs contre un ragoût, une leçon
contre un coup de main.

## Ce que vaut un objet
Un objet vaut par sa qualité, sa provenance et la main qui l’a façonné. Survolez-le dans la besace : sa fiche dit
son palier, d’où il vient et, pour un objet signé, qui l’a fait, son poinçon et l’histoire de ses réparations.
Demandez qui l’a fait : c’est souvent le début d’une rencontre.

La besace a sa place et son poids : on n’y porte pas tout, et ce que l’on ne peut emporter, un autre en a peut-être
besoin.

## Donner un objet
1. Ouvrez votre besace ([[touche:vava_inventory]]).
2. Faites glisser l’objet hors de la fenêtre, ou choisissez « Jeter » d’un clic droit : un sac se pose à vos pieds,
  visible de ceux qui sont près.
3. L’autre ouvre sa besace tout près du sac, et ramasse l’objet d’un double-clic.

> Un sac ne reste pas indéfiniment au sol, et il disparaît quand le royaume redémarre. Quiconque passe peut le
> ramasser : ne posez que devant celui qui prend.

L’usage veut qu’on annonce le don d’un [[commande:me]] et qu’on attende que l’autre ait pris. Ce que l’on tient en
main, chacun le voit : montrer l’outil que l’on offre fait partie de l’échange.

## Rendre service
Un service vaut bien un objet :
- réparer un outil usé : [[page:artisanat]] ;
- relever un blessé : [[page:a_terre]] ;
- enseigner ce que l’on sait : [[page:apprendre]] ;
- porter une part de sa récolte au grenier commun.

## Les réserves communes
Le grenier du champ communal est à tous : chacun y dépose, chacun y prend, et chaque dépôt comme chaque retrait y
est inscrit. Voir [[page:agriculture]].
]==],
}

-- Sources : vava_needs (deux besoins et leurs médaillons ; baisse en jeu seulement, ni hors connexion ni à la
-- sélection, plus vite à la course ; un message à chaque palier franchi vers le bas ; besoin critique : endurance
-- réduite ; besoin épuisé : blessure jusqu'à la mise à terre ; figés à terre ; geste d'un instant, marche possible ;
-- refus quand on est rassasié) ; vava_inventory (double-clic, ceinture : touche vava_inventory_slot) ; vava_farming
-- (carotte, chou : nourriture) ; vava_crafting (ragoût au fourneau : viande de la chasse et herbe) ; vava_gathering
-- (chasse, herboristerie). Les poissons et la viande crue ne nourrissent pas : la page ne dit pas que la pêche
-- nourrit. Décision 10 de la spec T-023 : ni puits ni fontaine pour boire (T-130), l'eau se partage.
pages[#pages + 1] = {
    id = 'faim_soif', chapter = 'premiers_pas', order = 40,
    title = 'La faim et la soif', summary = 'Manger et boire, et pourquoi il faut les autres pour cela.',
    audience = 'player', permission = '', requires = 'vava_needs',
    body = [==[
Deux besoins vous tiennent : la faim et la soif. Chacun a son médaillon, qui se vide à mesure qu’ils se creusent.

## Comment ils baissent
Ils baissent avec le temps passé dans le royaume, jamais en votre absence ni pendant le choix du personnage, et
plus vite quand vous courez. Un message vous prévient quand l’un d’eux devient bas, puis critique, puis épuisé.
- Un besoin critique coupe le souffle : vous vous essoufflez bien plus vite.
- Un besoin épuisé blesse, peu à peu, jusqu’à mettre à terre : voir [[page:a_terre]].
- À terre, la faim et la soif ne bougent plus.

## Manger et boire
Double-cliquez l’objet dans la besace, ou glissez-le à votre ceinture et servez-vous-en d’une touche
([[touche:vava_inventory_slot]]). Le geste dure un instant, et l’on peut marcher pendant ce temps. Rassasié, on ne
peut plus rien avaler : rien n’est gaspillé.

## D’où vient la nourriture
Du travail des autres. Le cultivateur tire des légumes de ses champs ; le cuisinier mijote au fourneau la viande
du chasseur et les herbes de l’herboriste. Qui ne sait rien de tout cela demande, troque ou rend service : voir
[[page:troquer]].

L’eau se partage comme le reste : une outre offerte au bon moment ne s’oublie pas. Et un repas pris ensemble est
la meilleure façon d’apprendre qui, dans le royaume, sait faire quoi.
]==],
}

-- Sources : vava_health (récupération de GTA coupée ; mise à terre ; relever : touche vava_health_assist, tout près,
-- geste de quelques secondes, distance revérifiée à la fin, relevé avec peu de vie ; barre de la relève sans le nom
-- du soignant ; rendre l'âme : touche vava_health_giveup maintenue, après un délai montré à l'écran, lieu de soins le
-- plus proche, vie partielle ; porté d'office plus tard ; déconnexion ou changement de personnage : retour à terre
-- avec le temps restant ; à terre : ni objet, ni récolte, ni artisanat, ni agriculture, aucun sort reçu ni lancé,
-- voix limitée, besoins figés ; soins par objet) ; vava_crafting (potion de soin à l'alambic, faite d'herbes) ;
-- vava_admin (/signaler)
pages[#pages + 1] = {
    id = 'a_terre', chapter = 'premiers_pas', order = 50,
    title = 'À terre et soins', summary = 'Personne ne se relève seul.',
    audience = 'player', permission = '', requires = 'vava_health',
    body = [==[
La vie ne remonte pas seule. Gravement blessé, on ne meurt pas : on tombe *à terre*, et l’on y reste jusqu’à ce
que quelqu’un vienne.

## Relever quelqu’un
Approchez-vous tout près de la personne à terre et appuyez sur [[touche:vava_health_assist]]. Le geste dure
quelques secondes : restez à ses côtés jusqu’au bout. Elle se relève, mais affaiblie, et aura besoin de soins.

Celui qu’on relève voit le geste avancer, sans savoir qui se penche sur lui.

## Si personne ne vient
Passé un moment, vous pouvez rendre l’âme en maintenant [[touche:vava_health_giveup]] : vous vous réveillez au
lieu de soins le plus proche, sans être tout à fait remis. Plus tard encore, on vous y porte d’office. L’écran vous
dit combien de temps il reste avant l’un et l’autre.

Se déconnecter ou changer de personnage n’y change rien : on revient à terre, là où le temps s’était arrêté.

## À terre
- Ni objet, ni récolte, ni artisanat, ni travail aux champs.
- Aucun sort ne vous touche, et vous n’en lancez aucun.
- On ne peut que chuchoter ou parler.
- La faim et la soif attendent.

## Se soigner
Debout, la vie ne revient que par des soins. L’alchimiste prépare à l’alambic des potions de soin, avec les herbes
qu’on lui apporte : allez le trouver, ou apprenez son art (voir [[page:artisanat]]).

> Un souci hors du rôle, un personnage bloqué ou blessé sans raison : [[commande:signaler]].
]==],
}
