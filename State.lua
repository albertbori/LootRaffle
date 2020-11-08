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
    MyRaffles = {},
    MyRafflesCount = 0,
    CurrentTimeInSeconds = 0,
    IncomingRaffleItemInfoRequests = {},
    IncomingRaffleItemInfoRequestCount = 0,
    PendingTrades = {},
    RollWindows = {},
    RollWindowsCount = 0,
    TradeWindowIsOpen = false,
    PlayerAcceptedTrade = false,
    IgnoredItems = {},
    ItemInfoCache = {}
}