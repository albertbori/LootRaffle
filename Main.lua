local _, LootRaffle_Local=...

LootRaffle = {
    MinimumQuality = LootRaffle_ItemQuality.Rare,
    RaffleLengthInSeconds = 60,
    PugRaffleRaffleLengthInSeconds = 20, --this is lower due to people being impatient, and the possibility of subsequent queues after the last boss of LFR is killed
    LoggingEnabled = false,
    AutoDetectLootedItems = true,
    NEW_RAFFLE_MESSAGE = "LR_START",
    ROLL_ON_ITEM_MESSAGE = "LR_ROLL",
    Log = function (...)
        if LootRaffle.LoggingEnabled then
            print("[LootRaffle]", ...)
        end
    end,
    PossibleRaffleItems = {},
    PossibleRaffleItemCount = 0,
    PossibleRafflePromptShown = false,
    MyRaffledItems = {},
    MyRaffledItemsCount = 0,
    CurrentTimeInSeconds = 0,
    IncomingRaffleItemInfoRequests = {},
    IncomingRaffleItemInfoRequestCount = 0,
    PendingTrades = {},
    RollWindows = {},
    RollWindowsCount = 0,
    TradeWindowIsOpen = false,
    PlayerAcceptedTrade = false
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

function LootRaffle_TryDetectNewRaffleOpportunity(itemLink, quality, bag, slot)
    if not bag or not slot then
        LootRaffle.Log("No bag or slot detected for", itemLink)
        return
    end
    -- must be of minimum quality, the owner of the item, in a group of some type, and the item be tradable
    if quality >= LootRaffle.MinimumQuality and IsInGroup() then
        LootRaffle.Log("LootRaffle detected new tradable loot: ", itemLink)
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
    local raffle = {
        itemLink = itemLink,
        timeInSeconds = LootRaffle.CurrentTimeInSeconds,
        Rollers = {},
        RollerCounts = {},
        ResponderCount = 0,
        GroupSize = LootRaffle_GetGroupSize()
     }
    for i,rollType in ipairs(LootRaffle_ROLLTYPES) do
        raffle.RollerCounts[rollType] = 0
        raffle.Rollers[rollType] = {}
    end
    table.insert(LootRaffle.MyRaffledItems, raffle)
    LootRaffle.MyRaffledItemsCount = LootRaffle.MyRaffledItemsCount + 1
    local playerName, playerRealmName = UnitFullName('player')
    C_ChatInfo.SendAddonMessage(LootRaffle.NEW_RAFFLE_MESSAGE, strjoin("^", playerName, playerRealmName or string.gsub(GetRealmName(), "%s+", ""), itemLink), LootRaffle_GetCurrentChannelName())
    SendChatMessage("[LootRaffle] whisper me \"NEED\", \"GREED\" or \"XMOG\" if you want "..itemLink.." within the next "..LootRaffle_GetRaffleLengthInSeconds().." seconds.", LootRaffle_GetCurrentChannelName())
end

function LootRaffle_ReceiveRoll(itemLink, playerName, playerRealmName, rollType, fromWhisper)

    local rollerUnitName = LootRaffle_GetUnitNameFromPlayerName(playerName, playerRealmName)
    if not itemLink then -- if we don't know which item the player was rolling on, pick the first usable item
        for i,raffle in ipairs(LootRaffle.MyRaffledItems) do
            if LootRaffle_UnitCanUseItem(rollerUnitName, raffle.itemLink) then
                itemLink = LootRaffle.MyRaffledItems[i].itemLink
                LootRaffle.Log("Roll received didn't contain an item link. Assigned:", itemLink)
                break
            end
        end
        if not itemLink then
            LootRaffle.Log("No eligible raffles found for whisper roll.")
            return
        end
    end

    -- Make sure roller can use item (in case of whisper or hack)
    if not LootRaffle_UnitCanUseItem(rollerUnitName, itemLink) and rollType ~= "PASS" then
        LootRaffle.Log("Discarding roll from", playerName, playerRealmName, "for item", itemLink, ". They cannot use the item.")
        if fromWhisper then
            SendChatMessage("[LootRaffle] You cannot use "..itemLink..". Your roll has been discarded.", "WHISPER", nil, LootRaffle_GetWhisperName(playerName, playerRealmName))
        end
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
            raffle.ResponderCount = raffle.ResponderCount + 1

            -- send confirmation message to those who rolled via whisper
            if fromWhisper then
                SendChatMessage("[LootRaffle] Your request to roll on "..itemLink.." has been received.", "WHISPER", nil, LootRaffle_GetWhisperName(playerName, playerRealmName))
            end
            break
        end
    end
end

function LootRaffle_CheckRollStatus()
    if LootRaffle.MyRaffledItemsCount == 0 then return end
    -- LootRaffle.Log("Checking roll timeout status...")
    for i=#LootRaffle.MyRaffledItems,1,-1 do
        local raffle = LootRaffle.MyRaffledItems[i]
        local secondsLapsed = LootRaffle.CurrentTimeInSeconds - raffle.timeInSeconds
        if secondsLapsed > LootRaffle_GetRaffleLengthInSeconds() then
            LootRaffle.Log("Raffle time limit reached. Ending raffle...")
            LootRaffle_EndRaffle(raffle)
        end
        if raffle.ResponderCount >= raffle.GroupSize then
            LootRaffle.Log("All responders responded. Ending raffle...")
            LootRaffle_EndRaffle(raffle)
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
            SendChatMessage("[LootRaffle] "..winner.playerName.."-"..winner.realmName.." has won "..raffle.itemLink..".", LootRaffle_GetCurrentChannelName())
            LootRaffle_AwardItem(raffle.itemLink, winner.playerName, winner.realmName)
            return
        end
    end
    SendChatMessage("[LootRaffle] No one wanted "..raffle.itemLink..".", LootRaffle_GetCurrentChannelName())
end

function LootRaffle_AwardItem(itemLink, playerName, playerRealmName)
    LootRaffle.Log("LootRaffle_AwardItem(", itemLink, ", ", playerName, ", ", playerRealmName, ")")
    table.insert(LootRaffle.PendingTrades, { itemLink = itemLink, playerName = playerName, playerRealmName = playerRealmName, tryCount = 0 })
    print("[LootRaffle] Move close to "..playerName.."-"..playerRealmName.." for auto-trading.")
    SendChatMessage("[LootRaffle] Hey "..playerName.."-"..playerRealmName.." you won!! Move close to me so I can give you "..itemLink..".", "WHISPER", nil, LootRaffle_GetWhisperName(playerName, playerRealmName))
end

function LootRaffle_TryTradeWinners()
    if #LootRaffle.PendingTrades == 0 or LootRaffle.TradeWindowIsOpen then return end

    local pendingTrade = LootRaffle.PendingTrades[1]

    pendingTrade.tryCount = pendingTrade.tryCount + 1
    if pendingTrade.tryCount >= 60 then
        table.remove(LootRaffle.PendingTrades, 1)
        print("[LootRaffle] Unable to auto-trade "..pendingTrade.itemLink.." with "..pendingTrade.playerName.."-"..pendingTrade.playerRealmName..". You will have to trade manually.")
        return
    end

    local winnerUnitName = LootRaffle_GetUnitNameFromPlayerName(pendingTrade.playerName, pendingTrade.playerRealmName)
    local canTrade = true
    if not winnerUnitName then
        canTrade = false
        LootRaffle.Log("Trade attempt failed, data not available for", pendingTrade.itemLink)
    elseif UnitIsDeadOrGhost(winnerUnitName) then
        canTrade = false
        LootRaffle.Log("Trade failed, winner is dead")
    elseif UnitAffectingCombat("player") == 1 or UnitAffectingCombat(winnerUnitName) == 1 then
        canTrade = false
        LootRaffle.Log("Trade failed, player or winner is in combat.")
    elseif not CheckInteractDistance(winnerUnitName, 2) then -- 1: Inspect, 2: Trade, 3: Duel, 4: Follow
        canTrade = false
        LootRaffle.Log("Trade failed, winner is out of range.")
        -- if LootRaffe_Following == false then
            if CheckInteractDistance(winnerUnitName, 4) then -- 1: Inspect, 2: Trade, 3: Duel, 4: Follow
                LootRaffle.Log("Auto-following winner...")
                -- LootRaffe_Following = true
                FollowUnit(winnerUnitName) --TODO: Check to see if this is awful.
            end
        -- end
    end

    if not canTrade then return end

    LootRaffle.Log("Attempting to trade with", winnerUnitName)
    InitiateTrade(winnerUnitName)
end

function LootRaffle_SelectItemToTrade(bag, slot)
    LootRaffle.Log("Moving ", bag, " bag item in ", slot, " slot to trade window.")
    PickupContainerItem(bag, slot)
    ClickTradeButton(1)
    -- AcceptTrade() -- Not allowed outside of a secure event
end

-- -------------------------------------------------------------
-- Recipient Methods
-- -------------------------------------------------------------

function LootRaffle_ShowRollWindow(itemLink, playerName, playerRealmName)
    if not LootRaffle_UnitCanUseItem("player", itemLink) then
        C_ChatInfo.SendAddonMessage(LootRaffle.ROLL_ON_ITEM_MESSAGE, strjoin("^", playerName, playerRealmName or string.gsub(GetRealmName(), "%s+", ""), itemLink, "PASS"), LootRaffle_GetCurrentChannelName())
        return
    end
    LootRaffle.Log("Showing roll window...")
    local name, link, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)

    local rollWindow = CreateFrame("Frame", "LootRaffle_RollWindow_" .. (LootRaffle.RollWindowsCount + 1), LootRaffle_Frame, "LootRaffle_RollWindowTemplate")
    rollWindow.data = { itemLink = itemLink, playerName = playerName, playerRealmName = playerRealmName, createdTimeInSeconds = LootRaffle.CurrentTimeInSeconds, elapsedTimeInSeconds = 0 }
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
    LootRaffle.Log("LootRaffle_Roll(", parent.data.itemLink, ", ", parent.data.playerName, ", ", parent.data.playerRealmName, ",", rollType, ")")
    local playerName, playerRealmName = UnitFullName('player')
    C_ChatInfo.SendAddonMessage(LootRaffle.ROLL_ON_ITEM_MESSAGE, strjoin("^", playerName, playerRealmName or string.gsub(GetRealmName(), "%s+", ""), parent.data.itemLink, rollType), LootRaffle_GetCurrentChannelName())
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

-- -------------------------------------------------------------
-- Helper Methods
-- -------------------------------------------------------------

function LootRaffle_GetCurrentChannelName()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    else
        return "PARTY"
    end
end

function LootRaffle_GetUnitNameFromPlayerName(playerName, playerRealmName)
    local sameRealm = select(2, UnitFullName("player")) == playerRealmName -- unit full name sometimes returns nil for other players on the same realm

    if IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        local groupPrefix = "party"
        if IsInRaid() then
            groupPrefix = "raid"
        end
        local raidMemberCount = GetNumGroupMembers()
        for i = 1, raidMemberCount do
            local name, realmName = UnitFullName(groupPrefix..i)
            if playerName == name and (sameRealm or playerRealmName == realmName) then
                LootRaffle.Log("Unit name for ", name, realmName, "is", groupPrefix..i)
                return groupPrefix..i
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

function LootRaffle_GetGroupSize()
    if IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return GetNumGroupMembers()
    else
        local partyRoster = GetHomePartyInfo()
        local partySize = 0
        for i, name in ipairs(partyRoster) do
            partySize = partySize + 1
        end
        return partySize
    end
end

function LootRaffle_GetRaffleLengthInSeconds()
    if  IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return LootRaffle.PugRaffleRaffleLengthInSeconds
    else
        return LootRaffle.RaffleLengthInSeconds
    end
end

function LootRaffle_GetTradableItemBagPosition(itemLink)
    LootRaffle.Log("Searching for", itemLink, "in bags...")
    local variantFragmentPattern = LootRaffle_EscapePatternCharacters(select(1, GetItemInfo(itemLink))).." of "
    for bag = NUM_BAG_SLOTS, 0, -1 do
        local slotCount = GetContainerNumSlots(bag)
        for slot = slotCount, 1, -1 do
            local containerItemLink = GetContainerItemLink(bag, slot)
            if containerItemLink == itemLink and LootRaffle_IsTradable(bag, slot) then
                LootRaffle.Log(itemLink.." found in slot: "..bag..","..slot)
                return bag, slot
            elseif containerItemLink and string.find(containerItemLink, variantFragmentPattern) and LootRaffle_IsTradable(bag, slot) then -- check for variant. "Bracers of Intelletct", etc.
                LootRaffle.Log("Green item variant for "..itemLink.." found in slot: "..bag..","..slot)
                return bag, slot
            end
        end
    end
    LootRaffle.Log(itemLink, "not found in bags.")
end

function LootRaffle_UnitCanUseItem(unitName, itemLink)
    local name, link, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
    local localizedClassName, classCodeName, classIndex = UnitClass(unitName)
    LootRaffle.Log("Checking to see if", unitName, "(", localizedClassName, "|", classCodeName, ") can use item:", link, "| itemClass:", itemClass, "| itemSubClass:", itemSubClass, "| equipSlot:", equipSlot)

    -- if it's armor or weapon, check if class can use it.
    if (itemClass == "Armor" or itemClass == "Weapon") and itemSubClass ~= "Miscellaneous" and equipSlot ~= "INVTYPE_CLOAK" then
        local isProficient = false
        local proficientSubClasses = LootRaffle_ClassProficiencies[classCodeName][itemClass]
        local proficientSubClassCount = 0
        for i,proficientSubClass in ipairs(proficientSubClasses) do
            proficientSubClassCount = proficientSubClassCount + 1
            if proficientSubClass == itemSubClass then
                isProficient = true
                break
            end
        end
        if not isProficient then
            LootRaffle.Log("Player CANNOT use "..itemClass.." of type "..itemSubClass)
            return false
        end
    end

    -- if it's class-specific item, check if this class can use it
    if not LootRaffle_ItemPassesClassRestriction(link, localizedClassName) then
        LootRaffle.Log("Player CANNOT use "..itemClass.." of type "..itemSubClass..". Class restriction doesn't match.")
        return false
    end

    if equipSlot == "INVTYPE_TRINKET" and not LootRaffle_ClassCanUseItemStat(link, classCodeName) then
        LootRaffle.Log("Player CANNOT use "..itemClass.." of type "..itemSubClass..". Wrong stats for class.")
        return false
    end

    if itemSubClass == "Artifact Relic" and not LootRaffle_ClassCanUseRelic(link, classCodeName) then
        LootRaffle.Log("Player CANNOT use "..itemClass.." of type "..itemSubClass..". Wrong reilc type for class.")
        return false
    end

    LootRaffle.Log("Player can use "..itemClass.." of type "..itemSubClass)
    return true
end


function LootRaffle_GetItemIconBorderAtlas(quality)
    return "loottoast-itemborder-blue"
end

function LootRaffle_IsTradable(bag, slot)
    if not LootRaffle_IsSoulbound(bag, slot) then
        LootRaffle.Log("Item in slot: ", bag, ",", slot, " is tradable. (Not Soulbound)")
        return true
    end

    --check if trading this BoP is still allowed
    --splits the template string on the macro text (%s), checks to see if both halfs match
    local starts, ends = string.find(BIND_TRADE_TIME_REMAINING, "%%s")
    local firstHalf = LootRaffle_EscapePatternCharacters(string.sub(BIND_TRADE_TIME_REMAINING, 1, starts-1))
    local secondHalf = LootRaffle_EscapePatternCharacters(string.sub(BIND_TRADE_TIME_REMAINING, ends+1, string.len(BIND_TRADE_TIME_REMAINING)))
    local isTradableBoP = LootRaffle_SearchBagItemTooltip(bag, slot, firstHalf) and LootRaffle_SearchBagItemTooltip(bag, slot, secondHalf)
    if isTradableBoP then
        LootRaffle.Log("Item in slot: ", bag, ",", slot, " is a temporarily tradable soulbound item.")
    else
        LootRaffle.Log("Item in slot: ", bag, ",", slot, " is not tradable (Soulbound).")
    end
    return isTradableBoP
end

function LootRaffle_IsSoulbound(bag, slot)
    return LootRaffle_SearchBagItemTooltip(bag, slot, ITEM_SOULBOUND)
end

function LootRaffle_ItemPassesClassRestriction(itemLink, class)
    local starts, ends = string.find(ITEM_CLASSES_ALLOWED , "%%s")
    local firstHalf = LootRaffle_EscapePatternCharacters(string.sub(ITEM_CLASSES_ALLOWED, 1, starts-1))
    if LootRaffle_SearchItemLinkTooltip(itemLink, firstHalf) and not LootRaffle_SearchItemLinkTooltip(itemLink, firstHalf..class) then
        return false
    end
    return true
end

function LootRaffle_ClassCanUseItemStat(itemLink, classCodeName)
    --if it has strength, agility or int, check for class proficiency match
    if LootRaffle_SearchItemLinkTooltip(itemLink, { SPELL_STAT1_NAME, SPELL_STAT2_NAME, SPELL_STAT4_NAME }) then
        local mainStats = LootRaffle_ClassProficiencies[classCodeName]["MainStats"]
        if LootRaffle_SearchItemLinkTooltip(itemLink, mainStats) then
            return true
        end
        return false
    end
    return true
end

function LootRaffle_ClassCanUseRelic(itemLink, classCodeName)
    local relics = LootRaffle_ClassProficiencies[classCodeName]["Relics"]
    local relicPatterns = {}
    for i,relicType in ipairs(relics) do
        local pattern = string.gsub(RELIC_TOOLTIP_TYPE, "%%s", relicType)
        table.insert(relicPatterns, pattern)
    end
    if LootRaffle_SearchItemLinkTooltip(itemLink, relicPatterns) then
        return true
    end
    return false
end

local parseItemTooltip = CreateFrame("GameTooltip","LootRaffle_ParseItemTooltip",nil,"GameTooltipTemplate")
function LootRaffle_SearchBagItemTooltip(bag, slot, patterns)
    --LootRaffle.Log("Searching for", patterns, "in item tooltip for bag/slot:", bag, "/", slot)
    parseItemTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    parseItemTooltip:SetBagItem(bag, slot)
    return LootRaffle_SearchTooltip(patterns)
end

function LootRaffle_SearchItemLinkTooltip(itemLink, patterns)
    --LootRaffle.Log("Searching for", patterns, "in item tooltip for itemLink:", itemLink)
    parseItemTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    parseItemTooltip:SetHyperlink(itemLink)
    return LootRaffle_SearchTooltip(patterns)
end

function LootRaffle_SearchTooltip(patterns)
    parseItemTooltip:Show()
    for i = 1,parseItemTooltip:NumLines() do
        local tooltipLine = _G["LootRaffle_ParseItemTooltipTextLeft"..i]
        if tooltipLine then
            local text = tooltipLine:GetText()
            if (type(patterns) == "table") then
                for x,pattern in ipairs(patterns) do
                    if text and (text == pattern or string.find(text, pattern)) then
                        return true
                    end
                end
            else
                if text and (text == patterns or string.find(text, patterns)) then
                    return true
                end
            end
        else
            LootRaffle.Log("Failed to read parsing tooltip text line", i)
        end
    end
    parseItemTooltip:Hide()
    return false
end

function LootRaffle_EscapePatternCharacters(text)
    return string.gsub(text, "[%.%%]", "%%%1")
end

function LootRaffle_GetWhisperName(playerName, playerRealmName)
    local whisperName = playerName
    if playerRealmName then
        whisperName = whisperName.."-"..playerRealmName
    end
    return whisperName
end
