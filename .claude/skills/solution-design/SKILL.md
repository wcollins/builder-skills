---
name: solution-design
description: Take a use-case HLD spec and an engineer's environment, produce a solution design, refine it collaboratively, then build it. Use when an engineer wants to implement a use case from a spec file.
argument-hint: "[spec-file-path]"
---

# Solution Design — Open-Spec Development

**Lock intent before touching the environment. Design against the approved intent. Build only from the approved design.**

```
Phase 1: UNDERSTAND          Phase 2: DISCOVER         Phase 3: DESIGN          Phase 4: BUILD
─────────────────            ──────────────────         ──────────────           ──────────────
Read spec                    Auth now                   Produce solution-        Execute locked
Collect business context     Pull bootstrap data          design.md                plan
Ask missing questions        Pull spec-contingent       Reuse / Build / Skip     Test each piece
Refine spec                  Resolve capabilities       Implementation plan      Deliver project
                             Match integrations
        │                    Find reuse                         │
        ▼                            │                          ▼
  GATE 1: spec ✓                     │                    GATE 2: design ✓
  (intent locked)                    │                    (plan locked)
                                     │
                          ◄──────────┘
                  no API calls before Gate 1
```

---

## Document Lifecycle

```
spec-files/spec-*.md                  ← Generic library spec (never modified)
        │
        │  fork (done by /itential-setup)
        ▼
{use-case}/customer-spec.md          ← Customized HLD → GATE 1: engineer approves
        │
        │  auth, discover, resolve, design
        ▼
{use-case}/solution-design.md        ← LLD / implementation plan → GATE 2: engineer approves
        │
        │  build
        ▼
{use-case}/*.json                    ← Built assets (workflows, templates, etc.)
```

---

## Spec File Structure

| Spec Section | What to Extract |
|-------------|----------------|
| **1. Problem Statement** | Context — what are we solving and why |
| **2. High-Level Flow** | The major phases to implement |
| **3. Phases** | What each phase does, decision points, stop/rollback conditions |
| **4. Key Design Decisions** | Constraints to honor during implementation |
| **5. Scope** | What to build, what NOT to build |
| **6. Risks & Mitigations** | Error handling and fallback behavior to build in |
| **7. Requirements** | **Capabilities, Integrations, Discovery Questions — drives design** |
| **8. Batch/Bulk Strategy** | Orchestration pattern if multi-device/multi-record |
| **9. Acceptance Criteria** | How to verify the build is correct |

Section 7 has three parts:
- **Capabilities** — what the platform must do → checked after Gate 1
- **Integrations** — external systems → checked after Gate 1
- **Discovery Questions** — ask when auto-discovery can't answer

---

## Phase 1: UNDERSTAND

**No auth. No API calls. Pure conversation.**

Entered from `/itential-setup` after the spec is forked to `{use-case}/customer-spec.md`.

### 1A. Read the Customer Spec

Read `{use-case}/customer-spec.md` and extract:
- **Phases** from Section 3 (workflow stages)
- **Design decisions** from Section 4 (constraints)
- **Capabilities** table from Section 7 (platform checks — resolved later)
- **Integrations** table from Section 7 (adapter checks — resolved later)
- **Discovery questions** from Section 7 (ask only if needed)
- **Acceptance criteria** from Section 9 (test cases)

### 1B. Collect Customer Context

Ask: *"Do you have existing documentation I should follow? Naming conventions, change policies, runbooks, config standards?"*

Write to `{use-case}/customer-context.md` using the Write tool if provided. If not, move on.

### 1C. Ask Only What's Missing

Go through the spec's Discovery Questions:
- **Already answered by the spec or customer context?** → Skip.
- **Can't answer yet?** → Ask the engineer.

Present what you understand alongside remaining questions.

### 1D. Refine the Spec

Incorporate ALL engineer input into `{use-case}/customer-spec.md`:
- Added requirements → update Section 7
- Changed scope → update Section 5
- Business rules → add to relevant sections
- Changed decisions → update Section 4

The spec must reflect everything the engineer told you.

---

## GATE 1: Spec Approval

**Present the refined spec. Do NOT touch the platform until approved.**

Show:
- Summary of changes from the generic spec
- Their additions (requirements, scope changes, business rules)
- What's in vs out of scope
- Discovery question answers captured

Ask: *"Here's your spec. Review it — add, remove, or change anything. When you approve it, I'll connect to your platform and design the solution."*

The engineer may:
- Add features ("also add a Slack notification step")
- Remove scope ("skip the monitoring integration")
- Change decisions ("auto-rollback, not manual review")
- Adjust acceptance criteria

Update `{use-case}/customer-spec.md` with every change.

**When the engineer approves: the spec is locked.** This is what discovery and design will be based on.

---

## Phase 2: DISCOVER

**Now — and only now — connect to the platform.** The approved spec tells you exactly what data you need.

### 2A. Authenticate

Check for credentials in this order:
1. `{use-case}/.auth.json` — already authenticated (reuse token)
2. `{use-case}/.env` — credentials saved during setup
3. `environments/*.env` — pre-configured environments at repo root

If none found, ask the engineer for:
1. Platform URL
2. Credentials (username/password or client_id/secret)

**Local Development (username/password):**
```
POST /login
Content-Type: application/json

{"username": "admin", "password": "admin"}
```
Returns a token string. Use as query parameter: `GET /endpoint?token=TOKEN`

**Cloud / OAuth (client_credentials):**
```
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

client_id=YOUR_CLIENT_ID
client_secret=YOUR_CLIENT_SECRET
grant_type=client_credentials
```
Returns `{"access_token": "eyJhbG..."}`. Use as Bearer header.

**Save auth for all downstream skills:**
```bash
cat > {use-case}/.auth.json << EOF
{
  "platform_url": "https://platform.example.com",
  "auth_method": "oauth",
  "token": "eyJhbG...",
  "timestamp": "2026-03-13T10:00:00Z"
}
EOF
```

### 2B. Pull Bootstrap Data

Always needed regardless of spec scope. Run in parallel:

```bash
curl -s "{BASE}/help/openapi?url={ENCODED_BASE}&token=TOKEN" > {use-case}/openapi.json
curl -s "{BASE}/workflow_builder/tasks/list?token=TOKEN" > {use-case}/tasks.json
curl -s "{BASE}/automation-studio/apps/list?token=TOKEN" > {use-case}/apps.json
curl -s "{BASE}/health/adapters?token=TOKEN" > {use-case}/adapters.json
curl -s "{BASE}/health/applications?token=TOKEN" > {use-case}/applications.json
```

### 2C. Pull Spec-Contingent Data

**Only pull what the approved spec requires.** Check the spec's capabilities and integrations to decide:

| Data | Pull if spec involves... | API |
|------|--------------------------|-----|
| `devices.json` | Device operations, CLI commands, config changes | `POST /configuration_manager/devices` with `{"options":{"start":0,"limit":1000,"sort":[{"name":1}],"order":"ascending"}}` |
| `workflows.json` | Any phases that might have existing workflows to reuse | `GET /automation-studio/workflows?limit=500` |
| `device-groups.json` | Device group operations, batch by group | `GET /configuration_manager/deviceGroups` |

Response shapes:
- `devices.json` → `{"list": [...]}`
- `workflows.json` → `{"items": [...]}`

Run spec-contingent pulls in parallel after bootstrap succeeds.

**Handling failures:** Before parsing any saved file, check if it contains valid JSON:
```bash
jq type {use-case}/devices.json 2>/dev/null || echo "empty"
```
If invalid, treat as "no data available" — don't block the flow. Not every use case needs every data type.

### 2D. Resolve Capabilities

For each row in the spec's Capabilities table:
- Can the platform do this? → **✓ Resolved**
- Can't + Required? → **⚠ Blocked** (stop and discuss)
- Can't + Not Required? → **✗ Skipped** (use fallback from spec)

### 2E. Resolve Integrations

For each row in the spec's Integrations table:
- Found + Running? → **✓ Resolved** (record adapter name, app name)
- Found + Stopped? → **⚠ Warning** (needs to be started)
- Not found + Required? → **⚠ Blocked** (stop and discuss)
- Not found + Not Required? → **✗ Skipped**

### 2F. Find Reuse Opportunities

Search `workflows.json` for existing workflows that match spec phases. Flag as **↻ Reuse** candidates.

---

## Phase 3: DESIGN

Produce the solution design from the approved spec + discovery results.

### Produce `{use-case}/solution-design.md`

**Write the file to disk** using the Write tool. Contents:

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

### Present for Review

**Present the full solution design. Do NOT proceed to build until approved.**

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

---

## GATE 2: Design Approval

**When the engineer approves: the design is locked.**

Both documents are saved before any building begins:
1. `{use-case}/customer-spec.md` — what they asked for (HLD)
2. `{use-case}/solution-design.md` — how it gets built (LLD)

---

## Phase 4: BUILD

Execute the locked plan step by step.

### Builder Contract

**The workspace is now complete.** The builder receives everything it needs:

```
{use-case}/
  .auth.json              ← auth (ready to use)
  .env                    ← credentials (for re-auth if token expires)
  customer-spec.md        ← locked HLD (Gate 1)
  customer-context.md     ← business rules, naming (if provided)
  solution-design.md      ← locked LLD (Gate 2)
  openapi.json            ← bootstrap
  tasks.json              ← bootstrap
  apps.json               ← bootstrap
  adapters.json           ← bootstrap
  applications.json       ← bootstrap
  devices.json            ← spec-contingent (if spec involves devices)
  workflows.json          ← spec-contingent (if spec involves reuse)
  device-groups.json      ← spec-contingent (if spec involves groups)
  task-schemas.json       ← populated during design as needed
```

**The builder never re-pulls discovery data.** If a file is missing, it stops and tells the user — that's an upstream failure.

The builder's only API calls are:
- **Create** — POST workflows, templates, projects
- **Update** — PUT to edit assets
- **Test** — POST jobs/start, GET job status
- **Schema fetch** — task schemas not yet in `task-schemas.json` (append to file)
- **Re-auth** — if token expires, use `.env` to refresh `.auth.json`

### For Each Build Step

1. **Invoke `/itential-builder`** — covers projects, workflows, templates (Jinja2/TextFSM), command templates (MOP), running jobs, and debugging. Load it once at the start of build.
   - For device-specific operations → invoke `/itential-devices`
   - For compliance → invoke `/itential-golden-config`
   - For IAG services → invoke `/iag`
   **Only load additional skills if the design requires their specific domain.**
2. **Start from a helper template** — read the matching file from `helpers/` first:
   - Command template → `helpers/create-command-template.json`
   - Jinja2 template → `helpers/create-template-jinja2.json`
   - Workflow → `helpers/create-workflow.json` + task helpers
   - childJob task → `helpers/workflow-task-childjob.json`
   - Project → `helpers/create-project.json` + `helpers/add-components-to-project.json`
   **Do NOT build JSON from scratch. Helpers have the correct structure.**
3. **Save locally** — write JSON to `{use-case}/` before sending to the platform
4. **Create on platform** — POST to the API
5. **Test** — run the test from the plan
6. **Review output** — check actual task output, not just job status
7. **When something fails — check local files FIRST:**
   - `openapi.json` → endpoint schema
   - `tasks.json` → task names
   - `task-schemas.json` → already-fetched schemas
   - `apps.json` → correct app casing
   **Don't guess, don't burn API calls — the answer is on disk.**
8. **Fix and iterate** — edit local JSON, PUT to update (don't recreate)
9. **Move on** — only after the current step passes

### Patterns to Follow

**Variable resolution:**
- `$var.job.x` only resolves as a direct top-level incoming variable value
- `$var` inside nested objects does NOT resolve — use `merge`, `makeData`, `query`, or other utility tasks to build the object, then pass it as a top-level `$var` reference

Key reminders:
- **childJob:** `actor: "job"`, variables use `{"task":"job","value":"varName"}` NOT `$var`
- **merge:** uses `"variable"` NOT `"value"` (different from childJob)
- **evaluation:** MUST have both `success` AND `failure` transitions
- **Error transitions:** mandatory on every adapter/external task
- **Adapter `app`:** from `apps.json`, NOT `tasks/list`
- **Testing:** `POST /operations-manager/jobs/start`, check `job.error` for failures
- **Iterating:** edit local JSON, `PUT` to update — don't recreate

### On Completion

Deliver:
1. **Create the project FIRST** — `POST /automation-studio/projects` → get `projectId`
2. Build all assets with names prefixed `@{projectId}: ` so childJob refs are correct from the start
3. If assets were built in global scope, move them with `POST /projects/{id}/components/add` — then **fix childJob `workflow` refs** (platform renames children but does NOT update parent references)
4. All components individually tested
5. End-to-end test passed
6. Acceptance criteria verified
7. Access granted to the engineer's team
8. Summary of what was built, how to run it, and what inputs it expects

---

## How This Gets Invoked

Entered from `/itential-setup` when the engineer chooses "Build from a spec." At that point the workspace contains:

```
{use-case}/
  customer-spec.md    ← forked spec (unmodified, unanalyzed)
  .env                ← credentials (if provided, for later auth)
```

That's it. No auth done. No data pulled. No analysis.

```
/solution-design flow:
    Phase 1: Read spec, collect context, refine (NO API calls)
    ── GATE 1: Present spec → engineer approves → intent locked ──
    Phase 2: Auth, pull bootstrap + spec-contingent, resolve capabilities
    Phase 3: Produce solution-design.md
    ── GATE 2: Present design → engineer approves → plan locked ──
    Phase 4: Build everything from locked plan
```

To modify later: update `{use-case}/customer-spec.md` → re-run from Gate 1.

---

## Gotchas

- OAuth MUST use `Content-Type: application/x-www-form-urlencoded`, not JSON
- Tokens expire mid-session — on auth errors, re-authenticate silently from `.env`
- `tasks/list` `app` field has WRONG casing for adapters — use `apps/list`
- OpenAPI spec is ~1.5MB — search it locally with `jq`, never load into context
