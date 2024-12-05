# Loot Manager Command Guide

### Start Script
- **Command:** `/lua run ConvLoot`
- **Description:** Starts the Lua script for the Loot Manager bot.

---

## General Commands
These commands provide general controls for the bot's configuration and operational state.

### Toggle Looting Pause
- **Command:** `/ConvLoot pause on/off`
- **Description:** Enables or disables the looting functionality temporarily.
- **Example:** `/ConvLoot pause on` pauses looting.

### Toggle Combat Loot
- **Command:** `/ConvLoot combatloot`
- **Description:** Enables or disables looting during combat.

### Toggle Looting No-Drop
- **Command:** `/ConvLoot nodrop`
- **Description:** Enables or disables the looting of No-Drop items.

### Set Corpse Radius
- **Command:** `/convloot corpseradius <radius>`
- **Description:** Sets radius to loop corpses.

---

## Loot Item Management
These commands allow you to set specific actions for items, such as keeping, selling, banking, ignoring, or destroying.

### Mark Item as "Keep"
- **Command:** `/ConvLoot keep <Item Name>` or `/ConvLoot keep` with item on cursor.
- **Description:** Marks the specified item as "Keep" or assigns this status to the item currently on the cursor.
- **Example:** `/ConvLoot keep Precious Gem`

### Mark Item as "Ignore"
- **Command:** `/ConvLoot ignore <Item Name>` or `/ConvLoot ignore` with item on cursor.
- **Description:** Marks the specified item as "Ignore," preventing it from being looted.
- **Example:** `/ConvLoot ignore Rusty Sword`

### Mark Item as "Sell"
- **Command:** `/ConvLoot sell <Item Name>` or `/ConvLoot sell` with item on cursor.
- **Description:** Marks the specified item as "Sell" to automatically sell it at a merchant.
- **Example:** `/ConvLoot sell Torn Parchment`

### Mark Item as "Bank"
- **Command:** `/ConvLoot bank <Item Name>` or `/ConvLoot bank` with item on cursor.
- **Description:** Marks the specified item as "Bank" for transfer to your bank.
- **Example:** `/ConvLoot bank Rare Artifact`

### Mark Item as "Destroy"
- **Command:** `/ConvLoot destroy <Item Name>` or `/ConvLoot destroy` with item on cursor.
- **Description:** Marks the specified item as "Destroy" for immediate disposal.
- **Example:** `/ConvLoot destroy Broken Shard`

---

## Merchant and Banking Commands
These commands facilitate interactions with merchants and bankers.

### Sell Items
- **Command:** `/ConvLoot sellstuff`
- **Description:** Automatically sells all items marked as "Sell" to the nearest merchant.

### Bank Items
- **Command:** `/ConvLoot bankstuff`
- **Description:** Automatically banks all items marked as "Bank" at the nearest banker.

### Bank Items
- **Command:** `/ConvLoot cleanup`
- **Description:** Automatically destroys all items marked as "Destroy" in the inventory.

---

Supports local loot.ini file by default, or you can add a custom path using `customIniPath`.
Inside of the init.lua file find line `customIniPath = nil` and change it to your path `local customIniPath = '//pcname/c/Macroquest/config/ConvLoot.ini'`.
This will allow you to use the same loot.ini file across a local area network. All chars will read and update this file.