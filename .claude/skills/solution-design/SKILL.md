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
{use-case}/spec.md                     ← Customer's spec → GATE 1: engineer approves
        │
        │  Resolve against environment
        ▼
{use-case}/solution-design.md          ← Implementation plan → GATE 2: engineer approves
        │
        │  Build
        ▼
{use-case}/*.json                      ← Built assets (workflows, templates, etc.)
```

**When the customer wants to change something later:** modify `{use-case}/spec.md` and re-run.

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

**Entered from `/itential-setup` after auth and heavy bootstrap are done.** The working directory exists with all data pulled. **Do NOT make additional API calls. Read local files.**

### 1A. Read the Customer Spec

The spec was forked to `{use-case}/spec.md` during setup. Read it and extract:
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

Incorporate ALL engineer input into `{use-case}/spec.md`:
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

Update `{use-case}/spec.md` with every change.

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
1. `{use-case}/spec.md` — what they asked for
2. `{use-case}/solution-design.md` — how it gets built

---

## Phase 4: BUILD

Execute the locked plan step by step.

### For Each Step

1. **Invoke the skill using the Skill tool** — before building any asset, load the relevant skill:
   - Workflows, templates, command templates, projects → invoke `/itential-studio`
   - Devices, backups, diffs, device groups → invoke `/itential-devices`
   - Golden config, compliance → invoke `/itential-golden-config`
   **You MUST invoke the skill before making API calls. Do not guess.**
2. **Start from a helper template** — read the matching file from `helpers/` first, then modify:
   - Command template → `helpers/create-command-template.json`
   - Jinja2 template → `helpers/create-template-jinja2.json`
   - Workflow → `helpers/create-workflow.json` + `helpers/workflow-task-application.json` / `helpers/workflow-task-adapter.json`
   - Project → `helpers/create-project.json` + `helpers/add-components-to-project.json`
   **Do NOT build JSON from scratch. Helpers have correct structure and field names.**
3. **Save locally** — write JSON to `{use-case}/` before sending to the platform
4. **Create on platform** — POST to the API
5. **Test** — run the test from the plan
6. **Review output** — check actual task output, not just job status. CLI commands can fail silently.
7. **Fix and iterate** — edit local JSON, PUT to update (don't recreate)
8. **Move on** — only after the current step passes

### Patterns to Follow

**Variable resolution:**
- `$var.job.x` only resolves as a direct incoming variable value
- `$var` inside nested objects does NOT resolve → use `merge` task

**childJob:**
- `actor` must be `"job"` not `"Pronghorn"`
- Variables: `{"task": "job", "value": "varName"}` syntax, not `$var`
- Empty optionals: `""` not `null`
- Never use `{"task": "static", "value": ["placeholder"]}` — the literal persists

**evaluation:**
- MUST have both `success` AND `failure` transitions

**Error handling:**
- Every task that can fail needs an error transition
- Use try-catch: `newVariable` on both success and error paths

**Adapter naming:**
- `app` from `apps/list` (e.g., `Servicenow`), NOT `tasks/list`
- `adapter_id` from `health/adapters` instance name (e.g., `ServiceNow`)

**Network device config:**
- MOP command templates → checks and validation ONLY (show commands + rules)
- Jinja2 templates → generate config to push
- Push via existing workflow or `itential_cli` task — ask engineer which method
- Test CLI commands on the actual device BEFORE building workflows

**Testing:**
- Command templates: `POST /mop/RunCommandTemplate`
- Jinja2 templates: `POST /template_builder/templates/{name}/renderJinja` with `{"context":{...}}`
- Workflows: `POST /operations-manager/jobs/start`, check with `GET /operations-manager/jobs/{id}`
- **Always review actual task output** — `status: complete` doesn't mean CLI worked

**Iterating:**
- Keep all JSON locally in `{use-case}/`
- Edit local file, `PUT /automation-studio/automations/{id}` with `{"update": {...}}`
- Don't delete and recreate — updating preserves IDs

### On Completion

The `{use-case}/` directory contains everything:

| File | Purpose |
|------|---------|
| `spec.md` | Customer's spec — approved at Gate 1 |
| `solution-design.md` | Implementation plan — approved at Gate 2 |
| `customer-context.md` | Business rules, naming conventions (if provided) |
| `openapi.json` | Platform API reference |
| `tasks.json`, `apps.json`, etc. | Discovery data |
| `wf-*.json`, `cmd-*.json`, `tmpl-*.json` | Built assets |

Deliver:
1. All components created and individually tested
2. End-to-end test passed
3. Acceptance criteria verified
4. Project packaged with all components
5. Access granted to the engineer's team
6. Summary of what was built, how to run it, and what inputs it expects

---

## How This Gets Invoked

Entered from `/itential-setup` when the engineer chooses "Build from a spec." By that point:
- Auth done
- Spec forked to `{use-case}/spec.md`
- Heavy bootstrap done (all data in local files)

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

To modify later: update `{use-case}/spec.md` → re-run from Gate 1.
