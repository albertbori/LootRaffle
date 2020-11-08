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

function LootRaffle_GetUnitNameFromPlayerName(playerName, playerRealmName)
    local sameRealm = select(2, UnitFullName("player")) == playerRealmName -- unit full name sometimes returns nil for other players on the same realm

    if IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        local groupPrefix = "party"
        if IsInRaid() then
            groupPrefix = "raid"
        end
        local raidMemberCount = GetNumGroupMembers()
        for i = 1, raidMemberCount do
            local name, realmName = UnitFullName(groupPrefix..i)
            if playerName == name and (sameRealm or playerRealmName == realmName) then
                LootRaffle.Log("Unit name for ", name, realmName, "is", groupPrefix..i)
                return groupPrefix..i
            end
        end
    elseif IsInGroup() then
        local partyRoster = GetHomePartyInfo()
        for i, name in ipairs(partyRoster) do
            local name, realmName = UnitFullName("party"..i)
            if playerName == name and (sameRealm or playerRealmName == realmName) then
                LootRaffle.Log("Unit name for ", name, realmName, "is", "party"..i)
                return "party"..i
            end
        end
    end
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

function LootRaffle_GetWhisperName(playerName, playerRealmName)
    local whisperName = playerName
    if playerRealmName then
        whisperName = whisperName.."-"..playerRealmName
    end
    return whisperName
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