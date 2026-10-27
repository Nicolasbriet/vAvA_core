--[[
    vava_magic/client/hud.lua
    Rôle : barre de mana de la magie, dans la page du module : sort prêt dans les mains (icône, nom, niveau), mode
           magie éveillé ou endormi, incantation en cours. La page anime elle-même la remontée de la mana d'après le
           rythme reçu du serveur, et décide de se montrer (mana pas pleine, mode éveillé, ou juste après un sort) :
           rien n'est envoyé périodiquement, aucune boucle ici.
    Dépendances : shared/, config.lua, client/nui.lua, client/state.lua
]]

local nui = VavaMagic.nui
local state = VavaMagic.state
local cfg = VavaMagic.config
local hudCfg = cfg.mana.hud

local hud = {}
VavaMagic.hud = hud

local awake = false
-- dernière valeur envoyée, pour ne rien renvoyer d'identique
local sentSpell = nil

--- Sort prêt et mana, d'après l'état du client (à chaque changement de la fiche ou de la mana).
function hud.refresh()
    if not state.isMage() then
        sentSpell = nil
        nui.send('hud:hide')
        return
    end
    local name = state.selected()
    local spell = nil
    if name then
        local spellCfg = state.spellConfig(name)
        local element = spellCfg and cfg.elements[spellCfg.element]
        if spellCfg and element then
            spell = { name = name, label = spellCfg.label, icon = spellCfg.icon, level = state.level(name), color = element.color }
        end
    end
    local key = spell and (spell.name .. ':' .. spell.level) or ''
    if key ~= sentSpell then
        sentSpell = key
        nui.send('hud:spell', spell or {})
    end
end

--- Mana reçue du serveur : la page anime la remontée.
function hud.mana(value, max, points, period, elapsed)
    nui.send('hud:mana', { value = value, max = max, points = points, period = period, elapsed = elapsed })
end

--- Mode magie éveillé (barre visible même mana pleine) ou endormi.
---@param value boolean
function hud.setAwake(value)
    if awake == value then return end
    awake = value
    nui.send('hud:mode', { awake = value })
end

--- Juste après un sort : la barre reste un moment, même mana pleine.
function hud.flash()
    nui.send('hud:flash', { ms = hudCfg.lingerMs })
end

--- Incantation en cours : lueur de la barre.
---@param active boolean
function hud.casting(active)
    nui.send('hud:casting', { active = active })
end

--- La page s'est rechargée : tout est renvoyé.
function hud.resend()
    sentSpell = nil
    nui.send('hud:mode', { awake = awake })
    hud.refresh()
end

state.onChange(hud.refresh)
