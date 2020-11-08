local _, LootRaffle_Local=...

LootRaffle_ItemQuality = {
    Poor = 0,
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Artifact = 6,
    Heirloom = 7
}

LootRaffle_ROLLTYPES = { "NEED", "GREED", "DE", "PASS" }

LootRaffle_ROLLTYPES_STRINGS = {
    NEED = "Need",
    GREED = "Greed",
    DE = "Disenchant/Transmog",
    PASS = "Pass"
}

LootRaffle_ClassProficiencies = {}
LootRaffle_ClassProficiencies["DEATHKNIGHT"] = {
    MainStats = { "Strength" },
    Armor = { "Plate" },
    Weapon = { "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces", "One-Handed Swords", "Two-Handed Swords" },
    Relics = { RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_FROST, RELIC_SLOT_TYPE_FIRE }
}
LootRaffle_ClassProficiencies["DEMONHUNTER"] = {
    MainStats = { "Agility" },
    Armor = { "Leather" },
    Weapon = { "One-Handed Axes", "Daggars", "Fist Weapons", "One-Handed Maces", "One-Handed Swords", "Warglaives" },
    Relics = { RELIC_SLOT_TYPE_FEL, RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_ARCANE }
}
LootRaffle_ClassProficiencies["DRUID"] = {
    MainStats = { "Agility", "Intellect" },
    Armor = { "Leather" },
    Weapon = { "Daggers", "Fist Weapons", "One-Handed Maces", "Polearms", "Staves", "Two-Handed Maces" },
    Relics = { RELIC_SLOT_TYPE_ARCANE, RELIC_SLOT_TYPE_LIFE, RELIC_SLOT_TYPE_FROST, RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_FIRE }
}
LootRaffle_ClassProficiencies["HUNTER"] = {
    MainStats = { "Agility" },
    Armor = { "Mail" },
    Weapon = { "One-Handed Axes", "Daggers", "Fist Weapons", "One-Handed Maces", "Polearms", "Staves", "One-Handed Swords", "Two-Handed Axes", "Two-Handed Swords", "Bows", "Crossbows", "Guns" },
    Relics = { RELIC_SLOT_TYPE_WIND, RELIC_SLOT_TYPE_ARCANE, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_LIFE }
}
LootRaffle_ClassProficiencies["MAGE"] = {
    MainStats = { "Intellect" },
    Armor = { "Cloth" },
    Weapon = { "Daggers", "Staves", "One-Handed Swords", "Wands" },
    Relics = { RELIC_SLOT_TYPE_ARCANE, RELIC_SLOT_TYPE_FROST, RELIC_SLOT_TYPE_FIRE }
}
LootRaffle_ClassProficiencies["MONK"] = {
    MainStats = { "Agility", "Intellect" },
    Armor = { "Leather" },
    Weapon = { "One-Handed Axes", "Fist Weapons", "One-Handed Maces", "Polearms", "Staves", "One-Handed Swords" },
    Relics = { RELIC_SLOT_TYPE_LIFE, RELIC_SLOT_TYPE_WIND, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_FROST }
}
LootRaffle_ClassProficiencies["PALADIN"] = {
    MainStats = { "Strength", "Intellect" },
    Armor = { "Plate", "Shields" },
    Weapon = { "One-Handed Axes", "One-Handed Maces", "Polearms", "One-Handed Swords", "Two-Handed Axes", "Two-Handed Maces", "Two-Handed Swords" },
    Relics = { RELIC_SLOT_TYPE_HOLY, RELIC_SLOT_TYPE_LIFE, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_ARCANE, RELIC_SLOT_TYPE_FIRE }
}
LootRaffle_ClassProficiencies["PRIEST"] = {
    MainStats = { "Intellect" },
    Armor = { "Cloth" },
    Weapon = { "Daggers", "One-Handed Maces", "Staves", "Wands" },
    Relics = { RELIC_SLOT_TYPE_HOLY, RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_LIFE, RELIC_SLOT_TYPE_BLOOD }
}
LootRaffle_ClassProficiencies["ROGUE"] = {
    MainStats = { "Agility" },
    Armor = { "Leather" },
    Weapon = { "One-Handed Axes", "Daggers", "Fist Weapons", "One-Handed Maces", "One-Handed Swords" },
    Relics = { RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_WIND, RELIC_SLOT_TYPE_FEL }
}
LootRaffle_ClassProficiencies["SHAMAN"] = {
    MainStats = { "Agility", "Intellect" },
    Armor = { "Mail" },
    Weapon = { "One-Handed Axes", "Daggers", "Fist Weapons", "One-Handed Maces", "Staves", "Two-Handed Axes", "Two-Handed Maces" },
    Relics = { RELIC_SLOT_TYPE_WIND, RELIC_SLOT_TYPE_FROST, RELIC_SLOT_TYPE_FIRE, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_LIFE }
}
LootRaffle_ClassProficiencies["WARLOCK"] = {
    MainStats = { "Intellect" },
    Armor = { "Cloth" },
    Weapon = { "Daggers", "Staves", "One-Handed Swords", "Wands" },
    Relics = { RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_FIRE, RELIC_SLOT_TYPE_FEL }
}
LootRaffle_ClassProficiencies["WARRIOR"] = {
    MainStats = { "Strength" },
    Armor = { "Plate", "Shields" },
    Weapon = { "One-Handed Axes", "Daggers", "Fist Weapons", "One-Handed Maces", "Polearms", "Staves", "One-Handed Swords", "Two-Handed Axes", "Two-Handed Maces", "Two-Handed Swords" },
    Relics = { RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_FIRE, RELIC_SLOT_TYPE_WIND }
}

LootRaffle_TooltipStatNames = {
    SPELL_STAT1_NAME, -- Strength
    SPELL_STAT2_NAME, -- Agility
    SPELL_STAT3_NAME, -- Stamina
    SPELL_STAT4_NAME, -- Intellect
    STAT_HASTE,
    STAT_CRITICAL_STRIKE,
    STAT_MASTERY
}

function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end