# Itential Platform - AI Agent Guide

This project contains skills for assisting developers on the Itential Platform. Read this first, then use the skills for detailed API references.

## Skill Router

Each skill owns a domain. **Invoke the skill using the Skill tool before working in that domain.** Skills contain the correct API methods, request bodies, response shapes, and patterns. Don't guess — load the skill.

| Skill | Owns | When to Use |
|-------|------|-------------|
| `/itential-setup` | **Entry point** | Always start here. Auth, bootstrap, then routes to explore or build-from-spec. |
| `/itential-studio` | Building automation | Create/edit workflows, templates, projects. Discover tasks from the palette. |
| `/itential-workflow-engine` | Running workflows | Start/monitor jobs, utility tasks (query, merge, eval, childJob, forEach), $var resolution, workflow patterns, debugging. |
| `/itential-mop` | Command validation | Command templates, analytic templates, eval types, RunCommandTemplate. |
| `/itential-devices` | Device operations | List devices, get configs, backup, diff, device groups, apply templates. |
| `/itential-golden-config` | Compliance | Golden config trees, config specs, compliance plans, grading, remediation. |
| `/iag` | Automation Gateway | Build IAG services (iagctl), call them from workflows (GatewayManager.runService). |
| `/itential-inventory` | Inventory management | Device inventories, nodes, actions, tags. Required for IAG5. |
| `/itential-lcm` | Lifecycle management | Resource models, instances, actions, execution history. Service lifecycle. |
| `/solution-design` | Spec-driven delivery | Entered from setup. Fork spec, design, refine, plan, build. |

### User Flow

`/itential-setup` is the single entry point. It handles auth + bootstrap, then routes:

```
/itential-setup
  ├── Auth + Bootstrap (always)
  │
  ├── "Build from a spec" → /solution-design
  │     Fork spec → Discover → Design → Refine → Plan → Build
  │     Uses /itential-studio, /itential-workflow-engine, /itential-mop,
  │     /itential-devices, /itential-golden-config, /iag as needed
  │
  └── "Explore / build freestyle"
        /itential-studio — create workflows, templates, projects
        /itential-workflow-engine — run jobs, wire tasks, debug
        /itential-mop — command templates, validation checks
        /itential-devices — device inventory, configs, backups
        /itential-golden-config — compliance, golden config
        /iag — IAG services (Python, Ansible, OpenTofu)
```

**IMPORTANT: Invoke skills using the Skill tool** — don't just reference them in text. When you need to work with devices, invoke `/itential-devices`. When you need to build a workflow, invoke `/itential-studio`. The skills contain the API details you need. Without loading them, you're guessing.

### Key Rule: Look Up Before You Act — Don't Guess

**Skills** teach patterns, workflows, and know-how (how to build a childJob, how to wire variables, how to test).

**`openapi.json`** has every endpoint, method, request body, and response schema. Pulled during bootstrap, stored locally in the use-case directory.

**Before making any API call:**
1. Check the relevant skill for the pattern
2. Search `openapi.json` locally to confirm the endpoint, method, request body, and response schema — `jq '.paths["/the/endpoint"]'`
3. Never hardcode API assumptions — the spec is the source of truth

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

**The filesystem is your debugger.** Every API endpoint, every task schema, every adapter name is already saved locally after bootstrap. Never guess a payload structure, field name, or endpoint path — the answer is in these files. Reading a local file costs zero API calls and zero time.

## Understanding User Intent

Figure out which **category of work** the user needs:

- **Building** — create something new (workflow, template, compliance standard). Start with requirements, then build.
- **Operating** — do something now (configure a device, run compliance, backup configs). Identify targets and execute.
- **Exploring** — understand what's available (devices, adapters, workflows). Bootstrap and navigate.
- **Debugging** — something broke (workflow failing, adapter errors). Get job details, check `job.error`.
- **Designing** — planning architecture (modular workflows, compliance hierarchy). Think before building.

## Developer Flow

### Step 1: Gather Requirements

Before building anything, understand:
- What is the use case?
- What systems are involved? (which adapters)
- What devices? (vendor, OS)
- What should the output be?

### Step 2: Set Up the Environment

Use `/itential-setup` to authenticate and bootstrap. Then use `/itential-devices` and `/itential-studio` to discover what's available.

### Step 3: Build Incrementally

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
3. **Adapter `app` field comes from `apps/list`**, not `tasks/list` (names can be completely different, not just casing). Resolve from bootstrapped `apps.json` and `adapters.json`. When multiple adapter apps exist for the same product, ask the user.
4. **Test each piece individually** before composing into a larger workflow
5. **Check `job.error` for failures**, not just task status
6. **Variable syntax differs by context:**
   - Jinja2 templates: `{{ var }}`
   - Command templates / makeData: `<!var!>`
   - Workflow wiring: `$var.job.x`
   - childJob/merge refs: `{"task": "job", "value": "varName"}`
7. **Validation errors = draft workflow** that cannot be started
8. **`$var` references don't resolve inside object values** (e.g., inside `newVariable` value or adapter `body`) — use `merge`, `makeData`, `query`, or other utility tasks to build the object, then pass it as a top-level `$var` reference
9. **Task IDs are hex-only** — `[0-9a-f]{1,4}`. Non-hex IDs (e.g., `apush`) cause `$var` references to silently fail (classified as static, never resolved)
10. **`genericAdapterRequest` prepends the adapter's `base_path`** to `uriPath` — don't include `/api/v1` in `uriPath`. Use `genericAdapterRequestNoBasePath` if you need the full path
11. **Create projects first, then build inside them** — moving/copying assets into a project re-prefixes names and changes `_id` but does NOT update internal references (childJob workflow refs, template names, transformation IDs)
12. **API response shapes vary** — projects use `{message, data, metadata}`, but workflow and template lists use `{items, skip, limit, total}`, and create endpoints return `{created, edit}`. Always check the response shape before parsing
13. **Project component types** — valid values: `workflow`, `template`, `transformation`, `jsonForm`, `mopCommandTemplate`, `mopAnalyticTemplate`
14. **Use skills, don't reimplement** — each skill owns its domain
15. **When unsure about ANY endpoint, method, or payload — check `openapi.json` FIRST.** Run `jq '.paths["/the/endpoint"]' {use-case}/openapi.json` to see the method, request body schema, and response schema. Don't guess, don't try variations, don't make up field names — look it up. The spec is always right.

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
