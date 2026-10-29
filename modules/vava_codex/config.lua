--[[
    vava_codex/config.lua
    Rôle : configuration du Codex (lue par le client et le serveur) : touche et commande d'ouverture, signets et
           dernières pages, commandes non décrites montrées au Conseil, droits sans vava_admin, débits, textes.
    Dépendances : shared/constants.lua
]]

VavaCodex.config = {
    coreVersion = '0.7.0',

    -- Touche par défaut, réglable par le joueur (Paramètres > Raccourcis > FiveM), et commande du chat.
    keys = { open = 'F1' },
    labels = { open = 'Ouvrir le Codex (commandes et touches)' },
    command = 'codex',

    -- Préférences par personnage : signets (favoris) et dernières pages (commandes lancées, du Codex ou du chat).
    favorites = { max = 24 },
    recent = { max = 12 },

    -- Commandes enregistrées auprès du jeu mais absentes du registre : montrées au Conseil seulement, pour les
    -- ressources dont le nom répond à `resources`, sauf celles qui répondent à `hidden` (touches +/−, internes).
    undeclared = { enabled = true, resources = { '^vava', '^vAvA' }, hidden = { '^[%+%-]', '^_' } },

    -- Sans vava_admin : qui est du Conseil (permission ACE). Avec lui : ses rangs et ses droits.
    staff = { ace = 'vava_codex.staff' },

    -- Arguments « joueur » (dont /mp) : hors du Conseil, seuls les joueurs proches sont proposés, à portée de voix
    -- (mètres ; positions lues par le serveur, même instance). Défaut : la portée « Parler » de vava_voice (5 m), à
    -- ajuster ici si elle change. Le Conseil a la liste complète ; un numéro tapé à la main reste permis.
    players = { nearbyRadius = 5.0 },

    -- Après « Lancer » : rester ouvert, sauf réglage contraire du joueur ; une commande qui ouvre une interface
    -- (`ui = true` dans sa déclaration) ferme toujours le Codex d'abord.
    keepOpenDefault = true,

    rateLimits = {
        open = { capacity = 3, refillPerSecond = 0.5 },
        options = { capacity = 10, refillPerSecond = 3 },
        prefs = { capacity = 10, refillPerSecond = 2 },   -- signets, dernières pages, réglage
    },

    messages = {
        unavailable = 'Le Codex est indisponible pour le moment.',
        unknown = 'Cette commande n\'est pas dans le Codex.',
        refused = 'Cette commande ne vous est pas ouverte.',
        consoleOnly = 'Cette commande ne se lance que depuis la console du serveur.',
        favoritesFull = 'Vous avez déjà %d signets : retirez-en un.',
    },
}
