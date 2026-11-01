-- Preuve de l'allègement du Lua livré (T-154, docs/plan/specs/T-154.md § 10.1 et § 12.3) : le comparateur
-- scripts/lib/meme-code.lua, chargé comme module. Il compile l'original et l'allégé par Lua 5.4 et compare les deux
-- fonctions, numéros de ligne compris (string.dump sans strip).

local ROOT = (os.getenv('VAVA_ROOT') or '.') .. '/'

describe('livraison : même code (scripts/lib/meme-code.lua)', function()
    local M

    before_each(function()
        M = dofile(ROOT .. 'scripts/lib/meme-code.lua')
    end)

    it('se charge comme module sans rien lancer', function()
        assert.is_table(M)
        assert.is_function(M.compare)
    end)

    it('accepte une paire identique hors commentaires et blancs de fin de ligne', function()
        local original = '-- en-tête\nlocal a = 1 -- note   \n--[[ bloc\n sur deux lignes ]]\nreturn a\n'
        local allege = '\nlocal a = 1\n\n\nreturn a\n'
        assert.is_true(M.compare(original, allege, 'essai.lua'))
    end)

    it('refuse deux lexèmes collés par le retrait d\'un commentaire', function()
        local same, reason = M.compare('local a, b = 1, 2\nlocal x = a--[[c]]or b\n', 'local a, b = 1, 2\nlocal x = aor b\n',
            'essai.lua')
        assert.is_false(same)
        assert.is_string(reason)
    end)

    it('refuse le même code décalé d\'une ligne', function()
        local same, reason = M.compare('local a = 1\nreturn a\n', '\nlocal a = 1\nreturn a\n', 'essai.lua')
        assert.is_false(same)
        assert.equal('numéros de ligne différents', reason)
    end)

    it('refuse une chaîne raccourcie', function()
        local same, reason = M.compare('return "a -- b"\n', 'return "a "\n', 'essai.lua')
        assert.is_false(same)
        assert.equal('code différent', reason)
    end)

    it('rend nil si l\'original ne se compile pas', function()
        local same, reason = M.compare('local = 1\n', 'local = 1\n', 'essai.lua')
        assert.is_nil(same)
        assert.truthy(reason:find('^original illisible : '))
    end)

    it('rend false si l\'allégé ne se compile pas', function()
        local same, reason = M.compare('local s = [[a]]\n', 'local s = [[a\n', 'essai.lua')
        assert.is_false(same)
        assert.truthy(reason:find('^allégé illisible : '))
    end)

    it('accepte un BOM et une première ligne #! des deux côtés, sans décaler les lignes', function()
        local bom = '\239\187\191'
        assert.is_true(M.compare(bom .. '-- c\nreturn 1\n', bom .. '\nreturn 1\n', 'essai.lua'))
        assert.is_true(M.compare('#!/usr/bin/lua\n-- c\nreturn 1\n', '#!/usr/bin/lua\n\nreturn 1\n', 'essai.lua'))
        assert.is_true(M.compare(bom .. '#!/usr/bin/lua\r\nreturn 1\r\n', bom .. '#!/usr/bin/lua\r\nreturn 1\r\n',
            'essai.lua'))
        local same = M.compare('#!/usr/bin/lua\nreturn 1\n', '#!/usr/bin/lua\n\nreturn 1\n', 'essai.lua')
        assert.is_false(same)
    end)

    it('compare aussi les lignes d\'une fonction (définition et fin)', function()
        local original = 'local function f(x)\n  return x --[[ long\n ]] end\nreturn f\n'
        assert.is_true(M.compare(original, 'local function f(x)\n  return x\n end\nreturn f\n', 'essai.lua'))
        -- `end` remonté d'une ligne : la ligne de fin de la fonction est dans le code compilé, même sans les lignes
        local same, reason = M.compare(original, 'local function f(x)\n  return x end\n\nreturn f\n', 'essai.lua')
        assert.is_false(same)
        assert.equal('code différent', reason)
    end)
end)
