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
    elseif string.find(msg, "test") then
        local itemLink = select(2, GetItemInfo(msg)) or GetContainerItemLink(0, 1)
        print("[LootRaffle] Testing item: "..itemLink)
        if itemLink then
            local bag, slot = LootRaffle_GetBagPosition(itemLink)
            local playerName, playerRealmName = UnitFullName('player')
            LootRaffle_ShowRollWindow(itemLink, playerName, playerRealmName)
        end
    elseif string.find(msg, "tradable") then
        local itemLink = select(2, GetItemInfo(msg)) or GetContainerItemLink(0, 1)
        print("[LootRaffle] Testing if item: "..itemLink.." is tradable.")
        if itemLink then
            local bag, slot = LootRaffle_GetBagPosition(itemLink)
            if LootRaffle_IsTradable(bag, slot) then
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
    else
        -- try for item
        local name, itemLink, quality, itemLevel, requiredLevel, class, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(msg)
        if not name then
            print("LootRaffle commands:"); 
            print(" - '[Item Link]]': Starts a raffle");
            print(" - 'logging (on|off)': Toggles logging");
            print(" - 'auto-detect (on|off)': Toggles Automatic raffle prompt when you loot a tradable item.");
            return
        end

        local bag, slot = LootRaffle_GetBagPosition(itemLink)
        if not IsInGroup() then
            print("[LootRaffle] can only be used in a party or raid group.")            
        elseif not LootRaffle_IsTradable(bag, slot) then
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
end

local function OnUnload(...)
    if not LootRaffle_DB then
        LootRaffle_DB = {}
    end
    LootRaffle_DB.LoggingEnabled = LootRaffle.LoggingEnabled
    LootRaffle_DB.AutoDetectLootedItems = LootRaffle.AutoDetectLootedItems
end

local LootedItems = {}
local LootedItemsCount = 0
local function OnItemLooted(message, sender, language, channelString, target, flags, unknown, channelNumber, channelName, unknown, counter)    
    if target ~= UnitName("player") or not IsInGroup() then return end
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
                    local bag, slot = LootRaffle_GetBagPosition(link)
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

    local playerName, playerRealmName = string.split("-", author, 2)
    -- try for item
    local name, itemLink, quality, itemLevel, requiredLevel, class, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(msg)
    LootRaffle.Log("Discovered whisper roll from ", playerName, playerRealmName, "for item", itemLink)
    LootRaffle_ReceiveRoll(itemLink, playerName, playerRealmName, "GREED", true) -- we don't know what priority people without the addon are rolling. default to greed.
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
    TradeWindowIsOpen = true
    -- print("OnTradeOpened", ...)
end

local function OnTradeClosed(...)
    TradeWindowIsOpen = false
    -- print("OnTradeClosed", ...)
end

local function SystemMessageReceived(...)
    local message, sender, language, channelString, target, flags, unknown, channelNumber, channelName, unknown, counter = ...
    LootRaffle.Log("System chat message was received.")
end

-- define event->handler mapping
local eventHandlers = {
    CHAT_MSG_SYSTEN = SystemMessageReceived,
    PLAYER_ENTERING_WORLD = OnPlayerLoad,
    ADDON_LOADED = OnLoad,
    PLAYER_LOGOUT = OnUnload,
    CHAT_MSG_LOOT = OnItemLooted,
    CHAT_MSG_ADDON = OnMessageRecieved,
    GET_ITEM_INFO_RECEIVED = OnItemInfoRecieved,
    TRADE_OPENED = OnTradeOpened,
    TRADE_CLOSED = OnTradeClosed,
    LOOT_OPENED = OnLootWindowOpen,
    LOOT_CLOSED = OnLootWindowClose,
    CHAT_MSG_WHISPER = OnWhisperReceived
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

RegisterAddonMessagePrefix(LootRaffle.NEW_RAFFLE_MESSAGE)
RegisterAddonMessagePrefix(LootRaffle.ROLL_ON_ITEM_MESSAGE)

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


