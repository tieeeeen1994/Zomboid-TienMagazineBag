require 'MagazineBag_Core'

local function magazineBagContextMenu(player, context, items)
    local item = nil
    if type(items) == "table" then
        item = items[1]

        if type(item) == "table" then
            if item.items then
                item = item.items[1]
            end
        end
    else
        item = items
    end

    if not item then return end
    if not item.canBeEquipped or not item:canBeEquipped() then return end
    if not item.getCapacity or item:getCapacity() <= 0 then return end

    local playerObj = getSpecificPlayer(player)

    if MagazineBag_Core.IsMagazineBag(item) then
        context:addOption("Unassign Magazine Bag", item, function()
            MagazineBag_Core.AssignMagazineBag(playerObj, item, false)
        end)
    else
        context:addOption("Assign Magazine Bag", item, function()
            MagazineBag_Core.AssignMagazineBag(playerObj, item, true)
        end)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(magazineBagContextMenu)
