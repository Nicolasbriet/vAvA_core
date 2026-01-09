--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                   vAvA Creator - Configuration                            ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]--

Config = Config or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- PARAMÈTRES GÉNÉRAUX
-- ═══════════════════════════════════════════════════════════════════════════

Config.Creator = {
    -- Langue par défaut
    DefaultLocale = 'fr',
    
    -- Position de spawn pour la création
    CreatorSpawn = vector4(-1037.41, -2737.92, 20.17, 326.72), -- LSIA Hangar
    
    -- Position de spawn après création
    FirstSpawn = vector4(-1045.35, -2750.53, 21.36, 326.72),
    
    -- Autoriser le multi-personnages
    MultiCharacter = true,
    
    -- Nombre max de personnages par joueur
    MaxCharacters = 3,
    
    -- Afficher l'âge minimum/maximum
    MinAge = 18,
    MaxAge = 80,
    
    -- Prénom/Nom longueur
    MinNameLength = 2,
    MaxNameLength = 20,
    
    -- Longueur max de l'histoire
    MaxStoryLength = 500,
    
    -- Durée animation de transition (ms)
    TransitionDuration = 500,
    
    -- Debug mode
    Debug = false
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CAMERA SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════

Config.Camera = {
    -- Distance par défaut
    DefaultDistance = 1.8,
    
    -- Hauteur offset
    HeightOffset = 0.5,
    
    -- Zoom min/max
    MinZoom = 0.5,
    MaxZoom = 3.0,
    
    -- Vitesse de rotation
    RotationSpeed = 2.0,
    
    -- Presets par étape
    Presets = {
        gender = { distance = 2.5, height = 0.0, fov = 50.0 },
        morphology = { distance = 2.5, height = 0.0, fov = 50.0 },
        face = { distance = 0.6, height = 0.65, fov = 30.0 },
        hair = { distance = 0.7, height = 0.65, fov = 35.0 },
        skin = { distance = 0.6, height = 0.65, fov = 30.0 },
        clothes = { distance = 2.0, height = 0.0, fov = 45.0 },
        identity = { distance = 2.0, height = 0.3, fov = 45.0 },
        summary = { distance = 2.5, height = 0.0, fov = 50.0 }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- MORPHOLOGIE - VALEURS PAR DÉFAUT
-- ═══════════════════════════════════════════════════════════════════════════

Config.DefaultSkin = {
    male = {
        -- Base
        sex = 0,
        mom = 21,
        dad = 0,
        mix = 0.5,
        skinMix = 0.5,
        
        -- Visage
        noseWidth = 0.0,
        nosePeakHeight = 0.0,
        nosePeakLength = 0.0,
        noseBoneHigh = 0.0,
        nosePeakLowering = 0.0,
        noseBoneTwist = 0.0,
        eyeBrowHeight = 0.0,
        eyeBrowLength = 0.0,
        cheekBoneHeight = 0.0,
        cheekBoneWidth = 0.0,
        cheekWidth = 0.0,
        eyeOpenning = 0.0,
        lipThickness = 0.0,
        jawBoneWidth = 0.0,
        jawBoneLength = 0.0,
        chinBoneHeight = 0.0,
        chinBoneLength = 0.0,
        chinBoneWidth = 0.0,
        chinDimple = 0.0,
        neckThickness = 0.0,
        
        -- Cheveux
        hair = 0,
        hairColor = 0,
        hairHighlight = 0,
        beard = -1,
        beardColor = 0,
        eyebrows = 0,
        eyebrowsColor = 0,
        
        -- Overlays
        blemishes = -1,
        blemishesOpacity = 1.0,
        ageing = -1,
        ageingOpacity = 1.0,
        complexion = -1,
        complexionOpacity = 1.0,
        sunDamage = -1,
        sunDamageOpacity = 1.0,
        moles = -1,
        molesOpacity = 1.0,
        makeup = -1,
        makeupOpacity = 1.0,
        makeupColor = 0,
        lipstick = -1,
        lipstickOpacity = 1.0,
        lipstickColor = 0,
        blush = -1,
        blushOpacity = 1.0,
        blushColor = 0,
        
        -- Yeux
        eyeColor = 0,
        
        -- Vêtements par défaut
        tshirt = 15,
        tshirtTexture = 0,
        torso = 15,
        torsoTexture = 0,
        decals = 0,
        decalsTexture = 0,
        arms = 15,
        armsTexture = 0,
        pants = 21,
        pantsTexture = 0,
        shoes = 34,
        shoesTexture = 0,
        mask = 0,
        maskTexture = 0,
        bag = 0,
        bagTexture = 0,
        accessory = 0,
        accessoryTexture = 0,
        hat = -1,
        hatTexture = 0,
        glasses = -1,
        glassesTexture = 0,
        ears = -1,
        earsTexture = 0,
        watch = -1,
        watchTexture = 0,
        bracelet = -1,
        braceletTexture = 0
    },
    female = {
        -- Base
        sex = 1,
        mom = 21,
        dad = 0,
        mix = 0.5,
        skinMix = 0.5,
        
        -- Visage (mêmes paramètres)
        noseWidth = 0.0,
        nosePeakHeight = 0.0,
        nosePeakLength = 0.0,
        noseBoneHigh = 0.0,
        nosePeakLowering = 0.0,
        noseBoneTwist = 0.0,
        eyeBrowHeight = 0.0,
        eyeBrowLength = 0.0,
        cheekBoneHeight = 0.0,
        cheekBoneWidth = 0.0,
        cheekWidth = 0.0,
        eyeOpenning = 0.0,
        lipThickness = 0.0,
        jawBoneWidth = 0.0,
        jawBoneLength = 0.0,
        chinBoneHeight = 0.0,
        chinBoneLength = 0.0,
        chinBoneWidth = 0.0,
        chinDimple = 0.0,
        neckThickness = 0.0,
        
        -- Cheveux
        hair = 0,
        hairColor = 0,
        hairHighlight = 0,
        beard = -1,
        beardColor = 0,
        eyebrows = 0,
        eyebrowsColor = 0,
        
        -- Overlays
        blemishes = -1,
        blemishesOpacity = 1.0,
        ageing = -1,
        ageingOpacity = 1.0,
        complexion = -1,
        complexionOpacity = 1.0,
        sunDamage = -1,
        sunDamageOpacity = 1.0,
        moles = -1,
        molesOpacity = 1.0,
        makeup = -1,
        makeupOpacity = 1.0,
        makeupColor = 0,
        lipstick = -1,
        lipstickOpacity = 1.0,
        lipstickColor = 0,
        blush = -1,
        blushOpacity = 1.0,
        blushColor = 0,
        
        -- Yeux
        eyeColor = 0,
        
        -- Vêtements par défaut
        tshirt = 15,
        tshirtTexture = 0,
        torso = 15,
        torsoTexture = 0,
        decals = 0,
        decalsTexture = 0,
        arms = 15,
        armsTexture = 0,
        pants = 15,
        pantsTexture = 0,
        shoes = 35,
        shoesTexture = 0,
        mask = 0,
        maskTexture = 0,
        bag = 0,
        bagTexture = 0,
        accessory = 0,
        accessoryTexture = 0,
        hat = -1,
        hatTexture = 0,
        glasses = -1,
        glassesTexture = 0,
        ears = -1,
        earsTexture = 0,
        watch = -1,
        watchTexture = 0,
        bracelet = -1,
        braceletTexture = 0
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- HERITAGE (PARENTS) - Noms affichables
-- ═══════════════════════════════════════════════════════════════════════════

Config.Parents = {
    male = {
        { id = 0, name = "Benjamin" },
        { id = 1, name = "Daniel" },
        { id = 2, name = "Joshua" },
        { id = 3, name = "Noah" },
        { id = 4, name = "Andrew" },
        { id = 5, name = "Juan" },
        { id = 6, name = "Alex" },
        { id = 7, name = "Isaac" },
        { id = 8, name = "Evan" },
        { id = 9, name = "Ethan" },
        { id = 10, name = "Vincent" },
        { id = 11, name = "Angel" },
        { id = 12, name = "Diego" },
        { id = 13, name = "Adrian" },
        { id = 14, name = "Gabriel" },
        { id = 15, name = "Michael" },
        { id = 16, name = "Santiago" },
        { id = 17, name = "Kevin" },
        { id = 18, name = "Louis" },
        { id = 19, name = "Samuel" },
        { id = 20, name = "Anthony" },
        { id = 42, name = "Claude" },
        { id = 43, name = "Niko" },
        { id = 44, name = "John" }
    },
    female = {
        { id = 21, name = "Hannah" },
        { id = 22, name = "Audrey" },
        { id = 23, name = "Jasmine" },
        { id = 24, name = "Giselle" },
        { id = 25, name = "Amelia" },
        { id = 26, name = "Isabella" },
        { id = 27, name = "Zoe" },
        { id = 28, name = "Ava" },
        { id = 29, name = "Camila" },
        { id = 30, name = "Violet" },
        { id = 31, name = "Sophia" },
        { id = 32, name = "Evelyn" },
        { id = 33, name = "Nicole" },
        { id = 34, name = "Ashley" },
        { id = 35, name = "Grace" },
        { id = 36, name = "Brianna" },
        { id = 37, name = "Natalie" },
        { id = 38, name = "Olivia" },
        { id = 39, name = "Elizabeth" },
        { id = 40, name = "Charlotte" },
        { id = 41, name = "Emma" },
        { id = 45, name = "Misty" }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- COULEURS DISPONIBLES (Cheveux, Barbe, Sourcils)
-- ═══════════════════════════════════════════════════════════════════════════

Config.HairColors = {
    { id = 0, name = "Noir", hex = "#0A0A0A" },
    { id = 1, name = "Brun foncé", hex = "#2C1810" },
    { id = 2, name = "Brun", hex = "#4A2912" },
    { id = 3, name = "Brun clair", hex = "#7C4A2D" },
    { id = 4, name = "Châtain", hex = "#8B5A2B" },
    { id = 5, name = "Blond foncé", hex = "#A67C52" },
    { id = 6, name = "Blond", hex = "#C9A86C" },
    { id = 7, name = "Blond platine", hex = "#E8D5B7" },
    { id = 8, name = "Roux foncé", hex = "#6B2E1A" },
    { id = 9, name = "Roux", hex = "#8B3E2F" },
    { id = 10, name = "Roux clair", hex = "#C14A36" },
    { id = 11, name = "Gris", hex = "#808080" },
    { id = 12, name = "Gris clair", hex = "#A9A9A9" },
    { id = 13, name = "Blanc", hex = "#E8E8E8" },
    { id = 14, name = "Rose", hex = "#FF69B4" },
    { id = 15, name = "Bleu", hex = "#4169E1" },
    { id = 16, name = "Vert", hex = "#228B22" },
    { id = 17, name = "Violet", hex = "#8B008B" },
    { id = 18, name = "Rouge", hex = "#DC143C" },
    { id = 19, name = "Orange", hex = "#FF8C00" }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- COULEURS DES YEUX
-- ═══════════════════════════════════════════════════════════════════════════

Config.EyeColors = {
    { id = 0, name = "Vert émeraude", hex = "#50C878" },
    { id = 1, name = "Vert clair", hex = "#90EE90" },
    { id = 2, name = "Bleu clair", hex = "#87CEEB" },
    { id = 3, name = "Bleu", hex = "#4169E1" },
    { id = 4, name = "Bleu gris", hex = "#778899" },
    { id = 5, name = "Marron clair", hex = "#D2691E" },
    { id = 6, name = "Marron", hex = "#8B4513" },
    { id = 7, name = "Marron foncé", hex = "#3D2314" },
    { id = 8, name = "Noir", hex = "#1A1A1A" }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SHOPS DE VÊTEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

Config.Shops = {
    {
        id = "binco",
        name = "Binco",
        blip = { sprite = 73, color = 1, scale = 0.7 },
        coords = vector3(75.33, -1392.97, 29.38),
        heading = 68.0,
        categories = { "tops", "pants", "shoes", "accessories" },
        priceMultiplier = 1.0
    },
    {
        id = "binco2",
        name = "Binco",
        blip = { sprite = 73, color = 1, scale = 0.7 },
        coords = vector3(-822.27, -1073.96, 11.33),
        heading = 300.0,
        categories = { "tops", "pants", "shoes", "accessories" },
        priceMultiplier = 1.0
    },
    {
        id = "suburban",
        name = "Suburban",
        blip = { sprite = 73, color = 2, scale = 0.7 },
        coords = vector3(125.62, -223.45, 54.56),
        heading = 68.0,
        categories = { "tops", "pants", "shoes", "accessories", "hats", "glasses" },
        priceMultiplier = 1.3
    },
    {
        id = "suburban2",
        name = "Suburban",
        blip = { sprite = 73, color = 2, scale = 0.7 },
        coords = vector3(-1193.42, -767.24, 17.32),
        heading = 217.0,
        categories = { "tops", "pants", "shoes", "accessories", "hats", "glasses" },
        priceMultiplier = 1.3
    },
    {
        id = "ponsonbys",
        name = "Ponsonbys",
        blip = { sprite = 73, color = 5, scale = 0.7 },
        coords = vector3(-165.13, -302.73, 39.73),
        heading = 250.0,
        categories = { "tops", "pants", "shoes", "accessories", "hats", "glasses", "masks" },
        priceMultiplier = 2.0
    },
    {
        id = "ponsonbys2",
        name = "Ponsonbys",
        blip = { sprite = 73, color = 5, scale = 0.7 },
        coords = vector3(-1447.79, -242.46, 49.81),
        heading = 38.0,
        categories = { "tops", "pants", "shoes", "accessories", "hats", "glasses", "masks" },
        priceMultiplier = 2.0
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CATÉGORIES DE VÊTEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

Config.ClothingCategories = {
    tops = {
        label = "Hauts",
        icon = "fa-shirt",
        components = {
            { component = 11, name = "torso" },      -- Torso
            { component = 8, name = "tshirt" },      -- Undershirt
            { component = 3, name = "arms" }         -- Arms/Gloves
        }
    },
    pants = {
        label = "Pantalons",
        icon = "fa-person",
        components = {
            { component = 4, name = "pants" }        -- Legs
        }
    },
    shoes = {
        label = "Chaussures",
        icon = "fa-shoe-prints",
        components = {
            { component = 6, name = "shoes" }        -- Feet
        }
    },
    accessories = {
        label = "Accessoires",
        icon = "fa-gem",
        components = {
            { component = 7, name = "accessory" },   -- Accessories
            { component = 10, name = "decals" }      -- Decals
        }
    },
    hats = {
        label = "Chapeaux",
        icon = "fa-hat-cowboy",
        props = {
            { prop = 0, name = "hat" }               -- Hat
        }
    },
    glasses = {
        label = "Lunettes",
        icon = "fa-glasses",
        props = {
            { prop = 1, name = "glasses" }           -- Glasses
        }
    },
    masks = {
        label = "Masques",
        icon = "fa-mask",
        components = {
            { component = 1, name = "mask" }         -- Mask
        }
    },
    bags = {
        label = "Sacs",
        icon = "fa-briefcase",
        components = {
            { component = 5, name = "bag" }          -- Parachute/Bag
        }
    },
    ears = {
        label = "Boucles d'oreilles",
        icon = "fa-ear-listen",
        props = {
            { prop = 2, name = "ears" }              -- Ears
        }
    },
    watches = {
        label = "Montres",
        icon = "fa-clock",
        props = {
            { prop = 6, name = "watch" }             -- Watch
        }
    },
    bracelets = {
        label = "Bracelets",
        icon = "fa-ring",
        props = {
            { prop = 7, name = "bracelet" }          -- Bracelet
        }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- PRIX DES VÊTEMENTS (par type)
-- ═══════════════════════════════════════════════════════════════════════════

Config.Prices = {
    tops = 150,
    pants = 120,
    shoes = 80,
    accessories = 50,
    hats = 60,
    glasses = 45,
    masks = 100,
    bags = 200,
    ears = 75,
    watches = 300,
    bracelets = 150
}

-- ═══════════════════════════════════════════════════════════════════════════
-- BARBER SHOPS (Coiffeur)
-- ═══════════════════════════════════════════════════════════════════════════

Config.Barbers = {
    {
        id = "barber1",
        name = "Coiffeur",
        blip = { sprite = 71, color = 0, scale = 0.7 },
        coords = vector3(-814.31, -183.82, 37.57),
        heading = 112.0
    },
    {
        id = "barber2",
        name = "Coiffeur",
        blip = { sprite = 71, color = 0, scale = 0.7 },
        coords = vector3(136.89, -1708.43, 29.29),
        heading = 140.0
    },
    {
        id = "barber3",
        name = "Coiffeur",
        blip = { sprite = 71, color = 0, scale = 0.7 },
        coords = vector3(-1282.57, -1116.84, 6.99),
        heading = 86.0
    },
    {
        id = "barber4",
        name = "Coiffeur",
        blip = { sprite = 71, color = 0, scale = 0.7 },
        coords = vector3(1931.51, 3729.67, 32.84),
        heading = 208.0
    },
    {
        id = "barber5",
        name = "Coiffeur",
        blip = { sprite = 71, color = 0, scale = 0.7 },
        coords = vector3(1212.84, -472.92, 66.21),
        heading = 71.0
    }
}

-- Prix coiffeur
Config.BarberPrices = {
    hair = 50,
    hairColor = 30,
    beard = 40,
    eyebrows = 20,
    makeup = 60
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TATTOO SHOPS
-- ═══════════════════════════════════════════════════════════════════════════

Config.TattooShops = {
    {
        id = "tattoo1",
        name = "Tattoo",
        blip = { sprite = 75, color = 1, scale = 0.7 },
        coords = vector3(1322.64, -1651.97, 52.28),
        heading = 127.0
    },
    {
        id = "tattoo2",
        name = "Tattoo",
        blip = { sprite = 75, color = 1, scale = 0.7 },
        coords = vector3(-1153.67, -1425.68, 4.95),
        heading = 124.0
    },
    {
        id = "tattoo3",
        name = "Tattoo",
        blip = { sprite = 75, color = 1, scale = 0.7 },
        coords = vector3(322.13, 180.35, 103.59),
        heading = 250.0
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CHIRURGIE ESTHETIQUE
-- ═══════════════════════════════════════════════════════════════════════════

Config.SurgeryShops = {
    {
        id = "surgery1",
        name = "Chirurgie Esthétique",
        blip = { sprite = 102, color = 1, scale = 0.7 },
        coords = vector3(-282.05, -1117.67, 23.95),
        heading = 259.0,
        price = 5000 -- Prix de base
    }
}
