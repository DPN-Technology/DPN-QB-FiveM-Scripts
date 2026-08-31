DPN_MED = DPN_MED or {}

-- v14 time-critical trauma, resuscitation and procedural-safety layer.
-- Additive to v13: all previous state models and exports remain available.

local previousRecalculate = DPN_MED.Recalculate

local function now() return os and os.time and os.time() or 0 end
local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end
local function round(value, places)
    local power = 10 ^ (places or 0)
    return math.floor((tonumber(value) or 0) * power + 0.5) / power
end
local function ensure(parent, key, defaults)
    parent[key] = type(parent[key]) == 'table' and parent[key] or {}
    for field, value in pairs(defaults or {}) do
        if parent[key][field] == nil then parent[key][field] = value end
    end
    return parent[key]
end
local function copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, child in pairs(value) do result[copy(key, seen)] = copy(child, seen) end
    return result
end
local function lab(state, key, fallback)
    for _, bucket in ipairs({ state.labs, state.electrolytes, state.bloodGas }) do
        if type(bucket) == 'table' and tonumber(bucket[key]) ~= nil then return tonumber(bucket[key]) end
    end
    return tonumber(fallback)
end
local function hasCondition(state, fragment)
    fragment = tostring(fragment or ''):lower()
    for key, value in pairs(type(state.conditions) == 'table' and state.conditions or {}) do
        if tostring(key):lower():find(fragment, 1, true) and (type(value) ~= 'table' or value.active ~= false) then return true end
    end
    return false
end
local function bodyRows(state)
    local rows = {}
    for region, value in pairs(type(state.body) == 'table' and state.body or {}) do
        if type(value) == 'table' then
            local row = copy(value); row.region = tostring(region); rows[#rows + 1] = row
        end
    end
    return rows
end
local function medicationRows(state)
    local rows = {}
    for key, value in pairs(type(state.medications) == 'table' and state.medications or {}) do
        if type(value) == 'table' then local row = copy(value); row.name = row.name or tostring(key); rows[#rows+1] = row
        elseif value then rows[#rows+1] = { name=tostring(key), active=true } end
    end
    return rows
end

function DPN_MED.EnsureV14Schema(state)
    state = type(state) == 'table' and state or DPN_MED.NewBodyState()
    if DPN_MED.EnsureV13Schema then state = DPN_MED.EnsureV13Schema(state) end
    ensure(state, 'traumaV14', {
        woundBurden=0, externalHemorrhageRate=0, occultHemorrhageRisk=0,
        compartmentSyndromeRisk=0, limbIschemiaRisk=0, rhabdomyolysisRisk=0,
        contaminationRisk=0, preventableDeathRisk=0, goldenHourRemaining=60
    })
    ensure(state, 'resuscitationV14', {
        crystalloidMl=0, packedCells=0, plasmaUnits=0, plateletsUnits=0,
        calciumDoses=0, dilutionRisk=0, citrateToxicityRisk=0,
        transfusionReactionRisk=0, tacoRisk=0, traliRisk=0,
        temperatureDebt=0, balancedRatioScore=100
    })
    ensure(state, 'airwayV14', {
        airwayProtection=100, aspirationRisk=0, obstructionRisk=0,
        ventilationFailureRisk=0, oxygenToxicityRisk=0, deadSpaceRisk=0,
        shuntRisk=0, etco2=38, airwayGrade='patent'
    })
    ensure(state, 'neuroV14', {
        cerebralPerfusionRisk=0, seizureRisk=0, pupilAsymmetryRisk=0,
        spinalCordRisk=0, deliriumRisk=0, neuroCommandLevel='routine'
    })
    ensure(state, 'procedureV14', {
        readiness=100, checklistGaps=0, consentReady=true, siteMarked=true,
        bloodAvailable=true, airwayPlanReady=true, monitoringReady=true,
        sedationRisk=0, anesthesiaRisk=0, approvalRequired=false
    })
    ensure(state, 'v14', {
        traumaCommandRisk=0, commandLevel='routine', traumaTier='none',
        goldenHourRemaining=60, preventableDeathRisk=0, resourceDemand=0,
        recommendedDestination='self_care', recommendedTeam='primary_care',
        recommendedActions={}, lastCalculated=0
    })
    state.v14TraumaClocks = type(state.v14TraumaClocks) == 'table' and state.v14TraumaClocks or {}
    state.v14ProcedureChecklists = type(state.v14ProcedureChecklists) == 'table' and state.v14ProcedureChecklists or {}
    state.v14TransfusionLog = type(state.v14TransfusionLog) == 'table' and state.v14TransfusionLog or {}
    return state
end

local function calculateTrauma(state)
    local woundBurden, externalRate, occult, compartment, ischemia, rhabdo, contamination = 0,0,0,0,0,0,0
    local severeRegions, crushRegions = 0,0
    for _, injury in ipairs(bodyRows(state)) do
        local damage = clamp(injury.damage, 0, 100)
        local kind = tostring(injury.type or injury.injuryType or ''):lower()
        local woundKinds = {}
        for _, wound in ipairs(type(injury.wounds) == 'table' and injury.wounds or {}) do
            local woundType = tostring(wound.type or ''):lower()
            woundKinds[#woundKinds + 1] = woundType
            if woundType:find('crush',1,true) then kind = kind .. ' crush' end
            if woundType:find('gunshot',1,true) then kind = kind .. ' gunshot' end
            if woundType:find('stab',1,true) then kind = kind .. ' stab' end
            if woundType:find('burn',1,true) then kind = kind .. ' burn' end
        end
        local bleeding = tostring(injury.bleeding or 'none'):lower()
        local internal = injury.internalBleeding == true
        woundBurden = woundBurden + damage * .12
        if damage >= 60 then severeRegions = severeRegions + 1 end
        if bleeding == 'arterial' then externalRate = externalRate + 38 + damage * .32
        elseif bleeding == 'venous' then externalRate = externalRate + 18 + damage * .18
        elseif bleeding ~= 'none' then externalRate = externalRate + 8 + damage * .10 end
        if internal then occult = occult + 24 + damage * .45 end
        if kind:find('crush',1,true) then crushRegions=crushRegions+1; rhabdo=rhabdo+35+damage*.5; compartment=compartment+30+damage*.45 end
        if kind:find('fracture',1,true) or tostring(injury.fracture or 'none') ~= 'none' then compartment=compartment+12+damage*.22 end
        if injury.tourniquet == true or injury.tourniquetApplied == true then ischemia=ischemia+20+damage*.18 end
        if kind:find('gunshot',1,true) or kind:find('stab',1,true) or kind:find('compound',1,true) then contamination=contamination+18+damage*.25 end
        if injury.foreignBody == true then contamination=contamination+30 end
    end
    local blood = tonumber(state.vitals and state.vitals.blood) or 5000
    local shock = tonumber(state.status and state.status.shock) or 0
    local lactate = lab(state,'lactate',1.2) or 1.2
    occult = occult + math.max(0, 4300-blood)/32 + shock*.25
    local preventable = clamp(externalRate*.35 + occult*.40 + compartment*.10 + math.max(0,lactate-2)*5 + severeRegions*4,0,100)
    local elapsed = tonumber(state.flags and state.flags.traumaElapsedMinutes) or tonumber(state.traumaElapsedMinutes) or 0
    local golden = clamp(60-elapsed-math.max(0,preventable-60)*.30,0,60)
    return {
        woundBurden=round(clamp(woundBurden,0,100),1), externalHemorrhageRate=round(clamp(externalRate,0,250),1),
        occultHemorrhageRisk=round(clamp(occult,0,100),1), compartmentSyndromeRisk=round(clamp(compartment,0,100),1),
        limbIschemiaRisk=round(clamp(ischemia,0,100),1), rhabdomyolysisRisk=round(clamp(rhabdo,0,100),1),
        contaminationRisk=round(clamp(contamination,0,100),1), preventableDeathRisk=round(preventable,1),
        goldenHourRemaining=round(golden,1), severeRegionCount=severeRegions, crushRegionCount=crushRegions
    }
end

local function calculateResuscitation(state)
    local log = type(state.v14TransfusionLog)=='table' and state.v14TransfusionLog or {}
    local crystalloid, prbc, plasma, platelets, calcium = 0,0,0,0,0
    for _, item in pairs(log) do
        if type(item)=='table' then
            local product=tostring(item.product or item.type or ''):lower(); local amount=tonumber(item.amount) or tonumber(item.units) or 0
            if product:find('crystalloid',1,true) or product:find('saline',1,true) then crystalloid=crystalloid+amount
            elseif product:find('packed',1,true) or product:find('prbc',1,true) or product:find('red',1,true) then prbc=prbc+amount
            elseif product:find('plasma',1,true) or product:find('ffp',1,true) then plasma=plasma+amount
            elseif product:find('platelet',1,true) then platelets=platelets+amount
            elseif product:find('calcium',1,true) then calcium=calcium+amount end
        end
    end
    local legacy = state.transfusionV10 or state.resuscitation or {}
    prbc=prbc+(tonumber(legacy.packedCells) or 0); plasma=plasma+(tonumber(legacy.plasma) or 0); platelets=platelets+(tonumber(legacy.platelets) or 0)
    crystalloid=crystalloid+(tonumber(legacy.crystalloidMl) or 0)
    local totalBlood=prbc+plasma+platelets
    local dilution=clamp(crystalloid/45 + math.max(0,prbc-plasma-2)*8,0,100)
    local citrate=clamp(totalBlood*7-math.max(0,calcium)*18,0,100)
    local ratio = totalBlood>0 and clamp(100-math.abs(prbc-math.max(1,plasma))*14-math.max(0,prbc-platelets*2)*6,0,100) or 100
    local temp=tonumber(state.vitals and (state.vitals.temperature or state.vitals.temp)) or 37
    local spo2=tonumber(state.vitals and state.vitals.spo2) or 99
    local sbp=tonumber(state.vitals and state.vitals.systolic) or 120
    local taco=clamp(totalBlood*4+crystalloid/100+math.max(0,95-spo2)*2+(hasCondition(state,'heart failure') and 30 or 0),0,100)
    local trali=clamp(plasma*6+platelets*5+math.max(0,92-spo2)*3,0,100)
    local reaction=clamp(totalBlood*2+(hasCondition(state,'transfusion reaction') and 60 or 0),0,100)
    return {
        crystalloidMl=round(crystalloid,0), packedCells=round(prbc,1), plasmaUnits=round(plasma,1), plateletsUnits=round(platelets,1), calciumDoses=round(calcium,1),
        dilutionRisk=round(dilution,1), citrateToxicityRisk=round(citrate,1), transfusionReactionRisk=round(reaction,1),
        tacoRisk=round(taco,1), traliRisk=round(trali,1), temperatureDebt=round(clamp(math.max(0,36-temp)*25,0,100),1),
        balancedRatioScore=round(ratio,1), hypotensionRisk=round(clamp(math.max(0,90-sbp)*2.2,0,100),1)
    }
end

local function calculateAirway(state)
    local rr=tonumber(state.vitals and state.vitals.rr) or 16
    local spo2=tonumber(state.vitals and state.vitals.spo2) or 99
    local gcs=tonumber(state.neurological and state.neurological.gcs) or tonumber(state.advanced and state.advanced.gcs) or 15
    local etco2=lab(state,'etco2',nil) or tonumber(state.respiratory and state.respiratory.etco2) or math.max(10,math.min(80,40+(16-rr)*1.4))
    local fio2=tonumber(state.ventilationV12 and state.ventilationV12.fio2) or tonumber(state.respiratory and state.respiratory.fio2) or .21
    local pao2=lab(state,'pao2',spo2>94 and 90 or math.max(35,spo2-20)) or 90
    local paco2=lab(state,'paco2',etco2+4) or etco2+4
    local obstruction=clamp((state.status and state.status.airwayObstructed and 80 or 0)+math.max(0,8-rr)*7+(gcs<=8 and 20 or 0),0,100)
    local aspiration=clamp((gcs<=8 and 55 or 0)+(state.status and state.status.vomiting and 35 or 0)+(hasCondition(state,'aspiration') and 45 or 0),0,100)
    local ventFail=clamp(math.max(0,92-spo2)*3+math.max(0,paco2-50)*2+math.max(0,8-rr)*8+math.max(0,rr-32)*2,0,100)
    local shunt=clamp(math.max(0,95-spo2)*3+math.max(0,.40-fio2)*0+math.max(0,80-pao2)*.7,0,100)
    local dead=clamp(math.max(0,etco2-45)*3+math.max(0,rr-28)*2+(hasCondition(state,'pulmonary embol') and 50 or 0),0,100)
    local oxygenTox=clamp(math.max(0,fio2-.60)*140+(tonumber(state.flags and state.flags.highOxygenMinutes) or 0)/12,0,100)
    local protection=clamp(100-obstruction*.55-aspiration*.45-(gcs<=8 and 35 or 0),0,100)
    local grade=protection<25 and 'unprotected' or protection<55 and 'threatened' or protection<80 and 'at_risk' or 'patent'
    return { airwayProtection=round(protection,1), aspirationRisk=round(aspiration,1), obstructionRisk=round(obstruction,1), ventilationFailureRisk=round(ventFail,1), oxygenToxicityRisk=round(oxygenTox,1), deadSpaceRisk=round(dead,1), shuntRisk=round(shunt,1), etco2=round(etco2,1), pao2=round(pao2,1), paco2=round(paco2,1), fio2=round(fio2,2), airwayGrade=grade }
end

local function calculateNeuro(state)
    local gcs=tonumber(state.neurological and state.neurological.gcs) or tonumber(state.advanced and state.advanced.gcs) or 15
    local map=tonumber(state.advanced and state.advanced.map) or (((tonumber(state.vitals and state.vitals.systolic) or 120)+2*(tonumber(state.vitals and state.vitals.diastolic) or 80))/3)
    local icp=tonumber(state.neurological and state.neurological.icp) or tonumber(state.neuroModelV10 and state.neuroModelV10.icp) or 10
    local cpp=map-icp
    local pupils=type(state.neurological)=='table' and state.neurological.pupils or {}
    local asym=tonumber(pupils.asymmetry) or (pupils.left and pupils.right and math.abs((tonumber(pupils.left)or 3)-(tonumber(pupils.right)or 3))*20 or 0)
    local seizure=clamp(math.max(0,10-gcs)*7+(hasCondition(state,'seizure') and 55 or 0)+math.max(0,60-cpp)*1.5,0,100)
    local spine=0
    for _, injury in ipairs(bodyRows(state)) do if tostring(injury.region):find('spine',1,true) or tostring(injury.type or ''):lower():find('spinal',1,true) then spine=spine+(tonumber(injury.damage)or 50) end end
    local perf=clamp(math.max(0,65-cpp)*2+math.max(0,10-gcs)*5,0,100)
    local level=perf>=75 and 'neurocritical' or perf>=50 and 'emergent' or perf>=25 and 'urgent' or 'routine'
    return { cerebralPerfusionRisk=round(perf,1), cerebralPerfusionPressure=round(cpp,1), seizureRisk=round(seizure,1), pupilAsymmetryRisk=round(clamp(asym,0,100),1), spinalCordRisk=round(clamp(spine,0,100),1), deliriumRisk=round(clamp((15-gcs)*6+(tonumber(state.recoveryV13 and state.recoveryV13.deliriumRisk)or 0),0,100),1), neuroCommandLevel=level }
end

local function calculateProcedure(state)
    local consent = state.consentStatus ~= 'refused' and not (state.codeStatus and state.codeStatus == 'comfort_only')
    local bloodAvailable = state.flags and state.flags.bloodUnavailable ~= true
    local airway = state.airwayV14 or calculateAirway(state)
    local monitoring = not (state.flags and state.flags.monitoringUnavailable == true)
    local site = not (state.flags and state.flags.siteNotMarked == true)
    local medications=medicationRows(state); local sedative=0
    for _,med in ipairs(medications) do local n=tostring(med.name or ''):lower();local c=tostring(med.class or ''):lower();if c:find('sedat',1,true)or n:find('propof',1,true)or n:find('midazol',1,true)then sedative=sedative+15+(tonumber(med.dose)or 0)*.25 end end
    local hypotension=clamp(math.max(0,90-(tonumber(state.vitals and state.vitals.systolic)or 120))*2.5,0,100)
    local sedation=clamp(sedative+airway.ventilationFailureRisk*.35+hypotension*.35,0,100)
    local gaps=0;if not consent then gaps=gaps+1 end;if not site then gaps=gaps+1 end;if not bloodAvailable then gaps=gaps+1 end;if airway.airwayProtection<55 then gaps=gaps+1 end;if not monitoring then gaps=gaps+1 end
    local readiness=clamp(100-gaps*18-sedation*.25-(tonumber(state.v13 and state.v13.continuumRisk)or 0)*.18,0,100)
    return { readiness=round(readiness,1), checklistGaps=gaps, consentReady=consent, siteMarked=site, bloodAvailable=bloodAvailable, airwayPlanReady=airway.airwayProtection>=40, monitoringReady=monitoring, sedationRisk=round(sedation,1), anesthesiaRisk=round(clamp(sedation*.55+hypotension*.45,0,100),1), approvalRequired=gaps>0 or sedation>=45 or readiness<70 }
end

function DPN_MED.CalculateV14Metrics(state)
    state=DPN_MED.EnsureV14Schema(state)
    state.traumaV14=calculateTrauma(state)
    state.resuscitationV14=calculateResuscitation(state)
    state.airwayV14=calculateAirway(state)
    state.neuroV14=calculateNeuro(state)
    state.procedureV14=calculateProcedure(state)
    local base=tonumber(state.v13 and state.v13.continuumRisk) or 0
    local shock=tonumber(state.status and state.status.shock) or 0
    local weighted=base*.16+state.traumaV14.preventableDeathRisk*.32+state.airwayV14.ventilationFailureRisk*.18+state.neuroV14.cerebralPerfusionRisk*.12+(100-state.procedureV14.readiness)*.07+state.resuscitationV14.citrateToxicityRisk*.05+state.resuscitationV14.dilutionRisk*.05+shock*.05
    local risk=clamp(math.max(weighted,
        state.traumaV14.preventableDeathRisk*.82,
        state.traumaV14.occultHemorrhageRisk*.72,
        state.airwayV14.ventilationFailureRisk*.78,
        state.traumaV14.compartmentSyndromeRisk*.62,
        state.traumaV14.rhabdomyolysisRisk*.58,
        state.resuscitationV14.citrateToxicityRisk*.70,
        state.resuscitationV14.tacoRisk*.66,
        state.resuscitationV14.traliRisk*.66),0,100)
    local resource=clamp(risk*.45+state.traumaV14.woundBurden*.25+state.airwayV14.ventilationFailureRisk*.15+state.neuroV14.cerebralPerfusionRisk*.15,0,100)
    local tier=risk>=88 and 'trauma_one' or risk>=68 and 'trauma_two' or risk>=45 and 'trauma_three' or risk>=25 and 'trauma_consult' or 'none'
    local command=risk>=90 and 'catastrophic' or risk>=75 and 'critical' or risk>=55 and 'high' or risk>=30 and 'elevated' or 'routine'
    local destination=risk>=88 and 'level_one_trauma_center' or risk>=70 and 'trauma_icu' or risk>=50 and 'trauma_center' or risk>=28 and 'emergency_department' or 'outpatient'
    local team=risk>=88 and 'trauma_command_multidisciplinary' or risk>=70 and 'trauma_surgery_critical_care' or risk>=50 and 'emergency_trauma_team' or risk>=28 and 'emergency_medicine' or 'primary_care'
    local actions={}
    local function add(code,priority,reason,department,approval) actions[#actions+1]={code=code,priority=priority,reason=reason,department=department,requiresApproval=approval==true} end
    if state.traumaV14.externalHemorrhageRate>=35 or state.traumaV14.occultHemorrhageRisk>=55 then add('hemorrhage_control',1,'Active or occult hemorrhage is time critical.','ems_surgery',true) end
    if state.airwayV14.airwayProtection<55 or state.airwayV14.ventilationFailureRisk>=55 then add('secure_airway',1,'Airway protection or ventilation is failing.','ems_anesthesia',true) end
    if state.resuscitationV14.citrateToxicityRisk>=40 or state.resuscitationV14.dilutionRisk>=45 then add('balanced_resuscitation',1,'Resuscitation complications require correction.','blood_bank_pharmacy',true) end
    if state.traumaV14.compartmentSyndromeRisk>=50 then add('compartment_pressure_evaluation',1,'Limb compartment syndrome is possible.','surgery',true) end
    if state.traumaV14.rhabdomyolysisRisk>=45 then add('crush_injury_bundle',1,'Crush injury and rhabdomyolysis risk.','ems_icu_pharmacy',true) end
    if state.neuroV14.cerebralPerfusionRisk>=45 then add('neuroprotection',1,'Cerebral perfusion is threatened.','neurocritical_care',true) end
    if state.procedureV14.checklistGaps>0 then add('close_procedure_gaps',2,'Procedure checklist has unresolved safety gaps.','procedure_team',false) end
    if #actions==0 then add('serial_reassessment',4,'No immediate trauma-command action is required.','clinical_team',false) end
    state.v14={traumaCommandRisk=round(risk,1),commandLevel=command,traumaTier=tier,goldenHourRemaining=state.traumaV14.goldenHourRemaining,preventableDeathRisk=state.traumaV14.preventableDeathRisk,resourceDemand=round(resource,1),recommendedDestination=destination,recommendedTeam=team,recommendedActions=actions,lastCalculated=now()}
    return state
end

function DPN_MED.BuildTraumaProtocolV14(state, requested)
    state=DPN_MED.CalculateV14Metrics(state)
    local steps={}
    for index,action in ipairs(state.v14.recommendedActions or {}) do steps[#steps+1]={id=('V14STEP-%02d-%s'):format(index,action.code),code=action.code,priority=action.priority,department=action.department,reason=action.reason,requiresHumanApproval=action.requiresApproval,status=action.requiresApproval and 'awaiting_approval' or 'planned'} end
    return {protocol=requested or 'damage_control_resuscitation',status='draft',tier=state.v14.traumaTier,risk=state.v14.traumaCommandRisk,goldenHourRemaining=state.v14.goldenHourRemaining,destination=state.v14.recommendedDestination,team=state.v14.recommendedTeam,approvalRequired=state.procedureV14.approvalRequired or state.v14.traumaCommandRisk>=55,steps=steps,createdAt=now()}
end

function DPN_MED.CompareTraumaDestinationsV14(state, destinations)
    state=DPN_MED.CalculateV14Metrics(state)
    destinations=type(destinations)=='table' and destinations or {
        {id='local_ed',travelMinutes=8,traumaLevel=4,icu=false,['or']=false,blood=false},
        {id='regional_trauma',travelMinutes=18,traumaLevel=2,icu=true,['or']=true,blood=true},
        {id='level_one',travelMinutes=32,traumaLevel=1,icu=true,['or']=true,blood=true,neuro=true}
    }
    local rows={}
    for _,d in ipairs(destinations) do
        local capability=(5-(tonumber(d.traumaLevel)or 5))*14+(d.icu and 15 or 0)+(d['or'] and 15 or 0)+(d.blood and 12 or 0)+(d.neuro and 8 or 0)
        local delay=(tonumber(d.travelMinutes)or 30)*math.max(.4,state.v14.traumaCommandRisk/70)
        local mismatch=0
        if state.v14.traumaCommandRisk>=75 and (tonumber(d.traumaLevel)or 5)>2 then mismatch=mismatch+35 end
        if state.neuroV14.cerebralPerfusionRisk>=50 and not d.neuro then mismatch=mismatch+20 end
        if state.traumaV14.preventableDeathRisk>=60 and not d.blood then mismatch=mismatch+20 end
        local score=clamp(50+capability-delay-mismatch,0,100)
        rows[#rows+1]={id=d.id or 'destination',score=round(score,1),travelMinutes=d.travelMinutes or 0,capabilityScore=capability,delayPenalty=round(delay,1),mismatchPenalty=mismatch,recommended=false}
    end
    table.sort(rows,function(a,b)return a.score>b.score end);if rows[1] then rows[1].recommended=true end
    return rows
end

function DPN_MED.ForecastTreatmentV14(state, intervention)
    state=DPN_MED.CalculateV14Metrics(state);intervention=tostring(intervention or 'reassessment')
    local before=state.v14.traumaCommandRisk;local benefit,risk=0,0
    if intervention=='hemorrhage_control' then benefit=state.traumaV14.externalHemorrhageRate*.22+state.traumaV14.occultHemorrhageRisk*.18
    elseif intervention=='massive_transfusion' then benefit=state.traumaV14.preventableDeathRisk*.22;risk=state.resuscitationV14.citrateToxicityRisk*.15+state.resuscitationV14.tacoRisk*.12
    elseif intervention=='secure_airway' then benefit=state.airwayV14.ventilationFailureRisk*.28+state.airwayV14.aspirationRisk*.15;risk=state.procedureV14.sedationRisk*.12
    elseif intervention=='fasciotomy' then benefit=state.traumaV14.compartmentSyndromeRisk*.30;risk=state.procedureV14.anesthesiaRisk*.08
    elseif intervention=='damage_control_surgery' then benefit=state.traumaV14.occultHemorrhageRisk*.28+state.traumaV14.preventableDeathRisk*.20;risk=(100-state.procedureV14.readiness)*.12
    else benefit=5 end
    local projected=clamp(before-benefit+risk,0,100)
    return {intervention=intervention,currentRisk=before,projectedRisk=round(projected,1),expectedBenefit=round(clamp(before-projected,0,100),1),treatmentRisk=round(clamp(risk,0,100),1),requiresHumanApproval=intervention~='reassessment',confidence=tonumber(state.uncertaintyV13 and state.uncertaintyV13.confidence)or 70,generatedAt=now()}
end

function DPN_MED.BuildV14Twin(state)
    state=DPN_MED.CalculateV14Metrics(state)
    return {version='14.0.0',demographics=copy(state.demographics or{}),vitals=copy(state.vitals or{}),v14=copy(state.v14),traumaV14=copy(state.traumaV14),resuscitationV14=copy(state.resuscitationV14),airwayV14=copy(state.airwayV14),neuroV14=copy(state.neuroV14),procedureV14=copy(state.procedureV14),v13=copy(state.v13 or{}),hemostasisV13=copy(state.hemostasisV13 or{}),uncertaintyV13=copy(state.uncertaintyV13 or{})}
end

function DPN_MED.BuildV14TrendPoint(state)
    state=DPN_MED.CalculateV14Metrics(state)
    return {at=now(),risk=state.v14.traumaCommandRisk,goldenHourRemaining=state.v14.goldenHourRemaining,preventableDeathRisk=state.v14.preventableDeathRisk,externalHemorrhageRate=state.traumaV14.externalHemorrhageRate,occultHemorrhageRisk=state.traumaV14.occultHemorrhageRisk,airwayProtection=state.airwayV14.airwayProtection,procedureReadiness=state.procedureV14.readiness,resourceDemand=state.v14.resourceDemand}
end

function DPN_MED.RunV14SharedSelfTest()
    local state=DPN_MED.NewBodyState();state.vitals.blood=2050;state.vitals.hr=154;state.vitals.systolic=66;state.vitals.diastolic=34;state.vitals.spo2=80;state.vitals.rr=7;state.vitals.temperature=33.1;state.status.shock=96
    state.body=state.body or{};state.body.abdomen={damage=92,type='gunshot',internalBleeding=true,bleeding='arterial'};state.body.left_leg={damage=82,type='crush',fracture='compound',bleeding='venous',tourniquet=true}
    state.labs={lactate=10.2,ph=7.03,platelets=52,fibrinogen=85,inr=2.6,ionizedCalcium=.72,etco2=58,paco2=64,pao2=54}
    state.v14TransfusionLog={{product='packed_cells',amount=6},{product='plasma',amount=2},{product='crystalloid',amount=2500}}
    state=DPN_MED.CalculateV14Metrics(state);local protocol=DPN_MED.BuildTraumaProtocolV14(state);local destinations=DPN_MED.CompareTraumaDestinationsV14(state);local forecast=DPN_MED.ForecastTreatmentV14(state,'damage_control_surgery')
    return {passed=state.v14.traumaCommandRisk>=70 and state.traumaV14.occultHemorrhageRisk>=60 and state.airwayV14.ventilationFailureRisk>=50 and #protocol.steps>=3 and destinations[1] and destinations[1].recommended and forecast.projectedRisk<forecast.currentRisk,risk=state.v14.traumaCommandRisk,occult=state.traumaV14.occultHemorrhageRisk,airway=state.airwayV14.ventilationFailureRisk,procedure=state.procedureV14.readiness,steps=#protocol.steps,destination=destinations[1]and destinations[1].id,projected=forecast.projectedRisk}
end

DPN_MED.Recalculate=function(state,...)
    if previousRecalculate then state=previousRecalculate(state,...) end
    return DPN_MED.CalculateV14Metrics(state)
end
