local _, LootRaffle_Local=...

function LootRaffle_GetTradableItemBagPosition(itemLink, isFuzzy)
    LootRaffle.Log("Searching for", itemLink, "(fuzzy: "..tostring(isFuzzy)..") in bags...")
    local itemName = select(1, GetItemInfo(itemLink))
    local fuzzyItemName = LootRaffle_EscapePatternCharacters("h["..itemName.."]")
    local variantFragmentPattern = LootRaffle_EscapePatternCharacters(itemName.." of ")
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        --LootRaffle.Log("Searching bag", bag)
	    for slot = 1,  C_Container.GetContainerNumSlots(bag) do
            local containerItemLink = C_Container.GetContainerItemLink(bag, slot)
            if containerItemLink then
                local isNameMatch = false

                if containerItemLink == itemLink then
                    LootRaffle.Log(itemLink.." found in slot: "..bag..","..slot)
                    isNameMatch = true
                elseif string.find(containerItemLink, variantFragmentPattern) then -- check for variant. "Bracers of Intellect", etc.
                    LootRaffle.Log("Green item variant for "..itemLink.." found in slot: "..bag..","..slot)
                    isNameMatch = true
                elseif isFuzzy and string.find(containerItemLink, fuzzyItemName) then
                    LootRaffle.Log("Fuzzy match "..fuzzyItemName.." found in "..gsub(containerItemLink, "\124", "\124\124").." for "..itemLink.." in slot: "..bag..","..slot)
                    isNameMatch = true
                end

                if isNameMatch then
			        local isTradable = LootRaffle_IsTradableItem(containerItemLink, bag, slot)
                    if isTradable then
                        return bag, slot
                    else
                        LootRaffle.Log("Slot", bag..","..slot, "matched but is not tradable")
			        end
                else
                    --LootRaffle.Log("Slot", bag..","..slot, "name did not match")
				end
            else
                --LootRaffle.Log("Slot", bag..","..slot, "contains no item")
		    end
        end
    end
    LootRaffle.Log(itemLink, "no tradable match was found in bags")
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
    local name, link, quality, itemLevel, requiredLevel, itemClass, itemSubClass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)

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
    local tooltipData = {}

    if bag and slot then
        tooltipData = C_TooltipInfo.GetBagItem(bag, slot)
    else
        tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
    end

    TooltipUtil.SurfaceArgs(tooltipData)
    for _, line in ipairs(tooltipData.lines) do
        TooltipUtil.SurfaceArgs(line)
        LootRaffle_CategorizeTooltipText(line.leftText, itemInfo)
    end

    --DevTools_Dump({ tooltipData })

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
