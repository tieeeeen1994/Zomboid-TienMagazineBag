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

    print("[TienMagazineBag] " .. self.Type .. " went on after " .. SYNC_WAIT_MS .. " ms without the server's result. " .. tostring(detail))
    return false
end

function MagazineBag_ContinueReload:perform()
    ISBaseTimedAction.perform(self)

    MagazineBag_Core.ReloadMagazines(self.character, self.pass, self.boxRun)
end

function MagazineBag_ContinueReload:new(character, pass, boxRun, synced)
    local o = ISBaseTimedAction.new(self, character)
    o.pass = pass
    o.boxRun = boxRun
    o.synced = synced
    o.maxTime = 1
    o.useProgressBar = false
    o.stopOnAim = false
    o.stopOnWalk = false
    o.stopOnRun = not MagazineBag_Core.HasRunningReload(character)
    return o
end

local pendingRestarts = {}

local function IsRunning(character)
    return character:isRunning() or character:isSprinting()
end

local function IsWalking(character)
    return character:isPlayerMoving() or character:pressedMovement(false)
end

local function CancelsReload(character)
    return IsRunning(character) and not MagazineBag_Core.HasRunningReload(character)
end

function MagazineBag_ContinueReload:forceCancel()
    if self.boxRun and IsWalking(self.character) and not CancelsReload(self.character) then
        pendingRestarts[self.character:getPlayerNum()] = self
    end
end

function MagazineBag_ContinueReload:restart()
    self.boxRun.tried = {}
    MagazineBag_Core.ReloadMagazines(self.character, 1, self.boxRun)
end

MagazineBag_ContinueFetch = MagazineBag_ContinueReload:derive("MagazineBag_ContinueFetch")

function MagazineBag_ContinueFetch:perform()
    ISBaseTimedAction.perform(self)

    MagazineBag_Core.FetchFromBoxes(self.character, self.boxRun, MagazineBag_Core.FetchBudget(self.character))
end

function MagazineBag_ContinueFetch:restart()
    self.boxRun.tried = {}
    MagazineBag_Core.FetchFromBoxes(self.character, self.boxRun, MagazineBag_Core.FetchBudget(self.character))
end

function MagazineBag_ContinueFetch:new(character, boxRun, synced)
    return MagazineBag_ContinueReload.new(self, character, nil, boxRun, synced)
end

local function CheckRestart(player)
    local playerNum = player:getPlayerNum()
    local step = pendingRestarts[playerNum]
    if not step then return end

    if step.character ~= player or player:isDead() or CancelsReload(player)
            or not player:getCharacterActions():isEmpty() then
        pendingRestarts[playerNum] = nil
        return
    end
    if IsWalking(player) or player:isAiming() then return end

    pendingRestarts[playerNum] = nil
    step:restart()
end

Events.OnPlayerUpdate.Add(CheckRestart)
