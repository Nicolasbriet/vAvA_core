--[[
    vava_world/client/main.lua
    Rôle : réglages du monde (population, sons) appliqués au démarrage du module et à chaque apparition du
           personnage (changement de modèle compris).
    Dépendances : shared/, config.lua, client/core.lua, client/population.lua, client/audio.lua
]]

local core = VavaWorld.core
if not core then return end

local population, audio = VavaWorld.population, VavaWorld.audio

local function apply()
    population.apply()
    audio.apply()
end

core.hooks.after('core:character:spawning', apply)

apply()
