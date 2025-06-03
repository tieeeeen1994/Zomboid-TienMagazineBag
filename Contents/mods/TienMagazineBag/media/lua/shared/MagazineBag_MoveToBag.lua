require "TimedActions/ISBaseTimedAction"

MagazineBag_MoveToBag = ISBaseTimedAction:derive("MagazineBag_MoveToBag")

function MagazineBag_MoveToBag:new(character, magazine, targetBag)
    local o = ISBaseTimedAction.new(self, character)
    o.magazine = magazine
    o.targetBag = targetBag
    o.maxTime = 12
    o.animation = CharacterActionAnims.RemoveBullets
    o.caloriesModifier = 1
    o.stopOnWalk = false
	o.stopOnRun = true
    o.useProgressBar = true
    return o
end

function MagazineBag_MoveToBag:isValid()
    return self.character and self.magazine and self.targetBag and
           self.character:getInventory():contains(self.magazine)
end

function MagazineBag_MoveToBag:waitToStart()
    return false
end

function MagazineBag_MoveToBag:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
    self.magazine:setJobDelta(self:getJobDelta())
end

function MagazineBag_MoveToBag:start()
    self.magazine:setJobType("Moving Magazine to Magazine Bag")
    self.magazine:setJobDelta(0.0)

    self:setActionAnim(self.animation)

    local magazineModel = self.magazine:getStaticModel()
    self:setOverrideHandModels(magazineModel, magazineModel)

    self.character:getEmitter():playSound("PutItemInBag")
end

function MagazineBag_MoveToBag:stop()
    ISBaseTimedAction.stop(self)
    self.magazine:setJobDelta(0.0)
    self.magazine:setJobType("")
end

function MagazineBag_MoveToBag:perform()
    local bagContainer = self.targetBag:getItemContainer()
    if bagContainer and bagContainer:hasRoomFor(self.character, self.magazine:getWeight()) then
        self.character:getInventory():DoRemoveItem(self.magazine)
        bagContainer:AddItem(self.magazine)
    end

    ISBaseTimedAction.perform(self)

    self.magazine:setJobDelta(0.0)
    self.magazine:setJobType("")
end
