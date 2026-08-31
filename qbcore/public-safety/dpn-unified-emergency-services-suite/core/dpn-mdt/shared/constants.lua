DPN_MDT = DPN_MDT or {}

DPN_MDT.ResourceName = GetCurrentResourceName()

DPN_MDT.Modules = {
    dashboard = 'Dashboard',
    dispatch = 'Dispatch',
    citizens = 'Citizens',
    vehicles = 'Vehicles',
    reports = 'Reports',
    cases = 'Cases',
    warrants = 'Warrants',
    bolos = 'BOLOs',
    evidence = 'Evidence',
    weapons = 'Weapons',
    roster = 'Roster',
    charges = 'Penal Code',
    courts = 'Courts',
    ems = 'EMS Medical',
    fire = 'Fire/Rescue',
    mib = 'MIB/Admin',
    corrections = 'Corrections',
    audit = 'Audit Trail'
}

DPN_MDT.ValidStatuses = {
    dispatch = { 'new', 'assigned', 'enroute', 'onscene', 'cleared', 'cancelled' },
    records = { 'open', 'active', 'pending', 'closed', 'archived' },
    priority = { 'low', 'normal', 'high', 'critical' }
}
