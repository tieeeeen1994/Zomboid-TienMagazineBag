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

-- The round the held weapon fires, e.g. "Base.Bullets9mm"
function MagazineBag_Core.GetAmmoItemType(player)
    if not MagazineBag_Core.HasValidWeapon(player) then return nil end

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
    if not MagazineBag_Core.HasValidWeapon(player) then return false end

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
    if not MagazineBag_Core.HasValidWeapon(player) then return false end

    local inventory = player:getInventory()
    local items = inventory:getItems()
    local ammoItemType = MagazineBag_Core.GetAmmoItemType(player)

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and (MagazineBag_Core.IsMagazine(item, player) or item:getFullType() == ammoItemType) then
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

-- Queues a move into the first bag that will take the item.
--
-- isItemAllowed matters as much as the weight check: a restricted container
-- such as a shoulder holster takes pistol magazines only, yet its weight
-- reduction leaves it reporting room for anything. Without the check it would
-- claim items it then refuses, both starving the bag that would have accepted
-- them and aborting the rest of the queue, since a rejected transfer stops and
-- resets it.
--
-- hasRoomFor likewise only sees a bag as it is right now and nothing has moved
-- yet while the queue is being built, so each bag is also charged for the
-- weight it has already been promised.
local function StoreInBag(player, item, inventory, magazineBags, reserved)
    local weight = item:getActualWeight()

    for index, bag in ipairs(magazineBags) do
        local bagContainer = bag:getItemContainer()
        if bagContainer and bagContainer:isItemAllowed(item)
                and bagContainer:hasRoomFor(player, reserved[index] + weight) then
            reserved[index] = reserved[index] + weight
            ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, item, inventory, bagContainer, "PutItemInBag"))
            return
        end
    end
end

-- The first worn magazine bag that will take the item as things stand, ignoring
-- one that has just turned it away. Used when a queued move reaches a bag that
-- has filled up since it was planned.
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

    -- loose rounds go in one run after the magazines: the transfer action only
    -- bulk-merges neighbouring moves of the same type into the same container
    local ammoItemType = MagazineBag_Core.GetAmmoItemType(player)
    if not ammoItemType then return end

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and item:getFullType() == ammoItemType then
            StoreInBag(player, item, inventory, magazineBags, reserved)
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
