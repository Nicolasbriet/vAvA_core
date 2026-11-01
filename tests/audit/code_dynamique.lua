--[[
    tests/audit/code_dynamique.lua
    Rôle : cas écrits pour `./scripts/audit-reseau.sh --essai` (jamais chargé, ni linté, ni audité en mode normal) :
           `load` de Lua hors des appels inscrits aux exceptions (T-157). Chaque ligne qui compte finit par ce que
           l'audit doit en dire. Un bloc de commentaire qui cite load(code) ne compte pas.  -- attendu: rien
]]

local store, obj = {}, {}
local f = load(code, '@@essai/x.lua', 't', env)  -- attendu: BLOQUANT
local g = load (code)  -- attendu: BLOQUANT
local ok = pcall(load, code)  -- attendu: BLOQUANT
local h = load  -- attendu: BLOQUANT
local i = _G.load  -- attendu: BLOQUANT
local j = _ENV['load']  -- attendu: BLOQUANT
local k = _G["load"](code)  -- attendu: BLOQUANT
local fn = load(chunk, '@@essai', 't', env)  -- attendu: rien
-- load(code) dans un commentaire  -- attendu: rien
local function load(x) return x end  -- attendu: rien
store.load(1)  -- attendu: rien
obj:load(2)  -- attendu: rien
local text = LoadResourceFile('vava_essai', 'x.lua')  -- attendu: rien
local reloaded = reload(3)  -- attendu: rien
local loaded = { 'load' }  -- attendu: rien

return f, g, ok, h, i, j, k, fn, text, reloaded, loaded
