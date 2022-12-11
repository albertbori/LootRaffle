local _, LootRaffle_Local=...

function LootRaffle_GetTradableItemBagPosition(itemLink)
    LootRaffle.Log("Searching for", itemLink, "in bags...")
    local variantFragmentPattern = LootRaffle_EscapePatternCharacters(select(1, GetItemInfo(itemLink))).." of "
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        LootRaffle.Log("Searching bag", bag)
	    for slot = 1,  C_Container.GetContainerNumSlots(bag) do
            local containerItemLink = C_Container.GetContainerItemLink(bag, slot)
            if containerItemLink then
                local isNameMatch = false

                containerItemLink = string.gsub(containerItemLink, "Player-[-%a%d]+", "") -- try removing crafter player id, ie: "Player-1190-0B8EB803" which doesn't appear in chat-linked item links
                --LootRaffle.Log("Checking "..containerItemLink..":\n"..gsub(containerItemLink, "\124", "\124\124").."\nagainst\n"..gsub(itemLink, "\124", "\124\124").."\nfound in slot: "..bag..","..slot)
                if containerItemLink == itemLink then
                    LootRaffle.Log(itemLink.." found in slot: "..bag..","..slot)
                    isNameMatch = true
                elseif string.find(containerItemLink, variantFragmentPattern) then -- check for variant. "Bracers of Intellect", etc.
                    LootRaffle.Log("Green item variant for "..itemLink.." found in slot: "..bag..","..slot)
                    isNameMatch = true
                end

                if isNameMatch then
			        local isTradable = LootRaffle_IsTradableItem(containerItemLink, bag, slot)
                    if isTradable then
                        return bag, slot
                    else
                        LootRaffle.Log("Slot", bag..","..slot, "is not tradable")
			        end
                else
                    LootRaffle.Log("Slot", bag..","..slot, "name did not match")
				end
            else
                LootRaffle.Log("Slot", bag..","..slot, "contains no item")
		    end
        end
    end
    LootRaffle.Log(itemLink, "not found in bags or wasn't tradable.")
end

function LootRaffle_IsTradableItem(itemLink, bag, slot)
    local item = LootRaffle_GetItemInfo(itemLink, bag, slot)
    return not item.Soulbound or item.TemporarilyTradable
end

function LootRaffle_UnitCanUseItem(unitName, itemLink)
    local item = LootRaffle_GetItemInfo(itemLink)
    local localizedClassName, classCodeName, classIndex = UnitClass(unitName)
    LootRaffle.Log("Checking to see if", unitName, "(", localizedClassName, "|", classCodeName, ") can use item:", item.Link, "| itemClass:", item.ItemClass, "| itemSubClass:", item.ItemSubClass, "| equipSlot:", item.EquipSlot)

    -- if it's armor or weapon, check if class can use it.
    if (item.ItemClass == "Armor" or item.ItemClass == "Weapon") and item.ItemSubClass ~= "Miscellaneous" and item.EquipSlot ~= "INVTYPE_CLOAK" then
        local isProficient = LootRaffle_TableContains(LootRaffle_ClassProficiencies[classCodeName][item.ItemClass], item.ItemSubClass)
        if not isProficient then
            LootRaffle.Log("Player CANNOT use "..item.ItemClass.." of type "..item.ItemSubClass)
            return false
        end
    end

    -- if it's class-specific item, check if this class can use it
    if item.Classes and not LootRaffle_TableContains(item.Classes, localizedClassName) then
        LootRaffle.Log("Player CANNOT use "..item.ItemClass.." of type "..item.ItemSubClass..". Class restriction doesn't match.")
        return false
    end

    -- If the item has primary stats, at least one of the primary stats on the item must match one of the class's primary stats
    local hasPrimaryStats = item.Stats[SPELL_STAT1_NAME] or item.Stats[SPELL_STAT2_NAME] or item.Stats[SPELL_STAT4_NAME] -- "Strength", "Agility" or "Intellect"
    if hasPrimaryStats then
        local found = false
        for _,stat in pairs(LootRaffle_ClassProficiencies[classCodeName]["MainStats"]) do
            if item.Stats[stat] then
                found = true
            end
        end
        if not found then
            LootRaffle.Log("Player CANNOT use "..item.ItemClass.." of type "..item.ItemSubClass..". Wrong stats for class: "..classCodeName..".")
            return false
        end
    end

    -- if the item is an artifact relic, and there's a type, at least one of the class's relic types must match
    if item.ItemSubClass == "Artifact Relic" and item.RelicType then        
        local found = false
        for _,relicType in pairs(LootRaffle_ClassProficiencies[classCodeName]["Relics"]) do
            if item.RelicType == relicType then
                found = true
            end
        end
        if not found then
            LootRaffle.Log("Player CANNOT use "..item.ItemClass.." of type "..item.ItemSubClass..". Wrong relic type '"..item.RelicType.."' for class: "..classCodeName..".")
            return false
        end
    end

    LootRaffle.Log("Player can use ", item.ItemClass, "of type", item.ItemSubClass, "in slot", item.EquipSlot)
    return true
end

function LootRaffle_GetItemInfo(itemLink, bag, slot)
    -- if LootRaffle.ItemInfoCache[itemLink] then --TODO Make sure this gets cleared at the end of all raffles and caches item link vs bag/slot searches separately
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
    local tooltipTable = {}
    if bag and slot then
        tooltipTable = LootRaffle_GetItemTooltipTableByBagSlot(bag, slot)
    else
        tooltipTable = LootRaffle_GetItemTooltipTableByItemLink(itemLink)
    end
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
    elseif not itemInfo.Soulbound and string.match(text, "^"..ITEM_ACCOUNTBOUND.."$") then -- "Account Bound"
        itemInfo.Soulbound = true
        return
    elseif not itemInfo.Soulbound and string.match(text, "^"..ITEM_BNETACCOUNTBOUND.."$") then -- "Blizzard Account Bound"
        itemInfo.Soulbound = true
        return
    end

    --check if trading this BoP is still allowed
    --splits the template string on the macro text (%s), checks to see if both halves match
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

    if not itemInfo.RelicType then
        local pattern = LootRaffle_EscapePatternCharacters(RELIC_TOOLTIP_TYPE) -- "%s Artifact Relic"
        pattern = string.gsub(pattern, "%%%%s", "(.+)")
        local relicType = string.match(text, pattern)
        if relicType then
            itemInfo.RelicType = relicType
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