DPN_MED = DPN_MED or {}

-- Canonical medical test catalog used by MedAdmin and automated validation.
-- Scenarios are server-authoritative and never trust client-provided injury data.
DPN_MED.TestScenarios = {
    { id='self_test', label='System Self-Test (Non-destructive)', category='SYSTEM', description='Validate scenario definitions, body regions, treatments, module registry, and core physiology without changing the patient.', nonDestructive=true },
    { id='restore_snapshot', label='Restore Previous Test Snapshot', category='SYSTEM', description='Restore the patient state captured immediately before the most recent test scenario.', confirm=true },
    { id='clean_baseline', label='Reset to Healthy Test Baseline', category='SYSTEM', description='Clear all injuries, conditions, medications, diagnostics, life-state changes, and abnormal vitals.', confirm=true },

    { id='minor_laceration', label='Minor Capillary Laceration', category='TRAUMA', description='Low-severity left-arm laceration with capillary bleeding.' },
    { id='deep_laceration', label='Deep Venous Laceration', category='TRAUMA', description='Deep right-leg laceration with severe pain and venous bleeding.' },
    { id='arterial_hemorrhage', label='Arterial Extremity Hemorrhage', category='TRAUMA', description='Life-threatening left-leg arterial bleed requiring hemorrhage control.', dangerous=true, confirm=true },
    { id='gunshot_chest', label='Gunshot Wound — Chest', category='TRAUMA', description='Penetrating chest trauma with arterial bleeding, lung injury, and internal hemorrhage.', dangerous=true, confirm=true },
    { id='gunshot_abdomen', label='Gunshot Wound — Abdomen', category='TRAUMA', description='Penetrating abdominal trauma with liver damage and internal bleeding.', dangerous=true, confirm=true },
    { id='stab_chest', label='Stab Wound — Chest', category='TRAUMA', description='Penetrating chest wound with venous bleeding and pneumothorax risk.', dangerous=true, confirm=true },
    { id='blunt_tbi', label='Severe Blunt Head Trauma / TBI', category='TRAUMA', description='Head trauma with brain injury, skull fracture, altered consciousness, and airway risk.', dangerous=true, confirm=true },
    { id='closed_leg_fracture', label='Closed Femur Fracture', category='TRAUMA', description='Severe closed left-femur fracture with mobility loss and pain.' },
    { id='compound_arm_fracture', label='Compound Arm Fracture', category='TRAUMA', description='Open right-arm fracture with arterial bleeding and nerve injury.', dangerous=true, confirm=true },
    { id='pelvic_fracture', label='Unstable Pelvic Fracture', category='TRAUMA', description='High-energy pelvic trauma with internal bleeding and femoral-artery risk.', dangerous=true, confirm=true },
    { id='spinal_trauma', label='Severe Spinal Trauma', category='TRAUMA', description='Vertebral and spinal-cord trauma with profound mobility and nerve impairment.', dangerous=true, confirm=true },
    { id='crush_injury', label='Crush Injury / Compartment Syndrome', category='TRAUMA', description='Severe lower-extremity crush trauma with ischemia, nerve damage, and shock.', dangerous=true, confirm=true },
    { id='explosion_polytrauma', label='Explosion Polytrauma', category='TRAUMA', description='Multi-region blast trauma with fractures, burns, internal bleeding, and shock.', dangerous=true, confirm=true },
    { id='vehicle_polytrauma', label='High-Speed Collision Polytrauma', category='TRAUMA', description='Head, chest, pelvis, and extremity trauma representative of a major vehicle collision.', dangerous=true, confirm=true },

    { id='first_degree_burn', label='First-Degree Burn', category='BURNS', description='Superficial chest burn with mild pain.' },
    { id='second_degree_burn', label='Second-Degree Burn', category='BURNS', description='Partial-thickness chest and arm burns with significant pain.' },
    { id='third_degree_burn', label='Third-Degree Burn', category='BURNS', description='Full-thickness chest and arm burns with shock and airway-monitoring requirement.', dangerous=true, confirm=true },
    { id='fourth_degree_burn', label='Fourth-Degree / Electrical Burn', category='BURNS', description='Deep electrical burn with cardiac, muscle, and nerve injury.', dangerous=true, confirm=true },

    { id='pneumothorax', label='Tension Pneumothorax', category='PHYSIOLOGY', description='Critical unilateral lung injury with severe hypoxia and obstructive shock.', dangerous=true, confirm=true },
    { id='internal_bleeding', label='Occult Internal Hemorrhage', category='PHYSIOLOGY', description='Abdominal internal bleeding with progressive hypovolemia and no external wound.', dangerous=true, confirm=true },
    { id='hypovolemic_shock', label='Class IV Hypovolemic Shock', category='PHYSIOLOGY', description='Critical blood loss with hypotension, tachycardia, hypoxia, and altered mental status.', dangerous=true, confirm=true },
    { id='respiratory_failure', label='Acute Respiratory Failure', category='PHYSIOLOGY', description='Severe hypoxia, low respiratory drive, high airway risk, and impending arrest.', dangerous=true, confirm=true },
    { id='cardiac_arrest', label='Cardiac Arrest — Shockable Rhythm', category='PHYSIOLOGY', description='Pulseless ventricular fibrillation requiring CPR, AED/LIFEPAK, and advanced resuscitation.', dangerous=true, confirm=true },
    { id='pea_arrest', label='Cardiac Arrest — PEA', category='PHYSIOLOGY', description='Pulseless electrical activity requiring reversible-cause management rather than defibrillation.', dangerous=true, confirm=true },
    { id='sepsis', label='Septic Shock', category='MEDICAL', description='Severe infection with fever, hypotension, tachycardia, high lactate, and organ dysfunction.', dangerous=true, confirm=true },
    { id='opioid_overdose', label='Opioid Overdose', category='MEDICAL', description='Respiratory depression, hypoxia, pinpoint-pupil flag, and naloxone indication.', dangerous=true, confirm=true },
    { id='drowning', label='Near Drowning', category='MEDICAL', description='Hypoxic respiratory emergency with aspiration, low temperature, and altered consciousness.', dangerous=true, confirm=true },
    { id='electrocution', label='Electrical Injury', category='MEDICAL', description='Electrical burn with dysrhythmia, muscle injury, and arrest risk.', dangerous=true, confirm=true },
    { id='hypothermia', label='Severe Hypothermia', category='MEDICAL', description='Core-temperature emergency with bradycardia, reduced respirations, and dysrhythmia risk.', dangerous=true, confirm=true },
    { id='heatstroke', label='Exertional Heatstroke', category='MEDICAL', description='Extreme hyperthermia with shock, neurologic impairment, and organ-failure risk.', dangerous=true, confirm=true },
    { id='diabetic_emergency', label='Diabetic Ketoacidosis', category='MEDICAL', description='Severe hyperglycemia, dehydration, metabolic acidosis, and respiratory compensation.', dangerous=true, confirm=true },
    { id='anaphylaxis', label='Anaphylactic Shock', category='MEDICAL', description='Airway swelling, bronchospasm, hypoxia, and distributive shock requiring epinephrine.', dangerous=true, confirm=true },

    { id='precision_lethal_triad', label='Precision Trauma Lethal Triad', category='PRECISION V8', description='Hypothermia, acidosis, coagulopathy, hemorrhage and oxygen-delivery failure for damage-control resuscitation testing.', dangerous=true, confirm=true },
    { id='precision_ards', label='Precision ARDS / Ventilation Failure', category='PRECISION V8', description='Severe lung-compliance loss, hypoxemia, high work of breathing and low P/F ratio for ICU and ventilator testing.', dangerous=true, confirm=true },
    { id='precision_aki', label='Precision Acute Kidney Injury', category='PRECISION V8', description='Renal hypoperfusion, oliguria and creatinine elevation for ICU, pharmacy and fluid-management testing.', dangerous=true, confirm=true },
    { id='precision_neuro_crisis', label='Precision Neuro-Perfusion Crisis', category='PRECISION V8', description='Severe TBI with elevated ICP, reduced CPP and low GCS for trauma, radiology and surgery testing.', dangerous=true, confirm=true },
    { id='precision_medication_safety', label='Medication Safety Challenge', category='PRECISION V8', description='Respiratory depression and hypotension state used to verify dose warnings and pharmacy hard stops.', dangerous=true, confirm=true },


    { id='v10_exsanguination_command', label='V10 Exsanguination Command', category='CRITICAL COMMAND V10', description='Uncontrolled external and internal hemorrhage with severe coagulopathy, acidosis, hypothermia and imminent arrest prediction.', dangerous=true, confirm=true },
    { id='v10_mixed_abg_failure', label='V10 Mixed ABG Failure', category='CRITICAL COMMAND V10', description='Combined metabolic and respiratory acidosis with severe oxygenation and ventilation failure.', dangerous=true, confirm=true },
    { id='v10_toxicology_collapse', label='V10 Toxicology Collapse', category='CRITICAL COMMAND V10', description='Opioid and sedative accumulation with respiratory depression, hypotension and antidote recommendations.', dangerous=true, confirm=true },
    { id='v10_neuro_oxygen_crisis', label='V10 Neuro-Oxygen Crisis', category='CRITICAL COMMAND V10', description='Severe TBI, low cerebral perfusion, hypoxemia and herniation risk for neurocritical command testing.', dangerous=true, confirm=true },
    { id='v10_closed_loop_gap_test', label='V10 Closed-Loop Care Gap Test', category='CRITICAL COMMAND V10', description='Creates multiple untreated care gaps to verify bundle creation, assignments, reconciliation and completion tracking.', dangerous=true, confirm=true },
    { id='v10_mci_command_patient', label='V10 MCI Command Patient', category='CRITICAL COMMAND V10', description='Critical blast/polytrauma patient for dispatch escalation, scene command, hospital surge and blood-bank testing.', dangerous=true, confirm=true },

    { id='v11_refractory_septic_shock', label='V11 Refractory Septic Shock', category='AUTONOMOUS CARE V11', description='Severe infection, endothelial failure, vasoplegia, lactic acidosis and escalating organ-support requirements.', dangerous=true, confirm=true },
    { id='v11_endocrine_collapse', label='V11 Endocrine Collapse', category='AUTONOMOUS CARE V11', description='DKA with hyperkalemia, severe dehydration, altered consciousness and high intervention-delay risk.', dangerous=true, confirm=true },
    { id='v11_transfusion_complication', label='V11 Massive Transfusion Complication', category='AUTONOMOUS CARE V11', description='Hypocalcemia, coagulopathy, hypothermia and pulmonary stress after high-volume blood-product resuscitation.', dangerous=true, confirm=true },
    { id='v11_ventilator_dyssynchrony', label='V11 Ventilator Dyssynchrony', category='AUTONOMOUS CARE V11', description='Severe oxygenation failure, high work of breathing and unsafe sedation burden for ventilator strategy testing.', dangerous=true, confirm=true },
    { id='v11_device_infection', label='V11 Device-Associated Infection', category='AUTONOMOUS CARE V11', description='Central-line and urinary-device infection risk with overdue device reviews and sepsis progression.', dangerous=true, confirm=true },
    { id='v11_frail_polytrauma', label='V11 Frail Geriatric Polytrauma', category='AUTONOMOUS CARE V11', description='High-risk multi-system trauma in a frail older patient with low reserve and complex discharge barriers.', dangerous=true, confirm=true },

    { id='v12_pediatric_septic_shock', label='V12 Pediatric Septic Shock', category='INTEGRATED CRITICAL CARE V12', description='Age-adjusted pediatric sepsis with hypotension, respiratory failure, renal stress and pediatric critical-care requirements.', dangerous=true, confirm=true },
    { id='v12_obstetric_hemorrhage', label='V12 Obstetric Hemorrhage', category='INTEGRATED CRITICAL CARE V12', description='Postpartum hemorrhage with massive-transfusion, obstetric, anesthesia and blood-bank coordination requirements.', dangerous=true, confirm=true },
    { id='v12_cardiogenic_shock', label='V12 Cardiogenic Shock', category='INTEGRATED CRITICAL CARE V12', description='Severe pump failure with low cardiac reserve, pulmonary edema and mechanical-circulatory-support evaluation.', dangerous=true, confirm=true },
    { id='v12_ards_ecmo', label='V12 Refractory ARDS / ECMO Evaluation', category='INTEGRATED CRITICAL CARE V12', description='Severe oxygenation failure with unsafe ventilator mechanics and ECMO candidacy.', dangerous=true, confirm=true },
    { id='v12_renal_hyperkalemia', label='V12 Renal Failure / Hyperkalemia', category='INTEGRATED CRITICAL CARE V12', description='Acute renal failure, severe hyperkalemia, acidosis and CRRT evaluation.', dangerous=true, confirm=true },
    { id='v12_network_degradation', label='V12 Network Degradation Drill', category='INTEGRATED CRITICAL CARE V12', description='Creates a critical patient with low data confidence to validate network reconciliation, circuit breakers and trend capture.', dangerous=true, confirm=true },



    { id='v14_occult_hemorrhage', label='V14 Occult Hemorrhage', category='TRAUMA COMMAND V14', description='Unrecognized abdominal and pelvic internal bleeding with initially subtle external signs.', dangerous=true, confirm=true },
    { id='v14_compartment_syndrome', label='V14 Compartment Syndrome', category='TRAUMA COMMAND V14', description='Severe closed limb injury with escalating ischemia and compartment pressure risk.', dangerous=true, confirm=true },
    { id='v14_crush_rhabdomyolysis', label='V14 Crush / Rhabdomyolysis', category='TRAUMA COMMAND V14', description='Prolonged crush injury with hyperkalemia, acidosis, renal risk and dysrhythmia potential.', dangerous=true, confirm=true },
    { id='v14_massive_transfusion_complication', label='V14 Massive Transfusion Complication', category='TRAUMA COMMAND V14', description='Citrate toxicity, hypocalcemia, dilution, hypothermia and pulmonary complication risk.', dangerous=true, confirm=true },
    { id='v14_airway_failure', label='V14 Airway Failure', category='TRAUMA COMMAND V14', description='Unprotected airway, aspiration, hypercapnia and severe ventilation failure.', dangerous=true, confirm=true },
    { id='v14_damage_control_resuscitation', label='V14 Damage-Control Resuscitation', category='TRAUMA COMMAND V14', description='Combined hemorrhage, coagulopathy, hypothermia and procedure-readiness failure.', dangerous=true, confirm=true },

    { id='v13_coagulopathy_collapse', label='V13 Coagulopathy Collapse', category='CONTINUUM COMMAND V13', description='Hemorrhage with thrombocytopenia, low fibrinogen, hypocalcemia, acidosis and hypothermia.', dangerous=true, confirm=true },
    { id='v13_polypharmacy_toxicity', label='V13 Polypharmacy Toxicity', category='CONTINUUM COMMAND V13', description='Opioid, sedative and QT medication burden with renal and hepatic accumulation.', dangerous=true, confirm=true },
    { id='v13_immunologic_storm', label='V13 Immunologic Storm', category='CONTINUUM COMMAND V13', description='Severe infection, cytokine burden, device infection risk and urgent source-control needs.', dangerous=true, confirm=true },
    { id='v13_prolonged_field_care', label='V13 Prolonged Field Care', category='CONTINUUM COMMAND V13', description='Critical trauma with delayed transport, limited reserve and sustainment requirements.', dangerous=true, confirm=true },
    { id='v13_regional_surge_patient', label='V13 Regional Surge Patient', category='CONTINUUM COMMAND V13', description='High-complexity patient for regional dispatch, destination, resource and hospital-capacity testing.', dangerous=true, confirm=true },
    { id='v13_recovery_failure', label='V13 Recovery Failure', category='CONTINUUM COMMAND V13', description='Frailty, malnutrition, delirium, immobility and discharge barriers for recovery-network testing.', dangerous=true, confirm=true },

    { id='full_injury_matrix', label='Full Injury Matrix Stress Test', category='STRESS TEST', description='Apply representative gunshot, stab, blunt, fracture, burn, internal bleeding, organ, and nerve injuries across all body regions.', dangerous=true, confirm=true },
    { id='mass_casualty_red', label='MCI Immediate / Red Patient', category='STRESS TEST', description='Create a critical multi-system patient suitable for dispatch, MCI triage, EMS, hospital, ICU, surgery, and records testing.', dangerous=true, confirm=true }
}

function DPN_MED.GetTestScenarioCatalog()
    local out = {}
    for index, item in ipairs(DPN_MED.TestScenarios) do
        out[index] = {
            id = item.id,
            label = item.label,
            category = item.category,
            description = item.description,
            dangerous = item.dangerous == true,
            confirm = item.confirm == true,
            nonDestructive = item.nonDestructive == true
        }
    end
    return out
end
