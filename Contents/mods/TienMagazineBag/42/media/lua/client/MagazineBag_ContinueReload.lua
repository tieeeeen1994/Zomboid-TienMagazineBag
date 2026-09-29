require "TimedActions/ISBaseTimedAction"

MagazineBag_ContinueReload = ISBaseTimedAction:derive("MagazineBag_ContinueReload")

local SYNC_WAIT_MS = 1000

function MagazineBag_ContinueReload:isValid()
    return true
end

function MagazineBag_ContinueReload:waitToStart()
    if not self.synced then return false end

    self.waitStartMs = self.waitStartMs or getTimestampMs()
    local synced, detail = self.synced()
    if synced then return false end
    if getTimestampMs() - self.waitStartMs < SYNC_WAIT_MS then return true end

    print("[TienMagazineBag] Reload went on after " .. SYNC_WAIT_MS .. " ms without the server's result. " .. tostring(detail))
    return false
end

function MagazineBag_ContinueReload:perform()
    ISBaseTimedAction.perform(self)

    MagazineBag_Core.ReloadMagazines(self.character, self.pass, self.openedBoxes)
end

function MagazineBag_ContinueReload:new(character, pass, openedBoxes, synced)
    local o = ISBaseTimedAction.new(self, character)
    o.pass = pass
    o.openedBoxes = openedBoxes
    o.synced = synced
    o.maxTime = 1
    o.useProgressBar = false
    o.stopOnAim = false
    o.stopOnWalk = false
    o.stopOnRun = true
    return o
end
