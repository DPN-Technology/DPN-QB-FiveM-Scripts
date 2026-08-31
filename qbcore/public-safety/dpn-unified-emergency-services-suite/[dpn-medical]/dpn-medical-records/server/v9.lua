local VERSION='9.0.0'
local summaries, integrity, consents = {}, {}, {}
local function uid(p)return('%s-%s-%04d'):format(p,os.time(),math.random(0,9999))end
local function core(name,...)local a=table.pack(...);local ok,x,y=pcall(function()local p=exports['dpn-medical-core'];return p[name](p,table.unpack(a,1,a.n))end);return ok,x,y end
exports('CreateLongitudinalSummaryV9',function(target,episodeId,author)
 local ok,twin=core('GetV9Twin',target);if not ok or type(twin)~='table'then return false,'Patient unavailable.'end;local item={id=uid('SUMMARY'),target=tonumber(target),episodeId=episodeId,author=author,adaptiveRisk=twin.v9.adaptiveRisk,recovery=twin.v9.recoveryProbability,trajectory=twin.v9.trajectory,disposition=twin.v9.disposition,keyRisks=twin.safety and twin.safety.findings or{},createdAt=os.time()};summaries[item.id]=item;return true,item
end)
exports('SealRecordIntegrityV9',function(recordId,payload,actor)local encoded=json.encode(payload or{});local checksum=0;for i=1,#encoded do checksum=(checksum+encoded:byte(i)*i)%2147483647 end;local item={recordId=recordId,seal=('DPN9-%08X'):format(checksum),actor=actor,sealedAt=os.time()};integrity[tostring(recordId)]=item;return true,item end)
exports('SetGranularConsentV9',function(patientCid,scope,allowed,expiresAt,actor)local key=('%s:%s'):format(patientCid,scope);local item={patientCid=patientCid,scope=scope,allowed=allowed==true,expiresAt=expiresAt,actor=actor,updatedAt=os.time()};consents[key]=item;return true,item end)
exports('GetV9RecordsBoard',function()return{version=VERSION,summaries=summaries,integrity=integrity,consents=consents,generatedAt=os.time()}end)
CreateThread(function()Wait(5500);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-records',VERSION,{'longitudinal_summary','record_integrity_seal','granular_consent','adaptive_charting'})end);print('[dpn-medical-records] v9 longitudinal summaries, consent and integrity sealing active')end)
