require 'MagazineBag_Core'

local function isAssignable(item)
    if instanceof(item, "HandWeapon") then
        return MagazineBag_Core.LoadsLooseRounds(item)
    end
    return (item:getMaxAmmo() or 0) > 0
end

local function findAssignableMagazines(items)
    local magazines = {}
    local family = nil

    for _, item in ipairs(ISInventoryPane.getActualItems(items)) do
        if isAssignable(item) and item:isInPlayerInventory() then
            local itemFamily = MagazineBag_Core.GetAmmoFamily(item)
            if itemFamily and (family == nil or itemFamily == family) then
                family = itemFamily
                table.insert(magazines, item)
            end
        end
    end

    return magazines
end

local function assignAll(playerObj, magazines, roundType)
    for _, magazine in ipairs(magazines) do
        MagazineBag_Core.AssignMagazineAmmo(playerObj, magazine, roundType)
    end
end

local function ammoAssignmentContextMenu(player, context, items)
    if not MagazineBag_Core.IsFeatureEnabled("ammoAssignment") then return end
    local magazines = findAssignableMagazines(items)
    if #magazines == 0 then return end

    local playerObj = getSpecificPlayer(player)
    local inventory = playerObj:getInventory()

    local shared = MagazineBag_Core.GetAssignedAmmo(magazines[1])
    local anyAssigned = false
    for _, magazine in ipairs(magazines) do
        local assigned = MagazineBag_Core.GetAssignedAmmo(magazine)
        if assigned then anyAssigned = true end
        if assigned ~= shared then shared = nil end
    end

    local parent = context:addOption("Assign Ammo")
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(parent, subMenu)

    for _, roundType in ipairs(MagazineBag_Core.GetAmmoChoices(magazines[1]) or {}) do
        local label = MagazineBag_Core.GetRoundDisplayName(roundType)
            .. " (" .. inventory:getItemCountRecurse(roundType) .. ")"
        local option = subMenu:addOption(label, playerObj, assignAll, magazines, roundType)
        option.checkMark = roundType == shared
    end

    if anyAssigned then
        context:addOption("Unassign Ammo", playerObj, assignAll, magazines, nil)
    end
end

local function onServerCommand(module, command, args)
    if module ~= "TienMagazineBag" or command ~= "syncAmmo" or not args or not args.itemId then return end

    for i = 0, getNumActivePlayers() - 1 do
        local playerObj = getSpecificPlayer(i)
        local item = playerObj and playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item then
            item:getModData()[MagazineBag_Core.AMMO_KEY] = args.value
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(ammoAssignmentContextMenu)
Events.OnServerCommand.Add(onServerCommand)
