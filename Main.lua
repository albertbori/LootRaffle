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
    MyRaffledItems = {},
    MyRaffledItemsCount = 0,
    ItemsForGrab = {},
    CurrentTimeInSeconds = 0,
    ItemInfoRequests = {},
    PendingTrades = {}
}

-- Add static confirmation dialog
StaticPopupDialogs["LOOTRAFFLE_PROMPT"] = {
    text = "Would you like to start a raffle for %s?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        LootRaffle_StartRaffle(data)
    end,
    timeout = LootRaffle.RaffleLengthInSeconds,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}

StaticPopupDialogs["LOOTRAFFLE_ROLL"] = {
    text = "%s is giving away %s. Would you like to roll on it?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        LootRaffle_Roll(data.itemLink, data.playerName, data.playerRealm)
    end,
    timeout = LootRaffle.RaffleLengthInSeconds,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}


-- -------------------------------------------------------------
-- Owner Methods
-- -------------------------------------------------------------

function LootRaffle_PromptForRaffle(itemLink)
    LootRaffle.Log("LootRaffle_PromptForRaffle(", itemLink, ")")
    local popup = StaticPopup_Show("LOOTRAFFLE_PROMPT", itemLink)
    popup.data = itemLink
end

function LootRaffle_StartRaffle(itemLink)
    LootRaffle.Log("LootRaffle_StartRaffle(", itemLink, ")")
    table.insert(LootRaffle.MyRaffledItems, { itemLink = itemLink, timeInSeconds = LootRaffle.CurrentTimeInSeconds, Rollers = {}, RollerCount = 0 })
    LootRaffle.MyRaffledItemsCount = LootRaffle.MyRaffledItemsCount + 1
    SendAddonMessage(LootRaffle.NEW_RAFFLE_MESSAGE, strjoin("^", UnitName('player'), GetRealmName(), itemLink), LootRaffle_GetCurrentChannelName())
    SendChatMessage("I'm giving away "..itemLink.." using the LootRaffle addon. (Download on Curse)", LootRaffle_GetCurrentChannelName())
end

function LootRaffle_ReceiveRoll(itemLink, playerName, playerRealmName)
    for i, raffle in ipairs(LootRaffle.MyRaffledItems) do
        -- try to find the raffle in question
        if raffle.itemLink == itemLink then
            -- check if player has already "rolled"
            for x, roller in ipairs(raffle.Rollers) do
                if roller.playerName == playerName and roller.realmName == playerRealmName then
                    return
                end
            end

            table.insert(raffle.Rollers, { playerName = playerName, realmName = playerRealmName })
            raffle.RollerCount = raffle.RollerCount + 1
            break
        end
    end
end

function LootRaffle_CheckRollStatus()
    if LootRaffle.MyRaffledItemsCount == 0 then
        return
    end
    LootRaffle.Log("Checking roll timeout status...")
    for i, raffle in ipairs(LootRaffle.MyRaffledItems) do
        local secondsLapsed = LootRaffle.CurrentTimeInSeconds - raffle.timeInSeconds
        if secondsLapsed > LootRaffle.RaffleLengthInSeconds then
            LootRaffle_EndRaffle(raffle)
            break
        end
    end
end

function LootRaffle_EndRaffle(raffle)
    LootRaffle.Log("LootRaffle_EndRaffle(", raffle, ")")
    table.remove(LootRaffle.MyRaffledItems, i)
    LootRaffle.MyRaffledItemsCount = LootRaffle.MyRaffledItemsCount - 1
    if raffle.RollerCount > 0 then
        local winner = raffle.Rollers[math.random(raffle.RollerCount)]
        SendChatMessage(winner.playerName.."-"..winner.realmName.." has won "..raffle.itemLink..".", LootRaffle_GetCurrentChannelName())
        LootRaffle_AwardItem(raffle.itemLink, winner.playerName, winner.realmName)
    else
        SendChatMessage("No one wanted "..raffle.itemLink..".", LootRaffle_GetCurrentChannelName())
    end            
end

function LootRaffle_AwardItem(itemLink, playerName, playerRealmName)
    LootRaffle.Log("LootRaffle_AwardItem(", itemLink, ", ", playerName, ", ", playerRealmName, ")")

    local tradeInProgress = false
    if IsInRaid() then
        local raidMemberCount = GetNumGroupMembers()
        for i in 1,raidMemberCount do
            local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
            if playerName == name and not dead then
                InitiateTrade("raid"..i)
                tradeInProgress = true
                break
            end
        end
    elseif IsInGroup() then
        local partyRoster = GetHomePartyInfo()
        for i, name in ipairs(partyRoster) do
            local name, realmName = UnitName("party"..i)
            if playerName == name and not dead then
                InitiateTrade("party"..i)
                tradeInProgress = true
                break
            end
        end
    else
        print("LootRaffle: Couldn't find player to trade with. The player is not in your group or raid. You must trade manually.")
    end

    if tradeInProgress then
        local bag, slot = LootRaffle_GetBagPosition(itemLink)
        if bag and slot then
            PickupContainerItem(bag, slot)
            AcceptTrade() -- This doesn't seem to work? http://wowprogramming.com/docs/api/AcceptTrade
        end
    end
end


-- -------------------------------------------------------------
-- Recipient Methods
-- -------------------------------------------------------------

function LootRaffle_ShowRollWindow(itemLink, playerName, playerRealmName)
    if not LootRaffle_CanUseItem(itemLink) then
        return
    end
    -- table.insert(LootRaffle.ItemsForGrab, { itemLink = itemLink, timeInSeconds = LootRaffle.CurrentTimeInSeconds, Rollers = {}, RollerCount = 0 })
    local popup = StaticPopup_Show("LOOTRAFFLE_ROLL", playerName.."-"..playerRealmName, itemLink)
    popup.data = { itemLink = itemLink, playerName = playerName, playerRealmName = playerRealmName }
end

function LootRaffle_Roll(itemLink, playerName, playerRealmName)
    LootRaffle.Log("LootRaffle_Roll(", itemLink, ", ", playerName, ", ", playerRealmName, ")")
    SendAddonMessage(LootRaffle.ROLL_ON_ITEM_MESSAGE, strjoin("^", UnitName('player'), GetRealmName(), itemLink), LootRaffle_GetCurrentChannelName())
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
        return "SAY"
    end
end

function LootRaffle_GetBagPosition(itemLink)
    for bag = 0, NUM_BAG_SLOTS do
        local slotCount = GetContainerNumSlots(NUM_BAG_SLOTS-bag)
        for slot = 1, slotCount do
            if(GetContainerItemLink(bag, slotCount-slot) == itemLink) then
                return bag, slot
            end
        end
    end
end

function LootRaffle_CanUseItem(itemLink)
    local name, link, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
    
    if itemClass == GetText("Miscellaneous") then -- cloak, trinket, rings are all class independent (or not easily distinguishable)
        LootRaffle.Log("Player can use "..itemClass.." of type "..itemSubClass)
        return true
    end

    local localizedClassName, classCodeName, classIndex = UnitClass('player')

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