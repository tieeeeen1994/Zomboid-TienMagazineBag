# Tien's Ammo Bags

Project Zomboid mod. The live code is under `Contents/mods/TienMagazineBag/42/` (B42). The top-level `Contents/mods/TienMagazineBag/media/` is the outdated B41 version.

The Lua source has no comments on purpose. The reasoning behind non-obvious code lives here. Update this file when that reasoning changes.

## MagazineBag_Core.lua

### Bag assignment (multiplayer)
- `AssignMagazineBag` sets `modData.isMagazineBag`, calls `syncItemModData`, and sends the `assignBag` client command. In B42 MP the inventory is server-authoritative, so the server's copy of the item has to get the flag too or the assignment is lost on logout. `MagazineBag_Server.lua` handles that command.

### Weapon kinds
- `HasMagazineWeapon`: magazine-fed guns (pistols, the bolt-action rifles that take a magazine). Only these have magazines to store, fetch or reload.
- `HasAmmoWeapon`: any firearm. Revolvers, shotguns, lever-actions and the hunting rifle load loose rounds straight into the gun. They have no magazines, but their rounds are still worth bagging.
- `IsMagazine` matches the weapon's magazine type against both the short and the full item type, the same way vanilla B42 does (see `predicateNotFullMagazine`).

### Menu visibility
- `HasAmmoInInventory` needs a magazine weapon. Only magazines separate "Store All Ammo" from "Store Spent Ammo", so without one that entry would just repeat the other.
- `GetFetchableRoundType` returns nil for magazine weapons. Loose rounds are only worth fetching for a gun that loads them directly. A magazine-fed gun wants magazines, and Reload Magazines already draws rounds out of the bags without carrying them first.
- `HasReloadableMagazines` is true for an empty gun with a magazine to hand. It is also true when the magazine in the gun is part-used and there is a spare to swap in, or loose rounds to top it up after ejecting.
- `FindReloadableMagazines` returns non-full magazines in priority order: main inventory first, then each worn bag.

### StoreInBag
Queues a move into the first bag that will take the item.
- `isItemAllowed` matters as much as the weight check. A restricted container such as a shoulder holster takes pistol magazines only, yet its weight reduction makes it report room for anything. Without the check it claims items it then refuses. That starves the bag that would have taken them, and it aborts the rest of the queue, because a rejected transfer stops and resets it.
- `hasRoomFor` only sees a bag as it is right now, and nothing has moved while the queue is being built. So each bag is also charged for the weight already promised to it (`reserved`).

### ReloadMagazines
- **Ejecting first.** A part-used magazine in the gun should be topped up too. But `ISEjectMagazine` only creates the item once its animation has run, so it cannot be queued for refilling in the same pass. Instead the reload queues the eject plus `MagazineBag_ContinueReload`, which plans again on pass 2, when the ejected magazine is an ordinary spare.
- **Loading the gun last.** The gun is loaded at the end, after the spares, so whichever magazine goes in is already full by then.
- **One magazine at a time.** A bag discounts the weight of what it holds, so a whole reload's worth of rounds in hand can push the character over their carry weight. Loading uses up the rounds and each magazine goes straight back into a bag, so only one magazine's worth is carried at any time.
- **One call to getSomeTypeRecurse.** It is called once and its result is handed out in slices. Calling it per magazine would return the same rounds each time, since nothing has moved yet while the queue is built.
- `ISLoadBulletsInMagazine` only draws from the main inventory, so rounds are moved there first. The move uses `MagazineBag_TransferAction` rather than `transferIfNeeded`, which uses the vanilla action: a refusal there would reset the queue and abandon the reload.
- Bag magazines are taken out to load and put back afterwards. A filled magazine is put away before the next one starts, so its weight doesn't follow the character through the rest of the sequence. The one headed for the gun stays in hand.
- `ISInsertMagazine` needs the magazine in the main inventory, not in a bag.

### FindBagForItem
The first worn bag that will take the item right now, skipping the one that just turned it away. It's used when a queued move reaches a bag that has filled up since the move was planned.

### StoreAmmoToBag
Loose rounds are queued in one run after the magazines. The transfer action only bulk-merges back-to-back moves of the same item type into the same container.

### FetchFreshAmmoFromBag
Fetches only what the character can carry without becoming encumbered.
- `hasRoomFor` on the main inventory checks the hard capacity. That is well above where Heavy Load sets in, which is the inventory's `getMaxWeight()` (the same limit `ISHotbar` checks). So the budget is `getMaxWeight() - getCapacityWeight()`, which is skipped when the character has unlimited carry.
- An item in a worn bag already counts toward the character's weight, discounted by the bag's weight reduction. Taking it out only adds back the part the bag was hiding: `weight * getWeightReduction() / 100`. A running total covers the moves the queue hasn't run yet.
- `hasRoomFor` stays in as the hard cap, with its own running total.

## MagazineBag_TransferAction.lua
A plain vanilla transfer with one change: where the item ends up.
- **Presentation is left alone.** An earlier version forced `CharacterActionAnims.RemoveBullets` on top of the transfer animation. That clip loops and is driven by anim events: its only vanilla user, `ISUnloadBulletsFromMagazine`, returns `getDuration() == -1` and ends the loop from an animEvent. A timed transfer handles no such events, so the character got stuck at the loop's hold point.
- **`resolveDestination`.** A restricted bag only turns an item away when the move actually runs. A shoulder holster reports room right up until it holds its second magazine, so a queue planned while it was empty sends too many items to it. Those items are redirected to the next bag that will take them. If none will, the move is dropped quietly, because a transfer that fails outright resets the whole queue behind it. This runs before `ISInventoryTransferAction:start` creates the item transaction, so the move is registered against the bag the item actually goes into.
- **`isValid` never returns false.** A failing action calls `stop()`, which resets the whole timed action queue, so one refused move would cancel every later step of the reload. Setting `dontAdd` uses vanilla's own no-op path: `start()` zeroes the timer and `transferItem()` moves nothing, so the action completes having done nothing and the queue carries on.

## MagazineBag_ContinueReload.lua
`ISEjectMagazine` creates the ejected magazine with `instanceItem()` when its animation finishes. That means the item doesn't exist while the reload is being planned. This action sits after the eject and runs the planning again, when the magazine is an ordinary spare.

## MagazineBag_Options.lua
- Option keys are deliberately not derived from the entry labels. Renaming an entry must not silently reset what players have already turned off.
- Anything that can't be read counts as enabled. A setting the game hasn't registered or loaded should never be why an entry goes missing.
- B42 ships `PZAPI.ModOptions`. The main options screen only builds its mod panel if something has registered by the time that screen is created, which is before `OnGameStart`. So registration runs as the file loads.

## MagazineBag_RadialMenu.lua
In B42, `fillMenu` is an instance method. Its data is the menu object, with `character`/`playerNum` set in `ISFirearmRadialMenu:new`.

## MagazineBag_Server.lua
In B42 MP the server's copy of the inventory is what gets saved. Bag assignments made client-side have to be applied here too, or they vanish on logout.
