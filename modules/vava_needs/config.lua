--[[
    vava_needs/config.lua
    Rôle : configuration des besoins (lue par le client et le serveur). Valeurs de 0 (épuisé) à 100 (satisfait).
    Dépendances : shared/constants.lua
]]

VavaNeeds.config = {
    coreVersion = '0.3.0',

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

    -- Boucle serveur : un seul passage pour tous les personnages actifs. La baisse n'a lieu qu'en jeu : ni hors
    -- connexion, ni pendant la sélection du personnage.
    tickMs = 60000,

    -- Activité lue côté serveur entre deux passages : la part du temps passé à courir accélère la baisse.
    -- En véhicule, la vitesse est celle du véhicule : elle ne compte pas.
    activity = { sampleMs = 15000, runningSpeed = 4.0, runningMultiplier = 1.5 },

    -- Vie : sans module de mise à terre (vava_health), un besoin épuisé ne fait pas descendre la vie sous ce plancher
    -- (part de la vie située au-dessus du seuil où GTA met le joueur à terre) : personne ne reste mort sans recours.
    -- Avec vava_health, le plancher est levé : le joueur tombe, puis peut être relevé ; la baisse s'arrête à terre.
    health = { floor = 0.10, downThreshold = 100 },

    -- Endurance quand un besoin est critique : part de l'endurance maximale habituelle.
    criticalStamina = 0.35,

    -- Manger et boire (objets de l'inventaire déclarant des effets : `effects = { hunger = 35 }`).
    consumption = {
        cooldownMs = 3000,                  -- un objet à la fois : durée du geste
        fullAt = 95,                        -- au-delà, l'objet est refusé : rien n'est gaspillé
        fullMessage = 'Vous êtes rassasié.',            -- objet qui nourrit et désaltère, les deux déjà pleins
        busyMessage = 'Vous n\'avez pas encore fini.',
        gestureByCategory = { nourriture = 'eat', boisson = 'drink' },
        defaultGesture = 'eat',
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
