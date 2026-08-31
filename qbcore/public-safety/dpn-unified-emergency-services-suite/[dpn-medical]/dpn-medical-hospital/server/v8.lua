local VERSION='8.0.0'
local codeEvents, flowForecasts, infectionRooms = {}, {}, {}
local function uid(prefix) return ('%s-%s-%04d'):format(prefix,os.time(),math.random(0,9999)) end
exports('CreateHospitalFlowForecast',function(data)
    data=type(data)=='table'and data or{};local arrivals=tonumber(data.expectedArrivals)or 0;local discharges=tonumber(data.expectedDischarges)or 0;local beds=tonumber(data.availableBeds)or 0;local forecast={id=uid('FLOW'),windowMinutes=tonumber(data.windowMinutes)or 60,netDemand=arrivals-discharges,projectedBeds=beds-arrivals+discharges,surgeRequired=(beds-arrivals+discharges)<0,createdAt=os.time()};flowForecasts[forecast.id]=forecast;return forecast
end)
exports('ActivateHospitalCode',function(code,target,location,actor)
    local item={id=uid('CODE'),code=tostring(code or'code_blue'),target=tonumber(target),location=location or'unknown',actor=actor,status='active',createdAt=os.time(),team={}};codeEvents[item.id]=item;TriggerEvent('dpn-medical:hospital:codeActivated',item);return item.id,item
end)
exports('UpdateHospitalCode',function(id,status,teamMember) local item=codeEvents[tostring(id)];if not item then return false end;item.status=status or item.status;if teamMember then item.team[#item.team+1]=teamMember end;item.updatedAt=os.time();return true,item end)
exports('AssignIsolationRoom',function(target,room,precautions,actor) local item={target=tonumber(target),room=room,precautions=precautions or{'standard'},actor=actor,assignedAt=os.time(),active=true};infectionRooms[tostring(target)]=item;return true,item end)
exports('GetHospitalV8CommandBoard',function()return{codes=codeEvents,forecasts=flowForecasts,isolationRooms=infectionRooms,generatedAt=os.time()}end)
CreateThread(function()Wait(3000);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-hospital',VERSION,{'patient_flow_forecast','hospital_codes','isolation_management','surge_intelligence'})end);print('[dpn-medical-hospital] v8 patient flow, code team and isolation command active')end)
