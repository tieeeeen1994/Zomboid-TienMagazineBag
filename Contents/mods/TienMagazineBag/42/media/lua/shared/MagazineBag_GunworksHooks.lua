require 'MagazineBag_Core'

local function HoldsOnly(item, roundType)
    local ammoList = item:hasModData() and item:getModData().AmmoList
    if ammoList and #ammoList > 0 then
        for _, loaded in ipairs(ammoList) do
            if loaded ~= roundType then return false end
        end
        return true
    end

    local ammoType = item:getAmmoType()
    return ammoType ~= nil and ammoType:getItemKey() == roundType
end

local function GetGunAssignment(item)
    if instanceof(item, "HandWeapon") and not MagazineBag_Core.LoadsLooseRounds(item) then return nil end
    return MagazineBag_Core.GetAssignedAmmo(item)
end

local Ammo = MagazineBag_Core.RequireGunworks("Ammo")
if Ammo then
    local original = Ammo.GetAutomaticReloadAmmoType
    Ammo.GetAutomaticReloadAmmoType = function(playerObj, item)
        return item and GetGunAssignment(item) or original(playerObj, item)
    end
end

local SpeedLoader = MagazineBag_Core.RequireGunworks("SpeedLoader")
if SpeedLoader then
    local original = SpeedLoader.GetBestSpeedLoaderForGun
    SpeedLoader.GetBestSpeedLoaderForGun = function(playerObj, gun)
        local assigned = gun and GetGunAssignment(gun)
        if not assigned then return original(playerObj, gun) end

        local inventory = playerObj and playerObj:getInventory()
        if not inventory then return nil end

        for _, speedLoaderType in ipairs(SpeedLoader.GetSpeedLoaderTypesForGun(gun) or {}) do
            local items = inventory:getAllTypeRecurse(speedLoaderType)
            for i = 0, items:size() - 1 do
                local speedLoader = items:get(i)
                if speedLoader:getCurrentAmmoCount() > 0 and HoldsOnly(speedLoader, assigned) then
                    return speedLoader
                end
            end
        end

        return nil
    end
end
