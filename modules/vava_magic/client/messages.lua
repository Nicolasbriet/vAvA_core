--[[
    vava_magic/client/messages.lua
    Rôle : texte d'un refus (code renvoyé par le serveur, ou par une pré-vérification), et sa notification (un simple
           avis, pas un avertissement, pour ce qui n'est qu'une attente : le rengainement d'une arme).
    Dépendances : config_client.lua, bridge/client.lua
]]

local type, tostring = type, tostring

local bridge = VavaMagic.bridge
local errors = VavaMagic.config.texts.errors
-- codes dont le texte porte les secondes restantes (`extra`)
local WITH_SECONDS = { cooldown = true, offer_refused = true }
-- codes qui disent une attente, pas une faute : notification d'information
local GENTLE = { sheathing = true }

local messages = {}
VavaMagic.messages = messages

--- Texte d'un code de refus ; `extra` complète certains textes (secondes de recharge).
---@param code any
---@param extra any
---@return string
function messages.error(code, extra)
    local textOf = type(code) == 'string' and errors[code]
    if not textOf then return errors.unknown:format(tostring(code)) end
    if WITH_SECONDS[code] then return textOf:format(type(extra) == 'number' and extra or 0) end
    return textOf
end

---@param code any
---@param extra any
function messages.refuse(code, extra)
    bridge.Notify(messages.error(code, extra), GENTLE[code] and 'info' or 'warning')
end
