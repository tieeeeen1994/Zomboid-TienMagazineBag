require "TimedActions/ISBaseTimedAction"
require 'MagazineBag_Core'

MagazineBag_StoreRounds = ISBaseTimedAction:derive("MagazineBag_StoreRounds")

local SYNC_WAIT_MS = 1000

function MagazineBag_StoreRounds:isValid()
    return true
end

function MagazineBag_StoreRounds:waitToStart()
    if not isClient() or not self.expected then return false end

    self.waitStartMs = self.waitStartMs or getTimestampMs()
    local count = MagazineBag_Core.CountLooseRounds(self.character, self.roundTypes)
    if count == self.expected then return false end
    if getTimestampMs() - self.waitStartMs < SYNC_WAIT_MS then return true end

    print("[TienMagazineBag] " .. self.Type .. " went on after " .. SYNC_WAIT_MS .. " ms without the server's result. loose rounds="
        .. count .. ", expected=" .. self.expected)
    return false
end

function MagazineBag_StoreRounds:perform()
    ISBaseTimedAction.perform(self)

    MagazineBag_Core.StoreLooseRounds(self.character, self.roundTypes)
end

function MagazineBag_StoreRounds:new(character, roundTypes, expected)
    local o = ISBaseTimedAction.new(self, character)
    o.roundTypes = roundTypes
    o.expected = expected
    o.maxTime = 1
    o.useProgressBar = false
    o.stopOnAim = false
    o.stopOnWalk = false
    o.stopOnRun = not MagazineBag_Core.HasRunningReload(character)
    return o
end
