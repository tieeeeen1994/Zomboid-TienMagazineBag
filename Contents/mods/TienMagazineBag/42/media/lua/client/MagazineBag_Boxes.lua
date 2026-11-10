require 'MagazineBag_Core'

MagazineBag_Boxes = {}

local MAX_DEPTH = 3

local openersByItem = nil

local function ShortName(name)
    return name and (name:match("%.([^%.]+)$") or name)
end

local function AddOpeners(output, containers, recipe, count)
    if not output or not containers then return end

    local outputType = output:getFullName()
    for i = 0, containers:size() - 1 do
        local container = containers:get(i)
        if ShortName(container:getDoubleClickRecipe()) == ShortName(recipe:getName()) then
            openersByItem[outputType] = openersByItem[outputType] or {}
            table.insert(openersByItem[outputType], { boxType = container:getFullName(), recipe = recipe, count = count })
        end
    end
end

local function BuildOpenerMap()
    openersByItem = {}

    local recipes = getScriptManager():getAllCraftRecipes()
    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i)
        local inputs = recipe:getInputs()
        local outputs = recipe:getOutputs()

        if inputs:size() == 1 and outputs:size() == 1 then
            local input = inputs:get(0)
            local output = outputs:get(0)

            if input:getResourceType() == ResourceType.Item and output:getResourceType() == ResourceType.Item
                    and input:getIntAmount() == 1 and output:getIntAmount() > 1 then
                local mapper = output:getOutputMapper()
                local results = output:getPossibleResultItems()

                for r = 0, results:size() - 1 do
                    local result = results:get(r)
                    if mapper and not mapper:isEmpty() then
                        AddOpeners(result, mapper:getPatternForResult(result), recipe, output:getIntAmount())
                    elseif results:size() == 1 then
                        AddOpeners(result, input:getPossibleInputItems(), recipe, output:getIntAmount())
                    end
                end
            end
        end
    end
end

local function GetOpeners(itemType)
    if not openersByItem then BuildOpenerMap() end
    return openersByItem[itemType] or {}
end

local function FindSource(inventory, itemType, used, depth)
    local openers = GetOpeners(itemType)

    for _, def in ipairs(openers) do
        local items = inventory:getAllTypeRecurse(def.boxType)
        for i = 0, items:size() - 1 do
            local box = items:get(i)
            if not used[box:getID()] then
                return box, def, itemType, def.count
            end
        end
    end

    if depth >= MAX_DEPTH then return nil end

    for _, def in ipairs(openers) do
        local box, found, outputType, yield = FindSource(inventory, def.boxType, used, depth + 1)
        if box then
            return box, found, outputType, yield * def.count
        end
    end
    return nil
end

local function BoxCost(player, box)
    local container = box:getContainer()
    if not container or container == player:getInventory() then return 0 end
    return box:getActualWeight() * (container:getWeightReduction() or 0) / 100
end

function MagazineBag_Boxes.NewRun()
    return { tried = {}, leftovers = {} }
end

function MagazineBag_Boxes.Plan(player, demands, options)
    options = options or {}
    local inventory = player:getInventory()
    local budget = options.budget
    local available, used, planned = {}, {}, {}

    for id in pairs(options.skip or {}) do used[id] = true end

    local function count(roundType)
        if available[roundType] == nil then
            available[roundType] = options.looseUsed and 0 or inventory:getItemCountRecurse(roundType)
        end
        return available[roundType]
    end

    local function take(roundType, needed)
        local taken = math.min(needed, count(roundType))
        available[roundType] = available[roundType] - taken
        return needed - taken
    end

    for _, demand in ipairs(demands) do
        local needed = demand.needed

        for _, roundType in ipairs(demand.roundTypes) do
            if needed <= 0 then break end
            needed = take(roundType, needed)
        end

        for _, roundType in ipairs(demand.roundTypes) do
            while needed > 0 do
                local box, def, outputType, yield = FindSource(inventory, roundType, used, 1)
                if not box then break end
                used[box:getID()] = true

                local cost = BoxCost(player, box)
                if budget == nil or cost <= budget then
                    if budget then budget = budget - cost end
                    table.insert(planned, {
                        box = box,
                        recipe = def.recipe,
                        roundType = roundType,
                        count = yield,
                        outputType = outputType,
                        outputCount = def.count,
                    })
                    available[roundType] = count(roundType) + yield
                    needed = take(roundType, needed)
                end
            end
            if needed <= 0 then break end
        end
    end

    return planned
end

function MagazineBag_Boxes.HasBoxesFor(player, demands)
    return #MagazineBag_Boxes.Plan(player, demands) > 0
end

function MagazineBag_Boxes.IsContainerOfBoxes(entry)
    return entry.outputType ~= entry.roundType
end

local function SourceBag(player, run, box)
    local container = box:getContainer()
    if container and container ~= player:getInventory() then return container end

    for _, record in ipairs(run.leftovers) do
        if record.itemType == box:getFullType() and not record.before[box:getID()] then
            return record.bag
        end
    end
    return nil
end

local function RememberLeftovers(player, run, entry)
    if not MagazineBag_Boxes.IsContainerOfBoxes(entry) then return end

    local bag = SourceBag(player, run, entry.box)
    if not bag then return end

    local before = {}
    local items = player:getInventory():getAllType(entry.outputType)
    for i = 0, items:size() - 1 do
        before[items:get(i):getID()] = true
    end
    table.insert(run.leftovers, { itemType = entry.outputType, bag = bag, before = before })
end

local function OpenBox(player, entry, run)
    run.tried[entry.box:getID()] = true
    RememberLeftovers(player, run, entry)
    ISInventoryPaneContextMenu.OnNewCraft(entry.box, entry.recipe, player:getPlayerNum(), false)
end

function MagazineBag_Boxes.Open(player, demands, budget, run)
    local planned = MagazineBag_Boxes.Plan(player, demands, { budget = budget, skip = run.tried })
    local opened = {}
    for _, entry in ipairs(planned) do
        OpenBox(player, entry, run)
        table.insert(opened, entry)
        if MagazineBag_Boxes.IsContainerOfBoxes(entry) then
            break
        end
    end
    return opened
end

function MagazineBag_Boxes.OpenOne(player, demands, run)
    local entry = MagazineBag_Boxes.Plan(player, demands, { looseUsed = true, skip = run.tried })[1]
    if not entry then return nil end

    OpenBox(player, entry, run)
    return entry
end

function MagazineBag_Boxes.SyncedAfterOpen(player, entries)
    local inventory = player:getInventory()
    local expected, ids = {}, {}
    for _, entry in ipairs(entries) do
        local itemType = entry.outputType
        expected[itemType] = (expected[itemType] or inventory:getItemCountRecurse(itemType)) + entry.outputCount
        table.insert(ids, entry.box:getID())
    end
    for _, entry in ipairs(entries) do
        local ownType = entry.box:getFullType()
        if expected[ownType] then
            expected[ownType] = expected[ownType] - 1
        end
    end

    return function()
        for _, id in ipairs(ids) do
            if inventory:getItemWithIDRecursiv(id) ~= nil then
                return false, "opened container " .. tostring(id) .. " still carried"
            end
        end
        for itemType, total in pairs(expected) do
            local now = inventory:getItemCountRecurse(itemType)
            if now < total then
                return false, string.format("%s carried=%d, expected at least %d", itemType, now, total)
            end
        end
        return true
    end
end

function MagazineBag_Boxes.ReturnLeftovers(player, run)
    local inventory = player:getInventory()
    local queued = {}

    for _, record in ipairs(run.leftovers) do
        local items = inventory:getAllType(record.itemType)
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local id = item:getID()
            if not record.before[id] and not queued[id] then
                queued[id] = true
                ISTimedActionQueue.add(MagazineBag_TransferAction:new(player, item, inventory, record.bag))
            end
        end
    end

    run.leftovers = {}
end
