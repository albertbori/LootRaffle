local RaffleState = {
    PROCESSING,
    WAITING_FOR_ITEM_DETAILS,
    WAITING_FOR_BAG_INFO
}

function LootRaffle.TryCreateNewRaffle(lootText)
    -- build the state frame
    local frame = CreateFrame("Frame")
    frame.lootText = lootText
    frame.ProcessRaffle = ProcessRaffle
    frame:SetScript('OnEvent', function(self, event, ...)
        if event == GET_ITEM_INFO_RECEIVED then
            OnItemInfoRecieved(self, ...)
        end
    end)
    frame.itemInfo = {
        lootText = lootText
    }
    frame:ProcessRaffle()
end

local function ProcessRaffle(self)
    if not self then error("Error: Call to ProcessRaffle with nil `self`") end
    self.State = PROCESSING
    if not self.itemInfo.itemLink then
        LootRaffle.Log("Getting item info for: \""..self.itemInfo.lootText.."\"")
        local itemLink = TryGetItemInfoFromLootText(self.itemInfo.lootText)
        if not itemLink then
            LootRaffle.Log("Item info not yet available for: \""..self.itemInfo.lootText.."\"")
            self.State = RaffleState.WAITING_FOR_ITEM_DETAILS
            return
        end
        self.itemInfo.itemLink = itemLink
    end
    if not self.itemInfo.bag and not self.itemInfo.slot then
        local bag, slot = TryGetBagSlot(self.itemInfo.itemLink)
        if not bag or not slot then
            LootRaffle.Log("Bag and slot not yet available for:", self.itemInfo.itemLink)
            self.State = RaffleState.WAITING_FOR_BAG_INFO
            C_Timer.After(0.1, function() self:ProcessRaffle() end) -- delay for a second while inventory catches up
            -- TODO: Add fail max
            return
        end
        self.itemInfo.bag = bag
        self.itemInfo.slot = slot
    end
    if not CanRaffle(self.itemInfo.itemLink, self.itemInfo.bag, self.itemInfo.slot) then
        self.parent = nil
    end

end

local function TryGetItemInfoFromLootText(lootText)
    if not lootText then error("Error: Call to TryGetItemInfoFromLootText with nil `lootText`") end
    local _, itemLink = GetItemInfo(lootText)
    return itemLink
end

local function OnItemInfoRecieved(self, itemId, success)
    if not self then error("Error: Call to OnItemInfoRecieved with nil `self`") end
    if not itemId then error("Error: Call to OnItemInfoRecieved with `nil` itemId") end
    if not success then error("Error: Call to OnItemInfoRecieved with `nil` success") end
    if self.State ~= RaffleState.WAITING_FOR_ITEM_DETAILS then return end
    if success == false then
        LootRaffle.Log("Item query failed for itemId:", itemId, ", looted text:", "\""..self.lootText.."\"")
        TryGetBagSlot(self, self.lootedText)
        return
    end 
    local itemLink = select(2, GetItemInfo(itemId))
    if not self.lootedText:find(self.lootedText, "item:"..itemId) then return end -- not the item we're looking for
    if self.lootedText:find(itemLink) then return end -- Message doesn't match this chat
    TryGetItemInfo(self, itemId)
end

local function TryGetBagSlot(self, itemLink)
    if not self then error("Error: Call to TryGetBagSlot with nil `self`") end
    if not itemLink then error("Error: Call to TryGetBagSlot with `nil` itemLink") end
    local bag, slot = LootRaffle_GetTradableItemBagPosition(itemLink)
    if not bag or not slot then
        LootRaffle.Log("Bag and slot not yet available for:", itemLink)
        -- What to do?
    end
end

local function CanRaffle(itemLink, bag, slot)
    if not itemLink then error("Error: Call to CanRaffle with nil `itemLink`") end
    if not bag then error("Error: Call to CanRaffle with `nil` bag") end
    if not slot then error("Error: Call to CanRaffle with `nil` slot") end
    local _, _, quality = GetItemInfo(itemLink)
    if quality < LootRaffle.MinimumQuality then
        LootRaffle.Log("Potential raffle item:", itemLink, "is not high enough quality:", quality)
        return
    end
    if not LootRaffle_FindIgnoredItemIndex(itemLink) then
        LootRaffle.Log("Item can be raffled: ", itemLink)
        LootRaffle_TryPromptForRaffle(itemLink)
    end
end