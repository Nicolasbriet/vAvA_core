--[[
    vava_arrival/config_client.lua
    Rôle : réglages de l'arrivée que lit le client : attente de l'accueil (écran calme), chapitre du Codex, textes
           montrés au nouveau venu. Téléchargé par chaque joueur ; le serveur le lit aussi (`welcome.maxSends`,
           `codex.chapter` vérifié au démarrage). Tout le reste est dans config.lua, servi au seul serveur (T-132).
    Les textes ont été relus avec ceux de l'écran de chargement (T-021) : `messages.kit` (config_client.lua) suit
    `kit.items` (config.lua) : les tenir d'accord ; `messages.codexHint` cite la touche par défaut de vava_codex (F1).
    Dépendances : shared/constants.lua
]]

VavaArrival.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.2.0)

    welcome = {
        delayMs = 4000,      -- attente après la réception de l'accueil (fondu d'ouverture terminé, écran calme)
        retryMs = 1000,      -- intervalle des essais tant que l'écran n'est pas prêt (menu pause, interface ouverte, fondu)
        maxWaitMs = 30000,   -- au-delà, les notifications s'affichent sans ouvrir le Codex (une rappelle la touche)
        maxSends = 3,        -- envois de l'accueil à un personnage sans accusé de lecture (un par session) ; ensuite rien
    },

    codex = {
        -- chapitre ou page où le Codex s'ouvre à la première venue (identifiant, 64 octets au plus) : le chapitre de
        -- lecture « Premiers pas » (vava_codex 1.5.0, T-023), ouvert à sa première page, « Vivre à Eldoria ». Un
        -- identifiant que le Codex ne connaît pas (Codex antérieur à 1.5.0) le laisse s'ouvrir à son index.
        chapter = 'premiers_pas',
    },

    -- Textes montrés par le client au nouveau venu (notifications : 200 octets au plus, texte brut). `kit` suit
    -- `kit.items` de config.lua : les tenir d'accord. Les textes du Conseil sont dans config.lua (messages.*).
    messages = {
        welcome = 'Bienvenue à Eldoria. Nulle pièce ici : on troque, on rend service, on partage. Allez vers les autres, ils vous guideront.',
        kit = 'Dans votre besace : deux miches de pain et deux outres d\'eau. Pour la suite, comptez sur les autres.',
        codexHint = 'Votre Codex (F1) garde ce qu\'il faut savoir pour vos premiers pas : ouvrez-le quand vous le voudrez.',
    },
}
