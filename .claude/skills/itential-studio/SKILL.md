---
name: itential-studio
description: Create and manage Itential workflows, templates, and projects. Discover tasks from the palette and get schemas. For running workflows and utility tasks, use /itential-builder. For command templates, use /itential-mop.
argument-hint: "[action or use-case]"
---

# Automation Studio - Developer Skills Guide

Automation Studio is the primary development environment within Itential Platform — the IDE where developers create, manage, and organize network automation assets such as workflows, templates, and projects.

## What is Automation Studio?

### Asset Types

Automation Studio is where you create these asset types:

- **Workflow** - Visual automation pipelines composed of tasks connected by transitions on a canvas
- **Transformation** - JST (JSON Schema Transformations) for mapping and reshaping data between tasks
- **Template** - Jinja2 templates (config generation) and TextFSM templates (output parsing)
- **Command Template** - Predefined CLI commands with validation rules for running against devices (details in `/itential-mop`)
- **Analytic Template** - Templates for analyzing command output data (details in `/itential-mop`)
- **JSON Form** - Dynamic forms for collecting user input to feed into workflows

### Projects

Projects are organizational containers that group related assets into deployable units. A project can contain any mix of the asset types above.

### Component Groups

Curated collections of reusable automation components shared across projects.

### Task Palette and Platform Apps

When building a **workflow**, you drag tasks from the **task palette** onto the canvas. The task palette is populated by methods from platform applications and adapters. You cannot invent task names - you must use methods that exist on the platform.

**Platform applications (task sources):**

| Application | Description |
|-------------|-------------|
| WorkFlowEngine | Core engine - provides utility tasks: `query`, `evaluation`, `transformation`, `childJob`, `manual`, `ViewData` |
| ConfigurationManager | Device config, compliance, golden config management |
| OperationsManager | Workflow execution, job management |
| AutomationStudio | Project and asset management |
| GatewayManager | External service execution (Ansible, scripts) |
| LifecycleManager | Resource lifecycle and instance management |
| MOP | Command template execution and validation |
| TemplateBuilder | Template rendering and parsing |
| FormBuilder | Form generation and management |
| JsonForms | JSON-based form handling |
| Jst | JSON Schema Transformations |
| Tags | Tag management across platform |
| NSOManager | Cisco NSO integration |
| AGManager | Automation Gateway management |
| FlowAI | Agent-based automation |
| ServiceCog | Service catalog management |
| WorkflowBuilder | Workflow design utilities |
| tmf-api | TMForum API integration |
| Search | Platform search capabilities |

Additionally, **adapters** provide adapter-specific tasks. Adapter names vary by environment - check `apps/list` and `health/adapters` for your platform's adapter names and instance IDs.

## Task Discovery

**To discover available tasks (REQUIRED before building workflows):**

### Bootstrap: Pull the Task Catalog Locally

Before building workflows, pull the full task catalog to a local use-case directory so you can search it with grep. This avoids hitting the API repeatedly for 11,000+ tasks.

**Create a use-case directory** named after what you're building (e.g., `port-turn-up/`, `firewall-rule-audit/`, `dns-record-mgmt/`).

**Pull all tasks with descriptions:**
```
GET /workflow_builder/tasks/list
```
Save the response to `{use-case}/tasks.json`. This returns **every available task** (11,000+) with names, summaries, descriptions, apps, and variable names:
```json
{
  "name": "renderJinjaTemplate",
  "canvasName": "renderJinjaTemplate",
  "summary": "Render Jinja Template",
  "description": "Renders jinja template output.",
  "location": "Application",
  "locationType": null,
  "app": "TemplateBuilder",
  "type": "automatic",
  "displayName": "TemplateBuilder",
  "variables": {
    "incoming": { "name": null, "context": null },
    "outgoing": { "renderedTemplate": null }
  },
  "deprecated": false
}
```

**Key fields for searching:**
- `name` - method name (e.g., `renderJinjaTemplate`, `createSubnet`)
- `summary` - short label (e.g., `"Render Jinja Template"`)
- `description` - what the task does (e.g., `"Renders jinja template output."`)
- `app` - which application/adapter provides this task
- `displayName` - how it appears in the UI task palette
- `location` - `"Application"` or `"Adapter"`
- `deprecated` - skip tasks where this is `true`
- `variables.incoming` / `variables.outgoing` - variable names (values are `null` here; full schemas come from the task details endpoint)

**Search locally for tasks:**
```bash
# Find tasks related to templates
grep -i "template" {use-case}/tasks.json

# Find tasks from a specific app
grep '"app": "ConfigurationManager"' {use-case}/tasks.json

# Find tasks by description
grep -i "render" {use-case}/tasks.json
```

**Also pull the apps list:**
```
GET /automation-studio/apps/list
```
Save to `{use-case}/apps.json`. Each entry has:
- `name` - the app/adapter name
- `type` - `"Application"` or `"Adapter"` (needed for task details URL)

### Get Full Task Schema (On Demand)

Once you've found a task from the local catalog, get its full input/output schema with types, examples, and validation:

```
GET /automation-studio/locations/{location}/packages/{pckg}/tasks/{method}?dereferenceSchemas=true
```
- `{location}` -> `Application` or `Adapter` (from the task's `location` field, or from apps/list `type`)
- `{pckg}` -> app name (from the task's `app` field)
- `{method}` -> method name (from the task's `name` field)
- Always use `dereferenceSchemas=true` to resolve all `$ref` references inline

**Mapping from tasks/list fields to task details URL:**

| tasks/list field | Maps to |
|------------------|---------|
| `location` (`Application` or `Adapter`) | `{location}` |
| `app` (e.g., `TemplateBuilder`) | `{pckg}` |
| `name` (e.g., `renderJinjaTemplate`) | `{method}` |

**Example:** For `TemplateBuilder.renderJinjaTemplate`:
```
GET /automation-studio/locations/Application/packages/TemplateBuilder/tasks/renderJinjaTemplate?dereferenceSchemas=true
```

**For multiple tasks at once:**
```
POST /automation-studio/multipleTaskDetails?dereferenceSchemas=true
```
```json
{
  "inputsArray": [
    {"location": "Application", "pckg": "TemplateBuilder", "method": "renderJinjaTemplate"},
    {"location": "Application", "pckg": "WorkFlowEngine", "method": "query"}
  ]
}
```

**Task details response (full schema):**
```json
{
  "location": "Application",
  "app": "TemplateBuilder",
  "name": "renderJinjaTemplate",
  "variables": {
    "incoming": {
      "name": {
        "type": "string",
        "description": "Template name",
        "schema": { "type": "string", "examples": ["Template name 1"] }
      },
      "context": {
        "type": "object",
        "description": "Context dictionary to render",
        "schema": { "type": "object", "examples": [{"name": "John", "DOB": "2000/1/1"}] }
      }
    },
    "outgoing": {
      "renderedTemplate": {
        "type": "object",
        "description": "Rendered jinja template",
        "schema": { "type": "object", "examples": [{"renderedTemplate": "John was born in year 2000"}] }
      }
    }
  }
}
```
Use the exact variable names from `incoming` and `outgoing` when wiring task variables in your workflow. Each variable includes a `schema` with type, examples, and validation rules, plus an optional `taskUISchema` describing the UI control (e.g., dropdown with server-side data source).

### nodeLocation Spacing Convention

Follow consistent spacing for readability on the Automation Studio canvas:

| Rule | Value |
|------|-------|
| workflow_start → first task (x-delta) | +264px |
| Sequential task columns (x-delta) | +360px |
| Stacked tasks in same column (y-delta) | +132px |
| Last task → workflow_end (x-delta) | +276px |

**Layout strategy:** Group related tasks vertically at the same x-coordinate:
- A phase's main task + its error handler share the same x, offset by +132px in y
- childJob + output extraction query in the same column
- merge + the adapter call it feeds in the same column

Example for a 3-phase workflow:
```
workflow_start (x=0, y=0)
  Phase 1: x=264   — task1 (y=0), task1_err (y=132)
  Phase 2: x=624   — task2 (y=0), task2_err (y=132)
  Phase 3: x=984   — task3 (y=0), task3_err (y=132)
workflow_end (x=1260, y=0)
```

## API Reference

**Base Path:** `/automation-studio`
**Authentication:** Bearer token (OAuth), Query token, Basic Auth, or Cookie

### Projects

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/automation-studio/projects` | List all projects with pagination and filtering |
| POST | `/automation-studio/projects` | Create a new project |
| GET | `/automation-studio/projects/{projectId}` | Get a single project by ID |
| PATCH | `/automation-studio/projects/{projectId}` | Update an existing project |
| DELETE | `/automation-studio/projects/{id}` | Delete a project and its components |
| GET | `/automation-studio/projects/{id}/export` | Export project as JSON with all inlined components |
| POST | `/automation-studio/projects/import` | Import a project from JSON |
| POST | `/automation-studio/projects/{projectId}/components/add` | Add components to a project |
| DELETE | `/automation-studio/projects/{projectId}/components/{componentId}` | Remove a component from a project |

**Create a project:**
```
POST /automation-studio/projects
```
```json
{
  "name": "My Network Automations",
  "description": "Automations for VLAN provisioning and compliance"
}
```

**Project response** (project object is inside `data`):
```json
{
  "message": "Successfully created project",
  "data": {
    "_id": "699a6b89e3ab0d8da851749f",
    "name": "My Network Automations",
    "description": "Automations for VLAN provisioning and compliance",
    "components": [
      { "iid": 0, "reference": "d8c323f6-...", "type": "workflow", "folder": "/" },
      { "iid": 1, "reference": "699a6b96...", "type": "template", "folder": "/" }
    ],
    "members": [
      { "type": "account", "role": "owner", "reference": "67eaf8b4...", "username": "user@example.com", "provenance": "Okta SAML" },
      { "type": "group", "role": "editor", "reference": "67c859...", "name": "Solutions Engineering" }
    ],
    "accessControl": {
      "manage": ["account:67eaf8b4..."],
      "write": ["account:67eaf8b4..."],
      "execute": ["account:67eaf8b4..."],
      "read": ["account:67eaf8b4..."]
    },
    "created": "2026-02-22T02:35:53.165Z",
    "lastUpdated": "2026-02-22T02:38:27.962Z"
  },
  "metadata": {}
}
```

**Component types within a project:** `workflow`, `template`, `transformation`, `jsonForm`, `mopCommandTemplate`, `mopAnalyticTemplate`

**Add components to a project:**
```
POST /automation-studio/projects/{projectId}/components/add
```
```json
{
  "components": [
    { "type": "workflow", "reference": "d8c323f6-66f1-4242-b4af-a0acd599eda9", "folder": "/" },
    { "type": "template", "reference": "699a6b96e3ab0d8da85174a0", "folder": "/" }
  ],
  "mode": "move"
}
```
- `mode`: two options:
  - `"copy"` — asset stays in global scope AND a copy is added to the project. Both remain accessible.
  - `"move"` — asset is removed from global scope and only exists in the project.
- `folder`: must start with `/`, use `"/"` for root
- `reference`: the `_id` of the asset being added
- **Both modes rename assets** with `@projectId:` prefix and assign new `_id` values. Internal references (childJob `workflow` fields, template names) are NOT updated. See the "Create project FIRST" gotcha below for the fix pattern.

**Update project membership (PATCH):**
```
PATCH /automation-studio/projects/{projectId}
```
```json
{
  "members": [
    { "type": "account", "role": "owner", "reference": "699a67bb3f6ac74ee0dbbe65" },
    { "type": "account", "role": "owner", "reference": "67eaf8b49b093bfbf0e62a9f" }
  ]
}
```
- `members` is a **full replacement** - include ALL members (existing + new) or you will lose them
- `accessControl` is automatically synced from `members` - do not set both manually
- To find a user's account `reference` ID, look at the `members` array of an existing project they belong to
- **Roles:** `owner`, `editor`, `viewer`
- **Member types:** `account` (individual user), `group` (team)

### Workflows

Workflows are the core automation artifacts. Each workflow is a directed graph of tasks connected by transitions on a visual canvas.

> **For running workflows, utility task patterns (childJob, forEach, evaluation), error handling, and $var resolution rules, invoke `/itential-builder`.**

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/automation-studio/workflows` | List workflows with pagination and filtering |
| POST | `/automation-studio/automations` | Create a new workflow |
| PUT | `/automation-studio/automations/{id}` | Update an existing workflow |
| POST | `/automation-studio/automations/import` | Import workflows from JSON |
| GET | `/automation-studio/workflows/detailed/{name}` | Get full workflow details by name |
| POST | `/automation-studio/workflows/validate` | Validate a workflow document |

**Create a workflow:**
```
POST /automation-studio/automations
```

The body wraps the workflow in `{"automation": {...}}`. Required fields:

```json
{
  "automation": {
    "name": "Create VPC Subnet",
    "description": "Creates a subnet in an existing VPC",
    "type": "automation",
    "canvasVersion": 3,
    "encodingVersion": 1,
    "font_size": 12,
    "tasks": {
      "workflow_start": {
        "name": "workflow_start",
        "groups": [],
        "nodeLocation": { "x": 360, "y": 1308 }
      },
      "303c": {
        "name": "createSubnet",
        "canvasName": "createSubnet",
        "summary": "Create Subnet",
        "description": "Creates a subnet in an existing VPC.",
        "location": "Adapter",
        "locationType": "Awsec2",
        "app": "Awsec2",
        "type": "automatic",
        "displayName": "Awsec2",
        "variables": {
          "incoming": {
            "cidrBlock": "$var.job.cidrBlock",
            "vpcId": "$var.job.vpcId",
            "adapter_id": "$var.job.adapterId"
          },
          "outgoing": {
            "result": null
          },
          "error": "",
          "decorators": []
        },
        "groups": [],
        "actor": "Pronghorn",
        "scheduled": false,
        "nodeLocation": { "x": 600, "y": 1308 }
      },
      "b647": {
        "name": "query",
        "canvasName": "query",
        "summary": "Query Subnet ID",
        "description": "Extracts the subnet ID from the create response",
        "location": "Application",
        "locationType": null,
        "app": "WorkFlowEngine",
        "type": "operation",
        "displayName": "WorkFlowEngine",
        "variables": {
          "incoming": {
            "pass_on_null": false,
            "query": "response.CreateSubnetResponse.subnet.subnetId",
            "obj": "$var.303c.result"
          },
          "outgoing": {
            "return_data": "$var.job.subnetId"
          },
          "error": "",
          "decorators": []
        },
        "groups": [],
        "scheduled": false,
        "nodeLocation": { "x": 912, "y": 1308 }
      },
      "workflow_end": {
        "name": "workflow_end",
        "groups": [],
        "nodeLocation": { "x": 1152, "y": 1308 }
      }
    },
    "transitions": {
      "workflow_start": {
        "303c": { "type": "standard", "state": "success" }
      },
      "303c": {
        "b647": { "type": "standard", "state": "success" }
      },
      "b647": {
        "workflow_end": { "type": "standard", "state": "success" }
      },
      "workflow_end": {}
    },
    "groups": [],
    "inputSchema": {
      "type": "object",
      "properties": {
        "cidrBlock": { "title": "cidrBlock", "type": "string" },
        "vpcId": { "title": "vpcId", "type": "string" },
        "adapterId": { "type": "string" }
      },
      "required": ["cidrBlock", "vpcId", "adapterId"]
    },
    "outputSchema": {
      "type": "object",
      "properties": {
        "subnetId": { "title": "return_data", "type": "string" }
      }
    }
  }
}
```

**Key workflow structure concepts:**

- **Task IDs** are short hex strings (e.g., `303c`, `b647`). `workflow_start` and `workflow_end` are special reserved IDs.
- **Task `name`** must be an actual method from a platform app or adapter (from the task palette). You cannot invent task names.
- **Task `canvasName`** must come from the task palette's `canvasName` field — NOT the method name and NOT a custom label. `canvasName` controls the icon and display in the UI. Some differ from `name`: `arrayPush` → `push`, `stringConcat` → `concat`. Get it from `tasks/list`.
- **Task `location`**: `"Application"` for platform apps, `"Adapter"` for adapters, `"Broker"` for broker calls
- **Task `app`**: for Applications use the app name (e.g., `WorkFlowEngine`). For Adapters use the **`apps/list` `name`** value — NOT `tasks/list` (names can be completely different, not just casing). Resolve from `apps.json` and `adapters.json` (bootstrapped locally). When multiple adapter apps exist for the same product, ask the user.
- **Task `locationType`**: `null` for Applications. For Adapters, same as `app` (from `apps/list`).
- **Task `displayName`**: UI display label. May differ from `app` (e.g., `displayName: "ServiceNow"` but `app: "Servicenow"`).
- **Task `type`**: `"automatic"` for adapter calls and most app calls, `"operation"` for WorkFlowEngine utility tasks (query, evaluation, merge, etc.)
- **Adapter tasks require `adapter_id`** in incoming variables, specifying which adapter instance to use. Get the instance name from `health/adapters`.
- **Variable references** use `$var` syntax:
  - `$var.job.fieldName` - references a workflow input parameter
  - `$var.taskId.outgoingVar` - references output from a previous task (e.g., `$var.303c.result`)
- **Transitions** define flow between tasks. Each entry maps a source task ID to target task IDs with `state` and `type` (`standard`)
- **Transition `state`** maps to task **finish states**:
  - `success` - task executed without error (all tasks can produce this)
  - `error` - task encountered errors during execution (all tasks can produce this)
  - `failure` - evaluation didn't match or query returned undefined (only `evaluation` and `query` tasks produce this)
  - `loop` - forEach loop iteration (only `forEach` tasks produce this)
- **Transition `type`**:
  - `standard` - moves forward in the workflow
  - `revert` - moves **backward** to a previous task (for retry loops)
- `workflow_end` transition must be an empty object `{}`
- `canvasVersion: 3` and `encodingVersion: 1` are required for current platform versions
- Workflows added to a project get auto-prefixed: `@projectId: Workflow Name`

**Common utility tasks (frequently used in workflows):**

| App | Task Name | Purpose | Key Incoming Variables |
|-----|-----------|---------|----------------------|
| WorkFlowEngine | `query` | Extract data from an object using a dot-path query | `query` (dot-path string), `obj` (source object), `pass_on_null` |
| WorkFlowEngine | `evaluation` | Conditional branching based on comparisons | `all_true_flag`, `evaluation_groups` with operand comparisons |
| WorkFlowEngine | `transformation` | Run a JST transformation inline | `tr_id`, `sample_data`, `jst_data` |
| WorkFlowEngine | `childJob` | Start another workflow as a sub-job | `workflow` (name), `variables`, `data_array`, `loopType` |
| WorkFlowEngine | `forEach` | Loop over array items | `data_array` (array to iterate) -> `current_item` |
| WorkFlowEngine | `delay` | Pause a job for N seconds | `time` (seconds) |
| WorkFlowEngine | `newVariable` | Create a new job variable at runtime | `name` (var name), `value` (any) |
| WorkFlowEngine | `stringConcat` | Concatenate strings | `str` (first string), `stringN` (second or array) -> `combinedStrings` |
| WorkFlowEngine | `toUpperCase` | Convert string to uppercase | `str` -> `uppercaseString` |
| WorkFlowEngine | `arrayConcat` | Merge two arrays | `arr` (first), `arrayN` (second) -> `combinedArray` |
| WorkFlowEngine | `ViewData` | Display data for manual inspection | data variables |
| WorkFlowEngine | `merge` | Merge key-value pairs into a single object | `data_to_merge` (array of `{key, value}` where inner `value` is `{"task":"...", "variable":"..."}` — field is `variable` NOT `value`) -> `merged_object` |
| WorkFlowEngine | `deepmerge` | Deep merge using extend | `data_to_merge` -> `merged_object` |
| WorkFlowEngine | `makeData` | Convert input to a different data type with variable substitution | `input` (string with `<!var!>` placeholders), `outputType` (boolean/json/number/string), `variables` -> `output` |
| WorkFlowEngine | `parse` | Parse a JSON string into an object | `text` (JSON string) -> `textObject` |
| TemplateBuilder | `renderJinja2ContextWithCast` | Render an inline Jinja2 template (no stored template needed) | `template` (inline string), `variables` (object), `castDataType` (string) -> `renderedTemplate` |
| TemplateBuilder | `renderJinja2TemplateWithCast` | Render a stored template by name with data cast | `name` (template name), `variables` (object), `castDataType` (string) -> `renderedTemplate` |
| TemplateBuilder | `renderJinjaTemplate` | Render a Jinja2 template by name with variables | `name` (template name), `context` (variables object) |
| TemplateBuilder | `parseTemplate` | Parse text output using a TextFSM template | template and data inputs |

### Templates (Jinja2, TextFSM)

Templates are Jinja2 or TextFSM documents used to generate device configurations or parse command output.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/automation-studio/templates` | List templates with pagination and filtering |
| POST | `/automation-studio/templates` | Create a new template |
| GET | `/automation-studio/templates/{id}` | Get a single template |
| PUT | `/automation-studio/templates/{id}` | Update a template |
| DELETE | `/automation-studio/templates/{id}` | Delete a template |
| GET | `/automation-studio/templates/{id}/export` | Export a template as JSON |
| POST | `/automation-studio/templates/import` | Import templates from JSON |

**Create a template:**
```
POST /automation-studio/templates
```
```json
{
  "template": {
    "name": "VLAN Interface Config",
    "type": "jinja2",
    "group": "Cisco IOS",
    "command": "configure terminal",
    "description": "Generates VLAN interface configuration for Cisco IOS devices",
    "template": "interface Vlan{{ vlan_id }}\n description {{ description }}\n ip address {{ ip_address }} {{ subnet_mask }}\n no shutdown",
    "data": "{\"vlan_id\": 100, \"description\": \"Management VLAN\", \"ip_address\": \"10.0.1.1\", \"subnet_mask\": \"255.255.255.0\"}"
  }
}
```

**Required fields:** `name`, `group`, `command`, `description`, `template`, `data`, `type`

**Template types:**
- `jinja2` - Jinja2 templates for generating device configurations. The `data` field contains sample JSON variables.
- `textfsm` - TextFSM templates for parsing CLI output into structured data. The `data` field contains sample CLI output.

**Template response includes an edit link:**
```json
{
  "created": { "_id": "699a6b96...", "name": "VLAN Interface Config", ... },
  "edit": "/automation-studio/#/edit?tab=0&template=699a6b96..."
}
```

### Component Groups

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/automation-studio/component-groups` | List component groups |
| POST | `/automation-studio/component-groups` | Create a component group |
| GET | `/automation-studio/component-groups/{id}` | Get a single component group |
| PUT | `/automation-studio/component-groups/{id}` | Update a component group |
| DELETE | `/automation-studio/component-groups/{id}` | Delete a component group |
| POST | `/automation-studio/component-groups/import` | Import component groups |

### Developer Utilities

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/workflow_builder/tasks/list` | **Primary task catalog** - all 11,000+ tasks with name, summary, description, app, variables, deprecated flag. Save locally and search with grep. |
| GET | `/automation-studio/apps/list` | List all apps and adapters with name and type (Application/Adapter) |
| GET | `/automation-studio/locations/{location}/packages/{pckg}/tasks/{method}?dereferenceSchemas=true` | Get full input/output schema for a specific task (with types, examples, validation) |
| POST | `/automation-studio/multipleTaskDetails?dereferenceSchemas=true` | Get full schemas for multiple tasks in one call |
| GET | `/automation-studio/references-to?target-type={type}&_id={id}` | Find what references a document (`target-type`: workflow, template, transformation, form, json-form, command-template, analytic-template) |
| POST | `/automation-studio/discoverReferences` | Discover all referenced resources recursively |

## Common Query Parameters

All list endpoints support these filtering parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `limit` | integer | Results per page (default: 25) |
| `skip` | integer | Results to skip for pagination |
| `order` | integer | Sort direction: 1 ascending, -1 descending |
| `sort` | string | Field to sort by (default: `name`) |
| `include` | string | Comma-separated fields to include in response |
| `exclude` | string | Comma-separated fields to exclude from response |
| `equals` | string | Exact field match filter |
| `contains` | string | Substring match filter. **Requires field specifier:** `contains=name:searchterm` not just `contains=searchterm`. Without a field, it may return all results. |
| `starts-with` | string | Prefix match filter |
| `ends-with` | string | Suffix match filter |
| `in` | string | Match one of given values |
| `not-in` | string | Exclude given values |
| `exclude-project-members` | boolean | Exclude items that belong to a project (default: `true` — project workflows are hidden from listings unless set to `false`) |

## Gotchas

**Adapter `app` field is tricky — don't guess, look it up.** The `app` field for adapter tasks MUST come from `apps/list`, NOT `tasks/list`. It's not just a casing difference — the names can be completely different (e.g., `tasks/list` says `ServiceNow-Integration` but `apps/list` says `ServiceNow Change Management API:latest`). Some products have multiple adapter apps (`Servicenow`, `ServicenowOmt`, `ServiceNow Change Management API:latest`). Wrong `app` causes "No such Method" errors. **Resolve it from bootstrapped files:**
1. `jq '.[].name' {use-case}/apps.json` — list all app names (correct values)
2. `jq '.results[] | select(.package_id | contains("servicenow"))' {use-case}/adapters.json` — find adapter instances
3. Check `{use-case}/environment.md` — maps instance names to type names
4. If still multiple options, ask the user which adapter to use

**Create project FIRST, then build inside it.** The project-first pattern:
```
1. POST /automation-studio/projects              → get projectId
2. Name all assets with prefix: "@{projectId}: My Workflow"
3. POST /automation-studio/automations           → create workflows with prefixed names
4. childJob workflow refs already use the correct prefixed child names
5. POST /projects/{id}/components/add            → add all to project
6. PATCH /automation-studio/projects/{id}        → grant team access (members)
7. Run — everything works, no broken refs
```
**Why:** Moving existing workflows into a project renames them with `@projectId:` prefix and assigns new `_id` values, but does NOT update internal references (childJob `workflow` fields, template names, transformation IDs). Building inside the project from the start avoids this entirely.

**If you already moved and refs are broken:**
1. `GET /automation-studio/projects/{id}` → find new component names
2. `GET /automation-studio/workflows/detailed/{urlEncodedNewName}` → get parent
3. Update each childJob `variables.incoming.workflow` to the new `@projectId: name`
4. `PUT /automation-studio/automations/{newId}` with `{"update": {...}}`

**Component type is `mopCommandTemplate` not `mop`:** Valid `type` values for `POST /automation-studio/projects/{id}/components/add`:

| Type | Asset |
|------|-------|
| `workflow` | Workflows |
| `template` | Jinja2 / TextFSM templates |
| `transformation` | JST transformations |
| `jsonForm` | JSON forms |
| `mopCommandTemplate` | MOP command templates (**not** `mop`) |
| `mopAnalyticTemplate` | MOP analytic templates |

**Template `group` field cannot be empty or whitespace-only.** Use a real group name (e.g., `"Cisco IOS"`, `"test"`) or omit the field. Empty string `""` causes: `"Field 'group' can not contain only whitespace characters"`.

**Create responses use `{created, edit}` shape** — NOT `{message, data, metadata}`. Both workflow and template creation return:
```json
{
  "created": { "_id": "...", "name": "...", ... },
  "edit": "/automation-studio/#/edit?..."
}
```
Extract `_id` from `response.created._id`.

**Workflows moved into a project are hidden from listings.** `GET /automation-studio/workflows` excludes project-owned workflows by default. To find them, either use `exclude-project-members=false` or access directly via `GET /automation-studio/workflows/detailed/{urlEncodedName}`.

**`copy` mode silently no-ops for pre-prefixed workflows.** If a workflow name already starts with `@projectId:`, using `mode: "copy"` returns success but doesn't actually add the component. Use `mode: "move"` instead.

**Template and workflow list responses use `{items}` shape** — `GET /automation-studio/templates` and `GET /automation-studio/workflows` both return `{items, skip, limit, total}`, NOT `{message, data, metadata}`. Only project endpoints use the `{message, data, metadata}` wrapper.

**TextFSM templates may have control chars that break jq:** `GET /automation-studio/templates` may return TextFSM templates alongside Jinja2 templates. TextFSM content can contain control characters that break `jq` parsing. Use Python with a control-character strip:
```python
import re, json
raw = open("templates.json").read()
clean = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', raw)
templates = json.loads(clean)
```

**Validation errors = draft workflow that cannot be started:** Workflow creation succeeds even with validation errors. Zero errors means all tasks exist on the platform. `"Method not found"` means the task name does not match any method on that app. Workflows with validation errors become **drafts** and cannot be started with `jobs/start` until errors are resolved.

**Project members PATCH is full replacement:** When updating project members via `PATCH /automation-studio/projects/{id}`, the `members` array is a **full replacement**. Include ALL members (existing + new) or you will lose them. `accessControl` is automatically synced from `members`.

**Variable syntax differs by context:**

| Context | Syntax | Example |
|---------|--------|---------|
| Jinja2 templates | `{{ var }}` | `interface Vlan{{ vlan_id }}` |
| Command templates (MOP) | `<!var!>` | `show interface <!interface!>` |
| `makeData` input | `<!var!>` | `{"name": "<!name!>", "ip": "<!ipaddress!>"}` |
| Workflow variable refs | `$var.job.x` or `$var.taskId.x` | `$var.job.deviceName` |
| childJob variable refs | `{"task":"job","value":"varName"}` | `{"task": "static", "value": ["a"]}` |
| merge/evaluation refs | `{"task":"job","variable":"varName"}` | `{"task": "static", "variable": "success"}` |

**Template names:** Use underscores or simple characters in template names (e.g., `IOS_Switchport_Config`). The `name` field is used by `TemplateBuilder.renderJinjaTemplate` to look up the template at runtime.

**Error transitions are mandatory on adapter tasks.** Without an error transition, task errors cause "Job has no available transitions" and the job gets stuck forever. Every adapter task MUST have both a `success` and `error` transition:
```json
"a1": {
  "b2": {"type": "standard", "state": "success"},
  "err1": {"type": "standard", "state": "error"}
}
```
**JSON duplicate key problem:** If both success and error need to go to `workflow_end`, you can't use `workflow_end` twice as a JSON key. Route the error to an intermediate task (e.g., a `newVariable` task that sets an error flag), then route that task to `workflow_end`.

**Adapter responses are transformed.** Don't assume the upstream API's native response shape. For example, ServiceNow's Table API returns `result.sys_id`, but the Itential ServiceNow adapter flattens it to `response.id`. Always verify adapter response shapes by calling the adapter endpoint directly or checking `openapi.json` before wiring query paths.

**Endpoint base paths differ for task discovery vs. task schemas:**
- Task catalog: `GET /workflow_builder/tasks/list`
- Task schemas: `GET /automation-studio/locations/{loc}/packages/{pkg}/tasks/{method}` or `POST /automation-studio/multipleTaskDetails`
- Do NOT use `/workflow_builder/multipleTaskDetails` — it doesn't exist (returns HTML 404)


## Bootstrap Output

Running `bootstrap.sh` creates the following files in your use-case directory:

| File | Contents |
|------|----------|
| `tasks.json` | Full task catalog (11,000+) - searchable with grep by name/summary/description/app |
| `apps.json` | All apps and adapters with name and type (Application/Adapter) |
| `adapters.json` | Adapter instance details: `id` (instance name), `package_id` (adapter type), `state`, `connection.state` |
| `applications.json` | Application details with state and description |
| `environment.md` | Human-readable overview: apps with task counts, adapters with instance name -> type mapping, top task sources |

The `environment.md` is especially important because it maps adapter **instance names** to adapter **type names**. The `app` field in workflow tasks uses the type name (from `apps/list`), while `adapter_id` uses the instance name (from `health/adapters`). These often differ in casing and naming.

After discovering tasks, save full schemas locally too:
```
POST /automation-studio/multipleTaskDetails?dereferenceSchemas=true -> save to {use-case}/task-schemas.json
```

## Helper Templates

**ALWAYS read the matching helper file before creating an asset.** The helpers have the correct JSON structure, field names, and API wrappers. Read the file, modify it for your use case, then POST it. Do NOT build JSON from scratch.

Helpers are in the `helpers/` directory at repo root:

| File | API Call | Description |
|------|----------|-------------|
| `create-project.json` | `POST /automation-studio/projects` | Create a new project |
| `create-template-jinja2.json` | `POST /automation-studio/templates` | Create a Jinja2 template |
| `create-template-textfsm.json` | `POST /automation-studio/templates` | Create a TextFSM template |
| `create-workflow.json` | `POST /automation-studio/automations` | Create a workflow (skeleton with start/end) |
| `workflow-task-application.json` | N/A (embed in workflow) | Application task template (e.g., WorkFlowEngine, TemplateBuilder) |
| `workflow-task-adapter.json` | N/A (embed in workflow) | Adapter task template (e.g., Awsec2, ServiceNow) |
| `workflow-task-childjob.json` | N/A (embed in workflow) | childJob task template with correct `actor: "job"` and empty field defaults |
| `add-components-to-project.json` | `POST /automation-studio/projects/{id}/components/add` | Add assets to a project |
| `update-project-members.json` | `PATCH /automation-studio/projects/{id}` | Update project membership |
| `import-project.json` | `POST /automation-studio/projects/import` | Import a project |
| `bootstrap.sh` | Multiple | Bootstraps a use-case directory with task catalog, apps, adapters, and environment overview |

> **For command template helpers** (`create-command-template.json`, `update-command-template.json`), **invoke `/itential-mop`.**

## Developer Scenarios

### 1. Create a project with a template and workflow
```
1. Bootstrap:  ./helpers/bootstrap.sh {use-case} {platform-url} {client-id} {client-secret}
               -> creates {use-case}/ with tasks.json, apps.json, adapters.json, environment.md
2. Discover:   Search {use-case}/tasks.json locally to find tasks by name/summary/description/app
3. Get schemas: POST /automation-studio/multipleTaskDetails?dereferenceSchemas=true
               -> save to {use-case}/task-schemas.json
4. Create:     POST /automation-studio/projects           (project)
               POST /automation-studio/templates          (templates)
               POST /automation-studio/automations        (workflow - use real task names + schemas from step 3)
5. Assemble:   POST /automation-studio/projects/{id}/components/add
6. Access:     PATCH /automation-studio/projects/{id}     (members)
```
### 2. Bootstrap the environment
```
./helpers/bootstrap.sh port-turn-up https://platform.example.com client123 secret456

Creates:
  {use-case}/tasks.json        - 11,000+ tasks with name, summary, description, app
  {use-case}/apps.json         - apps and adapters with types
  {use-case}/adapters.json     - adapter instance details (instance name -> adapter type)
  {use-case}/applications.json - application details with state
  {use-case}/environment.md    - human-readable overview with task counts
```

### 3. Explore available tasks for workflow building
```
GET /workflow_builder/tasks/list -> all 11,000+ tasks with name, summary, description, app, variables
Search locally by keyword/app/description
GET /automation-studio/locations/{location}/packages/{app}/tasks/{method}?dereferenceSchemas=true -> full schema for a specific task
POST /automation-studio/multipleTaskDetails?dereferenceSchemas=true -> full schemas for multiple tasks at once
```

### 4. Understand an existing workflow
```
GET /automation-studio/workflows?include=name,tasks,transitions -> list workflows with structure
GET /automation-studio/workflows/detailed/{name} -> full details including task variables
POST /automation-studio/discoverReferences -> find all dependencies
GET /automation-studio/references-to?target-type=workflow&_id={id} -> find what references this workflow
```

### 5. Import/Export for CI/CD
```
GET /automation-studio/projects/{id}/export -> self-contained JSON with all components inlined
POST /automation-studio/projects/import -> deploy to another environment
POST /automation-studio/automations/import -> import workflows individually
POST /automation-studio/templates/import -> import templates individually
```

### 6. Manage project access
```
GET an existing project to see current members
PATCH /automation-studio/projects/{id} with {"members": [...all members...]}
Note: members is a full replacement - include existing + new members
accessControl is auto-synced from members
```

## Security & Access Control

- **Roles:** `owner`, `editor`, `viewer`
- **Member types:** `account` (individual user), `group` (team)
- **Access control scopes:** `manage`, `write`, `execute`, `read` (auto-synced from members)
- **API Permissions:** `AutomationStudio.admin`, `AutomationStudio.designer`, `AutomationStudio.readonly`, `AutomationStudio.apiread`, `AutomationStudio.apiwrite`
