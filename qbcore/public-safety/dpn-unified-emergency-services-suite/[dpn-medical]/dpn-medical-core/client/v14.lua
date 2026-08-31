RegisterCommand('medicalv14',function()TriggerServerEvent('dpn-medical-core:server:requestV14Summary')end,false)
RegisterNetEvent('dpn-medical-core:client:v14Summary',function(message)TriggerEvent('chat:addMessage',{args={'DPN Medical v14',tostring(message)}})end)
CreateThread(function()Wait(3000);print('[dpn-medical-core] client v14 trauma summary and command hooks active')end)
