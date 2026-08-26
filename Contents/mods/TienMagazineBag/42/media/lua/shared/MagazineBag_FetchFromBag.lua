require "TimedActions/ISBaseTimedAction"

MagazineBag_FetchFromBag = ISBaseTimedAction:derive("MagazineBag_FetchFromBag")

function MagazineBag_FetchFromBag:new(character, magazine, sourceBag)
    local o = ISBaseTimedAction.new(self, character)
    o.magazine = magazine
    o.sourceBag = sourceBag
    o.maxTime = 12
    o.animation = CharacterActionAnims.RemoveBullets
    o.caloriesModifier = 1
    o.stopOnWalk = false
    o.stopOnRun = true
    o.useProgressBar = true
    return o
end

function MagazineBag_FetchFromBag:isValid()
    local bagContainer = self.sourceBag and self.sourceBag:getItemContainer()
    return self.character and self.magazine and bagContainer and
           bagContainer:contains(self.magazine)
end

function MagazineBag_FetchFromBag:waitToStart()
    return false
end

function MagazineBag_FetchFromBag:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
    self.magazine:setJobDelta(self:getJobDelta())
end

function MagazineBag_FetchFromBag:start()
    self.magazine:setJobType("Fetching Magazine from Magazine Bag")
    self.magazine:setJobDelta(0.0)

    self:setActionAnim(self.animation)

    local magazineModel = self.magazine:getStaticModel()
    self:setOverrideHandModels(magazineModel, magazineModel)

    self.character:getEmitter():playSound("BoxOfRoundsOpenOne")
end

function MagazineBag_FetchFromBag:stop()
    ISBaseTimedAction.stop(self)
    self.magazine:setJobDelta(0.0)
    self.magazine:setJobType("")
end

function MagazineBag_FetchFromBag:perform()
    local playerInventory = self.character:getInventory()
    local bagContainer = self.sourceBag:getItemContainer()
    if bagContainer and bagContainer:contains(self.magazine) then
        bagContainer:DoRemoveItem(self.magazine)
        playerInventory:AddItem(self.magazine)
        sendRemoveItemFromContainer(bagContainer, self.magazine)
        sendAddItemToContainer(playerInventory, self.magazine)
    end

    ISBaseTimedAction.perform(self)

    self.magazine:setJobDelta(0.0)
    self.magazine:setJobType("")
end
