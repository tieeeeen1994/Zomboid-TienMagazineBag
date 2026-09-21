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
    elseif command == "assignAmmo" and args and args.itemId then
        local item = findItemById(player:getInventory(), args.itemId)
        if item then
            item:getModData().MagazineBag_AmmoType = type(args.value) == "string" and args.value or nil
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
