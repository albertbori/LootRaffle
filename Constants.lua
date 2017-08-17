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
    Weapon = { "Axes", "Two-Handed Axes", "Maces", "Two-Handed Maces", "Swords", "Two-Handed Swords" },
    Relics = { RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_FROST, RELIC_SLOT_TYPE_FIRE }
}
LootRaffle_ClassProficiencies["DEMONHUNTER"] = {
    MainStats = { "Agility" },
    Armor = { "Leather" },
    Weapon = { "Axes", "Daggars", "Fist Weapons", "Maces", "Swords", "Warglaives" },
    Relics = { RELIC_SLOT_TYPE_FEL, RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_ARCANE }
}
LootRaffle_ClassProficiencies["DRUID"] = {
    MainStats = { "Agility", "Intellect" },
    Armor = { "Leather" },
    Weapon = { "Daggers", "Fist Weapons", "Maces", "Polearms", "Staves", "Two-Handed Maces" },
    Relics = { RELIC_SLOT_TYPE_ARCANE, RELIC_SLOT_TYPE_LIFE, RELIC_SLOT_TYPE_FROST, RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_FIRE }
}
LootRaffle_ClassProficiencies["HUNTER"] = {
    MainStats = { "Agility" },
    Armor = { "Mail" },
    Weapon = { "Axes", "Daggers", "Fist Weapons", "Maces", "Polearms", "Staves", "Swords", "Two-Handed Axes", "Two-Handed Swords", "Bow", "Crossbow", "Gun" },
    Relics = { RELIC_SLOT_TYPE_WIND, RELIC_SLOT_TYPE_ARCANE, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_LIFE }
}
LootRaffle_ClassProficiencies["MAGE"] = {
    MainStats = { "Intellect" },
    Armor = { "Cloth" },
    Weapon = { "Daggers", "Staves", "Swords", "Wand" },
    Relics = { RELIC_SLOT_TYPE_ARCANE, RELIC_SLOT_TYPE_FROST, RELIC_SLOT_TYPE_FIRE }
}
LootRaffle_ClassProficiencies["MONK"] = {
    MainStats = { "Agility", "Intellect" },
    Armor = { "Leather" },
    Weapon = { "Axes", "Fist Weapons", "Maces", "Polearms", "Staves", "Swords" },
    Relics = { RELIC_SLOT_TYPE_LIFE, RELIC_SLOT_TYPE_WIND, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_FROST }
}
LootRaffle_ClassProficiencies["PALADIN"] = {
    MainStats = { "Strength", "Intellect" },
    Armor = { "Plate", "Shields" },
    Weapon = { "Axes", "Maces", "Polearms", "Swords", "Two-Handed Axes", "Two-Handed Maces", "Two-Handed Swords" },
    Relics = { RELIC_SLOT_TYPE_HOLY, RELIC_SLOT_TYPE_LIFE, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_ARCANE, RELIC_SLOT_TYPE_FIRE }
}
LootRaffle_ClassProficiencies["PRIEST"] = {
    MainStats = { "Intellect" },
    Armor = { "Cloth" },
    Weapon = { "Daggers", "Maces", "Staves", "Wand" },
    Relics = { RELIC_SLOT_TYPE_HOLY, RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_LIFE, RELIC_SLOT_TYPE_BLOOD }
}
LootRaffle_ClassProficiencies["ROGUE"] = {
    MainStats = { "Agility" },
    Armor = { "Leather" },
    Weapon = { "Axes", "Daggers", "Fist Weapons", "Maces", "Swords" },
    Relics = { RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_WIND, RELIC_SLOT_TYPE_FEL }
}
LootRaffle_ClassProficiencies["SHAMAN"] = {
    MainStats = { "Agility", "Intellect" },
    Armor = { "Mail" },
    Weapon = { "Axes", "Daggers", "Fist Weapons", "Maces", "Staves", "Two-Handed Axes", "Two-Handed Maces" },
    Relics = { RELIC_SLOT_TYPE_WIND, RELIC_SLOT_TYPE_FROST, RELIC_SLOT_TYPE_FIRE, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_LIFE }
}
LootRaffle_ClassProficiencies["WARLOCK"] = {
    MainStats = { "Intellect" },
    Armor = { "Cloth" },
    Weapon = { "Daggers", "Staves", "Swords", "Wand" },
    Relics = { RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_FIRE, RELIC_SLOT_TYPE_FEL }
}
LootRaffle_ClassProficiencies["WARRIOR"] = {
    MainStats = { "Strength" },
    Armor = { "Plate", "Shields" },
    Weapon = { "Axes", "Daggers", "Fist Weapons", "Maces", "Polearms", "Staves", "Swords", "Two-Handed Axes", "Two-Handed Maces", "Two-Handed Swords" },
    Relics = { RELIC_SLOT_TYPE_BLOOD, RELIC_SLOT_TYPE_IRON, RELIC_SLOT_TYPE_SHADOW, RELIC_SLOT_TYPE_FIRE, RELIC_SLOT_TYPE_WIND }
}
