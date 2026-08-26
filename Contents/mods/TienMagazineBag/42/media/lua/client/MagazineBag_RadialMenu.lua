require 'MagazineBag_Core'
require "ISUI/ISFirearmRadialMenu"

local storeIcon = getTexture("media/ui/RadialMenu_MagazineBagStore.png")
local fetchIcon = getTexture("media/ui/RadialMenu_MagazineBagFetch.png")
local stowAllIcon = getTexture("media/ui/RadialMenu_MagazineBagStowAll.png")

local function magazineBagRadialMenu()
    if not ISFirearmRadialMenu or not ISFirearmRadialMenu.fillMenu then
        return
    end

    local original = ISFirearmRadialMenu.fillMenu
    ISFirearmRadialMenu.fillMenu = function(data)
        local result = original(data)

        -- B42: fillMenu is an instance method; data is the menu object with
        -- character/playerNum set in ISFirearmRadialMenu:new
        local player = data and data.character
        local playerNum = (data and data.playerNum) or 0

        if not player then
            return result
        end

        local magazineBags = MagazineBag_Core.FindMagazineBags(player)
        if #magazineBags == 0 then
            return result
        end

        local menu = getPlayerRadialMenu(playerNum)
        if not menu then
            return result
        end

        if MagazineBag_Core.HasEmptyMagazinesInInventory(player) then
            menu:addSlice("Store Incomplete & Empty Magazines", storeIcon, function()
                MagazineBag_Core.StoreAllMagazinesToBag(player)
            end)
        end

        if MagazineBag_Core.HasMagazinesInInventory(player) then
            menu:addSlice("Store All Magazines", stowAllIcon, function()
                MagazineBag_Core.StoreAllMagazinesToBag(player, true)
            end)
        end

        if MagazineBag_Core.HasFullMagazinesInBags(player) then
            menu:addSlice("Fetch Full Magazines", fetchIcon, function()
                MagazineBag_Core.FetchFullMagazinesFromBag(player)
            end)
        end

        return result
    end
end

Events.OnGameStart.Add(magazineBagRadialMenu)
