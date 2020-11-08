local _, LootRaffle_Local=...

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
    local s, e = string.find(BIND_TRADE_TIME_REMAINING, "%%s")
    local bindFirstHalf = LootRaffle_EscapePatternCharacters(string.sub(BIND_TRADE_TIME_REMAINING, 1, s-1))
    local bindSecondHalf = LootRaffle_EscapePatternCharacters(string.sub(BIND_TRADE_TIME_REMAINING, e+1, string.len(BIND_TRADE_TIME_REMAINING)))
    local isTradableBoP = LootRaffle_SearchBagItemTooltip(bag, slot, bindFirstHalf) and LootRaffle_SearchBagItemTooltip(bag, slot, bindSecondHalf)
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
    local s, e = string.find(ITEM_CLASSES_ALLOWED , "%%s")
    local bindFirstHalf = LootRaffle_EscapePatternCharacters(string.sub(ITEM_CLASSES_ALLOWED, 1, s-1))
    if LootRaffle_SearchItemLinkTooltip(itemLink, bindFirstHalf) and not LootRaffle_SearchItemLinkTooltip(itemLink, bindFirstHalf..class) then
        return false
    end
    return true
end

function LootRaffle_ClassCanUseItemStat(itemLink, classCodeName)
    local statsTable = { }
    GetItemStats(itemLink, statsTable)
    -- if it has no main stat, it's fair game. (We can't reliably determine on-use effect intention)
    LootRaffle.Log("Item Strength:", statsTable["ITEM_MOD_STRENGTH_SHORT"], "Agility:", statsTable["ITEM_MOD_AGILITY_SHORT"], "Intellect:", statsTable["ITEM_MOD_INTELLECT_SHORT"])
    if not statsTable["ITEM_MOD_STRENGTH_SHORT"] and not statsTable["ITEM_MOD_AGILITY_SHORT"] and not statsTable["ITEM_MOD_INTELLECT_SHORT"] then
        LootRaffle.Log("No main stat found on raffled item. It's fair game to all.")
        return true
    end
    -- if it has a main stat that the class in question can use, it's fair game
    for i,stat in ipairs(LootRaffle_ClassProficiencies[classCodeName]["MainStats"]) do
        local statKey = "ITEM_MOD_"..string.upper(stat).."_SHORT"
        if statsTable[statKey] then
            LootRaffle.Log(classCodeName, " can use ", stat, ".")
            return true
        end
    end
    LootRaffle.Log(classCodeName, " specs cannot use main stat on item.")
    return false
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

function LootRaffle_SearchBagItemTooltip(bag, slot, patterns)
    --LootRaffle.Log("Searching for", patterns, "in item tooltip for bag/slot:", bag, "/", slot)
    local itemTooltip = LootRaffle_BuildItemTooltip()
    itemTooltip:SetBagItem(bag, slot)
    return LootRaffle_SearchTooltip(itemTooltip, patterns)
end

function LootRaffle_SearchItemLinkTooltip(itemLink, patterns)
    --LootRaffle.Log("Searching for", patterns, "in item tooltip for itemLink:", itemLink)
    local itemTooltip = LootRaffle_BuildItemTooltip()
    itemTooltip:SetHyperlink(itemLink)
    return LootRaffle_SearchTooltip(itemTooltip, patterns)
end

function LootRaffle_SearchTooltip(itemTooltip, patterns)
    LootRaffle.Log("Searching item tooltip for texts: ", patterns)
    itemTooltip:Show()
    for i = 1,itemTooltip:NumLines() do
        local tooltipLine = _G["LootRaffle_ParseItemTooltipTextLeft"..i]
        if tooltipLine then
            local text = tooltipLine:GetText()
            if (type(patterns) == "table") then
                for x,pattern in ipairs(patterns) do
                    if text and (text == pattern or string.find(text, pattern)) then
                        LootRaffle.Log("Search found '", pattern, "' in '", text, "'")
                        return true
                    end
                end
            else
                if text and (text == patterns or string.find(text, patterns)) then
                    LootRaffle.Log("Search found '", patterns, "' in '", text, "'")
                    return true
                end
            end
        else
            LootRaffle.Log("Failed to read parsing tooltip text line", i)
        end
    end
    itemTooltip:Hide()
    LootRaffle.Log("Search found no results.")
    return false
end

function LootRaffle_EscapePatternCharacters(text)
    --return string.gsub(text, "[%.%%]", "%%%1")
    return string.gsub(text, "([^%w])", "%%%1")
end

function LootRaffle_GetItemInfo(itemLink)
    -- if LootRaffle.ItemInfoCache[itemLink] then --TODO Make sure this gets cleared at the end of all raffles
    --     return LootRaffle.ItemInfoCache[itemLink]
    -- end

    local name, link, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
    --local statsTable = GetItemStats(itemLink) --useless. Doesn't return stats for other specs

    local itemInfo = {
        Name = name,
        Link = link,
        Quality = quality,
        ItemLevel = itemLevel,
        RequiredLevel = requiredLevel,
        ItemClass = itemClass,
        ItemSubClass = itemSubClass,
        EquipSlot = equipSlot,
        Texture = texture,
        Stats = {}
    }
    local tooltipTable = LootRaffle_GetItemTooltipTableByItemLink(itemLink)    
    for i in pairs(tooltipTable) do
        LootRaffle_CategorizeTooltipText(tooltipTable[i], itemInfo)
    end
    -- LootRaffle.ItemInfoCache[itemLink] = itemInfo
    return itemInfo
end

function LootRaffle_CategorizeTooltipText(text, itemInfo)
    -- Search stat names
    for x, statName in ipairs(LootRaffle_TooltipStatNames) do
        if not itemInfo.Stats[statName] and string.match(text, "^%+%d+ "..statName.."$") then
            local s, e = string.find(text, "%d+")
            itemInfo.Stats[statName] = string.sub(text, s, e)
            return
        end
    end
    
    -- Search item details
    if not itemInfo.OnEquip and string.match(text, "^"..ITEM_SPELL_TRIGGER_ONEQUIP) then -- "Equip:"
        itemInfo.OnEquip = text
        return
    elseif not itemInfo.OnHit and string.match(text, "^"..ITEM_SPELL_TRIGGER_ONPROC) then -- "Chance on hit:"
        itemInfo.OnHit = text
        return
    elseif not itemInfo.OnUse and string.match(text, "^"..ITEM_SPELL_TRIGGER_ONUSE) then -- "Use:"
        itemInfo.OnUse = text
        return
    elseif not itemInfo.Soulbound and string.match(text, "^"..ITEM_SOULBOUND.."$") then -- "Soulbound"
        itemInfo.Soulbound = true
        return
    end

    --check if trading this BoP is still allowed
    --splits the template string on the macro text (%s), checks to see if both halfs match
    if not itemInfo.TemporarilyTradable then
        local pattern = LootRaffle_EscapePatternCharacters(BIND_TRADE_TIME_REMAINING) -- "You may trade this item with players that were also eligible to loot this item for the next %s."
        pattern = string.gsub(pattern, "%%%%s", ".+")
        if string.match(text, "^"..pattern.."$") then
            itemInfo.TemporarilyTradable = true
            return
        end
    end

    -- check for class-specific text
    if not itemInfo.Classes then
        local pattern = LootRaffle_EscapePatternCharacters(ITEM_CLASSES_ALLOWED) -- "Classes: %s"
        pattern = string.gsub(pattern, "%%%%s", "(.+)")
        local classes = string.match(text, "^"..pattern.."$")
        if classes then
            itemInfo.Classes = {}
            for class in string.gmatch(classes, "(%a[%a%s]+)") do
                table.insert(itemInfo.Classes, class)
            end
            return
        end
    end

    -- check for set bonus text
    local pattern = LootRaffle_EscapePatternCharacters(ITEM_SET_BONUS_GRAY) -- "(%d) Set: %s" (Set bonuses)
    pattern = string.gsub(pattern, "%%%%d", "%%d+")
    pattern = string.gsub(pattern, "%%%%s", ".+")
    if string.match(text, "^"..pattern.."$") then
        if not itemInfo.SetBonuses then
            itemInfo.SetBonuses = {}
        end
        table.insert(itemInfo.SetBonuses, text)
        return
    end

    --TODO:
    -- Sockets
end

-- Builds an item tooltip and then scans the tooltip to extract the text into a table
function LootRaffle_GetItemTooltipTableByBagSlot(bag, slot)
    local itemTooltip = LootRaffle_BuildItemTooltip()
    itemTooltip:SetBagItem(bag, slot)
    return LootRaffle_GetItemTooltipTable(itemTooltip)
end
function LootRaffle_GetItemTooltipTableByItemLink(itemLink)
    local itemTooltip = LootRaffle_BuildItemTooltip()
    itemTooltip:SetHyperlink(itemLink)
    return LootRaffle_GetItemTooltipTable(itemTooltip)
end
function LootRaffle_BuildItemTooltip()
    local itemTooltip = CreateFrame("GameTooltip", "LootRaffle_ParseItemTooltip", nil, "GameTooltipTemplate")
    itemTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    return itemTooltip
end
function LootRaffle_GetItemTooltipTable(itemTooltip)
    local tooltipTable = {}
    itemTooltip:Show()
    for i = 1, itemTooltip:NumLines() do
        local tooltipLine = _G["LootRaffle_ParseItemTooltipTextLeft"..i]
        if tooltipLine then
            local text = tooltipLine:GetText()
            table.insert(tooltipTable, text)
        else
            LootRaffle.Log("Failed to read parsing tooltip text line", i)
        end
    end
    itemTooltip:Hide()
    return tooltipTable
end