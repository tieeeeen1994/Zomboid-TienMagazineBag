require "TimedActions/ISInventoryTransferAction"
require 'MagazineBag_Core'

-- Server-safe transfer with the old mod's presentation: inherits
-- ISInventoryTransferAction's transaction/sync logic and overrides the
-- animation, hand models and sounds, plus the choice of destination bag.
MagazineBag_TransferAction = ISInventoryTransferAction:derive("MagazineBag_TransferAction")

-- A restricted bag only turns an item away at the moment the move runs: a
-- shoulder holster reports room right up until it holds its second magazine,
-- so a queue planned while it was empty aims too many items at it. Send those
-- on to the next bag that will take them instead, and where nothing will, give
-- the move up quietly -- a transfer that fails outright resets the whole queue
-- behind it.
--
-- This runs before ISInventoryTransferAction:start creates the item
-- transaction, so the move is registered against the bag it actually ends up
-- in.
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

    -- replace the vanilla rummage loop with the old mod's flavor sound
    if self.loopSound then
        self.character:getEmitter():stopSound(self.loopSound)
        self.loopSound = nil
    end
end

function MagazineBag_TransferAction:startActionAnim()
    ISInventoryTransferAction.startActionAnim(self)

    self:setActionAnim(CharacterActionAnims.RemoveBullets)

    local magazineModel = self.item:getStaticModel()
    self:setOverrideHandModels(magazineModel, magazineModel)

    if self.flavorSound then
        self.character:getEmitter():playSound(self.flavorSound)
    end
end

function MagazineBag_TransferAction:new(character, item, srcContainer, destContainer, flavorSound)
    local o = ISInventoryTransferAction.new(self, character, item, srcContainer, destContainer)
    o.flavorSound = flavorSound
    return o
end
