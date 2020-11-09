local _, LootRaffle_Local=...

function LootRaffle_GetCurrentChannelName()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    else
        return "PARTY"
    end
end

function LootRaffle_GetUnitNameFromPlayerName(fullName)
    if IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        local groupPrefix = "party"
        if IsInRaid() then
            groupPrefix = "raid"
        end
        local raidMemberCount = GetNumGroupMembers()
        for i = 1, raidMemberCount do
            local unitFullName = LootRaffle_UnitFullName(groupPrefix..i)
            if unitFullName == fullName then
                LootRaffle.Log("Unit name for ", name, realmName, "is", groupPrefix..i)
                return groupPrefix..i
            end
        end
    elseif IsInGroup() then
        local partyRoster = GetHomePartyInfo()
        for i, name in ipairs(partyRoster) do
            local unitFullName = LootRaffle_UnitFullName("party"..i)
            if unitFullName == fullName then
                LootRaffle.Log("Unit name for ", name, realmName, "is", "party"..i)
                return "party"..i
            end
        end
    end
    LootRaffle.Log("Could not find unit name from player name", fullName)
    return nil
end

function LootRaffle_GetGroupSize()
    if IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return GetNumGroupMembers()
    else
        local partyRoster = GetHomePartyInfo()
        local partySize = 0
        for i, name in ipairs(partyRoster) do
            partySize = partySize + 1
        end
        return partySize
    end
end

function LootRaffle_GetRaffleLengthInSeconds()
    if  IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return LootRaffle.PugRaffleRaffleLengthInSeconds
    else
        return LootRaffle.RaffleLengthInSeconds
    end
end

function LootRaffle_TableContains(table, element)
    for _, value in pairs(table) do
        if value == element then
        return true
        end
    end
    return false
end

function LootRaffle_Dump(o, level)
    if not level then
        level = 0
    end

    local indent = ""
    local step = level
    while step > 0 do
        indent = indent.."  "
        step = step - 1
    end

    if type(o) == 'table' then
        local s = '{\n'
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. indent .. '  ['..k..'] = ' .. LootRaffle_Dump(v, level + 1) .. ',\n'
        end
        return indent .. s .. indent .. '}\n'
    elseif type(o) == "string" then
        return '"'..o..'"'
    else
        return tostring(o)
    end
end

function LootRaffle_UnitFullName(unit)    
    local playerName, playerRealmName = UnitFullName(unit)
    local fullName = strjoin("-", playerName, playerRealmName or string.gsub(GetRealmName(), "%s+", ""))
    return fullName
end

function LootRaffle_LoadItemAsync(itemLink, completion)
    local name = GetItemInfo(itemLink)
    if name then
        completion(itemLink)
    else
        -- Use current latency to delay the attempt to get the item info
        local down, up, lagHome, lagWorld = GetNetStats();
        local delay = (lagWorld / 1000) * 2
        LootRaffle.Log("Delaying LootRaffle_LoadItemAsync("..itemLink..") for ", delay, "seconds...")
        C_Timer.After(delay, function() LootRaffle_LoadItemAsync(itemLink, completion) end)
    end
end

function LootRaffle_GetItemNameFromLink(itemLink)
    return string.match(itemLink, "\124h(%[.-%])\124")
end