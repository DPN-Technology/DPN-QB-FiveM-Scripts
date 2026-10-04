Config = {}
Config.Debug = false
Config.Command = 'crimeintel'
Config.OpenKey = 'F12'
Config.RequireDuty = true
Config.MaxSearchResults = 25
Config.MaxReportLength = 6000
Config.MaxTitleLength = 160

-- Server-side abuse resistance for network-facing intelligence actions.
-- Source 0/server-side integrations are not throttled.
Config.RateLimits = {
    OpenMs = 500,
    SearchMs = 900,
    MutationMs = 650,
    AlertMs = 1000
}
Config.DispatchResource = 'dpn-digital-dispatch'
Config.AllowedJobs = { police=true, sheriff=true, state=true, trooper=true, ranger=true, corrections=true }
Config.SupervisorGrades = { police=4, sheriff=4, state=4, trooper=4, ranger=4, corrections=4 }
Config.RiskWeights = { booking=18, citation=3, watchlist=35, activeBolo=30, linkedReport=5, activeWarrant=40, criticalWarrant=20 }
Config.RiskLevels = {
    { minimum=75, label='Critical', color='#ff415e' },
    { minimum=45, label='High', color='#ff9638' },
    { minimum=20, label='Elevated', color='#ffd24a' },
    { minimum=0, label='Routine', color='#55d99a' }
}
