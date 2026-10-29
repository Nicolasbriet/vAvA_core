local helper = require('tests.helper')

describe('vAvA.lib.semver', function()
    local semver

    before_each(function()
        helper.reset()
        helper.loadAll({ 'shared/init.lua', 'shared/lib/semver.lua' })
        semver = vAvA.lib.semver
    end)

    it('lit une version valide', function()
        assert.same({ major = 1, minor = 2, patch = 3 }, semver.parse('1.2.3'))
    end)

    it('refuse les formats invalides', function()
        assert.is_nil(semver.parse('1.2'))
        assert.is_nil(semver.parse('v1.2.3'))
        assert.is_nil(semver.parse(123))
        assert.is_nil(semver.parse('99999999999999999999.0.0'))
    end)

    it('compare correctement', function()
        assert.equal(-1, semver.compare('0.6.0', '0.7.0'))
        assert.equal(1, semver.compare('1.10.0', '1.9.9'))
        assert.equal(0, semver.compare('2.4.0', '2.4.0'))
        assert.is_nil(semver.compare('x', '1.0.0'))
    end)

    it('vérifie une version minimale', function()
        assert.is_true(semver.satisfiesMin('0.7.0', '0.6.0'))
        assert.is_false(semver.satisfiesMin('0.5.9', '0.6.0'))
        assert.is_false(semver.satisfiesMin('bad', '0.6.0'))
    end)
end)
