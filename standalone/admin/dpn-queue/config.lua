Config = {}

-- =============================
-- DPN QUEUE CORE SETTINGS
-- =============================
Config.Debug = false

-- Uses your server.cfg sv_maxclients value by default.
Config.MaxClientsConvar = 'sv_maxclients'

-- 13 reserved admin slots by default. Change this anytime.
-- Example: sv_maxclients 48 + ReservedAdminSlots 13 = 35 public slots and 13 admin-only slots.
Config.ReservedAdminSlots = 13

-- Require at least one license/steam/fivem/discord identifier to enter the queue.
Config.RequireIdentifier = true

-- If true, a newer connection from the same identifier replaces the older queued attempt.
Config.ReplaceDuplicateQueueConnection = true

-- =============================
-- ADMIN / RESERVED SLOT ACCESS
-- =============================
Config.Admin = {
    Enabled = true,

    -- Recommended method: ACE permission.
    -- server.cfg example:
    -- add_ace group.admin dpn.queue.admin allow
    -- add_principal identifier.license:YOUR_LICENSE_HERE group.admin
    AcePermissions = {
        'dpn.queue.admin'
    },

    -- Optional fallback identifiers for admins/owners.
    -- Use exact FiveM identifiers, examples:
    -- 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    -- 'discord:123456789012345678',
    -- 'steam:110000100000000'
    Identifiers = {
        -- 'license:PUT_OWNER_LICENSE_HERE'
    }
}

-- ACE required for /dpnqueue command when used in-game.
Config.ManageAce = 'dpn.queue.manage'

-- =============================
-- PRIORITY SETTINGS
-- =============================
Config.Priority = {
    Default = 0,
    Admin = 1000,
    ReconnectGrace = 300,

    -- Optional custom priority by identifier.
    -- Higher number = closer to front of queue.
    IdentifierBoosts = {
        -- ['license:PUT_OWNER_LICENSE_HERE'] = { points = 5000, label = 'Owner' },
        -- ['discord:123456789012345678'] = { points = 2500, label = 'VIP' }
    }
}

-- =============================
-- QUEUE TIMING / PROTECTION
-- =============================
Config.Queue = {
    UpdateIntervalSeconds = 5,
    ConnectionHoldTimeoutSeconds = 900, -- 15 minutes before a queued connection is timed out.
    AdmitReserveSeconds = 45,           -- Temporarily reserves a slot while the player is loading.
    ReconnectGraceSeconds = 180,        -- Recently disconnected players get reconnect priority.

    -- Anti-spam connection protection.
    AntiSpamEnabled = true,
    AntiSpamWindowSeconds = 60,
    AntiSpamMaxAttempts = 8
}

-- =============================
-- MESSAGES
-- =============================
Config.Brand = 'DPN Technology Queue'

Config.Messages = {
    Checking = 'Checking your queue status...',
    MissingIdentifier = 'Connection refused: no valid FiveM identifiers were found. Restart FiveM/Steam and try again.',
    TooManyAttempts = 'You are connecting too fast. Wait a minute and try again.',
    DuplicateReplaced = 'A newer connection attempt from your account replaced this queue session.',
    QueueTimeout = 'Your queue session timed out. Please reconnect.',
    Admitting = 'Slot found. Loading you into the server...',

    QueueFormat = '%s\nPosition: %d/%d\nPlayers: %d/%d\nPublic slots: %d | Reserved admin slots: %d\nPriority: %s\nPlease keep FiveM open while you wait.'
}
