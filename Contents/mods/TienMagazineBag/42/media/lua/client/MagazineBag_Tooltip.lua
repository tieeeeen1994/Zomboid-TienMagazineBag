require "ISUI/ISToolTipInv"
require 'MagazineBag_Core'

local PAD = 5

local function renderAssignedAmmo(tooltip, roundType, top, measureOnly)
    tooltip:setMeasureOnly(measureOnly)
    local layout = tooltip:beginLayout()
    local row = layout:addItem()
    row:setLabel("Assigned Ammo:", 1, 1, 0.8, 1)
    row:setValue(MagazineBag_Core.GetRoundDisplayName(roundType), 1, 1, 1, 1)
    local bottom = layout:render(PAD, top - PAD, tooltip) + PAD
    tooltip:endLayout(layout)
    tooltip:setMeasureOnly(false)
    return bottom
end

local function magazineBagTooltip()
    local original = ISToolTipInv.render

    ISToolTipInv.render = function(self)
        original(self)

        if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then return end

        local roundType = self.item and MagazineBag_Core.GetAssignedAmmo(self.item)
        if not roundType then return end

        local tooltip = self.tooltip
        local top = tooltip:getHeight()
        local oldWidth = tooltip:getWidth()
        local bottom = renderAssignedAmmo(tooltip, roundType, top, true)
        local width = math.max(oldWidth, tooltip:getWidth())

        local bg = self.backgroundColor
        local border = self.borderColor
        self:setWidth(width)
        self:setHeight(bottom)
        self:drawRect(0, top, width, bottom - top, bg.a, bg.r, bg.g, bg.b)
        if width > oldWidth then
            self:drawRect(oldWidth, 0, width - oldWidth, top, bg.a, bg.r, bg.g, bg.b)
        end
        self:drawRectBorder(0, 0, width, bottom, border.a, border.r, border.g, border.b)

        renderAssignedAmmo(tooltip, roundType, top, false)
        tooltip:setWidth(width)
        tooltip:setHeight(bottom)
    end
end

Events.OnGameStart.Add(magazineBagTooltip)
