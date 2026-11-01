local helper = require('tests.helper')

-- Chiffres des coups d'arme (vava_combat 1.4.0, T-155 § 7.1, § 7.2 et § 11.1) : règle pure weapons.wireAmount, contrôle
-- de config.numbers (checkEngine), et server/reactions.lua réel (reactions.after) avec des doublures : bridge (positions,
-- instances, proches d'une instance, envoi à une liste et envoi de proximité notés), issue imposée par la défense
-- réglable. Vérifie qui reçoit quoi : le montant aux seuls attaquant et cible désignés, l'esquive et l'absorbé à eux
-- seuls, les témoins comme en 1.3.0, jamais -1, jamais une liste vide, jamais hors de l'instance de l'attaquant.
describe('vava_combat : chiffres des coups', function()
    local weapons, reactions, cfg
    local positions, buckets, around, sent, near, imposed
    local A, B, C, D = 1, 2, 3, 4

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = copy(item) end
        return out
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        helper.loadAll({ 'modules/vava_combat/shared/constants.lua', 'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/weapons.lua' })
        cfg = VavaCombat.config
        weapons = VavaCombat.weapons
        -- A frappe B à 2 m ; C témoin à 10 m ; D à 50 m
        positions = { [A] = { 0, 0, 0 }, [B] = { 0, 2, 0 }, [C] = { 0, 10, 0 }, [D] = { 0, 50, 0 } }
        buckets, around, sent, near, imposed = {}, {}, {}, {}, nil
        VavaCombat.log = { warn = function() end, info = function() end }
        VavaCombat.defense = { takeOutcome = function() return imposed end }
        VavaCombat.bridge = {
            Timer = function() return 1000 end,
            Notify = function() end,
            Bucket = function(src) return buckets[src] or 0 end,
            Position = function(src)
                local p = positions[src]
                if not p then return nil end
                return p[1], p[2], p[3]
            end,
            PlayersAround = function(bucket, coords, radius)
                around[#around + 1] = { bucket = bucket, coords = copy(coords), radius = radius }
                local out = {}
                for id, p in pairs(positions) do
                    local dx, dy, dz = p[1] - coords.x, p[2] - coords.y, p[3] - coords.z
                    if (buckets[id] or 0) == bucket and dx * dx + dy * dy + dz * dz <= radius * radius then
                        out[#out + 1] = id
                    end
                end
                table.sort(out)
                return out
            end,
            SendTo = function(list, event, ...)
                assert.is_true(#list >= 1, 'liste vide envoyée')
                for _, id in ipairs(list) do assert.is_true(math.type(id) == 'integer' and id > 0) end
                sent[#sent + 1] = { list = copy(list), event = event, args = table.pack(...) }
                return true
            end,
            SendNear = function(bucket, coords, radius, event, ...)
                near[#near + 1] = { bucket = bucket, coords = copy(coords), radius = radius, event = event,
                    args = table.pack(...) }
                return true
            end,
        }
        helper.load('modules/vava_combat/server/reactions.lua')
        reactions = VavaCombat.reactions
    end)

    after_each(function() VavaCombat = nil end)

    local function strike(result, staggers)
        sent, near = {}, {}
        return reactions.after({ source = A, def = { staggers = staggers == true } }, B, result)
    end

    local function hit(amount, extra)
        local result = { id = 1, amount = amount, applied = amount, blocked = 0, absorbed = 0, resisted = 0, added = 0,
            downed = false }
        for key, value in pairs(extra or {}) do result[key] = value end
        return result
    end

    --- Envoi noté réduit à { liste, valeurs } (n compris : une 4e valeur absente se voit).
    local function shape(entry)
        return { list = entry.list, n = entry.args.n, args = { table.unpack(entry.args, 1, entry.args.n) } }
    end

    describe('weapons.wireAmount', function()
        it('dixièmes arrondis, bornés à 2 000 ; 0 permis pour un coup qui porte', function()
            assert.equal(120, weapons.wireAmount({ amount = 12 }, 'hit'))
            assert.equal(72, weapons.wireAmount({ amount = 7.24 }, 'hit'))
            assert.equal(180, weapons.wireAmount({ amount = 18 }, 'down'))
            assert.equal(216, weapons.wireAmount({ amount = 21.6 }, 'stagger'))
            assert.equal(0, weapons.wireAmount({ amount = 0 }, 'hit'))
            assert.equal(2000, weapons.wireAmount({ amount = 250 }, 'hit'))
        end)

        it('bloqué, garde brisée : le reste, rien s\'il est nul', function()
            assert.is_nil(weapons.wireAmount({ amount = 0 }, 'block'))
            assert.equal(72, weapons.wireAmount({ amount = 7.2 }, 'block'))
            assert.is_nil(weapons.wireAmount({ amount = 0 }, 'break'))
            assert.equal(40, weapons.wireAmount({ amount = 4 }, 'break'))
        end)

        it('paré, esquivé, absorbé, issue inconnue, montant illisible : rien', function()
            for _, issue in ipairs({ 'parry', 'dodge', 'absorb', 'heal' }) do
                assert.is_nil(weapons.wireAmount({ amount = 12 }, issue))
            end
            for _, bad in ipairs({ 0 / 0, -1, math.huge, '12' }) do
                assert.is_nil(weapons.wireAmount({ amount = bad }, 'hit'))
            end
            assert.is_nil(weapons.wireAmount({}, 'hit'))
            assert.is_nil(weapons.wireAmount(nil, 'hit'))
        end)
    end)

    describe('checkEngine : numbers', function()
        it('la config livrée passe ; sans witnesses, clé inconnue, valeur non booléenne : refus avec la raison', function()
            assert.same({ true }, { weapons.checkEngine(cfg) })
            cfg.numbers.witnesses = nil
            local ok, err = weapons.checkEngine(cfg)
            assert.is_false(ok)
            assert.matches('numbers.witnesses', err)
            cfg.numbers.witnesses, cfg.numbers.everyone = false, true
            ok, err = weapons.checkEngine(cfg)
            assert.is_false(ok)
            assert.matches('everyone', err)
            cfg.numbers.everyone, cfg.numbers.enabled = nil, 'oui'
            ok, err = weapons.checkEngine(cfg)
            assert.is_false(ok)
            assert.matches('numbers.enabled', err)
            cfg.numbers = nil
            assert.is_false((weapons.checkEngine(cfg)))
        end)
    end)

    describe('reactions.after : destinataires', function()
        it('A frappe B, C témoin : {A, B} avec le montant, {C} sans ; D à 50 m rien', function()
            assert.equal('hit', strike(hit(12)))
            assert.equal(2, #sent)
            assert.same({ list = { A, B }, n = 4, args = { A, B, 'hit', 120 } }, shape(sent[1]))
            assert.same({ list = { C }, n = 3, args = { A, B, 'hit' } }, shape(sent[2]))
            assert.same({ bucket = 0, coords = { x = 0, y = 2, z = 0 }, radius = cfg.reactions.radius }, around[1])
            assert.equal(0, #near)
        end)

        it('aucun témoin : un seul envoi', function()
            positions[C] = nil
            strike(hit(12))
            assert.equal(1, #sent)
            assert.same({ A, B }, sent[1].list)
        end)

        it('esquive, absorbé : le mot aux deux seuls participants, rien au témoin', function()
            assert.equal('dodge', strike({ id = 1, amount = 0, applied = 0, cancelled = 'esquive', stage = 'esquive' }))
            assert.equal(1, #sent)
            assert.same({ list = { A, B }, n = 4, args = { A, B, 'dodge', false } }, shape(sent[1]))
            assert.equal('absorb', strike({ id = 2, amount = 0, applied = 0, cancelled = 'egide', stage = 'bouclier' }))
            assert.same({ list = { A, B }, n = 4, args = { A, B, 'absorb', false } }, shape(sent[1]))
            assert.equal(1, #sent)
            strike(hit(0, { applied = 0, absorbed = 12 }))
            assert.same({ list = { A, B }, n = 4, args = { A, B, 'absorb', false } }, shape(sent[1]))
            assert.equal(1, #sent)
        end)

        it('paré : {A, B} à 4 valeurs sans montant, {C} à 3', function()
            imposed = 'parry'
            assert.equal('parry', strike({ id = 1, amount = 0, applied = 0, cancelled = 'parade', stage = 'parade' }))
            assert.same({ list = { A, B }, n = 4, args = { A, B, 'parry', false } }, shape(sent[1]))
            assert.same({ list = { C }, n = 3, args = { A, B, 'parry' } }, shape(sent[2]))
        end)

        it('bloqué : le reste ; garde brisée ; chancelle ; à terre', function()
            imposed = 'block'
            strike(hit(7.2, { blocked = 4.8 }))
            assert.same({ A, B, 'block', 72 }, { table.unpack(sent[1].args, 1, 4) })
            strike(hit(0, { applied = 0, blocked = 12 }))
            assert.same({ list = { A, B }, n = 4, args = { A, B, 'block', false } }, shape(sent[1]))
            imposed = 'break'
            strike(hit(4, { blocked = 8 }))
            assert.same({ A, B, 'break', 40 }, { table.unpack(sent[1].args, 1, 4) })
            imposed = nil
            assert.equal('stagger', strike(hit(21.6), true))
            assert.same({ A, B, 'stagger', 216 }, { table.unpack(sent[1].args, 1, 4) })
            assert.same({ list = { C }, n = 3, args = { A, B, 'stagger' } }, shape(sent[2]))
            -- à terre : le montant du coup, jamais la vie retirée
            strike(hit(18, { applied = 3, downed = true }))
            assert.same({ A, B, 'down', 180 }, { table.unpack(sent[1].args, 1, 4) })
        end)

        it('attacker = false : {B} à 4 valeurs, A avec les témoins à 3 ; une esquive : {B} seul', function()
            cfg.numbers.attacker = false
            strike(hit(12))
            assert.same({ list = { B }, n = 4, args = { A, B, 'hit', 120 } }, shape(sent[1]))
            assert.same({ list = { A, C }, n = 3, args = { A, B, 'hit' } }, shape(sent[2]))
            strike({ id = 1, amount = 0, applied = 0, cancelled = 'esquive', stage = 'esquive' })
            assert.equal(1, #sent)
            assert.same({ list = { B }, n = 4, args = { A, B, 'dodge', false } }, shape(sent[1]))
        end)

        it('target = false : {A} à 4 valeurs ; une esquive : {A} seul', function()
            cfg.numbers.target = false
            strike(hit(12))
            assert.same({ list = { A }, n = 4, args = { A, B, 'hit', 120 } }, shape(sent[1]))
            assert.same({ list = { B, C }, n = 3, args = { A, B, 'hit' } }, shape(sent[2]))
            strike({ id = 1, amount = 0, applied = 0, cancelled = 'esquive', stage = 'esquive' })
            assert.same({ list = { A }, n = 4, args = { A, B, 'dodge', false } }, shape(sent[1]))
            assert.equal(1, #sent)
        end)

        it('witnesses = true : {A, B, C} en un envoi à 4 valeurs ; une esquive reste aux deux participants', function()
            cfg.numbers.witnesses = true
            strike(hit(12))
            assert.equal(1, #sent)
            assert.same({ list = { A, B, C }, n = 4, args = { A, B, 'hit', 120 } }, shape(sent[1]))
            strike({ id = 1, amount = 0, applied = 0, cancelled = 'esquive', stage = 'esquive' })
            assert.same({ A, B }, sent[1].list)
            assert.equal(1, #sent)
        end)

        it('enabled = false : un envoi de proximité à 3 valeurs, rien pour une esquive (1.3.0)', function()
            cfg.numbers.enabled = false
            strike(hit(12))
            assert.equal(0, #sent)
            assert.equal(1, #near)
            assert.same({ A, B, 'hit', n = 3 }, near[1].args)
            strike({ id = 1, amount = 0, applied = 0, cancelled = 'esquive', stage = 'esquive' })
            assert.equal(0, #near)
            assert.equal(0, #sent)
        end)

        it('A dans une autre instance : rien pour A, l\'envoi part dans l\'instance de l\'attaquant', function()
            buckets[A] = 3
            strike(hit(12))
            -- instance de A (3) : ni B ni C n'y sont ; A, à 2 m de B, y est seul
            assert.equal(3, around[1].bucket)
            assert.same({ { A } }, { sent[1].list })
            assert.equal(1, #sent)
            buckets[B], buckets[C] = 3, 0
            strike(hit(12))
            assert.same({ A, B }, sent[1].list)
            assert.equal(1, #sent)
            -- attaquant hors de l'instance où sont B et C : aucun des deux ne reçoit
            buckets[A], buckets[B], buckets[C] = 5, 0, 0
            strike(hit(12))
            for _, entry in ipairs(sent) do
                for _, id in ipairs(entry.list) do assert.equal(A, id) end
            end
        end)

        it('coup retenu, annulé avant la cible, résultat illisible : rien envoyé', function()
            assert.is_nil(strike({ id = 1, amount = 0, applied = 0, cancelled = 'pvp_off' }))
            assert.is_nil(strike({ id = 1, amount = 0, applied = 0, cancelled = 'zone_protegee', stage = 'annulation' }))
            assert.is_nil(strike(nil))
            assert.equal(0, #sent)
            assert.equal(0, #near)
        end)
    end)
end)
