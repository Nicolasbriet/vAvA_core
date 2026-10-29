--[[
    vava_chat/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole.
    Dépendances : aucune
]]

VavaChat = {}

-- Événements serveur → client (toujours ciblés : jamais à tout le serveur).
VavaChat.EVENTS = {
    MESSAGE = 'vava_chat:message', -- message reçu { kind, id, name, text, chat?, out?, staff?, rank? }
    GONE = 'vava_chat:gone',       -- (conversation) : un correspondant est parti, son onglet se grise
    PROFILE = 'vava_chat:profile', -- { staff, rank? } : droits du Conseil changés ; le client redemande son profil
    NOTICE = 'vava_chat:notice',   -- (code, détail?) : avis du serveur au seul joueur (commande inconnue…)
}

-- Intentions du client (RPC du core). 0 tient lieu de « rien » pour les numéros (jamais de trou dans les arguments).
VavaChat.RPC = {
    SEND = 'vava_chat:send',       -- (genre, texte, numéro de joueur | 0, conversation | 0)
    PROFILE = 'vava_chat:profile', -- apparition, redémarrage, rang changé : { chat, staff, rank?, commands, suggestions }
}

-- Genres de message. SYSTEM : messages des autres ressources et du royaume (jamais envoyé par un joueur).
VavaChat.KINDS = { OOC = 'ooc', ME = 'me', DO = 'do', MP = 'mp', STAFF = 'staff', SYSTEM = 'system' }

-- Genres qu'un joueur peut envoyer (schéma du RPC).
VavaChat.SENDABLE = { 'ooc', 'me', 'do', 'mp', 'staff' }

-- Hooks déclenchés par le module.
VavaChat.HOOKS = {
    SENDING = 'vava_chat:sending', -- before : { source, characterId, kind, text, target? } — refus possible (sourdine…)
    SENT = 'vava_chat:sent',       -- after : { source, characterId, kind, text, target?, recipients }
}

-- Évènements de la ressource « chat » de FiveM, repris tels quels : les autres ressources n'ont rien à changer.
VavaChat.COMPAT = {
    ADD_MESSAGE = 'chat:addMessage',
    CHAT_MESSAGE = 'chatMessage',
    ADD_SUGGESTION = 'chat:addSuggestion',
    ADD_SUGGESTIONS = 'chat:addSuggestions',
    REMOVE_SUGGESTION = 'chat:removeSuggestion',
    ADD_TEMPLATE = 'chat:addTemplate',
    ADD_MODE = 'chat:addMode',
    REMOVE_MODE = 'chat:removeMode',
    CLEAR = 'chat:clear',
    SERVER_PRINT = '__cfx_internal:serverPrint',
    COMMAND_FALLBACK = '__cfx_internal:commandFallback',
}

-- Ressources liées (aucune n'est requise).
VavaChat.ADMIN = 'vava_admin'
VavaChat.ADMIN_ACTION = 'vava_admin:action'
VavaChat.STAFF_ACTIONS = { staffGrant = true, staffRevoke = true }
