--[[
    vava_codex/client/keys.lua
    Rôle : touche réellement liée par le joueur à une commande (RegisterKeyMapping), telle que le jeu l'affiche :
           la lettre pour le clavier (« L »), sinon le nom donné par la déclaration (« Clic droit », « Tab »).
           Permet à l'onglet Touches de montrer les touches du joueur et non les défauts.
    Dépendances : shared/constants.lua
]]

local type, match = type, string.match
local GetControlInstructionalButton, GetHashKey = GetControlInstructionalButton, GetHashKey

-- bit qui désigne, pour GTA, une commande liée par RegisterKeyMapping
local MAPPED_COMMAND = 0x80000000
local UINT32 = 0xFFFFFFFF

local keys = {}
VavaCodex.keys = keys

--- Touche du joueur pour une entrée de type touche : lettre lue dans le jeu, sinon `keyDisplay`, sinon `key`.
---@param entry { name: string, hold?: boolean, key?: string, keyDisplay?: string }
---@return string|nil
function keys.label(entry)
    if not entry.key then return nil end
    local command = entry.hold and ('+' .. entry.name) or entry.name
    local button = GetControlInstructionalButton(0, (GetHashKey(command) | MAPPED_COMMAND) & UINT32, true)
    if type(button) == 'string' then
        local letter = match(button, '^t_(.+)$')
        if letter then return letter end
    end
    return entry.keyDisplay or entry.key
end
