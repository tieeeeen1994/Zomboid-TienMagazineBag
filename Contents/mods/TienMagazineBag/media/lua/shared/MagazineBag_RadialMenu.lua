require 'MagazineBag_Core'
require "ISUI/ISFirearmRadialMenu"

local storeIcon = getTexture("media/ui/RadialMenu_MagazineBagStore.png")
local fetchIcon = getTexture("media/ui/RadialMenu_MagazineBagFetch.png")

local function magazineBagRadialMenu()
    if not ISFirearmRadialMenu or not ISFirearmRadialMenu.fillMenu then
        return
    end

    local original = ISFirearmRadialMenu.fillMenu
    ISFirearmRadialMenu.fillMenu = function(data)
        local result = original(data)

        local player = nil
        local playerNum = 0
        for k, v in pairs(data) do
            if type(v) == "userdata" and v.getInventory then
                player = v
            elseif k == "playerNum" then
                playerNum = v
            end
        end

        if not player then
            return result
        end

        local magazineBags = MagazineBag_Core.FindMagazineBags(player)
        if #magazineBags == 0 then
            return result
        end

        if not MagazineBag_Core.HasMagazines(player) then
            return result
        end

        local menu = getPlayerRadialMenu(playerNum)
        if not menu then
            return result
        end

        menu:addSlice("Store Incomplete & Empty Magazines", storeIcon, function()
            MagazineBag_Core.StoreAllMagazinesToBag(player)
        end)

        menu:addSlice("Fetch Full Magazines", fetchIcon, function()
            MagazineBag_Core.FetchFullMagazinesFromBag(player)
        end)

        return result
    end
end

Events.OnGameStart.Add(magazineBagRadialMenu)
