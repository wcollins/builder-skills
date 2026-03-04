---
name: itential-studio
description: Build and manage Itential workflows, templates, command templates, adapter tasks, and projects. Use when the user needs to create automation, run jobs, or work with the task palette.
argument-hint: "[action or use-case]"
---

# Automation Studio - Developer Skills Guide

Automation Studio is the primary development environment within Itential Platform for building, managing, and organizing network automation artifacts. It is the IDE where developers create, test, and organize automation assets.

## What is Automation Studio?

### Asset Types

Automation Studio is where you create these asset types:

- **Workflow** - Visual automation pipelines composed of tasks connected by transitions on a canvas
- **Transformation** - JST (JSON Schema Transformations) for mapping and reshaping data between tasks
- **Template** - Jinja2 templates (config generation) and TextFSM templates (output parsing)
- **Command Template** - Predefined CLI commands with validation rules for running against devices
- **Analytic Template** - Templates for analyzing command output data
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
| AutomationAgency | Agent-based automation |
| ServiceCog | Service catalog management |
| WorkflowBuilder | Workflow design utilities |
| tmf-api | TMForum API integration |
| Search | Platform search capabilities |

Additionally, **adapters** provide adapter-specific tasks. Adapter names vary by environment - check `apps/list` and `health/adapters` for your platform's adapter names and instance IDs.

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
- `{location}` → `Application` or `Adapter` (from the task's `location` field, or from apps/list `type`)
- `{pckg}` → app name (from the task's `app` field)
- `{method}` → method name (from the task's `name` field)
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
- `mode`: `"move"` (move into project) or `"copy"` (copy into project)
- `folder`: must start with `/`, use `"/"` for root
- `reference`: the `_id` of the asset being added
- When moved into a project, assets are automatically renamed with prefix `@projectId: `

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

**Key workflow concepts:**

- **Task IDs** are short hex strings (e.g., `303c`, `b647`). `workflow_start` and `workflow_end` are special reserved IDs.
- **Task `name`** must be an actual method from a platform app or adapter (from the task palette). You cannot invent task names.
- **Task `location`**: `"Application"` for platform apps, `"Adapter"` for adapters, `"Broker"` for broker calls
- **Task `app`**: for Applications use the app name (e.g., `WorkFlowEngine`). For Adapters use the **`apps/list` `name`** value (e.g., `Servicenow`, `AutomationGateway`). **CRITICAL: `tasks/list` `app` field has WRONG casing for adapters** (e.g., `ServiceNow` vs correct `Servicenow`). Always use `apps/list` as the source of truth. Wrong casing causes "No config found for Adapter" errors.
- **Task `locationType`**: `null` for Applications. For Adapters, same as `app` (from `apps/list`).
- **Task `displayName`**: UI display label. May differ from `app` (e.g., `displayName: "ServiceNow"` but `app: "Servicenow"`).
- **Task `type`**: `"automatic"` for adapter calls and most app calls, `"operation"` for WorkFlowEngine utility tasks (query, evaluation, merge, etc.)
- **Adapter tasks require `adapter_id`** in incoming variables, specifying which adapter instance to use. Get the instance name from `health/adapters`: `"adapter_id": "ServiceNow"`. When creating workflows via API, pass values as plain strings - do NOT wrap in extra quotes.
- **Adapter error debugging**: always check `job.error` array (not just task status) for runtime errors. Adapter errors include `icode`, `IAPerror.displayString`, and `recommendation` that tell you exactly what failed (e.g., missing required fields in the request body, schema validation errors).
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
  - `revert` - moves **backward** to a previous task (for retry loops). Example: on config push error, revert to the render step so the user can fix and retry.
- `workflow_end` transition must be an empty object `{}`
- `canvasVersion: 3` and `encodingVersion: 1` are required for current platform versions
- Workflows added to a project get auto-prefixed: `@projectId: Workflow Name`
- **Validation errors** are returned in the `errors` array (e.g., `"Method not found"` if a task name doesn't exist on the specified app). Workflows with validation errors become **drafts** and cannot be started with `jobs/start` until errors are resolved.

**Common utility tasks (frequently used in workflows):**

| App | Task Name | Purpose | Key Incoming Variables |
|-----|-----------|---------|----------------------|
| WorkFlowEngine | `query` | Extract data from an object using a dot-path query | `query` (dot-path string), `obj` (source object), `pass_on_null` |
| WorkFlowEngine | `evaluation` | Conditional branching based on comparisons | `all_true_flag`, `evaluation_groups` with operand comparisons |
| WorkFlowEngine | `transformation` | Run a JST transformation inline | `tr_id`, `sample_data`, `jst_data` |
| WorkFlowEngine | `childJob` | Start another workflow as a sub-job | `workflow` (name), `variables`, `data_array`, `loopType` |
| WorkFlowEngine | `forEach` | Loop over array items | `data_array` (array to iterate) → `current_item` |
| WorkFlowEngine | `delay` | Pause a job for N seconds | `time` (seconds) |
| WorkFlowEngine | `newVariable` | Create a new job variable at runtime | `name` (var name), `value` (any) |
| WorkFlowEngine | `stringConcat` | Concatenate strings | `str` (first string), `stringN` (second or array) → `combinedStrings` |
| WorkFlowEngine | `toUpperCase` | Convert string to uppercase | `str` → `uppercaseString` |
| WorkFlowEngine | `arrayConcat` | Merge two arrays | `arr` (first), `arrayN` (second) → `combinedArray` |
| WorkFlowEngine | `ViewData` | Display data for manual inspection | data variables |
| WorkFlowEngine | `merge` | Merge key-value pairs into a single object | `data_to_merge` (array of `{key, value}` pairs) → `merged_object` |
| WorkFlowEngine | `deepmerge` | Deep merge using extend | `data_to_merge` → `merged_object` |
| WorkFlowEngine | `makeData` | Convert input to a different data type with variable substitution | `input` (string with `<!var!>` placeholders), `outputType` (boolean/json/number/string), `variables` → `output` |
| WorkFlowEngine | `parse` | Parse a JSON string into an object | `text` (JSON string) → `textObject` |
| TemplateBuilder | `renderJinja2ContextWithCast` | Render an inline Jinja2 template (no stored template needed) | `template` (inline string), `variables` (object), `castDataType` (string) → `renderedTemplate` |
| TemplateBuilder | `renderJinja2TemplateWithCast` | Render a stored template by name with data cast | `name` (template name), `variables` (object), `castDataType` (string) → `renderedTemplate` |
| TemplateBuilder | `renderJinjaTemplate` | Render a Jinja2 template by name with variables | `name` (template name), `context` (variables object) |
| TemplateBuilder | `parseTemplate` | Parse text output using a TextFSM template | template and data inputs |

### Templates

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

### Command Templates

Command templates define CLI commands to run against devices with validation rules. They are used for pre-checks, post-checks, and compliance validation.

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/mop/createTemplate` | Create a command template |
| GET | `/mop/listTemplates` | List all command templates |
| GET | `/mop/listATemplate/{name}` | Get a command template by name |
| POST | `/mop/updateTemplate/{mopID}` | Update a command template |
| POST | `/mop/deleteTemplate/{id}` | Delete a command template |

**Create a command template:**
```
POST /mop/createTemplate
```
```json
{
  "mop": {
    "name": "Port_Turn_Up_Pre_Check",
    "description": "Validates interface and VLAN before port turn-up",
    "os": "",
    "passRule": true,
    "commands": [
      {
        "command": "show interface <!interface!>",
        "passRule": true,
        "rules": [
          {
            "rule": "line protocol is",
            "eval": "contains",
            "severity": "error",
            "evaluation": "pass"
          }
        ]
      },
      {
        "command": "show vlan brief",
        "passRule": true,
        "rules": [
          {
            "rule": "<!vlan_id!>",
            "eval": "contains",
            "severity": "error",
            "evaluation": "pass"
          }
        ]
      }
    ]
  }
}
```

**Command template structure:**
- **`passRule`** (top-level) - `true` = all commands must pass (AND), `false` = one command must pass (OR)
- **`commands`** - array of commands to execute
  - **`command`** - the CLI command string. Variables use `<!variable_name!>` syntax (NOT `{var}` or `{{ var }}`)
  - **`passRule`** - `true` = all rules must pass (AND), `false` = one rule must pass (OR)
  - **`rules`** - validation rules applied to the command output
    - **`rule`** - the string or pattern to match against. Can contain `<!variables!>`
    - **`eval`** - evaluation operator (case-sensitive):
      - `contains` — string exists in output
      - `!contains` — string does NOT exist in output
      - `contains1` — string exists exactly once in output
      - `RegEx` — regex matches output (**note capital R and E**)
      - `!RegEx` — regex does NOT match output
      - `#comparison` — compare two values extracted from output (uses operands + comparison operator)
    - **`severity`** - `"error"`, `"warning"`, or `"info"`
    - **`evaluation`** - `"pass"` (rule match = pass) or `"fail"` (rule match = fail)
    - **`flags`** (optional object) - evaluation flags:
      - `"case": true` — case-insensitive (available for all eval types)
      - `"global": true` — global search (RegEx only)
      - `"multiline": true` — `^`/`$` match start/end of lines, not just start/end of string (RegEx only)

**Gotcha: `contains` does substring matching.** `"100"` matches `"1002"`. For exact VLAN/ID matching, use `RegEx` with multiline flag:
```json
{"rule": "^<!vlanId!>\\s+", "eval": "RegEx", "severity": "error", "evaluation": "pass", "flags": {"multiline": true}}
```

**RunCommandTemplate response shape** (returned by `POST /mop/RunCommandTemplate`):
```json
{
  "all_pass_flag": true,
  "name": "Template_Name",
  "commands_results": [
    {
      "evaluated": "show vlan brief",
      "all_pass_flag": true,
      "device": "NX-ATL-LEAF-01",
      "response": "...command output...",
      "rules": [
        {"rule": "^200\\s+", "eval": "RegEx", "result": true}
      ]
    }
  ]
}
```
- `all_pass_flag` (top-level) — overall template pass/fail
- `commands_results[]` — one entry per command
  - `evaluated` — the command with variables substituted
  - `response` — raw device output
  - `all_pass_flag` — whether this command's rules passed
  - `rules[].result` — `true`/`false` for each individual rule

**Update a command template:**
```
POST /mop/updateTemplate/{mopID}
```
The `mopID` is the template name (URL-encoded). Uses the same `{"mop": {...}}` body wrapper as create. The body is a **full replacement** of the template - include all fields.
```json
{
  "mop": {
    "name": "@projectId: Port_Turn_Up_Pre_Check",
    "passRule": true,
    "commands": [
      {
        "command": "show interface <!interface!>",
        "passRule": true,
        "rules": [
          {
            "rule": "line protocol is",
            "eval": "contains",
            "severity": "error",
            "evaluation": "pass"
          }
        ]
      }
    ]
  }
}
```

Response on success:
```json
{
  "n": 1,
  "ok": 1,
  "nModified": 1
}
```

**Variable syntax:** Command templates use `<!variable_name!>` for variable substitution in both commands and rules. This is different from Jinja2 templates (`{{ var }}`) and workflow variable references (`$var.job.x`).

**Running a command template in a workflow:**
Use the `MOP.RunCommandTemplate` task:
```json
{
  "incoming": {
    "template": "$var.job.templateName",
    "variables": "$var.job.templateVariables",
    "devices": "$var.job.devices"
  },
  "outgoing": {
    "mop_template_results": null
  }
}
```
- `template` - name of the command template
- `variables` - object with values for `<!variable!>` substitutions
- `devices` - array of device names to run against

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
| `contains` | string | Substring match filter |
| `starts-with` | string | Prefix match filter |
| `ends-with` | string | Suffix match filter |
| `in` | string | Match one of given values |
| `not-in` | string | Exclude given values |
| `exclude-project-members` | boolean | Exclude items that belong to a project |

## Developer Scenarios

### 1. Create a project with a template and workflow
```
1. Bootstrap:  ./helpers/bootstrap.sh {use-case} {platform-url} {client-id} {client-secret}
               → creates {use-case}/ with tasks.json, apps.json, adapters.json, environment.md
2. Discover:   Search {use-case}/tasks.json locally to find tasks by name/summary/description/app
3. Get schemas: POST /automation-studio/multipleTaskDetails?dereferenceSchemas=true
               → save to {use-case}/task-schemas.json
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
  {use-case}/adapters.json     - adapter instance details (instance name → adapter type)
  {use-case}/applications.json - application details with state
  {use-case}/environment.md    - human-readable overview with task counts
```

### 3. Explore available tasks for workflow building
```
GET /workflow_builder/tasks/list → all 11,000+ tasks with name, summary, description, app, variables
Search locally by keyword/app/description
GET /automation-studio/locations/{location}/packages/{app}/tasks/{method}?dereferenceSchemas=true → full schema for a specific task
POST /automation-studio/multipleTaskDetails?dereferenceSchemas=true → full schemas for multiple tasks at once
```

### 4. Understand an existing workflow
```
GET /automation-studio/workflows?include=name,tasks,transitions → list workflows with structure
GET /automation-studio/workflows/detailed/{name} → full details including task variables
POST /automation-studio/discoverReferences → find all dependencies
GET /automation-studio/references-to?target-type=workflow&_id={id} → find what references this workflow
```

### 5. Import/Export for CI/CD
```
GET /automation-studio/projects/{id}/export → self-contained JSON with all components inlined
POST /automation-studio/projects/import → deploy to another environment
POST /automation-studio/automations/import → import workflows individually
POST /automation-studio/templates/import → import templates individually
```

### 6. Manage project access
```
GET an existing project to see current members
PATCH /automation-studio/projects/{id} with {"members": [...all members...]}
Note: members is a full replacement - include existing + new members
accessControl is auto-synced from members
```

## Helper JSON Templates

**ALWAYS read the matching helper file before creating an asset.** The helpers have the correct JSON structure, field names, and API wrappers. Read the file, modify it for your use case, then POST it. Do NOT build JSON from scratch.

Helpers are in the `helpers/` directory at repo root:

| File | API Call | Description |
|------|----------|-------------|
| `create-project.json` | `POST /automation-studio/projects` | Create a new project |
| `create-template-jinja2.json` | `POST /automation-studio/templates` | Create a Jinja2 template |
| `create-template-textfsm.json` | `POST /automation-studio/templates` | Create a TextFSM template |
| `create-command-template.json` | `POST /mop/createTemplate` | Create a command template with rules |
| `update-command-template.json` | `POST /mop/updateTemplate/{mopID}` | Update a command template (full replacement, mopID = URL-encoded name) |
| `create-workflow.json` | `POST /automation-studio/automations` | Create a workflow (skeleton with start/end) |
| `workflow-task-application.json` | N/A (embed in workflow) | Application task template (e.g., WorkFlowEngine, TemplateBuilder) |
| `workflow-task-adapter.json` | N/A (embed in workflow) | Adapter task template (e.g., Awsec2, ServiceNow) |
| `add-components-to-project.json` | `POST /automation-studio/projects/{id}/components/add` | Add assets to a project |
| `update-project-members.json` | `PATCH /automation-studio/projects/{id}` | Update project membership |
| `import-project.json` | `POST /automation-studio/projects/import` | Import a project |
| `bootstrap.sh` | Multiple | Bootstraps a use-case directory with task catalog, apps, adapters, and environment overview |

## Bootstrap Output

Running `bootstrap.sh` creates the following files in your use-case directory:

| File | Contents |
|------|----------|
| `tasks.json` | Full task catalog (11,000+) - searchable with grep by name/summary/description/app |
| `apps.json` | All apps and adapters with name and type (Application/Adapter) |
| `adapters.json` | Adapter instance details: `id` (instance name), `package_id` (adapter type), `state`, `connection.state` |
| `applications.json` | Application details with state and description |
| `environment.md` | Human-readable overview: apps with task counts, adapters with instance name → type mapping, top task sources |

The `environment.md` is especially important because it maps adapter **instance names** to adapter **type names**. The `app` field in workflow tasks uses the type name (from `apps/list`), while `adapter_id` uses the instance name (from `health/adapters`). These often differ in casing and naming.

After discovering tasks, save full schemas locally too:
```
POST /automation-studio/multipleTaskDetails?dereferenceSchemas=true → save to {use-case}/task-schemas.json
```

## Filesystem-First Debugging

**CRITICAL: The local filesystem has complete API documentation and platform data. Always check local files before making API calls or guessing.**

After bootstrap, your use-case directory contains everything you need:

| File | What it answers |
|------|-----------------|
| `openapi.json` | What endpoints exist? What method (GET/POST/PUT)? What's the request body schema? What does the response look like? What fields are required vs optional? |
| `tasks.json` | What's the task called? What app provides it? What are the incoming/outgoing variable names? Is it deprecated? |
| `task-schemas.json` | What are the full types, descriptions, and examples for each task's variables? (saved after first schema fetch) |
| `apps.json` | What's the correct app name? What type is it (Application/Adapter)? |
| `adapters.json` | What's the adapter instance name? What package? Is it running? |
| `applications.json` | Is the application healthy? What state is it in? |
| `environment.md` | Quick reference: which adapters map to which types, task counts per source |

### When to check local files

**Before building a request body:** Don't guess field names or structure. Look it up:
```bash
# What fields does this endpoint expect?
jq '.paths["/automation-studio/templates"].post.requestBody.content["application/json"].schema' {use-case}/openapi.json

# What does the response look like?
jq '.paths["/automation-studio/templates"].post.responses["200"]' {use-case}/openapi.json
```

**Before fetching task schemas:** Check if you already have them:
```bash
# Search local task-schemas.json first
jq '.[] | select(.name == "renderJinjaTemplate")' {use-case}/task-schemas.json

# Only call multipleTaskDetails for tasks NOT already saved locally
```

**When a task isn't found:** Search the local catalog, don't guess:
```bash
# Search by keyword
grep -i "compliance" {use-case}/tasks.json | grep '"name"'

# Search by app
jq '.[] | select(.app == "ConfigurationManager") | .name' {use-case}/tasks.json
```

**When a field name seems wrong:** Check the schema, don't try variations:
```bash
# Get the exact field names for a task
jq '.[] | select(.name == "childJob") | .variables.incoming | keys' {use-case}/task-schemas.json
```

**When an API call returns 404 or unexpected data:**
```bash
# Verify the endpoint exists and check the method
jq '.paths | keys[] | select(contains("templates"))' {use-case}/openapi.json

# Check if it's GET, POST, PUT, etc.
jq '.paths["/automation-studio/templates"] | keys' {use-case}/openapi.json
```

### Common mistakes this prevents

| Mistake | Local file that prevents it |
|---------|----------------------------|
| Wrong HTTP method (GET vs POST) | `openapi.json` — `.paths[endpoint] \| keys` |
| Wrong field name in request body | `openapi.json` — `.requestBody.content...schema.properties \| keys` |
| Wrong task name (typo or invented) | `tasks.json` — grep for the real name |
| Wrong app casing (`servicenow` vs `Servicenow`) | `apps.json` — exact name |
| Wrong adapter instance name | `adapters.json` — `.results[].id` |
| Re-fetching schemas you already have | `task-schemas.json` — search before calling API |
| Guessing response wrapper (`data` vs `items`) | `openapi.json` — response schema |

**Rule: If you're about to guess, stop and read a file instead. The answer is already on disk.**

## Testing and Running Workflows

### Test Individual Tasks

Some tasks have standalone REST endpoints (e.g., `POST /workflow_engine/query`), but many tasks (array ops, string ops, etc.) only work inside a running workflow. The reliable way to test any task:

1. **Get the schema first** - check `{use-case}/task-schemas.json` locally, or call `multipleTaskDetails?dereferenceSchemas=true` if not cached
2. **Create a minimal test workflow** - `start → task → end` with the task's exact incoming/outgoing variable names from the schema
3. **Start the job** - `POST /operations-manager/jobs/start`
4. **Check the result** - `GET /operations-manager/jobs/{jobId}` and inspect the `variables` object

### Start a Workflow (Run a Job)

```
POST /operations-manager/jobs/start
```
```json
{
  "workflow": "Test Array Concat",
  "options": {
    "description": "Testing arrayConcat task",
    "type": "automation",
    "variables": {
      "arr": ["IOS-CAT8KV-1", "IOS-CAT8KV-2"],
      "arrayN": ["IOS-CSR-AWS-1"]
    }
  }
}
```
- `workflow` - the workflow name (string, not ID)
- `options.variables` - input values that map to the workflow's `inputSchema`
- `options.type` - `"automation"`
- `options.description` - optional job description

**Response:**
```json
{
  "message": "Successfully started job",
  "data": {
    "_id": "da97dcf248b942a089fe7dc4",
    "status": "running",
    ...
  }
}
```

### Check Job Status and Results

```
GET /operations-manager/jobs/{id}
```

Response is wrapped in `{message, data, metadata}`. The job object is inside `data`:
- `data.status` - `"running"`, `"complete"`, `"error"`, `"canceled"`
- `data.variables` - all job variables including outputs mapped via `$var.job.x`
- `data.tasks` - each task with `status` and `metrics.finish_state`

**Example result:**
```json
{
  "message": "Successfully retrieved job",
  "data": {
    "status": "complete",
    "variables": {
      "arr": ["IOS-CAT8KV-1", "IOS-CAT8KV-2"],
      "arrayN": ["IOS-CSR-AWS-1"],
      "result": ["IOS-CAT8KV-1", "IOS-CAT8KV-2", "IOS-CSR-AWS-1"]
    }
  },
  "metadata": {}
}
```

**Check errors on failed jobs** (error array is inside `data`):
```json
{
  "data": {
    "status": "error",
    "error": [
      {
        "task": "371e",
        "message": {
          "icode": "AD.312",
          "IAPerror": {
            "displayString": "Schema validation failed on must have required property 'summary'",
            "recommendation": "Verify the information provided is in the correct format"
          }
        }
      }
    ]
  }
}
```

### Task Endpoint Patterns

Some tasks have standalone REST endpoints you can call directly for quick testing - **faster and cheaper than creating test workflows**:
- **WorkFlowEngine:** `POST /workflow_engine/{method}` (e.g., `/workflow_engine/query`) - requires `job_id` parameter (can use a dummy ObjectId like `"4321abcdef694aa79dae47ad"`)
- **ConfigurationManager:** `POST /configuration_manager/{route}` (e.g., `/configuration_manager/devices`)
- **MOP (command templates):** `POST /mop/RunCommandTemplate` with `{"template":"name","devices":["dev"],"variables":{...}}` - test command templates directly without a workflow
- **TemplateBuilder (render):** `POST /template_builder/templates/{name}/renderJinja` with `{"context":{...}}` - test Jinja2 template rendering directly. Note: the REST API uses `context` as the parameter name, not `variables`.

Most WorkFlowEngine utility tasks (array ops, string ops, forEach, childJob, merge, etc.) do **NOT** have standalone endpoints. The reliable way to test those is to create a minimal workflow and run it via `jobs/start`.

### Value Reference Patterns

Different tasks use different patterns for referencing values. There are two systems:

**`$var` references** (used by most tasks):
- `$var.job.varName` - reference a job variable
- `$var.taskId.outgoingVar` - reference a previous task's output

**`task`/`value` objects** (used by `childJob` variables and `merge` data):
- `{"task": "static", "value": "literal value"}` - pass a static/literal value
- `{"task": "job", "value": "varName"}` - reference a parent job variable
- `{"task": "taskId", "value": "outVar"}` - reference a previous task's output

**`merge` data_to_merge format** (array of key-value pairs):
```json
[
  {"key": "hostname", "value": {"task": "static", "variable": "IOS-CAT8KV-1"}},
  {"key": "details", "value": {"task": "job", "variable": "deviceInfo"}},
  {"key": "config", "value": {"task": "a1b2", "variable": "renderedTemplate"}}
]
```
Note: `merge` uses `"variable"` not `"value"` in its reference objects.

### childJob Task Patterns

The `childJob` task calls another workflow as a sub-job. **Use the helper template** `helpers/workflow-task-childjob.json` as your starting point.

**Complete childJob task template (copy-paste ready):**
```json
{
  "name": "childJob",
  "canvasName": "childJob",
  "summary": "Run Child Job",
  "description": "Runs a child job inside a workflow.",
  "location": "Application",
  "locationType": null,
  "app": "WorkFlowEngine",
  "type": "operation",
  "displayName": "WorkFlowEngine",
  "variables": {
    "incoming": {
      "task": "",
      "workflow": "Child Workflow Name",
      "variables": {},
      "data_array": "",
      "transformation": "",
      "loopType": ""
    },
    "outgoing": {
      "job_details": null
    },
    "decorators": []
  },
  "groups": [],
  "actor": "job",
  "nodeLocation": { "x": 600, "y": 600 }
}
```

**Critical fields that differ from normal tasks:**
- **`actor` MUST be `"job"`** — not `"Pronghorn"` (which is used for all other tasks)
- **`task` MUST be `""`** (empty string) — the engine auto-sets this to the task ID at runtime
- **`outgoing.job_details` MUST be `null`** (or `""`) — do NOT override with `$var.job.X` or it silently breaks
- **All incoming fields are required** — even unused ones must be present as empty strings: `"data_array": ""`, `"transformation": ""`, `"loopType": ""`
- **`loopType`** values: `""` (no loop), `"parallel"`, or `"sequential"`

**No loop** — run a single child job with variables:
```json
{
  "incoming": {
    "task": "",
    "workflow": "My Child Workflow",
    "variables": {
      "deviceName": {"task": "job", "value": "deviceName"},
      "configData": {"task": "a1b2", "value": "return_data"}
    },
    "data_array": "",
    "transformation": "",
    "loopType": ""
  },
  "outgoing": {"job_details": null}
}
```

**Loop parallel** — run multiple child jobs simultaneously:
```json
{
  "incoming": {
    "task": "",
    "workflow": "My Child Workflow",
    "variables": {},
    "data_array": "$var.6254.return_data",
    "transformation": "",
    "loopType": "parallel"
  },
  "outgoing": {"job_details": null}
}
```

**Loop with transformation** — transform each `data_array` element before passing to child:
```json
{
  "incoming": {
    "task": "",
    "workflow": "My Child Workflow",
    "variables": {},
    "data_array": "$var.6254.return_data",
    "transformation": "62955855e2dff7146fb1c269",
    "loopType": "parallel"
  },
  "outgoing": {"job_details": null}
}
```

**childJob variable passing:**
- `{"task": "static", "value": [...]}` — literal value passed directly to child
- `{"task": "job", "value": "varName"}` — parent job variable (must exist at start time)
- `{"task": "taskId", "value": "outVar"}` — previous task's output (preferred for runtime-produced data)
- When using `data_array`, each object in the array becomes the child job's variables for that iteration. The `variables` field should be `{}`.
- **Prefer `{"task": "taskId"}` over `{"task": "job"}` for runtime data** — job variables referenced with `{"task": "job"}` must exist when the job starts. Task references resolve at execution time.
- **Never use `{"task": "static", "value": ["placeholder"]}` as a stand-in** — the literal `["placeholder"]` persists at runtime. Use `{"task": "job", "value": "varName"}` instead.
- The engine auto-injects `childJobLoopIndex` into each loop iteration's variables.

**Dynamic data_array with newVariable:**

Use `newVariable` to build the child loop data at runtime, then reference it with `$var.job.varName`:
```json
{
  "tasks": {
    "a1b2": {
      "name": "newVariable",
      "variables": {
        "incoming": {
          "name": "myList",
          "value": [
            {"arr": ["alpha", "beta"], "arrayN": ["gamma"]},
            {"arr": ["one"], "arrayN": ["two", "three"]}
          ]
        },
        "outgoing": {"value": "$var.job.myList"}
      }
    },
    "c3d4": {
      "name": "childJob",
      "variables": {
        "incoming": {
          "task": "",
          "workflow": "Test Array Concat",
          "variables": {},
          "data_array": "$var.job.myList",
          "transformation": "",
          "loopType": "sequential"
        },
        "outgoing": {"job_details": null}
      },
      "actor": "job"
    }
  }
}
```

**childJob output (`job_details`) — CRITICAL: flat object, not full job document:**

`job_details` contains **only the child workflow's outputSchema variables as a flat object**. It does NOT contain the full job document. Query paths use the variable name directly.

No loop — flat spread of child's output variables:
```json
{
  "status": "complete",
  "arr": ["hello", "world"],
  "arrayN": ["foo", "bar"],
  "result": ["hello", "world", "foo", "bar"]
}
```

With loop — `status` + `loop` array, each entry is a flat spread of that iteration's variables:
```json
{
  "status": "complete",
  "loop": [
    {"status": "complete", "childJobLoopIndex": 0, "result": ["device1", "device2", "device3"]},
    {"status": "complete", "childJobLoopIndex": 1, "result": ["switch1", "switch2", "switch3"]},
    {"status": "complete", "childJobLoopIndex": 2, "result": ["router1", "router2", "router3", "router4"]}
  ]
}
```

**Querying childJob output — use flat variable names, NOT nested paths:**
```json
{
  "name": "query",
  "variables": {
    "incoming": {
      "query": "validateStatus",
      "obj": "$var.f48f.job_details",
      "pass_on_null": false
    }
  }
}
```
The query path is `"validateStatus"`, NOT `"variables.job.validateStatus"`. For loop output, use `"[**].healthCheckArray"` to extract a field from all loop iterations.
```

### forEach Task Pattern

The `forEach` task iterates over an array. Each iteration runs the loop body tasks.

**Transition pattern (critical):**
```
forEach ──state:loop──→ firstLoopBodyTask → ... → lastLoopBodyTask ──(empty {})
forEach ──state:success──→ nextTaskAfterLoop
```

- `forEach` has TWO outgoing transitions: `loop` (into the body) and `success` (after loop completes)
- The LAST task in the loop body has an **empty transition `{}`** - forEach handles the looping automatically
- The processing task does NOT connect back to forEach

**Example:**
```json
{
  "transitions": {
    "workflow_start": {"a1b2": {"type": "standard", "state": "success"}},
    "a1b2": {
      "c3d4": {"type": "standard", "state": "loop"},
      "workflow_end": {"type": "standard", "state": "success"}
    },
    "c3d4": {},
    "workflow_end": {}
  }
}
```

**forEach behavior:**
- `current_item` is set to the current array element each iteration
- Job variable mapped from `current_item` gets overwritten each iteration (only last value remains after loop)
- To accumulate results, use `arrayPush` inside the loop body

### evaluation Task Pattern

The `evaluation` task is a conditional branch. It transitions differently based on whether the condition is true or false.

- **`success` transition** → condition evaluated to `true`
- **`failure` transition** → condition evaluated to `false`

If you only have a `success` transition and the condition is `false`, the **job will error out**. Always add both transitions for evaluation tasks.

### Error Handling: Try-Catch Pattern

Workflows with no error transitions on tasks will get **stuck** when a task fails - the job stays running with no path forward. Every task that can fail needs error handling.

**Try-catch in child workflows:**

Inside each child workflow, catch errors using `newVariable` to set a status flag:

```
task ──success──→ newVariable("taskStatus" = "success") → workflow_end
task ──error──→ newVariable("taskStatus" = "error") → workflow_end
```

The child workflow **always completes** (never gets stuck), and the parent can check the result.

**Try-catch in parent workflows:**

After each `childJob`, extract and evaluate the child's `taskStatus`:

```
childJob → query (extract taskStatus from job_details) → evaluation (is it "success"?)
  ├── success → continue
  └── failure → handle error
```

Example:
```json
{
  "a110": {
    "name": "query",
    "variables": {
      "incoming": {"query": "taskStatus", "obj": "$var.a100.job_details", "pass_on_null": false},
      "outgoing": {"return_data": "$var.job.createStatus"}
    }
  },
  "a120": {
    "name": "evaluation",
    "variables": {
      "incoming": {
        "all_true_flag": true,
        "evaluation_groups": [{
          "all_true_flag": true,
          "evaluations": [{
            "operand_1": {"variable": "createStatus", "task": "job"},
            "operator": "==",
            "operand_2": {"variable": "success", "task": "static"}
          }]
        }]
      }
    }
  }
}
```

**Manual tasks** (`type: "manual"`) require a `view` property pointing to the UI controller:
```json
{
  "name": "ViewData",
  "type": "manual",
  "view": "/workflow_engine/task/ViewData",
  "variables": {
    "incoming": {
      "header": "Approval Required",
      "message": "Review and approve to continue.",
      "body": "$var.job.dataToReview",
      "btn_success": "Approve",
      "btn_failure": "Reject"
    }
  }
}
```
The workflow pauses at manual tasks until a human interacts via the UI. `btn_success` triggers `success` transition, `btn_failure` triggers `failure` transition.

### Asset Validation

Before running a workflow, **always validate that all referenced assets exist** on the target platform:

- **Devices**: `GET /configuration_manager/devices/{name}`
- **Jinja2 templates**: `POST /template_builder/templates/{name}/renderJinja` with `{"context":{}}` - if it renders, it exists
- **Command templates**: `GET /mop/listATemplate/{name}`
- **CM device templates**: `POST /configuration_manager/templates/search` with `{"name": "..."}`
- **Adapters**: `GET /health/adapters` - check state is `RUNNING`
- **Child workflows**: `GET /automation-studio/workflows?include=name` - verify names exist
- **Existing workflows to reuse**: before building a new workflow, check if one already exists that does what you need. Use it as a childJob instead of rebuilding.

Missing assets cause runtime errors or draft workflows that can't be started.

### Updating Assets (PUT/PATCH vs POST)

**Always keep asset JSON files locally** in the use-case directory. When you need to change something, edit the local file and use PUT/PATCH to update instead of creating new assets each time. This applies to ALL asset types:

| Asset | Create | Update | Local File |
|-------|--------|--------|------------|
| Workflow | `POST /automation-studio/automations` | `PUT /automation-studio/automations/{id}` with `{"update": {...}}` | `wf-{name}.json` |
| Template | `POST /automation-studio/templates` | `PUT /automation-studio/templates/{id}` with `{"update": {...}}` | `tmpl-{name}.json` |
| Command Template | `POST /mop/createTemplate` | `POST /mop/updateTemplate/{name}` with `{"mop": {...}}` | `mop-{name}.json` |
| Project | `POST /automation-studio/projects` | `PATCH /automation-studio/projects/{id}` | `project-{name}.json` |
| Golden Config Node | `PUT /configuration_manager/node/config` | Same endpoint (PUT) | `gc-{tree}-{node}.json` |
| Compliance Plan | `POST /configuration_manager/compliance_plans` | `PUT /configuration_manager/compliance_plans` with `{planId, options}` | `plan-{name}.json` |

**Development workflow:** create asset → save JSON locally → edit local file → PUT/PATCH to update → test → iterate.

This is **cheaper** than recreating - no orphaned assets, no name conflicts, same IDs.

## Common Workflow Patterns

### autoApprove Pattern

Use an `evaluation` task to conditionally skip manual approval:

```
evaluation (autoApprove == true?)
  ├── success → skip to next task (auto-approved)
  └── failure → ViewData (human reviews and approves/rejects)
```

The workflow accepts an `autoApprove` boolean input. When `true`, skips the manual step. Useful for CI/CD pipelines that run unattended vs interactive operator sessions.

### Pre-Check / Post-Check Design

**Pre-checks** validate conditions BEFORE making changes:
- Base interface is up: `"line protocol is up"` (contains)
- Sub-interface does NOT exist yet: `"GigabitEthernet1.910"` (`!contains`) - the `!contains` eval means "rule passes if string is NOT found"
- Target system is reachable

**Post-checks** verify the change was applied correctly:
- Config is present: `"encapsulation dot1Q 910"` (contains)
- Interface is up: `"line protocol is"` (contains)

Design pre-checks around what MUST be true before the change, and post-checks around what SHOULD be true after.

### Network Device Config Pattern: MOP for Checks, Jinja2 for Config, Push via Workflow/CLI

When automating network device changes, use this pattern:

**1. MOP command templates → validation and checks only**
- Pre-checks: `show vlan brief`, `show interfaces switchport`, `show ip bgp summary`
- Post-checks: same commands with validation rules to confirm changes applied
- MOP is for running show commands and evaluating output — NOT for pushing config

**2. Jinja2 templates → generate the configuration**
- Render the config snippet using a Jinja2 template with variables
- Example: VLAN creation, interface config, BGP neighbor config
- Test with `POST /template_builder/templates/{name}/renderJinja` before pushing

**3. Push config → use existing workflow or `itential_cli` task**
- Search for existing push workflows first (`Push Configuration to Device`, etc.) — **these may not exist in every environment**, so check before assuming
- If no push workflow exists, use the `itential_cli` task directly in your workflow to send the rendered config to the device
- **Ask the engineer** which push method they prefer if multiple options exist

**Never use MOP command templates to push configuration to network devices.** MOP is for read-only validation.

**4. Test commands against the actual device BEFORE building workflows**
- Run `show` commands via MOP first to understand device capabilities and interface names
- Test a single CLI command via `itential_cli` before building the full workflow
- **Always review task output** — a job can show `status: complete` even when CLI commands return errors like `% Invalid input detected`. Check `stdout` for actual command results.
- Device type determines config approach: routers use sub-interfaces + `encapsulation dot1Q`, switches use `switchport` commands. Verify which style the target device needs.
- Check `show ip interface brief` or `show running-config | section interface` to understand what interfaces exist before writing config templates

### Revert Transitions (Retry Loops)

Use `"type": "revert"` transitions to go backward for retry scenarios:

```
renderTemplate → viewConfig (approve/reject)
  ├── success → pushConfig → evalSuccess
  │                             ├── success → end
  │                             └── failure → viewError (retry/abort)
  │                                             ├── success (retry) ──revert──→ renderTemplate
  │                                             └── failure (abort) → end
  └── failure (reject) ──revert──→ renderTemplate
```

The `revert` transition moves execution back to a previous task, allowing the user to fix inputs and retry.

## Modular Workflow Design

Build workflows as small, testable child workflows composed via `childJob` in a parent:

```
Parent Workflow
  ├── childJob (parallel) → Child: Data Gathering (one per item)
  ├── renderJinja2ContextWithCast → Format results into report
  └── childJob → Child: External Action (e.g., create ticket)
```

**Principles:**
- **Check for existing workflows first** - before building a new workflow, search for ones that already exist on the platform (`GET /automation-studio/workflows?include=name&limit=100`). Reuse them as childJobs instead of rebuilding. Note: don't assume specific workflows exist (e.g., `Push Configuration to Device` is common but not guaranteed). Always search first.
- Each child workflow should be independently testable via `jobs/start`
- Child workflows have clear input/output contracts via `inputSchema`/`outputSchema`
- Use `data_array` + `loopType: "parallel"` to fan out across multiple items
- Pass childJob output directly to the next task's `$var` input - don't try to restructure with `newVariable`
- **Keep ALL asset JSON files locally** in the use-case directory (workflows, templates, command templates, etc.). Edit locally, PUT/PATCH to update. Don't recreate - it's cheaper to patch.

**Chaining childJob output to a template:**

The childJob output has structure `{status, loop: [{...child vars...}, ...]}`. Pass it directly as `variables` to `renderJinja2ContextWithCast` and iterate over `loop` in the template:

```json
{
  "incoming": {
    "template": "Report\n{% for item in loop %}\n- {{ item.fieldName }}\n{% endfor %}",
    "variables": "$var.job.childJobResults",
    "castDataType": "string"
  }
}
```

## Workflow Tips

### $var Resolution Rules (Source-Code Verified)

Task IDs are generated as **4-character hex strings** (`[0-9a-f]{4}`, range `0000`-`ffff`). The engine validates `$var` references against this regex:

```
taskIdRegex = /^([0-9a-f]{1,4}|workflow_start|workflow_end)$/
```

**If a task ID contains non-hex characters, `$var` references to it silently fail** — the string is classified as `type: "static"` and stored literally, never resolved at runtime.

| $var Pattern | Resolves? | Why |
|---|---|---|
| `$var.job.deviceName` | Yes | `job` is a recognized keyword |
| `$var.a1b2.result` | Yes | `a1b2` is valid hex |
| `$var.ff09.return_data` | Yes | `ff09` is valid hex |
| `$var.apush.result` | **NO** | `p`, `u`, `s`, `h` are not hex chars |
| `$var.myTask.output` | **NO** | `m`, `y`, `T`, `k` are not hex chars |

**$var only resolves at the top level of `incoming` variables.** The engine iterates `Object.values(incoming)` and only resolves direct string values. It does NOT recurse into nested objects:

| Wiring | Works? | Why |
|---|---|---|
| `"deviceName": "$var.job.x"` | Yes | Direct top-level string value |
| `"variables": {"key": "$var.job.x"}` | **NO** | Nested inside an object — stored as literal string |
| `"body": {"data": "$var.job.x"}` | **NO** | Same — nested object, never resolved |

**Workaround for nested objects:** Use a `merge` or `query` intermediate task (with a hex ID) to build the object, then reference that task's output.

### Adapter URI Prefix

Adapters have a `base_path` configured in their adapter settings (e.g., `/api` for ServiceNow, NetBox). The `genericAdapterRequest` task **automatically prepends** this base_path to the `uriPath` you provide.

The task schema says: *"do not include the host, port, base path or version"*

| What you want to call | Correct `uriPath` | Wrong `uriPath` | Result of wrong |
|---|---|---|---|
| `https://snow.example.com/api/now/table/change_request` | `/now/table/change_request` | `/api/now/table/change_request` | `/api/api/now/table/...` → 400 error |

If you need to bypass the base_path prepend, use `genericAdapterRequestNoBasePath` instead.

### API Response Shapes

Most platform API responses are wrapped in `{message, data, metadata}`. Always extract from `data`:

| Endpoint | Extract |
|---|---|
| `POST /operations-manager/jobs/start` | `response.data._id` (job ID) |
| `GET /operations-manager/jobs/{id}` | `response.data.status`, `response.data.variables`, `response.data.error` |
| `POST /automation-studio/projects` | `response.data._id` |
| `GET /automation-studio/projects` | `response.data` (array of projects) |
| `DELETE /automation-studio/projects/{id}` | `response.message` |
| `POST /automation-studio/automations` | `response.data._id` |

**Exception:** `GET /automation-studio/workflows` returns `{items, skip, limit, total}` — NO `data` wrapper.

**Exception:** `GET /automation-studio/workflows/detailed/{name}` returns the workflow document directly — NO wrapper.

### Template Discovery Gotcha

`GET /automation-studio/templates` may return TextFSM templates alongside Jinja2 templates. TextFSM content can contain control characters that break `jq` parsing. Use Python with a control-character strip if you need to parse template listings:
```python
import re, json
raw = open("templates.json").read()
clean = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', raw)
templates = json.loads(clean)
```

**General gotchas:**
- **`makeData` `<!var!>` names must match source object keys exactly** — if the source has `ipaddress`, use `<!ipaddress!>` not `<!ip!>`
- **`$var` references don't resolve inside object values** — `newVariable` with `{"key": "$var.job.x"}` stores the literal string, not the resolved value. Always pass data between tasks using `$var.job.x` directly in the task's incoming variable wiring. Use a `merge` task to build nested objects dynamically.
- **Every task that can fail needs error handling** — tasks without error/failure transitions cause the job to get stuck in `running` state forever. Use the try-catch pattern (see Error Handling section).
- **Validate assets exist before running** — missing templates, devices, or adapters cause runtime errors. Check all referenced assets on the target platform first.
- **Runtime-populated variables in childJob** — don't create dummy job variables for data produced at runtime. Instead, wire the childJob's `variables` to reference the **task that produces the value** using `{"task": "taskId", "value": "outgoingVar"}`. For example, if a query task `a150` extracts a `changeId`, reference it as `{"task": "a150", "value": "return_data"}` in the childJob, not `{"task": "job", "value": "changeId"}`.

- **Reuse the same task type** — You can use the same task multiple times with different task IDs (e.g., two `WorkFlowEngine.query` tasks with IDs `c3d4` and `e5f6` doing different queries). Task IDs must be hex only.
- **Use JSON files for API payloads** — Write request bodies to `.json` files and use `curl -d @file.json` to avoid shell escaping issues with `$var` references and nested quotes
- **Check the `errors` array** — Workflow creation succeeds even with validation errors. Zero errors = all tasks exist on the platform. `"Method not found"` means the task name doesn't match any method on that app.
- **Template names** — Use underscores or simple characters in template names (e.g., `IOS_Switchport_Config`). The `name` field is used by `TemplateBuilder.renderJinjaTemplate` to look up the template at runtime.
- **Variable syntax differs by context** — don't mix them up:

| Context | Syntax | Example |
|---------|--------|---------|
| Jinja2 templates | `{{ var }}` | `interface Vlan{{ vlan_id }}` |
| Command templates (MOP) | `<!var!>` | `show interface <!interface!>` |
| `makeData` input | `<!var!>` | `{"name": "<!name!>", "ip": "<!ipaddress!>"}` |
| Workflow variable refs | `$var.job.x` or `$var.taskId.x` | `$var.job.deviceName` |
| childJob/merge refs | `{"task":"job","value":"varName"}` | `{"task": "static", "value": ["a"]}` |

### Project Reference Gotcha — Create Project First

**When moving/copying workflows into a project, internal references break:**

1. Workflow names get re-prefixed: `@OLD_PROJECT_ID: Workflow Name` → `@NEW_PROJECT_ID: Workflow Name`
2. Workflow `_id` changes (new UUID assigned)
3. **Internal references are NOT updated** — childJob `workflow` fields, template `name` references, and transformation `tr_id` fields still point to old names/IDs

**Example of the problem:**
- Parent workflow in new project references `@66f47bc8: Bulk Delete Policy` (old project prefix)
- Child workflow now lives at `@683049e2: Bulk Delete Policy` (new project prefix)
- The childJob reference is stale — works only if old project still exists

**Safe pattern: always create the project first, then create all workflows inside it.**
- Workflow names automatically get the `@PROJECT_ID:` prefix
- All cross-references (childJob, templates, transformations) use the correct project-prefixed names from the start
- Use `mode: "copy"` (not `"move"`) if you must add existing assets — this preserves the originals

### Project Component Types

Valid `type` values for `POST /automation-studio/projects/{id}/components/add`:

| Type | Asset |
|------|-------|
| `workflow` | Workflows |
| `template` | Jinja2 / TextFSM templates |
| `transformation` | JST transformations |
| `jsonForm` | JSON forms |
| `mopCommandTemplate` | MOP command templates (**not** `mop`) |
| `mopAnalyticTemplate` | MOP analytic templates |

## Security & Access Control

- **Roles:** `owner`, `editor`, `viewer`
- **Member types:** `account` (individual user), `group` (team)
- **Access control scopes:** `manage`, `write`, `execute`, `read` (auto-synced from members)
- **API Permissions:** `AutomationStudio.admin`, `AutomationStudio.designer`, `AutomationStudio.readonly`, `AutomationStudio.apiread`, `AutomationStudio.apiwrite`
