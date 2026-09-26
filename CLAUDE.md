# Tien's Ammo Bags

Project Zomboid mod. The live code is under `Contents/mods/TienMagazineBag/42/` (B42). The top-level `Contents/mods/TienMagazineBag/media/` is the outdated B41 version.

The Lua source has no comments on purpose. The reasoning behind non-obvious code lives here. Update this file when that reasoning changes.

## MagazineBag_Core.lua

### Bag assignment (multiplayer)
- `AssignMagazineBag` sets `modData.isMagazineBag` locally and sends the `assignBag` client command. In B42 MP the inventory is server-authoritative, so the server's copy of the item has to get the flag too or the assignment is lost on logout. `MagazineBag_Server.lua` handles that command, then calls `syncItemModData` to push the server's copy back to the owner. That is the direction vanilla uses it in (from `complete()`, e.g. `ISChangeFishingRodEquip`). The client doesn't call it: it does nothing useful there, and could pull back the server's copy from before the change.

### Gunworks support
Everything Gunworks-specific keys off the framework (`SWMG`), not a particular gun pack, so any pack built on it is covered (Guns of Marz, VWP2GoM, ...). It has no setting: it's always on when `SWMG` is active. `GetGunworks(name)` only requires `WeaponSystems/Utils/<name>` when `SWMG` is active, and resolves it lazily so file load order doesn't matter. Without it, every path falls back to vanilla and behaves as it always did. Ammo Maker only handles crafting and casings, so it plays no part here.

### Assigned ammo
Gunworks puts each magazine in an ammo family (e.g. `"5.56x45mm"`) that lists several round types: ball, HP, AP, subsonic. A magazine loads one type at a time, whatever `getAmmoType()` currently says.
- `GetAmmoFamily` falls back to the family of the item's current round (`Ammo.FindBulletEntry`) when the item itself isn't registered. Packs register magazines but often not the guns: Guns of Marz lists the STANAGs under `5.56x45mm`, but not the M16s. And Gunworks swaps a gun's `getAmmoType()` to whatever round it's firing, so without the fallback, Store would bag only that one round type.
- The assignment is `modData.MagazineBag_AmmoType`, synced like `isMagazineBag`. `GetAssignedAmmo` ignores a value that isn't in the item's family, so a stale one (Gunworks removed, family changed) is harmless.
- `GetReloadRoundTypes`: an assigned magazine takes only its assigned round and waits if there is none. That is the point of assigning it. An unassigned one takes whatever is on hand, in the player's Gunworks reload order (`GunworksAmmoPref`), and can mix types to fill up. Gunworks' `AmmoList` hooks track each round, so mixing is safe.
- Guns that load loose rounds (`LoadsLooseRounds`: revolvers, shotguns, lever-actions, anything whose feed kind isn't "magazine") can be assigned a round themselves. On a magazine-fed gun the same modData key only holds the inserted magazine's assignment while it's in there (see `MagazineBag_AmmoCarry.lua`), so assigning those guns directly isn't offered.
- `GetReloadRoundTypes`: an unassigned speedloader or magazine takes the assignment of the loose-round gun in hand when they share a family. So a revolver assigned to subsonic gets its speedloaders filled with subsonic, which it will then accept.
- `GetFetchableRoundTypes` narrows to the gun's own assignment. Storing still bags the whole family.
- Inserting a magazine destroys the item, and ejecting creates a new one with `instanceItem()`, so modData would be lost. `MagazineBag_AmmoCarry.lua` moves the assignment onto the gun in `ISInsertMagazine:loadAmmo` and back onto the new magazine in `ISEjectMagazine:unloadAmmo`. Those run in SP or on the MP server, so the owning client is told through the `syncAmmo` server command. The ejected magazine is found by diffing item IDs, not by type: Gunworks swaps the gun's magazine type around inside the same call. Both hooks skip loose-round guns, because inserting a speedloader into a revolver also goes through `loadAmmo`, and copying would overwrite the revolver's own assignment.
- Hot Brass Tactical Reload (`HBTacReload`) ejects without `ISEjectMagazine`: it creates the magazine itself and drops it through `SpentCasingPhysics.doSpawnCasing(..., optionalItem, ...)`. That function is wrapped to move the assignment onto `optionalItem`. The wrap is installed on `OnInitGlobalModData`, because `doSpawnCasing` is defined in Hot Brass's server folder. It works because that item object itself is what `AddWorldInventoryItem` later puts on the ground, so its modData lands with it.
- `hasModData()` guards `GetAssignedAmmo`, because the tooltip calls it for every hovered item and `getModData()` would create a table on each one.

### Weapon kinds
`GetFeedKind` classifies the gun in hand in the same order Gunworks' `BeginAutomaticReload` does: a Gunworks magazine profile, then Gunworks speedloaders, then the vanilla `getMagazineType()`.
- `HasMagazineWeapon`: magazine-fed guns (pistols, rifles and anything with a Gunworks magazine profile). Only these have a magazine to eject or insert.
- `HasFeedWeapon`: magazine-fed guns plus Gunworks speedloader guns (revolvers, the Mosin's stripper clip). Speedloaders are stored, refilled and fetched like magazines, but never ejected. See ReloadMagazines for how the revolver itself is loaded.
- `HasSpeedLoaderWeapon`: the speedloader case on its own. The radial entry is labelled "Reload Speedloaders" for these, under the same `reloadMagazines` option key.
- `HasAmmoWeapon`: any firearm. Revolvers, shotguns, lever-actions and the hunting rifle load loose rounds straight into the gun. Their rounds are still worth bagging.
- `IsMagazine`: a Gunworks gun can take several magazines (an M4 takes STANAG 20 to 150), but `getMagazineType()` names only the one last inserted. So it checks the profile's set first, or the speedloader list, and then falls back to matching the magazine type against both the short and the full item type, as vanilla B42 does (see `predicateNotFullMagazine`).
- `GetBestMagazine` uses Gunworks' `getBestMagazineForGun` for profile guns. `HandWeapon:getBestMagazine` only knows the one magazine type.
- `GetWeaponRoundTypes`: the gun's whole Gunworks ammo family in the player's reload order, or else its single ammo type. Store and fetch use it, so loose HP or AP rounds are bagged along with ball.

### Menu visibility
- `HasAmmoInInventory` needs a magazine or speedloader weapon. Only those separate "Store All Ammo" from "Store Spent Ammo", so without one that entry would just repeat the other. Speedloaders follow the magazine rule: Store Spent takes empty and part-used ones, and Store All takes full ones too.
- `GetFetchableRoundTypes` is empty for magazine weapons. Loose rounds are only worth fetching for a gun that loads them directly (speedloader guns included). A magazine-fed gun wants magazines, and Reload Magazines already draws rounds out of the bags without carrying them first.
- `HasReloadableMagazines` is true for an empty magazine gun with a magazine to hand. It is also true when the magazine in the gun is part-used and there is a spare to swap in, or loose rounds to top it up after ejecting. For any feed weapon, it is true when a non-full magazine or speedloader has rounds to hand.
- `FindReloadableMagazines` returns non-full magazines in priority order: main inventory first, then each worn bag.

### StoreInBag
Queues a move into the first bag that will take the item.
- `isItemAllowed` matters as much as the weight check. A restricted container such as a shoulder holster takes pistol magazines only, yet its weight reduction makes it report room for anything. Without the check it claims items it then refuses. That starves the bag that would have taken them, and it aborts the rest of the queue, because a rejected transfer stops and resets it.
- `hasRoomFor` only sees a bag as it is right now, and nothing has moved while the queue is being built. So each bag is also charged for the weight already promised to it (`reserved`).

### ReloadMagazines
- **Ejecting first.** A part-used magazine in the gun should be topped up too. But `ISEjectMagazine` only creates the item once its animation has run, so it cannot be queued for refilling in the same pass. Instead the reload queues the eject plus `MagazineBag_ContinueReload`, which plans again on pass 2, when the ejected magazine is an ordinary spare.
- **Loading the gun last.** The gun is loaded at the end, after the spares, so whichever magazine goes in is already full by then.
- **Planned before queued.** Every magazine's refill is worked out first (`entry.loads`, `entry.bullets`), then the magazine for the gun is chosen, then the actions are queued. The choice needs to know what each magazine will hold after its refill, and the queue needs to know which one stays in hand.
- **Which magazine goes in** (`ChooseInsertMagazine`). The target is the chambered round (the last `AmmoList` entry when a round is chambered), or else the gun's `getAmmoType()`, which Gunworks sets to each round as it's fired, so it's the last round fired. Candidates are every accepted magazine carried, full ones included, judged by their count after the planned refill. A magazine that will hold only the target round wins on round count, then capacity. If none will, the one with the most capacity goes in, then the most rounds. Empty ones never go in. Without Gunworks there is one round type, so this comes down to the fullest magazine, as before.
- **Speedloader guns load first.** Pass 1 hands the revolver to `ISReloadWeaponAction.BeginAutomaticReload`, the R-key reload that Gunworks hooks. An empty cylinder takes the best speedloader, and a part-loaded one takes loose rounds in the player's ammo order. Then `MagazineBag_ContinueReload` refills the speedloaders on pass 2. The order is reversed from magazines because Gunworks' insert hook only empties a speedloader into the cylinder and leaves the item behind. Refilling afterwards tops up the one just used, and planning it on pass 2 sees its real, emptied count.
- `HasReloadableMagazines` for a speedloader gun is also true when the revolver can take rounds: loose rounds on hand, or an empty cylinder with a loaded speedloader.
- **One magazine at a time.** A bag discounts the weight of what it holds, so a whole reload's worth of rounds in hand can push the character over their carry weight. Loading uses up the rounds and each magazine goes straight back into a bag, so only one magazine's worth is carried at any time.
- **One call to getSomeTypeRecurse per round type.** Each type is fetched once, for the combined need of every magazine that accepts it, and the result is handed out in slices. Calling it per magazine would return the same rounds each time, since nothing has moved yet while the queue is built.
- **Switching round type.** Before each load whose type differs from the magazine's current one, `MagazineBag_SetAmmoType` calls Gunworks' `MagazineAmmoProfileSetter`. It runs in the queue, not at planning time, so a cancelled reload never leaves a magazine switched to a round it didn't get. It runs after the magazine has moved to the main inventory, because Gunworks' server handler only looks there.
- **Each load is capped.** Vanilla `ISLoadBulletsInMagazine` ignores its `ammoCount`: it loads until the magazine is full or the main inventory has none of that round left. A mixed plan (10 ball, then 20 HP) would have the ball load swallow every ball round in hand, including rounds moved there for later magazines, and fill up, so the HP load does nothing and the HP rounds are left in hand. So each load passes Gunworks' extra `ammoLimit` and `ammoTypeOverride` arguments (the same ones its own `reloadMagazine` uses). Without Gunworks they're ignored, and with one round type the overdraw only shifts rounds between magazines.
- `ISLoadBulletsInMagazine` only draws from the main inventory, so rounds are moved there first. The move uses `MagazineBag_TransferAction` rather than `transferIfNeeded`, which uses the vanilla action: a refusal there would reset the queue and abandon the reload.
- Bag magazines are taken out to load and put back afterwards. A filled magazine is put away before the next one starts, so its weight doesn't follow the character through the rest of the sequence. The one headed for the gun stays in hand.
- `ISInsertMagazine` needs the magazine in the main inventory, not in a bag.

### FindBagForItem
The first worn bag that will take the item right now, skipping the one that just turned it away. It's used when a queued move reaches a bag that has filled up since the move was planned.

### StoreAmmoToBag
Loose rounds are queued after the magazines, one run per round type. The transfer action only bulk-merges back-to-back moves of the same item type into the same container.

### FetchFreshAmmoFromBag
Fetches only what the character can carry without becoming encumbered.
- `hasRoomFor` on the main inventory checks the hard capacity. That is well above where Heavy Load sets in, which is the inventory's `getMaxWeight()` (the same limit `ISHotbar` checks). So the budget is `getMaxWeight() - getCapacityWeight()`, which is skipped when the character has unlimited carry.
- An item in a worn bag already counts toward the character's weight, discounted by the bag's weight reduction. Taking it out only adds back the part the bag was hiding: `weight * getWeightReduction() / 100`. A running total covers the moves the queue hasn't run yet.
- `hasRoomFor` stays in as the hard cap, with its own running total.
- Two passes over the bags: full magazines and speedloaders first, then loose rounds. Both share one weight budget, so without the ordering, loose rounds a revolver owner also wants could use up the budget and leave the speedloaders in the bag.

### Opening ammo boxes
"(Open Boxes)" versions of Reload and Fetch, each with its own option that is off by default.
- `GetReloadDemands` lists what the reload will need: each reloadable magazine or speedloader, plus the gun itself when it's a part-used magazine gun (its magazine becomes a spare after the eject) or a speedloader revolver. Each entry uses the same `GetReloadRoundTypes` the reload uses, so assignments decide which boxes are worth opening.
- `GetFetchDemands`: only for guns that load loose rounds. It asks for one full load (`getMaxAmmo()`). A magazine gun fetches magazines, and Reload already pulls rounds out of the bags.
- **One box at a time.** Opening every needed box up front would put all their rounds in hand at once. That breaks the one-magazine's-worth rule and can leave the character encumbered. So Reload (Open Boxes) runs in rounds, each ending in one `MagazineBag_ContinueReload`:
  1. Each round refills magazines from the loose rounds on hand, and each one goes back to its bag.
  2. It collects what's still short (`shortfall`) and opens **one** box for it (`MagazineBag_Boxes.OpenOne`).
  3. It plans again once that box's rounds exist. Opened rounds don't exist until the craft finishes, the same reason the eject needs a second pass.
  4. The gun is only loaded on the last round, when no box is left to open. Until then every refilled magazine goes back to its bag.
- **Loose rounds count as used.** A magazine still short after the refill plan has used up every loose round on its list. So the shortfall is planned with `looseUsed` (loose rounds count as 0), not counted again.
- **`openedBoxes`** is nil for a normal reload, and a table of box IDs already tried in box mode. It's carried through `ContinueReload`, including across the eject pass. A box that fails to open (its recipe refused) is skipped from then on, so the loop always ends.
- **Speedloader revolvers:** pass 1 opens one box first, but only if the revolver has nothing to load from (`RevolverHasRounds`: no loose rounds, and for an empty cylinder no loaded speedloader).

## MagazineBag_Boxes.lua
- **Finding boxes.** Built once from the game's craft recipes, so vanilla, Gunworks packs and any other mod's boxes are found without a list. A candidate is a recipe with one item input (amount 1) and one item output (amount > 1). The box has to name that recipe as its `DoubleClickRecipe`. That rule leaves out conversion recipes such as Guns of Marz's `Convert_MarzGuns_to_SWMG`, which also turn one item into rounds. Mapped outputs are resolved with `OutputMapper:getPatternForResult(round)`, which returns the box `Item` scripts for that round. Unmapped ones use the input's possible items.
- **`Plan`.** Loose rounds are used first, and a box is opened only for what they can't cover. A box's rounds count as available for later demands, so one box can serve several magazines. Options: `budget` (Fetch) charges each box the weight its bag was hiding, as in `FetchFreshAmmoFromBag`. `looseUsed` counts loose rounds as 0. `skip` is a set of box IDs to leave alone.
- **Opening.** Goes through vanilla `ISInventoryPaneContextMenu.OnNewCraft`, the same path as opening a box from its right-click menu. It checks the recipe and moves the box into the main inventory, where the rounds come out. That move uses the vanilla transfer action. A refusal would reset the queue, but moving a worn bag's item into the main inventory is practically never refused.
- The radial entries only show when `Plan` would open at least one box. Otherwise they'd be copies of the normal entries.

## MagazineBag_TransferAction.lua
A plain vanilla transfer with one change: where the item ends up.
- **Presentation is left alone.** An earlier version forced `CharacterActionAnims.RemoveBullets` on top of the transfer animation. That clip loops and is driven by anim events: its only vanilla user, `ISUnloadBulletsFromMagazine`, returns `getDuration() == -1` and ends the loop from an animEvent. A timed transfer handles no such events, so the character got stuck at the loop's hold point.
- **`resolveDestination`.** A restricted bag only turns an item away when the move actually runs. A shoulder holster reports room right up until it holds its second magazine, so a queue planned while it was empty sends too many items to it. Those items are redirected to the next bag that will take them. If none will, the move is dropped quietly, because a transfer that fails outright resets the whole queue behind it. This runs before `ISInventoryTransferAction:start` creates the item transaction, so the move is registered against the bag the item actually goes into.
- **`isValid` never returns false.** A failing action calls `stop()`, which resets the whole timed action queue, so one refused move would cancel every later step of the reload. Setting `dontAdd` uses vanilla's own no-op path: `start()` zeroes the timer and `transferItem()` moves nothing, so the action completes having done nothing and the queue carries on.

## MagazineBag_ContinueReload.lua
`ISEjectMagazine` creates the ejected magazine with `instanceItem()` when its animation finishes. That means the item doesn't exist while the reload is being planned. This action sits after the eject and runs the planning again, when the magazine is an ordinary spare.

## MagazineBag_SetAmmoType.lua
It sets the type before `ISBaseTimedAction.perform`, because that call can start the next action right away. The next action is the load, and `ISLoadBulletsInMagazine:start` checks the magazine's ammo type.

## MagazineBag_GunworksHooks.lua
Makes Gunworks' own reloads (the R key, its radial and "reload all magazines" paths) follow assignments. Gunworks calls these through the module table on every use, so replacing the table field is enough.
- `Ammo.GetAutomaticReloadAmmoType` returns the item's assignment. It returns it even when none of that round is carried: Gunworks then loads nothing, where a nil would let it fall back to the gun's current type. Magazine-fed guns are skipped, because their key belongs to the inserted magazine, and Gunworks never asks for their round type anyway.
- `SpeedLoader.GetBestSpeedLoaderForGun`: for an assigned gun, only a speedloader holding nothing but the assigned round (checked through its `AmmoList`, or its ammo type when there is none). If there isn't one, Gunworks falls through to loading loose assigned rounds.

## MagazineBag_AmmoMenu.lua
"Assign Ammo ▸" and "Unassign Ammo" apply to every selected magazine, speedloader or loose-round gun of the first one's family. Only carried items are offered, because the server applies the assignment by searching the player's inventory. The round counts shown are what the player carries, bags included.

## MagazineBag_Tooltip.lua
Other mods replace `ISToolTipInv:render` wholesale. Guns of Marz does it when its file loads. ZomboidFixesB42 does it on `OnGameStart`, and draws every `WeaponPart` itself without calling the previous render; Guns of Marz magazines are weapon parts. So the wrap is installed on the first `OnTick` after `OnGameStart`, after every `OnGameStart` handler has run, and so on top of whichever render ends up in place. Installed on `OnGameStart` itself, it was sometimes under ZomboidFixes: guns showed the row and magazines didn't. 
- **The row is part of the tooltip, not drawn after it.** Drawing it below a finished tooltip gave it its own background and border, with a divider line and columns that didn't line up. Instead, for the length of one render call, the item class's `DoTooltip` and `DoTooltipEmbedded` are wrapped on its metatable (the same technique as StarlitLibrary), then always restored, under `pcall`.
- **Renderers that build the layout themselves** call `DoTooltipEmbedded(tooltip, layout, offsetY)` from Lua (ZomboidFixesB42, StarlitLibrary). The row is added straight into their layout, so it lines up with the stat rows.
- **The vanilla path, and Guns of Marz,** call `DoTooltip(tooltip)`. Java then calls `DoTooltipEmbedded` itself, where Lua can't see it, so the row goes in its own small layout directly after the item's own content, inside the same `DoTooltip` call. The render's measuring pass includes it, so the one background and border cover it. A layout sizes its columns by itself, so a separate label/value row would leave a wide gap before the value. In this case the row is written as one label, "Assigned Ammo: <round>". `addedToLayout` stops the row being added twice when a `DoTooltip` replacement (Starlit's) routes through `DoTooltipEmbedded`.
- **Padding** can't be read, because instance fields are hidden from Lua. It's recomputed the way the game sets it, from the width of one digit (as ZomboidFixesB42 does).

## MagazineBag_Options.lua
- Option keys are deliberately not derived from the entry labels. Renaming an entry must not silently reset what players have already turned off.
- Anything that can't be read counts as its default. For most entries that means enabled, so a setting the game hasn't registered or loaded is never why an entry goes missing. The Open Boxes entries default to off (`DEFAULTS`), because opening boxes uses them up, and a player has to choose that.
- B42 ships `PZAPI.ModOptions`. The main options screen only builds its mod panel if something has registered by the time that screen is created, which is before `OnGameStart`. So registration runs as the file loads.

## MagazineBag_RadialMenu.lua
In B42, `fillMenu` is an instance method. Its data is the menu object, with `character`/`playerNum` set in `ISFirearmRadialMenu:new`.

## MagazineBag_Server.lua
In B42 MP the server's copy of the inventory is what gets saved. Bag and ammo assignments made client-side have to be applied here too, or they vanish on logout. The item is found with `getItemWithIDRecursiv`, so a magazine in a worn bag is found as well. An earlier hand-written search called `getItemContainer()` on every item it passed, but only container items have that method in B42. Any other item threw an error, so assignments to magazines in bags never reached the server. They then disappeared on relog, and after any server update to the item.
