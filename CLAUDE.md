# Itential Platform - AI Agent Guide

This project contains skills for assisting developers on the Itential Platform. Read this first, then use the skills for detailed API references.

## Skill Router

Each skill owns a domain. **Invoke the skill using the Skill tool before working in that domain.** Skills contain the correct API methods, request bodies, response shapes, and patterns. Don't guess — load the skill.

| Skill | Owns | When to Use |
|-------|------|-------------|
| `/itential-setup` | **Entry point** | Always start here. Route: explore (auth + bootstrap) or spec (fork + hand off). |
| `/solution-design` | Spec → design | Understand spec, approve (Gate 1), discover environment, design, approve (Gate 2). |
| `/itential-builder` | **Building everything** | Create projects, workflows, templates (Jinja2/TextFSM), command templates (MOP). Wire tasks, run jobs, debug. |
| `/itential-devices` | Device operations | List devices, get configs, backup, diff, device groups, apply templates. |
| `/itential-golden-config` | Compliance | Golden config trees, config specs, compliance plans, grading, remediation. |
| `/iag` | Automation Gateway | Build IAG services (iagctl), call them from workflows (GatewayManager.runService). |
| `/itential-inventory` | Inventory management | Device inventories, nodes, actions, tags. Required for IAG5. |
| `/itential-lcm` | Lifecycle management | Resource models, instances, actions, execution history. Service lifecycle. |
| `/flowagent` | AI Agents | Create agents, configure LLM providers, discover tools, run missions, track results. |

### User Flow

`/itential-setup` is the entry point. It asks intent, then routes.

```
/itential-setup          → "What are you here to do?"
  │
  ├── "Explore"
  │     Auth → pull bootstrap → summarize → use skills directly
  │
  └── "Build from a spec"
        Pick spec → fork to customer-spec.md → set expectations
        │
        /solution-design → Understand + Gate 1 (spec) → Discover → Design + Gate 2
        /itential-builder → Execute locked plan, test, deliver
```

**Spec-based flow — three layers:**
```
INTENT:       /itential-setup → fork spec → /solution-design Phase 1 → Gate 1
FEASIBILITY:  /solution-design Phase 2-3 → auth, discover, design → Gate 2
EXECUTION:    /itential-builder → build from locked plan, test, deliver
```

**Key principle:** Lock intent before touching the environment. Design against approved intent. Build only from approved design.

**IMPORTANT: Invoke skills using the Skill tool** — don't just reference them in text. When you need to build workflows/templates, invoke `/itential-builder`. When you need to work with devices, invoke `/itential-devices`. The skills contain the API details you need. Without loading them, you're guessing.

### Auth Reuse — Authenticate Once, Reuse Everywhere

**Auth happens when first needed** — in setup (explore path) or in solution-design Phase 2 (spec path). The token is saved to `{use-case}/.auth.json`. Every subsequent skill should:
1. Read `{use-case}/.auth.json` for `platform_url`, `auth_method`, and `token`
2. Use the token for all API calls (Bearer header for OAuth, query param for local)
3. On auth error (401/403): re-authenticate using `{use-case}/.env` and update `.auth.json`
4. **Never ask the user for credentials if `.env` exists**

This means the user authenticates once and every subsequent skill just works.

### Key Rule: Look Up Before You Act — Don't Guess

**Skills** teach patterns, workflows, and know-how (how to build a childJob, how to wire variables, how to test).

**`openapi.json`** has every endpoint, method, request body, and response schema. Pull it locally if not already present, then search — never guess.

**How to get it:**
```bash
# OAuth (cloud)
curl -s "{BASE}/help/openapi?url={ENCODED_BASE}" -H "Authorization: Bearer {TOKEN}" > openapi.json

# Local dev
curl -s "{BASE}/help/openapi?url={ENCODED_BASE}&token={TOKEN}" > openapi.json
```
For explore mode, setup pulls this automatically. For spec mode, solution-design pulls it after Gate 1. If you're working outside those flows, fetch it yourself.

**Before making any API call:**
1. Check the relevant skill for the pattern
2. Search `openapi.json` locally to confirm the endpoint, method, request body, and response schema — `jq '.paths["/the/endpoint"]'`
3. **Check the body wrapper** — most Itential APIs wrap the body in a top-level key. Find it: `jq '.paths["/the/endpoint"].post.requestBody.content["application/json"].schema.properties | keys'` → returns the wrapper name (e.g., `["role"]` means `{role: {...}}`)
4. Never hardcode API assumptions — the spec is the source of truth

**Before fetching task schemas:**
1. Check if `{use-case}/task-schemas.json` exists — search it first with `jq` or `grep`
2. Only call `multipleTaskDetails` for tasks NOT already in the local file
3. After fetching, always append to the local file so future lookups are instant

**Before parsing any local JSON file:**
1. Check the response shape first — `jq type` and `jq keys` on the file
2. The solution-design skill has a file-to-shape table — use it
3. Key shapes to remember:
   - `adapters.json` → `{"results": [...]}`
   - `applications.json` → `{"results": [...]}`
   - `devices.json` → `{"list": [...]}`
   - `workflows.json` → `{"items": [...]}`
   - `apps.json` → plain array `[...]`
   - `tasks.json` → plain array `[...]`
4. Use `jq` for parsing, not inline Python scripts with isinstance fallbacks

**When something fails or returns unexpected data — check local files FIRST:**
1. **`openapi.json`** — verify the endpoint exists, check the method (GET vs POST), read the request body schema and response schema. This file has EVERY endpoint, field, and type. Don't guess what a payload looks like — look it up.
2. **`tasks.json`** — verify the task name, app, location. If a task is "not found," search here first.
3. **`task-schemas.json`** — if you already fetched schemas, the full input/output definition is here. Check field names, types, required vs optional.
4. **`adapters.json` / `apps.json`** — verify adapter instance names, app names, casing. Adapter names from `apps.json` (type name) differ from `adapters.json` (instance name).
5. **`job.error` array** — for runtime errors (not just task status)
6. **Actual task output** — `status: complete` doesn't mean the CLI commands worked

**The filesystem is your debugger.** Every API endpoint, every task schema, every adapter name is already saved locally after setup. Never guess a payload structure, field name, or endpoint path — the answer is in these files. Reading a local file costs zero API calls and zero time.

## Understanding User Intent

Figure out which **category of work** the user needs:

- **Building** — create something new (workflow, template, compliance standard). Start with requirements, then build.
- **Operating** — do something now (configure a device, run compliance, backup configs). Identify targets and execute.
- **Exploring** — understand what's available (devices, adapters, workflows). Discover and navigate.
- **Debugging** — something broke (workflow failing, adapter errors). Get job details, check `job.error`.
- **Designing** — planning architecture (modular workflows, compliance hierarchy). Think before building.

## Developer Flow

### Step 1: Start with Intent

Use `/itential-setup` to decide what you're doing:
- **Explore** — auth, pull bootstrap, browse the platform with skills
- **Build from spec** — pick a spec, fork it, then `/solution-design` handles everything: understand → approve spec (Gate 1) → discover environment → design → approve design (Gate 2)

### Step 2: Build Incrementally (after design is approved)

1. **Check for existing assets to reuse** — search workflows, templates before building new
2. **Test each piece individually** — command templates, Jinja2 templates, child workflows
3. **Create assets and save JSON locally** — in the use-case directory
4. **Test and iterate** — run via `jobs/start`, check results, edit local JSON, PUT to update
5. **Then compose** — connect tested pieces into the full workflow with error handling

### Step 4: Test and Debug

```
POST /operations-manager/jobs/start
{"workflow": "Name", "options": {"type": "automation", "variables": {...}}}
```

```
GET /operations-manager/jobs/{jobId}
```

When something fails: check `job.status`, check `job.error` array, look at `IAPerror.displayString`.

### Step 5: Package and Deliver

1. Create a project: `POST /automation-studio/projects`
2. Add all components: `POST /automation-studio/projects/{id}/components/add`
3. Grant access: `PATCH /automation-studio/projects/{id}` with members

## Key Rules

1. **Never invent task names** — always look them up from `tasks/list`
2. **Always get the schema before building** — `multipleTaskDetails?dereferenceSchemas=true`
3. **Adapter `app` field comes from `apps/list`**, not `tasks/list` (names can be completely different, not just casing). Resolve from local `apps.json` and `adapters.json`. When multiple adapter apps exist for the same product, ask the user.
4. **Test each piece individually** before composing into a larger workflow
5. **Check `job.error` for failures**, not just task status
6. **Variable syntax differs by context:**
   - Jinja2 templates: `{{ var }}`
   - Command templates / makeData: `<!var!>`
   - Workflow wiring: `$var.job.x`
   - childJob variable refs: `{"task": "job", "value": "varName"}`
   - merge/evaluation refs: `{"task": "job", "variable": "varName"}` (NOT `"value"` — different field than childJob)
7. **Validation errors = draft workflow** that cannot be started
8. **`$var` references don't resolve inside object values** (e.g., inside `newVariable` value or adapter `body`) — use `merge`, `makeData`, `query`, or other utility tasks to build the object, then pass it as a top-level `$var` reference
9. **Task IDs are hex-only** — `[0-9a-f]{1,4}`. Non-hex IDs (e.g., `apush`) cause `$var` references to silently fail (classified as static, never resolved)
10. **`genericAdapterRequest` prepends the adapter's `base_path`** to `uriPath` — don't include `/api/v1` in `uriPath`. Use `genericAdapterRequestNoBasePath` if you need the full path
11. **Use `POST /projects/import` to create projects atomically** — build all assets locally, pre-compute the project `_id`, pre-wire childJob `@projectId:` refs, then import everything in one call. Avoid the create-then-move pattern (breaks childJob refs, causes project-locking issues).
12. **API response shapes vary** — projects use `{message, data, metadata}`, but workflow and template lists use `{items, skip, limit, total}`, and create endpoints return `{created, edit}`. Always check the response shape before parsing
13. **Project component types** — valid values: `workflow`, `template`, `transformation`, `jsonForm`, `mopCommandTemplate`, `mopAnalyticTemplate`
14. **Use skills, don't reimplement** — `/itential-builder` covers projects, workflows, templates, MOP, and testing. Only load other skills for their specific domains (devices, compliance, IAG, etc.)
15. **When unsure about ANY endpoint, method, or payload — check `openapi.json` FIRST.** Run `jq '.paths["/the/endpoint"]' {use-case}/openapi.json` to see the method, request body schema, and response schema. Don't guess, don't try variations, don't make up field names — look it up. The spec is always right.
16. **If `openapi.json` is not local, fetch it** — `GET /help/openapi?url={ENCODED_BASE}` and save it. Then search locally.
17. **If the openapi schema is empty for an endpoint** — check the corresponding POST/PUT endpoint's schema for the wrapper pattern. As a last resort, send `{}` and read the `"Missing Params"` error — it lists every required field with name, type, and examples.
18. **Endpoint base paths differ** — task catalog is at `/workflow_builder/tasks/list`, but task schemas are at `/automation-studio/multipleTaskDetails` (NOT `/workflow_builder/multipleTaskDetails`). Don't mix them up.
19. **Error transitions are mandatory on adapter/external tasks** — without an error transition, task errors produce "Job has no available transitions" and the job gets stuck forever. Always add `"state": "error"` transitions on tasks that call adapters or external systems.
20. **Adapter responses are transformed** — adapters reshape the upstream API response. Don't assume the native API's response structure (e.g., ServiceNow `result.sys_id`). Call the adapter endpoint directly or check `openapi.json` to verify the actual response shape before wiring query paths.
21. **Duplicate transition keys to same target** — JSON doesn't allow two keys with the same name. If a task needs both `success` and `error` to reach `workflow_end`, create an error handler task (e.g., `newVariable` to set error status) and route error there, then route that task to `workflow_end`.

## Helper JSON Templates

**ALWAYS start from a helper template when creating assets.** Read the helper file first, then modify it for your use case. Do NOT build JSON from scratch — the helpers have the correct structure, field names, and wrappers.

Helper templates are in `helpers/`:

| File | Purpose |
|------|---------|
| `create-workflow.json` | Workflow scaffold with start/end tasks |
| `workflow-task-adapter.json` | Adapter task template |
| `workflow-task-application.json` | Application task template |
| `workflow-task-childjob.json` | childJob task template (actor: "job") |
| `create-command-template.json` | Command template with `<!var!>` syntax |
| `create-template-jinja2.json` | Jinja2 template |
| `create-template-textfsm.json` | TextFSM template |
| `create-project.json` | Project creation |
| `add-components-to-project.json` | Add assets to project |
| `create-golden-config-tree.json` | Golden config tree |
| `create-golden-config-node.json` | Child node |
| `update-node-config.json` | Node template with full syntax |
| `create-compliance-plan.json` | Compliance plan |
| `run-compliance-plan.json` | Run compliance plan |
| `run-compliance.json` | Run compliance directly |
| `update-command-template.json` | Update command template (full replacement) |
| `import-project.json` | Import a project |
| `update-project-members.json` | Update project membership |
| `add-devices-to-node.json` | Assign devices to a golden config node |
| `lcm-action-workflow.json` | LCM action workflow (must output `instance` variable) |
