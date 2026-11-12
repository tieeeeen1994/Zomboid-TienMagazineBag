require "Entity/TimedActions/ISHandcraftAction"

MagazineBag_BoxAnimSync = {}

local BOX_ANIM = "OpenAmmoBox"
local LEFTOVER_FLAGS = { "isLoading", "isLoadingShort", "isRacking", "isUnloading", "RackAiming" }
local LEFTOVER_STRINGS = { "GunworksReloadAnim" }
local CHECK_EVERY_TICKS = 3
local STUCK_MS = 3000

local function isEnabled()
    local vars = SandboxVars and SandboxVars.TienMagazineBag
    return vars ~= nil and vars.BoxAnimationSync == true
end

MagazineBag_BoxAnimSync.isEnabled = isEnabled

local function IsBoxOpening(action)
    local script = action.actionScript
    return script ~= nil and tostring(script:getActionAnim()) == BOX_ANIM
end

local vanillaStart = ISHandcraftAction.start

function ISHandcraftAction:start()
    if isClient() and isEnabled() and IsBoxOpening(self) then
        for _, key in ipairs(LEFTOVER_FLAGS) do
            self:setAnimVariable(key, false)
        end
        for _, key in ipairs(LEFTOVER_STRINGS) do
            self:setAnimVariable(key, "")
        end
    end
    return vanillaStart(self)
end

if not isClient() then return end

local firstSeen = {}
local ticks = 0

local function ClearLeftovers(player)
    for _, key in ipairs(LEFTOVER_FLAGS) do
        if player:getVariableBoolean(key) then
            player:clearVariable(key)
        end
    end
    for _, key in ipairs(LEFTOVER_STRINGS) do
        local value = player:getVariableString(key)
        if value and value ~= "" then
            player:clearVariable(key)
        end
    end
    if player:getVariableBoolean("isTurning") then
        player:setVariable("isTurning", false)
    end
end

local function EndBoxOpening(player)
    player:clearVariable("PerformingAction")
    player:setVariable("IsPerformingAnAction", false)
    player:resetEquippedHandsModels()
end

local function CheckRemote(player, now)
    local name = player:getUsername()
    if player:getVariableString("PerformingAction") ~= BOX_ANIM then
        firstSeen[name] = nil
        return
    end

    local since = firstSeen[name]
    if not since then
        since = now
        firstSeen[name] = now
    end

    if now - since > STUCK_MS then
        EndBoxOpening(player)
        firstSeen[name] = nil
        return
    end

    ClearLeftovers(player)
    if not player:getVariableBoolean("IsPerformingAnAction") and not player:isPlayerMoving() then
        player:setVariable("IsPerformingAnAction", true)
    end
end

local function OnTick()
    ticks = ticks + 1
    if ticks < CHECK_EVERY_TICKS then return end
    ticks = 0
    if not isEnabled() then return end

    local players = getOnlinePlayers()
    if not players then return end

    local now = getTimestampMs()
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player and not player:isLocalPlayer() then
            CheckRemote(player, now)
        end
    end
end

Events.OnTick.Add(OnTick)
