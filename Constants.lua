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

LootRaffle_ClassProficiencies = {}
LootRaffle_ClassProficiencies["DEATHKNIGHT"] = {
    Armor = { "Plate" },
    Weapon = { "Axes", "Two-Handed Axes", "Maces", "Two-Handed Maces", "Swords", "Two-Handed Swords" }
}
LootRaffle_ClassProficiencies["DEMONHUNTER"] = {
    Armor = { "Leather" },
    Weapon = { "Axes", "Daggars", "Fist Weapons", "Maces", "Swords", "Warglaives" }
}
LootRaffle_ClassProficiencies["DRUID"] = {
    Armor = { "Leather" },
    Weapon = { "Daggers", "Fist Weapons", "Maces", "Polearms", "Staves", "Two-Handed Maces" }
}
LootRaffle_ClassProficiencies["HUNTER"] = {
    Armor = { "Leather" },
    Weapon = { "Axes", "Daggers", "Fist Weapons", "Maces", "Polearms", "Staves", "Swords", "Two-Handed Axes", "Two-Handed Swords", "Bow", "Crossbow", "Gun" }
}
LootRaffle_ClassProficiencies["MAGE"] = {
    Armor = { "Cloth" },
    Weapon = { "Daggers", "Staves", "Swords", "Wand" }
}
LootRaffle_ClassProficiencies["MONK"] = {
    Armor = { "Leather" },
    Weapon = { "Axes", "Fist Weapons", "Maces", "Polearms", "Staves", "Swords" }
}
LootRaffle_ClassProficiencies["PALADIN"] = {
    Armor = { "Plate", "Shields" },
    Weapon = { "Axes", "Maces", "Polearms", "Swords", "Two-Handed Axes", "Two-Handed Maces", "Two-Handed Swords" }
}
LootRaffle_ClassProficiencies["PRIEST"] = {
    Armor = { "Cloth" },
    Weapon = { "Daggers", "Maces", "Staves", "Wand" }
}
LootRaffle_ClassProficiencies["ROGUE"] = {
    Armor = { "Leather" },
    Weapon = { "Axes", "Daggers", "Fist Weapons", "Maces", "Swords" }
}
LootRaffle_ClassProficiencies["SHAMAN"] = {
    Armor = { "Mail" },
    Weapon = { "Axes", "Daggers", "Fist Weapons", "Maces", "Staves", "Two-Handed Axes", "Two-Handed Maces" }
}
LootRaffle_ClassProficiencies["WARLOCK"] = {
    Armor = { "Cloth" },
    Weapon = { "Daggers", "Staves", "Swords", "Wand" }
}
LootRaffle_ClassProficiencies["WARRIOR"] = {
    Armor = { "Plate", "Shields" },
    Weapon = { "Axes", "Daggers", "Fist Weapons", "Maces", "Polearms", "Staves", "Swords", "Two-Handed Axes", "Two-Handed Maces", "Two-Handed Swords" }
}
