require 'MagazineBag_Core'
require 'MagazineBag_Options'
require 'MagazineBag_Boxes'
require "ISUI/ISFirearmRadialMenu"

local KEY_SECTION = "[Ammo Bags]"

local function ReloadLabel(player)
    if MagazineBag_Core.HasSpeedLoaderWeapon(player) then return "Reload All Speedloaders" end
    if MagazineBag_Core.HasMagazineWeapon(player) then return "Reload All Magazines" end
    return "Reload All"
end

local ENTRIES = {
    {
        option = MagazineBag_Options.STORE_SPENT,
        key = "TAB Store Spent",
        icon = getTexture("media/ui/RadialMenu_MagazineBagStore.png"),
        label = function() return "Store Spent Ammo" end,
        available = MagazineBag_Core.HasSpentAmmoInInventory,
        run = function(player) MagazineBag_Core.StoreAmmoToBag(player) end,
    },
    {
        option = MagazineBag_Options.STORE_ALL,
        key = "TAB Store All",
        icon = getTexture("media/ui/RadialMenu_MagazineBagStowAll.png"),
        label = function() return "Store All Ammo" end,
        available = MagazineBag_Core.HasAmmoInInventory,
        run = function(player) MagazineBag_Core.StoreAmmoToBag(player, true) end,
    },
    {
        option = MagazineBag_Options.RELOAD,
        key = "TAB Reload All",
        icon = getTexture("media/ui/RadialMenu_ReloadMagazines.png"),
        label = ReloadLabel,
        available = function(player)
            return MagazineBag_Core.HasReloadableMagazines(player)
                or MagazineBag_Core.HasLooseRoundWork(player)
                or MagazineBag_Boxes.HasBoxesFor(player, MagazineBag_Core.GetReloadDemands(player))
        end,
        run = function(player) MagazineBag_Core.ReloadMagazines(player) end,
    },
    {
        option = MagazineBag_Options.FETCH_FRESH,
        key = "TAB Fetch Fresh",
        icon = getTexture("media/ui/RadialMenu_MagazineBagFetch.png"),
        label = function() return "Fetch Fresh Ammo" end,
        available = MagazineBag_Core.HasFreshAmmoInBags,
        run = function(player) MagazineBag_Core.FetchFreshAmmoFromBag(player) end,
    },
}

local function magazineBagRadialMenu()
    if not ISFirearmRadialMenu or not ISFirearmRadialMenu.fillMenu then
        return
    end

    local original = ISFirearmRadialMenu.fillMenu
    ISFirearmRadialMenu.fillMenu = function(data)
        local result = original(data)

        local player = data and data.character
        local playerNum = (data and data.playerNum) or 0

        if not player or #MagazineBag_Core.FindMagazineBags(player) == 0 then
            return result
        end

        local menu = getPlayerRadialMenu(playerNum)
        if not menu then
            return result
        end

        for _, entry in ipairs(ENTRIES) do
            if MagazineBag_Options.IsEnabled(entry.option) and entry.available(player) then
                menu:addSlice(entry.label(player), entry.icon, function()
                    entry.run(player)
                end)
            end
        end

        return result
    end
end

local function AddKeyBindings()
    if not keyBinding then return end
    for _, bind in ipairs(keyBinding) do
        if bind.value == KEY_SECTION then return end
    end
    table.insert(keyBinding, { value = KEY_SECTION })
    for _, entry in ipairs(ENTRIES) do
        table.insert(keyBinding, { value = entry.key, key = 0 })
    end
end

local function OnKeyPressed(key)
    if not key or key == 0 or isGamePaused() then return end

    local core = getCore()
    for _, entry in ipairs(ENTRIES) do
        if core:isKey(entry.key, key) then
            local player = getSpecificPlayer(0)
            if player and not player:isDead() and #MagazineBag_Core.FindMagazineBags(player) > 0
                    and entry.available(player) then
                entry.run(player)
            end
            return
        end
    end
end

AddKeyBindings()

Events.OnGameStart.Add(magazineBagRadialMenu)
Events.OnKeyPressed.Add(OnKeyPressed)
