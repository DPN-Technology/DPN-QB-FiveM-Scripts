DPNStarChaseDB = {}

local DEFAULT_TABLE_NAME = 'dpn_starchase_logs'
local DEFAULT_DATABASE_RESOURCE = 'oxmysql'

local function dbEnabled()
    return Config.Database
        and Config.Database.enabled
        and GetResourceState(Config.Database.resource or DEFAULT_DATABASE_RESOURCE) == 'started'
end

local function ident(value, fallback)
    fallback = tostring(fallback or DEFAULT_TABLE_NAME)
    value = tostring(value or '')

    if value == '' or #value > 64 or not value:match('^[%w_]+$') then
        return fallback, false
    end

    return value, true
end

local resolvedTableName, configuredTableNameValid = ident(
    Config.Database and Config.Database.tableName,
    DEFAULT_TABLE_NAME
)

if Config.Database and Config.Database.tableName and not configuredTableNameValid then
    print(('^3[dpn-starchase]^7 Invalid database table identifier %q; using %s instead.'):format(
        tostring(Config.Database.tableName):sub(1, 96),
        DEFAULT_TABLE_NAME
    ))
end

local function tableName()
    return resolvedTableName
end

local function databaseResource()
    return (Config.Database and Config.Database.resource) or DEFAULT_DATABASE_RESOURCE
end

function DPNStarChaseDB.Init()
    if not Config.Database or not Config.Database.enabled then return end
    if not dbEnabled() then
        print('^3[dpn-starchase]^7 oxmysql is not started. Database logging disabled for this session.')
        return
    end
    if not Config.Database.autoCreate then return end

    local query = ([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `tracker_id` VARCHAR(64) DEFAULT NULL,
            `action` VARCHAR(40) NOT NULL,
            `source` INT DEFAULT NULL,
            `citizenid` VARCHAR(80) DEFAULT NULL,
            `officer_name` VARCHAR(120) DEFAULT NULL,
            `job` VARCHAR(80) DEFAULT NULL,
            `plate` VARCHAR(16) DEFAULT NULL,
            `target_net_id` INT DEFAULT NULL,
            `coords` LONGTEXT DEFAULT NULL,
            `extra` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            INDEX `tracker_id` (`tracker_id`),
            INDEX `action` (`action`),
            INDEX `plate` (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]):format(tableName())

    exports[databaseResource()]:execute(query, {}, function()
        print('^2[dpn-starchase]^7 Database table checked/created.')
    end)
end

function DPNStarChaseDB.Log(action, src, tracker, extra)
    if not dbEnabled() then return end

    local Player = src and QBCore and QBCore.Functions.GetPlayer(src) or nil
    local citizenid, officerName, job = nil, nil, nil

    if Player and Player.PlayerData then
        citizenid = Player.PlayerData.citizenid
        local ci = Player.PlayerData.charinfo or {}
        officerName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
        job = Player.PlayerData.job and Player.PlayerData.job.name or nil
    end

    local coords = tracker and tracker.coords and json.encode(tracker.coords) or nil
    local payload = {
        tracker_id = tracker and tracker.id or nil,
        action = action,
        source = src,
        citizenid = citizenid,
        officer_name = officerName,
        job = job,
        plate = tracker and tracker.plate or nil,
        target_net_id = tracker and tracker.netId or nil,
        coords = coords,
        extra = extra and json.encode(extra) or nil
    }

    exports[databaseResource()]:insert(([[
        INSERT INTO `%s`
        (`tracker_id`, `action`, `source`, `citizenid`, `officer_name`, `job`, `plate`, `target_net_id`, `coords`, `extra`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]):format(tableName()), {
        payload.tracker_id,
        payload.action,
        payload.source,
        payload.citizenid,
        payload.officer_name,
        payload.job,
        payload.plate,
        payload.target_net_id,
        payload.coords,
        payload.extra
    })
end
