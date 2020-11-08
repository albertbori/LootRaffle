local _, LootRaffle_Local=...

function LootRaffle_FindIgnoredItemIndex(itemLink)
    for i, listItemLink in ipairs(LootRaffle.IgnoredItems) do
        if listItemLink == itemLink then            
            return i
        end
    end
end

function LootRaffle_IgnoreItem(itemLink)
    local index = LootRaffle_FindIgnoredItemIndex(itemLink)
    if index and index > 0 then
        print("[LootRaffle] "..itemLink.." was already in your ignored list.")
    else
        table.insert(LootRaffle.IgnoredItems, itemLink)
        print("[LootRaffle] "..itemLink.." was added to your ignore list. Type '/raffle unignore "..itemLink.."' to remove it from the ignore list.")
    end
end

function LootRaffle_UnignoreItem(itemLink)
    local index = LootRaffle_FindIgnoredItemIndex(itemLink)
    if index and index > 0 then
        table.remove(LootRaffle.IgnoredItems, i)
        print("[LootRaffle] "..itemLink.." was removed from your ignore list. Type '/raffle ignore "..itemLink.."' to add it back to the ignore list.")
    else
        print("[LootRaffle] Could not find "..itemLink.." in your ignored list.")
    end
end

function LootRaffle_ClearIgnored()
    local count = #LootRaffle.IgnoredItems
    LootRaffle.IgnoredItems = {}
    print("[LootRaffle] "..count.." items removed from your ignore list.")
end

function LootRaffle_ShowIgnored()
    if #LootRaffle.IgnoredItems == 0 then
        print("[LootRaffle] 0 ignored items.")
    end
    for i, listItemLink in ipairs(LootRaffle.IgnoredItems) do
        print("[LootRaffle] Ignored item: "..listItemLink)
    end
end