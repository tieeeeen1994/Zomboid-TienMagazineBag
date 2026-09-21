require 'MagazineBag_Core'
require 'MagazineBag_Options'
require 'MagazineBag_Boxes'
require "ISUI/ISFirearmRadialMenu"

local storeIcon = getTexture("media/ui/RadialMenu_MagazineBagStore.png")
local fetchIcon = getTexture("media/ui/RadialMenu_MagazineBagFetch.png")
local stowAllIcon = getTexture("media/ui/RadialMenu_MagazineBagStowAll.png")
local reloadIcon = getTexture("media/ui/RadialMenu_ReloadMagazines.png")

local function magazineBagRadialMenu()
    if not ISFirearmRadialMenu or not ISFirearmRadialMenu.fillMenu then
        return
    end

    local original = ISFirearmRadialMenu.fillMenu
    ISFirearmRadialMenu.fillMenu = function(data)
        local result = original(data)

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

        if MagazineBag_Options.IsEnabled(MagazineBag_Options.STORE_SPENT)
                and MagazineBag_Core.HasSpentAmmoInInventory(player) then
            menu:addSlice("Store Spent Ammo", storeIcon, function()
                MagazineBag_Core.StoreAmmoToBag(player)
            end)
        end

        if MagazineBag_Options.IsEnabled(MagazineBag_Options.STORE_ALL)
                and MagazineBag_Core.HasAmmoInInventory(player) then
            menu:addSlice("Store All Ammo", stowAllIcon, function()
                MagazineBag_Core.StoreAmmoToBag(player, true)
            end)
        end

        local reloadLabel = MagazineBag_Core.HasSpeedLoaderWeapon(player) and "Reload Speedloaders" or "Reload Magazines"

        if MagazineBag_Options.IsEnabled(MagazineBag_Options.RELOAD)
                and MagazineBag_Core.HasReloadableMagazines(player) then
            menu:addSlice(reloadLabel, reloadIcon, function()
                MagazineBag_Core.ReloadMagazines(player)
            end)
        end

        if MagazineBag_Options.IsEnabled(MagazineBag_Options.RELOAD_BOXES)
                and MagazineBag_Boxes.HasBoxesFor(player, MagazineBag_Core.GetReloadDemands(player)) then
            menu:addSlice(reloadLabel .. " (Open Boxes)", reloadIcon, function()
                MagazineBag_Core.ReloadMagazines(player, 1, {})
            end)
        end

        if MagazineBag_Options.IsEnabled(MagazineBag_Options.FETCH_FRESH)
                and MagazineBag_Core.HasFreshAmmoInBags(player) then
            menu:addSlice("Fetch Fresh Ammo", fetchIcon, function()
                MagazineBag_Core.FetchFreshAmmoFromBag(player)
            end)
        end

        if MagazineBag_Options.IsEnabled(MagazineBag_Options.FETCH_BOXES)
                and MagazineBag_Boxes.HasBoxesFor(player, MagazineBag_Core.GetFetchDemands(player)) then
            menu:addSlice("Fetch Fresh Ammo (Open Boxes)", fetchIcon, function()
                MagazineBag_Core.FetchFreshAmmoFromBag(player, true)
            end)
        end

        return result
    end
end

Events.OnGameStart.Add(magazineBagRadialMenu)
