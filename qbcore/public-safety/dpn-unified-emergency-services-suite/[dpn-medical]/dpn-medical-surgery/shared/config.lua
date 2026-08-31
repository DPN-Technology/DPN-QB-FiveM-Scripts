Config=Config or {}
Config.Jobs={surgeon=true,doctor=true}
Config.Procedures={
 exploratory_laparotomy={label='Exploratory Laparotomy',part='abdomen',minutes=30,cost=7500},
 thoracotomy={label='Emergency Thoracotomy',part='chest',minutes=40,cost=11000},
 fracture_fixation={label='Fracture Fixation',part=nil,minutes=35,cost=6500},
 vascular_repair={label='Vascular Repair',part=nil,minutes=45,cost=12500},
 neurosurgery={label='Neurosurgery',part='head',minutes=60,cost=18000}
}
