--[[
    vava_example/config.lua
    Rôle : configuration du module d'exemple (serveur uniquement).
    Dépendances : aucune
]]

VavaExample = {
    config = {
        coreVersion = '0.2.0',  -- version minimale de vAvA_core requise (personnages)

        -- Qui peut publier une note (le serveur revérifie à chaque appel) : droit vava_admin `permission`, ou ACE
        -- `ace`. Le module ne démarre qu'en mode développement (`set vava_env dev`).
        access = { permission = 'staff', ace = 'vava.dev' },

        -- Entrées ajoutées au registre des types de notes. D'autres modules peuvent en ajouter.
        noteTypes = {
            annonce = { label = 'Annonce publique', maxLength = 200 },
            rumeur = { label = 'Rumeur de taverne', maxLength = 120 },
        },

        forbiddenWords = { 'hérésie', 'sorcellerie' },
        forbiddenWordsPriority = 50,  -- filtre exécuté avant les hooks before de priorité par défaut

        -- Une note toutes les 5 secondes en régime établi, rafale de 3.
        postRateLimit = { capacity = 3, refillPerSecond = 0.2 },

        -- La table ne grossit pas sans fin : au plus `maxNotesPerCharacter` notes gardées par personnage (au-delà,
        -- refus `too_many`), et les notes de plus de `retentionDays` jours sont retirées à chaque démarrage.
        maxNotesPerCharacter = 20,
        retentionDays = 7,

        pingTimeoutMs = 5000,
    },
}
