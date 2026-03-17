-- =================================================================
-- STAP 5: Assets aanmaken voor onze databronnen
-- =================================================================
-- Elk fysiek apparaat krijgt een asset in de ISA-95 hierarchy.
--
-- ISA-95 hierarchy:
--
--   smc (enterprise)
--   └── hq (site)
--       └── tasmota (area)
--           ├── cabinet (line)     → serverkast energiemeter
--           ├── siderack (line)    → zijkast energiemeter
--           └── desk (line)        → bureau energiemeter
--
--   metalfab (enterprise)
--   └── eindhoven (site)
--       ├── cutting (area)
--       │   └── laser_01 (line)    → laser snijmachine
--       └── forming (area)
--           └── press_brake_01     → kantbank
--
-- NB: get_asset_id() maakt assets ook automatisch aan.
--     Dit script is voor de duidelijkheid / demonstratie.
-- =================================================================

-- Tasmota Energy Sensors (Home Lab)
-- NB: site = 'workshop' moet overeenkomen met de bridge location in UMH Core
INSERT INTO asset (asset_name, enterprise, site, area, line)
VALUES
  ('smc.workshop.tasmota.cabinet',   'smc', 'workshop', 'tasmota', 'cabinet'),
  ('smc.workshop.tasmota.siderack',  'smc', 'workshop', 'tasmota', 'siderack'),
  ('smc.workshop.tasmota.desk',      'smc', 'workshop', 'tasmota', 'desk')
ON CONFLICT (enterprise, site, area, line, workcell, origin_id) DO NOTHING;

-- MetalFab Simulator (Cloud)
INSERT INTO asset (asset_name, enterprise, site, area, line)
VALUES
  ('metalfab.eindhoven.cutting.laser_01',       'metalfab', 'eindhoven', 'cutting', 'laser_01'),
  ('metalfab.eindhoven.forming.press_brake_01', 'metalfab', 'eindhoven', 'forming', 'press_brake_01')
ON CONFLICT (enterprise, site, area, line, workcell, origin_id) DO NOTHING;

-- Verificatie
SELECT id, asset_name, enterprise, site, area, line FROM asset ORDER BY enterprise, site, area, line;
