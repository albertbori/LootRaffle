local _, LootRaffle_Local=...

-- Add static confirmation dialog
StaticPopupDialogs["LOOTRAFFLE_PROMPT"] = {
    text = "Would you like to start a raffle for %s?",
    button1 = "Yes",
    button2 = "No",
    button3 = "Ignore",
    OnAccept = function(self, data)
        LootRaffle.Log("LOOTRAFFLE_PROMPT accepted.")
        LootRaffle_StartRaffle(data.link)
        LootRaffle.PossibleRafflePromptShown = false
    end,
    OnCancel = function()
        LootRaffle.Log("LOOTRAFFLE_PROMPT canceled.")
        LootRaffle.PossibleRafflePromptShown = false
    end,
    OnAlt = function(self, data)
        LootRaffle.Log("LOOTRAFFLE_PROMPT ignored.")
        LootRaffle_IgnoreItem(data.link)
        LootRaffle.PossibleRafflePromptShown = false
    end,
    timeout = LootRaffle.RaffleLengthInSeconds,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
    hasItemFrame = true
}


function LootRaffle_Notification_SendRaffleStart(itemLink, raffleId)
    local rafflerName = LootRaffle_UnitFullName("player")
    local notification = strjoin("^", rafflerName, raffleId, itemLink)
    C_ChatInfo.SendAddonMessage(LootRaffle.NEW_RAFFLE_MESSAGE, notification, LootRaffle_GetCurrentChannelName())
end

function LootRaffle_Notification_ParseRaffleStart(message)
    local rafflerName, raffleId, itemLink = string.split("^", message)
    return rafflerName, raffleId, itemLink
end

function LootRaffle_Notification_SendRoll(itemLink, rafflerName, raffleId, rollType)
    local rollerName = LootRaffle_UnitFullName("player")
    local notification = strjoin("^", rafflerName, raffleId, itemLink, rollerName, rollType)
    C_ChatInfo.SendAddonMessage(LootRaffle.ROLL_ON_ITEM_MESSAGE, notification, LootRaffle_GetCurrentChannelName())
end

function LootRaffle_Notification_ParseRoll(message)
    local rafflerName, raffleId, itemLink, rollerName, rollType = string.split("^", message)
    return rafflerName, raffleId, itemLink, rollerName, rollType
end
