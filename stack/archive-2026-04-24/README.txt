Archive — UNS Cursus Stack — 2026-04-24
========================================

Doel: snapshot voordat de stack opnieuw wordt opgezet voor sessie-4 opname.

Bestanden
---------
container-state.txt           Draaiende containers, volumes, networks op moment van archivering
timescaledb-dump.sql          Volledige pg_dump van database "umh" (alle schemas, data, extensions)
asset-data.txt                25 assets (leesbare tabel)
production-orders-data.txt    7 production orders (leesbare tabel)
nodered-flows.json            Alle Node-RED flows (4 tabs: API Werkorder, Event OUT, Polling v2/v3)
nodered-flows_cred.json       Node-RED credentials (versleuteld)
nodered-package.json          Node-RED npm dependencies (o.a. node-red-dashboard)
grafana-dashboard-new.json    Handmatig Grafana dashboard "New dashboard" (niet provisioned)
grafana-dashboard-quoteclaw-llm.json  QuoteClaw LLM Observability dashboard (niet provisioned)

Provisioned Grafana dashboards staan al in git:
  stack/configs/grafana/provisioning/dashboards/
    - data-overview.json
    - metalfab-machines.json
    - tasmota-energy.json
    - werkorders.json

Docker volumes (behouden, niet verwijderd):
  uns-cursus_grafana-data
  uns-cursus_hivemq-data
  uns-cursus_nodered-data
  uns-cursus_portainer-data
  uns-cursus_timescaledb-data
  uns-cursus_umh-core-data
  stack_umh-core-data
  nocodb-data

Database stats op moment van archivering:
  public.asset:              25 rijen
  public.tag:              4809 rijen (sensor data)
  public.tag_string:        405 rijen
  public.production_orders:   7 rijen
  quoteclaw.llm_calls:     3252 rijen
  quoteclaw.uns_events:    1724 rijen
