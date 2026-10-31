--[[
    vava_needs/config_client.lua
    Rôle : réglages des besoins que lit le client (le serveur les lit aussi). Valeurs de 0 (épuisé) à 100
           (satisfait). Besoins suivis, paliers, vie et endurance, durée du geste de consommation, gestes, jauges.
           Téléchargé par chaque joueur. Ce que lit le seul serveur (boucle de baisse, activité, refus d'un objet,
           geste par catégorie) est dans config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaNeeds.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.3.0)

    -- Besoins suivis, dans l'ordre d'affichage. Ajouter un besoin ici suffit (fiche d'objet, HUD et effets suivent).
    --   durationHours : temps de jeu pour passer de 100 à 0 au repos ;
    --   damage        : points de vie perdus à chaque passage de la boucle quand le besoin est à 0 ;
    --   messages      : low, critical et empty au franchissement d'un palier ; full quand un objet est refusé.
    needs = {
        {
            name = 'hunger', label = 'Faim', durationHours = 4, damage = 2,
            icon = 'nui://vava_needs/web/icons/hunger.svg',
            messages = {
                low = 'Votre ventre gargouille.',
                critical = 'La faim vous affaiblit : vous ne tenez plus la course.',
                empty = 'Vous mourez de faim.',
                full = 'Vous n\'avez plus faim.',
            },
        },
        {
            name = 'thirst', label = 'Soif', durationHours = 3, damage = 4,
            icon = 'nui://vava_needs/web/icons/thirst.svg',
            messages = {
                low = 'Vous avez la gorge sèche.',
                critical = 'La soif vous affaiblit : vous ne tenez plus la course.',
                empty = 'Vous mourez de soif.',
                full = 'Vous n\'avez plus soif.',
            },
        },
    },

    initial = 100,                          -- valeur d'un nouveau personnage (et d'un besoin ajouté plus tard)
    thresholds = { low = 30, critical = 10 },

    -- Vie : sans module de mise à terre (vava_health), un besoin épuisé ne fait pas descendre la vie sous ce plancher
    -- (part de la vie située au-dessus du seuil où GTA met le joueur à terre) : personne ne reste mort sans recours.
    -- Avec vava_health, le plancher est levé : le joueur tombe, puis peut être relevé ; la baisse s'arrête à terre.
    health = { floor = 0.10, downThreshold = 100 },

    -- Endurance quand un besoin est critique : part de l'endurance maximale habituelle.
    criticalStamina = 0.35,

    -- Manger et boire (objets de l'inventaire déclarant des effets : `effects = { hunger = 35 }`). Le reste de la
    -- consommation (refus d'un objet, geste par catégorie) est lu par le seul serveur : config.lua.
    consumption = {
        cooldownMs = 3000,                  -- un objet à la fois : durée du geste
    },

    -- Gestes (client) : animations GTA jouées sans accessoire en main, en attendant les packs médiévaux.
    -- flag 49 = en boucle + haut du corps + secondaire : le joueur peut marcher pendant le geste.
    gestures = {
        eat = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
        drink = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
    },
    animation = { flag = 49, blendIn = 8.0, blendOut = -8.0, loadTimeoutMs = 1000, loadPollMs = 10 },

    -- Jauges de vava_hud (facultatif) : ordre de la première, écart entre deux.
    hud = { firstOrder = 10, orderStep = 10 },
}
