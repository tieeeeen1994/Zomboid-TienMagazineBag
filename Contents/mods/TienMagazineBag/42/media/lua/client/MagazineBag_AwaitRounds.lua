require "TimedActions/ISBaseTimedAction"

MagazineBag_AwaitRounds = ISBaseTimedAction:derive("MagazineBag_AwaitRounds")

local WAIT_MS = 3000

function MagazineBag_AwaitRounds:isValid()
    return true
end

function MagazineBag_AwaitRounds:hasRounds()
    return self.character:getInventory():containsWithModule(self.roundType)
end

function MagazineBag_AwaitRounds:waitToStart()
    if not isClient() then return false end

    self.waitStartMs = self.waitStartMs or getTimestampMs()
    return getTimestampMs() - self.waitStartMs < WAIT_MS and not self:hasRounds()
end

function MagazineBag_AwaitRounds:perform()
    if not self:hasRounds() then
        local queue = ISTimedActionQueue.getTimedActionQueue(self.character)
        for _, action in ipairs(self.dependents) do
            queue:removeFromQueue(action)
        end
    end

    ISBaseTimedAction.perform(self)
end

function MagazineBag_AwaitRounds:new(character, roundType)
    local o = ISBaseTimedAction.new(self, character)
    o.roundType = roundType
    o.dependents = {}
    o.maxTime = 1
    o.useProgressBar = false
    o.stopOnAim = false
    o.stopOnWalk = false
    o.stopOnRun = true
    return o
end
