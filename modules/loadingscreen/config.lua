--[[
    Configuration du module vava_loadingscreen
    Personnalisez tous les aspects de votre écran de chargement ici
]]

Config = Config or {}

Config.LoadingScreen = {
    -- ═══════════════════════════════════════════════════════════════
    -- INFORMATIONS DU SERVEUR
    -- ═══════════════════════════════════════════════════════════════
    ServerName = "vAvA Roleplay",
    ServerSlogan = "L'immersion au service du RP",
    ServerVersion = "1.0.0",
    
    -- ═══════════════════════════════════════════════════════════════
    -- LANGUE PAR DÉFAUT
    -- ═══════════════════════════════════════════════════════════════
    DefaultLocale = "fr", -- fr, en, es
    
    -- ═══════════════════════════════════════════════════════════════
    -- IMAGES
    -- ═══════════════════════════════════════════════════════════════
    Background = {
        Image = "assets/background.png",  -- Chemin vers l'image de fond
        Blur = 0,                          -- Flou (0-20)
        Opacity = 1.0,                     -- Opacité (0.0-1.0)
        Filter = "none",                   -- none, sepia, grayscale, saturate
        Animation = "zoom",                -- none, zoom, parallax
        AnimationSpeed = 30                -- Durée de l'animation en secondes
    },
    
    Logo = {
        Enabled = true,
        Image = "assets/logo.png",         -- Chemin vers le logo
        Width = 200,                       -- Largeur en pixels
        Height = 200,                      -- Hauteur en pixels
        Animation = true                   -- Animation du logo (pulse)
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- BARRE DE CHARGEMENT
    -- ═══════════════════════════════════════════════════════════════
    ProgressBar = {
        Style = "line",                    -- line, block, circle
        Color = "#e74c3c",                 -- Couleur principale
        BackgroundColor = "rgba(255,255,255,0.2)", -- Couleur de fond
        Height = 4,                        -- Hauteur en pixels (pour line/block)
        Width = 400,                       -- Largeur en pixels
        Animated = true,                   -- Animation de la barre
        ShowPercentage = true              -- Afficher le pourcentage
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- COULEURS ET STYLE
    -- ═══════════════════════════════════════════════════════════════
    Colors = {
        Primary = "#e74c3c",               -- Couleur principale (rouge vAvA)
        Secondary = "#c0392b",             -- Couleur secondaire
        Text = "#ffffff",                  -- Couleur du texte
        TextShadow = "rgba(0,0,0,0.5)",    -- Ombre du texte
        Accent = "#f39c12"                 -- Couleur d'accent
    },
    
    Fonts = {
        Primary = "'Montserrat', sans-serif",
        Secondary = "'Open Sans', sans-serif"
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- MESSAGES DYNAMIQUES
    -- ═══════════════════════════════════════════════════════════════
    Messages = {
        Enabled = true,
        DisplayMode = "random",            -- random, sequential
        DisplayTime = 5000,                -- Temps d'affichage en ms
        FadeTime = 500                     -- Temps de transition en ms
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- MUSIQUE
    -- ═══════════════════════════════════════════════════════════════
    Music = {
        Enabled = false,
        File = "assets/music.mp3",         -- Fichier audio
        Volume = 0.3,                      -- Volume (0.0-1.0)
        Loop = true,                       -- Lecture en boucle
        AutoPlay = true,                   -- Lecture automatique
        ShowControls = true                -- Afficher bouton mute/unmute
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- EFFETS VISUELS
    -- ═══════════════════════════════════════════════════════════════
    Effects = {
        Particles = {
            Enabled = false,
            Type = "snow",                 -- snow, rain, dust, stars
            Density = 50,                  -- Nombre de particules
            Speed = 1.0                    -- Vitesse des particules
        },
        Vignette = {
            Enabled = true,
            Opacity = 0.4                  -- Opacité du vignette
        },
        Scanlines = {
            Enabled = false,
            Opacity = 0.05                 -- Opacité des scanlines
        }
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- INFORMATIONS DYNAMIQUES
    -- ═══════════════════════════════════════════════════════════════
    DynamicInfo = {
        ShowPlayerCount = true,            -- Afficher nombre de joueurs
        ShowServerVersion = true,          -- Afficher version du serveur
        ShowLoadingModules = true          -- Afficher modules en chargement
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- PERFORMANCE
    -- ═══════════════════════════════════════════════════════════════
    Performance = {
        LowQualityMode = false,            -- Mode basse qualité
        DisableAnimations = false,         -- Désactiver les animations
        MaxFPS = 60                        -- FPS maximum
    }
}

-- ═══════════════════════════════════════════════════════════════════
-- LISTE DES MESSAGES (tips, règles, infos)
-- Utilisez les locales pour le multilingue
-- ═══════════════════════════════════════════════════════════════════
Config.LoadingMessages = {
    -- Ces messages sont définis dans les fichiers locales
    -- Voir locales/fr.lua, locales/en.lua, locales/es.lua
}
