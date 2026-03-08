# Solution Design: Change Management

## A. Environment Summary

Local dev platform (localhost:4000) with ServiceNow adapter (ONLINE) and AutomationGateway (ONLINE). 904 tasks available including full ServiceNow CRUD operations (`createChangeRequest`, `getChangeRequestById`, `updateChangeRequest`) and all utility tasks (childJob, evaluation, merge, query, delay, newVariable). No monitoring adapter — those phases are stubbed.

## B. Requirements Resolution

| Spec Requirement | Status | Resolution |
|-----------------|--------|------------|
| Orchestrate multi-step with conditional logic | ✓ | WorkFlowEngine (evaluation, transitions) |
| Call external processes and wait | ✓ | childJob task |
| Poll external system with timeout | ✓ | delay + evaluation loop |
| Generate reports from structured data | ✓ | Jinja2 templates |
| Handle errors and route to different paths | ✓ | Error transitions, evaluation task |
| ITSM / ticketing | ✓ | ServiceNow adapter (ONLINE), app name: `Servicenow` |
| Monitoring suppression | ✗ | SKIP — stubbed with newVariable placeholder |
| Pluggable change process | ✓ | childJob calling any workflow |

## C. Design Decisions

| Decision | Implementation |
|----------|---------------|
| ITSM integration | ServiceNow — `createChangeRequest`, `getChangeRequestById`, `updateChangeRequest` |
| Approval polling | `delay` (60s) + `getChangeRequestById` + `evaluation` loop, max iterations for timeout |
| Pluggable change | `childJob` — workflow name + variables passed as input |
| Monitoring | Stubbed — `newVariable` tasks as placeholders |
| Rollback | Manual — escalate to engineer via ticket update on failure |
| Batch strategy | Single window — all devices in one ticket |
| Error handling | Error transitions on all adapter tasks → update ticket with failure → end |

## D. Component Inventory

| # | Component | Type | Action |
|---|-----------|------|--------|
| 1 | Change Management Orchestrator | Parent Workflow | Build |
| 2 | Evidence Report Template | Jinja2 Template | Build |
| 3 | Change Management Project | Project | Build |

### Workflow: Change Management Orchestrator

```
workflow_start
    │
    ▼
[1] evaluation — check if existing ticket (sys_id provided?)
    ├── yes → [2a] updateChangeRequest (update existing)
    └── no  → [2b] createChangeRequest (create new)
    │
    ▼
[3] query — extract sys_id from create/update response
    │
    ▼
[4] newVariable — set approval polling counter to 0
    │
    ▼
┌─► [5] delay — wait 60 seconds
│       │
│       ▼
│   [6] getChangeRequestById — check approval status
│       │
│       ▼
│   [7] query — extract approval field
│       │
│       ▼
│   [8] evaluation — check approval status
│       ├── approved → [9]
│       ├── rejected → [ERR1] updateChangeRequest (set rejected) → workflow_end
│       └── pending  → [8b] evaluation — check timeout counter
│                          ├── under limit → increment counter → loop to [5]
│                          └── over limit  → [ERR2] updateChangeRequest (timed out) → workflow_end
│
▼
[9] newVariable — stub: "monitoring suppressed" placeholder
    │
    ▼
[10] updateChangeRequest — set ticket to "in progress"
    │
    ▼
[11] childJob — execute pluggable change workflow
    │  (error transition → [ERR3])
    ▼
[12] childJob — execute verification workflow (optional, skip if not provided)
    │  (error transition → [ERR3])
    ▼
[13] newVariable — stub: "monitoring restored" placeholder
    │
    ▼
[14] merge — build evidence report data (timing, results, status)
    │
    ▼
[15] updateChangeRequest — close ticket with results + evidence
    │
    ▼
workflow_end

[ERR3] updateChangeRequest — update ticket with failure details → workflow_end
```

### Workflow Inputs (job variables)

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `short_description` | string | yes | Change ticket title |
| `description` | string | yes | Detailed change plan |
| `summary` | string | yes | Summary field |
| `category` | string | yes | Change category |
| `priority` | string | yes | Priority level |
| `assignment_group` | string | yes | Responsible group |
| `cmdb_ci` | string | no | Affected CI |
| `existing_ticket_id` | string | no | Existing sys_id to update instead of create |
| `change_workflow` | string | yes | Name of the child workflow to execute |
| `change_variables` | object | no | Variables to pass to the child workflow |
| `verify_workflow` | string | no | Name of verification workflow |
| `verify_variables` | object | no | Variables for verification workflow |
| `approval_timeout_minutes` | number | no | Max wait for approval (default: 240 = 4 hours) |
| `devices` | array | no | List of affected devices |

## E. Implementation Plan

| Step | What | Test |
|------|------|------|
| 1 | Create project | Verify project exists |
| 2 | Build orchestrator workflow | Start job with test inputs, verify ticket created in ServiceNow |
| 3 | Build evidence report Jinja2 template | Render with sample data |
| 4 | Add components to project | Verify all components in project |
| 5 | End-to-end test | Full run: create ticket → approval → child job → close |

## F. Acceptance Criteria → Tests

| Criteria | Test |
|----------|------|
| Change does not proceed without approved ticket | Start job, don't approve → verify it polls and times out |
| Pluggable change receives inputs, outcome captured | Start job with a simple child workflow, verify it runs |
| Post-change verification runs | Provide verify_workflow, check it executes |
| Ticket updated in all exit paths | Test success, rejection, and timeout paths |
| Approval timeout aborts cleanly | Set short timeout, verify ticket updated and job ends |
| Monitoring stubs present | Verify placeholder tasks exist in workflow |
| Change window duration recorded | Check ticket close comment includes timing |
