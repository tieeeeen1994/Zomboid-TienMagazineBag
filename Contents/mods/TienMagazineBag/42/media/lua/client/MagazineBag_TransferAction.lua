require "TimedActions/ISInventoryTransferAction"
require 'MagazineBag_Core'

-- A plain vanilla transfer, with one change: where the item ends up.
--
-- Presentation is deliberately left alone. An earlier version forced
-- CharacterActionAnims.RemoveBullets on top of the transfer animation, but that
-- clip is looping and event-driven -- its only vanilla user,
-- ISUnloadBulletsFromMagazine, reports getDuration() == -1 and ends the loop
-- itself from an animEvent. A time-driven transfer handles no such events, so
-- the character reached the hold point of the loop and stayed in it.
MagazineBag_TransferAction = ISInventoryTransferAction:derive("MagazineBag_TransferAction")

-- A restricted bag only turns an item away at the moment the move runs: a
-- shoulder holster reports room right up until it holds its second magazine, so
-- a queue planned while it was empty aims too many items at it. Send those on to
-- the next bag that will take them, and where nothing will, give the move up
-- quietly -- a transfer that fails outright resets the whole queue behind it.
--
-- This runs before ISInventoryTransferAction:start creates the item
-- transaction, so the move is registered against the bag it ends up in.
function MagazineBag_TransferAction:resolveDestination()
    if self.resolvedDestination then return end
    self.resolvedDestination = true

    if not self.item or not self.destContainer then return end
    if self.destContainer:isItemAllowed(self.item) then return end

    local bagContainer = MagazineBag_Core.FindBagForItem(self.character, self.item, self.destContainer)
    if bagContainer then
        self.destContainer = bagContainer
    else
        self.noBagLeft = true
    end
end

function MagazineBag_TransferAction:isValid()
    self:resolveDestination()

    -- dontAdd is the vanilla no-op path: start() zeroes the timer and
    -- transferItem() moves nothing, so the action completes and the queue lives
    if self.noBagLeft then
        self.dontAdd = true
        return true
    end

    return ISInventoryTransferAction.isValid(self)
end

function MagazineBag_TransferAction:start()
    self:resolveDestination()

    if self.noBagLeft then
        self.dontAdd = true
    end

    ISInventoryTransferAction.start(self)
end
