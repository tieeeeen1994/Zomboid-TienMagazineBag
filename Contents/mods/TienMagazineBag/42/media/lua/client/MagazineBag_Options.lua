MagazineBag_Options = {}

local OPTIONS_ID = "TienMagazineBag"

-- Keys are deliberately not derived from the entry labels: renaming an entry
-- must not silently reset what players have already turned off.
MagazineBag_Options.STORE_SPENT = "storeSpentAmmo"
MagazineBag_Options.STORE_ALL = "storeAllAmmo"
MagazineBag_Options.RELOAD = "reloadMagazines"
MagazineBag_Options.FETCH_FRESH = "fetchFreshAmmo"

-- Anything that cannot be read counts as enabled: a setting the game has not
-- registered or loaded should never be the reason an entry goes missing.
function MagazineBag_Options.IsEnabled(id)
    if not PZAPI or not PZAPI.ModOptions then return true end

    local options = PZAPI.ModOptions:getOptions(OPTIONS_ID)
    local option = options and options:getOption(id)
    if not option then return true end

    return option:getValue() ~= false
end

-- B42 ships PZAPI.ModOptions, and the main options screen only builds its mod
-- panel if something has registered by the time that screen is created. That
-- happens before OnGameStart, so registration runs as this file loads.
if PZAPI and PZAPI.ModOptions then
    local options = PZAPI.ModOptions:create(OPTIONS_ID, "Tien's Ammo Bags")

    options:addTitle("Radial Menu Entries")
    options:addDescription("Turn individual entries off to keep the firearm radial menu short. This is per player and does not affect anyone else on a server.")
    options:addSeparator()

    options:addTickBox(MagazineBag_Options.STORE_SPENT, "Store Spent Ammo", true,
        "Stows empty and part-used magazines, plus loose rounds, into your ammo bags.")
    options:addTickBox(MagazineBag_Options.STORE_ALL, "Store All Ammo", true,
        "As above, but full magazines go in as well.")
    options:addTickBox(MagazineBag_Options.RELOAD, "Reload Magazines", true,
        "Refills every empty and part-used magazine you are carrying.")
    options:addTickBox(MagazineBag_Options.FETCH_FRESH, "Fetch Fresh Ammo", true,
        "Takes fresh ammunition back out of your ammo bags.")
end
