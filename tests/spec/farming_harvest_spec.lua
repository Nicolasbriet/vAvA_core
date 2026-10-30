local helper = require('tests.helper')

-- Ordre de la récolte et de l'arrachage (modules/vava_farming/shared/growth.lua, appliqué par server/actions.lua,
-- T-029) : la plante est prise AVANT que la besace ne reçoive le produit, dont l'ajout peut céder la main ; un second
-- cultivateur qui finit le même geste trouve l'emplacement libre ; si la besace refuse, la plante est rendue telle
-- quelle (couverture contre le gel comprise), sauf si quelqu'un a semé entre-temps. Valeurs documentées : README du
-- module, § Gestes, et tableau « Règles » (fertilité : − coût de la culture, même famille − 10, autre famille + 10).

describe('vava_farming harvest order', function()
    local growth, cfg, STATES

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_farming/shared/constants.lua',
            'modules/vava_farming/config.lua',
            'modules/vava_farming/shared/growth.lua',
        })
        growth = VavaFarming.growth
        cfg = VavaFarming.config
        STATES = VavaFarming.STATES
    end)

    --- Plante de blé mûre (mêmes champs que slots.plant côté serveur), couverte contre le gel, plus les marques
    --- d'écriture du serveur (jamais copiées ni rendues).
    local function ripeWheat()
        local crop = cfg.crops.ble
        return {
            crop = 'ble', seedTier = 4, plantedAt = 1000, growth = crop.growMinutes * 60, moisture = 55, fertility = 80,
            drySince = nil, dryHours = 0.5, waterings = 3, wilted = false, dead = false, covered = true,
            lastFamily = 'racine', updatedAt = 9000, dirty = false, inflight = nil,
        }, crop
    end

    --- Ce que fait server/actions.lua à la fin d'une récolte : contrôle et prise sans céder la main, puis ajout (qui peut
    --- céder la main : `add` est appelé à ce moment), plante rendue si la besace refuse.
    local function finishHarvest(slot, crops, now, add)
        local crop = slot.crop and crops[slot.crop] or nil
        if not crop or growth.state(slot, crop) ~= STATES.RIPE then return false, 'not_found' end
        local taken = growth.snapshot(slot)
        growth.harvest(slot, crop, now)
        if not add() then
            growth.giveBack(slot, taken)
            return false, 'no_space'
        end
        return true
    end

    describe('prise avant l’ajout', function()
        it('vide l’emplacement avant que la besace ne reçoive le produit', function()
            local slot = ripeWheat()
            local seenDuringAdd
            local ok = finishHarvest(slot, cfg.crops, 10000, function()
                seenDuringAdd = slot.crop
                return true
            end)
            assert.is_true(ok)
            assert.is_nil(seenDuringAdd)
            assert.is_nil(slot.crop)
        end)

        it('ne sert qu’un des deux cultivateurs qui finissent la même plante (l’ajout du premier cède la main)', function()
            local slot = ripeWheat()
            local served = 0
            local second
            local ok = finishHarvest(slot, cfg.crops, 10000, function()
                -- pendant l'ajout du premier, le second finit son geste sur le même emplacement
                local ok2, code2 = finishHarvest(slot, cfg.crops, 10000, function()
                    served = served + 1
                    return true
                end)
                second = { ok2, code2 }
                served = served + 1
                return true
            end)
            assert.is_true(ok)
            assert.equal(1, served)
            assert.same({ false, 'not_found' }, second)
        end)

        it('ne sert qu’un des deux quand le premier est refusé par la besace : le second trouve l’emplacement vide '
            .. 'pendant l’attente, puis la plante revient pour un geste suivant', function()
            local slot = ripeWheat()
            local second
            local ok, code = finishHarvest(slot, cfg.crops, 10000, function()
                second = { finishHarvest(slot, cfg.crops, 10000, function() return true end) }
                return false
            end)
            assert.same({ false, 'no_space' }, { ok, code })
            assert.same({ false, 'not_found' }, second)
            assert.equal('ble', slot.crop)
            assert.equal(STATES.RIPE, growth.state(slot, cfg.crops.ble))
        end)
    end)

    describe('besace qui refuse', function()
        it('rend la plante telle quelle, couverture contre le gel, fertilité et famille comprises', function()
            local slot = ripeWheat()
            local before = growth.snapshot(slot)
            local ok, code = finishHarvest(slot, cfg.crops, 10000, function() return false end)
            assert.is_false(ok)
            assert.equal('no_space', code)
            assert.same(before, growth.snapshot(slot))
            assert.is_true(slot.covered)
            assert.equal(80, slot.fertility)
            assert.equal('racine', slot.lastFamily)
        end)

        it('ne touche pas aux marques d’écriture du serveur', function()
            local slot = ripeWheat()
            slot.dirty, slot.inflight = 'writing', true
            local taken = growth.snapshot(slot)
            assert.is_nil(taken.dirty)
            assert.is_nil(taken.inflight)
            growth.harvest(slot, cfg.crops.ble, 10000)
            assert.is_true(growth.giveBack(slot, taken))
            assert.equal('writing', slot.dirty)
            assert.is_true(slot.inflight)
        end)

        it('n’écrase jamais un semis fait entre-temps', function()
            local slot = ripeWheat()
            local taken = growth.snapshot(slot)
            growth.harvest(slot, cfg.crops.ble, 10000)
            slot.crop, slot.plantedAt, slot.seedTier = 'carotte', 10500, 2
            assert.is_false(growth.giveBack(slot, taken))
            assert.equal('carotte', slot.crop)
            assert.equal(10500, slot.plantedAt)
            assert.equal(2, slot.seedTier)
        end)

        it('refuse une copie absente', function()
            local slot = ripeWheat()
            growth.clear(slot, 10000)
            assert.is_false(growth.giveBack(slot, nil))
            assert.is_nil(slot.crop)
        end)

        it('garde une copie indépendante de l’emplacement', function()
            local slot = ripeWheat()
            local taken = growth.snapshot(slot)
            slot.fertility, slot.covered = 10, false
            assert.equal(80, taken.fertility)
            assert.is_true(taken.covered)
        end)
    end)

    describe('emplacement vidé', function()
        it('récolte : libre, découvert, fertilité payée (autre famille : 80 − 15 + 10), famille retenue', function()
            local slot, crop = ripeWheat()
            growth.harvest(slot, crop, 10000)
            assert.is_nil(slot.crop)
            assert.is_false(slot.covered)
            assert.is_false(slot.dead)
            assert.is_false(slot.wilted)
            assert.equal(0, slot.growth)
            assert.equal(0, slot.moisture)
            assert.equal(0, slot.waterings)
            assert.equal(0, slot.plantedAt)
            assert.equal(1, slot.seedTier)
            assert.equal(75, slot.fertility)
            assert.equal('cereale', slot.lastFamily)
            assert.equal(10000, slot.updatedAt)
        end)

        it('arrachage : libre et découvert, sans rien payer ni retenir', function()
            local slot = ripeWheat()
            slot.dead = true
            growth.clear(slot, 10000)
            assert.is_nil(slot.crop)
            assert.is_false(slot.covered)
            assert.is_false(slot.dead)
            assert.equal(80, slot.fertility)
            assert.equal('racine', slot.lastFamily)
            assert.equal(10000, slot.updatedAt)
        end)
    end)
end)
