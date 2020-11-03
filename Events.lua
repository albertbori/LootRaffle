local _, LootRaffle_Local=...

-- Slash commands
SLASH_LootRaffle1 = '/raffle';
function SlashCmdList.LootRaffle(msg, editbox)
    if msg == "show" then
        -- LootRaffle_Frame:Show();
    elseif msg == "hide" then
        -- LootRaffle_Frame:Hide();
    elseif msg == "reset" then
        -- LootRaffle_ResetSizeAndPosition();
    elseif msg == "logging on" then
        LootRaffle.LoggingEnabled = true
        print("[LootRaffle] Logging enabled")
    elseif msg == "logging off" then
        LootRaffle.LoggingEnabled = false
        print("[LootRaffle] Logging disabled.")
    elseif msg == "auto-detect on" then
        LootRaffle.AutoDetectLootedItems = true
        print("[LootRaffle] Automatic raffle prompt enabled.")
    elseif msg == "auto-detect off" then
        LootRaffle.AutoDetectLootedItems = false
        print("[LootRaffle] Automatic raffle prompt disabled.")
    elseif string.find(msg, "unignore ") then
        local itemLink = select(2, GetItemInfo(msg))
        print("[LootRaffle] Unignoring "..itemLink.."...")
        if itemLink then
            LootRaffle_UnignoreItem(itemLink)
        end
    elseif string.find(msg, "ignore ") then
        local itemLink = select(2, GetItemInfo(msg))
        print("[LootRaffle] Ignoring "..itemLink.."...")
        if itemLink then
            LootRaffle_IgnoreItem(itemLink)
        end
    elseif string.find(msg, "clearignore") then
        print("[LootRaffle] Clearing ignore list...")
        LootRaffle_ClearIgnored()
    elseif string.find(msg, "showignore") then
        print("[LootRaffle] Showing ignore list...")
        LootRaffle_ShowIgnored()
    elseif string.find(msg, "test") then
        local itemLink = select(2, GetItemInfo(msg)) or GetContainerItemLink(0, 1)
        print("[LootRaffle] Testing item: "..itemLink)
        if itemLink then
            local bag, slot = LootRaffle_GetTradableItemBagPosition(itemLink)
            local playerName, playerRealmName = UnitFullName('player')
            LootRaffle_ShowRollWindow(itemLink, playerName, playerRealmName)
        end
    elseif string.find(msg, "tradable") then
        local itemLink = select(2, GetItemInfo(msg)) or GetContainerItemLink(0, 1)
        print("[LootRaffle] Testing if item: "..itemLink.." is tradable.")
        if itemLink then
            local bag, slot = LootRaffle_GetTradableItemBagPosition(itemLink)
            if bag and slot then
                print("[LootRaffle] "..itemLink.." is tradable.")
            else
                print("[LootRaffle] "..itemLink.." is NOT tradable.")
            end
        end
    elseif string.find(msg, "usable") then
        local itemLink = select(2, GetItemInfo(msg)) or GetContainerItemLink(0, 1)
        local unitName = string.match(msg, "usable (%w+) ")
        if not unitName then unitName = "player" end
        print("[LootRaffle] Testing if item: "..itemLink.." is usable by "..unitName)
        if itemLink then
            if LootRaffle_UnitCanUseItem(unitName, itemLink) then
                print("[LootRaffle] "..itemLink.." is usable by "..unitName..".")
            else
                print("[LootRaffle] "..itemLink.." is NOT usable "..unitName..".")
            end
        end
    elseif string.find(msg, "prompt") then
        local itemLink = select(2, GetItemInfo(msg)) or GetContainerItemLink(0, 1)
        print("[LootRaffle] Testing prompt for item: "..itemLink)
        if itemLink then
            LootRaffle_PromptForRaffle(itemLink)
        end
    else
        -- try for item
        local name, itemLink, quality, itemLevel, requiredLevel, class, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(msg)
        if not name then
            print("LootRaffle commands:"); 
            print(" - '[Item Link]': Starts a raffle");
            print(" - 'logging (on|off)': Toggles logging");
            print(" - 'auto-detect (on|off)': Toggles Automatic raffle prompt when you loot a tradable item.");
            print(" - 'ignore [Item Link]': Adds [Item Link] to your ignore list. Ignored items won't prompt you to start a raffle.");
            print(" - 'unignore [Item Link]': Removes [Item Link] from your ignore list.");
            print(" - 'showignore': Prints out your ignore list.");
            print(" - 'clearignore': Clears the ignore list.");
            return
        end

        local bag, slot = LootRaffle_GetTradableItemBagPosition(itemLink)
        if not IsInGroup() then
            print("[LootRaffle] can only be used in a party or raid group.")            
        elseif not bag or not slot then
            print("[LootRaffle] Item is not tradable.")
        else
            LootRaffle_StartRaffle(itemLink)
        end
    end
end

-- Event handlers

local function OnPlayerLoad(...)
    LootRaffle.Log("Player loaded.")
end

local function OnLoad(...)
    local addon = ...
    if addon ~= "LootRaffle" then return end

    LootRaffle.Log("Addon loaded.")
    LootRaffle.LoggingEnabled = LootRaffle_DB.LoggingEnabled or LootRaffle.LoggingEnabled
    LootRaffle.AutoDetectLootedItems = LootRaffle_DB.AutoDetectLootedItems or LootRaffle.AutoDetectLootedItems
    LootRaffle.IgnoredItems = LootRaffle_DB.IgnoredItems or LootRaffle.IgnoredItems
end

local function OnUnload(...)
    if not LootRaffle_DB then
        LootRaffle_DB = {}
    end
    LootRaffle_DB.LoggingEnabled = LootRaffle.LoggingEnabled
    LootRaffle_DB.AutoDetectLootedItems = LootRaffle.AutoDetectLootedItems
    LootRaffle_DB.IgnoredItems = LootRaffle.IgnoredItems
end

local LootedItems = {}
local LootedItemsCount = 0
local function OnItemLooted(message, sender, language, channelString, target, flags, unknown, channelNumber, channelName, unknown, counter)
    local formattedPlayerName = select(1,UnitName("player")) .. "-" .. GetRealmName()
    LootRaffle.Log("Looted item detected for target: ", target, " | in a group: ", IsInGroup(), " | detect enabled: ", LootRaffle.AutoDetectLootedItems, " | current player: ", formattedPlayerName)    
    if target ~= formattedPlayerName or not IsInGroup() or LootRaffle.AutoDetectLootedItems == false then return end
    local instanceType = select(2, IsInInstance())
    if instanceType ~= "party" and instanceType ~= "raid" then return end

    LootRaffle.Log("Queuing looted item:", message)
    table.insert(LootedItems, { message = message, tries = 0 })
    LootedItemsCount = LootedItemsCount + 1
end

local isLootWindowOpen = false
local function OnLootWindowOpen()
    isLootWindowOpen = true
    LootRaffle.Log("Loot window opened.")
end

local function OnLootWindowClose()
    if isLootWindowOpen == true then
        isLootWindowOpen = false
        LootRaffle.Log("Loot window closed.")
    end
end

local function ProcessLootedItems()
    -- attempt to find the item info and slot info of each looted item
    if not isLootWindowOpen and LootedItemsCount > 0 then
        LootRaffle.Log("Processing", LootedItemsCount, "looted items...")
        for i = LootedItemsCount, 1, -1 do
            local itemData = LootedItems[i]
            -- print("message:", itemData.message, "| tries:", itemData.tries)
            local name, link, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemData.message)
            if itemData.tries >= 5 then --max 5 retries to find the item data
                LootRaffle.Log("Max loot processing retries for item:", link)
                table.remove(LootedItems, i)
                LootedItemsCount = LootedItemsCount - 1
            else
                if name then
                    local bag, slot = LootRaffle_GetTradableItemBagPosition(link)
                    if bag and slot then
                        -- LootRaffle.Log("Looted item data requests fnished for", link)
                        LootRaffle_TryDetectNewRaffleOpportunity(link, quality, bag, slot)
                        table.remove(LootedItems, i)
                        LootedItemsCount = LootedItemsCount - 1
                    else
                        itemData.tries = itemData.tries + 1
                        LootRaffle.Log("Bag and slot not yet available for:", link)
                    end
                else
                    itemData.tries = itemData.tries + 1
                    LootRaffle.Log("Item info not yet available for: ", itemData.message)
                end
            end
        end
    end
end

local function OnMessageRecieved(prefix, message)
    if prefix ~= LootRaffle.NEW_RAFFLE_MESSAGE and prefix ~= LootRaffle.ROLL_ON_ITEM_MESSAGE then return end
    
    LootRaffle.Log("Addon message received: ", prefix, " | ", message)
    local playerName, playerRealmName, itemLink, rollType = string.split("^", message)
    if prefix == LootRaffle.NEW_RAFFLE_MESSAGE and playerName ~= UnitName('player') then
        LootRaffle.Log("New raffle message recieved from: ", playerName, "-", playerRealmName, " for: ", itemLink)
        local name = GetItemInfo(itemLink)
        if name then
            LootRaffle_ShowRollWindow(itemLink, playerName, playerRealmName)
        else
            LootRaffle.Log("No item data found for "..itemLink..". Waiting for async result...")
            -- no data, queue for async item info result
            table.insert(LootRaffle.IncomingRaffleItemInfoRequests, { itemLink = itemLink, playerName = playerName, playerRealmName = playerRealmName })
            LootRaffle.IncomingRaffleItemInfoRequestCount = LootRaffle.IncomingRaffleItemInfoRequestCount + 1
        end
    elseif prefix == LootRaffle.ROLL_ON_ITEM_MESSAGE and playerName ~= UnitName('player') then
        LootRaffle.Log("Roll message recieved from: ", playerName, "-", playerRealmName, " for: ", itemLink)
        LootRaffle_ReceiveRoll(itemLink, playerName, playerRealmName, rollType)
    end
end

local function OnWhisperReceived(msg, author, language, status, msgid, unknown, lineId, senderGuid)
    if LootRaffle.MyRaffledItemsCount == 0 then return end

    local searchableMessage = string.lower(msg)
    local isNeedRoll = string.find(searchableMessage, "need") ~= nil
    local isGreedRoll = string.find(searchableMessage, "greed") ~= nil
    local isXmogRoll = string.find(searchableMessage, "xmog") ~= nil or string.find(searchableMessage, "disenchant") ~= nil

    local rollType = nil
    if isNeedRoll then rollType = "NEED"
    elseif isGreedRoll then rollType = "GREED"
    elseif isXmogRoll then rollType = "DE" end

    if not rollType then return end

    local playerName, playerRealmName = string.split("-", author, 2)
    -- try for item
    local name, itemLink, quality, itemLevel, requiredLevel, class, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(msg)
    LootRaffle.Log("Discovered ", rollType, " whisper roll from ", playerName, playerRealmName, "for item", itemLink)
    LootRaffle_ReceiveRoll(itemLink, playerName, playerRealmName, rollType, true) -- we don't know what priority people without the addon are rolling. default to need.
end

local function OnItemInfoRecieved(itemId)
    -- if there are any async item info requests for incoming raffles, process them and try to show a roll window
    if LootRaffle.IncomingRaffleItemInfoRequestCount > 0 then
        local name, itemLink, quality, itemLevel, requiredLevel, class, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemId)
        LootRaffle.Log("Async item info request completed for incoming raffle"..itemLink)
        for i,raffle in ipairs(LootRaffle.IncomingRaffleItemInfoRequests) do
            if raffle.itemLink == itemLink or string.find(raffle.itemLink, LootRaffle_EscapePatternCharacters(name)) then
                table.remove(LootRaffle.IncomingRaffleItemInfoRequests, i)
                LootRaffle.IncomingRaffleItemInfoRequestCount = LootRaffle.IncomingRaffleItemInfoRequestCount - 1
                LootRaffle_ShowRollWindow(raffle.itemLink, raffle.playerName, raffle.playerRealmName)
                break
            end
        end
    end
end

local function OnTradeOpened(...)
    LootRaffle.TradeWindowIsOpen = true
    LootRaffle.Log("OnTradeOpened", ...)
    if #LootRaffle.PendingTrades == 0 then return end

    local pendingTrade = LootRaffle.PendingTrades[1]

    -- Reduce try counts once first trade is started to prevent "forcing" a trade.
    if pendingTrade.tryCount < 25 then
        pendingTrade.tryCount = 25
    end
    pendingTrade.tryCount = pendingTrade.tryCount * 1.4 --reduce try-counts left by 40%
    LootRaffle.Log("Trade attempts:", pendingTrade.tryCount)

    local bag, slot = LootRaffle_GetTradableItemBagPosition(pendingTrade.itemLink)    
    LootRaffle.Log("Trade opened, presumably for", pendingTrade.itemLink)

    -- Use current latency to delay the attempt to move the item to the trade window
    local down, up, lagHome, lagWorld = GetNetStats();
    local delay = (lagWorld / 1000) * 2
    LootRaffle.Log("Delaying for ", delay, " seconds before moving trade item...")
    C_Timer.After(delay, function() LootRaffle_SelectItemToTrade(bag, slot) end)
end

local function ProcessTradeAcceptance()
    LootRaffle.PlayerAcceptedTrade = false
    if #LootRaffle.PendingTrades == 0 then return end

    local pendingTrade = LootRaffle.PendingTrades[1]
    LootRaffle.Log("Trade completed, presumably for", pendingTrade.itemLink)
    
    table.remove(LootRaffle.PendingTrades, 1)
end

local function OnTradeAccept(playerAccepted, targetAccepted)
    LootRaffle.Log("OnTradeAccept", playerAccepted, targetAccepted)

    LootRaffle.PlayerAcceptedTrade = playerAccepted == 1

    if #LootRaffle.PendingTrades == 0 or playerAccepted == 0 or targetAccepted == 0 then 
        LootRaffle.Log("Trade state changed: player:", playerAccepted, "target:", targetAccepted)
        return
    end
    ProcessTradeAcceptance()
end

local function OnTradeClosed(...)
    LootRaffle.Log("OnTradeClosed", ...)
    if LootRaffle.PlayerAcceptedTrade then
        ProcessTradeAcceptance()
    end
    LootRaffle.TradeWindowIsOpen = false
end

-- define event->handler mapping
local eventHandlers = {
    PLAYER_ENTERING_WORLD = OnPlayerLoad,
    ADDON_LOADED = OnLoad,
    PLAYER_LOGOUT = OnUnload,
    CHAT_MSG_LOOT = OnItemLooted,
    CHAT_MSG_ADDON = OnMessageRecieved,
    GET_ITEM_INFO_RECEIVED = OnItemInfoRecieved,
    TRADE_SHOW = OnTradeOpened,
    TRADE_CLOSED = OnTradeClosed,
    LOOT_OPENED = OnLootWindowOpen,
    LOOT_CLOSED = OnLootWindowClose,
    CHAT_MSG_WHISPER = OnWhisperReceived,
    TRADE_ACCEPT_UPDATE = OnTradeAccept
}

-- associate event handlers to desired events
for key,block in pairs(eventHandlers) do LootRaffle_Frame:RegisterEvent(key) end
LootRaffle_Frame:SetScript('OnEvent', 
    function(self, event, ...)
        for key,block in pairs(eventHandlers) do
            if event == key then
                block(...)
            end
        end
    end
)

-- registered chat prefixes

C_ChatInfo.RegisterAddonMessagePrefix(LootRaffle.NEW_RAFFLE_MESSAGE)
C_ChatInfo.RegisterAddonMessagePrefix(LootRaffle.ROLL_ON_ITEM_MESSAGE)

-- continuous update handler

local elapsedTime = 0
local updateInterval = 1
local function OnUpdate(self, elapsed)
    elapsedTime = elapsedTime + elapsed
    LootRaffle.CurrentTimeInSeconds = LootRaffle.CurrentTimeInSeconds + elapsed
    if elapsedTime >= updateInterval then
        elapsedTime = 0
        LootRaffle_CheckRollStatus()
        if not InCombatLockdown() then
            LootRaffle_TryPromptForRaffle()
            ProcessLootedItems()
            if not TradeWindowIsOpen then
                LootRaffle_TryTradeWinners()
            end
        end
    end
end

local f = CreateFrame("frame")
f:SetScript("OnUpdate", OnUpdate)
-- LootRaffle_Frame:SetScript("OnUpdate", OnUpdate)


