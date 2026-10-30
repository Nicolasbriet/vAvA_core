--[[
    vava_codex/content/premiers_pas.lua
    Rôle : pages du chapitre « Premiers pas » (texte provisoire, sobre : le texte définitif est celui du gardien du
           lore). Chaque page dit le jeu tel qu'il est codé : une règle qui change dans un module cité fait relire la
           page (voir les sources en tête de chaque page). Aucun nombre réglable en config n'est cité (durées,
           distances, quantités) ; les touches et commandes sont citées par leur nom au registre `core:commands`.
    Dépendances : content/chapters.lua (VavaCodex.seed)
]]

local pages = VavaCodex.seed.pages

-- Sources : lore (aucune monnaie, réserves communes) ; vava_skills (budget de compétences) ; vava_arrival
-- (kit.items, sans les quantités) ; vava_codex (touche codex, onglets) ; vava_inventory (touche vava_inventory) ;
-- vava_skills (touche vava_skills) ; vava_time (/date) ; vava_chat (texte sans commande : hors du rôle)
pages[#pages + 1] = {
    id = 'bienvenue', chapter = 'premiers_pas', order = 10,
    title = 'Vivre à Eldoria', summary = 'Une cité sans pièce, où chacun a besoin des autres.',
    audience = 'player', permission = '', requires = '',
    body = [==[
Eldoria ne connaît ni pièce ni échoppe. Ce dont on a besoin, on le troque, on le reçoit pour un service rendu, ou
on le prend dans les réserves communes, que chacun remplit à son tour.

Personne ici ne sait tout faire. Le menuisier a besoin du forgeron, la cuisinière du cultivateur, et chacun apprend
son métier auprès de ceux qui le savent déjà.

## Votre arrivée
Le nouveau venu arrive avec un peu de pain et d’eau, de quoi tenir un soir. Pour la suite, il faut aller vers les
autres.

## Ce livre
Le Codex s’ouvre avec [[touche:codex]]. Il a trois onglets :
- *Lecture* : les pages que vous lisez ;
- *Commandes* : chaque commande qui vous est ouverte, que l’on compose et que l’on lance d’ici ;
- *Touches* : les touches du royaume, telles que vous les avez liées.

## Vos premiers gestes
- La besace : [[touche:vava_inventory]].
- Le livre des compétences : [[touche:vava_skills]].
- L’heure, la saison et le ciel : [[commande:date]].
- Ce qui s’écrit dans le chat sans commande est dit hors du rôle.

## Pour aller plus loin
- [[page:se_parler]]
- [[page:troquer]]
- [[page:apprendre]]
- [[page:conseil]]
]==],
}

-- Sources : vava_chat (touche vava_chat_ouvrir, /me, /do, /mp, /r, texte hors du rôle entendu des proches,
-- conservation des messages pour la modération) ; vava_voice (quatre portées, touche vava_voice_portee, lieux qui
-- portent la voix, touche de parole du jeu) ; vava_health (à terre : chuchoter ou parler) ; vava_magic (Murmure)
pages[#pages + 1] = {
    id = 'se_parler', chapter = 'premiers_pas', order = 20,
    title = 'Se parler', summary = 'Le chat, les gestes, les messages privés et la voix.',
    audience = 'player', permission = '', requires = 'vava_chat',
    body = [==[
À Eldoria, on se parle de vive voix et par gestes. Le chat sert aussi, et il a ses usages.

## Le chat
La fenêtre s’ouvre avec [[touche:vava_chat_ouvrir]]. Ce que vous y écrivez sans commande est dit hors du rôle, et
seuls les joueurs proches l’entendent.
- [[commande:me]] : un geste de votre personnage, vu des proches et montré au-dessus de sa tête.
- [[commande:do]] : décrire la scène, ce qui se voit ou s’entend autour de vous.
- [[commande:mp]] : un message privé à un joueur, par son numéro.
- [[commande:r]] : répondre au dernier message privé.

> Les messages hors du rôle et les messages privés sont gardés quelques jours, pour la modération.

## La voix
Le chat vocal du jeu s’active dans ses réglages ; on parle avec la touche du jeu, [[N]] par défaut.

Quatre portées : *Chuchoter*, *Parler*, *Crier* et *Déclamer*. On passe de l’une à l’autre avec
[[touche:vava_voice_portee]]. Certains lieux portent la voix plus ou moins loin.

À terre, on ne fait que chuchoter ou parler : voir [[page:a_terre]].

Dans le rôle, on ne parle qu’à ceux qui sont là. Seule une magie, le *Murmure*, porte la parole au loin, et elle ne
répond pas à tous : voir [[page:magie]].
]==],
}

-- Sources : vava_inventory (fiche d'objet : palier, provenance, créateur, poinçon ; place et poids de la besace ;
-- sacs au sol, durée de vie, perdus au redémarrage ; objet tenu en main visible) ; vava_crafting (poinçon,
-- réparation) ; vava_health (relever) ; vava_skills (enseigner) ; vava_farming (grenier commun, dépôts et retraits
-- inscrits). Décision 9 de la spec T-023 : rien du troc face à face (T-030), aucun prix, aucun don à distance.
pages[#pages + 1] = {
    id = 'troquer', chapter = 'premiers_pas', order = 30,
    title = 'Troquer et partager', summary = 'Ici rien ne s’achète : on donne, on rend service, on partage.',
    audience = 'player', permission = '', requires = 'vava_inventory',
    body = [==[
Ici, nul ne compte en pièces. Un objet vaut par sa qualité, par sa provenance et par la main qui l’a façonné : sa
fiche, dans la besace, montre son palier, d’où il vient, qui l’a fait et son poinçon.

La besace a sa place et son poids : on n’y porte pas tout.

## Donner un objet
1. Ouvrez votre besace ([[touche:vava_inventory]]).
2. Faites glisser l’objet hors de la fenêtre : un sac se pose à vos pieds, visible des proches.
3. L’autre ouvre sa besace près du sac et ramasse l’objet d’un double-clic.

> Un sac ne reste pas indéfiniment au sol et ne survit pas au redémarrage du royaume : ne posez que devant celui qui
> prend.

L’usage veut qu’on annonce le don d’un [[commande:me]] et qu’on reste jusqu’à ce que l’autre ait pris. Ce que l’on
tient en main se voit.

## Rendre service
- Réparer un outil : [[page:artisanat]].
- Relever un blessé : [[page:a_terre]].
- Enseigner ce que l’on sait : [[page:apprendre]].
- Porter une part de récolte au grenier.

## Les réserves communes
Le grenier du champ communal est à tous : chaque dépôt et chaque retrait y est inscrit. Voir
[[page:agriculture]].
]==],
}

-- Sources : vava_needs (deux besoins et leurs médaillons, baisse en jeu seulement, plus vite à la course,
-- avertissements, besoin critique : endurance, besoin épuisé : blessure, figés à terre, rassasié) ;
-- vava_inventory (usage d'un objet, ceinture : touche vava_inventory_slot) ; vava_gathering, vava_farming,
-- vava_crafting (nourriture : récolte, pêche, chasse, champs, ragoût au fourneau). Décision 10 de la spec T-023 :
-- ni puits ni fontaine pour boire (T-130), l'eau se partage.
pages[#pages + 1] = {
    id = 'faim_soif', chapter = 'premiers_pas', order = 40,
    title = 'La faim et la soif', summary = 'Manger et boire, et pourquoi il faut les autres pour cela.',
    audience = 'player', permission = '', requires = 'vava_needs',
    body = [==[
Deux besoins vous tiennent : la faim et la soif. Chacun a son médaillon.

## Comment ils baissent
Ils baissent avec le temps passé en jeu, jamais hors ligne ni pendant le choix du personnage, et plus vite à la
course. Vous êtes prévenu quand ils baissent.
- Un besoin critique coupe le souffle : l’endurance diminue.
- Un besoin épuisé blesse, jusqu’à mettre à terre : voir [[page:a_terre]].
- À terre, la faim et la soif sont figées.

## Manger et boire
Utilisez l’objet dans la besace d’un double-clic, ou depuis la ceinture ([[touche:vava_inventory_slot]]). Le geste
dure un instant, et l’on peut marcher pendant ce temps. Rassasié, on ne peut plus rien avaler.

## D’où vient la nourriture
Du travail des autres : la récolte, la pêche, la chasse, les champs, un ragoût cuit au fourneau. Qui ne sait rien
de tout cela demande, troque ou rend service : voir [[page:troquer]].

L’eau se partage comme le reste.
]==],
}

-- Sources : vava_health (vie qui ne remonte pas seule, à terre, relever : touche vava_health_assist, repartir
-- affaibli, rendre l'âme : touche vava_health_giveup, lieu de soins, transport d'office, déconnexion sans effet,
-- interdits à terre, voix limitée) ; vava_crafting (potion de soin à l'alambic) ; vava_admin (/signaler)
pages[#pages + 1] = {
    id = 'a_terre', chapter = 'premiers_pas', order = 50,
    title = 'À terre et soins', summary = 'Personne ne se relève seul.',
    audience = 'player', permission = '', requires = 'vava_health',
    body = [==[
La vie ne remonte pas seule. Gravement blessé, on ne meurt pas : on tombe *à terre*.

## Être relevé
Quelqu’un tout près de vous peut vous relever ([[touche:vava_health_assist]]) : un geste de quelques secondes. Vous
repartez affaibli.

## Si personne ne vient
Après quelques minutes, vous pouvez rendre l’âme en maintenant [[touche:vava_health_giveup]] : vous vous réveillez
au lieu de soins le plus proche. Plus tard encore, vous y êtes porté d’office. Se déconnecter n’y change rien.

## À terre
- Ni objet, ni récolte, ni artisanat, ni champ.
- Aucun sort ne vous touche.
- La voix se limite à chuchoter et parler.

## Se soigner
Par des objets de soin, comme les potions de l’alchimiste, préparées à l’alambic (voir [[page:artisanat]]), ou en
se faisant relever.

> Un souci hors du rôle, un personnage bloqué ou blessé sans raison : [[commande:signaler]].
]==],
}
