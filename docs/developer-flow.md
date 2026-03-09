  ┌─────────────────────────────────────────────────────────────────────────┐
  │                         USE CASE LIBRARY                                │
  │                                                                         │
  │  spec-software-upgrade.md    spec-circuit-provisioning.md               │
  │  spec-dns-record-management.md    spec-compliance-audit.md   ...        │
  │                                                                         │
  │  21 technology-agnostic HLD specs.                                      │
  │  Define WHAT to orchestrate, not HOW.                                      │
  └────────────────────────────────┬────────────────────────────────────────┘
                                   │
                                   │  Engineer runs /itential-setup
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                      /itential-setup                                    │
  │                                                                         │
  │  1. Authenticate (reads .env or asks for credentials)                  │
  │  2. Save token to .auth.json (all skills reuse it)                     │
  │  3. "Exploring or building from a spec?"                               │
  │                                                                         │
  │     ┌──────────────────┐         ┌──────────────────────┐              │
  │     │ EXPLORE          │         │ SPEC-BASED           │              │
  │     │                  │         │                      │              │
  │     │ Pull platform    │         │ Pick spec, fork it,  │              │
  │     │ data, use skills │         │ pull platform data,  │              │
  │     │ directly         │         │ review against env   │              │
  │     └────────┬─────────┘         └──────────┬───────────┘              │
  │              │                              │                          │
  └──────────────┼──────────────────────────────┼──────────────────────────┘
                 │                              │
                 ▼                              ▼
  ┌──────────────────────┐    ┌─────────────────────────────────────────────┐
  │ Use skills directly  │    │              /solution-design                │
  │                      │    │                                              │
  │ /itential-builder    │    │  GATE 1: SPEC REVIEW                        │
  │   workflows,         │    │  ┌────────────────────────────────────────┐ │
  │   templates,         │    │  │ Present spec to engineer for review.   │ │
  │   MOP, run/test      │    │  │ Resolve capabilities + integrations   │ │
  │                      │    │  │ against the environment.              │ │
  │ /itential-devices    │    │  │ Ask only what data can't answer.      │ │
  │   backups, diffs     │    │  │                                        │ │
  │                      │    │  │ Engineer approves → spec locked.       │ │
  │ /itential-golden-    │    │  └──────────────────┬─────────────────────┘ │
  │   config             │    │                     │                       │
  │   compliance         │    │                     ▼                       │
  │                      │    │  GATE 2: DESIGN REVIEW                      │
  │ /iag                 │    │  ┌────────────────────────────────────────┐ │
  │   IAG services       │    │  │ Produce solution design:              │ │
  │                      │    │  │                                        │ │
  │ /flowagent           │    │  │ ┌──────────────┬──────────┬──────────┐│ │
  │   AI agents          │    │  │ │ Component    │ Type     │ Action   ││ │
  │                      │    │  │ ├──────────────┼──────────┼──────────┤│ │
  │ /itential-lcm        │    │  │ │ Pre-Check    │ MOP      │ BUILD    ││ │
  │   lifecycle mgmt     │    │  │ │ Backup       │ Workflow │ REUSE    ││ │
  │                      │    │  │ │ ITSM         │ Adapter  │ BUILD    ││ │
  │ /itential-inventory  │    │  │ │ Monitoring   │ -        │ SKIP     ││ │
  │   device inventories │    │  │ └──────────────┴──────────┴──────────┘│ │
  │                      │    │  │                                        │ │
  └──────────────────────┘    │  │ Engineer approves → design locked.     │ │
                              │  └──────────────────┬─────────────────────┘ │
                              │                     │                       │
                              └─────────────────────┼───────────────────────┘
                                                    │
                                                    ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                      /itential-builder                                  │
  │                                                                         │
  │  Builds everything from the approved design:                           │
  │                                                                         │
  │   Step 1: Create project                                               │
  │   Step 2: Build command templates (MOP) → test standalone              │
  │   Step 3: Build Jinja2 templates → test render                         │
  │   Step 4: Build child workflows → test each with jobs/start            │
  │   Step 5: Build parent workflow → test end-to-end                      │
  │   Step 6: Add all assets to project                                    │
  │   Step 7: Grant access, deliver                                        │
  │                                                                         │
  │  Each step: read helper → build JSON → save locally → POST → test     │
  │  On failure: check .auth.json, job.error, openapi.json, task-schemas   │
  └─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                          DELIVERED                                      │
  │                                                                         │
  │  ✓ Working automation on the engineer's platform                       │
  │  ✓ All assets tested end-to-end                                        │
  │  ✓ Packaged in a project with access granted                           │
  │  ✓ JSON files saved locally for future iteration                       │
  └─────────────────────────────────────────────────────────────────────────┘
