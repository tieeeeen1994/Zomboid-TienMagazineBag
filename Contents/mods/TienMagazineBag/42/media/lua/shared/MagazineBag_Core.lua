MagazineBag_Core = {}

function MagazineBag_Core.AssignMagazineBag(player, item, value)
    if not item then return false end
    local modData = item:getModData()
    modData.isMagazineBag = value

    -- B42 MP: inventory is server-authoritative, so the server's copy of the
    -- item must get the flag too or the assignment is lost on logout
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

function MagazineBag_Core.HasValidWeapon(player)
    if not player then return false end

    local weapon = player:getPrimaryHandItem()
    return weapon and weapon:isRanged() and weapon.getMagazineType and weapon:getMagazineType()
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
    if not item or not MagazineBag_Core.HasValidWeapon(player) then return false end

    local weapon = player:getPrimaryHandItem()
    local weaponMagType = weapon:getMagazineType()
    -- B42 vanilla matches either the short type or the full type (see predicateNotFullMagazine)
    if item:getType() == weaponMagType or item:getFullType() == weaponMagType then
        return true
    end
    local weaponMagTypeName = weaponMagType:find("%.") and weaponMagType:match("%.(.+)$") or weaponMagType

    return item:getType() == weaponMagTypeName
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

function MagazineBag_Core.HasEmptyMagazinesInInventory(player)
    if not MagazineBag_Core.HasValidWeapon(player) then return false end

    local inventory = player:getInventory()
    local items = inventory:getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineEmpty(item) then
            return true
        end
    end

    return false
end

function MagazineBag_Core.HasMagazinesInInventory(player)
    if not MagazineBag_Core.HasValidWeapon(player) then return false end

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

function MagazineBag_Core.HasFullMagazinesInBags(player)
    if not MagazineBag_Core.HasValidWeapon(player) then return false end

    local magazineBags = MagazineBag_Core.FindMagazineBags(player)

    for _, bag in ipairs(magazineBags) do
        local bagContainer = bag:getItemContainer()
        if bagContainer then
            local bagItems = bagContainer:getItems()

            for i = 0, bagItems:size() - 1 do
                local item = bagItems:get(i)
                if item and MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineFull(item) then
                    return true
                end
            end
        end
    end

    return false
end

-- Non-full magazines for the held weapon, in reload priority order:
-- main inventory first, then each worn magazine bag
function MagazineBag_Core.FindReloadableMagazines(player)
    local magazines = {}
    if not MagazineBag_Core.HasValidWeapon(player) then return magazines end

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
    local magazines = MagazineBag_Core.FindReloadableMagazines(player)
    if #magazines == 0 then return false end
    return MagazineBag_Core.CountSpareBullets(player, magazines[1].magazine) > 0
end

function MagazineBag_Core.ReloadMagazines(player)
    if not player then return end

    local magazines = MagazineBag_Core.FindReloadableMagazines(player)
    if #magazines == 0 then return end

    local bulletBudget = MagazineBag_Core.CountSpareBullets(player, magazines[1].magazine)
    if bulletBudget <= 0 then return end

    local playerInventory = player:getInventory()
    local itemKey = magazines[1].magazine:getAmmoType():getItemKey()

    -- ISLoadBulletsInMagazine only takes bullets from the main inventory, so
    -- move everything we plan to load out of nested containers in one pass
    local totalNeeded = 0
    for _, entry in ipairs(magazines) do
        local magazine = entry.magazine
        totalNeeded = totalNeeded + math.max(0, (magazine:getMaxAmmo() or 0) - (magazine:getCurrentAmmoCount() or 0))
    end
    local bullets = playerInventory:getSomeTypeRecurse(itemKey, math.min(bulletBudget, totalNeeded))
    ISInventoryPaneContextMenu.transferIfNeeded(player, bullets)

    for _, entry in ipairs(magazines) do
        if bulletBudget <= 0 then break end
        local magazine = entry.magazine
        local needed = (magazine:getMaxAmmo() or 0) - (magazine:getCurrentAmmoCount() or 0)
        if needed > 0 and (not entry.bagContainer or playerInventory:hasRoomFor(player, magazine)) then
            local toLoad = math.min(needed, bulletBudget)
            bulletBudget = bulletBudget - toLoad

            -- bag magazines are pulled out to load (the action requires the
            -- main inventory), then returned to their bag
            if entry.bagContainer then
                ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, magazine, entry.bagContainer, playerInventory, "BoxOfRoundsOpenOne"))
            end
            ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, magazine, toLoad))
            if entry.bagContainer then
                ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, magazine, playerInventory, entry.bagContainer, "PutItemInBag"))
            end
        end
    end
end

function MagazineBag_Core.StoreAllMagazinesToBag(player, includeFull)
    if not player then return end

    local inventory = player:getInventory()
    local items = inventory:getItems()
    local magazineBags = MagazineBag_Core.FindMagazineBags(player)

    if #magazineBags == 0 then return end

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and MagazineBag_Core.IsMagazine(item, player) and (includeFull or MagazineBag_Core.IsMagazineEmpty(item)) then
            for _, bag in ipairs(magazineBags) do
                local bagContainer = bag:getItemContainer()
                if bagContainer and bagContainer:hasRoomFor(player, item) then
                    ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, item, inventory, bagContainer, "PutItemInBag"))
                    break
                end
            end
        end
    end
end

function MagazineBag_Core.FetchFullMagazinesFromBag(player)
    if not player then return end

    local magazineBags = MagazineBag_Core.FindMagazineBags(player)
    local playerInventory = player:getInventory()

    if #magazineBags == 0 then return end

    for _, bag in ipairs(magazineBags) do
        local bagContainer = bag:getItemContainer()
        if bagContainer then
            local bagItems = bagContainer:getItems()

            for i = bagItems:size() - 1, 0, -1 do
                local item = bagItems:get(i)
                if item and MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineFull(item) then
                    if playerInventory:hasRoomFor(player, item) then
                        ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, item, bagContainer, playerInventory, "BoxOfRoundsOpenOne"))
                    end
                end
            end
        end
    end
end

return MagazineBag_Core
