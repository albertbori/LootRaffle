local _, LootRaffle_Local=...

LootRaffle = {
    MinimumQuality = LootRaffle_ItemQuality.Rare,
    RaffleLengthInSeconds = 30,
    NEW_RAFFLE_MESSAGE = "LR_START",
    ROLL_ON_ITEM_MESSAGE = "LR_ROLL",
    LoggingEnabled = false,
    Log = function (...)
        if LootRaffle.LoggingEnabled then
            print("LootRaffle:", ...)
        end
    end,
    PossibleRaffleItems = {},
    PossibleRaffleItemCount = 0,
    PossibleRafflePromptShown = false,
    PossibleRaffleItemInfoRequests = {},
    PossibleRaffleItemInfoRequestCount = 0,
    MyRaffledItems = {},
    MyRaffledItemsCount = 0,
    CurrentTimeInSeconds = 0,
    IncomingRaffleItemInfoRequests = {},
    IncomingRaffleItemInfoRequestCount = 0,
    PendingTrades = {}, --unused (planned)
    RollWindows = {},
    RollWindowsCount = 0
}

-- Add static confirmation dialog
StaticPopupDialogs["LOOTRAFFLE_PROMPT"] = {
    text = "Would you like to start a raffle for %s?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        LootRaffle.Log("LOOTRAFFLE_PROMPT accepted.")
        LootRaffle_StartRaffle(data.link)
        LootRaffle.PossibleRafflePromptShown = false
    end,
    OnCancel = function()
        LootRaffle.Log("LOOTRAFFLE_PROMPT canceled.")
        LootRaffle.PossibleRafflePromptShown = false
    end,
    timeout = LootRaffle.RaffleLengthInSeconds,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
    hasItemFrame = true    
}


-- -------------------------------------------------------------
-- Owner Methods
-- -------------------------------------------------------------

function LootRaffle_TryDetectNewRaffleOpportunity(itemLink, quality)
    local bag, slot = LootRaffle_GetBagPosition(itemLink)
    -- must be of minimum quality, the owner of the item, in a group of some type, and the item be tradable
    if quality >= LootRaffle.MinimumQuality and IsInGroup() and LootRaffle_IsTradeable(bag, slot) then    
        LootRaffle.Log("LootRaffle detected new loot: ", itemLink)
        LootRaffle_TryPromptForRaffle(itemLink)
    end
end

function LootRaffle_TryPromptForRaffle(itemLink)
    if itemLink then
        if LootRaffle.PossibleRafflePromptShown then 
            LootRaffle.Log("Prompt already shown. Queueing "..itemLink.."...")
            table.insert(LootRaffle.PossibleRaffleItems, itemLink)
            LootRaffle.PossibleRaffleItemCount = LootRaffle.PossibleRaffleItemCount + 1
        else
            LootRaffle_PromptForRaffle(itemLink)
        end
        return 
    end
    if not LootRaffle.PossibleRafflePromptShown and LootRaffle.PossibleRaffleItemCount > 0 then
        local itemLink = LootRaffle.PossibleRaffleItems[1]
        LootRaffle.Log("Processing next raffle prompt for: "..itemLink.."...")
        table.remove(LootRaffle.PossibleRaffleItems, 1)
        LootRaffle.PossibleRaffleItemCount = LootRaffle.PossibleRaffleItemCount - 1
        LootRaffle_PromptForRaffle(itemLink)
    end
end

function LootRaffle_PromptForRaffle(itemLink)
    LootRaffle.PossibleRafflePromptShown = true
    LootRaffle.Log("LootRaffle_PromptForRaffle(", itemLink, ")")
    local data = { ["useLinkForItemInfo"] = true, ["link"] = itemLink }
    local popup = StaticPopup_Show("LOOTRAFFLE_PROMPT", itemLink, nil, data)
end

function LootRaffle_StartRaffle(itemLink)
    LootRaffle.Log("LootRaffle_StartRaffle(", itemLink, ")")
    local raffle = { itemLink = itemLink, timeInSeconds = LootRaffle.CurrentTimeInSeconds, Rollers = {}, RollerCounts = {} }
    for i,rollType in ipairs(LootRaffle_ROLLTYPES) do
        raffle.RollerCounts[rollType] = 0
        raffle.Rollers[rollType] = {}
    end
    table.insert(LootRaffle.MyRaffledItems, raffle)
    LootRaffle.MyRaffledItemsCount = LootRaffle.MyRaffledItemsCount + 1
    local playerName, playerRealmName = UnitFullName('player')
    SendAddonMessage(LootRaffle.NEW_RAFFLE_MESSAGE, strjoin("^", playerName, playerRealmName, itemLink), LootRaffle_GetCurrentChannelName())
    SendChatMessage("I'm giving away "..itemLink.." using the LootRaffle addon. (Download it on Curse. If you don't have the addon, whisper me with the item link if you're interested.)", LootRaffle_GetCurrentChannelName())
end

function LootRaffle_ReceiveRoll(itemLink, playerName, playerRealmName, rollType)
    if not itemLink and LootRaffle.MyRaffledItemsCount > 0 then -- if we don't know which item the player was rolling on, pick the first item
        itemLink = LootRaffle.MyRaffledItems[1].itemLink
        LootRaffle.Log("Roll recieved didn't contain an item link. Assigned: ", itemLink)
    end

    -- Make sure roller can use item (in case of whisper or hack)
    local rollerUnitName = LootRaffle_GetUnitNameFromPlayerName(playerName, playerRealmName)
    if not LootRaffle_UnitCanUseItem(rollerUnitName, itemLink) then
        LootRaffle.Log("Discarding roll from", playerName, playerRealmName, "for item", itemLink, ". They cannot use the item.")
        return
    end

    for i, raffle in ipairs(LootRaffle.MyRaffledItems) do
        -- try to find the raffle in question
        if raffle.itemLink == itemLink then
            -- check if player has already "rolled"
            for x, roller in ipairs(raffle.Rollers[rollType]) do
                if roller.playerName == playerName and roller.realmName == playerRealmName then
                    return
                end
            end

            LootRaffle.Log("Registering", rollType, "roll from", playerName, playerRealmName, "for item", itemLink)
            table.insert(raffle.Rollers[rollType], { playerName = playerName, realmName = playerRealmName })
            raffle.RollerCounts[rollType] = raffle.RollerCounts[rollType] + 1
            break
        end
    end
end

function LootRaffle_CheckRollStatus()
    if LootRaffle.MyRaffledItemsCount == 0 then
        return
    end
    -- LootRaffle.Log("Checking roll timeout status...")
    for i, raffle in ipairs(LootRaffle.MyRaffledItems) do
        local secondsLapsed = LootRaffle.CurrentTimeInSeconds - raffle.timeInSeconds
        if secondsLapsed > LootRaffle.RaffleLengthInSeconds then
            LootRaffle_EndRaffle(raffle)
            break
        end
    end
end

function LootRaffle_EndRaffle(raffle)
    LootRaffle.Log("LootRaffle_EndRaffle(", raffle.itemLink, ")")
    for i,raffle in ipairs(LootRaffle.MyRaffledItems) do
        if raffle.itemLink == raffle.itemLink then
            table.remove(LootRaffle.MyRaffledItems, i)
        end
    end

    LootRaffle.MyRaffledItemsCount = LootRaffle.MyRaffledItemsCount - 1
    for i,rollType in ipairs(LootRaffle_ROLLTYPES) do
        if rollType ~= "PASS" and raffle.RollerCounts[rollType] > 0 then
            local winner = raffle.Rollers[rollType][math.random(raffle.RollerCounts[rollType])]
            SendChatMessage(winner.playerName.."-"..winner.realmName.." has won "..raffle.itemLink..".", LootRaffle_GetCurrentChannelName())
            LootRaffle_AwardItem(raffle.itemLink, winner.playerName, winner.realmName)
            return
        end
    end
    SendChatMessage("No one wanted "..raffle.itemLink..".", LootRaffle_GetCurrentChannelName())        
end

function LootRaffle_AwardItem(itemLink, playerName, playerRealmName)
    LootRaffle.Log("LootRaffle_AwardItem(", itemLink, ", ", playerName, ", ", playerRealmName, ")")

    local winnerUnitName = LootRaffle_GetUnitNameFromPlayerName(playerName, playerRealmName)

    if not winnerUnitName then
        print("LootRaffle: Couldn't find player to trade with. The player is not in your group or raid. You must trade manually.")
        return
    end

    if UnitIsDeadOrGhost(winnerUnitName) then
        print("LootRaffle: Couldn't find player to trade with. The player is dead. You must trade manually.")
        return
    end

    InitiateTrade(winnerUnitName)

    local bag, slot = LootRaffle_GetBagPosition(itemLink)
    if bag and slot then
        PickupContainerItem(bag, slot)
        AcceptTrade() -- This doesn't seem to work? http://wowprogramming.com/docs/api/AcceptTrade
    end
end


-- -------------------------------------------------------------
-- Recipient Methods
-- -------------------------------------------------------------

function LootRaffle_ShowRollWindow(itemLink, playerName, playerRealmName)
    if not LootRaffle_UnitCanUseItem("player", itemLink) then
        return
    end
    LootRaffle.Log("Showing roll window...")
    local name, link, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)

    local rollWindow = CreateFrame("Frame", "LootRaffle_RollWindow_" .. (LootRaffle.RollWindowsCount + 1), LootRaffle_Frame, "LootRaffle_RollWindowTemplate")
    rollWindow.data = { itemLink = itemLink, playerName = playerName, playerRealmName = playerRealmName, createdTimeInSeconds = LootRaffle.CurrentTimeInSeconds, elapsedTimeInSeconds = 0 }
    rollWindow.Timer:SetMinMaxValues(0, LootRaffle.RaffleLengthInSeconds)
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
    LootRaffle.Log("LootRaffle_Roll(", parent.data.itemLink, ", ", parent.data.playerName, ", ", parent.data.playerRealmName, ",", rollType, ")")
    local playerName, playerRealmName = UnitFullName('player')
    SendAddonMessage(LootRaffle.ROLL_ON_ITEM_MESSAGE, strjoin("^", playerName, playerRealmName, parent.data.itemLink, rollType), LootRaffle_GetCurrentChannelName())
end

function LootRaffle_OnRollWindowUpdate(self, elapsed)
    local parent = self:GetParent()
    parent.data.elapsedTimeInSeconds = parent.data.elapsedTimeInSeconds + elapsed

    -- check for expiration
    if parent.data.elapsedTimeInSeconds >= LootRaffle.RaffleLengthInSeconds then
        LootRaffle.RollWindowsCount = LootRaffle.RollWindowsCount - 1
        parent:Hide()
        return
    end

	local left = math.max(LootRaffle.RaffleLengthInSeconds - parent.data.elapsedTimeInSeconds, 0)
	local min, max = self:GetMinMaxValues();
	if ( (left < min) or (left > max) ) then
		left = min;
	end
	self:SetValue(left);
end

-- -------------------------------------------------------------
-- Helper Methods
-- -------------------------------------------------------------

function LootRaffle_GetCurrentChannelName()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    else
        return "PARTY"
    end
end

function LootRaffle_GetUnitNameFromPlayerName(playerName, playerRealmName)
    local sameRealm = select(2, UnitFullName("player")) == playerRealmName -- unit full name sometimes returns nil for other players on the same realm

    if IsInRaid() then
        local raidMemberCount = GetNumGroupMembers()
        for i = 1, raidMemberCount do
            local name, realmName = UnitFullName("raid"..i)
            if playerName == name and (sameRealm or playerRealmName == realmName) then
                LootRaffle.Log("Unit name for ", name, realmName, "is", "raid"..i)
                return "raid"..i
            end
        end
    elseif IsInGroup() then
        local partyRoster = GetHomePartyInfo()
        for i, name in ipairs(partyRoster) do
            local name, realmName = UnitFullName("party"..i)
            if playerName == name and (sameRealm or playerRealmName == realmName) then
                LootRaffle.Log("Unit name for ", name, realmName, "is", "party"..i)
                return "party"..i
            end
        end
    end
    return nil
end

function LootRaffle_GetBagPosition(itemLink)
    for bag = NUM_BAG_SLOTS, 0, -1 do
        local slotCount = GetContainerNumSlots(bag)
        for slot = slotCount, 1, -1 do
            if(GetContainerItemLink(bag, slot) == itemLink) then
                LootRaffle.Log(itemLink.." found in slot: "..bag..","..slot)
                return bag, slot
            end
        end
    end
end

function LootRaffle_UnitCanUseItem(unitName, itemLink)
    local name, link, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
    if not equipSlot or equipSlot == "" then
        LootRaffle.Log("Player can use unequippable item: "..itemClass.." of type "..itemSubClass)
        return true
    end

    if itemSubClass == "Miscellaneous" then -- trinket, rings are all class independent (or not easily distinguishable)
        LootRaffle.Log("Player can use Miscellaneous item: "..itemClass.." of type "..itemSubClass)
        return true
    end

    if equipSlot == "INVTYPE_CLOAK" then -- cloaks are class independant
        LootRaffle.Log("Player can use cloak: "..itemClass.." of type "..itemSubClass)
        return true
    end

    local localizedClassName, classCodeName, classIndex = UnitClass(unitName)

    if not LootRaffle_ItemCanBeUsedByClass(link, localizedClassName) then
        LootRaffle.Log("Player CANNOT use "..itemClass.." of type "..itemSubClass..". Class restriction doesn't match.")
        return false
    end

    local proficientSubClasses = LootRaffle_ClassProficiencies[classCodeName][itemClass]
    local proficientSubClassCount = 0
    for i,proficientSubClass in ipairs(proficientSubClasses) do
        proficientSubClassCount = proficientSubClassCount + 1
        if proficientSubClass == itemSubClass then
            LootRaffle.Log("Player can use "..itemClass.." of type "..itemSubClass)
            return true
        end
    end

    LootRaffle.Log("Player CANNOT use "..itemClass.." of type "..itemSubClass)
    return false
end


function LootRaffle_GetItemIconBorderAtlas(quality)
    return "loottoast-itemborder-blue"
end

function LootRaffle_IsTradeable(bag, slot)
    if not LootRaffle_IsSoulbound(bag, slot) then
        LootRaffle.Log("Item in slot: "..bag..","..slot.." is tradable.")
        return true
    end

    --check if trading this BoP is still allowed
    --splits the template string on the macro text (%s), checks to see if both halfs match
    local starts, ends = string.find(BIND_TRADE_TIME_REMAINING, "%%s")
    local firstHalf = LootRaffle_EscapePatternCharacters(string.sub(BIND_TRADE_TIME_REMAINING, 1, starts-1))
    local secondHalf = LootRaffle_EscapePatternCharacters(string.sub(BIND_TRADE_TIME_REMAINING, ends+1, string.len(BIND_TRADE_TIME_REMAINING)))
    local isTradeableBoP = LootRaffle_SearchOwnedItemTooltip(bag, slot, firstHalf) and LootRaffle_SearchOwnedItemTooltip(bag, slot, secondHalf)
    if isTradeableBoP then
        LootRaffle.Log("Item in slot: "..bag..","..slot.." is tradable.")
    else
        LootRaffle.Log("Item in slot: "..bag..","..slot.." is not tradable.")
    end
    return isTradeableBoP
end

function LootRaffle_IsSoulbound(bag, slot)
    return LootRaffle_SearchOwnedItemTooltip(bag, slot, ITEM_SOULBOUND)
end

function LootRaffle_ItemCanBeUsedByClass(itemLink, class)
    local starts, ends = string.find(BIND_TRADE_TIME_REMAINING, "%%s")
    local firstHalf = LootRaffle_EscapePatternCharacters(string.sub(BIND_TRADE_TIME_REMAINING, 1, starts-1))
    if LootRaffle_SearchItemTooltip(itemLink, firstHalf) and not LootRaffle_SearchItemTooltip(itemLink, firstHalf..class) then
        return false
    end
    return true
end

LootRaffle_ParseTooltip = CreateFrame("GameTooltip","LootRaffle_ParseTooltip",nil,"GameTooltipTemplate")
function LootRaffle_SearchOwnedItemTooltip(bag, slot, pattern)
    LootRaffle_ParseTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    LootRaffle_ParseTooltip:SetBagItem(bag, slot)
    LootRaffle_ParseTooltip:Show()
    for i = 1,LootRaffle_ParseTooltip:NumLines() do
        local text = _G["GameTooltipTextLeft"..i]:GetText()
        if text and (text == pattern or string.find(text, pattern)) then
            return true
        end
    end
    LootRaffle_ParseTooltip:Hide()
    return false
end

function LootRaffle_SearchItemTooltip(itemLink, pattern)
    LootRaffle_ParseTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    LootRaffle_ParseTooltip:SetHyperlink(itemLink)
    LootRaffle_ParseTooltip:Show()
    for i = 1,LootRaffle_ParseTooltip:NumLines() do
        local text = _G["GameTooltipTextLeft"..i]:GetText()
        if text and (text == pattern or string.find(text, pattern)) then
            return true
        end
    end
    LootRaffle_ParseTooltip:Hide()
    return false
end

function LootRaffle_EscapePatternCharacters(text)
    return string.gsub(text, "[%.%%]", "%%%1")
end