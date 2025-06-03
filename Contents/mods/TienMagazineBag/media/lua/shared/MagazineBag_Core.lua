MagazineBag_Core = {}

function MagazineBag_Core.AssignMagazineBag(item, value)
    if not item then return false end
    local modData = item:getModData()
    modData.isMagazineBag = value
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
    local magazineType = item:getType()
    local weaponMagTypeName = weaponMagType:find("%.") and weaponMagType:match("%.(.+)$") or weaponMagType

    return magazineType == weaponMagTypeName
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

function MagazineBag_Core.StoreAllMagazinesToBag(player)
    if not player then return end

    local inventory = player:getInventory()
    local items = inventory:getItems()
    local magazineBags = MagazineBag_Core.FindMagazineBags(player)

    if #magazineBags == 0 then return end

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and MagazineBag_Core.IsMagazine(item, player) and MagazineBag_Core.IsMagazineEmpty(item) then
            for _, bag in ipairs(magazineBags) do
                local bagContainer = bag:getItemContainer()
                if bagContainer and bagContainer:hasRoomFor(player, item:getWeight()) then
                    local action = MagazineBag_MoveToBag:new(player, item, bag)
                    ISTimedActionQueue.add(action)
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
                    if playerInventory:hasRoomFor(player, item:getWeight()) then
                        local action = MagazineBag_FetchFromBag:new(player, item, bag)
                        ISTimedActionQueue.add(action)
                    end
                end
            end
        end
    end
end

return MagazineBag_Core
