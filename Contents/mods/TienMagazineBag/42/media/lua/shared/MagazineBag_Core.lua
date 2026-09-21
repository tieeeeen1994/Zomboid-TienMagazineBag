MagazineBag_Core = {}

MagazineBag_Core.AMMO_KEY = "MagazineBag_AmmoType"

local gunworksModules = {}

local function GetGunworks(name)
    if gunworksModules[name] == nil then
        gunworksModules[name] = getActivatedMods():contains("SWMG") and require("WeaponSystems/Utils/" .. name) or false
    end
    return gunworksModules[name] or nil
end

MagazineBag_Core.GetGunworks = GetGunworks

local function GetGunworksAmmo()
    return GetGunworks("Ammo")
end

local function SendModData(player, item, command, value)
    if not player then return end
    if isClient() then
        sendClientCommand(player, "TienMagazineBag", command, { itemId = item:getID(), value = value })
    end
end

function MagazineBag_Core.AssignMagazineBag(player, item, value)
    if not item then return false end
    local modData = item:getModData()
    modData.isMagazineBag = value

    SendModData(player, item, "assignBag", value)
end

function MagazineBag_Core.GetAmmoFamily(item)
    local Ammo = GetGunworksAmmo()
    if not Ammo or not item then return nil end

    local family = Ammo.GetFamilyForItem(item)
    if family then return family end

    local ammoType = item.getAmmoType and item:getAmmoType()
    local _, roundFamily = Ammo.FindBulletEntry(ammoType and ammoType:getItemKey())
    return roundFamily
end

function MagazineBag_Core.GetAmmoChoices(item)
    local family = MagazineBag_Core.GetAmmoFamily(item)
    return family and GetGunworksAmmo().GetBulletTypesForFamily(family) or nil
end

function MagazineBag_Core.GetAssignedAmmo(item)
    if not item or not item:hasModData() then return nil end
    local roundType = item:getModData()[MagazineBag_Core.AMMO_KEY]
    if not roundType then return nil end

    local family = MagazineBag_Core.GetAmmoFamily(item)
    if not family or not GetGunworksAmmo().FindBulletIndexInFamily(family, roundType) then return nil end

    return roundType
end

function MagazineBag_Core.AssignMagazineAmmo(player, magazine, roundType)
    if not magazine then return end
    magazine:getModData()[MagazineBag_Core.AMMO_KEY] = roundType

    SendModData(player, magazine, "assignAmmo", roundType)
end

function MagazineBag_Core.SendAssignedAmmoToOwner(character, item)
    if not isServer() or not character or not item then return end
    sendServerCommand(character, "TienMagazineBag", "syncAmmo",
        { itemId = item:getID(), value = item:getModData()[MagazineBag_Core.AMMO_KEY] })
end

function MagazineBag_Core.GetRoundDisplayName(roundType)
    local script = roundType and getScriptManager():FindItem(roundType)
    return script and script:getDisplayName() or roundType
end

function MagazineBag_Core.GetReloadRoundTypes(player, item)
    local assigned = MagazineBag_Core.GetAssignedAmmo(item)
    if assigned then return { assigned } end

    local family = MagazineBag_Core.GetAmmoFamily(item)
    if family then
        local gun = player and player:getPrimaryHandItem()
        if gun and gun ~= item and MagazineBag_Core.LoadsLooseRounds(gun)
                and MagazineBag_Core.GetAmmoFamily(gun) == family then
            local gunAssigned = MagazineBag_Core.GetAssignedAmmo(gun)
            if gunAssigned then return { gunAssigned } end
        end
        return GetGunworksAmmo().GetOrderedBulletTypesForFamily(player, family) or {}
    end

    local ammoType = item and item:getAmmoType()
    return ammoType and { ammoType:getItemKey() } or {}
end

function MagazineBag_Core.SetMagazineRoundType(magazine, roundType)
    local Ammo = GetGunworksAmmo()
    if Ammo and magazine and roundType then
        Ammo.MagazineAmmoProfileSetter(magazine, roundType)
    end
end

function MagazineBag_Core.IsMagazineBag(item)
    if not item then return false end
    local modData = item:getModData()
    return modData.isMagazineBag or false
end

local function GetRangedWeapon(player)
    local weapon = player and player:getPrimaryHandItem()
    if weapon and instanceof(weapon, "HandWeapon") and weapon:isRanged() then return weapon end
    return nil
end

local function GetProfileMagazineSet(weapon)
    local Magazine = GetGunworks("Magazine")
    local profile = Magazine and Magazine.GetProfileForGun(weapon)
    return profile and Magazine.ProfileMagazineSet[profile] or nil
end

local function GetSpeedLoaderTypes(weapon)
    local SpeedLoader = GetGunworks("SpeedLoader")
    local types = SpeedLoader and SpeedLoader.GetSpeedLoaderTypesForGun(weapon)
    return types and #types > 0 and types or nil
end

local function GetFeedKind(weapon)
    if not weapon then return nil end
    if GetProfileMagazineSet(weapon) then return "magazine" end
    if GetSpeedLoaderTypes(weapon) then return "speedloader" end
    if weapon:getMagazineType() then return "magazine" end
    return nil
end

function MagazineBag_Core.LoadsLooseRounds(item)
    return item ~= nil and instanceof(item, "HandWeapon") and item:isRanged() and GetFeedKind(item) ~= "magazine"
end

function MagazineBag_Core.HasMagazineWeapon(player)
    return GetFeedKind(GetRangedWeapon(player)) == "magazine"
end

function MagazineBag_Core.HasFeedWeapon(player)
    return GetFeedKind(GetRangedWeapon(player)) ~= nil
end

function MagazineBag_Core.HasSpeedLoaderWeapon(player)
    return GetFeedKind(GetRangedWeapon(player)) == "speedloader"
end

local function CanLoadGun(weapon)
    return not weapon:isJammed() and (weapon:getCurrentAmmoCount() or 0) < (weapon:getMaxAmmo() or 0)
end

local function RevolverHasRounds(player, revolver)
    if MagazineBag_Core.CountSpareBullets(player, revolver) > 0 then return true end
    return (revolver:getCurrentAmmoCount() or 0) == 0
        and GetGunworks("SpeedLoader").GetBestSpeedLoaderForGun(player, revolver) ~= nil
end

function MagazineBag_Core.GetBestMagazine(player, weapon)
    if GetProfileMagazineSet(weapon) then
        return GetGunworks("Magazine").getBestMagazineForGun(player, weapon)
    end
    return weapon:getBestMagazine(player)
end

function MagazineBag_Core.HasAmmoWeapon(player)
    if not player then return false end

    local weapon = player:getPrimaryHandItem()
    return weapon and weapon:isRanged() and weapon.getAmmoType and weapon:getAmmoType() ~= nil
end

function MagazineBag_Core.FindMagazineBags(player)
    local magazineBags = {}
    local wornItems = player:getWornItems()

    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:get(i)
        local item = wornItem:getItem()

        if item and MagazineBag_Core.IsMagazineBag(item) then
            table.insert(magazineBags, item)
        end
    end

    return magazineBags
end

function MagazineBag_Core.IsMagazine(item, player)
    local weapon = GetRangedWeapon(player)
    local kind = GetFeedKind(weapon)
    if not item or not kind then return false end

    local fullType = item:getFullType()

    if kind == "speedloader" then
        for _, speedLoaderType in ipairs(GetSpeedLoaderTypes(weapon)) do
            if fullType == speedLoaderType then return true end
        end
        return false
    end

    local profileSet = GetProfileMagazineSet(weapon)
    if profileSet and profileSet[fullType] then return true end

    local weaponMagType = weapon:getMagazineType()
    if not weaponMagType then return false end
    if item:getType() == weaponMagType or fullType == weaponMagType then
        return true
    end
    local weaponMagTypeName = weaponMagType:find("%.") and weaponMagType:match("%.(.+)$") or weaponMagType

    return item:getType() == weaponMagTypeName
end

function MagazineBag_Core.GetWeaponRoundTypes(player)
    if not MagazineBag_Core.HasAmmoWeapon(player) then return {} end

    local weapon = player:getPrimaryHandItem()
    local family = MagazineBag_Core.GetAmmoFamily(weapon)
    local familyTypes = family and GetGunworksAmmo().GetOrderedBulletTypesForFamily(player, family)
    if familyTypes and #familyTypes > 0 then return familyTypes end

    return { weapon:getAmmoType():getItemKey() }
end

local function ToSet(list)
    local set = {}
    for _, value in ipairs(list) do set[value] = true end
    return set
end

function MagazineBag_Core.IsMagazineEmpty(magazine)
    if not magazine then return false end
    local currentAmmo = magazine:getCurrentAmmoCount() or 0
    local maxAmmo = magazine:getMaxAmmo() or 0
    return currentAmmo < maxAmmo
end

function MagazineBag_Core.IsMagazineFull(magazine)
    if not magazine then return false end
    local currentAmmo = magazine:getCurrentAmmoCount() or 0
    local maxAmmo = magazine:getMaxAmmo() or 0
    return currentAmmo >= maxAmmo
end

function MagazineBag_Core.HasSpentAmmoInInventory(player)
    if not MagazineBag_Core.HasAmmoWeapon(player) then return false end

    local inventory = player:getInventory()
    local items = inventory:getItems()
    local roundTypes = ToSet(MagazineBag_Core.GetWeaponRoundTypes(player))

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineEmpty(item) then
                return true
            end
            if roundTypes[item:getFullType()] then
                return true
            end
        end
    end

    return false
end

function MagazineBag_Core.HasAmmoInInventory(player)
    if not MagazineBag_Core.HasFeedWeapon(player) then return false end

    local inventory = player:getInventory()
    local items = inventory:getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and MagazineBag_Core.IsMagazine(item, player) then
            return true
        end
    end

    return false
end

local function GetFetchableRoundList(player)
    if MagazineBag_Core.HasMagazineWeapon(player) then return {} end

    local assigned = MagazineBag_Core.GetAssignedAmmo(GetRangedWeapon(player))
    if assigned then return { assigned } end

    return MagazineBag_Core.GetWeaponRoundTypes(player)
end

function MagazineBag_Core.GetFetchableRoundTypes(player)
    return ToSet(GetFetchableRoundList(player))
end

function MagazineBag_Core.GetFetchDemands(player)
    local weapon = GetRangedWeapon(player)
    if not weapon or not MagazineBag_Core.HasAmmoWeapon(player) or MagazineBag_Core.HasMagazineWeapon(player) then
        return {}
    end
    return { { needed = weapon:getMaxAmmo() or 0, roundTypes = GetFetchableRoundList(player) } }
end

function MagazineBag_Core.HasFreshAmmoInBags(player)
    if not MagazineBag_Core.HasAmmoWeapon(player) then return false end

    local magazineBags = MagazineBag_Core.FindMagazineBags(player)
    local roundTypes = MagazineBag_Core.GetFetchableRoundTypes(player)

    for _, bag in ipairs(magazineBags) do
        local bagContainer = bag:getItemContainer()
        if bagContainer then
            local bagItems = bagContainer:getItems()

            for i = 0, bagItems:size() - 1 do
                local item = bagItems:get(i)
                if item then
                    if MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineFull(item) then
                        return true
                    end
                    if roundTypes[item:getFullType()] then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function MagazineBag_Core.FindReloadableMagazines(player)
    local magazines = {}
    if not MagazineBag_Core.HasFeedWeapon(player) then return magazines end

    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineEmpty(item) then
            table.insert(magazines, { magazine = item, bagContainer = nil })
        end
    end

    for _, bag in ipairs(MagazineBag_Core.FindMagazineBags(player)) do
        local bagContainer = bag:getItemContainer()
        if bagContainer then
            local bagItems = bagContainer:getItems()
            for i = 0, bagItems:size() - 1 do
                local item = bagItems:get(i)
                if item and MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineEmpty(item) then
                    table.insert(magazines, { magazine = item, bagContainer = bagContainer })
                end
            end
        end
    end

    return magazines
end

function MagazineBag_Core.CountSpareBullets(player, item)
    local inventory = player:getInventory()
    local count = 0
    for _, roundType in ipairs(MagazineBag_Core.GetReloadRoundTypes(player, item)) do
        count = count + inventory:getItemCountRecurse(roundType)
    end
    return count
end

function MagazineBag_Core.HasReloadableMagazines(player)
    if not MagazineBag_Core.HasFeedWeapon(player) then return false end

    local weapon = player:getPrimaryHandItem()
    local isMagazineWeapon = MagazineBag_Core.HasMagazineWeapon(player)

    if isMagazineWeapon and not weapon:isContainsClip() then
        return MagazineBag_Core.GetBestMagazine(player, weapon) ~= nil
    end

    for _, entry in ipairs(MagazineBag_Core.FindReloadableMagazines(player)) do
        if MagazineBag_Core.CountSpareBullets(player, entry.magazine) > 0 then
            return true
        end
    end

    if isMagazineWeapon and (weapon:getCurrentAmmoCount() or 0) < (weapon:getMaxAmmo() or 0) then
        if MagazineBag_Core.GetBestMagazine(player, weapon) then return true end
        if MagazineBag_Core.CountSpareBullets(player, weapon) > 0 then return true end
    end

    if not isMagazineWeapon and CanLoadGun(weapon) and RevolverHasRounds(player, weapon) then
        return true
    end

    return false
end

local function StoreInBag(player, item, inventory, magazineBags, reserved)
    local weight = item:getActualWeight()

    for index, bag in ipairs(magazineBags) do
        local bagContainer = bag:getItemContainer()
        if bagContainer and bagContainer:isItemAllowed(item)
                and bagContainer:hasRoomFor(player, reserved[index] + weight) then
            reserved[index] = reserved[index] + weight
            ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, item, inventory, bagContainer))
            return
        end
    end
end

function MagazineBag_Core.GetReloadDemands(player)
    local demands = {}

    local function add(item, needed)
        if needed > 0 then
            table.insert(demands, { needed = needed, roundTypes = MagazineBag_Core.GetReloadRoundTypes(player, item) })
        end
    end

    for _, entry in ipairs(MagazineBag_Core.FindReloadableMagazines(player)) do
        local magazine = entry.magazine
        add(magazine, (magazine:getMaxAmmo() or 0) - (magazine:getCurrentAmmoCount() or 0))
    end

    local weapon = GetRangedWeapon(player)
    if weapon and (MagazineBag_Core.HasSpeedLoaderWeapon(player)
            or (MagazineBag_Core.HasMagazineWeapon(player) and weapon:isContainsClip())) then
        add(weapon, (weapon:getMaxAmmo() or 0) - (weapon:getCurrentAmmoCount() or 0))
    end

    return demands
end

function MagazineBag_Core.HoldsOnly(item, roundType)
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

local function GetLastRound(weapon)
    local ammoList = weapon:hasModData() and weapon:getModData().AmmoList
    if weapon:isRoundChambered() and ammoList and #ammoList > 0 then
        return ammoList[#ammoList]
    end
    local ammoType = weapon:getAmmoType()
    return ammoType and ammoType:getItemKey()
end

local function EndsHoldingOnly(entry, roundType)
    if (entry.magazine:getCurrentAmmoCount() or 0) > 0 and not MagazineBag_Core.HoldsOnly(entry.magazine, roundType) then
        return false
    end
    for _, load in ipairs(entry.loads) do
        if load.roundType ~= roundType then return false end
    end
    return true
end

local function ChooseInsertMagazine(player, weapon, reloadable)
    local candidates = {}
    local planned = {}
    for _, entry in ipairs(reloadable) do
        planned[entry.magazine] = true
        table.insert(candidates, entry)
    end

    local function addFull(item)
        if item and not planned[item] and MagazineBag_Core.IsMagazine(item, player) then
            table.insert(candidates, { magazine = item, loads = {} })
        end
    end

    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do addFull(items:get(i)) end
    for _, bag in ipairs(MagazineBag_Core.FindMagazineBags(player)) do
        local bagContainer = bag:getItemContainer()
        if bagContainer then
            local bagItems = bagContainer:getItems()
            for i = 0, bagItems:size() - 1 do addFull(bagItems:get(i)) end
        end
    end

    local lastRound = GetLastRound(weapon)
    local best, bestKey = nil, nil

    for _, entry in ipairs(candidates) do
        local rounds = entry.magazine:getCurrentAmmoCount() or 0
        for _, load in ipairs(entry.loads) do rounds = rounds + load.count end

        if rounds > 0 then
            local capacity = entry.magazine:getMaxAmmo() or 0
            local matches = lastRound and EndsHoldingOnly(entry, lastRound)
            local key = matches and { 1, rounds, capacity } or { 0, capacity, rounds }

            local better = not bestKey
            if not better then
                for k = 1, 3 do
                    if key[k] ~= bestKey[k] then better = key[k] > bestKey[k]; break end
                end
            end
            if better then best, bestKey = entry.magazine, key end
        end
    end

    return best
end

function MagazineBag_Core.ReloadMagazines(player, pass, openedBoxes)
    if not player then return end
    pass = pass or 1

    local isMagazineWeapon = MagazineBag_Core.HasMagazineWeapon(player)
    local weapon = isMagazineWeapon and player:getPrimaryHandItem() or nil

    if weapon and pass < 2 and weapon:isContainsClip()
            and (weapon:getCurrentAmmoCount() or 0) < (weapon:getMaxAmmo() or 0) then
        ISTimedActionQueue.add(ISEjectMagazine:new(player, weapon))
        ISTimedActionQueue.add(MagazineBag_ContinueReload:new(player, pass + 1, openedBoxes))
        return
    end

    local revolver = MagazineBag_Core.HasSpeedLoaderWeapon(player) and player:getPrimaryHandItem() or nil
    if revolver and pass < 2 and CanLoadGun(revolver) then
        if openedBoxes and not RevolverHasRounds(player, revolver) then
            local demand = {
                needed = (revolver:getMaxAmmo() or 0) - (revolver:getCurrentAmmoCount() or 0),
                roundTypes = MagazineBag_Core.GetReloadRoundTypes(player, revolver),
            }
            local boxId = MagazineBag_Boxes.OpenOne(player, { demand }, openedBoxes)
            if boxId then
                openedBoxes[boxId] = true
                ISTimedActionQueue.add(MagazineBag_ContinueReload:new(player, pass, openedBoxes))
                return
            end
        end

        ISReloadWeaponAction.BeginAutomaticReload(player, revolver)
        ISTimedActionQueue.add(MagazineBag_ContinueReload:new(player, pass + 1, openedBoxes))
        return
    end

    local magazines = MagazineBag_Core.FindReloadableMagazines(player)
    local playerInventory = player:getInventory()
    local magazineBags = MagazineBag_Core.FindMagazineBags(player)

    local reserved = {}
    for index = 1, #magazineBags do reserved[index] = 0 end

    local neededByType = {}
    for _, entry in ipairs(magazines) do
        local magazine = entry.magazine
        entry.needed = math.max(0, (magazine:getMaxAmmo() or 0) - (magazine:getCurrentAmmoCount() or 0))
        entry.roundTypes = MagazineBag_Core.GetReloadRoundTypes(player, magazine)
        for _, roundType in ipairs(entry.roundTypes) do
            neededByType[roundType] = (neededByType[roundType] or 0) + entry.needed
        end
    end

    local pools = {}
    for roundType, needed in pairs(neededByType) do
        if needed > 0 then
            pools[roundType] = { bullets = playerInventory:getSomeTypeRecurse(roundType, needed), taken = 0 }
        end
    end

    for _, entry in ipairs(magazines) do
        local needed = entry.needed
        entry.loads = {}
        entry.bullets = {}

        for _, roundType in ipairs(entry.roundTypes) do
            if needed <= 0 then break end
            local pool = pools[roundType]
            local toLoad = pool and math.min(needed, pool.bullets:size() - pool.taken) or 0

            if toLoad > 0 then
                for _ = 1, toLoad do
                    table.insert(entry.bullets, pool.bullets:get(pool.taken))
                    pool.taken = pool.taken + 1
                end
                needed = needed - toLoad
                table.insert(entry.loads, { roundType = roundType, count = toLoad })
            end
        end
    end

    local shortfall = {}
    if openedBoxes then
        for _, entry in ipairs(magazines) do
            local short = entry.needed
            for _, load in ipairs(entry.loads) do short = short - load.count end
            if short > 0 then
                table.insert(shortfall, { needed = short, roundTypes = entry.roundTypes })
            end
        end
    end
    local moreBoxes = #shortfall > 0
        and MagazineBag_Boxes.Plan(player, shortfall, { looseUsed = true, skip = openedBoxes })[1] ~= nil

    local insertMagazine = nil
    local insertAlreadyInHand = false
    if weapon and not weapon:isContainsClip() and not moreBoxes then
        insertMagazine = ChooseInsertMagazine(player, weapon, magazines)
    end

    for _, entry in ipairs(magazines) do
        local magazine = entry.magazine

        if #entry.loads > 0 then
            for _, bullet in ipairs(entry.bullets) do
                if luautils.haveToBeTransfered(player, bullet) then
                    ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, bullet, bullet:getContainer(), playerInventory))
                end
            end

            if entry.bagContainer then
                ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, magazine, entry.bagContainer, playerInventory))
            end

            local ammoType = magazine:getAmmoType()
            local loadedType = ammoType and ammoType:getItemKey()
            for _, load in ipairs(entry.loads) do
                if load.roundType ~= loadedType then
                    ISTimedActionQueue.add(MagazineBag_SetAmmoType:new(player, magazine, load.roundType))
                    loadedType = load.roundType
                end
                ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, magazine, load.count))
            end

            if magazine == insertMagazine then
                insertAlreadyInHand = true
            elseif entry.bagContainer then
                ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, magazine, playerInventory, entry.bagContainer))
            else
                StoreInBag(player, magazine, playerInventory, magazineBags, reserved)
            end
        end
    end

    if insertMagazine then
        local container = insertMagazine:getContainer()
        if not insertAlreadyInHand and container and container ~= playerInventory then
            ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, insertMagazine, container, playerInventory))
        end
        ISTimedActionQueue.add(ISInsertMagazine:new(player, weapon, insertMagazine))
    end

    if moreBoxes then
        local boxId = MagazineBag_Boxes.OpenOne(player, shortfall, openedBoxes)
        if boxId then
            openedBoxes[boxId] = true
            ISTimedActionQueue.add(MagazineBag_ContinueReload:new(player, math.max(pass, 2), openedBoxes))
        end
    end
end

function MagazineBag_Core.FindBagForItem(player, item, exclude)
    if not player or not item then return nil end

    for _, bag in ipairs(MagazineBag_Core.FindMagazineBags(player)) do
        local bagContainer = bag:getItemContainer()
        if bagContainer and bagContainer ~= exclude
                and bagContainer:isItemAllowed(item)
                and bagContainer:hasRoomFor(player, item) then
            return bagContainer
        end
    end

    return nil
end

function MagazineBag_Core.StoreAmmoToBag(player, includeFull)
    if not player then return end

    local inventory = player:getInventory()
    local items = inventory:getItems()
    local magazineBags = MagazineBag_Core.FindMagazineBags(player)

    if #magazineBags == 0 then return end

    local reserved = {}
    for index = 1, #magazineBags do reserved[index] = 0 end

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and MagazineBag_Core.IsMagazine(item, player) and (includeFull or MagazineBag_Core.IsMagazineEmpty(item)) then
            StoreInBag(player, item, inventory, magazineBags, reserved)
        end
    end

    for _, roundType in ipairs(MagazineBag_Core.GetWeaponRoundTypes(player)) do
        for i = items:size() - 1, 0, -1 do
            local item = items:get(i)
            if item and item:getFullType() == roundType then
                StoreInBag(player, item, inventory, magazineBags, reserved)
            end
        end
    end
end

function MagazineBag_Core.FetchFreshAmmoFromBag(player, openBoxes)
    if not player then return end

    local magazineBags = MagazineBag_Core.FindMagazineBags(player)
    local playerInventory = player:getInventory()
    local roundTypes = MagazineBag_Core.GetFetchableRoundTypes(player)

    if #magazineBags == 0 then return end

    local unlimited = player:isUnlimitedCarry()
    local budget = playerInventory:getMaxWeight() - playerInventory:getCapacityWeight()
    local fetched = 0
    local added = 0

    for _, looseRounds in ipairs({ false, true }) do
        for _, bag in ipairs(magazineBags) do
            local bagContainer = bag:getItemContainer()
            if bagContainer then
                local reduction = (bagContainer:getWeightReduction() or 0) / 100
                local bagItems = bagContainer:getItems()

                for i = bagItems:size() - 1, 0, -1 do
                    local item = bagItems:get(i)
                    local wanted
                    if looseRounds then
                        wanted = item and roundTypes[item:getFullType()]
                    else
                        wanted = item and MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineFull(item)
                    end

                    if wanted then
                        local weight = item:getActualWeight()
                        local cost = weight * reduction
                        if (unlimited or added + cost <= budget)
                                and playerInventory:hasRoomFor(player, fetched + weight) then
                            fetched = fetched + weight
                            added = added + cost
                            ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, item, bagContainer, playerInventory))
                        end
                    end
                end
            end
        end
    end

    if openBoxes then
        MagazineBag_Boxes.Open(player, MagazineBag_Core.GetFetchDemands(player), not unlimited and (budget - added) or nil)
    end
end

return MagazineBag_Core
