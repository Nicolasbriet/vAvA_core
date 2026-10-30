--[[
    vava_anim_test/config.lua
    Rôle : configuration de l'outil de test des animations : accès, commandes, délais, drapeaux, noms de clips
           essayés, accessoire par défaut.
    Dépendances : aucune
]]

VavaAnimTest = {
    config = {
        -- Qui peut s'en servir : droit vava_admin `permission`, ou ACE `ace` ; le serveur répond à chaque demande
        -- d'accès du client, gardée `accessCacheMs` (un droit retiré vaut au plus tard à l'expiration). Le module ne
        -- démarre qu'en mode développement (`set vava_env dev`) : sinon aucune commande ne répond.
        access = { permission = 'staff', ace = 'vava.dev' },
        accessRateLimit = { capacity = 5, refillPerSecond = 0.5 },
        accessCacheMs = 60000,
        refusals = {
            not_allowed = 'outil réservé au Conseil (droit staff) ou à l\'ACE vava.dev.',
            unknown_rpc = 'outil inactif sur ce serveur (mode développement absent).',
        },

        commands = { play = 'anim', stop = 'animstop', prop = 'animprop', flags = 'animflags' },
        -- Raccourcis : une commande par animation à tester, sans rien à taper (/epee). `clip` nil : sondage des noms
        -- courants. Chaque raccourci est déclaré au Codex avec son libellé.
        shortcuts = {
            { command = 'epee', label = 'Épée à une main (test)', dict = 'vava_sword_1h', clip = nil, flag = 49 },
        },
        chatAuthor = 'Anim',
        loadTimeoutMs = 5000,          -- attente maximale du chargement d'un dictionnaire ou d'un modèle
        startCheckMs = 150,            -- délai avant de vérifier que le clip joue bien
        defaultFlag = 1,               -- boucle
        blendIn = 8.0,
        blendOut = -8.0,

        -- Noms de clips essayés quand la commande ne donne pas le clip ; %s = nom du dictionnaire. Un clip existe si
        -- le jeu lui connaît une durée. Si rien ne répond, le nom se lit dans CodeWalker (ouvrir le .ycd).
        clipCandidates = {
            '%s', '%s_clip', '%s_idle', '%s_loop', 'clip', 'idle', 'base', 'anim', 'loop', 'attack', 'swing', 'idle_a', 'a', 'clip_0', 'clip_01',
        },

        -- Accessoire accroché à la main droite (os 57005) pour juger la pose : décalage et rotation par défaut,
        -- modifiables en arguments de /animprop.
        prop = {
            bone = 57005,
            offset = { 0.1, 0.03, -0.02 },
            rotation = { -100.0, 0.0, 0.0 },
            defaultModel = 'w_me_machete_lr',
        },

        -- Drapeaux de TaskPlayAnim les plus utiles (ils s'additionnent).
        flags = {
            { 0, 'normal : corps entier, immobile, une fois' },
            { 1, 'boucle' },
            { 2, 'garder la dernière image' },
            { 16, 'haut du corps seulement' },
            { 32, 'le joueur garde la main (peut bouger)' },
            { 48, 'haut du corps + le joueur garde la main' },
            { 49, 'haut du corps + main libre + boucle' },
            { 50, 'haut du corps + main libre + dernière image' },
        },
    },
}
