MagazineBag_Core = {}

function MagazineBag_Core.AssignMagazineBag(player, item, value)
    if not item then return false end
    local modData = item:getModData()
    modData.isMagazineBag = value

    if player then
        if syncItemModData then
            syncItemModData(player, item)
        end
        if isClient() then
            sendClientCommand(player, "TienMagazineBag", "assignBag", { itemId = item:getID(), value = value })
        end
    end
end

function MagazineBag_Core.IsMagazineBag(item)
    if not item then return false end
    local modData = item:getModData()
    return modData.isMagazineBag or false
end

function MagazineBag_Core.HasMagazineWeapon(player)
    if not player then return false end

    local weapon = player:getPrimaryHandItem()
    return weapon and weapon:isRanged() and weapon.getMagazineType and weapon:getMagazineType()
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
    if not item or not MagazineBag_Core.HasMagazineWeapon(player) then return false end

    local weapon = player:getPrimaryHandItem()
    local weaponMagType = weapon:getMagazineType()
    if item:getType() == weaponMagType or item:getFullType() == weaponMagType then
        return true
    end
    local weaponMagTypeName = weaponMagType:find("%.") and weaponMagType:match("%.(.+)$") or weaponMagType

    return item:getType() == weaponMagTypeName
end

function MagazineBag_Core.GetAmmoItemType(player)
    if not MagazineBag_Core.HasAmmoWeapon(player) then return nil end

    local weapon = player:getPrimaryHandItem()
    local ammoType = weapon.getAmmoType and weapon:getAmmoType()

    return ammoType and ammoType:getItemKey() or nil
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
    local ammoItemType = MagazineBag_Core.GetAmmoItemType(player)

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineEmpty(item) then
                return true
            end
            if item:getFullType() == ammoItemType then
                return true
            end
        end
    end

    return false
end

function MagazineBag_Core.HasAmmoInInventory(player)
    if not MagazineBag_Core.HasMagazineWeapon(player) then return false end

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

function MagazineBag_Core.GetFetchableRoundType(player)
    if MagazineBag_Core.HasMagazineWeapon(player) then return nil end

    return MagazineBag_Core.GetAmmoItemType(player)
end

function MagazineBag_Core.HasFreshAmmoInBags(player)
    if not MagazineBag_Core.HasAmmoWeapon(player) then return false end

    local magazineBags = MagazineBag_Core.FindMagazineBags(player)
    local roundItemType = MagazineBag_Core.GetFetchableRoundType(player)

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
                    if item:getFullType() == roundItemType then
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
    if not MagazineBag_Core.HasMagazineWeapon(player) then return magazines end

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

function MagazineBag_Core.CountSpareBullets(player, magazine)
    local ammoType = magazine and magazine:getAmmoType()
    if not ammoType then return 0 end
    return player:getInventory():getItemCountRecurse(ammoType:getItemKey())
end

function MagazineBag_Core.HasReloadableMagazines(player)
    if not MagazineBag_Core.HasMagazineWeapon(player) then return false end

    local weapon = player:getPrimaryHandItem()

    if not weapon:isContainsClip() then
        return weapon:getBestMagazine(player) ~= nil
    end

    local magazines = MagazineBag_Core.FindReloadableMagazines(player)
    if #magazines > 0 and MagazineBag_Core.CountSpareBullets(player, magazines[1].magazine) > 0 then
        return true
    end

    if (weapon:getCurrentAmmoCount() or 0) < (weapon:getMaxAmmo() or 0) then
        if weapon:getBestMagazine(player) then return true end

        local ammoItemType = MagazineBag_Core.GetAmmoItemType(player)
        if ammoItemType and player:getInventory():getItemCountRecurse(ammoItemType) > 0 then
            return true
        end
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

function MagazineBag_Core.ReloadMagazines(player, pass)
    if not player then return end
    pass = pass or 1

    local isMagazineWeapon = MagazineBag_Core.HasMagazineWeapon(player)
    local weapon = isMagazineWeapon and player:getPrimaryHandItem() or nil

    if weapon and pass < 2 and weapon:isContainsClip()
            and (weapon:getCurrentAmmoCount() or 0) < (weapon:getMaxAmmo() or 0) then
        ISTimedActionQueue.add(ISEjectMagazine:new(player, weapon))
        ISTimedActionQueue.add(MagazineBag_ContinueReload:new(player, pass + 1))
        return
    end

    local magazines = MagazineBag_Core.FindReloadableMagazines(player)
    local playerInventory = player:getInventory()
    local magazineBags = MagazineBag_Core.FindMagazineBags(player)

    local reserved = {}
    for index = 1, #magazineBags do reserved[index] = 0 end

    local insertMagazine = nil
    local insertAlreadyInHand = false
    if weapon and not weapon:isContainsClip() then
        insertMagazine = weapon:getBestMagazine(player)
    end

    if #magazines > 0 then
        local bulletBudget = MagazineBag_Core.CountSpareBullets(player, magazines[1].magazine)
        local itemKey = magazines[1].magazine:getAmmoType():getItemKey()

        local totalNeeded = 0
        for _, entry in ipairs(magazines) do
            local magazine = entry.magazine
            totalNeeded = totalNeeded + math.max(0, (magazine:getMaxAmmo() or 0) - (magazine:getCurrentAmmoCount() or 0))
        end

        if bulletBudget > 0 then
            local bullets = playerInventory:getSomeTypeRecurse(itemKey, math.min(bulletBudget, totalNeeded))
            local taken = 0

            for _, entry in ipairs(magazines) do
                if taken >= bullets:size() then break end
                local magazine = entry.magazine
                local needed = (magazine:getMaxAmmo() or 0) - (magazine:getCurrentAmmoCount() or 0)
                if needed > 0 then
                    local toLoad = math.min(needed, bullets:size() - taken)

                    for _ = 1, toLoad do
                        local bullet = bullets:get(taken)
                        taken = taken + 1
                        if luautils.haveToBeTransfered(player, bullet) then
                            ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, bullet, bullet:getContainer(), playerInventory))
                        end
                    end

                    if entry.bagContainer then
                        ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, magazine, entry.bagContainer, playerInventory))
                    end
                    ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, magazine, toLoad))

                    if magazine == insertMagazine then
                        insertAlreadyInHand = true
                    elseif entry.bagContainer then
                        ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, magazine, playerInventory, entry.bagContainer))
                    else
                        StoreInBag(player, magazine, playerInventory, magazineBags, reserved)
                    end
                end
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

    local ammoItemType = MagazineBag_Core.GetAmmoItemType(player)
    if not ammoItemType then return end

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and item:getFullType() == ammoItemType then
            StoreInBag(player, item, inventory, magazineBags, reserved)
        end
    end
end

function MagazineBag_Core.FetchFreshAmmoFromBag(player)
    if not player then return end

    local magazineBags = MagazineBag_Core.FindMagazineBags(player)
    local playerInventory = player:getInventory()
    local roundItemType = MagazineBag_Core.GetFetchableRoundType(player)

    if #magazineBags == 0 then return end

    local unlimited = player:isUnlimitedCarry()
    local budget = playerInventory:getMaxWeight() - playerInventory:getCapacityWeight()
    local fetched = 0
    local added = 0

    for _, bag in ipairs(magazineBags) do
        local bagContainer = bag:getItemContainer()
        if bagContainer then
            local reduction = (bagContainer:getWeightReduction() or 0) / 100
            local bagItems = bagContainer:getItems()

            for i = bagItems:size() - 1, 0, -1 do
                local item = bagItems:get(i)
                local wanted = item and
                    ((MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineFull(item))
                        or item:getFullType() == roundItemType)

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

return MagazineBag_Core
