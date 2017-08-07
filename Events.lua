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
        print("LootRaffle: Logging enabled")
    elseif msg == "logging off" then
        LootRaffle.LoggingEnabled = false
        print("LootRaffle: Logging disabled.")
    elseif string.find(msg, "test |") then
        local name, itemLink = GetItemInfo(msg)
        if itemLink then
            local bag, slot = LootRaffle_GetBagPosition(itemLink)
            local playerName, playerRealmName = UnitFullName('player')
            LootRaffle_ShowRollWindow(itemLink, playerName, playerRealmName)
        end
    elseif msg == "test" then
        local itemLink = GetContainerItemLink(0, 1)
        if itemLink then
            local playerName, playerRealmName = UnitFullName('player')
            LootRaffle_ShowRollWindow(itemLink, playerName, playerRealmName)
        end
    else
        -- try for item
        local name, itemLink, quality, itemLevel, requiredLevel, class, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(msg)
        if not name then
            print("LootRaffle commands:"); 
            print(" - '[Item Link]]': Starts a raffle");
            print(" - 'logging (on|off)': Toggles logging");
            return
        end

        local bag, slot = LootRaffle_GetBagPosition(itemLink)
        if not IsInGroup() then
            print("LootRaffle can only be used in a party or raid group.")            
        elseif not LootRaffle_IsTradeable(bag, slot) then
            print("LootRaffle: Item is not tradable.")
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
end

local function OnUnload(...)
    if not LootRaffle_DB then
        LootRaffle_DB = {}
    end
    LootRaffle_DB.LoggingEnabled = LootRaffle.LoggingEnabled
end

local function OnItemLooted(message, sender, language, channelString, target, flags, unknown, channelNumber, channelName, unknown, counter)
    if target ~= UnitName('player') then return end

    local name, itemLink, quality, itemLevel, requiredLevel, class, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(message)

    if not name then
        LootRaffle.Log("Async item info request triggered for message: "..message)
        table.insert(LootRaffle.PossibleRaffleItemInfoRequests, message)
        LootRaffle.PossibleRaffleItemInfoRequestCount = LootRaffle.PossibleRaffleItemInfoRequestCount + 1
    else
        LootRaffle_TryDetectNewRaffleOpportunity(itemLink, quality)
    end
end

local function OnLootWindowClose()
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
    LootRaffle_ReceiveRoll(itemLink, playerName, playerRealmName, "GREED") -- we don't know what priority people without the addon are rolling. default to greed.
end

local function OnItemInfoRecieved(itemId)

    -- if there are any async item info requests for incoming raffles, process them and try to show a roll window
    if LootRaffle.IncomingRaffleItemInfoRequestCount > 0 then
        local name, link, quality, itemLevel, requiredLevel, class, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemId)
        LootRaffle.Log("Async item info request completed for "..link)
        for i,raffle in ipairs(LootRaffle.IncomingRaffleItemInfoRequests) do
            if raffle.itemLink == link then
                LootRaffle_ShowRollWindow(raffle.itemLink, raffle.playerName, raffle.playerRealmName)
                table.remove(LootRaffle.IncomingRaffleItemInfoRequests, i)
                LootRaffle.IncomingRaffleItemInfoRequestCount = LootRaffle.IncomingRaffleItemInfoRequestCount - 1
                return
            end
        end
    end

    -- if there are any async item info requests for possible raffle prompts, process them and try to show the raffle prompt
    if LootRaffle.PossibleRaffleItemInfoRequestCount > 0 then
        for i,message in ipairs(LootRaffle.PossibleRaffleItemInfoRequests) do
            local name, itemLink, quality, itemLevel, requiredLevel, class, subClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(message)
            if name then
                LootRaffle.PossibleRaffleItemInfoRequestCount = LootRaffle.PossibleRaffleItemInfoRequestCount - 1
                table.remove(LootRaffle.PossibleRaffleItemInfoRequests, i) 
                LootRaffle_TryDetectNewRaffleOpportunity(itemLink, quality)
                return
            end
        end
    end
end

local function OnTradeReqCanceled(...)
    -- print("OnTradeReqCanceled", ...)
end

local function OnTradeClosed(...)
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
    TRADE_REQUEST_CANCEL = OnTradeReqCanceled,
    TRADE_CLOSED = OnTradeClosed,
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
        LootRaffle_TryPromptForRaffle()
    end
end

local f = CreateFrame("frame")
f:SetScript("OnUpdate", OnUpdate)
-- LootRaffle_Frame:SetScript("OnUpdate", OnUpdate)


