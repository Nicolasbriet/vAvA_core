--[[
    vAvA_inventory - Shared Functions
]]

Inventory = Inventory or {}

-- Catégories d'items
Inventory.Categories = {
    weapon = { label = 'Armes', icon = 'fa-gun' },
    ammo = { label = 'Munitions', icon = 'fa-bullet' },
    consumable = { label = 'Consommables', icon = 'fa-utensils' },
    item = { label = 'Items', icon = 'fa-box' },
    tool = { label = 'Outils', icon = 'fa-wrench' },
    clothing = { label = 'Vêtements', icon = 'fa-shirt' }
}

-- Vérifie si un item est une arme
function Inventory.IsWeapon(itemName)
    if not itemName then return false end
    local name = string.lower(itemName)
    return string.find(name, 'weapon_') ~= nil or InventoryConfig.WeaponsList[name] ~= nil
end

-- Récupère les infos d'une arme
function Inventory.GetWeaponData(weaponName)
    if not weaponName then return nil end
    return InventoryConfig.WeaponsList[string.lower(weaponName)]
end

-- Récupère le type de munition pour une arme
function Inventory.GetAmmoType(weaponName)
    local weaponData = Inventory.GetWeaponData(weaponName)
    if weaponData then
        return weaponData.ammo
    end
    return nil
end

-- Vérifie si une arme utilise des munitions
function Inventory.WeaponNeedsAmmo(weaponName)
    local ammoType = Inventory.GetAmmoType(weaponName)
    return ammoType ~= nil
end

-- Obtient le hash d'une arme
function Inventory.GetWeaponHash(weaponName)
    return joaat(string.upper(weaponName))
end

-- Obtient le nom propre d'une arme depuis son hash
function Inventory.GetWeaponNameFromHash(hash)
    for name, _ in pairs(InventoryConfig.WeaponsList) do
        if joaat(string.upper(name)) == hash then
            return name
        end
    end
    return nil
end

-- Calcule le poids total d'un inventaire
function Inventory.CalculateWeight(items)
    local weight = 0
    if not items then return weight end
    
    for _, item in ipairs(items) do
        local itemWeight = item.weight or 0
        local amount = item.amount or 1
        weight = weight + (itemWeight * amount)
    end
    
    return weight
end

-- Vérifie si un item peut être stacké
function Inventory.CanStack(item)
    if not item then return false end
    if Inventory.IsWeapon(item.name) then return false end
    return not item.unique
end

-- Formate le poids pour affichage
function Inventory.FormatWeight(weight)
    if weight >= 1000 then
        return string.format("%.1f kg", weight / 1000)
    end
    return string.format("%d g", weight)
end
