local VERSION = '13.0.0'
local snapshots, simulations, pathways, reservations, commandIncidents, journals, trends = {}, {}, {}, {}, {}, {}, {}

local function now() return os.time() end
local function uid(prefix, target) return ('%s-%s-%s-%04d'):format(prefix, now(), tostring(target or 0), math.random(0,9999)) end
local function encode(value) local ok, data = pcall(json.encode, value); return ok and data or '{}' end
local function clone(value) local ok, data = pcall(json.encode, value); if not ok then return nil end; local ok2, out = pcall(json.decode, data); return ok2 and out or nil end
local function player(target) local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end); if not ok or not core or not core.Functions then return nil end; local ok2,p=pcall(function() return core.Functions.GetPlayer(tonumber(target)) end); return ok2 and p or nil end
local function cid(target) local p=player(target); return p and p.PlayerData and p.PlayerData.citizenid or ('source:%s'):format(tostring(target)) end
local function stateFor(target) if not DPNMedicalServer or not DPNMedicalServer.EnsureState then return nil end; return DPNMedicalServer.EnsureState(tonumber(target)) end
local function commit(target,state,eventType,data) if not DPNMedicalServer or not DPNMedicalServer.Commit then return false end; local _,pcid=DPNMedicalServer.EnsureState(tonumber(target)); if not pcid then return false end; DPNMedicalServer.Commit(tonumber(target),pcid,state,eventType,data or{}); return true end
local function persist(sql,params,update) CreateThread(function() pcall(function() if update then MySQL.update.await(sql,params) else MySQL.insert.await(sql,params) end end) end) end
local function count(t)local n=0;for _ in pairs(type(t)=='table'and t or{})do n=n+1 end;return n end
local function lcg(seed) seed=(1103515245*(tonumber(seed)or 1)+12345)%2147483648;return seed,seed/2147483648 end
local function journal(target,eventType,data,actor)
    target=tonumber(target); local item={id=uid('JRN13',target),target=target,patientCid=target and cid(target)or nil,eventType=tostring(eventType),data=data or{},actor=tostring(actor or'system'),at=now()}
    journals[target or 0]=journals[target or 0]or{};table.insert(journals[target or 0],1,item);while#journals[target or 0]>300 do table.remove(journals[target or 0])end
    persist('INSERT INTO dpn_medical_v13_journal (journal_id,patient_cid,event_type,event_data,actor) VALUES (?,?,?,?,?)',{item.id,item.patientCid,item.eventType,encode(item.data),item.actor});return item
end
local function trend(target,state,source)
    target=tonumber(target);local point=DPN_MED.BuildV13TrendPoint(state);point.id=uid('TR13',target);point.source=source or'state_change';trends[target]=trends[target]or{};table.insert(trends[target],1,point);while#trends[target]>300 do table.remove(trends[target])end
    persist('INSERT INTO dpn_medical_v13_trends (trend_id,patient_cid,source_module,trend_data) VALUES (?,?,?,?)',{point.id,cid(target),point.source,encode(point)});return point
end

exports('GetV13Twin',function(target)local s=stateFor(target);return s and DPN_MED.BuildV13Twin(s)or nil end)
exports('GetV13CausalGraph',function(target)local s=stateFor(target);return s and DPN_MED.CalculateV13Metrics(s).v13CausalGraph or nil end)
exports('ForecastInterventionV13',function(target,intervention)local s=stateFor(target);if not s then return false,'Patient not found.'end;return true,DPN_MED.SimulateInterventionV13(s,intervention)end)

exports('CreatePatientSnapshotV13',function(target,label,actor)
    target=tonumber(target);local s=stateFor(target);if not s then return false,'Patient not found.'end
    local item={id=uid('SNAP13',target),target=target,patientCid=cid(target),label=tostring(label or'manual_snapshot'),actor=tostring(actor or'system'),state=clone(s),createdAt=now()}
    snapshots[target]=snapshots[target]or{};snapshots[target][item.id]=item
    persist('INSERT INTO dpn_medical_v13_snapshots (snapshot_id,patient_cid,label,snapshot_data,created_by) VALUES (?,?,?,?,?)',{item.id,item.patientCid,item.label,encode(item.state),item.actor});journal(target,'snapshot_created',{snapshotId=item.id,label=item.label},item.actor);return item.id,item
end)
exports('RestorePatientSnapshotV13',function(target,snapshotId,actor)
    target=tonumber(target);local item=snapshots[target]and snapshots[target][tostring(snapshotId)];if not item then return false,'V13 snapshot not found in active memory.'end
    local restored=clone(item.state);if not restored then return false,'Snapshot decode failed.'end;DPN_MED.CalculateV13Metrics(restored);commit(target,restored,'v13_snapshot_restored',{snapshotId=item.id,actor=actor});journal(target,'snapshot_restored',{snapshotId=item.id},actor);return true,restored
end)
exports('GetPatientSnapshotsV13',function(target)return snapshots[tonumber(target)]or{}end)

exports('StartDeterministicSimulationV13',function(target,scenario,options,actor)
    target=tonumber(target);local s=stateFor(target);if not s then return false,'Patient not found.'end;options=type(options)=='table'and options or{}
    local item={id=uid('SIM13',target),target=target,patientCid=cid(target),scenario=tostring(scenario or'continuum'),actor=tostring(actor or'system'),seed=tonumber(options.seed)or(now()+target),step=0,status='active',applyToLive=options.applyToLive==true,model=clone(DPN_MED.BuildV13Twin(s)),history={},createdAt=now()}
    simulations[item.id]=item;persist('INSERT INTO dpn_medical_v13_simulations (simulation_id,patient_cid,scenario,status,simulation_data,created_by) VALUES (?,?,?,?,?,?)',{item.id,item.patientCid,item.scenario,item.status,encode(item),item.actor});journal(target,'simulation_started',{simulationId=item.id,scenario=item.scenario},item.actor);return item.id,item
end)
exports('StepDeterministicSimulationV13',function(simulationId,steps)
    local item=simulations[tostring(simulationId)];if not item or item.status~='active'then return false,'Active v13 simulation not found.'end;steps=math.max(1,math.min(120,tonumber(steps)or 1))
    for _=1,steps do item.seed,item.random=lcg(item.seed);item.step=item.step+1;local drift=(item.random-.5)*6;local risk=tonumber(item.model.v13.continuumRisk)or 0
        if item.scenario=='hemorrhage'then drift=math.abs(drift)+2 elseif item.scenario=='sepsis'then drift=math.abs(drift)+1.2 elseif item.scenario=='recovery'then drift=-math.abs(drift)-1 end
        item.model.v13.continuumRisk=math.max(0,math.min(100,risk+drift));item.model.v13.resilienceScore=math.max(0,math.min(100,(tonumber(item.model.v13.resilienceScore)or 100)-drift*.6))
        item.history[#item.history+1]={step=item.step,risk=item.model.v13.continuumRisk,resilience=item.model.v13.resilienceScore,at=now()};if#item.history>240 then table.remove(item.history,1)end
    end
    persist('UPDATE dpn_medical_v13_simulations SET status=?,simulation_data=?,updated_at=NOW() WHERE simulation_id=?',{item.status,encode(item),item.id},true);return true,item
end)
exports('StopDeterministicSimulationV13',function(simulationId,actor)local item=simulations[tostring(simulationId)];if not item then return false,'Simulation not found.'end;item.status='stopped';item.stoppedBy=tostring(actor or'system');item.stoppedAt=now();persist('UPDATE dpn_medical_v13_simulations SET status=?,simulation_data=?,updated_at=NOW() WHERE simulation_id=?',{item.status,encode(item),item.id},true);return true,item end)
exports('GetDeterministicSimulationV13',function(id)return simulations[tostring(id)]end)

exports('CreateContinuumCarePathwayV13',function(target,requested,actor)
    target=tonumber(target);local s=stateFor(target);if not s then return false,'Patient not found.'end;local plan=DPN_MED.BuildContinuumPlanV13(s,requested);plan.id=uid('PATH13',target);plan.target=target;plan.patientCid=cid(target);plan.actor=tostring(actor or'system');pathways[target]=pathways[target]or{};pathways[target][plan.id]=plan;s.v13ContinuumPlans[plan.id]=plan;commit(target,s,'v13_pathway_created',{pathwayId=plan.id,steps=#plan.steps});persist('INSERT INTO dpn_medical_v13_pathways (pathway_id,patient_cid,status,pathway_data,created_by) VALUES (?,?,?,?,?)',{plan.id,plan.patientCid,plan.status,encode(plan),plan.actor});journal(target,'pathway_created',{pathwayId=plan.id},plan.actor);return plan.id,plan
end)
exports('ApproveContinuumCarePathwayV13',function(target,pathwayId,actor)local plan=pathways[tonumber(target)]and pathways[tonumber(target)][tostring(pathwayId)];if not plan then return false,'Pathway not found.'end;plan.status='approved';plan.approvedBy=tostring(actor or'system');plan.approvedAt=now();for _,step in ipairs(plan.steps or{})do if step.status=='awaiting_approval'then step.status='planned'end end;persist('UPDATE dpn_medical_v13_pathways SET status=?,pathway_data=?,updated_at=NOW() WHERE pathway_id=?',{plan.status,encode(plan),plan.id},true);return true,plan end)
exports('CompleteContinuumCareStepV13',function(target,pathwayId,stepId,actor,evidence)local plan=pathways[tonumber(target)]and pathways[tonumber(target)][tostring(pathwayId)];if not plan then return false,'Pathway not found.'end;local found;for _,step in ipairs(plan.steps or{})do if step.id==tostring(stepId)then found=step break end end;if not found then return false,'Pathway step not found.'end;if found.requiresHumanApproval and plan.status~='approved'then return false,'Human approval required.'end;found.status='complete';found.completedBy=tostring(actor or'system');found.completedAt=now();found.evidence=evidence;local complete=true;for _,step in ipairs(plan.steps or{})do if step.status~='complete'then complete=false break end end;plan.status=complete and'complete'or'active';persist('UPDATE dpn_medical_v13_pathways SET status=?,pathway_data=?,updated_at=NOW() WHERE pathway_id=?',{plan.status,encode(plan),plan.id},true);return true,plan end)
exports('GetContinuumCarePathwaysV13',function(target)return pathways[tonumber(target)]or{}end)

exports('ReserveCriticalResourceV13',function(target,resourceType,amount,location,actor)
    target=tonumber(target);amount=math.max(1,tonumber(amount)or 1);local item={id=uid('RSV13',target),target=target,patientCid=cid(target),resourceType=tostring(resourceType or'critical_kit'),amount=amount,location=tostring(location or'main'),actor=tostring(actor or'system'),status='reserved',createdAt=now()};reservations[item.id]=item;persist('INSERT INTO dpn_medical_v13_resource_reservations (reservation_id,patient_cid,resource_type,amount,location,status,reservation_data,created_by) VALUES (?,?,?,?,?,?,?,?)',{item.id,item.patientCid,item.resourceType,item.amount,item.location,item.status,encode(item),item.actor});journal(target,'resource_reserved',{reservationId=item.id,resourceType=item.resourceType,amount=item.amount},item.actor);return true,item
end)
exports('ReleaseCriticalResourceV13',function(reservationId,actor)local item=reservations[tostring(reservationId)];if not item then return false,'Reservation not found.'end;item.status='released';item.releasedBy=tostring(actor or'system');item.releasedAt=now();persist('UPDATE dpn_medical_v13_resource_reservations SET status=?,reservation_data=?,updated_at=NOW() WHERE reservation_id=?',{item.status,encode(item),item.id},true);return true,item end)
exports('GetCriticalResourceReservationsV13',function()return reservations end)

exports('CreateRegionalContinuumIncidentV13',function(target,location,actor)
    target=tonumber(target);local s=stateFor(target);if not s then return false,'Patient not found.'end;local twin=DPN_MED.BuildV13Twin(s);local item={id=uid('CMD13',target),target=target,patientCid=cid(target),location=location,actor=tostring(actor or'system'),risk=twin.v13.continuumRisk,priority=twin.v13.networkPriority,destination=twin.v13.recommendedDestination,team=twin.v13.recommendedTeam,status='active',createdAt=now()};commandIncidents[item.id]=item;persist('INSERT INTO dpn_medical_v13_command_incidents (incident_id,patient_cid,status,incident_data,created_by) VALUES (?,?,?,?,?)',{item.id,item.patientCid,item.status,encode(item),item.actor});TriggerEvent('dpn-medical:server:v13ContinuumIncident',item);journal(target,'continuum_incident_created',{incidentId=item.id},item.actor);return true,item
end)
exports('GetRegionalContinuumIncidentsV13',function()return commandIncidents end)
exports('GetClinicalJournalV13',function(target,limit)local rows=journals[tonumber(target)]or{};local out={};for i=1,math.min(#rows,tonumber(limit)or 50)do out[#out+1]=rows[i]end;return out end)

exports('GetV13OperationalDashboard',function()
    local patients,critical,lowConfidence,coagulopathy,toxicity,infection,prolonged={},0,0,0,0,0,0
    for _,sid in ipairs(GetPlayers()or{})do local target=tonumber(sid);local s=stateFor(target);if s then local twin=DPN_MED.BuildV13Twin(s);if twin.v13.continuumRisk>=75 then critical=critical+1 end;if twin.uncertaintyV13.confidence<65 then lowConfidence=lowConfidence+1 end;if twin.hemostasisV13.clotStrength<55 then coagulopathy=coagulopathy+1 end;if twin.pharmacologyV13.toxicityRisk>=45 then toxicity=toxicity+1 end;if twin.immuneV13.infectionProbability>=50 then infection=infection+1 end;if twin.recoveryV13.prolongedCareRisk>=55 then prolonged=prolonged+1 end;patients[#patients+1]={id=target,citizenid=cid(target),twin=twin,pathwayCount=count(pathways[target]),snapshotCount=count(snapshots[target]),trendPoints=#(trends[target]or{})}end end
    table.sort(patients,function(a,b)return(a.twin.v13.continuumRisk or 0)>(b.twin.v13.continuumRisk or 0)end)
    return{version=VERSION,generatedAt=now(),patients=patients,critical=critical,lowConfidence=lowConfidence,coagulopathy=coagulopathy,toxicity=toxicity,infection=infection,prolongedCare=prolonged,activeSimulations=count(simulations),activePathways=count(pathways),resourceReservations=count(reservations),commandIncidents=count(commandIncidents)}
end)
exports('RunV13SelfTest',function()local shared=DPN_MED.RunV13SharedSelfTest();return{passed=shared and shared.passed==true,shared=shared,version=VERSION,exports={'GetV13Twin','CreatePatientSnapshotV13','StartDeterministicSimulationV13','CreateContinuumCarePathwayV13','ReserveCriticalResourceV13','CreateRegionalContinuumIncidentV13','GetV13OperationalDashboard'}}end)

AddEventHandler(DPN_MED.Events.StateChanged,function(target,patientCid,changedState,eventType,data)local s=type(changedState)=='table'and changedState or stateFor(target);if not s then return end;DPN_MED.CalculateV13Metrics(s);trend(target,s,eventType or'state_changed');journal(target,eventType or'state_changed',data or{},'medical-core');if s.v13.continuumRisk>=90 then pcall(function()exports['dpn-medical-core']:RaiseSafetyAlert(target,'v13_continuum_critical','critical','V13 continuum model predicts catastrophic deterioration.',{risk=s.v13.continuumRisk,destination=s.v13.recommendedDestination,team=s.v13.recommendedTeam},'dpn-medical-core-v13')end)end end)
CreateThread(function()Wait(5600);pcall(function()exports['dpn-medical-core']:RegisterModule('dpn-medical-core-v13',VERSION,{'continuum_physiology','advanced_hemostasis','pharmacokinetic_risk','immune_response','recovery_forecasting','causal_graph','deterministic_simulation','state_snapshots','continuum_pathways','critical_resource_reservations','regional_command','clinical_event_journal'})end);print('[dpn-medical-core] v13.0.0 continuum command, deterministic simulation and recovery intelligence active')end)
RegisterCommand('medv13',function(src,args)local target=tonumber(args[1]or src);local twin=exports['dpn-medical-core']:GetV13Twin(target);local msg=twin and('V13 risk %s%% | %s | clot %s%% | tox %s%% | infection %s%% | recovery %s%% | confidence %s%%'):format(twin.v13.continuumRisk,twin.v13.recommendedDestination,twin.hemostasisV13.clotStrength,twin.pharmacologyV13.toxicityRisk,twin.immuneV13.infectionProbability,twin.recoveryV13.recoveryReserve,twin.uncertaintyV13.confidence)or'Patient unavailable.';if src==0 then print(msg)else TriggerClientEvent('chat:addMessage',src,{args={'DPN Medical v13',msg}})end end,false)
RegisterCommand('medv13test',function(src)local r=exports['dpn-medical-core']:RunV13SelfTest();local s=r.shared or{};local msg=('V13 self-test passed=%s risk=%s clot=%s toxicity=%s infection=%s steps=%s projected=%s'):format(tostring(r.passed),tostring(s.risk),tostring(s.clotStrength),tostring(s.toxicity),tostring(s.infection),tostring(s.planSteps),tostring(s.projectedRisk));if src==0 then print(msg)else TriggerClientEvent('chat:addMessage',src,{args={'DPN Medical v13',msg}})end end,false)

RegisterNetEvent('dpn-medical-core:server:requestV13Snapshot',function() local src=source;local twin=exports['dpn-medical-core']:GetV13Twin(src);TriggerClientEvent('dpn-medical-core:client:v13Summary',src,twin and ('Risk %s%% | %s | Resilience %s%% | Confidence %s%%'):format(twin.v13.continuumRisk,twin.v13.recommendedDestination,twin.v13.resilienceScore,twin.uncertaintyV13.confidence) or 'No medical state available.') end)
