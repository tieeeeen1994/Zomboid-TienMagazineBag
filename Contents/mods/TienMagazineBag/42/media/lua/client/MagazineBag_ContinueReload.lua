require "TimedActions/ISBaseTimedAction"

-- A carton unpacks into boxes that don't exist yet while "Reload Magazines" is
-- being queued, so this sits after the unpacking actions and plans the next
-- pass once they have run.
MagazineBag_ContinueReload = ISBaseTimedAction:derive("MagazineBag_ContinueReload")

function MagazineBag_ContinueReload:isValid()
    return true
end

function MagazineBag_ContinueReload:perform()
    ISBaseTimedAction.perform(self)

    MagazineBag_Core.ReloadMagazines(self.character, self.pass)
end

function MagazineBag_ContinueReload:new(character, pass)
    local o = ISBaseTimedAction.new(self, character)
    o.pass = pass
    o.maxTime = 1
    o.useProgressBar = false
    o.stopOnAim = false
    o.stopOnWalk = false
    o.stopOnRun = true
    return o
end
