--[[
    vava_chat/server/sessions.lua
    Rôle : joueurs dont le personnage est en jeu, vus par le chat : nom affiché, droits du Conseil, numéro de
           conversation et correspondants. Le numéro de conversation désigne un personnage en jeu le temps de sa
           présence ; il n'est jamais réutilisé tant que le serveur tourne : un onglet de message privé resté ouvert ne
           peut pas écrire à quelqu'un d'autre qui aurait repris le même numéro de joueur. Au départ d'un personnage,
           ses seuls correspondants en sont avertis (leur onglet se grise).
    Dépendances : shared/constants.lua, server/core.lua, server/links.lua
]]

local pairs = pairs
local TriggerClientEvent = TriggerClientEvent

local links = VavaChat.links
local EVENTS = VavaChat.EVENTS

---@class vAvA.ChatSession
---@field source integer
---@field characterId integer
---@field chat integer                    numéro de conversation
---@field name string                     prénom nom du personnage
---@field staff boolean                   membre du Conseil
---@field rank string|nil                 libellé du rang (vava_admin)
---@field contacts table<integer, true>   sources des correspondants

local sessions = {}
VavaChat.sessions = sessions

---@type table<integer, vAvA.ChatSession>
local bySource = {}
---@type table<integer, integer>
local byChat = {}
local lastChat = 0

--- Personnage arrivé en jeu (ou déjà là au démarrage du module).
---@param src integer
---@param characterId integer
---@return vAvA.ChatSession|nil
function sessions.open(src, characterId)
    sessions.close(src)
    local name = links.characterName(src)
    if not name then return nil end
    lastChat = lastChat + 1
    local staff, rank = links.staff(src)
    local session = {
        source = src, characterId = characterId, chat = lastChat, name = name, staff = staff, rank = rank, contacts = {},
    }
    bySource[src] = session
    byChat[lastChat] = src
    return session
end

--- Départ du personnage (sélection, déconnexion) : ses correspondants en sont avertis.
---@param src integer
function sessions.close(src)
    local session = bySource[src]
    if not session then return end
    bySource[src] = nil
    byChat[session.chat] = nil
    for other in pairs(session.contacts) do
        local peer = bySource[other]
        if peer then
            peer.contacts[src] = nil
            TriggerClientEvent(EVENTS.GONE, other, session.chat)
        end
    end
end

---@param src integer
---@return vAvA.ChatSession|nil
function sessions.get(src)
    return bySource[src]
end

---@param chat integer
---@return vAvA.ChatSession|nil
function sessions.byChat(chat)
    local src = byChat[chat]
    return src and bySource[src] or nil
end

--- Sessions en cours, par source (ne pas modifier).
---@return table<integer, vAvA.ChatSession>
function sessions.all()
    return bySource
end

--- Deux joueurs ont échangé un message privé : chacun sera averti du départ de l'autre.
---@param a vAvA.ChatSession
---@param b vAvA.ChatSession
function sessions.link(a, b)
    a.contacts[b.source] = true
    b.contacts[a.source] = true
end

--- Droits du Conseil relus (rang donné ou retiré, vava_admin redémarré) ; le joueur est prévenu s'ils changent.
---@param src integer
function sessions.refreshStaff(src)
    local session = bySource[src]
    if not session then return end
    local staff, rank = links.staff(src)
    if staff == session.staff and rank == session.rank then return end
    session.staff, session.rank = staff, rank
    TriggerClientEvent(EVENTS.PROFILE, src, { staff = staff, rank = rank })
end

function sessions.refreshAllStaff()
    for src in pairs(bySource) do sessions.refreshStaff(src) end
end
