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
    if not item or not player then return false end

    local weapon = player:getPrimaryHandItem()
    if not weapon or not weapon:isRanged() or not weapon.getMagazineType then return false end

    local weaponMagType = weapon:getMagazineType()
    if not weaponMagType then return false end

    local magazineType = item:getType()
    local weaponMagTypeName = weaponMagType:find("%.") and weaponMagType:match("%.(.+)$") or weaponMagType

    return magazineType == weaponMagTypeName
end

function MagazineBag_Core.HasMagazines(player)
    if not player then return false end

    local weapon = player:getPrimaryHandItem()
    if not weapon or not weapon:isRanged() or not weapon.getMagazineType then return false end

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

function MagazineBag_Core.StoreAllMagazinesToBag(player)
    if not player then return end

    local inventory = player:getInventory()
    local items = inventory:getItems()
    local magazineBags = MagazineBag_Core.FindMagazineBags(player)

    if #magazineBags == 0 then return end

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and MagazineBag_Core.IsMagazine(item, player) then
            local currentAmmo = item:getCurrentAmmoCount() or 0
            local maxAmmo = item:getMaxAmmo() or 0

            if currentAmmo < maxAmmo then
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
end

function MagazineBag_Core.FetchFullMagazinesFromBag(player)
    if not player then return end

    local weapon = player:getPrimaryHandItem()
    if not weapon or not weapon:isRanged() or not weapon.getMagazineType then return end

    local weaponMagType = weapon:getMagazineType()
    if not weaponMagType then return end

    local weaponMagTypeName = weaponMagType:find("%.") and weaponMagType:match("%.(.+)$") or weaponMagType
    local magazineBags = MagazineBag_Core.FindMagazineBags(player)
    local playerInventory = player:getInventory()

    if #magazineBags == 0 then return end

    for _, bag in ipairs(magazineBags) do
        local bagContainer = bag:getItemContainer()
        if bagContainer then
            local bagItems = bagContainer:getItems()

            for i = bagItems:size() - 1, 0, -1 do
                local item = bagItems:get(i)
                if item and item:getType() == weaponMagTypeName then
                    local currentAmmo = item:getCurrentAmmoCount() or 0
                    local maxAmmo = item:getMaxAmmo() or 0

                    -- Only move full magazines
                    if currentAmmo >= maxAmmo and playerInventory:hasRoomFor(player, item:getWeight()) then
                        local action = MagazineBag_FetchFromBag:new(player, item, bag)
                        ISTimedActionQueue.add(action)
                    end
                end
            end
        end
    end
end

return MagazineBag_Core
