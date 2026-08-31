Config = {}

Config.Framework = 'qbcore' -- QBCore-only release
Config.OpenCommand = 'academy'
Config.OpenKey = 'F2'
Config.Debug = false
Config.RequireDuty = true

Config.AllowedJobs = {
    police = true,
    sheriff = true,
    state = true,
    trooper = true,
    ranger = true,
    corrections = true,
    ambulance = true,
    ems = true,
    fire = true
}

Config.InstructorGrades = {
    [4] = true,
    [5] = true,
    [6] = true,
    [7] = true,
    [8] = true,
    [9] = true,
    [10] = true
}

Config.AceInstructor = 'dpn.academy.instructor'
Config.AceAdmin = 'dpn.academy.admin'

Config.Webhook = ''

Config.DefaultCertExpiryDays = 90
Config.MinimumCourseSeconds = 15

Config.Certifications = {
    firearms_basic = { label = 'Basic Firearms Qualification', minScore = 80, expiresDays = 90 },
    firearms_advanced = { label = 'Advanced Firearms Qualification', minScore = 88, expiresDays = 90 },
    evoc_basic = { label = 'Basic EVOC', minScore = 80, expiresDays = 120 },
    evoc_pursuit = { label = 'Pursuit EVOC', minScore = 85, expiresDays = 120 },
    drone_operator = { label = 'Drone Operator', minScore = 80, expiresDays = 180 },
    incident_command = { label = 'Incident Command', minScore = 85, expiresDays = 180 },
    evidence_handling = { label = 'Evidence Handling', minScore = 80, expiresDays = 180 },
    field_training = { label = 'Field Training Officer', minScore = 90, expiresDays = 365 }
}

Config.Courses = {
    firearms_basic = {
        label = 'Firearms Basic Range',
        type = 'firearms',
        cert = 'firearms_basic',
        location = vector3(821.2, -2163.4, 29.6),
        maxTimeSeconds = 180,
        targets = 20
    },
    evoc_basic = {
        label = 'EVOC Basic Driving',
        type = 'driving',
        cert = 'evoc_basic',
        location = vector3(215.7, -1398.4, 30.6),
        maxTimeSeconds = 300,
        checkpoints = 12
    },
    firearms_advanced = {
        label = 'Advanced Firearms Qualification',
        type = 'firearms',
        cert = 'firearms_advanced',
        location = vector3(821.2, -2163.4, 29.6),
        maxTimeSeconds = 210,
        targets = 30
    },
    evoc_pursuit = {
        label = 'Pursuit EVOC Qualification',
        type = 'driving',
        cert = 'evoc_pursuit',
        location = vector3(215.7, -1398.4, 30.6),
        maxTimeSeconds = 360,
        checkpoints = 16
    },
    drone_operator = {
        label = 'Drone Operator Practical',
        type = 'scenario',
        cert = 'drone_operator',
        location = vector3(449.0, -981.2, 30.7),
        maxTimeSeconds = 420
    },
    incident_command = {
        label = 'Incident Command Qualification',
        type = 'scenario',
        cert = 'incident_command',
        location = vector3(441.2, -982.0, 30.7),
        maxTimeSeconds = 600
    },
    evidence_handling = {
        label = 'Evidence Handling Qualification',
        type = 'scenario',
        cert = 'evidence_handling',
        location = vector3(474.7, -996.8, 26.3),
        maxTimeSeconds = 420
    },
    field_training = {
        label = 'Field Training Officer Qualification',
        type = 'scenario',
        cert = 'field_training',
        location = vector3(428.2, -984.2, 30.7),
        maxTimeSeconds = 720
    }
}

Config.ScenarioPresets = {
    traffic_stop = { label = 'High Risk Traffic Stop', units = 2, difficulty = 'medium' },
    active_shooter = { label = 'Active Shooter Response', units = 4, difficulty = 'hard' },
    domestic = { label = 'Domestic Disturbance', units = 2, difficulty = 'medium' },
    barricaded = { label = 'Barricaded Subject', units = 5, difficulty = 'hard' },
    medical = { label = 'Medical Emergency Response', units = 2, difficulty = 'easy' }
}
