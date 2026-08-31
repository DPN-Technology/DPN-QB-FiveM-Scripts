DPN_UNES = DPN_UNES or {}
DPN_UNES.Config = {
    Command = 'unes',
    PanicCommand = 'panic',
    UnitRefreshMs = 10000,
    ClientLocationRefreshMs = 3500,
    StaleUnitSeconds = 75,
    EnableAuditLogs = true,
    EnableBOLO = true,
    EnableMutualAid = true,
    EnableSceneCommand = true,
    EnableHospitalRouting = true,
    EnableTowRouting = true,
    EnableCourtCorrectionsRouting = true,
    RequireDispatcherForCommandOverride = true,
    Jobs = {
        police = { type = 'law', label = 'Law Enforcement', dispatch = true, command = true },
        sheriff = { type = 'law', label = 'Sheriff Office', dispatch = true, command = true },
        ambulance = { type = 'ems', label = 'Emergency Medical Services', dispatch = true, command = true },
        fire = { type = 'fire', label = 'Fire Rescue', dispatch = true, command = true },
        doj = { type = 'justice', label = 'Department of Justice', dispatch = true, command = false },
        judge = { type = 'justice', label = 'Courts', dispatch = true, command = false },
        corrections = { type = 'corrections', label = 'Corrections', dispatch = true, command = true },
        bailbonds = { type = 'bail', label = 'Bail Bonds', dispatch = false, command = false },
        mechanic = { type = 'tow', label = 'Tow / Mechanic', dispatch = false, command = false },
        admin = { type = 'admin', label = 'MIB Administration', dispatch = true, command = true }
    },
    AgencyColors = {
        law = '#0b3d91', ems = '#ff7a00', fire = '#b5121b', justice = '#7c8794', corrections = '#7a4b24', bail = '#af8f31', tow = '#215b3d', admin = '#111111', civilian = '#888888'
    },
    IncidentTypes = {
        traffic_stop = { label = 'Traffic Stop', priority = 3, agencies = {'law'} },
        pursuit = { label = 'Vehicle Pursuit', priority = 1, agencies = {'law'}, escalation = {'ems','fire'} },
        shots_fired = { label = 'Shots Fired', priority = 1, agencies = {'law','ems'} },
        structure_fire = { label = 'Structure Fire', priority = 1, agencies = {'fire','ems','law'} },
        vehicle_fire = { label = 'Vehicle Fire', priority = 2, agencies = {'fire','law'} },
        medical = { label = 'Medical Emergency', priority = 2, agencies = {'ems'} },
        trauma = { label = 'Trauma Alert', priority = 1, agencies = {'ems','fire','law'} },
        warrant = { label = 'Warrant Service', priority = 2, agencies = {'law','justice','corrections'} },
        transport = { label = 'Prisoner Transport', priority = 3, agencies = {'law','corrections'} },
        court = { label = 'Court Required', priority = 4, agencies = {'justice','law'} },
        panic = { label = 'Responder Panic', priority = 1, agencies = {'law','ems','fire'} },
        disaster = { label = 'Disaster / MCI', priority = 1, agencies = {'law','ems','fire','justice','corrections','admin'} },
        custom = { label = 'Custom Incident', priority = 3, agencies = {'law'} }
    },
    UnitStatuses = {'available','busy','enroute','onscene','transporting','at_hospital','at_station','offradio','out_of_service'},
    Roles = {
        dispatcherGrades = {0,1,2,3,4,5,6,7,8,9,10},
        commandGrades = {4,5,6,7,8,9,10},
        adminAgencies = { admin = true }
    },

    LiveMap = {
        Provider = 'oulsen_satmap',
        -- oulsen_satmap streams GTA minimap .ytd textures. NUI cannot read .ytd directly, so this UI uses an exported/static image.
        -- Put your exported Oulsen satmap PNG/JPG at html/img/oulsen_satmap.png or change ImageUrl below.
        ImageUrl = 'img/oulsen_satmap.png',
        FallbackImageUrl = '',
        ShowDebug = true,
        WorldBounds = { minX = -4000.0, maxX = 4500.0, minY = -4500.0, maxY = 8500.0 },
        ForceGpsOnOpen = true,
        RefreshSeconds = 5
    },
    Routing = {
        hospitals = {
            { name = 'Pillbox Medical Center', x = 307.0, y = -1433.0, z = 29.8 },
            { name = 'Sandy Shores Medical', x = 1839.0, y = 3672.0, z = 34.3 },
            { name = 'Paleto Medical', x = -247.0, y = 6331.0, z = 32.4 }
        },
        stations = {
            law = {{name='Mission Row PD', x=441.2,y=-981.9,z=30.7}},
            fire = {{name='Fire Station 7', x=215.7,y=-1642.5,z=29.7}},
            ems = {{name='Pillbox EMS Bay', x=307.0,y=-1433.0,z=29.8}},
            corrections = {{name='Bolingbroke Penitentiary', x=1845.0,y=2585.0,z=45.7}}
        }
    }
}
