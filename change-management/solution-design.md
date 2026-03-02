# Solution Design: Change Management / Maintenance Window Orchestration

## A. Environment Summary

Platform running locally with **ServiceNow** adapter (ONLINE) for ticketing and **AutomationGateway** (ONLINE) for device connectivity. 24 devices in inventory (primarily Cisco IOS). No monitoring adapter available — monitoring suppression/restore phases will be skipped per spec ("If Not Available: Engineer manages alerts manually"). The pluggable change process will be passed in as a workflow name variable, allowing this orchestrator to wrap any change type.

---

## B. Requirements Resolution

| Spec Requirement | Status | Resolution |
|-----------------|--------|------------|
| Orchestrate multi-step processes with conditional logic | ✓ | WorkFlowEngine — evaluation, childJob, merge |
| Call external processes and wait for completion | ✓ | childJob task — calls any workflow by name |
| Poll an external system on an interval with timeout | ✓ | delay + getChangeRequestById in a loop with counter |
| Generate reports from structured data | ✓ | newVariable + merge to build evidence object |
| Handle errors and route to different paths | ✓ | evaluation task with success/failure transitions |
| ITSM / ticketing (ServiceNow) | ✓ | ServiceNow adapter — full change request CRUD |
| Monitoring (suppress/restore alerts) | ✗ SKIP | No monitoring adapter — engineer manages manually |
| The change process itself | ✓ | Pluggable — passed as `changeWorkflowName` variable |

---

## C. Design Decisions

| Decision | In This Environment |
|----------|-------------------|
| Ticketing system | ServiceNow — `createChangeRequest`, `updateChangeRequest`, `getChangeRequestById` |
| Change request type | Normal change request (requires approval) |
| Approval mechanism | Poll `getChangeRequestById`, check `state` field for approved/rejected |
| Approval timeout | Default 4 hours (configurable via `approvalTimeoutMinutes` variable) |
| Poll interval | Every 60 seconds (configurable via `pollIntervalSeconds` variable) |
| Monitoring suppression | SKIP — no adapter; engineer handles manually |
| Pluggable change | childJob calls workflow named in `changeWorkflowName` input variable |
| Rollback behavior | If `autoRollback=true` and a `rollbackWorkflowName` is provided, call it on failure; otherwise escalate |
| Ticket updates | Update ticket at every phase transition for audit trail |
| Evidence | Build evidence object with timestamps, outcomes, errors; attach to ticket at close |

---

## D. Component Inventory

| # | Component | Type | Description |
|---|-----------|------|-------------|
| 1 | CM - Create Change Ticket | Child Workflow | Creates a ServiceNow normal change request with description, affected devices, risk, schedule |
| 2 | CM - Poll Approval | Child Workflow | Polls ServiceNow for change approval with configurable interval and timeout. Returns approved/rejected/timeout |
| 3 | CM - Update Ticket | Child Workflow | Updates a ServiceNow change request with phase status, work notes. Reused at every phase boundary |
| 4 | CM - Close Ticket | Child Workflow | Final ticket update: outcome, evidence report, transition to closed/canceled state |
| 5 | CM - Orchestrator | Parent Workflow | Sequences all phases: create ticket → approve → execute change → verify → close. Error paths ensure ticket is always closed and monitoring note is always added |
| 6 | CM - Project | Automation Studio Project | Packages all workflows for delivery |

---

## E. Implementation Plan

### Step 1: CM - Create Change Ticket
**Build:** Child workflow with ServiceNow `createChangeRequest` task
**Inputs:** `shortDescription`, `description`, `affectedDevices`, `riskLevel`, `scheduledStart`, `scheduledEnd`, `changePlan`
**Outputs:** `changeRequestId`, `changeRequestNumber`
**Test:** Run standalone, verify ticket created in ServiceNow

### Step 2: CM - Poll Approval
**Build:** Child workflow with a polling loop — `delay` → `getChangeRequestById` → `evaluation` (check state) → loop or exit
**Inputs:** `changeRequestId`, `pollIntervalSeconds` (default 60), `approvalTimeoutMinutes` (default 240)
**Outputs:** `approvalStatus` (approved / rejected / timeout), `approvalNotes`
**Test:** Run standalone with an existing ticket ID, verify it returns correct status

### Step 3: CM - Update Ticket
**Build:** Child workflow with ServiceNow `updateChangeRequest` task
**Inputs:** `changeRequestId`, `workNotes`, `state` (optional)
**Outputs:** `updateSuccess`
**Test:** Run standalone, verify work notes appear on the ticket

### Step 4: CM - Close Ticket
**Build:** Child workflow — builds evidence object, then calls `updateChangeRequest` to close
**Inputs:** `changeRequestId`, `outcome` (success/failure/rollback), `evidence` (object with timestamps, results, errors)
**Outputs:** `closeSuccess`
**Test:** Run standalone, verify ticket transitions to closed with evidence in notes

### Step 5: CM - Orchestrator
**Build:** Parent workflow wiring all children together:
```
Start
  → childJob: CM - Create Change Ticket
  → childJob: CM - Update Ticket ("Awaiting approval")
  → childJob: CM - Poll Approval
  → evaluation: approved?
      ├─ YES → childJob: CM - Update Ticket ("Change in progress")
      │         → childJob: {changeWorkflowName} (the pluggable change)
      │         → evaluation: change succeeded?
      │             ├─ YES → childJob: CM - Update Ticket ("Verifying")
      │             │         → (optional) childJob: {verifyWorkflowName}
      │             │         → childJob: CM - Close Ticket (success)
      │             └─ NO  → evaluation: autoRollback?
      │                        ├─ YES → childJob: {rollbackWorkflowName}
      │                        │         → childJob: CM - Close Ticket (rollback)
      │                        └─ NO  → childJob: CM - Close Ticket (failure + escalate)
      ├─ REJECTED → childJob: CM - Close Ticket (rejected)
      └─ TIMEOUT  → childJob: CM - Close Ticket (timeout)
  → End
```
**Inputs:** `shortDescription`, `description`, `affectedDevices`, `riskLevel`, `scheduledStart`, `scheduledEnd`, `changePlan`, `changeWorkflowName`, `changeWorkflowVariables`, `verifyWorkflowName` (optional), `rollbackWorkflowName` (optional), `autoRollback` (boolean), `pollIntervalSeconds`, `approvalTimeoutMinutes`
**Test:** End-to-end with a simple test workflow as the pluggable change

### Step 6: CM - Project
**Build:** Create Automation Studio project, add all 5 workflows
**Test:** Verify all components listed in project

---

## F. Acceptance Criteria → Tests

| Acceptance Criterion | Test |
|---------------------|------|
| 1. Change does not proceed without an approved ticket | Run orchestrator, leave ticket unapproved — verify it times out and closes cleanly |
| 2. Monitoring confirmed suppressed before change | SKIP — no monitoring adapter |
| 3. Pluggable change receives all inputs, outcome captured | Run with a test workflow, verify variables passed and result captured |
| 4. Post-change verification runs and results recorded | Run with a verify workflow, check evidence on ticket |
| 5. Monitoring restored in all exit paths | SKIP — no monitoring adapter |
| 6. Ticket updated with outcome in all exit paths | Force failure, timeout, and success — verify ticket closed each time |
| 7. Approval timeout aborts cleanly | Set short timeout, don't approve — verify clean abort |
| 8. Change window duration recorded | Check closed ticket for start/end timestamps |

---

## G. ServiceNow Task Reference

| Task Name | Purpose |
|-----------|---------|
| `createChangeRequest` | Create a new change request |
| `getChangeRequestById` | Get change request details (for approval polling) |
| `updateChangeRequest` | Update work notes, state, fields |
| `autoApproveChangeRequest` | Auto-approve (for testing) |

**App name for workflow tasks:** `Servicenow` (from apps.json)
**Adapter ID:** `ServiceNow` (from adapters.json)
