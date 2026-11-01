--[[
    scripts/lib/meme-code.lua
    Rôle : preuve de l'allègement du Lua livré (T-154) par le compilateur Lua 5.4, indépendante du lexeur JavaScript
           (chancellerie/lib/luastrip.js) : l'original et l'allégé sont compilés ; les deux fonctions, numéros de ligne
           compris (string.dump sans strip), doivent être identiques à l'octet.
           Module (require, dofile sans argument) : M.compare(original, allege, chemin).
           Ligne de commande, depuis la racine du dépôt : lua scripts/lib/meme-code.lua <dossier> < sortie de
           `node scripts/livraison.js --essai <dossier>` ; « ÉCART chemin : raison » par écart, puis le bilan ; code 1
           au moindre écart.
    Dépendances : aucune (io, load, string.dump).
]]

local load, type, select, tostring = load, type, select, tostring
local dump, sub, find, format = string.dump, string.sub, string.find, string.format
local open, lines, write, exit = io.open, io.lines, io.write, os.exit
local concat = table.concat

local M = {}

-- Texte préparé comme par luaL_loadfile : BOM UTF-8 de tête retiré, première ligne commençant par `#` vidée (sa fin
-- de ligne gardée : les lignes ne bougent pas).
local function prepare(text)
    if sub(text, 1, 3) == '\239\187\191' then text = sub(text, 4) end
    if sub(text, 1, 1) == '#' then
        local stop = find(text, '\n', 1, true)
        text = stop and sub(text, stop) or ''
    end
    return text
end
M.prepare = prepare

--- Même code, mêmes lignes ? `nil, raison` si l'original ne se compile pas ; `false, raison` si l'allégé diffère.
---@param original string
---@param allege string
---@param chemin string
---@return boolean|nil same, string? reason
function M.compare(original, allege, chemin)
    local name = '@' .. tostring(chemin)
    local f1, err1 = load(prepare(original), name, 't')
    if not f1 then return nil, 'original illisible : ' .. tostring(err1) end
    local f2, err2 = load(prepare(allege), name, 't')
    if not f2 then return false, 'allégé illisible : ' .. tostring(err2) end
    if dump(f1) == dump(f2) then return true end
    if dump(f1, true) == dump(f2, true) then return false, 'numéros de ligne différents' end
    return false, 'code différent'
end

local function readFile(path)
    local handle = open(path, 'rb')
    if not handle then return nil end
    local text = handle:read('a')
    handle:close()
    return text
end

-- découpe d'une ligne de livraison.js --essai : genre, chemin, (ligne, raison)
local function fields(line)
    local out, start = {}, 1
    while true do
        local tab = find(line, '\t', start, true)
        if not tab then
            out[#out + 1] = sub(line, start)
            return out
        end
        out[#out + 1] = sub(line, start, tab - 1)
        start = tab + 1
    end
end

--- Preuve de toute une sortie de livraison.js --essai ; renvoie le code de sortie.
---@param dossier string
function M.run(dossier)
    local proved, delivered, gaps, skipped = 0, 0, 0, {}
    local function gap(path, reason)
        gaps = gaps + 1
        write(format('ÉCART %s : %s\n', path, reason))
    end
    for line in lines() do
        line = line:gsub('\r$', '')
        local f = fields(line)
        local kind, path = f[1], f[2]
        if (kind == 'livre' or kind == 'depot' or kind == 'refuse') and path and path ~= '' then
            local original = readFile(path)
            if not original then
                gap(path, 'original introuvable')
            elseif kind == 'refuse' then
                if load(prepare(original), '@' .. path, 't') then
                    gap(path, 'le lexeur refuse un fichier que Lua lit (ligne ' .. tostring(f[3]) .. ' : '
                        .. tostring(f[4]) .. ')')
                end
            else
                local allege = readFile(dossier .. '/' .. path)
                local same, reason
                if allege then same, reason = M.compare(original, allege, path) end
                if not allege then
                    gap(path, 'fichier allégé introuvable')
                elseif same then
                    proved = proved + 1
                    if kind == 'livre' then delivered = delivered + 1 end
                elseif same == nil and kind == 'depot' then
                    skipped[#skipped + 1] = path
                elseif same == nil then
                    gap(path, reason .. ' (livré : on ne livre pas ce qu\'on ne peut prouver)')
                else
                    gap(path, reason)
                end
            end
        end
    end
    local rest = #skipped > 0 and (' : ' .. concat(skipped, ', ')) or ''
    if gaps > 0 then
        write(format('MÊME CODE : ÉCHEC (%d écarts ; %d fichiers prouvés, dont %d livrés)\n', gaps, proved, delivered))
        return 1
    end
    if proved == 0 then
        write('MÊME CODE : ÉCHEC (aucun fichier lu sur l\'entrée)\n')
        return 1
    end
    write(format('MÊME CODE : OK (%d fichiers prouvés, dont %d livrés ; %d non compilables hors livraison%s)\n',
        proved, delivered, #skipped, rest))
    return 0
end

-- ligne de commande : `lua scripts/lib/meme-code.lua <dossier>` ; sinon (require, dofile) : le module
local first = select('#', ...) > 0 and select(1, ...) or nil
if type(arg) == 'table' and type(arg[0]) == 'string' and find(arg[0], 'meme%-code%.lua$') and arg[1]
    and first == arg[1] then
    exit(M.run(arg[1]))
end

return M
