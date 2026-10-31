--[[
    vava_world/client/audio.lua
    Rôle : sons de la ville moderne coupés chez chaque joueur : ambiance de circulation et de foule (scènes de
           mixage de GTA), véhicules lointains, sirènes au loin, radio de police, musiques d'avion et d'avis de
           recherche, émetteurs fixes choisis. Réglages persistants : posés au démarrage et à chaque apparition,
           jamais à chaque image ; une scène déjà active n'est pas relancée.
    Dépendances : config_client.lua
]]

local ipairs = ipairs
local StartAudioScene, IsAudioSceneActive, SetAudioFlag, SetStaticEmitterEnabled =
    StartAudioScene, IsAudioSceneActive, SetAudioFlag, SetStaticEmitterEnabled
local SetDistantCarsEnabled, DisableVehicleDistantlights, DistantCopCarSirens =
    SetDistantCarsEnabled, DisableVehicleDistantlights, DistantCopCarSirens

local cfg = VavaWorld.config.audio

local audio = {}
VavaWorld.audio = audio

function audio.apply()
    for _, scene in ipairs(cfg.scenes) do
        if not IsAudioSceneActive(scene) then StartAudioScene(scene) end
    end
    for _, flag in ipairs(cfg.flags) do SetAudioFlag(flag, true) end
    for _, emitter in ipairs(cfg.staticEmitters) do SetStaticEmitterEnabled(emitter, false) end
    SetDistantCarsEnabled(cfg.distantCars)
    DisableVehicleDistantlights(not cfg.distantCars)
    DistantCopCarSirens(cfg.distantSirens)
end
