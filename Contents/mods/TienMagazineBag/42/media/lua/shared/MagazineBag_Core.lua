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

-- Magazine-fed: pistols and the bolt-action rifles that take a magazine. Only
-- these have magazines to store, fetch or reload.
function MagazineBag_Core.HasMagazineWeapon(player)
    if not player then return false end

    local weapon = player:getPrimaryHandItem()
    return weapon and weapon:isRanged() and weapon.getMagazineType and weapon:getMagazineType()
end

-- Any firearm, magazine-fed or not. Revolvers, shotguns, lever-actions and the
-- hunting rifle load loose rounds straight into the gun, so they have no
-- magazines but their ammunition is still worth carrying in a bag.
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
    -- B42 vanilla matches either the short type or the full type (see predicateNotFullMagazine)
    if item:getType() == weaponMagType or item:getFullType() == weaponMagType then
        return true
    end
    local weaponMagTypeName = weaponMagType:find("%.") and weaponMagType:match("%.(.+)$") or weaponMagType

    return item:getType() == weaponMagTypeName
end

-- The round the held weapon fires, e.g. "Base.Bullets9mm"
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

-- Only magazines separate "Store All Ammo" from "Store Spent Ammo", so without
-- one the slice would just repeat the other
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

-- Loose rounds are only worth fetching for a gun that loads them directly. A
-- magazine-fed gun wants magazines, and Reload Magazines already draws rounds
-- out of the bags on its own without them being carried first.
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

-- Non-full magazines for the held weapon, in reload priority order:
-- main inventory first, then each worn magazine bag
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

    -- an empty gun with a magazine to hand is worth the entry on its own
    if not weapon:isContainsClip() then
        return weapon:getBestMagazine(player) ~= nil
    end

    local magazines = MagazineBag_Core.FindReloadableMagazines(player)
    if #magazines > 0 and MagazineBag_Core.CountSpareBullets(player, magazines[1].magazine) > 0 then
        return true
    end

    -- a part-used magazine in the gun can be swapped for a spare, or ejected
    -- and topped up from loose rounds
    if (weapon:getCurrentAmmoCount() or 0) < (weapon:getMaxAmmo() or 0) then
        if weapon:getBestMagazine(player) then return true end

        local ammoItemType = MagazineBag_Core.GetAmmoItemType(player)
        if ammoItemType and player:getInventory():getItemCountRecurse(ammoItemType) > 0 then
            return true
        end
    end

    return false
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

    -- A part-used magazine in the gun deserves topping up like any other, but
    -- ISEjectMagazine only creates the item once its animation has run, so it
    -- cannot be queued for refilling here. Eject, then plan again: the second
    -- pass sees it as an ordinary spare.
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

    -- The gun is loaded at the end, once the spares are done, so whichever
    -- magazine goes in has been filled by then.
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
            -- Rounds are fetched one magazine at a time rather than all at once.
            -- A bag discounts the weight of what it holds, so a whole reload's
            -- worth of ammunition in hand can push the character over their
            -- carry weight -- yet every magazine still needs filling. Loading
            -- consumes the rounds and the magazine goes straight back in the
            -- bag, so only one magazine's worth is ever being carried and the
            -- weight never builds up.
            --
            -- getSomeTypeRecurse is called once and its result handed out in
            -- slices: calling it per magazine would return the same rounds each
            -- time, since nothing has moved yet while the queue is being built.
            local bullets = playerInventory:getSomeTypeRecurse(itemKey, math.min(bulletBudget, totalNeeded))
            local taken = 0

            for _, entry in ipairs(magazines) do
                if taken >= bullets:size() then break end
                local magazine = entry.magazine
                local needed = (magazine:getMaxAmmo() or 0) - (magazine:getCurrentAmmoCount() or 0)
                if needed > 0 then
                    local toLoad = math.min(needed, bullets:size() - taken)

                    -- ISLoadBulletsInMagazine only draws from the main
                    -- inventory. Queued through our own action rather than
                    -- transferIfNeeded, which uses the vanilla one: a refusal
                    -- there would reset the queue and abandon the reload.
                    for _ = 1, toLoad do
                        local bullet = bullets:get(taken)
                        taken = taken + 1
                        if luautils.haveToBeTransfered(player, bullet) then
                            ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, bullet, bullet:getContainer(), playerInventory))
                        end
                    end

                    -- bag magazines are pulled out to load, then returned
                    if entry.bagContainer then
                        ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, magazine, entry.bagContainer, playerInventory))
                    end
                    ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(player, magazine, toLoad))

                    -- A filled magazine is put away before the next one starts,
                    -- so the weight of what has already been loaded does not
                    -- follow the character through the rest of the sequence.
                    -- The one headed for the gun stays in hand.
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
        -- ISInsertMagazine wants it in the main inventory, not in a bag
        local container = insertMagazine:getContainer()
        if not insertAlreadyInHand and container and container ~= playerInventory then
            ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, insertMagazine, container, playerInventory))
        end
        ISTimedActionQueue.add(ISInsertMagazine:new(player, weapon, insertMagazine))
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

function MagazineBag_Core.FetchFreshAmmoFromBag(player)
    if not player then return end

    local magazineBags = MagazineBag_Core.FindMagazineBags(player)
    local playerInventory = player:getInventory()
    local roundItemType = MagazineBag_Core.GetFetchableRoundType(player)

    if #magazineBags == 0 then return end

    -- Fetch only what the character can still carry unencumbered. A bag reduces
    -- the weight of what it holds, so every magazine taken out costs more than
    -- it did inside, and hasRoomFor sees the inventory as it is now rather than
    -- as it will be once the queue has run -- hence the running total.
    local fetched = 0

    for _, bag in ipairs(magazineBags) do
        local bagContainer = bag:getItemContainer()
        if bagContainer then
            local bagItems = bagContainer:getItems()

            for i = bagItems:size() - 1, 0, -1 do
                local item = bagItems:get(i)
                local wanted = item and
                    ((MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineFull(item))
                        or item:getFullType() == roundItemType)

                if wanted then
                    local weight = item:getActualWeight()
                    if playerInventory:hasRoomFor(player, fetched + weight) then
                        fetched = fetched + weight
                        ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, item, bagContainer, playerInventory))
                    end
                end
            end
        end
    end
end

return MagazineBag_Core
