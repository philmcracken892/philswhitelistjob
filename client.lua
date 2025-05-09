
local isAdmin = false


local playerPrompt = nil
RegisterNetEvent('rsg_job_application:setIsAdmin', function(adminStatus)
    isAdmin = adminStatus
end)

Citizen.CreateThread(function()
    TriggerServerEvent('rsg_job_application:checkIsAdmin')
    local prompts = {}

    for _, loc in ipairs(Config.Locations) do
        
        if loc.showBlip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, loc.blipData.sprite, true)
            SetBlipScale(blip, loc.blipData.scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, loc.blipData.name)
            Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey("BLIP_MODIFIER_MP_COLOR_" .. tostring(loc.blipData.color)))
            Citizen.InvokeNative(0x9029B2F3DA924928, blip, true)
        end

       
        local prompt = PromptRegisterBegin()
        PromptSetControlAction(prompt, loc.promptKey)
        PromptSetText(prompt, Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", loc.promptText, Citizen.ResultAsLong()))
        PromptSetEnabled(prompt, false)
        PromptSetVisible(prompt, false)
        PromptSetStandardMode(prompt, true)
        PromptRegisterEnd(prompt)
        table.insert(prompts, { data = loc, prompt = prompt })
    end

    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)

        for _, entry in ipairs(prompts) do
            local loc = entry.data
            if loc.isAdminOnly and not isAdmin then goto continue end

            local dist = #(coords - loc.coords)
            if dist <= Config.InteractionDistance then
                PromptSetEnabled(entry.prompt, true)
                PromptSetVisible(entry.prompt, true)

                if PromptHasStandardModeCompleted(entry.prompt) or IsControlJustPressed(0, loc.promptKey) then
                    loc.onInteract()
                    Citizen.Wait(500)
                end
            else
                PromptSetEnabled(entry.prompt, false)
                PromptSetVisible(entry.prompt, false)
            end

            ::continue::
        end
    end
end)



function OpenJobApplicationMenu()
    
    local options = {}

   
    for _, job in ipairs(Config.AvailableJobs) do
        table.insert(options, {
            title = 'Apply for ' .. job.label,
            description = 'Submit an application for the ' .. job.label .. ' position.',
            onSelect = function()
              
                local input = lib.inputDialog('Job Application - ' .. job.label, {
                    {
                        type = 'input',
                        label = 'Reason for Application',
                        description = 'Why do you want this job? (max 200 characters)',
                        required = true,
                        min = 10,
                        max = 200
                    }
                })
                if input and input[1] then
                   
                    TriggerServerEvent('rsg_job_application:submitApplication', job.job, job.grade, input[1])
                else
                    lib.notify({
                        title = 'Application Cancelled',
                        description = 'You must provide a reason to apply.',
                        type = 'error'
                    })
                    
                end
            end
        })
    end

    
    table.insert(options, {
        title = 'Manage Applications',
        description = 'View and manage pending job applications.',
        onSelect = function()
            print('Requesting pending applications')
            TriggerServerEvent('rsg_job_application:getApplications')
        end
    })

    lib.registerContext({
        id = 'job_application_menu',
        title = 'Job Application Center',
        options = options
    })
    lib.showContext('job_application_menu')
   
end


RegisterNetEvent('rsg_job_application:openAdminMenu')
AddEventHandler('rsg_job_application:openAdminMenu', function(applications)
   
    OpenAdminApplicationMenu(applications)
end)


function OpenAdminApplicationMenu(applications)
  
    if not applications or type(applications) ~= 'table' then
        lib.notify({
            title = 'Error',
            description = 'Invalid application data received.',
            type = 'error'
        })
       
        return
    end

    if #applications == 0 then
        lib.notify({
            title = 'No Applications',
            description = 'There are no pending job applications.',
            type = 'inform'
        })
        
        return
    end

    local options = {}
    for i, app in ipairs(applications) do
        
        if app.id and app.citizenid and app.job and app.grade and app.reason then
            table.insert(options, {
                title = 'Application #' .. app.id .. ' - ' .. app.job,
                description = 'CitizenID: ' .. app.citizenid .. ' | Job: ' .. app.job .. ' | Grade: ' .. app.grade .. ' | Reason: ' .. app.reason,
                menu = 'application_actions_' .. app.id
            })
        else
           
        end
    end

    if #options == 0 then
        lib.notify({
            title = 'No Valid Applications',
            description = 'No valid pending applications found.',
            type = 'inform'
        })
       
        return
    end

   
    local success, err = pcall(function()
        lib.registerContext({
            id = 'admin_job_applications',
            title = 'Pending Job Applications',
            options = options
        })
        lib.showContext('admin_job_applications')
    end)

    if not success then
        
        lib.notify({
            title = 'Error',
            description = 'Failed to display application menu.',
            type = 'error'
        })
        return
    end
    

    for _, app in ipairs(applications) do
        if app.id then
            
            lib.registerContext({
                id = 'application_actions_' .. app.id,
                title = 'Manage Application #' .. app.id,
                options = {
                    {
                        title = 'Approve Application',
                        description = 'Assign ' .. app.job .. ' (Grade ' .. app.grade .. ') to CitizenID: ' .. app.citizenid,
                        onSelect = function()
                            print('Approving application ID: ' .. app.id)
                            TriggerServerEvent('rsg_job_application:approveApplication', app.id, app.citizenid, app.job, app.grade)
                        end
                    },
                    {
                        title = 'Deny Application',
                        description = 'Reject the application.',
                        onSelect = function()
                            print('Denying application ID: ' .. app.id)
                            TriggerServerEvent('rsg_job_application:denyApplication', app.id, app.citizenid)
                        end
                    }
                }
            })
        end
    end
end