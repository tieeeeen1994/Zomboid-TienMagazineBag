require "ISUI/ISToolTipInv"
require 'MagazineBag_Core'

local LABEL = "Assigned Ammo:"

local function addRow(layout, roundType)
    local row = layout:addItem()
    row:setLabel(LABEL, 1, 1, 0.8, 1)
    row:setValue(MagazineBag_Core.GetRoundDisplayName(roundType), 1, 1, 1, 1)
end

local function appendRow(tooltip, roundType)
    local padSide = getTextManager():MeasureStringX(tooltip:getFont(), "0")
    local padEnd = math.floor(padSide / 2)

    local layout = tooltip:beginLayout()
    layout:addItem():setLabel(LABEL .. " " .. MagazineBag_Core.GetRoundDisplayName(roundType), 1, 1, 0.8, 1)
    local bottom = layout:render(padSide, tooltip:getHeight() - padEnd, tooltip)
    tooltip:endLayout(layout)
    tooltip:setHeight(bottom + padEnd)
end

local function renderWithRow(item, roundType, render)
    local methods = getmetatable(item).__index
    local originalDoTooltip = methods.DoTooltip
    local originalEmbedded = methods.DoTooltipEmbedded
    local addedToLayout = false

    methods.DoTooltipEmbedded = function(self, tooltip, layout, offsetY)
        local result = originalEmbedded(self, tooltip, layout, offsetY)
        if self == item and layout then
            addRow(layout, roundType)
            addedToLayout = true
        end
        return result
    end

    methods.DoTooltip = function(self, tooltip)
        addedToLayout = false
        originalDoTooltip(self, tooltip)
        if self == item and not addedToLayout then
            appendRow(tooltip, roundType)
        end
    end

    local ok, err = pcall(render)

    methods.DoTooltip = originalDoTooltip
    methods.DoTooltipEmbedded = originalEmbedded

    if not ok then error(err, 0) end
end

local function magazineBagTooltip()
    local original = ISToolTipInv.render

    ISToolTipInv.render = function(self)
        local item = self.item
        local roundType = item and instanceof(item, "InventoryItem") and MagazineBag_Core.GetAssignedAmmo(item)
        if not roundType then return original(self) end

        renderWithRow(item, roundType, function() original(self) end)
    end
end

local function installAfterGameStart()
    Events.OnTick.Remove(installAfterGameStart)
    magazineBagTooltip()
end

Events.OnGameStart.Add(function()
    Events.OnTick.Add(installAfterGameStart)
end)
