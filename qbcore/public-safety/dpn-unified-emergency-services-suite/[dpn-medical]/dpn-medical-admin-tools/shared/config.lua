Config = Config or {}

Config.Command = 'medadmin'
Config.Alias = 'dpnmedadmin'
Config.CloseCommand = 'medadminclose'
Config.RefreshCommand = 'medadminrefresh'
Config.DiagnosticCommand = 'medadmindiag'
Config.ConsoleOpenCommand = 'medadminforce'
Config.ConsoleActionCommand = 'medadminexec'
Config.EnableKeybind = true
Config.EnableMouse = true
Config.MouseWheelNavigation = true
Config.MouseCursorSprite = 1
Config.DefaultKeybind = 'F10'
Config.Debug = true
Config.NotifyActionSuccess = true
Config.ActionCooldownMs = 650
Config.TestLabCooldownMs = 900
Config.RefreshCooldownMs = 750
Config.AuditLimit = 60

Config.Hospital = {
    resource = 'dpn-medical-hospital',
    defaultHospital = 'pillbox',
    erMinutes = 15,
    icuMinutes = 30
}

Config.AllowEveryone = false
Config.QBCorePermissions = { 'god', 'admin', 'superadmin' }
Config.AcePermissions = {
    'dpn.medical.admin',
    'command.medadmin',
    'qbcore.god',
    'qbcore.admin'
}
Config.AllowedCitizenIds = {}
Config.AllowedLicenses = {}

Config.RequiredModules = {
    'dpn-medical-core', 'dpn-medical-ems', 'dpn-medical-hospital',
    'dpn-medical-surgery', 'dpn-medical-radiology', 'dpn-medical-pharmacy',
    'dpn-medical-records', 'dpn-medical-coroner', 'dpn-medical-insurance',
    'dpn-medical-training', 'dpn-medical-disease', 'dpn-medical-ambulance',
    'dpn-medical-ai', 'dpn-medical-dispatch', 'dpn-medical-icu',
    'dpn-medical-rehab', 'dpn-medical-lifepak', 'dpn-medical-inventory',
    'dpn-medical-billing-plus', 'dpn-medical-admin-tools'
}
