require "TimedActions/ISInsertMagazine"
require "TimedActions/ISEjectMagazine"
require 'MagazineBag_Core'

local AMMO_KEY = MagazineBag_Core.AMMO_KEY

local function CarriesMagazineAmmo(gun)
    return gun ~= nil and not MagazineBag_Core.LoadsLooseRounds(gun)
end

local function MoveAssignmentToMagazine(character, gun, magazine)
    magazine:getModData()[AMMO_KEY] = gun:getModData()[AMMO_KEY]
    gun:getModData()[AMMO_KEY] = nil
    MagazineBag_Core.SendAssignedAmmoToOwner(character, magazine)
    MagazineBag_Core.SendAssignedAmmoToOwner(character, gun)
end

local originalLoadAmmo = ISInsertMagazine.loadAmmo
function ISInsertMagazine:loadAmmo()
    if self.magazine and CarriesMagazineAmmo(self.gun) then
        self.gun:getModData()[AMMO_KEY] = self.magazine:getModData()[AMMO_KEY]
        MagazineBag_Core.SendAssignedAmmoToOwner(self.character, self.gun)
    end
    return originalLoadAmmo(self)
end

local originalUnloadAmmo = ISEjectMagazine.unloadAmmo
function ISEjectMagazine:unloadAmmo()
    local roundType = CarriesMagazineAmmo(self.gun) and self.gun:getModData()[AMMO_KEY]
    if not roundType then
        return originalUnloadAmmo(self)
    end

    local inventory = self.character:getInventory()
    local knownIds = {}
    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        knownIds[items:get(i):getID()] = true
    end

    local result = originalUnloadAmmo(self)

    items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if not knownIds[item:getID()] and (item:getMaxAmmo() or 0) > 0
                and not instanceof(item, "HandWeapon") then
            MoveAssignmentToMagazine(self.character, self.gun, item)
            return result
        end
    end

    self.gun:getModData()[AMMO_KEY] = nil
    MagazineBag_Core.SendAssignedAmmoToOwner(self.character, self.gun)

    return result
end

local function hookTacticalReloadDrop()
    if not getActivatedMods():contains("HBTacReload") then return end

    local SpentCasingPhysics = require("SpentCasingPhysics/Init")
    local original = SpentCasingPhysics and SpentCasingPhysics.doSpawnCasing
    if not original then return end

    SpentCasingPhysics.doSpawnCasing = function(player, weapon, params, racking, optionalItem, ignoreDespawn)
        if optionalItem and instanceof(optionalItem, "InventoryItem") and CarriesMagazineAmmo(weapon)
                and weapon:hasModData() and weapon:getModData()[AMMO_KEY] then
            MoveAssignmentToMagazine(player, weapon, optionalItem)
        end
        return original(player, weapon, params, racking, optionalItem, ignoreDespawn)
    end
end

Events.OnInitGlobalModData.Add(hookTacticalReloadDrop)
