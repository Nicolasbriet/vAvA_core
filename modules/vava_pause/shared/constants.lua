--[[
    vava_pause/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : RPC, crochets, natures d'une
           demande au Conseil, façons de quitter, rubriques, directions de la manette, bornes de ce que le client
           envoie ou relit (version des touches, texte au Conseil, blocages).
    Dépendances : aucune
]]

VavaPause = {}

-- Intentions du client (RPC à schéma strict, débit limité).
VavaPause.RPC = {
    OPEN = 'vava_pause:open',          -- version des touches gardée : instantané de la bannière
    COUNCIL = 'vava_pause:council',    -- nature, texte, joindre la position : demande au Conseil
    LEAVE = 'vava_pause:leave',        -- disconnect | quit : le serveur déconnecte l'appelant
}

-- Crochets émis par le module.
VavaPause.HOOKS = {
    OPENING = 'vava_pause:opening',              -- serveur, before : { source, characterId, downed } (refus : raison)
    STATE = 'vava_pause:state',                  -- client, after : { open }
    SETTING_CHANGED = 'vava_pause:settingChanged', -- client, after : { key, value }
}

-- Crochets écoutés chez d'autres modules.
VavaPause.LISTENED = {
    HIT = 'vava_health:hit',                     -- serveur, after : fenêtre de combat
    CODEX_CLOSED = 'vava_codex:closed',          -- client, after : { docked, reason }
}

-- Natures d'une demande au Conseil (mêmes noms que vava_admin `requests.kinds`).
VavaPause.KINDS = { 'question', 'player', 'bug', 'other' }
-- Façons de quitter Eldoria.
VavaPause.LEAVE_MODES = { 'disconnect', 'quit' }
-- Rubriques de la bannière que la page peut désigner (rappel `rubric`).
VavaPause.RUBRICS = { 'personnage', 'codex', 'carte', 'reglages', 'conseil', 'quitter' }
-- Refus d'ouverture gardés tels quels quand un crochet serveur les donne ; tout autre refus devient `busy`.
VavaPause.KEPT_REFUSALS = { combat = true, restrained = true }

-- Bornes de protocole.
VavaPause.MAX_COUNCIL_TEXT = 500                 -- octets d'un message au Conseil (vava_admin MAX_TEXT)
VavaPause.KEYS_VERSION = { MAX = 24, PATTERN = '^[%w%-]*$' }   -- '' : aucune liste de touches gardée
VavaPause.BLOCK = { ID_PATTERN = '^[%w_]+$', MAX_ID = 32, MAX = 16, KINDS = { restrained = true, combat = true, other = true } }
VavaPause.MAX_SETTING_KEY = 48
