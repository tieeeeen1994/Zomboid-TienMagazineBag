-- B42 MP: the server's copy of the inventory is what gets saved, so bag
-- assignments made client-side must also be applied here or they vanish
-- on logout.

local function findItemById(container, id)
    local item = container:getItemWithID(id)
    if item then return item end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local inner = items:get(i):getItemContainer()
        if inner then
            local found = findItemById(inner, id)
            if found then return found end
        end
    end

    return nil
end

local function onClientCommand(module, command, player, args)
    if module ~= "TienMagazineBag" then return end

    if command == "assignBag" and args and args.itemId then
        local item = findItemById(player:getInventory(), args.itemId)
        if item then
            item:getModData().isMagazineBag = args.value or false
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
