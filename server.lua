if GetResourceState('rsg-core') == 'started' then
    local RSGCore = exports['rsg-core']:GetCoreObject()

   
    local function IsPlayerAdmin(src)
        return IsPlayerAceAllowed(src, "admin")
    end

    
    MySQL.ready(function()
        MySQL.execute([[
            CREATE TABLE IF NOT EXISTS job_applications (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                job VARCHAR(50) NOT NULL,
                grade INT NOT NULL,
                reason VARCHAR(200) NOT NULL,
                status ENUM('pending', 'approved', 'denied') DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]], {})
    end)

    
    local function SendApplicationToDiscord(title, player, job, grade, reason, color)
        if not Config.EnableWebHook or not Config.WHLink or Config.WHLink == "" then return end

        local embed = {{
            title = title or "Job Application",
            type = "rich",
            color = color or 5814783,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            fields = {
                {
                    name = "Applicant",
                    value = string.format("%s %s (%s)", player.firstname or "N/A", player.lastname or "N/A", player.citizenid or "N/A"),
                    inline = true
                },
                {
                    name = "Requested Job",
                    value = job and (job .. " (Grade " .. grade .. ")") or "N/A",
                    inline = true
                },
                {
                    name = "Reason",
                    value = reason or "N/A",
                    inline = false
                }
            },
            thumbnail = { url = Config.WHLogo or "https://i.imgur.com/youricon.png" }
        }}

        PerformHttpRequest(Config.WHLink, function() end, 'POST', json.encode({
            username = Config.WHName or "Job Applications",
            embeds = embed
        }), { ['Content-Type'] = 'application/json' })
    end

    
    RegisterServerEvent('rsg_job_application:submitApplication')
    AddEventHandler('rsg_job_application:submitApplication', function(job, grade, reason)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end

       
        local isValid = false
        for _, j in pairs(Config.AvailableJobs) do
            if j.job == job and j.grade == grade then
                isValid = true
                break
            end
        end

        if not isValid then
            return TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Invalid job or grade.', type = 'error' })
        end

        if type(reason) ~= 'string' or reason:len() < 10 or reason:len() > 200 then
            return TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Reason must be 10-200 characters.', type = 'error' })
        end

        local citizenid = Player.PlayerData.citizenid
        local firstname = Player.PlayerData.charinfo.firstname
        local lastname = Player.PlayerData.charinfo.lastname

        MySQL.insert('INSERT INTO job_applications (citizenid, job, grade, reason) VALUES (?, ?, ?, ?)', {
            citizenid, job, grade, reason
        }, function(id)
            if id then
                SendApplicationToDiscord("New Job Application", { citizenid = citizenid, firstname = firstname, lastname = lastname }, job, grade, reason, Config.WHColor)
                TriggerClientEvent('ox_lib:notify', src, { title = 'Application Submitted', description = 'Your application for ' .. job .. ' has been submitted.', type = 'success' })
            else
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Failed to submit application.', type = 'error' })
            end
        end)
    end)

    
    RegisterServerEvent('rsg_job_application:getApplications')
    AddEventHandler('rsg_job_application:getApplications', function()
        local src = source
        if not IsPlayerAdmin(src) then
            return TriggerClientEvent('ox_lib:notify', src, { title = 'Unauthorized', description = 'Not authorized.', type = 'error' })
        end

        MySQL.query('SELECT * FROM job_applications WHERE status = "pending"', {}, function(apps)
            TriggerClientEvent('rsg_job_application:openAdminMenu', src, apps or {})
        end)
    end)

    
    RegisterServerEvent('rsg_job_application:approveApplication')
    AddEventHandler('rsg_job_application:approveApplication', function(appId, citizenid, job, grade)
        local src = source
        if not IsPlayerAdmin(src) then
            return TriggerClientEvent('ox_lib:notify', src, { title = 'Unauthorized', description = 'Not authorized.', type = 'error' })
        end

        MySQL.update('UPDATE job_applications SET status = "approved" WHERE id = ?', { appId }, function(affectedRows)
            if affectedRows > 0 then
                local target = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
                if target then
                    local firstname = target.PlayerData.charinfo.firstname
                    local lastname = target.PlayerData.charinfo.lastname
                    target.Functions.SetJob(job, grade)
                    TriggerClientEvent('ox_lib:notify', target.PlayerData.source, {
                        title = 'Job Approved',
                        description = 'You are now working as ' .. job .. ' (Grade ' .. grade .. ').',
                        type = 'success'
                    })
                    SendApplicationToDiscord("Application Approved", { citizenid = citizenid, firstname = firstname, lastname = lastname }, job, grade, "Application Approved", 65280)
                else
                   
                    MySQL.query('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid }, function(result)
                        if result and result[1] then
                            local charinfo = json.decode(result[1].charinfo)
                            SendApplicationToDiscord("Application Approved", {
                                citizenid = citizenid,
                                firstname = charinfo.firstname,
                                lastname = charinfo.lastname
                            }, job, grade, "Application Approved", 65280)
                            MySQL.update('UPDATE players SET job = ?, jobgrade = ? WHERE citizenid = ?', { job, grade, citizenid })
                        end
                    end)
                end
                TriggerClientEvent('ox_lib:notify', src, { title = 'Approved', description = 'Application approved.', type = 'success' })
            else
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Could not approve application.', type = 'error' })
            end
        end)
    end)

    
    RegisterServerEvent('rsg_job_application:denyApplication')
    AddEventHandler('rsg_job_application:denyApplication', function(appId, citizenid)
        local src = source
        if not IsPlayerAdmin(src) then
            return TriggerClientEvent('ox_lib:notify', src, { title = 'Unauthorized', description = 'Not authorized.', type = 'error' })
        end

        MySQL.update('UPDATE job_applications SET status = "denied" WHERE id = ?', { appId }, function(affectedRows)
            if affectedRows > 0 then
                local target = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
                if target then
                    local firstname = target.PlayerData.charinfo.firstname
                    local lastname = target.PlayerData.charinfo.lastname
                    TriggerClientEvent('ox_lib:notify', target.PlayerData.source, {
                        title = 'Application Denied',
                        description = 'Your job application has been denied.',
                        type = 'error'
                    })
                    SendApplicationToDiscord("Application Denied", {
                        citizenid = citizenid,
                        firstname = firstname,
                        lastname = lastname
                    }, "N/A", "N/A", "Application Denied", 16711680)
                else
                   
                    MySQL.query('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid }, function(result)
                        if result and result[1] then
                            local charinfo = json.decode(result[1].charinfo)
                            SendApplicationToDiscord("Application Denied", {
                                citizenid = citizenid,
                                firstname = charinfo.firstname,
                                lastname = charinfo.lastname
                            }, "N/A", "N/A", "Application Denied", 16711680)
                        end
                    end)
                end
                TriggerClientEvent('ox_lib:notify', src, { title = 'Denied', description = 'Application denied.', type = 'success' })
            else
                TriggerClientEvent('ox_lib:notify', src, { title = 'Error', description = 'Could not deny application.', type = 'error' })
            end
        end)
    end)
end