--[[
    tests/audit/code_dynamique.lua
    Rôle : cas écrits pour `./scripts/audit-reseau.sh --essai` (jamais chargé, ni linté, ni audité en mode normal) :
           code exécuté à la volée hors des lignes inscrites aux exceptions (T-157, relecture sécurité S-4). Chaque
           ligne qui compte finit par ce que l'audit doit en dire. Un bloc de commentaire qui cite load(code) ou
           dofile('x') ne compte pas.  -- attendu: rien
]]

local store, obj, x, fn, code, env, chunk = {}, {}, nil, nil, '', {}, ''
local f = load(code, '@@essai/x.lua', 't', env)  -- attendu: BLOQUANT
local g = load (code)  -- attendu: BLOQUANT
local ok = pcall(load, code)  -- attendu: BLOQUANT
local h = load  -- attendu: BLOQUANT
local i = _G.load  -- attendu: BLOQUANT
local j = _ENV['load']  -- attendu: BLOQUANT
local k = _G["load"](code)  -- attendu: BLOQUANT
-- cas de la relecture sécurité S-4
local a = rawget(_G, 'load')  -- attendu: BLOQUANT
local b = _G [ "load" ](code)  -- attendu: BLOQUANT
local c = _ENV.load(code)  -- attendu: BLOQUANT
local d = (load)(code)  -- attendu: BLOQUANT
local e = { load }  -- attendu: BLOQUANT
local s1 = select(1, load)  -- attendu: BLOQUANT
local g2 = _G['lo' .. 'ad']  -- attendu: BLOQUANT
local h2 = loadfile('x.lua')  -- attendu: BLOQUANT
local i2 = dofile('x.lua')  -- attendu: BLOQUANT
local i3 = loadstring('return 1')  -- attendu: BLOQUANT
local j2 = load  -- attendu: BLOQUANT
(code)
local k2 = x and load or nil  -- attendu: BLOQUANT
local l2 = load--[[c]](code)  -- attendu: BLOQUANT
local m2 = string.dump(fn)  -- attendu: rien
local n2 = _G  -- attendu: BLOQUANT
n2.load(code)  -- attendu: rien
local o2 = rawget(env, 'load')  -- attendu: BLOQUANT
local function load(z) return z end load(1)  -- attendu: BLOQUANT
local function load(z) return z end  -- attendu: rien
local s2 = "load(code)"  -- attendu: rien
local s3 = 'dofile et _G dans une phrase'  -- attendu: rien
local s4 = [[load(code)]]  -- attendu: rien
-- exception : seulement la ligne entière
local fn2 = load(chunk, '@@essai', 't', env)  -- attendu: rien
local fn3 = load(chunk, '@@essai', 't', env) or 1  -- attendu: BLOQUANT
-- load(code) dans un commentaire  -- attendu: rien
store.load(1)  -- attendu: rien
obj:load(2)  -- attendu: rien
local text = LoadResourceFile('vava_essai', 'x.lua')  -- attendu: rien
local reloaded = reload(3)  -- attendu: rien
local loaded = { 'chargé', 'loader', 'payload' }  -- attendu: rien
-- cas de la contre-relecture sécurité C-1
local g3 = debug.getregistry()[2]; g3.load(code)()  -- attendu: BLOQUANT
local _, env2 = debug.getupvalue(fn, 1); env2.load(code)()  -- attendu: BLOQUANT
package.loaded._G.load(code)()  -- attendu: BLOQUANT
local t2 = package.loaded['string']  -- attendu: BLOQUANT
local p2 = x._G  -- attendu: BLOQUANT
local d2 = debug  -- attendu: BLOQUANT
local traceback = debug.traceback  -- attendu: rien
local tb = xpcall(fn, debug.traceback)  -- attendu: rien
local samples = cfg.debug.logSamples  -- attendu: rien
local level = core.log.debug('debug et package dans une phrase')  -- attendu: rien

return f, g, ok, h, i, j, k, a, b, c, d, e, s1, g2, h2, i2, i3, j2, k2, l2, m2, o2, s2, s3, s4, fn2, fn3, text,
    reloaded, loaded, t2, p2, d2, traceback, tb, samples, level
