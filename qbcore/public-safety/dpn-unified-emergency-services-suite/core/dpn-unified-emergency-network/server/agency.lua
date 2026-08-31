-- Agency helpers are intentionally thin. The main support request handler lives in server/incidents.lua
-- so every support request updates the incident history, SQL record, and UI consistently.

DPN_UNES.Server.ValidAgency = function(agency)
    local valid = { law=true, ems=true, fire=true, justice=true, corrections=true, bail=true, admin=true }
    return valid[agency] == true
end
