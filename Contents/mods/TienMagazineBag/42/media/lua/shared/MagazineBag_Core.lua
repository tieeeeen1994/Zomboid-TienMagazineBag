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

-- Ammunition is carried as loose rounds, boxes of rounds, or cartons of boxes.
-- Each reload pass unpacks one layer: a pass that opens cartons re-plans itself
-- so the next one can open the boxes that came out of them.
local MAX_UNPACK_PASSES = 3

-- What one unpack of an item type yields, keyed by full type. false marks a
-- type that can't be unpacked at all.
local unpackResults = {}

local function GetUnpackRecipe(item)
    local recipeName = item.getDoubleClickRecipe and item:getDoubleClickRecipe()
    if not recipeName or recipeName == "" then return nil end
    return getScriptManager():getCraftRecipe(recipeName)
end

-- What a single unpack of an item produces: always the count, and where the
-- recipe's output mapper can be read, the full type as well. Resolving through
-- the mapper the way double-clicking the item would is what keeps a .45 carton
-- from reading as a source of 9mm.
local function ResolveUnpack(player, item)
    local itemType = item:getFullType()
    local cached = unpackResults[itemType]
    if cached ~= nil then
        return cached or nil
    end

    local result = false
    local recipe = GetUnpackRecipe(item)
    if recipe then
        -- guarded: a recipe shape we don't understand must not break the reload
        pcall(function()
            local outputs = recipe:getOutputs()
            if not outputs or outputs:size() ~= 1 then return end

            local output = outputs:get(0)
            if output:getResourceType() ~= ResourceType.Item then return end

            result = { amount = math.max(1, output:getIntAmount() or 1) }

            local logic = HandcraftLogic.new(player, nil, nil)
            logic:setContainers(ISInventoryPaneContextMenu.getContainers(player))
            logic:setRecipeFromContextClick(recipe, item)

            local mapper = output:getOutputMapper()
            local resultItem = mapper and mapper:getOutputItem(logic:getRecipeData(), true)
            resultItem = resultItem or output:getScriptItem()
            if resultItem then result.resultType = resultItem:getFullName() end
        end)
    end

    unpackResults[itemType] = result

    return result or nil
end

local function CollectCarriedItems(container, carried)
    local items = container:getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            table.insert(carried, item)

            local nested = item:getItemContainer()
            if nested then CollectCarriedItems(nested, carried) end
        end
    end

    return carried
end

-- The held weapon's AmmoBox script property. Without it a carton can only be
-- recognised when the player already carries a matching box.
local function GetWeaponAmmoBox(player)
    local weapon = player:getPrimaryHandItem()
    if not weapon or not weapon.getAmmoBox then return nil end

    local ammoBox = weapon:getAmmoBox()
    if type(ammoBox) ~= "string" or ammoBox == "" then return nil end

    return ammoBox
end

-- Carried boxes that open into ammoItemType, and cartons that open into one of
-- those boxes.
function MagazineBag_Core.FindAmmoPackages(player, ammoItemType)
    local boxes, cartons = {}, {}
    if not ammoItemType then return boxes, cartons end

    local carried = CollectCarriedItems(player:getInventory(), {})
    local boxTypes = {}

    local weaponAmmoBox = GetWeaponAmmoBox(player)
    if weaponAmmoBox then boxTypes[weaponAmmoBox] = true end

    for _, item in ipairs(carried) do
        local unpack = ResolveUnpack(player, item)
        if unpack and (unpack.resultType == ammoItemType or item:getFullType() == weaponAmmoBox) then
            boxTypes[item:getFullType()] = true
            table.insert(boxes, { item = item, yield = unpack.amount })
        end
    end

    for _, item in ipairs(carried) do
        local unpack = ResolveUnpack(player, item)
        if unpack and unpack.resultType and boxTypes[unpack.resultType] then
            table.insert(cartons, { item = item, yield = unpack.amount })
        end
    end

    return boxes, cartons
end

-- Opens a box or carton exactly the way double-clicking it in the inventory
-- does, so the vanilla animation, timing and item handling are preserved.
function MagazineBag_Core.OpenAmmoPackage(player, item)
    local recipe = GetUnpackRecipe(item)
    if not recipe then return end

    ISInventoryPaneContextMenu.OnNewCraft(item, recipe, player:getPlayerNum(), false)
end

function MagazineBag_Core.HasReloadableMagazines(player)
    local magazines = MagazineBag_Core.FindReloadableMagazines(player)
    if #magazines == 0 then return false end
    if MagazineBag_Core.CountSpareBullets(player, magazines[1].magazine) > 0 then return true end

    local ammoType = magazines[1].magazine:getAmmoType()
    if not ammoType then return false end

    local boxes, cartons = MagazineBag_Core.FindAmmoPackages(player, ammoType:getItemKey())

    return #boxes > 0 or #cartons > 0
end

function MagazineBag_Core.ReloadMagazines(player, pass)
    if not player then return end
    pass = pass or 1

    local magazines = MagazineBag_Core.FindReloadableMagazines(player)
    if #magazines == 0 then return end

    local playerInventory = player:getInventory()
    local itemKey = magazines[1].magazine:getAmmoType():getItemKey()

    local totalNeeded = 0
    for _, entry in ipairs(magazines) do
        local magazine = entry.magazine
        totalNeeded = totalNeeded + math.max(0, (magazine:getMaxAmmo() or 0) - (magazine:getCurrentAmmoCount() or 0))
    end
    if totalNeeded <= 0 then return end

    local bulletBudget = playerInventory:getItemCountRecurse(itemKey)

    -- loose rounds may not fill every magazine, so open just enough boxes (and
    -- cartons of boxes) to cover the rest before loading
    if bulletBudget < totalNeeded and pass <= MAX_UNPACK_PASSES then
        local boxes, cartons = MagazineBag_Core.FindAmmoPackages(player, itemKey)
        local shortfall = totalNeeded - bulletBudget
        local bulletsPerBox = boxes[1] and boxes[1].yield

        for _, entry in ipairs(boxes) do
            if shortfall <= 0 then break end
            MagazineBag_Core.OpenAmmoPackage(player, entry.item)
            bulletBudget = bulletBudget + entry.yield
            shortfall = shortfall - entry.yield
        end

        local openedCarton = false
        for _, entry in ipairs(cartons) do
            if shortfall <= 0 then break end
            MagazineBag_Core.OpenAmmoPackage(player, entry.item)
            openedCarton = true
            -- with no box on hand the rounds per box are unknown, so open one
            -- carton and let the next pass measure what came out
            shortfall = shortfall - (bulletsPerBox and bulletsPerBox * entry.yield or shortfall)
        end

        -- the boxes inside a carton have no inventory items yet, so hand the
        -- planning back to a later pass instead of loading now
        if openedCarton then
            ISTimedActionQueue.add(MagazineBag_ContinueReload:new(player, pass + 1))
            return
        end
    end

    if bulletBudget <= 0 then return end

    -- ISLoadBulletsInMagazine only takes bullets from the main inventory, so
    -- move everything we plan to load out of nested containers in one pass
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
