---
name: solution-design
description: Take a use-case HLD spec and an engineer's environment, produce a solution design, refine it collaboratively, then build it. Use when an engineer wants to implement a use case from a spec file.
argument-hint: "[spec-file-path]"
---

# Solution Design — Spec-Driven Development

Two approval gates before anything gets built: **approve the spec, then approve the design.**

```
┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────┐
│ 1.DISCOVER│ →  │ 2.SPEC    │ →  │ 3.DESIGN  │ →  │ 4.BUILD   │
│           │    │  REVIEW   │    │  REVIEW   │    │           │
│ Read spec,│    │           │    │           │    │ Plan,     │
│ read env, │    │ Present   │    │ Present   │    │ create    │
│ ask q's,  │    │ customer  │    │ solution  │    │ assets,   │
│ update    │    │ spec →    │    │ design →  │    │ test each,│
│ spec      │    │ APPROVE   │    │ APPROVE   │    │ deliver   │
└───────────┘    └───────────┘    └───────────┘    └───────────┘
                  Gate 1 ✓         Gate 2 ✓
```

---

## Document Lifecycle

```
spec-files/spec-port-turn-up.md        ← Generic template (never modified)
        │
        │  Fork + customize
        ▼
{use-case}/{use-case}-spec.md                     ← Customer's spec → GATE 1: engineer approves
        │
        │  Resolve against environment
        ▼
{use-case}/solution-design.md          ← Implementation plan → GATE 2: engineer approves
        │
        │  Build
        ▼
{use-case}/*.json                      ← Built assets (workflows, templates, etc.)
```

**When the customer wants to change something later:** modify `{use-case}/{use-case}-spec.md` and re-run.

---

## Spec File Structure

| Spec Section | What the Agent Extracts |
|-------------|------------------------|
| **1. Problem Statement** | Context — what are we solving and why |
| **2. High-Level Flow** | The major phases to implement |
| **3. Phases** | What each phase does, decision points, stop/rollback conditions |
| **4. Key Design Decisions** | Constraints to honor during implementation |
| **5. Scope** | What to build, what NOT to build |
| **6. Risks & Mitigations** | Error handling and fallback behavior to build in |
| **7. Requirements** | **This drives the discovery and design** |
| **8. Batch/Bulk Strategy** | Orchestration pattern if multi-device/multi-record |
| **9. Acceptance Criteria** | How to verify the build is correct |

Section 7 has three parts:
- **Capabilities** — what the platform must do → agent checks the environment
- **Integrations** — external systems → agent checks what adapters exist
- **Discovery Questions** — what to ask when auto-discovery can't answer

---

## Phase 1: DISCOVER

**Entered from `/itential-setup` after auth and environment discovery are done.** The working directory exists with all data pulled. **Do NOT make additional API calls. Read local files.**

### 1A. Read the Customer Spec

The spec was forked to `{use-case}/{use-case}-spec.md` during setup. Read it and extract:
- **Phases** from Section 3 (workflow stages)
- **Design decisions** from Section 4 (constraints)
- **Capabilities** table from Section 7 (platform checks)
- **Integrations** table from Section 7 (adapter checks)
- **Discovery questions** from Section 7 (ask only if data can't answer)
- **Acceptance criteria** from Section 9 (test cases)

### 1B. Read the Environment Data

Read local files — do not call the API:

| File | What to look for |
|------|-----------------|
| `adapters.json` | External systems available (ITSM, monitoring) — `.results[]` |
| `applications.json` | Platform apps running — `.results[]` |
| `devices.json` | Devices, OS types — `.list[]` |
| `workflows.json` | Reuse candidates — `.items[]` |
| `apps.json` | App names for workflow wiring — plain array |
| `tasks.json` | Task catalog — plain array |

### 1C. Collect Customer Context

Ask: *"Do you have existing documentation I should follow? Naming conventions, change policies, runbooks, config standards?"*

Capture in `{use-case}/customer-context.md` if provided. If not, move on.

### 1D. Ask Only What Data Can't Answer

Go through the spec's Discovery Questions:
- **Data already answers it?** → Skip. ("Do you use a ticketing system?" → ServiceNow adapter exists)
- **Can't answer from data?** → Ask. ("VLAN naming convention?" → Engineer knowledge)

Present what you found alongside remaining questions.

### 1E. Update the Customer Spec

Incorporate ALL engineer input into `{use-case}/{use-case}-spec.md`:
- Added requirements → update Section 7
- Changed scope → update Section 5
- Business rules → add to relevant sections
- Changed decisions → update Section 4

The spec must reflect everything the engineer told you.

---

## Phase 2: SPEC REVIEW — Gate 1

**Present the updated customer spec to the engineer for review. Do NOT proceed to design until approved.**

Show them:
- Summary of what changed from the generic spec
- Their additions (requirements, scope changes, business rules)
- What's in vs out of scope
- Discovery question answers captured

Ask: *"Here's your spec. Review it — add, remove, or change anything. When you're happy with it, I'll design the solution."*

The engineer may:
- Add features ("also add a Slack notification step")
- Remove scope ("skip the monitoring integration")
- Change decisions ("auto-rollback, not manual review")
- Adjust acceptance criteria

Update `{use-case}/{use-case}-spec.md` with every change.

**When the engineer approves: the spec is locked.** This is what the solution design will be based on. Save the file.

---

## Phase 3: DESIGN + REVIEW — Gate 2

Now produce the solution design from the approved spec.

### Step 1: Resolve Capabilities

For each row in the spec's capabilities table:
- Can the platform do this? → **✓ Resolved**
- Can't + Required? → **⚠ Blocked** (stop)
- Can't + Not Required? → **✗ Skipped** (use fallback from spec)

### Step 2: Resolve Integrations

For each row in the spec's integrations table:
- Found + Running? → **✓ Resolved** (record adapter name)
- Found + Stopped? → **⚠ Warning** (needs to be started)
- Not found + Required? → **⚠ Blocked**
- Not found + Not Required? → **✗ Skipped**

### Step 3: Check Reuse Opportunities

Search `workflows.json` for existing workflows that match spec phases. Flag as **↻ Reuse** candidates.

### Step 4: Produce the Solution Design

Generate `{use-case}/solution-design.md` with:

**A. Environment Summary** — one paragraph

**B. Requirements Resolution**
```
┌─────────────────────────────────────────┬────────┬──────────────────────────────┐
│ Spec Requirement                        │ Status │ Resolution                   │
├─────────────────────────────────────────┼────────┼──────────────────────────────┤
│ Execute CLI commands on devices         │ ✓      │ MOP app + AutomationGateway  │
│ ITSM / ticketing                        │ ✓      │ ServiceNow adapter           │
│ Monitoring                              │ ✗      │ SKIP — engineer handles      │
└─────────────────────────────────────────┴────────┴──────────────────────────────┘
```

**C. Design Decisions**
```
┌─────────────────────────────────────┬────────────────────────────────────────┐
│ Decision                            │ In This Environment                    │
├─────────────────────────────────────┼────────────────────────────────────────┤
│ ITSM integration                    │ ServiceNow — create incidents          │
│ Naming convention                   │ VLAN_{id}_{site} (customer standard)   │
└─────────────────────────────────────┴────────────────────────────────────────┘
```

**D. Component Inventory**
```
┌────┬──────────────────────────────┬─────────────────────┬──────────┐
│ #  │ Component                    │ Type                │ Action   │
├────┼──────────────────────────────┼─────────────────────┼──────────┤
│ 1  │ Pre-Check                    │ Command Template    │ Build    │
│ 2  │ Backup workflow              │ Child Workflow      │ Reuse    │
│ 3  │ Orchestrator                 │ Parent Workflow     │ Build    │
└────┴──────────────────────────────┴─────────────────────┴──────────┘
```

**E. Implementation Plan** — ordered build steps with test method for each

**F. Acceptance Criteria → Tests** — map each criterion to how to verify it

### Step 5: Present for Review

**Present the full solution design to the engineer. Do NOT proceed to build until approved.**

Walk through each section:
- Requirements: "I'll use [adapter/app]. Correct?"
- Decisions: "The spec says [X], I'll do [Y]. Sound right?"
- Components: "Reuse this? Build that? Skip this?"
- Plan: "Here's the build order. Agree?"

The engineer may:
- Change reuse → build ("that workflow is outdated")
- Add components ("we also need a cleanup workflow")
- Change the plan order
- Modify how acceptance criteria get tested

Update `{use-case}/solution-design.md` with every change.

**When the engineer approves: the design is locked.** Both documents are saved before any building begins:
1. `{use-case}/{use-case}-spec.md` — what they asked for
2. `{use-case}/solution-design.md` — how it gets built

---

## Phase 4: BUILD

Execute the locked plan step by step.

### For Each Step

1. **Invoke `/itential-builder`** — this single skill covers projects, workflows, templates (Jinja2/TextFSM), command templates (MOP), running jobs, and debugging. Load it once at the start of the build phase.
   - For device-specific operations (backups, diffs, device groups) → invoke `/itential-devices`
   - For compliance (golden config, compliance plans) → invoke `/itential-golden-config`
   - For IAG services → invoke `/iag`
   **Only load additional skills if the design requires their specific domain.**
2. **Start from a helper template** — read the matching file from `helpers/` first, then modify:
   - Command template → `helpers/create-command-template.json`
   - Jinja2 template → `helpers/create-template-jinja2.json`
   - Workflow → `helpers/create-workflow.json` + `helpers/workflow-task-application.json` / `helpers/workflow-task-adapter.json`
   - childJob task → `helpers/workflow-task-childjob.json`
   - Project → `helpers/create-project.json` + `helpers/add-components-to-project.json`
   All helper details are in `/itential-builder`.
   **Do NOT build JSON from scratch. Helpers have correct structure and field names.**
3. **Save locally** — write JSON to `{use-case}/` before sending to the platform
4. **Create on platform** — POST to the API
5. **Test** — run the test from the plan
6. **Review output** — check actual task output, not just job status. CLI commands can fail silently.
7. **When something fails — check local files FIRST:**
   - Wrong field name or payload structure? → `jq '.paths["/the/endpoint"].post.requestBody' {use-case}/openapi.json`
   - Task not found? → `grep -i "keyword" {use-case}/tasks.json`
   - Need task schema? → Check `{use-case}/task-schemas.json` before calling `multipleTaskDetails` again
   - Wrong app name or casing? → `jq '.[].name' {use-case}/apps.json`
   - **Don't guess, don't burn API calls — the answer is already on disk.**
8. **Fix and iterate** — edit local JSON, PUT to update (don't recreate)
9. **Move on** — only after the current step passes

### Patterns to Follow

**Variable resolution:**
- `$var.job.x` only resolves as a direct top-level incoming variable value
- `$var` inside nested objects does NOT resolve — use `merge`, `makeData`, `query`, or other utility tasks to build the object, then pass it as a top-level `$var` reference

All build patterns, wiring rules, testing, and debugging details are in `/itential-builder`. Key reminders:

- **childJob:** `actor: "job"`, variables use `{"task":"job","value":"varName"}` NOT `$var`
- **merge:** uses `"variable"` NOT `"value"` (different from childJob)
- **evaluation:** MUST have both `success` AND `failure` transitions
- **Error transitions:** mandatory on every adapter/external task
- **Adapter `app`:** from `apps.json`, NOT `tasks/list`
- **Testing:** `POST /operations-manager/jobs/start`, check `job.error` for failures
- **Iterating:** edit local JSON, `PUT` to update — don't recreate

### On Completion

The `{use-case}/` directory contains everything:

| File | Purpose |
|------|---------|
| `{use-case}-spec.md` | Customer's spec — approved at Gate 1 |
| `solution-design.md` | Implementation plan — approved at Gate 2 |
| `customer-context.md` | Business rules, naming conventions (if provided) |
| `openapi.json` | Platform API reference |
| `tasks.json`, `apps.json`, etc. | Discovery data |
| `wf-*.json`, `cmd-*.json`, `tmpl-*.json` | Built assets |

Deliver:
1. **Create the project FIRST** — `POST /automation-studio/projects` → get `projectId`
2. Build all assets with names prefixed `@{projectId}: ` so childJob refs are correct from the start
3. If assets were built in global scope, move them with `POST /projects/{id}/components/add` — then **fix childJob `workflow` refs** in parent workflows (the platform renames children but does NOT update parent references, causing "Cannot find workflow" errors)
4. All components individually tested
5. End-to-end test passed
6. Acceptance criteria verified
7. Access granted to the engineer's team
8. Summary of what was built, how to run it, and what inputs it expects

---

## How This Gets Invoked

Entered from `/itential-setup` when the engineer chooses "Build from a spec." By that point:
- Auth done
- Spec forked to `{use-case}/{use-case}-spec.md`
- Environment data pulled (all data in local files)

```
/solution-design flow:
    1. Read spec + read local environment files (NO API calls)
    2. Collect customer context
    3. Ask only what data can't answer
    4. Update customer spec
    5. ── GATE 1: Present spec for review → engineer approves ──
    6. Produce solution design
    7. ── GATE 2: Present design for review → engineer approves ──
    8. Plan + build everything
```

To modify later: update `{use-case}/{use-case}-spec.md` → re-run from Gate 1.
