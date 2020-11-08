local _, LootRaffle_Local=...

function LootRaffle_HandleNewRaffleNotification(itemLink, rafflerName, raffleId)
    if not LootRaffle_UnitCanUseItem("player", itemLink) then
        LootRaffle_Notification.SendRoll(itemLink, rafflerName, raffleId, LOOTRAFFLE_ROLL_PASS)
        return
    end
    LootRaffle_ShowRollWindow(itemLink, rafflerName, raffleId)
end

function LootRaffle_ShowRollWindow(itemLink, rafflerName, raffleId)
    LootRaffle.Log("Showing roll window for ", itemLink, rafflerName, raffleId, "...")
    local name, link, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)

    local rollWindow = CreateFrame("Frame", "LootRaffle_RollWindow_" .. (LootRaffle.RollWindowsCount + 1), LootRaffle_Frame, "LootRaffle_RollWindowTemplate")
    rollWindow.data = { itemLink = itemLink, rafflerName = rafflerName, raffleId = raffleId, createdTimeInSeconds = LootRaffle.CurrentTimeInSeconds, elapsedTimeInSeconds = 0 }
    rollWindow.Timer:SetMinMaxValues(0, LootRaffle_GetRaffleLengthInSeconds())
    rollWindow.IconFrame.Icon:SetTexture(texture)
    rollWindow.Name:SetText(name)

	local color = ITEM_QUALITY_COLORS[quality];
	rollWindow.Name:SetVertexColor(color.r, color.g, color.b);
	rollWindow.Border:SetVertexColor(color.r, color.g, color.b);
	rollWindow.IconFrame.Border:SetAtlas(LOOT_BORDER_BY_QUALITY[quality] or LOOT_BORDER_BY_QUALITY[LE_ITEM_QUALITY_UNCOMMON]);

    local verticalOffset = (77 * LootRaffle.RollWindowsCount)
    rollWindow:SetPoint("CENTER",0,verticalOffset)
    rollWindow:Show()
    LootRaffle.RollWindowsCount = LootRaffle.RollWindowsCount + 1
end

function LootRaffle_Roll(self, rollType)
    local parent = self:GetParent()
    parent:Hide()
    LootRaffle.RollWindowsCount = LootRaffle.RollWindowsCount - 1
    LootRaffle.Log("LootRaffle_Roll(", parent.data.rafflerName, ", raffleId: ", parent.data.raffleId, ",", rollType, ")")
    LootRaffle_Notification_SendRoll(parent.data.itemLink, parent.data.rafflerName, parent.data.raffleId, rollType)
end

function LootRaffle_OnRollWindowUpdate(self, elapsed)
    local parent = self:GetParent()
    parent.data.elapsedTimeInSeconds = parent.data.elapsedTimeInSeconds + elapsed

    -- check for expiration
    if parent.data.elapsedTimeInSeconds >= LootRaffle_GetRaffleLengthInSeconds() then
        LootRaffle.RollWindowsCount = LootRaffle.RollWindowsCount - 1
        parent:Hide()
        return
    end

	local left = math.max(LootRaffle_GetRaffleLengthInSeconds() - parent.data.elapsedTimeInSeconds, 0)
	local min, max = self:GetMinMaxValues();
	if ( (left < min) or (left > max) ) then
		left = min;
	end
	self:SetValue(left);
end