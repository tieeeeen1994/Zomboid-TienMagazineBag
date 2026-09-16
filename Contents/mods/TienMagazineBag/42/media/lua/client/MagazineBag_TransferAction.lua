require "TimedActions/ISInventoryTransferAction"
require 'MagazineBag_Core'

MagazineBag_TransferAction = ISInventoryTransferAction:derive("MagazineBag_TransferAction")

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

    if self.noBagLeft or not ISInventoryTransferAction.isValid(self) then
        self.dontAdd = true
    end

    return true
end

function MagazineBag_TransferAction:start()
    self:resolveDestination()

    if self.noBagLeft then
        self.dontAdd = true
    end

    ISInventoryTransferAction.start(self)
end
