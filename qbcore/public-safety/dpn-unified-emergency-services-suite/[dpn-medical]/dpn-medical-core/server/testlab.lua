local RESOURCE = GetCurrentResourceName()
local VERSION = GetResourceMetadata(RESOURCE, 'version', 0) or 'unknown'
local snapshots, testRuns = {}, {}

local function deepCopy(value)
    local ok, encoded = pcall(json.encode, value)
    if not ok then return nil end
    local decodedOk, decoded = pcall(json.decode, encoded)
    return decodedOk and decoded or nil
end

local function targetId(target)
    target = tonumber(target)
    return target and target > 0 and target or nil
end

local function stateFor(target)
    target = targetId(target)
    if not target then return nil, nil end
    local state, cid = DPNMedicalServer.EnsureState(target)
    return state, cid
end

local function applyInjury(state, part, injury)
    local changed
    state, changed = DPN_MED.ApplyInjury(state, part, injury)
    return state, changed == true
end

local function setCondition(state, id, data)
    state.conditions = type(state.conditions) == 'table' and state.conditions or {}
    data = type(data) == 'table' and data or {}
    data.id = id
    data.active = data.active ~= false
    data.startedAt = data.startedAt or os.time()
    state.conditions[id] = data
end

local function setFlags(state, flags)
    state.flags = type(state.flags) == 'table' and state.flags or {}
    for key, value in pairs(flags or {}) do state.flags[key] = value end
end

local function applyScenarioState(state, scenarioId)
    local lifeState = 'alive'
    local details = { cause = 'Medical administrator test scenario: ' .. tostring(scenarioId), testScenario = scenarioId }

    if scenarioId == 'clean_baseline' then
        return DPN_MED.NewBodyState(), lifeState, details
    elseif scenarioId == 'minor_laceration' then
        state = select(1, applyInjury(state, 'left_arm', {type='laceration',damage=15,pain=18,bleeding='capillary',source='medadmin_test'}))
    elseif scenarioId == 'deep_laceration' then
        state = select(1, applyInjury(state, 'right_leg', {type='laceration',damage=46,pain=52,bleeding='venous',nerve=8,source='medadmin_test'}))
    elseif scenarioId == 'arterial_hemorrhage' then
        state = select(1, applyInjury(state, 'left_leg', {type='laceration',damage=68,pain=72,bleeding='arterial',nerve=12,source='medadmin_test'}))
        state.vitals.blood = 3400; state.status.shock = 55
    elseif scenarioId == 'gunshot_chest' then
        state = select(1, applyInjury(state, 'chest', {type='gunshot',damage=78,pain=82,bleeding='arterial',internalBleeding=true,fracture='closed',organ='left_lung',organDamage=72,source='medadmin_test',weapon='WEAPON_CARBINERIFLE'}))
        state.vitals.blood = 3000; state.vitals.spo2 = 82; state.status.shock = 72
        setFlags(state,{pneumothorax=true,penetratingChestTrauma=true})
    elseif scenarioId == 'gunshot_abdomen' then
        state = select(1, applyInjury(state, 'abdomen', {type='gunshot',damage=76,pain=80,bleeding='venous',internalBleeding=true,organ='liver',organDamage=78,source='medadmin_test',weapon='WEAPON_PISTOL'}))
        state.vitals.blood = 2850; state.status.shock = 74
    elseif scenarioId == 'stab_chest' then
        state = select(1, applyInjury(state, 'chest', {type='stab',damage=58,pain=64,bleeding='venous',internalBleeding=true,organ='right_lung',organDamage=45,source='medadmin_test',weapon='WEAPON_KNIFE'}))
        state.vitals.spo2 = 88; setFlags(state,{openChestWound=true,pneumothorax=true})
    elseif scenarioId == 'blunt_tbi' then
        state = select(1, applyInjury(state, 'head', {type='blunt',damage=82,pain=90,internalBleeding=true,fracture='closed',organ='brain',organDamage=80,nerve=25,source='medadmin_test'}))
        state.status.unconscious = true; state.vitals.spo2 = 90; setFlags(state,{tbi=true,airwayRisk=true})
    elseif scenarioId == 'closed_leg_fracture' then
        state = select(1, applyInjury(state, 'left_leg', {type='blunt',damage=58,pain=72,bleeding='capillary',fracture='closed',nerve=10,source='medadmin_test'}))
        state.body.left_leg.bones.left_femur = 'closed'
    elseif scenarioId == 'compound_arm_fracture' then
        state = select(1, applyInjury(state, 'right_arm', {type='blunt',damage=76,pain=86,bleeding='arterial',fracture='compound',nerve=45,source='medadmin_test'}))
        state.body.right_arm.bones.right_humerus = 'compound'
    elseif scenarioId == 'pelvic_fracture' then
        state = select(1, applyInjury(state, 'pelvis', {type='blunt',damage=82,pain=88,bleeding='venous',internalBleeding=true,fracture='compound',organ='femoral_artery',organDamage=68,nerve=20,source='medadmin_test'}))
        state.body.pelvis.bones.pelvis = 'compound'; state.vitals.blood = 3000
    elseif scenarioId == 'spinal_trauma' then
        state = select(1, applyInjury(state, 'spine', {type='blunt',damage=88,pain=92,internalBleeding=true,fracture='compound',organ='spinal_cord',organDamage=88,nerve=90,source='medadmin_test'}))
        state.body.spine.bones.vertebrae = 'compound'; state.body.spine.mobility = 0; setFlags(state,{spinalPrecautions=true,paralysisRisk=true})
    elseif scenarioId == 'crush_injury' then
        state = select(1, applyInjury(state, 'left_leg', {type='crush',damage=90,pain=94,bleeding='venous',internalBleeding=true,fracture='compound',nerve=75,source='medadmin_test'}))
        setCondition(state,'crush_syndrome',{severity=90,rhabdomyolysis=true,hyperkalemiaRisk=true}); state.vitals.blood=3300; state.status.shock=65
    elseif scenarioId == 'explosion_polytrauma' then
        state = select(1, applyInjury(state,'head',{type='blast',damage=55,pain=65,internalBleeding=true,fracture='closed',organ='brain',organDamage=35,source='medadmin_test'}))
        state = select(1, applyInjury(state,'chest',{type='blast',damage=82,pain=86,bleeding='venous',internalBleeding=true,fracture='compound',organ='right_lung',organDamage=70,burn=2,source='medadmin_test'}))
        state = select(1, applyInjury(state,'left_leg',{type='blast',damage=78,pain=85,bleeding='arterial',fracture='compound',burn=2,nerve=35,source='medadmin_test'}))
        state.vitals.blood=2550; state.vitals.spo2=80; state.status.shock=86; setFlags(state,{blastLung=true,massiveHemorrhage=true})
    elseif scenarioId == 'vehicle_polytrauma' then
        state = select(1, applyInjury(state,'head',{type='collision',damage=52,pain=58,internalBleeding=true,fracture='closed',organ='brain',organDamage=30,source='medadmin_test'}))
        state = select(1, applyInjury(state,'chest',{type='collision',damage=68,pain=72,internalBleeding=true,fracture='closed',organ='left_lung',organDamage=38,source='medadmin_test'}))
        state = select(1, applyInjury(state,'pelvis',{type='collision',damage=72,pain=80,internalBleeding=true,fracture='closed',source='medadmin_test'}))
        state = select(1, applyInjury(state,'right_leg',{type='collision',damage=65,pain=75,bleeding='venous',fracture='compound',source='medadmin_test'}))
        state.vitals.blood=2900; state.status.shock=76
    elseif scenarioId == 'first_degree_burn' then
        state = select(1, applyInjury(state,'chest',{type='burn',damage=12,pain=20,burn=1,source='medadmin_test'}))
    elseif scenarioId == 'second_degree_burn' then
        state = select(1, applyInjury(state,'chest',{type='burn',damage=38,pain=62,burn=2,source='medadmin_test'}))
        state = select(1, applyInjury(state,'left_arm',{type='burn',damage=30,pain=55,burn=2,source='medadmin_test'}))
    elseif scenarioId == 'third_degree_burn' then
        state = select(1, applyInjury(state,'chest',{type='burn',damage=72,pain=78,burn=3,source='medadmin_test'}))
        state = select(1, applyInjury(state,'right_arm',{type='burn',damage=62,pain=70,burn=3,source='medadmin_test'}))
        state.status.shock=60; state.vitals.spo2=88; setFlags(state,{burnShock=true,airwayRisk=true})
    elseif scenarioId == 'fourth_degree_burn' then
        state = select(1, applyInjury(state,'chest',{type='electrical',damage=90,pain=88,burn=4,internalBleeding=true,organ='heart',organDamage=68,nerve=70,source='medadmin_test'}))
        state = select(1, applyInjury(state,'left_arm',{type='electrical',damage=82,pain=80,burn=4,nerve=85,source='medadmin_test'}))
        state.status.shock=82; setFlags(state,{electricalInjury=true,dysrhythmia=true})
    elseif scenarioId == 'pneumothorax' then
        state = select(1, applyInjury(state,'chest',{type='thoracic',damage=72,pain=78,internalBleeding=true,organ='right_lung',organDamage=82,source='medadmin_test'}))
        state.vitals.spo2=72; state.vitals.rr=36; state.vitals.systolic=76; state.status.shock=88; setFlags(state,{pneumothorax=true,tensionPneumothorax=true,airwayRisk=true})
    elseif scenarioId == 'internal_bleeding' then
        state = select(1, applyInjury(state,'abdomen',{type='internal_hemorrhage',damage=68,pain=48,internalBleeding=true,organ='spleen',organDamage=72,source='medadmin_test'}))
        state.vitals.blood=2700; state.status.shock=78; setFlags(state,{occultHemorrhage=true})
    elseif scenarioId == 'hypovolemic_shock' then
        state = select(1, applyInjury(state,'left_leg',{type='hemorrhage',damage=70,pain=65,bleeding='arterial',source='medadmin_test'}))
        state.vitals.blood=1750; state.vitals.systolic=66; state.vitals.diastolic=35; state.vitals.hr=154; state.vitals.rr=34; state.vitals.spo2=84; state.status.shock=96; state.status.unconscious=true
    elseif scenarioId == 'respiratory_failure' then
        state.vitals.spo2=64; state.vitals.rr=6; state.vitals.hr=118; state.vitals.etco2=68; state.status.shock=70; state.status.unconscious=true; setCondition(state,'respiratory_failure',{severity=95}); setFlags(state,{airwayRisk=true,ventilationRequired=true})
    elseif scenarioId == 'cardiac_arrest' then
        state.status.cardiacArrest=true; state.status.unconscious=true; state.vitals.hr=0; state.vitals.rr=0; state.vitals.spo2=55; state.vitals.systolic=0; state.vitals.diastolic=0; setFlags(state,{cardiacRhythm='ventricular_fibrillation',shockableRhythm=true}); lifeState='incapacitated'
    elseif scenarioId == 'pea_arrest' then
        state.status.cardiacArrest=true; state.status.unconscious=true; state.vitals.hr=0; state.vitals.rr=0; state.vitals.spo2=52; state.vitals.systolic=0; state.vitals.diastolic=0; setFlags(state,{cardiacRhythm='pea',shockableRhythm=false}); lifeState='incapacitated'
    elseif scenarioId == 'sepsis' then
        setCondition(state,'sepsis',{severity=92,source='pneumonia',suspected=true}); state.infection=state.infection or{}; state.infection.suspected=true; state.infection.source='lung'; state.vitals.temp=104.2; state.vitals.hr=142; state.vitals.rr=34; state.vitals.systolic=72; state.vitals.diastolic=38; state.vitals.spo2=86; state.status.shock=91; state.labs=state.labs or{}; state.labs.wbc=23; state.labs.ph=7.22; state.labs.lactate=6.2
    elseif scenarioId == 'opioid_overdose' then
        setCondition(state,'opioid_overdose',{severity=90,agent='fentanyl'}); state.vitals.rr=4; state.vitals.spo2=68; state.vitals.hr=48; state.vitals.etco2=72; state.status.unconscious=true; setFlags(state,{pinpointPupils=true,naloxoneIndicated=true,airwayRisk=true})
    elseif scenarioId == 'drowning' then
        setCondition(state,'drowning',{severity=88,aspiration=true}); state.vitals.spo2=70; state.vitals.rr=8; state.vitals.temp=94.0; state.status.unconscious=true; state.status.shock=75; setFlags(state,{aspiration=true,airwayRisk=true})
    elseif scenarioId == 'electrocution' then
        state = select(1, applyInjury(state,'left_arm',{type='electrical',damage=58,pain=70,burn=3,nerve=65,source='medadmin_test'}))
        setCondition(state,'electrical_injury',{severity=82}); state.vitals.hr=190; state.status.shock=74; setFlags(state,{cardiacRhythm='ventricular_tachycardia',dysrhythmia=true})
    elseif scenarioId == 'hypothermia' then
        setCondition(state,'hypothermia',{severity=92}); state.vitals.temp=85.5; state.vitals.hr=34; state.vitals.rr=6; state.vitals.spo2=82; state.status.unconscious=true; setFlags(state,{cardiacRhythm='sinus_bradycardia',rewarmingRequired=true})
    elseif scenarioId == 'heatstroke' then
        setCondition(state,'heatstroke',{severity=94}); state.vitals.temp=107.1; state.vitals.hr=158; state.vitals.rr=36; state.vitals.systolic=78; state.status.shock=88; state.status.unconscious=true; setFlags(state,{rapidCoolingRequired=true,organFailureRisk=true})
    elseif scenarioId == 'diabetic_emergency' then
        setCondition(state,'dka',{severity=88}); state.vitals.glucose=520; state.vitals.hr=132; state.vitals.rr=34; state.vitals.systolic=84; state.status.shock=68; state.labs=state.labs or{}; state.labs.ph=7.12; state.labs.hco3=10; state.labs.potassium=5.8; setFlags(state,{kussmaulRespirations=true,dehydration=true})
    elseif scenarioId == 'anaphylaxis' then
        setCondition(state,'anaphylaxis',{severity=95,allergen='test exposure'}); state.vitals.spo2=74; state.vitals.rr=38; state.vitals.hr=146; state.vitals.systolic=64; state.status.shock=94; setFlags(state,{airwaySwelling=true,bronchospasm=true,epinephrineIndicated=true,airwayRisk=true})
    elseif scenarioId == 'precision_lethal_triad' then
        state = select(1, applyInjury(state,'abdomen',{type='hemorrhage',damage=82,pain=78,bleeding='arterial',internalBleeding=true,organ='liver',organDamage=75,source='medadmin_test'}))
        state.vitals.blood=2100;state.vitals.temp=93.4;state.vitals.spo2=78;state.vitals.hr=148;state.vitals.rr=36;state.vitals.systolic=68;state.status.shock=96
        state.labs=state.labs or{};state.labs.ph=7.08;state.labs.inr=3.1;state.labs.platelets=42;state.labs.hemoglobin=6.4;state.labs.creatinine=2.0
        state.fluids=state.fluids or{};state.fluids.urineMlHr=8;setFlags(state,{damageControlRequired=true,massiveHemorrhage=true})
    elseif scenarioId == 'precision_ards' then
        state = select(1, applyInjury(state,'chest',{type='pulmonary',damage=86,pain=74,internalBleeding=true,organ='left_lung',organDamage=82,source='medadmin_test'}))
        state.vitals.spo2=68;state.vitals.rr=42;state.vitals.etco2=58;state.status.shock=74
        state.respiration=state.respiration or{};state.respiration.pneumothorax=true;state.respiration.oxygenLpm=15;setFlags(state,{ards=true,ventilationRequired=true})
    elseif scenarioId == 'precision_aki' then
        state.vitals.systolic=78;state.vitals.diastolic=42;state.vitals.hr=122;state.status.shock=72
        state.labs=state.labs or{};state.labs.creatinine=4.4;state.labs.potassium=6.1;state.labs.ph=7.24
        state.fluids=state.fluids or{};state.fluids.urineMlHr=4;setCondition(state,'acute_kidney_injury',{severity=92,stage=3});setFlags(state,{renalProtectionRequired=true})
    elseif scenarioId == 'precision_neuro_crisis' then
        state = select(1, applyInjury(state,'head',{type='blunt',damage=92,pain=92,internalBleeding=true,fracture='compound',organ='brain',organDamage=92,nerve=45,source='medadmin_test'}))
        state.vitals.systolic=82;state.vitals.diastolic=44;state.vitals.hr=52;state.vitals.spo2=88;state.status.unconscious=true
        state.neuro=state.neuro or{};state.neuro.gcs=6;setFlags(state,{tbi=true,herniationRisk=true,neuroSurgeryRequired=true})
    elseif scenarioId == 'precision_medication_safety' then
        state.vitals.systolic=82;state.vitals.diastolic=45;state.vitals.hr=54;state.vitals.rr=7;state.vitals.spo2=84;state.vitals.etco2=66;state.status.unconscious=true
        state.medicationAdministration={{id='TEST-OPIOID',medication='morphine',dose=10,route='iv',riskWeight=10,status='active',administeredAt=os.time()}}
        setFlags(state,{medicationSafetyChallenge=true,airwayRisk=true})
    elseif scenarioId == 'adaptive_electrolyte_storm' then
        state.vitals.hr=178;state.vitals.rr=30;state.vitals.spo2=91;state.vitals.systolic=86;state.vitals.diastolic=48;state.status.shock=72
        state.labs=state.labs or{};state.labs.sodium=122;state.labs.potassium=6.8;state.labs.chloride=91;state.labs.hco3=12;state.labs.magnesium=1.0;state.labs.calcium=7.1;state.labs.ph=7.16
        setFlags(state,{qtRisk=true,dysrhythmia=true,electrolyteEmergency=true})
    elseif scenarioId == 'adaptive_polypharmacy' then
        state.vitals.hr=46;state.vitals.rr=6;state.vitals.spo2=78;state.vitals.systolic=76;state.vitals.diastolic=40;state.status.unconscious=true
        state.labs=state.labs or{};state.labs.creatinine=4.8;state.labs.bilirubin=6.2;state.labs.inr=2.4;state.labs.albumin=2.2
        state.medicationAdministration={{id='V9-MORPH',medication='morphine',dose=10,route='iv',status='active',administeredAt=os.time()-900},{id='V9-MIDAZ',medication='midazolam',dose=8,route='iv',status='active',administeredAt=os.time()-600},{id='V9-FENT',medication='fentanyl',dose=150,route='iv',status='active',administeredAt=os.time()-300}}
        setFlags(state,{polypharmacy=true,clearanceFailure=true,airwayRisk=true})
    elseif scenarioId == 'adaptive_hepatic_failure' then
        state.vitals.hr=118;state.vitals.rr=24;state.vitals.systolic=88;state.vitals.diastolic=50;state.status.shock=58
        state.labs=state.labs or{};state.labs.bilirubin=12.5;state.labs.inr=3.4;state.labs.albumin=1.9;state.labs.ast=980;state.labs.alt=1120;state.labs.glucose=54
        state.neuro=state.neuro or{};state.neuro.gcs=10;setCondition(state,'acute_hepatic_failure',{severity=95});setFlags(state,{encephalopathy=true,coagulopathy=true})
    elseif scenarioId == 'adaptive_endocrine_crisis' then
        state.vitals.glucose=760;state.vitals.hr=142;state.vitals.rr=32;state.vitals.systolic=72;state.vitals.diastolic=38;state.status.shock=86
        state.labs=state.labs or{};state.labs.sodium=154;state.labs.potassium=5.9;state.labs.chloride=116;state.labs.hco3=10;state.labs.bun=62;state.labs.creatinine=3.6;state.labs.ph=7.10
        setCondition(state,'hyperosmolar_endocrine_crisis',{severity=96});setFlags(state,{severeDehydration=true,osmoticEmergency=true})
    elseif scenarioId == 'adaptive_post_rosc' then
        state.vitals.hr=154;state.vitals.rr=10;state.vitals.spo2=84;state.vitals.systolic=68;state.vitals.diastolic=36;state.vitals.temp=95.0;state.status.shock=92;state.status.unconscious=true
        state.labs=state.labs or{};state.labs.ph=7.08;state.labs.lactate=9.5;state.labs.potassium=5.8;state.neuro=state.neuro or{};state.neuro.gcs=5
        setCondition(state,'post_rosc_syndrome',{severity=95});setFlags(state,{postROSC=true,rearrestRisk=true,temperatureControlRequired=true})
    elseif scenarioId == 'adaptive_multi_organ_failure' then
        state.vitals.blood=2400;state.vitals.hr=150;state.vitals.rr=38;state.vitals.spo2=72;state.vitals.systolic=62;state.vitals.diastolic=34;state.vitals.temp=104.4;state.status.shock=98;state.status.unconscious=true
        state.labs=state.labs or{};state.labs.ph=7.02;state.labs.lactate=11.2;state.labs.creatinine=5.2;state.labs.bilirubin=10.4;state.labs.inr=3.0;state.labs.platelets=38;state.labs.potassium=6.3;state.labs.sodium=128;state.labs.hco3=9
        state.neuro=state.neuro or{};state.neuro.gcs=4;state.infection=state.infection or{};state.infection.suspected=true;state.infection.source='unknown';state.fluids=state.fluids or{};state.fluids.urineMlHr=2
        setCondition(state,'multi_organ_failure',{severity=100});setFlags(state,{multiOrganFailure=true,criticalCareRequired=true})
    elseif scenarioId == 'v10_exsanguination_command' then
        state = select(1, applyInjury(state,'chest',{type='gunshot',damage=92,pain=95,bleeding='arterial',internalBleeding=true,organ='right_lung',organDamage=88,source='medadmin_test'}))
        state = select(1, applyInjury(state,'abdomen',{type='blast',damage=88,pain=90,bleeding='arterial',internalBleeding=true,organ='liver',organDamage=85,source='medadmin_test'}))
        state.vitals.blood=1750;state.vitals.spo2=70;state.vitals.hr=168;state.vitals.rr=40;state.vitals.systolic=54;state.vitals.diastolic=28;state.vitals.temp=92.8;state.status.shock=100;state.status.unconscious=true
        state.labs=state.labs or{};state.labs.ph=6.98;state.labs.hco3=9;state.labs.lactate=13.5;state.labs.inr=4.0;state.labs.platelets=28;state.labs.fibrinogen=70;setFlags(state,{massiveHemorrhage=true,criticalCareRequired=true})
    elseif scenarioId == 'v10_mixed_abg_failure' then
        state.vitals.spo2=61;state.vitals.rr=6;state.vitals.etco2=72;state.vitals.hr=138;state.vitals.systolic=76;state.vitals.diastolic=42;state.status.unconscious=true
        state.labs=state.labs or{};state.labs.ph=6.99;state.labs.paco2=78;state.labs.pao2=42;state.labs.hco3=14;state.labs.lactate=8.8;setFlags(state,{ventilationFailure=true,oxygenationFailure=true,airwayRisk=true})
    elseif scenarioId == 'v10_toxicology_collapse' then
        state.vitals.hr=42;state.vitals.rr=4;state.vitals.spo2=66;state.vitals.systolic=62;state.vitals.diastolic=34;state.vitals.etco2=76;state.status.unconscious=true
        state.labs=state.labs or{};state.labs.ph=7.08;state.labs.paco2=74;state.labs.hco3=30;state.medicationAdministration={{id='V10-MORPH',medication='morphine',dose=20,route='iv',status='active',administeredAt=os.time()-300},{id='V10-FENT',medication='fentanyl',dose=250,route='iv',status='active',administeredAt=os.time()-180},{id='V10-MIDAZ',medication='midazolam',dose=12,route='iv',status='active',administeredAt=os.time()-120}};setCondition(state,'opioid_toxicity',{severity=100});setFlags(state,{toxicologyEmergency=true,airwayRisk=true})
    elseif scenarioId == 'v10_neuro_oxygen_crisis' then
        state = select(1, applyInjury(state,'head',{type='blunt',damage=98,pain=95,internalBleeding=true,fracture='compound',organ='brain',organDamage=95,nerve=55,source='medadmin_test'}))
        state.vitals.spo2=72;state.vitals.hr=48;state.vitals.systolic=74;state.vitals.diastolic=40;state.vitals.rr=8;state.status.unconscious=true;state.neuro=state.neuro or{};state.neuro.gcs=4
        state.labs=state.labs or{};state.labs.ph=7.18;state.labs.lactate=6.0;setFlags(state,{herniationRisk=true,neuroSurgeryRequired=true,airwayRisk=true})
    elseif scenarioId == 'v10_closed_loop_gap_test' then
        state = select(1, applyInjury(state,'left_leg',{type='arterial_laceration',damage=78,pain=86,bleeding='arterial',fracture='compound',source='medadmin_test'}))
        state.vitals.blood=2600;state.vitals.spo2=84;state.vitals.hr=148;state.vitals.systolic=72;state.vitals.diastolic=38;state.vitals.temp=94.8;state.status.shock=92
        state.labs=state.labs or{};state.labs.ph=7.16;state.labs.hco3=15;state.labs.lactate=7.8;state.labs.inr=2.4;state.labs.platelets=72;state.labs.fibrinogen=120
    elseif scenarioId == 'v10_mci_command_patient' then
        state = select(1, applyInjury(state,'chest',{type='blast',damage=84,pain=88,bleeding='arterial',internalBleeding=true,fracture='compound',organ='left_lung',organDamage=78,source='medadmin_test'}))
        state = select(1, applyInjury(state,'pelvis',{type='crush',damage=90,pain=94,internalBleeding=true,fracture='compound',organ='femoral_artery',organDamage=80,source='medadmin_test'}))
        state = select(1, applyInjury(state,'right_arm',{type='burn',damage=65,pain=70,burn=3,nerve=35,source='medadmin_test'}))
        state.vitals.blood=2050;state.vitals.spo2=69;state.vitals.hr=160;state.vitals.rr=38;state.vitals.systolic=58;state.vitals.diastolic=30;state.status.shock=98;state.status.unconscious=true
        state.labs=state.labs or{};state.labs.ph=7.04;state.labs.lactate=11.0;state.labs.inr=3.2;state.labs.platelets=44;state.labs.fibrinogen=90;setFlags(state,{mciTag='red',massiveHemorrhage=true,criticalCareRequired=true});lifeState='incapacitated'
    elseif scenarioId == 'v11_refractory_septic_shock' then
        state.vitals.hr=152;state.vitals.rr=36;state.vitals.spo2=84;state.vitals.systolic=58;state.vitals.diastolic=28;state.vitals.temp=104.2;state.vitals.blood=4300
        state.labs=state.labs or{};state.labs.ph=7.12;state.labs.hco3=14;state.labs.paco2=31;state.labs.lactate=9.4;state.labs.wbc=24;state.labs.crp=24;state.labs.procalcitonin=8.2;state.labs.creatinine=3.4;state.labs.glucose=210
        state.conditions=state.conditions or{};state.conditions.sepsis={severity=100};state.conditions.pneumonia={severity=90};state.flags=state.flags or{};state.flags.infectionSource='pneumonia';state.flags.antimicrobialDelayMinutes=75;state.status.shock=98;state.status.unconscious=true;lifeState='incapacitated'
    elseif scenarioId == 'v11_endocrine_collapse' then
        state.vitals.hr=142;state.vitals.rr=40;state.vitals.spo2=94;state.vitals.systolic=76;state.vitals.diastolic=42;state.vitals.temp=99.8;state.vitals.blood=3900
        state.labs=state.labs or{};state.labs.ph=7.05;state.labs.hco3=8;state.labs.paco2=19;state.labs.lactate=5.0;state.labs.glucose=680;state.labs.ketones=6.8;state.labs.sodium=122;state.labs.potassium=6.7;state.labs.creatinine=2.8
        state.conditions=state.conditions or{};state.conditions.diabetic_ketoacidosis={severity=100};state.status.shock=86;state.status.unconscious=true;lifeState='incapacitated'
    elseif scenarioId == 'v11_transfusion_complication' then
        state = select(1, applyInjury(state,'abdomen',{type='gunshot',damage=72,pain=80,internalBleeding=true,organ='liver',organDamage=55,source='medadmin_test'}))
        state.vitals.hr=128;state.vitals.rr=30;state.vitals.spo2=86;state.vitals.systolic=82;state.vitals.diastolic=44;state.vitals.temp=93.2;state.vitals.blood=4700
        state.labs=state.labs or{};state.labs.ph=7.18;state.labs.hco3=16;state.labs.lactate=6.5;state.labs.inr=2.8;state.labs.platelets=52;state.labs.fibrinogen=95;state.labs.calcium=6.1;state.labs.potassium=5.9
        state.flags=state.flags or{};state.flags.transfusionStarted=true;state.flags.massiveTransfusion=true;state.status.shock=82
    elseif scenarioId == 'v11_ventilator_dyssynchrony' then
        state.vitals.hr=138;state.vitals.rr=42;state.vitals.spo2=70;state.vitals.systolic=88;state.vitals.diastolic=52;state.vitals.temp=101.6;state.vitals.etco2=68
        state.labs=state.labs or{};state.labs.ph=7.09;state.labs.hco3=21;state.labs.paco2=76;state.labs.pao2=48;state.labs.lactate=5.8
        state.organSupport=state.organSupport or{};state.organSupport.ventilator={mode='volume_control',fio2=.9,peep=12};state.medicationAdministration={{medication='midazolam',dose=12,status='active'},{medication='fentanyl',dose=250,status='active'}}
        state.conditions=state.conditions or{};state.conditions.ards={severity=95};state.flags=state.flags or{};state.flags.ventilatorDyssynchrony=true;state.status.unconscious=true
    elseif scenarioId == 'v11_device_infection' then
        state.vitals.hr=126;state.vitals.rr=28;state.vitals.spo2=91;state.vitals.systolic=84;state.vitals.diastolic=48;state.vitals.temp=103.0
        state.labs=state.labs or{};state.labs.ph=7.25;state.labs.hco3=18;state.labs.lactate=5.6;state.labs.wbc=20;state.labs.crp=18;state.labs.procalcitonin=5.4
        state.conditions=state.conditions or{};state.conditions.central_line_infection={severity=90};state.devices={central_line={type='central_line',status='active',invasive=true,insertedAt=os.time()-86400*8,reviewAfterDays=3},foley={type='foley',status='active',invasive=true,insertedAt=os.time()-86400*6,reviewAfterDays=2}}
        state.flags=state.flags or{};state.flags.infectionSource='central_line';state.flags.antimicrobialDelayMinutes=45;state.status.shock=72
    elseif scenarioId == 'v11_frail_polytrauma' then
        state.demographics=state.demographics or{};state.demographics.age=82;state.demographics.weightKg=52;state.demographics.heightCm=165;state.demographics.baselineMobility=45;state.demographics.baselineCognition=70
        state = select(1, applyInjury(state,'head',{type='blunt',damage=68,pain=74,internalBleeding=true,fracture='closed',organ='brain',organDamage=48,source='medadmin_test'}))
        state = select(1, applyInjury(state,'chest',{type='blunt',damage=72,pain=82,internalBleeding=true,fracture='closed',organ='left_lung',organDamage=52,source='medadmin_test'}))
        state = select(1, applyInjury(state,'pelvis',{type='collision',damage=78,pain=88,internalBleeding=true,fracture='compound',source='medadmin_test'}))
        state.vitals.hr=136;state.vitals.rr=32;state.vitals.spo2=82;state.vitals.systolic=72;state.vitals.diastolic=38;state.vitals.blood=2450;state.vitals.temp=95.0;state.status.shock=90;state.status.unconscious=true
        state.labs=state.labs or{};state.labs.ph=7.17;state.labs.hco3=15;state.labs.lactate=7.2;state.labs.creatinine=2.2;state.conditions=state.conditions or{};state.conditions.heart_failure={severity=55};state.conditions.chronic_kidney_disease={severity=55};lifeState='incapacitated'
    elseif scenarioId == 'v12_pediatric_septic_shock' then
        state.demographics=state.demographics or{};state.demographics.age=6;state.demographics.weightKg=22;state.demographics.heightCm=118
        state.vitals.hr=168;state.vitals.rr=44;state.vitals.spo2=82;state.vitals.systolic=60;state.vitals.diastolic=32;state.vitals.temp=104.0;state.vitals.blood=1100
        state.labs=state.labs or{};state.labs.ph=7.14;state.labs.hco3=13;state.labs.paco2=38;state.labs.pao2=55;state.labs.lactate=7.8;state.labs.creatinine=1.8;state.labs.potassium=5.7;state.labs.glucose=58;state.labs.wbc=22;state.labs.procalcitonin=6.2
        state.conditions=state.conditions or{};state.conditions.sepsis={severity=100};state.conditions.pneumonia={severity=85};state.flags=state.flags or{};state.flags.infectionSource='pneumonia';state.status.shock=96;state.status.unconscious=true;lifeState='incapacitated'
    elseif scenarioId == 'v12_obstetric_hemorrhage' then
        state.demographics=state.demographics or{};state.demographics.age=28;state.demographics.weightKg=78;state.demographics.heightCm=168;state.demographics.pregnancy=true;state.demographics.pregnancyWeeks=40
        state.vitals.hr=156;state.vitals.rr=34;state.vitals.spo2=88;state.vitals.systolic=62;state.vitals.diastolic=30;state.vitals.temp=95.0;state.vitals.blood=2300
        state.labs=state.labs or{};state.labs.ph=7.12;state.labs.hco3=14;state.labs.lactate=8.9;state.labs.inr=2.7;state.labs.platelets=58;state.labs.fibrinogen=85;state.labs.hemoglobin=5.8
        state.conditions=state.conditions or{};state.conditions.postpartum_hemorrhage={severity=100};state.flags=state.flags or{};state.flags.postpartum=true;state.flags.postpartumHours=2;state.flags.postpartumHemorrhage=true;state.flags.massiveHemorrhage=true;state.status.shock=99;state.status.unconscious=true;lifeState='incapacitated'
    elseif scenarioId == 'v12_cardiogenic_shock' then
        state.vitals.hr=138;state.vitals.rr=34;state.vitals.spo2=78;state.vitals.systolic=64;state.vitals.diastolic=46;state.vitals.temp=97.2;state.vitals.blood=5000
        state.labs=state.labs or{};state.labs.ph=7.20;state.labs.hco3=17;state.labs.paco2=48;state.labs.pao2=52;state.labs.lactate=7.6;state.labs.creatinine=2.6;state.labs.troponin=18
        state.conditions=state.conditions or{};state.conditions.cardiogenic_shock={severity=100};state.conditions.heart_failure={severity=95};state.conditions.pulmonary_edema={severity=90};state.hemodynamics=state.hemodynamics or{};state.hemodynamics.cardiacOutput=1.6;state.status.shock=96;state.status.unconscious=true;lifeState='incapacitated'
    elseif scenarioId == 'v12_ards_ecmo' then
        state.vitals.hr=132;state.vitals.rr=40;state.vitals.spo2=62;state.vitals.systolic=82;state.vitals.diastolic=46;state.vitals.temp=102.2;state.vitals.etco2=72
        state.labs=state.labs or{};state.labs.ph=7.07;state.labs.hco3=19;state.labs.paco2=78;state.labs.pao2=42;state.labs.lactate=5.4
        state.conditions=state.conditions or{};state.conditions.ards={severity=100};state.organSupport=state.organSupport or{};state.organSupport.ventilator={mode='volume_control',fio2=1.0,peep=14,tidalVolumeMl=650,plateauPressure=38,peakPressure=45,rate=30};state.flags=state.flags or{};state.flags.oxygenationFailure=true;state.flags.ventilationFailure=true;state.status.unconscious=true;lifeState='incapacitated'
    elseif scenarioId == 'v12_renal_hyperkalemia' then
        state.vitals.hr=48;state.vitals.rr=30;state.vitals.spo2=92;state.vitals.systolic=88;state.vitals.diastolic=50;state.vitals.temp=97.0
        state.labs=state.labs or{};state.labs.ph=7.08;state.labs.hco3=10;state.labs.paco2=24;state.labs.lactate=4.0;state.labs.creatinine=7.2;state.labs.potassium=7.4;state.labs.bun=110;state.labs.glucose=120
        state.conditions=state.conditions or{};state.conditions.acute_renal_failure={severity=100};state.conditions.hyperkalemia={severity=100};state.fluids=state.fluids or{};state.fluids.urineMlHr=2;state.flags=state.flags or{};state.flags.dialysisRequired=true;state.status.shock=72
    elseif scenarioId == 'v12_network_degradation' then
        state = select(1, applyInjury(state,'chest',{type='blunt',damage=75,pain=80,internalBleeding=true,fracture='closed',organ='left_lung',organDamage=60,source='medadmin_test'}))
        state.vitals.hr=146;state.vitals.rr=36;state.vitals.spo2=76;state.vitals.systolic=70;state.vitals.diastolic=38;state.vitals.blood=2600;state.vitals.temp=95.5
        state.labs=state.labs or{};state.labs.ph=7.16;state.labs.lactate=7.1;state.labs.paco2=55;state.labs.pao2=50;state.flags=state.flags or{};state.flags.staleData=true;state.lastObservationAt=os.time()-1200;state.status.shock=90;state.status.unconscious=true;lifeState='incapacitated'
    elseif scenarioId == 'v14_occult_hemorrhage' then
        state=select(1,applyInjury(state,'abdomen',{type='blunt_trauma',damage=78,pain=42,internalBleeding=true,organ='spleen',organDamage=72,source='medadmin_test'}))
        state=select(1,applyInjury(state,'pelvis',{type='fracture',damage=82,pain=58,internalBleeding=true,fracture='unstable',source='medadmin_test'}))
        state.vitals.blood=3250;state.vitals.hr=118;state.vitals.systolic=98;state.vitals.diastolic=62;state.status.shock=48;state.labs=state.labs or{};state.labs.lactate=4.8
    elseif scenarioId == 'v14_compartment_syndrome' then
        state=select(1,applyInjury(state,'left_leg',{type='crush',damage=88,pain=96,fracture='closed',source='medadmin_test'}));state.vitals.hr=126;state.status.pain=94;state.flags=state.flags or{};state.flags.limbSwelling=true;state.labs=state.labs or{};state.labs.ck=9200;state.labs.potassium=5.8
    elseif scenarioId == 'v14_crush_rhabdomyolysis' then
        state=select(1,applyInjury(state,'right_leg',{type='crush',damage=94,pain=88,fracture='compound',source='medadmin_test'}));state=select(1,applyInjury(state,'pelvis',{type='crush',damage=72,pain=82,source='medadmin_test'}));state.vitals.hr=142;state.vitals.systolic=82;state.status.shock=78;state.labs=state.labs or{};state.labs.ck=18000;state.labs.potassium=7.1;state.labs.creatinine=3.2;state.labs.ph=7.12;state.labs.lactate=7.4
    elseif scenarioId == 'v14_massive_transfusion_complication' then
        state.vitals.blood=2600;state.vitals.hr=138;state.vitals.systolic=78;state.vitals.temperature=33.0;state.vitals.spo2=84;state.status.shock=84;state.v14TransfusionLog={{product='packed_cells',amount=10},{product='plasma',amount=3},{product='platelets',amount=1},{product='crystalloid',amount=4000}};state.labs=state.labs or{};state.labs.ionizedCalcium=.62;state.labs.fibrinogen=85;state.labs.platelets=55;state.labs.ph=7.06
    elseif scenarioId == 'v14_airway_failure' then
        state.vitals.rr=5;state.vitals.spo2=66;state.vitals.hr=52;state.vitals.systolic=76;state.status.unconscious=true;state.status.airwayObstructed=true;state.status.vomiting=true;state.neurological=state.neurological or{};state.neurological.gcs=6;state.labs=state.labs or{};state.labs.etco2=72;state.labs.paco2=78;state.labs.pao2=42;state.labs.ph=6.98
    elseif scenarioId == 'v14_damage_control_resuscitation' then
        state=select(1,applyInjury(state,'chest',{type='gunshot',damage=86,pain=82,internalBleeding=true,organ='right_lung',organDamage=78,source='medadmin_test'}));state=select(1,applyInjury(state,'abdomen',{type='gunshot',damage=92,pain=88,internalBleeding=true,organ='liver',organDamage=90,source='medadmin_test'}));state.vitals.blood=1850;state.vitals.hr=158;state.vitals.systolic=58;state.vitals.diastolic=28;state.vitals.spo2=72;state.vitals.rr=8;state.vitals.temperature=32.4;state.status.shock=99;state.labs=state.labs or{};state.labs.lactate=12.5;state.labs.ph=6.92;state.labs.platelets=38;state.labs.fibrinogen=55;state.labs.inr=3.4;state.labs.ionizedCalcium=.58
    elseif scenarioId == 'v13_coagulopathy_collapse' then
        state = select(1, applyInjury(state,'abdomen',{type='internal_hemorrhage',damage=86,pain=70,internalBleeding=true,organ='liver',organDamage=82,source='medadmin_test'}))
        state.vitals.blood=2100;state.vitals.systolic=68;state.vitals.diastolic=34;state.vitals.hr=152;state.vitals.temperature=33.0;state.status.shock=95
        state.labs=state.labs or{};state.labs.platelets=42;state.labs.fibrinogen=70;state.labs.inr=2.8;state.labs.ionizedCalcium=.70;state.labs.ph=7.02;state.labs.lactate=10.5
    elseif scenarioId == 'v13_polypharmacy_toxicity' then
        state.vitals.rr=5;state.vitals.spo2=72;state.vitals.hr=48;state.vitals.systolic=74;state.status.unconscious=true;state.status.shock=72
        state.medications={morphine={name='morphine',class='opioid',dose=20,renalClearance=true,active=true},midazolam={name='midazolam',class='sedative',dose=12,hepaticClearance=true,active=true},amiodarone={name='amiodarone',class='antiarrhythmic',dose=300,qtRisk=true,active=true}}
        state.labs=state.labs or{};state.labs.egfr=18;state.labs.creatinine=4.0;state.labs.alt=550;state.labs.ast=620
    elseif scenarioId == 'v13_immunologic_storm' then
        state.vitals.temperature=40.2;state.vitals.hr=148;state.vitals.rr=36;state.vitals.systolic=70;state.vitals.diastolic=35;state.vitals.spo2=86;state.status.shock=94
        state.labs=state.labs or{};state.labs.wbc=25;state.labs.crp=240;state.labs.lactate=9.2;state.labs.creatinine=2.9;state.conditions=state.conditions or{};state.conditions.sepsis={active=true,severity=98};state.conditions.contagious_infection={active=true,severity=75};state.devices={central_line={active=true,reviewDue=true},urinary_catheter={active=true,reviewDue=true}}
    elseif scenarioId == 'v13_prolonged_field_care' then
        state = select(1, applyInjury(state,'chest',{type='gunshot',damage=74,pain=80,internalBleeding=true,organ='left_lung',organDamage=65,source='medadmin_test'}))
        state = select(1, applyInjury(state,'left_leg',{type='fracture',damage=72,pain=82,bleeding='venous',fracture='compound',source='medadmin_test'}))
        state.vitals.blood=2850;state.vitals.spo2=83;state.vitals.hr=136;state.vitals.systolic=82;state.vitals.temperature=34.1;state.status.shock=82;state.flags=state.flags or{};state.flags.prolongedFieldCare=true;state.flags.transportDelayMinutes=120
    elseif scenarioId == 'v13_regional_surge_patient' then
        state = select(1, applyInjury(state,'head',{type='blast',damage=65,pain=72,internalBleeding=true,organ='brain',organDamage=48,source='medadmin_test'}))
        state = select(1, applyInjury(state,'chest',{type='blast',damage=78,pain=84,internalBleeding=true,organ='right_lung',organDamage=70,source='medadmin_test'}))
        state = select(1, applyInjury(state,'pelvis',{type='blast',damage=82,pain=88,internalBleeding=true,fracture='compound',source='medadmin_test'}))
        state.vitals.blood=2450;state.vitals.spo2=78;state.vitals.hr=150;state.vitals.systolic=70;state.status.shock=95;state.flags=state.flags or{};state.flags.massCasualty=true;state.flags.regionalSurge=true
    elseif scenarioId == 'v13_recovery_failure' then
        state.demographics=state.demographics or{};state.demographics.age=82;state.status.pain=74;state.mobility=18;state.status.unconscious=false;state.conditions=state.conditions or{};state.conditions.malnutrition={active=true,severity=75};state.conditions.frailty={active=true,severity=85};state.labs=state.labs or{};state.labs.albumin=2.1;state.socialBarriers={score=78,housing=true,caregiver=false};state.recoveryV11=state.recoveryV11 or{};state.recoveryV11.frailty=88
    elseif scenarioId == 'full_injury_matrix' then
        local injuries={
            {'head',{type='blunt',damage=55,pain=65,internalBleeding=true,fracture='closed',organ='brain',organDamage=35}},
            {'neck',{type='laceration',damage=45,pain=60,bleeding='venous',organ='airway',organDamage=25}},
            {'chest',{type='gunshot',damage=78,pain=84,bleeding='arterial',internalBleeding=true,fracture='compound',organ='left_lung',organDamage=68}},
            {'abdomen',{type='stab',damage=66,pain=72,bleeding='venous',internalBleeding=true,organ='liver',organDamage=58}},
            {'pelvis',{type='crush',damage=70,pain=80,internalBleeding=true,fracture='closed',organ='bladder',organDamage=35}},
            {'spine',{type='collision',damage=74,pain=82,fracture='compound',organ='spinal_cord',organDamage=60,nerve=70}},
            {'left_arm',{type='burn',damage=55,pain=62,burn=3,nerve=30}},
            {'right_arm',{type='laceration',damage=42,pain=52,bleeding='arterial',nerve=15}},
            {'left_leg',{type='blunt',damage=72,pain=82,fracture='compound',bleeding='venous'}},
            {'right_leg',{type='electrical',damage=60,pain=70,burn=3,nerve=55}}
        }
        for _,entry in ipairs(injuries)do entry[2].source='medadmin_test';state=select(1,applyInjury(state,entry[1],entry[2])) end
        state.vitals.blood=2200;state.vitals.spo2=76;state.status.shock=92;state.status.unconscious=true;setFlags(state,{fullInjuryMatrix=true})
    elseif scenarioId == 'mass_casualty_red' then
        state = select(1, applyInjury(state,'chest',{type='blast',damage=75,pain=80,bleeding='arterial',internalBleeding=true,fracture='closed',organ='right_lung',organDamage=65,source='medadmin_test'}))
        state = select(1, applyInjury(state,'left_leg',{type='amputation_risk',damage=90,pain=95,bleeding='arterial',fracture='compound',nerve=80,source='medadmin_test'}))
        state.vitals.blood=1900;state.vitals.spo2=72;state.vitals.rr=38;state.status.shock=96;state.status.unconscious=true;setFlags(state,{mciTag='red',massiveHemorrhage=true,airwayRisk=true});lifeState='incapacitated'
    else
        return nil, nil, nil, 'Unknown test scenario: ' .. tostring(scenarioId)
    end

    state = DPN_MED.NormalizeState(state)
    if DPN_MED.EnsureV6Schema then DPN_MED.EnsureV6Schema(state) end
    if DPN_MED.CalculateV6Metrics then DPN_MED.CalculateV6Metrics(state) end
    if DPN_MED.EnsureV8Schema then DPN_MED.EnsureV8Schema(state) end
    if DPN_MED.CalculatePrecisionMetrics then DPN_MED.CalculatePrecisionMetrics(state) end
    if DPN_MED.EnsureV9Schema then DPN_MED.EnsureV9Schema(state) end
    if DPN_MED.CalculateV9Metrics then DPN_MED.CalculateV9Metrics(state) end
    if DPN_MED.EnsureV10Schema then DPN_MED.EnsureV10Schema(state) end
    if DPN_MED.CalculateV10Metrics then DPN_MED.CalculateV10Metrics(state) end
    if DPN_MED.EnsureV11Schema then DPN_MED.EnsureV11Schema(state) end
    if DPN_MED.CalculateV11Metrics then DPN_MED.CalculateV11Metrics(state) end
    if DPN_MED.EnsureV12Schema then DPN_MED.EnsureV12Schema(state) end
    if DPN_MED.CalculateV12Metrics then DPN_MED.CalculateV12Metrics(state) end
    if DPN_MED.EnsureV13Schema then DPN_MED.EnsureV13Schema(state) end
    if DPN_MED.CalculateV13Metrics then DPN_MED.CalculateV13Metrics(state) end

    -- Preserve deliberate test values that the normal recalculation may normalize.
    if scenarioId == 'cardiac_arrest' or scenarioId == 'pea_arrest' then
        state.status.cardiacArrest=true;state.status.unconscious=true;state.vitals.hr=0;state.vitals.rr=0;state.vitals.systolic=0;state.vitals.diastolic=0
    end
    return state, lifeState, details
end

local function catalogById(id)
    for _,item in ipairs(DPN_MED.TestScenarios or {}) do if item.id==id then return item end end
end

local function summarize(state)
    local summary = DPN_MED.GetSummary and DPN_MED.GetSummary(state) or {}
    local twin = DPN_MED.BuildDigitalTwin and DPN_MED.BuildDigitalTwin(state) or nil
    return {
        lifeState=state.status and state.status.lifeState,
        triage=state.status and state.status.triage,
        pain=state.status and state.status.pain,
        shock=state.status and state.status.shock,
        blood=state.vitals and state.vitals.blood,
        hr=state.vitals and state.vitals.hr,
        rr=state.vitals and state.vitals.rr,
        spo2=state.vitals and state.vitals.spo2,
        summary=summary,
        digitalTwin=twin and twin.v6 or nil,
        precision=DPN_MED.BuildPrecisionTwin and DPN_MED.BuildPrecisionTwin(state) or nil,
        adaptive=DPN_MED.BuildV9Twin and DPN_MED.BuildV9Twin(state) or nil
    }
end

local function persistRun(run)
    CreateThread(function()
        pcall(function()
            MySQL.insert.await('INSERT INTO dpn_medical_v7_test_runs (run_id,patient_cid,patient_source,scenario_id,actor,success,result_data) VALUES (?,?,?,?,?,?,?)',{
                run.id,run.patientCid,run.target,run.scenarioId,run.actor,run.success and 1 or 0,json.encode(run)
            })
        end)
    end)
end

local function selfTest()
    local errors, warnings = {}, {}
    local seen = {}
    for _,item in ipairs(DPN_MED.TestScenarios or {}) do
        if not item.id or item.id=='' then errors[#errors+1]='Scenario missing id' end
        if seen[item.id] then errors[#errors+1]='Duplicate scenario id: '..tostring(item.id) end
        seen[item.id]=true
    end
    for part in pairs(Config.BodyParts or {}) do
        if not Config.BodyParts[part] then errors[#errors+1]='Invalid body part: '..tostring(part) end
    end
    for required,_ in pairs({pressure_bandage=true,hemostatic_gauze=true,tourniquet=true,chest_seal=true,splint=true,oxygen=true,iv_fluids=true,blood=true,morphine=true,epinephrine=true,narcan=true,aed=true,surgical_repair=true}) do
        if not Config.Treatments[required] then errors[#errors+1]='Missing treatment: '..required end
    end
    local modules = {}
    local ok, registry = pcall(function() return exports['dpn-medical-core']:GetModules() end)
    if ok and type(registry)=='table' then
        for name,data in pairs(registry) do modules[#modules+1]={name=name,version=data.version} end
    else warnings[#warnings+1]='Module registry unavailable during self-test' end
    return {success=#errors==0,errors=errors,warnings=warnings,scenarios=#(DPN_MED.TestScenarios or{}),modules=modules,generatedAt=os.time()}
end

exports('GetTestScenarioCatalog', function() return DPN_MED.GetTestScenarioCatalog() end)
exports('RunMedicalSelfTest', selfTest)
exports('GetTestRunHistory', function(target) return testRuns[targetId(target) or 0] or {} end)

exports('RestoreTestSnapshot', function(target, actor)
    target=targetId(target);if not target then return false,'Invalid patient' end
    local snapshot=snapshots[target];if not snapshot then return false,'No test snapshot is available for this patient.' end
    local _,cid=stateFor(target);if not cid then return false,'Patient not found' end
    DPNMedicalServer.Commit(target,cid,deepCopy(snapshot),'test_snapshot_restored',{actor=actor or 'medical-admin'})
    snapshots[target]=nil
    TriggerClientEvent('dpn-medical-core:client:resetScreen',target)
    return true,'Previous medical state restored.'
end)

exports('ApplyTestScenario', function(target, scenarioId, options, actor)
    target=targetId(target);scenarioId=tostring(scenarioId or '')
    options=type(options)=='table' and options or{}
    actor=tostring(actor or 'medical-admin'):sub(1,128)
    if scenarioId=='self_test' then
        local report=selfTest();return report.success,report
    end
    if scenarioId=='restore_snapshot' then
        local ok,message=exports['dpn-medical-core']:RestoreTestSnapshot(target,actor);return ok,{message=message,scenarioId=scenarioId}
    end
    local definition=catalogById(scenarioId);if not definition then return false,{message='Unknown test scenario.',scenarioId=scenarioId} end
    local current,cid=stateFor(target);if not current or not cid then return false,{message='Patient not found.',scenarioId=scenarioId} end
    snapshots[target]=deepCopy(current)
    local working=options.resetBefore==false and deepCopy(current) or DPN_MED.NewBodyState()
    if current.profile then working.profile=deepCopy(current.profile) end
    if current.history then working.history=deepCopy(current.history) end
    local state,lifeState,details,errorMessage=applyScenarioState(working,scenarioId)
    if not state then return false,{message=errorMessage or 'Scenario failed.',scenarioId=scenarioId} end
    state.status.lifeState=lifeState or state.status.lifeState or 'alive'
    if state.status.lifeState=='incapacitated' then state.status.incapacitatedAt=os.time() end
    DPNMedicalServer.Commit(target,cid,state,'admin_test_scenario',{scenarioId=scenarioId,actor=actor,resetBefore=options.resetBefore~=false})
    TriggerClientEvent('dpn-medical-core:client:lifeState',target,state.status.lifeState,details or{})
    if state.status.lifeState=='incapacitated' and state.status.cardiacArrest then
        TriggerClientEvent('dpn-medical-core:client:resetDamageTracker',target)
    end
    local result={id=('TEST-%s-%s-%04d'):format(os.time(),target,math.random(0,9999)),scenarioId=scenarioId,label=definition.label,target=target,patientCid=cid,actor=actor,success=true,appliedAt=os.time(),state=summarize(state),message=definition.label..' applied successfully.'}
    testRuns[target]=testRuns[target] or{};table.insert(testRuns[target],1,result);while #testRuns[target]>25 do table.remove(testRuns[target]) end
    persistRun(result)
    TriggerEvent('dpn-medical:server:testScenarioApplied',target,cid,result,state)
    return true,result
end)

RegisterNetEvent('dpn-medical-core:server:requestTestCatalog',function()
    local src=source
    if not DPNMedicalServer.HasAdminPermission(src) then return end
    TriggerClientEvent('dpn-medical-core:client:testCatalog',src,DPN_MED.GetTestScenarioCatalog())
end)

CreateThread(function()
    Wait(2200)
    print(('[dpn-medical-core] %s medical test laboratory with trauma-command scenarios active'):format(VERSION))
end)
