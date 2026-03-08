# Use Case: Change Management / Maintenance Window Orchestration

## 1. Problem Statement

Change windows are the most stressful hours in network operations. Engineers manually create tickets, wait for approvals over email, SSH into monitoring tools to suppress alerts, execute the change, check if things broke, re-enable monitoring, and update the ticket. Steps get skipped under pressure. Monitoring stays suppressed for hours after the window closes. Tickets sit in "In Progress" for days.

**Goal:** Automate the full change window lifecycle — ticket creation through close-out — so the engineer focuses on the change itself while everything around it happens reliably and in order. The actual change is pluggable: this is a wrapper that orchestrates before, during, and after.

---

## 2. High-Level Flow (Simplified)

```
Create Ticket  →  Get Approval  →  Execute Change  →  Verify Change  →  Close Ticket
     │                 │                 │                  │                 │
  Open ticket,     Poll SNOW for     Call pluggable     Run post-change   Update ticket
  populate         approval or       child workflow     verification      with results,
  fields           timeout                              (childJob)        close out
                                                             │
                                                        FAIL? → Escalate
```

**Note:** Monitoring suppression/restore phases are stubbed out (no monitoring adapter installed). Placeholder tasks included for future integration.

---

## 3. Phases

### Ticket Creation
Create a ServiceNow change_request with fields: `short_description`, `description`, `summary`, `category`, `priority`, `assignment_group`, `cmdb_ci`. If a ticket ID (sys_id) is provided as input, update the existing ticket instead of creating a new one.

### Approval Gate
Wait for the change_request to reach an approved state. Poll ServiceNow on an interval checking the `approval` field. If approval is not received within a configurable timeout (default: 4 hours), **abort and update the ticket**. If rejected, abort and update the ticket with the rejection reason.

### Suppress Monitoring (Stubbed)
Placeholder — no monitoring adapter available. Log a message that monitoring suppression would occur here. Future: integrate SolarWinds, PRTG, or Datadog adapter.

### Execute Change
Call the pluggable change process via childJob, passing it the device list, variables, and any change-specific inputs. Wait for completion. Capture success/failure status and outputs.

### Verify Change
Run post-change validation via childJob. Compare results. If verification fails, **escalate** (pause for engineer review — no auto-rollback).

### Restore Monitoring (Stubbed)
Placeholder — log that monitoring restore would occur here.

### Close Ticket
Update the ServiceNow change_request with outcome (success/failure), attach evidence (timing, results), transition to closed state.

---

## 4. Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Approval is a hard gate | Never proceed without approval | Change management compliance requires it |
| The change itself is pluggable | childJob calls any workflow | One wrapper handles all change types |
| Monitoring is stubbed | Placeholder tasks, no adapter | No monitoring adapter available; future integration |
| Rollback is manual | Escalate to engineer on failure | Engineer reviews before rollback |
| Single window batch | All devices in one ticket | Simplest approach; can extend later |
| Ticket updated at every phase | Not just at open and close | Creates a real-time audit trail |

---

## 5. Scope

**In scope:** Ticket lifecycle (create, update, close) via ServiceNow, approval polling, pluggable change execution via childJob, post-change verification, evidence generation, single-device and batch change windows.

**Out of scope:** Monitoring suppression/restore (stubbed). The change itself (pluggable). Approval routing rules in ServiceNow. Calendar/scheduling integration. Auto-rollback.

---

## 6. Environment

| Resource | Details |
|----------|---------|
| **Platform** | localhost:4000, password auth |
| **ServiceNow adapter** | ONLINE (`@itentialopensource/adapter-servicenow`, routePrefix: `Servicenow`) |
| **ServiceNow app name** | `Servicenow` (from apps.json) |
| **AutomationGateway** | ONLINE |
| **Monitoring adapter** | None installed — phases stubbed |
| **Devices in Config Manager** | 0 (not required for this use case) |

---

## 7. ServiceNow Fields

Change request fields:
- `short_description` — brief title of the change
- `description` — detailed change plan
- `summary` — summary field (added per engineer request)
- `category` — change category
- `priority` — priority level
- `assignment_group` — group responsible
- `cmdb_ci` — affected configuration item(s)

Approval tracking:
- Poll `approval` field on the change_request record
- Approved state: `approved`
- Rejected state: `rejected`

---

## 8. Acceptance Criteria

1. Change does not proceed without an approved ticket
2. The pluggable change process (childJob) receives all required inputs and its outcome is captured
3. Post-change verification runs and results are recorded
4. Ticket is updated with outcome and evidence in all exit paths
5. Approval timeout aborts cleanly and updates the ticket
6. Monitoring phases are present as stubs for future integration
7. Change window duration is recorded on the ticket
