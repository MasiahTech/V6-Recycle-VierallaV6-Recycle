local config = require 'config.client'
local isLoggedIn = LocalPlayer.state.isLoggedIn
local carryPackage = nil
local packageCoords = nil
local nearbyPackage = nil
local myPackageEntity = nil  -- Track the player's own package
local dropoffBoxEntity = nil  -- Track the persistent dropoff box
local pickupPointSerial = nil  -- Track the pickup UI point serial
local dropoffPointSerial = nil  -- Track the dropoff UI point serial
local onDuty = false

-- Debounce flags for E key interactions
local pickupDebounce = false
local dropoffDebounce = false

-- zone check
local entranceTargetID = 'entranceTarget'

local exitTargetID = 'exitTarget'
local exitZone = nil

local deliveryTargetID = 'deliveryTarget'
local deliveryZone = nil

local dutyTargetID = 'dutyTarget'
local dutyZone = nil

local pickupTargetID = 'pickupTarget'
local pickupZone = nil

local tradeNpcTargetID = 'tradeNpcTarget'
local tradeNpcZone = nil

-- Point removal functions (must be defined early for other functions to use)
local function removePickupPoint()
    if pickupPointSerial then
        exports['ZSX_UIV2']:RemovePoint(pickupPointSerial)
        pickupPointSerial = nil
    end
end

local function removeDropoffPoint()
    -- Dropoff point removed via deleteDropoffBox() instead
    if dropoffPointSerial then
        exports['ZSX_UIV2']:RemovePoint(dropoffPointSerial)
        dropoffPointSerial = nil
    end
end

local function clearAllPoints()
    removePickupPoint()
    removeDropoffPoint()
end

local function destroyPickupTarget()
    if not pickupZone then
        return
    end

    if config.useTarget then
        exports.ox_target:removeZone(pickupZone)
    else
        pickupZone:remove()
    end
    
    pickupZone = nil
end

local function destroyDeliveryTarget()
    removeDropoffPoint()
    
    if not deliveryZone then
        return
    end

    if config.useTarget then
        exports.ox_target:removeZone(deliveryZone)
    else
        deliveryZone:remove()
    end
    
    deliveryZone = nil
end

local function spawnDropoffBox()
    print('^2[Recycle Job DEBUG]^7 Spawning dropoff box')
    
    -- Delete old box if it exists
    if dropoffBoxEntity and DoesEntityExist(dropoffBoxEntity) then
        DeleteEntity(dropoffBoxEntity)
    end
    
    local coords = vector3(config.dropLocation.x, config.dropLocation.y, config.dropLocation.z)
    local modelName = config.dropoffBoxModel
    local model = GetHashKey(modelName)
    
    lib.requestModel(model, 5000)
    
    if not HasModelLoaded(model) then
        print('^1[Recycle Job ERROR]^7 Failed to load dropoff box model: ' .. modelName)
        return
    end
    
    dropoffBoxEntity = CreateObject(model, coords.x, coords.y, coords.z, false, true, true)
    SetModelAsNoLongerNeeded(model)
    PlaceObjectOnGroundProperly(dropoffBoxEntity)
    FreezeEntityPosition(dropoffBoxEntity, true)
    
    print('^2[Recycle Job]^7 Dropoff box spawned at delivery location')
end

local function deleteDropoffBox()
    print('^2[Recycle Job DEBUG]^7 Deleting dropoff box')
    if dropoffBoxEntity and DoesEntityExist(dropoffBoxEntity) then
        DeleteEntity(dropoffBoxEntity)
    end
    dropoffBoxEntity = nil
end

local function onDutyOff()
    print('^3[Recycle Job DEBUG]^7 onDutyOff() called')
    onDuty = false
    
    -- Clean up all points
    clearAllPoints()
    print('^2[Recycle Job DEBUG]^7 Points cleared')
    
    -- Destroy zones
    destroyPickupTarget()
    destroyDeliveryTarget()
    print('^2[Recycle Job DEBUG]^7 Zones destroyed')
    
    -- Delete dropoff box
    deleteDropoffBox()
    
    -- Force delete package entity
    if myPackageEntity then
        if DoesEntityExist(myPackageEntity) then
            print('^1[Recycle Job DEBUG]^7 Deleting package entity')
            DeleteEntity(myPackageEntity)
        end
        myPackageEntity = nil
    end
    
    -- Reset package state
    packageCoords = nil
    carryPackage = nil
    
    print('^2[Recycle Job DEBUG]^7 onDutyOff() complete')
end

-- Functions

local function registerEntranceTarget()
    local coords = vector3(config.outsideLocation.x, config.outsideLocation.y, config.outsideLocation.z)

    if config.useTarget then
        exports.ox_target:addBoxZone({
            name = entranceTargetID,
            coords = coords,
            rotation = config.outsideLocation.w,
            size = vec3(4.7, 1.7, 3.75),
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fa-solid fa-house',
                    type = 'client',
                    event = 'qbx_recyclejob:client:target:enterLocation',
                    label = locale("text.enter_warehouse"),
                    distance = 1
                },
            },
        })
    else
        lib.zones.box({
            coords = coords,
            rotation = config.outsideLocation.w,
            size = vec3(4.7, 1.7, 3.75),
            debug = config.debugPoly,
            onEnter = function()
                lib.showTextUI(locale("text.point_enter_warehouse"))
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('qbx_recyclejob:client:target:enterLocation')
                    lib.hideTextUI()
                end
            end
        })
    end
end

local function registerExitTarget()
    local coords = vector3(config.insideLocation.x, config.insideLocation.y, config.insideLocation.z)

    if config.useTarget then
        exitZone = exports.ox_target:addBoxZone({
            name = exitTargetID,
            coords = coords,
            rotation = 0.0,
            size = vec3(1.7, 4.7, 3.75),
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fa-solid fa-house',
                    type = 'client',
                    event = 'qbx_recyclejob:client:target:exitLocation',
                    label = locale("text.exit_warehouse"),
                    distance = 1
                },
            },
        })
    else
        exitZone = lib.zones.box({
            coords = coords,
            rotation = 0.0,
            size = vec3(1.55, 4.95, 3.75),
            debug = config.debugPoly,
            onEnter = function()
                lib.showTextUI(locale("text.point_exit_warehouse"))
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('qbx_recyclejob:client:target:exitLocation')
                    lib.hideTextUI()
                end
            end
        })
    end
end

local function destroyExitTarget()
    if not exitZone then
        return
    end

    if config.useTarget then
        exports.ox_target:removeZone(exitZone)
    else
        exitZone:remove()
    end
    
    exitZone = nil
end

local function getDutyTargetText()
    if config.useTarget then
        local text = onDuty and locale("text.clock_out") or locale("text.clock_in")
        return text
    else
        local text = onDuty and locale("text.point_clock_out") or locale("text.point_clock_in")
        return text
    end
end

local function registerDutyTarget()
    local coords = vector3(config.dutyLocation.x, config.dutyLocation.y, config.dutyLocation.z)

    if config.useTarget then
        dutyZone = exports.ox_target:addBoxZone({
            name = dutyTargetID,
            coords = coords,
            rotation = 0.0,
            size = vec3(1.8, 2.65, 2.0),
            distance = 1.0,
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fa-solid fa-house',
                    type = 'client',
                    event = 'qbx_recyclejob:client:target:toggleDuty',
                    label = getDutyTargetText(),
                    distance = 1
                },
            },
        })
    else
        dutyZone = lib.zones.box({
            coords = coords,
            rotation = 0.0,
            size = vec3(1.8, 2.65, 2.0),
            debug = config.debugPoly,
            onEnter = function()
                lib.showTextUI(getDutyTargetText())
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('qbx_recyclejob:client:target:toggleDuty')
                    lib.hideTextUI()
                end
            end
        })
    end
end

local function destroyDutyTarget()
    if not dutyZone then
        return
    end

    if config.useTarget then
        exports.ox_target:removeZone(dutyZone)
    else
        dutyZone:remove()
    end
    
    dutyZone = nil
end

local function refreshDutyTarget()
    destroyDutyTarget()
    registerDutyTarget()
end

local function registerDeliveryTarget()
    local coords = vector3(config.dropLocation.x, config.dropLocation.y, config.dropLocation.z)
    
    -- Remove old dropoff point if it exists
    if dropoffPointSerial then
        exports['ZSX_UIV2']:RemovePoint(dropoffPointSerial)
    end
    
    -- Add dropoff UI point - only visible to this player
    dropoffPointSerial = exports['ZSX_UIV2']:AddPoint('dropbox', coords, locale("text.hand_in_package"), {
        drawDistance = 50.0,
        removeOnNearby = false,
        onNearby = function()
            -- Optional: Handle when player gets nearby
        end
    })
    
    print('^2[Recycle Job DEBUG]^7 Dropoff point registered with serial: ' .. tostring(dropoffPointSerial))

    if config.useTarget then
        deliveryZone = exports.ox_target:addBoxZone({
            name = deliveryTargetID,
            coords = coords,
            rotation = 0.0,
            size = vec3(5.0, 5.0, 3.0),
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fa-solid fa-house',
                    type = 'client',
                    event = 'qbx_recyclejob:client:target:dropPackage',
                    label = locale("text.hand_in_package"),
                    distance = 2.5,
                    canInteract = function()
                        return carryPackage ~= nil
                    end
                },
            },
        })
    else
        deliveryZone = lib.zones.box({
            coords = coords,
            rotation = 0.0,
            size = vec3(5.0, 5.0, 3.0),
            debug = config.debugPoly,
            onEnter = function()
                lib.showTextUI(locale("text.point_hand_in_package"))
                dropoffDebounce = false
            end,
            onExit = function()
                lib.hideTextUI()
                dropoffDebounce = false
            end,
            inside = function()
                if carryPackage then
                    if IsControlJustReleased(0, 38) and not dropoffDebounce then
                        dropoffDebounce = true
                        TriggerEvent('qbx_recyclejob:client:target:dropPackage')
                        lib.hideTextUI()
                    end
                end
            end
        })
    end
end

local function destroyTradeNpcZone()
    if not tradeNpcZone then
        return
    end

    if config.useTarget then
        exports.ox_target:removeZone(tradeNpcZone)
    else
        tradeNpcZone:remove()
    end
    
    tradeNpcZone = nil
end

local function destroyInsideZones()
    destroyPickupTarget()
    destroyExitTarget()
    destroyDutyTarget()
    destroyDeliveryTarget()
end

local function scrapAnim()
    local time = 5

    lib.playAnim(cache.ped, 'mp_car_bomb', 'car_bomb_mechanic', 3.0, 3.0, -1, 16, 0, false, false, false)
    local openingDoor = true

    CreateThread(function()
        while openingDoor do
            lib.playAnim(cache.ped, 'mp_car_bomb', 'car_bomb_mechanic', 3.0, 3.0, -1, 16, 0, false, false, false)
            Wait(1000)
            time = time - 1
            if time <= 0 then
                openingDoor = false
                StopAnimTask(cache.ped, 'mp_car_bomb', 'car_bomb_mechanic', 1.0)
            end
        end
    end)
end

local function spawnPlayerPackage()
    -- Only spawn package if player is on duty
    if not onDuty then
        print('^1[Recycle Job DEBUG]^7 spawnPlayerPackage() called but onDuty=' .. tostring(onDuty) .. ', returning')
        return
    end
    
    print('^2[Recycle Job DEBUG]^7 spawnPlayerPackage() spawning - onDuty=' .. tostring(onDuty))
    
    if not packageCoords then
        print('^1[Recycle Job DEBUG]^7 packageCoords is nil, returning')
        return
    end
    
    -- Force delete old entity if it still exists
    if myPackageEntity and DoesEntityExist(myPackageEntity) then
        print('^1[Recycle Job DEBUG]^7 Old myPackageEntity exists, deleting it first')
        DeleteEntity(myPackageEntity)
        myPackageEntity = nil
    end
    
    local modelName = config.warehouseObjects[math.random(1, #config.warehouseObjects)]
    local model = GetHashKey(modelName)
    
    lib.requestModel(model, 5000)
    
    if not HasModelLoaded(model) then
        print('^1[Recycle Job ERROR]^7 Failed to load model: ' .. modelName)
        return
    end
    
    local obj = CreateObject(model, packageCoords.x, packageCoords.y, packageCoords.z, false, true, true)
    local obj2 = config.dropLocation.x, config.dropLocation.y, config.dropLocation.z,
    SetModelAsNoLongerNeeded(model)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    
    myPackageEntity = obj
    
    print('^2[Recycle Job DEBUG]^7 Package entity created: ' .. tostring(obj))
    
    -- Remove old point if it exists
    if pickupPointSerial then
        print('^1[Recycle Job DEBUG]^7 Removing old pickupPointSerial')
        exports['ZSX_UIV2']:RemovePoint(pickupPointSerial)
    end
    
    -- Add UI point directly on the object entity - only visible to this player
    pickupPointSerial = exports['ZSX_UIV2']:AddPoint('box', obj,'Pickup materials', {
        drawDistance = 50.0,
        removeOnNearby = false,
        onNearby = function()
            -- Optional: Handle when player gets nearby
        end
    })

    dropoffPointSerial = exports['ZSX_UIV2']:AddPoint('box', obj2, 'Dropoff materials', {
        drawDistance = 50.0,
        removeOnNearby = false,
        onNearby = function()
            -- Optional: Handle when player gets nearby
        end
    })
    
    print('^2[Recycle Job]^7 Package spawned with UI point on entity. Point serial: ' .. tostring(pickupPointSerial))
end

local function getRandomPackage()
    print('^2[Recycle Job DEBUG]^7 getRandomPackage() called, onDuty=' .. tostring(onDuty))
    
    if not onDuty then
        print('^1[Recycle Job DEBUG]^7 getRandomPackage() called but onDuty is false, returning')
        return
    end
    
    -- Ensure old entity is cleaned up
    if myPackageEntity and DoesEntityExist(myPackageEntity) then
        print('^1[Recycle Job DEBUG]^7 Cleaning up old package entity before spawning new one')
        DeleteEntity(myPackageEntity)
    end
    myPackageEntity = nil
    
    -- Get new random location
    packageCoords = config.pickupLocations[math.random(1, #config.pickupLocations)]
    print('^2[Recycle Job DEBUG]^7 Random location selected: ' .. json.encode(packageCoords))
    
    -- Spawn the package at the location
    spawnPlayerPackage()
    
    -- Register target if spawn was successful
    if myPackageEntity then
        RegisterPickupTarget(packageCoords)
        print('^2[Recycle Job DEBUG]^7 Pickup target registered')
    else
        print('^1[Recycle Job ERROR]^7 Failed to spawn package entity')
    end
end

local function pickupPackage()
    local pos = GetEntityCoords(cache.ped, true)
    local boxModel = config.pickupBoxModel
    lib.requestModel(boxModel, 5000)
    lib.playAnim(cache.ped, 'anim@heists@box_carry@', 'idle', 5.0, -1, -1, 50, 0, false, false, false)
    local object = CreateObject(boxModel, pos.x, pos.y, pos.z, true, true, true)
    SetModelAsNoLongerNeeded(boxModel)
    AttachEntityToEntity(object, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.05, 0.1, -0.3, 300.0, 250.0, 20.0, true, true, false, true, 1, true)
    carryPackage = object
end

local function dropPackage()
    ClearPedTasks(cache.ped)
    DetachEntity(carryPackage, true, true)
    DeleteObject(carryPackage)
    carryPackage = nil
end

local function setLocationBlip()
    local RecycleBlip = AddBlipForCoord(config.outsideLocation.x, config.outsideLocation.y, config.outsideLocation.z)
    SetBlipSprite(RecycleBlip, 365)
    SetBlipColour(RecycleBlip, 2)
    SetBlipScale(RecycleBlip, 0.8)
    SetBlipAsShortRange(RecycleBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Recycle Center')
    EndTextCommandSetBlipName(RecycleBlip)
end

local function buildInteriorDesign()
    -- No longer spawning props here - they spawn dynamically when player clocks in
end


local function enterLocation()
    DoScreenFadeOut(500)

    while not IsScreenFadedOut() do
        Wait(10)
    end

    SetEntityCoords(cache.ped, config.insideLocation.x, config.insideLocation.y, config.insideLocation.z)
    buildInteriorDesign()
    DoScreenFadeIn(500)

    destroyInsideZones()
    registerExitTarget()
    registerDutyTarget()
end

local function exitLocation()
    DoScreenFadeOut(500)

    while not IsScreenFadedOut() do
        Wait(10)
    end

    SetEntityCoords(cache.ped, config.outsideLocation.x, config.outsideLocation.y, config.outsideLocation.z + 1)
    DoScreenFadeIn(500)

    onDutyOff()

    if carryPackage then
        dropPackage()
    end
end

function RegisterPickupTarget(coords)
    if not myPackageEntity or not coords then
        return
    end
    
    local targetCoords = vector3(coords.x, coords.y, coords.z)

    if config.useTarget then
        -- Add target zone using a box around the package location
        pickupZone = exports.ox_target:addBoxZone({
            name = pickupTargetID,
            coords = targetCoords,
            size = vec3(3.5, 3.5, 3.0),
            rotation = 0.0,
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fa-solid fa-box',
                    type = 'client',
                    event = 'qbx_recyclejob:client:target:pickupPackage',
                    label = locale("text.get_package"),
                    distance = 3.5,
                    canInteract = function()
                        return not carryPackage
                    end
                }
            }
        })
    else
        pickupZone = lib.zones.box({
            coords = targetCoords,
            rotation = 0.0,
            size = vec3(3.5, 3.5, 4.5),
            debug = config.debugPoly,
            onEnter = function()
                lib.showTextUI(locale("text.point_get_package"))
                pickupDebounce = false
            end,
            onExit = function()
                lib.hideTextUI()
                pickupDebounce = false
            end,
            inside = function ()
                if onDuty then
                    if not carryPackage then
                        if IsControlJustReleased(0, 38) and not pickupDebounce then
                            pickupDebounce = true
                            TriggerEvent('qbx_recyclejob:client:target:pickupPackage')
                            lib.hideTextUI()
                        end
                    end
                end
            end
        })
    end
end

-- Clean up on script restart
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if onDuty then
            onDutyOff()
        end
        clearAllPoints()
    end
end)



local function DrawPackageLocationBlip()
    -- Package point is managed by ZSX_UIV2, no longer needed here
end

local function DrawDropLocationBlip()
    -- Dropoff location is now shown via ZSX_UIV2 point
    -- This function is kept for backwards compatibility but disabled
    return
end

-- Events
RegisterNetEvent('qbx_recyclejob:client:target:enterLocation', function()
    enterLocation()
end)

RegisterNetEvent('qbx_recyclejob:client:target:exitLocation', function()
    exitLocation()
end)

RegisterNetEvent('qbx_recyclejob:client:target:toggleDuty', function()
    print('^2[Recycle Job DEBUG]^7 toggleDuty event - onDuty before: ' .. tostring(onDuty))
    onDuty = not onDuty
    print('^2[Recycle Job DEBUG]^7 toggleDuty event - onDuty after: ' .. tostring(onDuty))

    if onDuty then
        exports.qbx_core:Notify(locale("success.you_have_been_clocked_in"), 'success')
        spawnDropoffBox()
        getRandomPackage()
    else
        exports.qbx_core:Notify(locale("error.you_have_clocked_out"), 'error')
        onDutyOff()
    end

    if carryPackage then
        dropPackage()
    end

    refreshDutyTarget()
    destroyDeliveryTarget()
end)

RegisterNetEvent('qbx_recyclejob:client:target:pickupPackage', function()
    if not pickupZone or carryPackage then
        return
    end

    -- Delete the package entity from the world
    if myPackageEntity and DoesEntityExist(myPackageEntity) then
        DeleteEntity(myPackageEntity)
        myPackageEntity = nil
    end
    
    -- Remove the UI point
    removePickupPoint()
    
    packageCoords = nil
    ClearPedTasks(cache.ped)
    pickupPackage()
    destroyPickupTarget()
    registerDeliveryTarget()
    
end)

RegisterNetEvent('qbx_recyclejob:client:target:dropPackage', function()
    if not carryPackage or not deliveryZone then
        return
    end

    dropPackage()
    destroyDeliveryTarget()
    ClearPedTasks(cache.ped)
    
    TriggerServerEvent('qbx_recycle:server:dropoffBox')
    getRandomPackage()
    
end)

-- Spawn peds
local pedsSpawned = false
local function spawnPeds()
    if not config.peds or not next(config.peds) or pedsSpawned then return end
    for i = 1, #config.peds do
        local point = config.peds[i]
        
        print('^3[Recycle Job DEBUG]^7 Point data: ' .. json.encode(point))
        print('^3[Recycle Job DEBUG]^7 Model type: ' .. type(point.model))
        print('^3[Recycle Job DEBUG]^7 Model value: ' .. tostring(point.model))
        
        -- Use hardcoded model name for testing
        local modelName = 'a_m_m_business_01'
        print('^3[Recycle Job DEBUG]^7 Requesting model: ' .. modelName)
        
        local model = lib.requestModel(modelName)
        
        if not model then
            print('^1[Recycle Job ERROR]^7 Failed to load model: ' .. modelName)
            goto continue
        end
        
        print('^3[Recycle Job DEBUG]^7 Model loaded, creating ped')
        local entity = CreatePed(0, model, point.coords.x, point.coords.y, point.coords.z, point.coords.w, false, true)
        
        if point.scenario then TaskStartScenarioInPlace(entity, point.scenario, 0, true) end
        
        SetModelAsNoLongerNeeded(model)
        FreezeEntityPosition(entity, true)
        SetEntityInvincible(entity, true)
        SetBlockingOfNonTemporaryEvents(entity, true)
        
        point.pedHandle = entity
        print('^2[Recycle Job]^7 Ped ' .. i .. ' spawned successfully')
        
        ::continue::
    end
    pedsSpawned = true
    print('^2[Recycle Job]^7 All peds spawned successfully')
end

RegisterNetEvent('qbx_recyclejob:client:target:openTradeMenu', function()
    TriggerServerEvent('qbx_recycle:server:openTradeMenu')
end)

RegisterNetEvent('qbx_recycle:client:showTradeDialog', function(materialCount)
    local menuOptions = {}
    
    -- Add preset amounts
    local presets = {
        { amount = 1, label = 'Trade 1 recyclablematerial' },
        { amount = 5, label = 'Trade 5 recyclablematerial' },
        { amount = 10, label = 'Trade 10 recyclablematerial' },
        { amount = 20, label = 'Trade 20 recyclablematerial' },
    }
    
    for _, preset in ipairs(presets) do
        if preset.amount <= materialCount then
            table.insert(menuOptions, {
                title = preset.label,
                description = 'Confirm trade',
                onSelect = function()
                    TriggerServerEvent('qbx_recycle:server:executeTrade', preset.amount)
                    exports.qbx_core:Notify('Trade submitted', 'success')
                end
            })
        end
    end
    
    -- Custom amount option
    table.insert(menuOptions, {
        title = 'Custom Amount',
        description = 'Enter a custom amount',
        onSelect = function()
            local input = lib.inputDialog('Custom Trade Amount', {
                {
                    type = 'number',
                    label = 'Amount (1-' .. materialCount .. ')',
                    icon = 'fas fa-coins',
                    min = 1,
                    max = materialCount,
                }
            })
            
            if input then
                TriggerServerEvent('qbx_recycle:server:executeTrade', input[1])
                exports.qbx_core:Notify('Trade submitted', 'success')
            end
        end
    })
    
    -- Cancel option
    table.insert(menuOptions, {
        title = 'Cancel',
        onSelect = function()
            exports.qbx_core:Notify('Trade cancelled', 'error')
        end
    })
    
    lib.registerContext({
        id = 'recycle_trade_menu',
        title = 'Trade Recyclablematerial',
        subtitle = 'You have: ' .. materialCount .. ' recyclablematerial',
        options = menuOptions
    })
    
    lib.showContext('recycle_trade_menu')
end)

RegisterNetEvent('qbx_recycle:client:teleportOutside', function()
    local outsideCoords = config.outsideLocation
    
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Wait(10)
    end

    SetEntityCoords(cache.ped, outsideCoords.x, outsideCoords.y, outsideCoords.z + 1)
    DoScreenFadeIn(500)
    
    if carryPackage then
        dropPackage()
    end
    
    onDutyOff()
    
    exports.qbx_core:Notify('You were teleported outside', 'warning')
end)

CreateThread(function()
    while true do
        if config.drawDropLocationBlip and onDuty and carryPackage then
            DrawDropLocationBlip()
            Wait(0)
        elseif config.drawPackageLocationBlip and onDuty and packageCoords and not carryPackage then
            DrawPackageLocationBlip()
            Wait(0)
        elseif not isLoggedIn then
            Wait(4000)
        else
            Wait(1000)
        end
    end
end)

AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(cache.serverId), function(_, _, loginState)
    if isLoggedIn == loginState then return end
    isLoggedIn = loginState
end)

local function registerTradeNpcZone()
    if not config.peds or not config.peds[1] then return end
    
    local pedCoords = config.peds[1].coords
    local coords = vector3(pedCoords.x, pedCoords.y, pedCoords.z)

    if config.useTarget then
        tradeNpcZone = exports.ox_target:addBoxZone({
            name = tradeNpcTargetID,
            coords = coords,
            rotation = 0.0,
            size = vec3(1.5, 1.5, 2.0),
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fa-solid fa-coins',
                    type = 'client',
                    event = 'qbx_recyclejob:client:target:openTradeMenu',
                    label = 'Trade recyclablematerial',
                    distance = 2.0
                },
            },
        })
    else
        tradeNpcZone = lib.zones.box({
            coords = coords,
            size = vec3(1.5, 1.5, 2.0),
            debug = config.debugPoly,
            onEnter = function()
                lib.showTextUI('[E] Trade recyclablematerial')
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('qbx_recyclejob:client:target:openTradeMenu')
                    lib.hideTextUI()
                end
            end
        })
    end
end

CreateThread(function()
    Wait(1000) -- Wait for config to be fully loaded
    setLocationBlip()
    registerEntranceTarget()
    registerTradeNpcZone()
    spawnPeds()
end)

-- Check if player is inside location on logout/restart
CreateThread(function()
    Wait(5000)
    local playerCoords = GetEntityCoords(cache.ped)
    local insideCoords = vector3(config.insideLocation.x, config.insideLocation.y, config.insideLocation.z)
    
    if #(playerCoords - insideCoords) < 50.0 then
        TriggerServerEvent('qbx_recycle:server:checkInsideLocation')
    end
end)
