MagazineBag_Options = {}

local OPTIONS_ID = "TienMagazineBag"

MagazineBag_Options.STORE_SPENT = "storeSpentAmmo"
MagazineBag_Options.STORE_ALL = "storeAllAmmo"
MagazineBag_Options.RELOAD = "reloadMagazines"
MagazineBag_Options.RELOAD_BOXES = "reloadMagazinesOpenBoxes"
MagazineBag_Options.FETCH_FRESH = "fetchFreshAmmo"
MagazineBag_Options.FETCH_BOXES = "fetchFreshAmmoOpenBoxes"
MagazineBag_Options.GUNWORKS = "gunworksSupport"
MagazineBag_Options.AMMO_ASSIGNMENT = "ammoAssignment"
MagazineBag_Options.SPEEDLOADER_RELOAD = "speedloaderReload"

local DEFAULTS = {
    [MagazineBag_Options.RELOAD_BOXES] = false,
    [MagazineBag_Options.FETCH_BOXES] = false,
    [MagazineBag_Options.GUNWORKS] = false,
    [MagazineBag_Options.AMMO_ASSIGNMENT] = false,
    [MagazineBag_Options.SPEEDLOADER_RELOAD] = false,
}

function MagazineBag_Options.IsEnabled(id)
    local default = DEFAULTS[id] ~= false
    if not PZAPI or not PZAPI.ModOptions then return default end

    local options = PZAPI.ModOptions:getOptions(OPTIONS_ID)
    local option = options and options:getOption(id)
    if not option then return default end

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
        "Refills every empty and part-used magazine you are carrying.")
    options:addTickBox(MagazineBag_Options.FETCH_FRESH, "Fetch Fresh Ammo", true,
        "Takes fresh ammunition back out of your ammo bags.")

    options:addSeparator()
    options:addTitle("Beta Features")
    options:addDescription("Newer features that are still being tested. Each is off until you turn it on, and turning one back off returns that part of the mod to normal.")
    options:addSeparator()

    options:addTickBox(MagazineBag_Options.RELOAD_BOXES, "Reload Magazines (Open Boxes)", false,
        "As Reload Magazines, but first opens just enough ammo boxes to cover what your loose rounds can't. Only shown when a box would be opened.")
    options:addTickBox(MagazineBag_Options.FETCH_BOXES, "Fetch Fresh Ammo (Open Boxes)", false,
        "As Fetch Fresh Ammo, but for guns that load loose rounds it opens ammo boxes when you don't have a full load of rounds. Only shown when a box would be opened.")
    options:addTickBox(MagazineBag_Options.GUNWORKS, "Gunworks Gang Support", false,
        "For guns from packs built on Gunworks Gang: handles every magazine a gun takes, speedloaders and stripper clips, and every kind of round.")
    options:addTickBox(MagazineBag_Options.AMMO_ASSIGNMENT, "Assign Ammo", false,
        "Needs Gunworks Gang Support. Right click a magazine, speedloader or loose-round gun to choose the one round it is filled with, including when you use your Reload key.")
    options:addTickBox(MagazineBag_Options.SPEEDLOADER_RELOAD, "Reload Speedloaders Loads the Revolver", false,
        "Needs Gunworks Gang Support. Reload Speedloaders also loads the revolver in your hand before refilling your speedloaders.")
end
