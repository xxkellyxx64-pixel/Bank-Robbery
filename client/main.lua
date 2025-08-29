player = {}
bank_to_vault = {}
local bank = nil
Entities = {}
local bankRobberyInProgress = false


Citizen.CreateThread(function()
    while not DoesEntityExist(PlayerPedId()) do Wait(100) end
    SetupBanks(bank_robbed)
end)

local vh_to_bank = {}
function SetupBanks(bank_robbed)
    RequestModel(BANKS.pillbox.vault_hack.model)
    while not HasModelLoaded(BANKS.pillbox.vault_hack.model) do Wait(100) end

    for k, v in pairs(BANKS) do
        local vault_hack = CreateObject(v.vault_hack.model, v.vault_hack.position, false, false, false)
        SetEntityAsMissionEntity(vault_hack)
        FreezeEntityPosition(vault_hack, true)
        SetEntityRotation(vault_hack, v.vault_hack.rotation)
        SetEntityInvincible(vault_hack, true)
        vh_to_bank[vault_hack] = k
        Entities[#Entities+1] = vault_hack
        

        if v.vault_door.closestObject then
            bank_to_vault[k] = GetClosestObjectOfType(v.vault_door.position, 1.0, v.vault_door.model, false, false, false)
            AddDoorToSystem(GetHashKey("bank_robbery_"..k), v.vault_door.model, GetEntityCoords(bank_to_vault[k]))
        else
            bank_to_vault[k] = CreateObject(v.vault_door.model, v.vault_door.position, false, false, false)
            AddDoorToSystem(GetHashKey("bank_robbery_"..k), v.vault_door.model, v.door.position)
        end
        
        FreezeEntityPosition(bank_to_vault[k], true)
        SetEntityRotation(bank_to_vault[k], 0.0, 0.0, bank_robbed == k and v.vault_door.reset_yaw-90 or v.vault_door.reset_yaw)
        SetEntityInvincible(bank_to_vault[k], true)
        SetEntityAsMissionEntity(bank_to_vault[k])
        Entities[#Entities+1] = bank_to_vault[k]
        DoorSystemSetDoorState(GetHashKey("bank_robbery_"..k), 4, true, true)
        DoorSystemSetDoorState(GetHashKey("bank_robbery_"..k), 6, true, true)
        DoorSystemSetDoorState(GetHashKey("bank_robbery_"..k), 1, true, true)

        exports.ox_target:addLocalEntity(vault_hack, {
            label = localesEN["hack_vault"],
            event = "Calsky_bankrobbery:StartVaultHack",
            icon = "fas fa-book-skull",
            distance = 1.5
        })
    end

    if bank then
        if bank.door_hack then
            local door_hack = GetClosestObjectOfType(bank.door_hack.position, 1.0, bank.door_hack.model)
            while bank and not DoesEntityExist(door_hack) do Wait(100)
                door_hack = GetClosestObjectOfType(bank.door_hack.position, 1.0, bank.door_hack.model)
            end
            exports.ox_target:addLocalEntity(door_hack, {
                label = localesEN["hack_vault"],
                event = "Calsky_bankrobbery:StartDoorHack",
                icon = "fas fa-book-skull",
                distance = 1.5
            })
        end
    end
end

RegisterNetEvent("Calsky_bankrobbery:StartVaultHack", function(data)
    local entity = data.entity
    StartVaultHack(entity)
end)

function StartVaultHack(entity)
    bank = BANKS[vh_to_bank[entity]]
    bank.bank = vh_to_bank[entity]
    lib.callback("Calsky_bankrobbery:CanBeRobbed", false, function(allowed)
        if not allowed then 
            lib.notify({
                title = localesEN["hack_vault_name"],
                description = localesEN["vault_empty"],
                type = "error"
            })
            return 
        end
        player.Ped = PlayerPedId()
        
        -- Play the animation but don't use its result
        AnimateHacking(entity)
        
        -- Always set success to true (no minigame, but animation still plays)
        local success = true
        
        local playerCoords = GetEntityCoords(player.Ped)
        local streetName = GetStreetNameFromHashKey(GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z))
                
        if success then
            bankRobberyInProgress = true  -- Set to true when hack succeeds
            TriggerServerEvent('Calsky_bankrobbery:PlayVaultSound', bank.bank)
                        
            -- Add timer notification
            lib.notify({
                title = 'Bank Robbery',
                description = 'You have 10 minutes to grab the cash before the vault closes!',
                type = 'inform',
                duration = 10000, -- Show for 10 seconds
                position = 'center-right',
                icon = 'fa-solid fa-vault' -- Bank vault icon
            })
                        
            -- Use your custom dispatch system (replace 'your_dispatch_script_name' with actual name)
            exports['dispatch']:TriggerBankRobbery(bank.bank, streetName)
                        
            PrepareInside()
            TriggerServerEvent("Calsky_bankrobbery:OpenVaultDoor", bank.bank)
            lib.notify({
                title = localesEN["hack_vault_name"],
                description = localesEN["vault_hacked"],
                type = "success"
            })
        end
    end, bank.bank)
end




RegisterNetEvent("Calsky_bankrobbery:GrabCash", function(data)
    local entity = data.entity
    player.Ped = PlayerPedId()
    AnimateGrabCash(entity)
end)

function PrepareInside()
    if bank.first_cash then RequestModel(bank.first_cash.model) 
        while not HasModelLoaded(bank.first_cash.model) do Wait(100) end

        -- FIRST CASH LOCATION
        local old_first_cash = GetClosestObjectOfType(bank.first_cash.position, 1.0, bank.first_cash.model)
        if DoesEntityExist(old_first_cash) then
            NetworkRequestControlOfEntity(old_first_cash)
            while not NetworkHasControlOfEntity(old_first_cash) do Wait(10) end
            DeleteObject(old_first_cash)
        end

        local old_first_cash_empty = GetClosestObjectOfType(bank.first_cash.position, 1.0, GetHashKey("hei_prop_hei_cash_trolly_03"))
        if DoesEntityExist(old_first_cash_empty) then
            NetworkRequestControlOfEntity(old_first_cash_empty)
            while not NetworkHasControlOfEntity(old_first_cash_empty) do Wait(10) end
            DeleteObject(old_first_cash_empty)
        end

        local first_cash = CreateObject(bank.first_cash.model, bank.first_cash.position, true, true)
        SetEntityRotation(first_cash, bank.first_cash.rotation)
        FreezeEntityPosition(first_cash, true)
        PlaceObjectOnGroundProperly(first_cash)
        Entities[#Entities+1] = first_cash
    end
    if bank.second_cash then RequestModel(bank.second_cash.model)
        while not HasModelLoaded(bank.second_cash.model) do Wait(100) end

        -- SECOND CASH LOCATION
        local old_second_cash = GetClosestObjectOfType(bank.second_cash.position, 1.0, bank.second_cash.model)
        if DoesEntityExist(old_second_cash) then
            NetworkRequestControlOfEntity(old_second_cash)
            while not NetworkHasControlOfEntity(old_second_cash) do Wait(10) end
            DeleteObject(old_second_cash)
        end

        local old_second_cash_empty = GetClosestObjectOfType(bank.second_cash.position, 1.0, GetHashKey("hei_prop_hei_cash_trolly_03"))
        if DoesEntityExist(old_second_cash_empty) then
            NetworkRequestControlOfEntity(old_second_cash_empty)
            while not NetworkHasControlOfEntity(old_second_cash_empty) do Wait(10) end
            DeleteObject(old_second_cash_empty)
        end

        local second_cash = CreateObject(bank.second_cash.model, bank.second_cash.position, true, true)
        SetEntityRotation(second_cash, bank.second_cash.rotation)
        FreezeEntityPosition(second_cash, true)
        PlaceObjectOnGroundProperly(second_cash)
        Entities[#Entities+1] = second_cash
    end 
    if bank.third_cash then RequestModel(bank.third_cash.model)
        while not HasModelLoaded(bank.third_cash.model) do Wait(100) end

        -- THIRD CASH LOCATION
        local old_third_cash = GetClosestObjectOfType(bank.third_cash.position, 1.0, bank.third_cash.model)
        if DoesEntityExist(old_third_cash) then
            NetworkRequestControlOfEntity(old_third_cash)
            while not NetworkHasControlOfEntity(old_third_cash) do Wait(10) end
            DeleteObject(old_third_cash)
        end

        local old_third_cash_empty = GetClosestObjectOfType(bank.third_cash.position, 1.0, GetHashKey("hei_prop_hei_cash_trolly_03"))
        if DoesEntityExist(old_third_cash_empty) then
            NetworkRequestControlOfEntity(old_third_cash_empty)
            while not NetworkHasControlOfEntity(old_third_cash_empty) do Wait(10) end
            DeleteObject(old_third_cash_empty)
        end

        local third_cash = CreateObject(bank.third_cash.model, bank.third_cash.position, true, true)
        SetEntityRotation(third_cash, bank.third_cash.rotation)
        FreezeEntityPosition(third_cash, true)
        PlaceObjectOnGroundProperly(third_cash)
        Entities[#Entities+1] = third_cash
    end
    if bank.door_hack then RequestModel(bank.door_hack.model)
        while not HasModelLoaded(bank.door_hack.model) do Wait(100) end

        -- DOOR HACK LOCATION
        local old_door_hack = GetClosestObjectOfType(bank.door_hack.position, 0.5, bank.door_hack.model)
        if DoesEntityExist(old_door_hack) then
            NetworkRequestControlOfEntity(old_door_hack)
            while not NetworkHasControlOfEntity(old_door_hack) do Wait(10) end
            DeleteObject(old_door_hack)
        end

        local door_hack = CreateObject(bank.door_hack.model, bank.door_hack.position, true, true)
        SetEntityRotation(door_hack, bank.door_hack.rotation)
        FreezeEntityPosition(door_hack, true)
        Entities[#Entities+1] = door_hack
    end
    if bank.door then RequestModel(bank.door.model)
        while not HasModelLoaded(bank.door.model) do Wait(100) end
    end



    TriggerServerEvent("Calsky_bankrobbery:LockDoor", bank.bank, true)
end

RegisterNetEvent("Calsky_bankrobbery:StartDoorHack", function(data)
    local entity = data.entity
    
    -- Play the animation but don't use its result
    AnimateHacking(entity)
    
    -- Always set success to true
    local success = true
    
    if success then
        TriggerServerEvent("Calsky_bankrobbery:LockDoor", bank.bank, false)
        lib.notify({
            title = localesEN["hack_door_name"],
            description = localesEN["door_hacked"],
            type = "success"
        })
    end
end)

RegisterNetEvent("Calsky_bankrobbery:LockDoor", function(bank_id, state)
    if state then
        DoorSystemSetDoorState(GetHashKey("bank_robbery_"..bank_id), 4, true, true)
        DoorSystemSetDoorState(GetHashKey("bank_robbery_"..bank_id), 1, true, true)
    else
        DoorSystemSetDoorState(GetHashKey("bank_robbery_"..bank_id), state)
    end
    if state then
        bank = BANKS[bank_id]
        bank.bank = bank_id
        if bank.first_cash then
            local first_cash = GetClosestObjectOfType(bank.first_cash.position, 1.0, bank.first_cash.model)
            while bank and not DoesEntityExist(first_cash) do Wait(100)
                first_cash = GetClosestObjectOfType(bank.first_cash.position, 1.0, bank.first_cash.model)
            end
            exports.ox_target:addLocalEntity(first_cash, {
                label = localesEN["grab_cash"],
                event = "Calsky_bankrobbery:GrabCash",
                icon = "fas fa-book-skull",
                distance = 1.5
            })
        end

        if bank.second_cash then
            local second_cash = GetClosestObjectOfType(bank.second_cash.position, 1.0, bank.second_cash.model)
            while bank and not DoesEntityExist(second_cash) do Wait(100)
                second_cash = GetClosestObjectOfType(bank.second_cash.position, 1.0, bank.second_cash.model)
            end
            exports.ox_target:addLocalEntity(second_cash, {
                label = localesEN["grab_cash"],
                event = "Calsky_bankrobbery:GrabCash",
                icon = "fas fa-book-skull",
                distance = 1.5
            })
        end


        if bank.third_cash then
            local third_cash = GetClosestObjectOfType(bank.third_cash.position, 1.0, bank.third_cash.model)
            while bank and not DoesEntityExist(third_cash) do Wait(100)
                third_cash = GetClosestObjectOfType(bank.third_cash.position, 1.0, bank.third_cash.model)
            end
            exports.ox_target:addLocalEntity(third_cash, {
                label = localesEN["grab_cash"],
                event = "Calsky_bankrobbery:GrabCash",
                icon = "fas fa-book-skull",
                distance = 1.5
            })
        end

        if bank.door_hack then
            local door_hack = GetClosestObjectOfType(bank.door_hack.position, 1.0, bank.door_hack.model)
            while bank and not DoesEntityExist(door_hack) do Wait(100)
                door_hack = GetClosestObjectOfType(bank.door_hack.position, 1.0, bank.door_hack.model)
            end
            exports.ox_target:addLocalEntity(door_hack, {
                label = localesEN["hack_vault"],
                event = "Calsky_bankrobbery:StartDoorHack",
                icon = "fas fa-book-skull",
                distance = 1.5
            })
        end
        
    end
end)

RegisterNetEvent("Calsky_bankrobbery:OpenVaultDoor", function(bank_id)
    for i = 1, 90, 0.2 do
        SetEntityRotation(bank_to_vault[bank_id], 0.0, 0.0, BANKS[bank_id].vault_door.reset_yaw-i)
        Wait(10)
    end
end)

RegisterNetEvent("Calsky_bankrobbery:CloseVaultDoor", function(bank_id)
    SetEntityRotation(bank_to_vault[bank_id], 0.0, 0.0, BANKS[bank_id].vault_door.reset_yaw)
    bank = nil
    bankRobberyInProgress = false  -- Reset when vault closes
end)


AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for index, value in ipairs(Entities) do
        DeleteEntity(value)
    end
end)


-- Add after your existing variables
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Existing vault hack text
        for bankName, bankData in pairs(BANKS) do
            if bankData.vault_hack then
                local panelPos = bankData.vault_hack.position
                local distance = #(playerCoords - panelPos)
                
                if distance < 2.0 then
                    DrawText3D(panelPos.x, panelPos.y, panelPos.z + 0.5, "Hold ~p~LEFT ALT~w~ to start vault hack!")
                end
            end
            
            -- Add cash grab text if robbery in progress
            if bankRobberyInProgress then
                if bankData.first_cash then
                    local cashPos = bankData.first_cash.position
                    local distance = #(playerCoords - cashPos)
                    if distance < 2.0 then
                        DrawText3D(cashPos.x, cashPos.y, cashPos.z + 1.5, "Hold ~p~LEFT ALT~w~ to grab cash!")
                    end
                end
                
                if bankData.second_cash then
                    local cashPos = bankData.second_cash.position
                    local distance = #(playerCoords - cashPos)
                    if distance < 2.0 then
                        DrawText3D(cashPos.x, cashPos.y, cashPos.z + 1.5, "Hold ~p~LEFT ALT~w~ to grab cash!")
                    end
                end
                
                if bankData.third_cash then
                    local cashPos = bankData.third_cash.position
                    local distance = #(playerCoords - cashPos)
                    if distance < 2.0 then
                        DrawText3D(cashPos.x, cashPos.y, cashPos.z + 1.5, "Hold ~p~LEFT ALT~w~ to grab cash!")
                    end
                end
            end
        end
    end
end)
