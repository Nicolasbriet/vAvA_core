local helper = require('tests.helper')

-- Baptême d'un chef-d'œuvre (modules/vava_crafting/server/signature.lua, signature.name) : le nom est rogné de ses
-- blancs ASCII de bord puis vérifié caractère par caractère (lettres et séparateurs de config.masterpiece).
-- T-133 : `%s` suit la locale du système ; sous Windows (cp1252), l'octet 0xA0 du « à » final passait pour un blanc,
-- le nom devenait de l'UTF-8 coupé et était refusé. Ces essais tournent sous une telle locale si le système en a une
-- (helper.legacyLocale) et échouent alors avec l'ancien code ; sinon, ils fixent la règle.
describe('vava_crafting signature : baptême', function()
    local signature, cfg, patched, previousLocale

    local SRC, INSTANCE, CHARACTER = 7, 41, 12

    before_each(function()
        -- sous une locale Windows à octet unique si le système en a une (helper.legacyLocale)
        previousLocale = helper.legacyLocale()
        helper.reset()
        VavaCrafting = nil
        helper.loadAll({ 'modules/vava_crafting/shared/constants.lua', 'modules/vava_crafting/config.lua' })
        patched = nil
        -- doublures des dépendances serveur : un artisan qui tient le chef-d'œuvre qu'il vient de créer
        VavaCrafting.bridge = {
            GetCharacterId = function() return CHARACTER end,
            Items = function()
                return { { id = INSTANCE, item = 'epee', metadata = { crafter_id = CHARACTER, quality = 95 } } }
            end,
            GetCharacterName = function() return 'Aldric Ferrand' end,
            PatchMetadata = function(_, _, patch) patched = patch return true end,
            Notify = function() end,
        }
        VavaCrafting.journal = { write = function() end }
        VavaCrafting.catalog = { itemLabel = function() return 'Épée' end }
        helper.load('modules/vava_crafting/server/signature.lua')
        signature, cfg = VavaCrafting.signature, VavaCrafting.config.masterpiece
    end)

    after_each(function()
        VavaCrafting = nil
        helper.restoreLocale(previousLocale)
    end)

    --- Baptise le chef-d'œuvre en attente : ok, code d'erreur, nom gardé.
    local function baptize(name)
        patched = nil
        signature.offerName(SRC, INSTANCE, 'Épée')
        local ok, code = signature.name(SRC, INSTANCE, name)
        return ok, code, patched and patched.name
    end

    it('rogne les blancs ASCII de bord et garde le nom', function()
        local ok, code, name = baptize(' \tDurandal \r\n')
        assert.is_true(ok, code)
        assert.equal('Durandal', name)
    end)

    it('chaque caractère de U+00A0 à U+017F et U+2010 : gardé entier s\'il est permis, sinon refusé', function()
        local allowed = {}
        for _, code in utf8.codes(cfg.nameLetters) do allowed[code] = true end
        local codes = {}
        for code = 0xA0, 0x17F do codes[#codes + 1] = code end
        codes[#codes + 1] = 0x2010
        for _, code in ipairs(codes) do
            local c, label = utf8.char(code), string.format('U+%04X', code)
            local ok, err, name = baptize(' Ab' .. c .. ' ')
            if allowed[code] then
                assert.is_true(ok, label .. ' ' .. tostring(err))
                assert.equal('Ab' .. c, name, label)
            else
                assert.is_false(ok, label)
                assert.equal('invalid_name', err, label)
            end
        end
        local ok, err = baptize('Ída l’Ýr')
        assert.is_false(ok, 'apostrophe typographique hors des séparateurs')
        assert.equal('invalid_name', err)
        local name
        ok, err, name = baptize('Ída Ýr-Là')
        assert.is_true(ok, err)
        assert.equal('Ída Ýr-Là', name)
    end)

    it('refuse un contrôle ASCII (0x00 à 0x1F, 0x7F) dans le nom', function()
        for b = 0, 127 do
            if b <= 31 or b == 127 then
                local ok, err = baptize('Dur' .. string.char(b) .. 'andal')
                assert.is_false(ok, string.format('0x%02X', b))
                assert.equal('invalid_name', err, string.format('0x%02X', b))
            end
        end
    end)
end)
