local _, LootRaffle_Local=...

function LootRaffle_TryDetectNewRaffleOpportunity(itemLink, quality, bag, slot)
    if not bag or not slot then
        LootRaffle.Log("No bag or slot detected for", itemLink)
        return
    end
    -- must be of minimum quality, the owner of the item, in a group of some type, and the item be tradable
    if quality >= LootRaffle.MinimumQuality and IsInGroup() and not LootRaffle_FindIgnoredItemIndex(itemLink) then
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
    LootRaffle.MyRaffles[tostring(LootRaffle.MyRafflesCount + 1)] = raffle
    LootRaffle.MyRafflesCount = LootRaffle.MyRafflesCount + 1
    LootRaffle_Notification_SendRaffleStart(itemLink, raffleId)
    SendChatMessage("[LootRaffle] whisper me \"NEED\", \"GREED\" or \"XMOG\" if you want "..itemLink.." within the next "..LootRaffle_GetRaffleLengthInSeconds().." seconds.", LootRaffle_GetCurrentChannelName())
end

function LootRaffle_HandleRollNotification(raffleId, rollerName, rollType)
    local rollerUnitName = LootRaffle_GetUnitNameFromPlayerName(rollerName)
    local raffle = LootRaffle.MyRaffles[raffleId]
    if not raffle then
        LootRaffle.Log("Could not find raffle for id:", raffleId)
    end
    LootRaffle_ReceiveRoll(raffle, rollerName, rollerUnitName, rollType)
end

function LootRaffle_HandleRollWhisper(itemLink, rollerName, rollType)
    local rollerUnitName = LootRaffle_GetUnitNameFromPlayerName(rollerName)
    local raffle = nil
    if not itemLink then -- if we don't know which item the player was rolling on, pick the first usable item
        for i,id in ipairs(LootRaffle.MyRaffles) do
            if LootRaffle_UnitCanUseItem(rollerUnitName, LootRaffle.MyRaffles[id].itemLink) then
                raffle = LootRaffle.MyRaffles[id]
                LootRaffle.Log("Roll received didn't contain an item link. Assigned:", raffle.itemLink)
                break
            end
        end
        if not raffle then
            LootRaffle.Log("No eligible raffles found for whisper roll.")
            SendChatMessage("[LootRaffle] You cannot use that item. Your roll has been discarded.", "WHISPER", nil, rollerName)
            return
        end
    else
        for i,id in ipairs(LootRaffle.MyRaffles) do
            if LootRaffle.MyRaffles[id].itemLink == itemLink then
                raffle = LootRaffle.MyRaffles[id]
                LootRaffle.Log("Found roll id:", id, "from item link:", itemLink)
                break
            end
        end
    end
    if raffle and LootRaffle_ReceiveRoll(raffle, rollerName, rollerUnitName, rollType, true) then
        SendChatMessage("[LootRaffle] Your request to roll on "..itemLink.." has been received.", "WHISPER", nil, rollerName)
    end
end

function LootRaffle_ReceiveRoll(raffle, rollerName, rollerUnitName, rollType)
    -- Make sure roller can use item (in case of whisper or hack)
    if not LootRaffle_UnitCanUseItem(rollerUnitName, raffle.itemLink) and rollType ~= LOOTRAFFLE_ROLL_PASS then
        LootRaffle.Log("Discarding roll from", rollerName, "for item", raffle.itemLink, ". They cannot use the item.")
        SendChatMessage("[LootRaffle] You cannot use "..raffle.itemLink..". Your roll has been discarded.", "WHISPER", nil, rollerName)
        return false 
    end
    
    -- check if player has already "rolled"
    if raffle.Rollers[rollType][rollerName] then
        LootRaffle.Log("Ignoring roll from", rollerName, "for item", raffle.itemLink, ". They already rolled.")
        SendChatMessage("[LootRaffle] You have already rolled on "..raffle.itemLink..".", "WHISPER", nil, rollerName)
        return false
    end

    LootRaffle.Log("Registering", rollType, "roll from", rollerName, "for item", raffle.itemLink)
    raffle.Rollers[rollType][rollerName] = true
    raffle.RollerCounts[rollType] = raffle.RollerCounts[rollType] + 1
    raffle.ResponderCount = raffle.ResponderCount + 1
    return true
end

function LootRaffle_CheckRollStatus()
    if LootRaffle.MyRafflesCount == 0 then return end
    -- LootRaffle.Log("Checking roll timeout status...")
    for _,id in LootRaffle.MyRaffles do
        local raffle = LootRaffle.MyRaffles[id]
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
    for i,id in ipairs(LootRaffle.MyRaffles) do
        local raffle = LootRaffle.MyRaffles[id]
        if raffle.itemLink == raffle.itemLink then
            table.remove(LootRaffle.MyRaffles, i)
        end
    end

    LootRaffle.MyRafflesCount = LootRaffle.MyRafflesCount - 1
    for i,rollType in ipairs(LootRaffle_ROLLTYPES) do
        if rollType ~= "PASS" and raffle.RollerCounts[rollType] > 0 then
            local winner = raffle.Rollers[rollType][math.random(raffle.RollerCounts[rollType])]
            SendChatMessage("[LootRaffle] "..winner.rollerName.." has won "..raffle.itemLink..".", LootRaffle_GetCurrentChannelName())
            LootRaffle_AwardItem(raffle.itemLink, winner.rollerName)
            return
        end
    end
    SendChatMessage("[LootRaffle] No one wanted "..raffle.itemLink..".", LootRaffle_GetCurrentChannelName())
end

function LootRaffle_AwardItem(itemLink, rollerName)
    LootRaffle.Log("LootRaffle_AwardItem(", itemLink, ", ", rollerName, ")")
    table.insert(LootRaffle.PendingTrades, { itemLink = itemLink, rollerName = rollerName, tryCount = 0 })
    print("[LootRaffle] Move close to "..rollerName.." for auto-trading.")
    SendChatMessage("[LootRaffle] Hey "..rollerName.." you won!! Move close to me so I can give you "..itemLink..".", "WHISPER", nil, rollerName)
end

function LootRaffle_TryTradeWinners()
    if #LootRaffle.PendingTrades == 0 or LootRaffle.TradeWindowIsOpen then return end

    local pendingTrade = LootRaffle.PendingTrades[1]

    pendingTrade.tryCount = pendingTrade.tryCount + 1
    if pendingTrade.tryCount >= 60 then
        table.remove(LootRaffle.PendingTrades, 1)
        print("[LootRaffle] Unable to auto-trade "..pendingTrade.itemLink.." with "..pendingTrade.rollerName..". You will have to trade manually.")
        return
    end

    local winnerUnitName = LootRaffle_GetUnitNameFromPlayerName(pendingTrade.rollerName)
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