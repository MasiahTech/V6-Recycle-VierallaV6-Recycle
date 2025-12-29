local config = require 'config.server'

-- Debug command to check inventory
RegisterCommand('checkinv', function(source, args, rawCommand)
    if source == 0 then return end
    
    local searchResult = exports.ox_inventory:Search(source, 'recyclablematerial')
    local allItems = exports.ox_inventory:GetInventoryItems(source)
    
    print('^3[DEBUG]^7 Full inventory:')
    for i, item in ipairs(allItems) do
        print('  - ' .. item.name .. ': ' .. (item.count or 0))
    end
    
    print('^3[DEBUG]^7 Recyclablematerial search result: ' .. json.encode(searchResult or {}))
end, false)

-- Get the best trading tier based on amount
local function getTradeAmountTier(amount)
    local tiers = {}
    for tier, _ in pairs(config.tradeAmounts) do
        table.insert(tiers, tier)
    end
    table.sort(tiers, function(a, b) return a > b end)

    for _, tier in ipairs(tiers) do
        if amount >= tier then
            return tier
        end
    end
    return 1
end

-- Player drops off box and receives recyclablematerial
RegisterNetEvent('qbx_recycle:server:dropoffBox', function()
    local src = source
    local amount = math.random(config.dropoffRewards.minAmount, config.dropoffRewards.maxAmount)

    if exports.ox_inventory:CanCarryItem(src, 'recyclablematerial', amount) then
        exports.ox_inventory:AddItem(src, 'recyclablematerial', amount)
    else
        exports.qbx_core:Notify(src, 'Inventory too full', 'error')
    end
end)

-- Open trade menu
RegisterNetEvent('qbx_recycle:server:openTradeMenu', function()
    local src = source
    
    print('^3[Recycle Job DEBUG]^7 openTradeMenu called for player ' .. src)
    
    -- Get all inventory items
    local allItems = exports.ox_inventory:GetInventoryItems(src)
    local materialCount = 0
    
    print('^3[Recycle Job DEBUG]^7 Total items in inventory: ' .. #allItems)
    
    -- Find recyclablematerial in the inventory
    for i = 1, #allItems do
        if allItems[i].name == 'recyclablematerial' then
            materialCount = allItems[i].count or 0
            print('^3[Recycle Job DEBUG]^7 Found recyclablematerial: ' .. materialCount)
            break
        end
    end

    print('^3[Recycle Job]^7 Material count found: ' .. materialCount)

    if materialCount <= 0 then
        exports.qbx_core:Notify(src, 'You have no materials to trade', 'error')
        return
    end

    TriggerClientEvent('qbx_recycle:client:showTradeDialog', src, materialCount)
end)

-- Handle player trade request
RegisterNetEvent('qbx_recycle:server:executeTrade', function(tradeAmount)
    local src = source

    print('^3[Recycle Job DEBUG]^7 executeTrade called with amount: ' .. tostring(tradeAmount))

    -- Validate trade amount
    if type(tradeAmount) ~= 'number' or tradeAmount <= 0 then
        print('^1[Recycle Job ERROR]^7 Invalid trade amount type or value')
        exports.qbx_core:Notify(src, 'Invalid trade amount', 'error')
        return
    end

    -- Check inventory
    local allItems = exports.ox_inventory:GetInventoryItems(src)
    local materialCount = 0
    
    for i = 1, #allItems do
        if allItems[i].name == 'recyclablematerial' then
            materialCount = allItems[i].count or 0
            break
        end
    end

    print('^3[Recycle Job DEBUG]^7 Player has ' .. materialCount .. ', needs ' .. tradeAmount)

    if materialCount < tradeAmount then
        exports.qbx_core:Notify(src, 'You do not have enough materials', 'error')
        return
    end

    -- Remove recyclablematerial
    exports.ox_inventory:RemoveItem(src, 'recyclablematerial', tradeAmount)

    -- Get trading tier
    local tier = getTradeAmountTier(tradeAmount)
    local tierConfig = config.tradeAmounts[tier]

    -- Distribute base items
    local itemCount = math.random(tierConfig.itemsRewardCount.min, tierConfig.itemsRewardCount.max)
    for _ = 1, itemCount do
        local randItem = config.itemTable[math.random(1, #config.itemTable)]
        local amount = math.random(1, 3)

        if exports.ox_inventory:CanCarryItem(src, randItem, amount) then
            exports.ox_inventory:AddItem(src, randItem, amount)
        end
        Wait(100)
    end

    -- Check for chance items
    for _, chanceItemData in ipairs(tierConfig.chanceItems) do
        local rand = math.random(1, 100)
        if rand <= chanceItemData.chance then
            local qty = math.random(chanceItemData.qty.min, chanceItemData.qty.max)
            if exports.ox_inventory:CanCarryItem(src, chanceItemData.item, qty) then
                exports.ox_inventory:AddItem(src, chanceItemData.item, qty)
            end
        end
        Wait(100)
    end

    -- Check for lucky items
    for _, luckyItemData in ipairs(tierConfig.luckyItems) do
        local rand = math.random(1, 100)
        if rand <= luckyItemData.chance then
            local qty = math.random(luckyItemData.qty.min, luckyItemData.qty.max)
            if exports.ox_inventory:CanCarryItem(src, luckyItemData.item, qty) then
                exports.ox_inventory:AddItem(src, luckyItemData.item, qty)
            end
        end
        Wait(100)
    end

    exports.qbx_core:Notify(src, 'Trade completed! You received items.', 'success')
end)

-- Check if player is inside location and teleport them outside
RegisterNetEvent('qbx_recycle:server:checkInsideLocation', function()
    local src = source
    
    CreateThread(function()
        Wait(1000)
        
        local ped = GetPlayerPed(src)
        if ped == 0 then
            return
        end

        local playerCoords = GetEntityCoords(ped)
        local insideCoords = vector3(config.insideLocation.x, config.insideLocation.y, config.insideLocation.z)

        if #(playerCoords - insideCoords) < 10.0 then
            TriggerClientEvent('qbx_recycle:client:teleportOutside', src)
        end
    end)
end)
