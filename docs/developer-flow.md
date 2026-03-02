  ┌─────────────────────────────────────────────────────────────────────────┐                                                                                                                                                                       
  │                         USE CASE LIBRARY                                │
  │                                                                         │                                                                                                                                                                       
  │  spec-software-upgrade.md    spec-circuit-provisioning.md               │
  │  spec-dns-record-management.md    spec-compliance-audit.md   ...        │
  │                                                                         │
  │  Technology-agnostic HLD specs.                                         │
  │  Define WHAT to automate, not HOW.                                      │
  └────────────────────────────────┬────────────────────────────────────────┘
                                   │
                                   │  Engineer picks a use case
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                      /solution-design                                   │
  │                                                                         │
  │  Phase 1: DISCOVER                                                      │
  │  ┌───────────────────────────────────────────────────────────────┐      │
  │  │ Agent connects to the engineer's platform and auto-discovers │      │
  │  │ everything: adapters, devices, tasks, existing workflows,    │      │
  │  │ golden configs, device groups.                               │      │
  │  │                                                               │      │
  │  │ "What do you have?"                                           │      │
  │  └───────────────────────────────────────────────────────────────┘      │
  │                                 │                                       │
  │                                 ▼                                       │
  │  Phase 2: DESIGN                                                        │
  │  ┌───────────────────────────────────────────────────────────────┐      │
  │  │ Agent maps spec requirements against the environment.         │      │
  │  │                                                               │      │
  │  │ Spec says "ITSM integration" → ServiceNow adapter? RUNNING.  │      │
  │  │ Spec says "config backup"    → ConfigurationManager? RUNNING. │      │
  │  │ Spec says "rollback"         → existing rollback workflow? No.│      │
  │  │ Spec says "monitoring"       → no adapter found. SKIP.        │      │
  │  │                                                               │      │
  │  │ Produces: Solution Design with Design Decisions Table         │      │
  │  │                                                               │      │
  │  │ ┌────────────────┬─────────────────┬────────────┐            │      │
  │  │ │ Spec Component │ Env Match       │ Decision   │            │      │
  │  │ ├────────────────┼─────────────────┼────────────┤            │      │
  │  │ │ Pre-Check      │ MOP: RUNNING    │ BUILD      │            │      │
  │  │ │ Backup         │ ACW Backup v3   │ REUSE      │            │      │
  │  │ │ ITSM           │ SNOW: RUNNING   │ BUILD      │            │      │
  │  │ │ Monitoring     │ not found       │ SKIP       │            │      │
  │  │ └────────────────┴─────────────────┴────────────┘            │      │
  │  └───────────────────────────────────────────────────────────────┘      │
  │                                 │                                       │
  │                                 ▼                                       │
  │  Phase 3: REFINE                                                        │
  │  ┌───────────────────────────────────────────────────────────────┐      │
  │  │ Agent walks through each decision with the engineer:          │      │
  │  │                                                               │      │
  │  │ "I found ServiceNow. Incidents or change requests?"           │      │
  │  │ "No monitoring adapter. Skip or add a manual pause?"          │      │
  │  │ "Your devices run cisco-ios. These are the commands I'll      │      │
  │  │  use for pre-check. Anything to add?"                         │      │
  │  │ "I see an existing backup workflow. Reuse it?"                │      │
  │  │                                                               │      │
  │  │ Engineer adjusts. Agent updates the design.                   │      │
  │  └───────────────────────────────────────────────────────────────┘      │
  │                                 │                                       │
  │                                 ▼                                       │
  │  Phase 4: PLAN                                                          │
  │  ┌───────────────────────────────────────────────────────────────┐      │
  │  │ Agent produces an ordered implementation plan:                │      │
  │  │                                                               │      │
  │  │  Step 1: Create command template "Pre-Check" → test it       │      │
  │  │  Step 2: Create Jinja2 template "Report"     → test it       │      │
  │  │  Step 3: Build child workflow "Pre-Check"    → test it       │      │
  │  │  Step 4: Build child workflow "Activate"     → test it       │      │
  │  │  Step 5: Build parent workflow               → test it       │      │
  │  │  Step 6: End-to-end test                                      │      │
  │  │  Step 7: Package into project                                 │      │
  │  │                                                               │      │
  │  │ Engineer approves.                                            │      │
  │  └───────────────────────────────────────────────────────────────┘      │
  │                                 │                                       │
  │                                 ▼                                       │
  │  Phase 5: BUILD                                                         │
  │  ┌───────────────────────────────────────────────────────────────┐      │
  │  │ Agent builds everything using the Itential skills:            │      │
  │  │                                                               │      │
  │  │ /itential-setup     → authenticate, bootstrap                │      │
  │  │ /itential-studio    → create templates, workflows, project   │      │
  │  │ /itential-devices   → validate devices, backups, diffs       │      │
  │  │ /itential-golden-config → compliance (if needed)             │      │
  │  │                                                               │      │
  │  │ Each step: create → save locally → test → verify → next      │      │
  │  └───────────────────────────────────────────────────────────────┘      │
  │                                                                         │
  └─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                          DELIVERED                                       │
  │                                                                         │
  │  ✓ Working automation on the engineer's platform                        │
  │  ✓ All assets tested end-to-end                                         │
  │  ✓ Packaged in a project with access granted                            │
  │  ✓ JSON files saved locally for future iteration                        │
  └─────────────────────────────────────────────────────────────────────────┘