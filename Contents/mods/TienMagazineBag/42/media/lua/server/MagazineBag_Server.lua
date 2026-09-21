local function onClientCommand(module, command, player, args)
    if module ~= "TienMagazineBag" or not args or not args.itemId then return end

    local item = player:getInventory():getItemWithIDRecursiv(args.itemId)
    if not item then return end

    if command == "assignBag" then
        item:getModData().isMagazineBag = args.value or false
    elseif command == "assignAmmo" then
        item:getModData().MagazineBag_AmmoType = type(args.value) == "string" and args.value or nil
    else
        return
    end

    syncItemModData(player, item)
end

Events.OnClientCommand.Add(onClientCommand)
