MagazineBag_Options = {}

local OPTIONS_ID = "TienMagazineBag"

MagazineBag_Options.STORE_SPENT = "storeSpentAmmo"
MagazineBag_Options.STORE_ALL = "storeAllAmmo"
MagazineBag_Options.RELOAD = "reloadMagazines"
MagazineBag_Options.FETCH_FRESH = "fetchFreshAmmo"

function MagazineBag_Options.IsEnabled(id)
    if not PZAPI or not PZAPI.ModOptions then return true end

    local options = PZAPI.ModOptions:getOptions(OPTIONS_ID)
    local option = options and options:getOption(id)
    if not option then return true end

    return option:getValue() ~= false
end

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
        "Refills every empty and part-used magazine you are carrying. With a speedloader revolver it reloads the revolver, then refills your speedloaders.")
    options:addTickBox(MagazineBag_Options.FETCH_FRESH, "Fetch Fresh Ammo", true,
        "Takes fresh ammunition back out of your ammo bags.")
end
