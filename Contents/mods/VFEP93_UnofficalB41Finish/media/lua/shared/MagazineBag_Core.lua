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

function MagazineBag_Core.MoveMagazine(magazine, player)
    if not player then return end
    if not magazine or not MagazineBag_Core.IsMagazine(magazine, player) then return end

    local magazineBags = MagazineBag_Core.FindMagazineBags(player)
    if #magazineBags == 0 then return end

    for i, bag in ipairs(magazineBags) do
        local bagContainer = bag:getItemContainer()
        if bagContainer and bagContainer:hasRoomFor(player, magazine:getWeight()) then
            local action = MagazineBag_TimedAction:new(player, magazine, bag)
            ISTimedActionQueue.add(action)
            return
        end
    end
end

function MagazineBag_Core.MoveAllMagazinesToBag(player)
    if not player then return end

    local inventory = player:getInventory()
    local items = inventory:getItems()

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and MagazineBag_Core.IsMagazine(item, player) then
            local currentAmmo = item:getCurrentAmmoCount() or 0
            local maxAmmo = item:getMaxAmmo() or 0

            if currentAmmo < maxAmmo then
                MagazineBag_Core.MoveMagazine(item, player)
            end
        end
    end
end

return MagazineBag_Core
