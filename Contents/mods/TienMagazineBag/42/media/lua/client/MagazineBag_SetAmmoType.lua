require "TimedActions/ISBaseTimedAction"
require 'MagazineBag_Core'

MagazineBag_SetAmmoType = ISBaseTimedAction:derive("MagazineBag_SetAmmoType")

function MagazineBag_SetAmmoType:isValid()
    return true
end

function MagazineBag_SetAmmoType:perform()
    MagazineBag_Core.SetMagazineRoundType(self.magazine, self.roundType)

    ISBaseTimedAction.perform(self)
end

function MagazineBag_SetAmmoType:new(character, magazine, roundType)
    local o = ISBaseTimedAction.new(self, character)
    o.magazine = magazine
    o.roundType = roundType
    o.maxTime = 1
    o.useProgressBar = false
    o.stopOnAim = false
    o.stopOnWalk = false
    o.stopOnRun = true
    return o
end
