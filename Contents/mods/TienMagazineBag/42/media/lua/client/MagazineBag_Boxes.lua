require 'MagazineBag_Core'

MagazineBag_Boxes = {}

local boxesByRound = nil

local function ShortName(name)
    return name and (name:match("%.([^%.]+)$") or name)
end

local function AddBoxes(round, boxes, recipe, count)
    if not round or not boxes then return end

    local roundType = round:getFullName()
    for i = 0, boxes:size() - 1 do
        local box = boxes:get(i)
        if ShortName(box:getDoubleClickRecipe()) == ShortName(recipe:getName()) then
            boxesByRound[roundType] = boxesByRound[roundType] or {}
            table.insert(boxesByRound[roundType], { boxType = box:getFullName(), recipe = recipe, count = count })
        end
    end
end

local function BuildBoxMap()
    boxesByRound = {}

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
                local rounds = output:getPossibleResultItems()

                for r = 0, rounds:size() - 1 do
                    local round = rounds:get(r)
                    if mapper and not mapper:isEmpty() then
                        AddBoxes(round, mapper:getPatternForResult(round), recipe, output:getIntAmount())
                    elseif rounds:size() == 1 then
                        AddBoxes(round, input:getPossibleInputItems(), recipe, output:getIntAmount())
                    end
                end
            end
        end
    end
end

local function GetBoxTypes(roundType)
    if not boxesByRound then BuildBoxMap() end
    return boxesByRound[roundType] or {}
end

local function FindBox(inventory, roundType, used)
    for _, def in ipairs(GetBoxTypes(roundType)) do
        local items = inventory:getAllTypeRecurse(def.boxType)
        for i = 0, items:size() - 1 do
            local box = items:get(i)
            if not used[box:getID()] then
                return box, def
            end
        end
    end
    return nil
end

local function BoxCost(player, box)
    local container = box:getContainer()
    if not container or container == player:getInventory() then return 0 end
    return box:getActualWeight() * (container:getWeightReduction() or 0) / 100
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
                local box, def = FindBox(inventory, roundType, used)
                if not box then break end
                used[box:getID()] = true

                local cost = BoxCost(player, box)
                if budget == nil or cost <= budget then
                    if budget then budget = budget - cost end
                    table.insert(planned, { box = box, recipe = def.recipe })
                    available[roundType] = count(roundType) + def.count
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

local function OpenBox(player, entry)
    ISInventoryPaneContextMenu.OnNewCraft(entry.box, entry.recipe, player:getPlayerNum(), false)
end

function MagazineBag_Boxes.Open(player, demands, budget)
    local planned = MagazineBag_Boxes.Plan(player, demands, { budget = budget })
    for _, entry in ipairs(planned) do
        OpenBox(player, entry)
    end
    return #planned > 0
end

function MagazineBag_Boxes.OpenOne(player, demands, skip)
    local entry = MagazineBag_Boxes.Plan(player, demands, { looseUsed = true, skip = skip })[1]
    if not entry then return nil end

    OpenBox(player, entry)
    return entry.box:getID()
end
