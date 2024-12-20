local mq = require('mq')
local lootConfig = {}
local cantLootList = {}
local ignoredCorpses = {}
local lockedCorpses = {}

local DEBUG_MODE = true
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

-- Settings
local settings = {
    CorpseRadius = 60, -- Radius to search for corpses
    CombatLooting = false, -- Allow looting during combat
    MobsTooClose = 50, -- Radius for detecting nearby mobs
    LockedCorpseDuration = 240, -- Seconds to lock unlootable corpses
    IgnoreCorpseDuration = 1800, -- Seconds to skip corpses with ignored items
    MinimumEmptySlots = 4, -- Minimum empty slots required to continue looting
    LootNoDrop = false, -- Loot No-Drop items
    Pause = false
}

-- State tracking
local inventoryFullReported = false
local isReloading = false
-- Default path settings
local iniPath = mq.configDir .. '/loot.ini'


-- Supports local loot.ini file by default, or you can add a custom path using customIniPath.
-- Inside of the init.lua file find line customIniPath = nil and change it to your path local customIniPath = '//pcname/c/Macroquest/config/Loot.ini'.
-- This will allow you to use the same loot.ini file across a local area network. All chars will read and update this file.

local customIniPath = '//Dustin-pc/c/MQ-Emu/config/loot.ini'


-- Function to load loot configuration
local function loadLootConfig()
    if isReloading then return end -- Prevent recursive spam during reload

    local path = customIniPath or iniPath -- Use customIniPath if available
    print("Attempting to load loot configuration from: " .. path)

    local configFile, err = io.open(path, "r")
    if not configFile then
        printf("Failed to load loot configuration file from '%s': %s", path, err)
        return
    end

    print("Loading loot configuration from: " .. path)
    local currentSection = nil
    local tempConfig = {}

    for line in configFile:lines() do
        line = line:match("^%s*(.-)%s*$") -- Trim whitespace

        -- Parse sections and key-value pairs
        if line:sub(1, 1) == "[" and line:sub(-1) == "]" then
            currentSection = line:sub(2, -2)
            tempConfig[currentSection] = {}
            mq.cmdf("/echo New section found: \ay[" .. currentSection .. "]\ax")
        elseif line:find("=") and currentSection then
            local item, action = line:match("^(.-)=(.-)$")
            if item and action then
                item = item:match("^%s*(.-)%s*$")
                action = action:match("^%s*(.-)%s*$")
                tempConfig[currentSection][item] = action
            end
        end
    end
    configFile:close()

    -- Validate loaded config before overwriting
    if next(tempConfig) then
        lootConfig = tempConfig
        mq.cmdf("/echo Loot configuration loaded \agsuccessfully\ax.")
    else
        print("Warning: Loaded configuration is empty. Keeping existing settings.")
    end
end

local function backupFile(filePath)
    local backupPath = filePath .. ".bak"
    local source, err = io.open(filePath, "r")
    if not source then
        print("Failed to create backup: " .. err)
        return
    end
    local dest = io.open(backupPath, "w")
    if not dest then
        print("Failed to write backup file.")
        source:close()
        return
    end
    for line in source:lines() do
        dest:write(line .. "\n")
    end
    source:close()
    dest:close()
end

local function saveLootConfig()
    local path = customIniPath or iniPath
    backupFile(path) -- Create a backup before overwriting

    local file, err = io.open(path, "w")
    if not file then
        printf("Failed to save loot configuration file to '%s': %s", path, err)
        return
    end

    -- Gather and sort section names
    local sections = {}
    for section in pairs(lootConfig) do
        table.insert(sections, section)
    end
    table.sort(sections)

    -- Write sections and their items to the INI file
    for _, section in ipairs(sections) do
        file:write(string.format("[%s]\n", section))
        
        -- Gather and sort item names for the current section
        local items = {}
        for item in pairs(lootConfig[section]) do
            table.insert(items, item)
        end
        table.sort(items)

        -- Write items and their actions
        for _, item in ipairs(items) do
            local action = lootConfig[section][item]
            file:write(string.format("%s=%s\n", item, action))
        end
        file:write("\n")
    end
    
    file:close()
end

local function updateLootConfig(action, itemName)
    local section = string.sub(itemName, 1, 1):upper()
    lootConfig[section] = lootConfig[section] or {}
    lootConfig[section][itemName] = action
    saveLootConfig()
end

mq.bind('/reloadlootfile', function()
    print("Reloading loot configuration...")
    loadLootConfig()
end)

local function setPause(value)
    if value == "on" then
        settings.Pause = true
        print("Looting paused.")
    elseif value == "off" then
        settings.Pause = false
        print("Looting resumed.")
    end
end

-- Helper function to get the name of the item on the cursor
local function getCursorItemName()
    if mq.TLO.Cursor() then
        local cursorItem = mq.TLO.Cursor.Name()
        if cursorItem then
            return cursorItem
        end
    else
        print("No item on cursor.")
        return nil
    end
end

-- Updates the loot configuration to mark an item as "Keep"
local function setItemKeep(value)
    value = value or getCursorItemName()
    if not value or value == "" then
        mq.cmd('/echo \arPlease specify an item to mark as \ayKeep\ax, or place the item on your cursor.')
        return
    end
    mq.cmdf('/echo \agSetting item \ao%s\ax to \ayKeep\ax...', value)
    updateLootConfig("Keep", value)
    mq.cmdf('/echo \agItem \ao%s\ax is now set to \ayKeep\ax.', value)
    mq.cmd('/autoinventory')
    mq.cmd('/dgexecute looter /reloadlootfile')
end

-- Updates the loot configuration to mark an item as "Ignore"
local function setItemIgnore(value)
    value = value or getCursorItemName()
    if not value or value == "" then
        mq.cmd('/echo \arPlease specify an item to mark as \ayIgnore\ax, or place the item on your cursor.')
        return
    end
    mq.cmdf('/echo \agSetting item \ao%s\ax to \ayIgnore\ax...', value)
    updateLootConfig("Ignore", value)
    mq.cmdf('/echo \agItem \ao%s\ax is now set to \ayIgnore\ax.', value)
    mq.cmd('/autoinventory')
    mq.cmd('/dgexecute looter /reloadlootfile')
end

-- Updates the loot configuration to mark an item as "Sell"
local function setItemSell(value)
    value = value or getCursorItemName()
    if not value or value == "" then
        mq.cmd('/echo \arPlease specify an item to mark as \aySell\ax, or place the item on your cursor.')
        return
    end
    mq.cmdf('/echo \agSetting item \ao%s\ax to \aySell\ax...', value)
    updateLootConfig("Sell", value)
    mq.cmdf('/echo \agItem \ao%s\ax is now set to \aySell\ax.', value)
    mq.cmd('/autoinventory')
    mq.cmd('/dgexecute looter /reloadlootfile')
end

-- Updates the loot configuration to mark an item as "Bank"
local function setItemBank(value)
    value = value or getCursorItemName()
    if not value or value == "" then
        mq.cmd('/echo \arPlease specify an item to mark as \ayBank\ax, or place the item on your cursor.')
        return
    end
    mq.cmdf('/echo \agSetting item \ao%s\ax to \ayBank\ax...', value)
    updateLootConfig("Bank", value)
    mq.cmdf('/echo \agItem \ao%s\ax is now set to \ayBank\ax.', value)
    mq.cmd('/autoinventory')
    mq.cmd('/dgexecute looter /reloadlootfile')
end

-- Updates the loot configuration to mark an item as "Destroy"
local function setItemDestroy(value)
    value = value or getCursorItemName()
    if not value or value == "" then
        mq.cmd('/echo \arPlease specify an item to mark as \ayDestroy\ax, or place the item on your cursor.')
        return
    end
    mq.cmdf('/echo \agSetting item \ao%s\ax to \arDestroy\ax...', value)
    updateLootConfig("Destroy", value)
    mq.cmdf('/echo \agItem \ao%s\ax is now set to \arDestroy\ax.', value)
    mq.cmd('/destroy')
    mq.cmd('/dgexecute looter /reloadlootfile')
end

-- Mark a corpse as locked for a duration
local function markLockedCorpse(corpseID)
    lockedCorpses[corpseID] = os.time() + settings.LockedCorpseDuration
end

-- Function to check inventory space
local function hasSufficientInventorySpace()
    local emptySlots = mq.TLO.Me.FreeInventory() or 0
    if emptySlots <= settings.MinimumEmptySlots - 1 then
        if not inventoryFullReported then
            mq.cmdf("/dgt \\ar!!!!\\ax \\ayInventory is almost full (\\ax\\ag%d\\ax\\ay empty slots remaining). Looting paused.\\ax\\ar !!!!\\ax", emptySlots)
            inventoryFullReported = true -- Set the flag to avoid duplicate messages
        end
        return false
    else
        if inventoryFullReported then
            mq.cmd("/echo \agInventory space available. Resuming looting.\ax")
            inventoryFullReported = false -- Reset the flag when space is available
        end
        return true
    end
end

-- Check if a corpse is locked due to ignored items
local function isIgnoredCorpse(corpseID)
    local ignoreUntil = ignoredCorpses[corpseID]
    if not ignoreUntil then return false end
    if os.time() > ignoreUntil then
        ignoredCorpses[corpseID] = nil
        return false
    end
    return true
end

local function isLockedCorpse(corpseID)
    local lockUntil = lockedCorpses[corpseID]
    if not lockUntil then return false end
    if os.time() > lockUntil then
        lockedCorpses[corpseID] = nil
        return false
    end
    return true
end

local function getLootAction(itemName)
    for section, items in pairs(lootConfig) do
        if items[itemName] then
            return items[itemName]
        end
    end
    mq.cmdf("/echo \arItem \ao'%s'\ax not found in loot configuration.", itemName)
    return nil
end

local function lootCorpse(corpseID)
    if corpseID then
        print("Attempting to loot corpse ID: " .. corpseID)
        mq.cmdf('/target id %d', corpseID)
        mq.delay(500, function() return mq.TLO.Target() and corpseID and mq.TLO.Target.ID() == corpseID end)
    end
    -- Ensure the target is a corpse
    if mq.TLO.Target.Type() ~= "Corpse" then
        print("Target is not a corpse.")
        return
    end

    -- Open the loot window
    local success = false
    for attempt = 1, 3 do
        mq.cmd('/loot')
        mq.delay(1000, function() return mq.TLO.Window('LootWnd').Open() end)
        if mq.TLO.Window('LootWnd').Open() then
            success = true
            break
        end
    end

    if not success then
        mq.cmdf("/echo \arFailed to open loot window for corpse ID: \ao%s\ax", corpseID)
        markLockedCorpse(corpseID)
        return
    end

    local items = mq.TLO.Corpse.Items() or 0
    mq.cmdf("/echo \agLoot window opened. Items available: \ay%s\ax", items)
    debugPrint("Items: " .. items)

    for i = 1, items do
        debugPrint("Checking loot slot: " .. i)
        local item = mq.TLO.Corpse.Item(i)
        if item() then
            local itemName = item.Name()
            local action = getLootAction(itemName) -- Check action from loot.ini

            if not action then
                -- If the item is not in loot.ini, add it with Keep action
                mq.cmdf("/echo \ayAdding item to loot.ini as Keep: \ao%s\ax", itemName)
                setItemKeep(itemName)
                action = "Keep" -- Assume Keep after adding
            end

            if action == "Keep" or action == "Bank" or action == "Sell" then
                mq.cmdf("/echo \agLooting item: \ao%s\ax (\ayAction: %s\ax)", itemName, action)
                mq.cmdf('/itemnotify loot%d rightmouseup', i) -- Loot the item
                mq.delay(200) -- Configurable delay
            else
                mq.cmdf("/echo \arSkipping item: \ao%s\ax (\arAction: \ay%s\ax)", itemName, tostring(action))
            end
        end
        mq.delay(100)
    end

    print("Closing loot window for corpse ID: " .. corpseID)
    mq.cmd('/nomodkey /notify LootWnd LW_DoneButton leftmouseup')
    mq.delay(1000, function() return not mq.TLO.Window('LootWnd').Open() end)
end

-- Loot nearby corpses function with slot check
local function lootNearbyCorpses(limit)
    if not hasSufficientInventorySpace() then return false end -- Stop if inventory is full

    local deadCount = mq.TLO.SpawnCount(('npccorpse radius %d'):format(settings.CorpseRadius))()
    local mobsNearby = mq.TLO.SpawnCount(('xtarhater radius %d'):format(settings.MobsTooClose))()

    if deadCount == 0 or (mobsNearby > 0 and not settings.CombatLooting) then return false end

    local didLoot = false
    for i = 1, (limit or deadCount) do
        local corpse = mq.TLO.NearestSpawn(('%d, npccorpse radius %d'):format(i, settings.CorpseRadius))
        if corpse() then
            local corpseID = corpse.ID()
            local distance = corpse.Distance3D() -- Get the 3D distance to the corpse

            if not isIgnoredCorpse(corpseID) and not cantLootList[corpseID] and not isLockedCorpse(corpseID) then
                if corpse() and distance and distance <= 15 then
                    printf("Looting nearby corpse ID %d at distance %.2f.", corpseID, distance)
                    lootCorpse(corpseID)
                else
                    printf("Navigating to corpse ID %d at distance %.2f.", corpseID, distance)
                    mq.cmdf('/nav spawn id %d', corpseID)
                    mq.delay(2000, function() return corpse() and corpse.Distance3D() and corpse.Distance3D() <= 15 end) -- Wait until within 15 units
                    if corpse() and corpse.Distance3D() and corpse.Distance3D() <= 15 then
                        printf("Now within 15 units. Looting corpse ID %d.", corpseID)
                        lootCorpse(corpseID)
                    else
                        printf("Failed to reach corpse ID %d within 15 units.", corpseID)
                    end
                end
                didLoot = true
            end
        end
    end
    return didLoot
end

local function findnearbymerchant()
    print("Finding nearby merchant...")

    -- Search for the nearest merchant within 200 units
    local merchant = mq.TLO.NearestSpawn('merchant radius 200')
    if merchant() then
        local merchantID = merchant.ID()
        local distance = merchant.Distance3D()
        printf("Found nearby merchant ID %d at distance %.2f.", merchantID, distance)

        -- Target the merchant
        mq.cmdf('/target id %d', merchantID)
        mq.delay(500, function() return mq.TLO.Target() and merchantID and mq.TLO.Target.ID() == merchantID end)

        if mq.TLO.Target() and mq.TLO.Target.ID() ~= merchantID then
            mq.cmd("/dgt \\ayFailed to target the merchant. Aborting.")
            return false
        end

        -- Navigate to the merchant if it's farther than 15 units
        if distance and merchantID and distance > 15 then
            printf("Navigating to merchant ID %d (distance: %.2f)...", merchantID, distance)
            mq.cmdf('/nav spawn id %d', merchantID)
            while mq.TLO.Navigation.Active() do
                mq.delay(50)
            end

            -- Verify we reached the merchant
            if mq.TLO.Target() and mq.TLO.Target.Distance3D() > 15 then
                mq.cmd("/dgt \\ayFailed to reach the merchant. Aborting.")
                return false
            end
        end

        print("Successfully reached the merchant.")
        return true
    else
        return false
    end
end

local function sellstuff()
    print("Starting the selling process...")

    if not findnearbymerchant() then
        mq.cmd("/dgt \\ayFailed to find a nearby merchant. Aborting sell process.")
        return
    end

    -- Ensure the merchant window is open
    if not mq.TLO.Window('MerchantWnd').Open() then
        print("Opening merchant window...")
        mq.cmd('/click right target')
        mq.delay(1000, function() return mq.TLO.Window('MerchantWnd').Open() end)
        if not mq.TLO.Window('MerchantWnd').Open() then
            print("Failed to open the merchant window. Aborting sell process.")
            return
        end
    end

    local totalPlat = 0

    -- Iterate through main inventory slots (23-32)
    for i = 23, 32 do
        local mainSlotItem = mq.TLO.Me.Inventory(i)
        if mainSlotItem() then
            local containerSize = mainSlotItem.Container()
            if containerSize and containerSize > 0 then
                -- If the slot contains a container, iterate through its contents
                for j = 1, containerSize do
                    local bagItem = mainSlotItem.Item(j)
                    if bagItem() then
                        local itemName = bagItem.Name()
                        local action = getLootAction(itemName)
                        if action == "Sell" then
                            local sellPrice = bagItem.Value() and bagItem.Value() / 1000 or 0
                            if sellPrice > 0 then
                                mq.cmdf("/echo \agSelling \ao'%s'\ax for \ay%.2f\ax plat.", itemName, sellPrice)
                                mq.cmdf('/itemnotify in pack%d %d leftmouseup', i - 22, j)
                                mq.delay(1000, function()
                                    return mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == itemName
                                end)
                                if mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == itemName then
                                    mq.cmd('/nomodkey /shiftkey /notify MerchantWnd MW_Sell_Button leftmouseup')
                                    mq.delay(1000, function()
                                        return mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == ''
                                    end)
                                    totalPlat = totalPlat + sellPrice
                                else
                                    mq.cmdf("/echo \arFailed to select item \ao'%s'\ax for selling.", itemName)
                                end
                            else
                                mq.cmdf("/echo \arItem \ao'%s'\ax has no sell value. \aySkipping.\ax", itemName)
                            end
                        end
                    end
                end
            else
                -- If the slot does not contain a container, treat it as a single item
                local itemName = mainSlotItem.Name()
                local action = getLootAction(itemName)
                if action == "Sell" then
                    local sellPrice = mainSlotItem.Value() and mainSlotItem.Value() / 1000 or 0
                    if sellPrice > 0 then
                        mq.cmdf("/echo \agSelling \ao'%s'\ax for \ay%.2f\ax plat.", itemName, sellPrice)
                        mq.cmdf('/itemnotify %d leftmouseup', i)
                        mq.delay(1000, function()
                            return mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == itemName
                        end)
                        if mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == itemName then
                            mq.cmd('/nomodkey /shiftkey /notify MerchantWnd MW_Sell_Button leftmouseup')
                            mq.delay(1000, function()
                                return mq.TLO.Window('MerchantWnd/MW_SelectedItemLabel').Text() == ''
                            end)
                            totalPlat = totalPlat + sellPrice
                        else
                            mq.cmdf("/echo \arFailed to select item \ao'%s'\ax for selling.", itemName)
                        end
                    else
                        mq.cmdf("/echo \arItem \ao'%s'\ax has no sell value. \aySkipping.\ax", itemName)
                    end
                end
            end
        end
    end

    -- Close the merchant window after selling
    mq.cmd('/nomodkey /notify MerchantWnd MW_Done_Button leftmouseup')
    mq.cmdf('/dgt \\ayFinished selling. Total\\ax \\atPlatinum\\ax \\ayearned:\\ax \\ag%.2f\\ax', totalPlat)
end

local function findnearbybanker()
    print("Finding nearby banker...")

    -- Search for the nearest banker within 200 units
    local banker = mq.TLO.NearestSpawn('banker radius 200')
    if banker() then
        local bankerID = banker.ID()
        local distance = banker.Distance3D()
        printf("Found nearby banker ID %d at distance %.2f.", bankerID, distance)

        -- Target the banker
        mq.cmdf('/target id %d', bankerID)
        mq.delay(500, function() return mq.TLO.Target() and bankerID and mq.TLO.Target.ID() == bankerID end)

        if mq.TLO.Target() and bankerID and mq.TLO.Target.ID() ~= bankerID then
            mq.cmd("/dgt \\ayFailed to target the banker. Aborting.")
            return false
        end

        -- Navigate to the banker if it's farther than 15 units
        if distance and bankerID and distance > 15 then
            printf("Navigating to banker ID %d (distance: %.2f)...", bankerID, distance)
            mq.cmdf('/nav spawn id %d', bankerID)
            while mq.TLO.Navigation.Active() do
                mq.delay(50)
            end

            -- Verify we reached the banker
            if mq.TLO.Target() and mq.TLO.Target.Distance3D() > 15 then
                mq.cmd("/dgt \\ayFailed to reach the banker. Aborting.")
                return false
            end
        end

        print("Successfully reached the banker.")
        return true
    else
        return false
    end
end

local function bankstuff()
    print("Starting the banking process...")

    -- Use the existing function to find and move to the nearby banker
    if not findnearbybanker() then
        mq.cmd("/dgt \\ayFailed to find a nearby banker. Aborting banking process.")
        return
    end

    -- Ensure the banker window is open
    if not mq.TLO.Window('BigBankWnd').Open() then
        print("Opening banker window...")
        mq.cmd('/click right target')
        mq.delay(1000, function() return mq.TLO.Window('BigBankWnd').Open() end)
        if not mq.TLO.Window('BigBankWnd').Open() then
            mq.cmd("/dgt \\ayFailed to open the banker window. Aborting banking process.")
            return
        end
    end

    -- Function to check if the bank has space for an item of a specific size
    local function canItemFitInBank(itemSize)
        -- Loop from the item's size to the maximum size (4)
        for size = itemSize, 4 do -- Start at the item's size and go up to the largest size
            if mq.TLO.Inventory.Bank.FreeSlots(size)() > 0 then
                return true -- Found a suitable slot
            end
        end
        return false -- No suitable slot found
    end

    -- Move items from the inventory to the bank
    for i = 23, 32 do -- Bag slots for character inventory
        local slotItem = mq.TLO.Me.Inventory(i)
        if slotItem() then
            local containerSize = slotItem.Container()
            if containerSize and containerSize > 0 then
                -- If the slot contains a container, iterate through its contents
                print("Checking bag slot: " .. i)
                for slot = 1, containerSize do
                    local item = slotItem.Item(slot)
                    if item() and item.ID() then
                        local itemName = item.Name()
                        local action = getLootAction(itemName) -- Get the action for the item
                        if action == "Bank" then
                            local itemSlot = item.ItemSlot()
                            local itemSlot2 = item.ItemSlot2()
                            if itemSlot and itemSlot2 then
                                -- Check if the item can fit in the bank
                                local itemSize = item.Size()
                                if canItemFitInBank(itemSize) then
                                    printf("Banking item: %s from bag %d, slot %d", itemName, i, slot)
                                    mq.cmdf(
                                        "/shift /itemnotify in pack%d %d leftmouseup",
                                        math.floor(itemSlot - 22), -- Adjust for pack number
                                        itemSlot2 + 1             -- Sub-slot (1-based index)
                                    )
                                    mq.delay(100, function() return mq.TLO.Cursor() end)
                                    mq.cmdf('/notify BigBankWnd BIGB_AutoButton leftmouseup')
                                    mq.delay(100, function() return not mq.TLO.Cursor() end)
                                else
                                    mq.cmdf('/dgt ALL No valid bank slot for item: %s', itemName)
                                end
                            end
                        end
                    end
                end
            else
                -- If the slot does not contain a container, treat it as a single item
                if slotItem.ID() then
                    local itemName = slotItem.Name()
                    local action = getLootAction(itemName)
                    if action == "Bank" then
                        local itemSlot = slotItem.ItemSlot()
                        if itemSlot then
                            -- Check if the item can fit in the bank
                            local itemSize = slotItem.Size()
                            if canItemFitInBank(itemSize) then
                                printf("Banking item: %s from main slot %d", itemName, i)
                                mq.cmdf("/shift /itemnotify %d leftmouseup", itemSlot)
                                mq.delay(100, function() return mq.TLO.Cursor() end)
                                mq.cmdf('/notify BigBankWnd BIGB_AutoButton leftmouseup')
                                mq.delay(100, function() return not mq.TLO.Cursor() end)
                            else
                                mq.cmdf('/dgt ALL No valid bank slot for item: %s', itemName)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Function to check if the inventory has enough space for an item of a specific size
    local function canItemFitInInventory(itemSize)
        -- Loop from the item's size to the maximum size (4)
        for size = itemSize, 4 do
            if mq.TLO.Me.FreeInventory(size)() > 0 then
                return true -- Found a suitable slot
            end
        end
        return false -- No suitable slot found
    end

    -- Move items from the bank to inventory
    for bankSlot = 1, 24 do -- Bank slots range from 1 to 24
        local containerSize = mq.TLO.Me.Bank(bankSlot).Container()
        if containerSize and containerSize > 0 then
            -- Bank slot contains a container
            for bankSubslot = 1, containerSize do
                local item = mq.TLO.Me.Bank(bankSlot).Item(bankSubslot)
                if item.ID() then
                    local itemName = item.Name()
                    local action = getLootAction(itemName) -- Get the action for the item
                    if action == "Keep" or action == "Sell" or action == "Destroy" then
                        local itemSize = item.Size()
                        if canItemFitInInventory(itemSize) then
                            mq.cmdf('/itemnotify in bank%d %d leftmouseup', bankSlot, bankSubslot)
                            mq.delay(100, function() return mq.TLO.Cursor() end)
                            mq.cmd('/autoinventory')
                            mq.delay(100, function() return not mq.TLO.Cursor() end)
                        else
                            mq.cmd("/dgt \\arNot enough space in inventory for item: " .. itemName)
                            break
                        end
                    end
                end
            end
        else
            -- Bank slot is not a container
            local item = mq.TLO.Me.Bank(bankSlot).Item()
            if item.ID() then
                local itemName = item.Name()
                local action = getLootAction(itemName)
                if action == "Keep" or action == "Sell" or action == "Destroy" then
                    local itemSize = item.Size()
                    if canItemFitInInventory(itemSize) then
                        mq.cmdf('/itemnotify bank%d leftmouseup', bankSlot)
                        mq.delay(100, function() return mq.TLO.Cursor() end)
                        mq.cmd('/autoinventory')
                        mq.delay(100, function() return not mq.TLO.Cursor() end)
                    else
                        mq.cmd("/dgt \\arNot enough space in inventory for item: " .. itemName)
                        break
                    end
                end
            end
        end
    end

    -- Convert currency into platinum
    print("Converting all currency to platinum...")
    if mq.TLO.Window('BigBankWnd').Open() then
        mq.cmd('/notify BigBankWnd BIGB_ChangeButton leftmouseup')
        mq.delay(1000, function() return mq.TLO.Window('BigBankWnd').Open() end)
    else
        print("Banker window not open. Conversion failed.")
    end

    -- Close the banker window after banking and retrieval
    mq.cmd('/nomodkey /notify BigBankWnd BIGB_DoneButton leftmouseup')
    print("Finished banking, retrieving, and currency conversion process.")
end

local function cleanup()
    print("Starting the cleanup process...")

-- cleanup items from inventory
for i = 23, 32 do -- Bag slots for character inventory
    local slotItem = mq.TLO.Me.Inventory(i)
    if slotItem() then
        local containerSize = slotItem.Container()
        if containerSize and containerSize > 0 then
            -- If the slot contains a container, iterate through its contents
            print("Checking bag slot: " .. i)
            for slot = 1, containerSize do
                local item = slotItem.Item(slot)
                if item() and item.ID() then
                    local itemName = item.Name()
                    local action = getLootAction(itemName) -- Get the action for the item
                    if action == "Destroy" then
                        local itemSlot = item.ItemSlot()
                        local itemSlot2 = item.ItemSlot2()
                        if itemSlot and itemSlot2 then
                            printf("Destroying item: %s from bag %d, slot %d", itemName, i, slot)
                            mq.cmdf(
                                "/shift /itemnotify in pack%d %d leftmouseup",
                                math.floor(itemSlot - 22), -- Adjust for pack number
                                itemSlot2 + 1             -- Sub-slot (1-based index)
                            )
                            mq.delay(100, function() return mq.TLO.Cursor() end)
                            mq.cmdf('/destroy')
                            mq.delay(100, function() return not mq.TLO.Cursor() end)
                        end
                    end
                end
            end
        else
            -- If the slot does not contain a container, treat it as a single item
            if slotItem.ID() then
                local itemName = slotItem.Name()
                local action = getLootAction(itemName)
                if action == "Destroy" then
                    local itemSlot = slotItem.ItemSlot()
                    if itemSlot then
                        printf("Destroying item: %s from main slot %d", itemName, i)
                        mq.cmdf("/shift /itemnotify %d leftmouseup", itemSlot)
                        mq.delay(100, function() return mq.TLO.Cursor() end)
                        mq.cmdf('/destroy')
                        mq.delay(100, function() return not mq.TLO.Cursor() end)
                    end
                end
            end
        end
    end
end

    print("Finished destroying items.")
end

local function commandHandler(command, ...)
    -- Convert command and arguments to lowercase for case-insensitive matching
    command = string.lower(command)
    local args = {...}
    for i, arg in ipairs(args) do
        args[i] = string.lower(arg)
    end

    if command == "pause" then
        setPause(args[1])
    elseif command == "combatloot" then
        settings.CombatLooting = not settings.CombatLooting
        print("Combat looting is now " .. (settings.CombatLooting and "enabled" or "disabled") .. ".")
    elseif command == "nodrop" then
        settings.LootNoDrop = not settings.LootNoDrop
        print("Looting No-Drop items is now " .. (settings.LootNoDrop and "enabled" or "disabled") .. ".")
    elseif command == "corpseradius" then
        settings.CorpseRadius = tonumber(args[1]) or 0
        print("Corpse radius set to: " .. settings.CorpseRadius)
    elseif command == "keep" then
        setItemKeep(args[1])
    elseif command == "ignore" then
        setItemIgnore(args[1])
    elseif command == "sell" then
        setItemSell(args[1])
    elseif command == "bank" then
        setItemBank(args[1])
    elseif command == "destroy" then
        setItemDestroy(args[1])
    elseif command == "sellstuff" then
        sellstuff()
    elseif command == "bankstuff" then
        bankstuff()
    elseif command == "cleanup" then
        cleanup()
    end
end

local function commands()
    -- Single binding for the /convSHM command
    mq.bind('/convloot', function(command, ...)
        commandHandler(command, ...)
    end)
end

-- Initialize
local function initialize()
    mq.cmd('/hidecorpse looted')
    mq.cmd('/djoin looter')
    loadLootConfig()
    commands()
end

local function main()
    initialize()
    while true do
        if not settings.Pause then
            if hasSufficientInventorySpace() then
                if (settings.CombatLooting and mq.TLO.Me.Combat()) or not mq.TLO.Me.Combat() then
                    lootNearbyCorpses()
                end
            end
        end
        mq.doevents()
        mq.delay(50)
    end
end

main()