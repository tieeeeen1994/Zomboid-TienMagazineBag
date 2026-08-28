require "TimedActions/ISInventoryTransferAction"

-- Server-safe transfer with the old mod's presentation: inherits
-- ISInventoryTransferAction's transaction/sync logic untouched and overrides
-- the animation, hand models and sounds.
MagazineBag_TransferAction = ISInventoryTransferAction:derive("MagazineBag_TransferAction")

function MagazineBag_TransferAction:start()
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
