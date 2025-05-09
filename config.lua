Config = {
    InteractionDistance = 2.0,

    EnableWebHook = true,
    WHTitle = "New Job Application",
    WHColor = 5814783,
    WHName = "Job Applications",
    WHLink = "webhook here ",
    WHLogo = "logo here",

    AvailableJobs = {
        { job = 'vallaw', label = 'Valentine Deputy', grade = 0 },
        { job = 'blklaw', label = 'blacklaw', grade = 0 },
        { job = 'stdenlaw', label = 'stdenlaw', grade = 0 },
        { job = 'rholaw', label = 'rhodeslaw', grade = 0 },
        { job = 'strlaw', label = 'strawberrylaw', grade = 0 },
        { job = 'traindriver', label = 'Traindriver', grade = 0 },
        { job = 'bountyhunter', label = 'bountyhunter', grade = 0 },
        { job = 'medic', label = 'medic', grade = 0 },
    },

    Locations = {
        {
            name = "Job Application Center",
            coords = vector3(-234.93, 748.07, 117.75),
            promptText = 'Open Job Application Menu',
            promptKey = 0xF3830D8E,
            showBlip = true,
            blipData = {
                sprite = GetHashKey("blip_ambient_newspaper"),
                scale = 0.8,
                color = 4,
                name = 'Job Application Center'
            },
            onInteract = function()
                OpenJobApplicationMenu()
            end
        },
        {
            name = "Job Application Center",
            coords = vector3(-234.93, 748.07, 117.75),
            promptText = 'Open Admin Application Menu',
            promptKey = 0xF3830D8E,
            showBlip = true,
            blipData = {
                sprite = GetHashKey("blip_ambient_newspaper"),
                scale = 0.8,
                color = 4,
                name = 'Admin Application Center'
            },
            onInteract = function()
                TriggerServerEvent('rsg_job_application:getApplications')
            end,
            isAdminOnly = true
        }
    }
}
