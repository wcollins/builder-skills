---
name: itential-builder
description: Create projects, build workflows, templates (Jinja2/TextFSM), and command templates (MOP). Wire utility tasks, run jobs, and debug. This is the single build skill — invoke it when you need to create or test any Itential asset.
argument-hint: "[action or asset-type]"
---

# Itential Builder - Developer Skills Guide

This skill covers everything needed to build and test Itential automation assets: projects, workflows, templates, and command templates.

## Build Lifecycle

```
1. Create project           → container for all assets
2. Discover tasks           → search tasks.json, fetch schemas
3. Build workflows          → wire tasks, transitions, $var refs
4. Build templates          → Jinja2 (config gen) or TextFSM (output parsing)
5. Build command templates  → MOP pre/post checks with validation rules
6. Add assets to project    → move/copy into the project
7. Test                     → jobs/start, check results
8. Debug                    → check job.error, filesystem-first
```

---

## Projects

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/automation-studio/projects` | Create a new project |
| GET | `/automation-studio/projects/{projectId}` | Get a project |
| PATCH | `/automation-studio/projects/{projectId}` | Update a project |
| DELETE | `/automation-studio/projects/{id}` | Delete a project |
| GET | `/automation-studio/projects/{id}/export` | Export project as JSON |
| POST | `/automation-studio/projects/import` | Import a project |
| POST | `/automation-studio/projects/{projectId}/components/add` | Add components |
| DELETE | `/automation-studio/projects/{projectId}/components/{componentId}` | Remove component |

**Create a project:**
```
POST /automation-studio/projects
```
```json
{"name": "My Network Automations", "description": "VLAN provisioning and compliance"}
```

Response uses `{message, data, metadata}` shape. Project is in `data`:
```json
{"message": "Successfully created project", "data": {"_id": "699a6b89...", "name": "..."}}
```

**Add components:**
```
POST /automation-studio/projects/{projectId}/components/add
```
```json
{
  "components": [
    {"type": "workflow", "reference": "d8c323f6-...", "folder": "/"},
    {"type": "template", "reference": "699a6b96...", "folder": "/"}
  ],
  "mode": "move"
}
```

- `mode`: `"move"` (removes from global scope) or `"copy"` (keeps both)
- `reference`: the `_id` of the asset
- **Both modes rename assets** with `@projectId:` prefix and assign new `_id`s. Internal references (childJob `workflow` fields, template names) are NOT updated.

**Component types:** `workflow`, `template`, `transformation`, `jsonForm`, `mopCommandTemplate`, `mopAnalyticTemplate`

**Update membership (full replacement):**
```
PATCH /automation-studio/projects/{projectId}
```
```json
{
  "members": [
    {"type": "account", "role": "owner", "reference": "699a67bb..."},
    {"type": "group", "role": "editor", "reference": "67c859..."}
  ]
}
```
Include ALL members (existing + new) — this is a full replacement.

---

## Task Discovery

### Pull Task Catalog

```
GET /workflow_builder/tasks/list → save to {use-case}/tasks.json
GET /automation-studio/apps/list → save to {use-case}/apps.json
```

Search locally:
```bash
grep -i "template" {use-case}/tasks.json
jq '.[] | select(.app == "ConfigurationManager") | .name' {use-case}/tasks.json
```

### Get Full Task Schemas

**Single task:**
```
GET /automation-studio/locations/{location}/packages/{pckg}/tasks/{method}?dereferenceSchemas=true
```

**Multiple tasks:**
```
POST /automation-studio/multipleTaskDetails?dereferenceSchemas=true
```
```json
{
  "inputsArray": [
    {"location": "Application", "pckg": "WorkFlowEngine", "method": "query"},
    {"location": "Adapter", "pckg": "Servicenow", "method": "createChangeRequest"}
  ]
}
```

**Mapping from tasks.json → schema endpoint:**

| tasks.json field | Maps to |
|------------------|---------|
| `location` (`Application`/`Adapter`) | `{location}` |
| `app` (e.g., `TemplateBuilder`) | `{pckg}` |
| `name` (e.g., `renderJinjaTemplate`) | `{method}` |

**IMPORTANT:** The `pckg` value must come from `apps.json`, NOT `tasks.json`. The names can differ (e.g., tasks.json says `ServiceNow` but apps.json says `Servicenow`).

**Before fetching schemas:**
1. Check if `{use-case}/task-schemas.json` exists — search it first
2. Only call `multipleTaskDetails` for tasks NOT already in the local file
3. After fetching, append to the local file

---

## Workflows

### Workflow Structure

```
POST /automation-studio/automations
```

Body wraps the workflow in `{"automation": {...}}`:

```json
{
  "automation": {
    "name": "My Workflow",
    "description": "Does something useful",
    "type": "automation",
    "canvasVersion": 3,
    "encodingVersion": 1,
    "font_size": 12,
    "tasks": {
      "workflow_start": {
        "name": "workflow_start",
        "groups": [],
        "nodeLocation": {"x": 360, "y": 1308}
      },
      "a1b2": {
        "name": "query",
        "canvasName": "query",
        "summary": "Extract Data",
        "description": "Extracts field from response",
        "location": "Application",
        "locationType": null,
        "app": "WorkFlowEngine",
        "type": "operation",
        "displayName": "WorkFlowEngine",
        "variables": {
          "incoming": {
            "pass_on_null": false,
            "query": "hostname",
            "obj": "$var.job.deviceData"
          },
          "outgoing": {
            "return_data": "$var.job.deviceName"
          },
          "error": "",
          "decorators": []
        },
        "groups": [],
        "actor": "Pronghorn",
        "scheduled": false,
        "nodeLocation": {"x": 600, "y": 1308}
      },
      "workflow_end": {
        "name": "workflow_end",
        "groups": [],
        "nodeLocation": {"x": 1152, "y": 1308}
      }
    },
    "transitions": {
      "workflow_start": {
        "a1b2": {"type": "standard", "state": "success"}
      },
      "a1b2": {
        "workflow_end": {"type": "standard", "state": "success"}
      },
      "workflow_end": {}
    },
    "groups": [],
    "inputSchema": {
      "type": "object",
      "properties": {
        "deviceData": {"title": "deviceData", "type": "object"}
      },
      "required": ["deviceData"]
    },
    "outputSchema": {
      "type": "object",
      "properties": {
        "deviceName": {"title": "deviceName", "type": "string"}
      }
    }
  }
}
```

**Update a workflow:**
```
PUT /automation-studio/automations/{id}
```
```json
{"update": { ...same structure as automation object... }}
```

### Task Fields

| Field | Application Tasks | Adapter Tasks |
|-------|-------------------|---------------|
| `name` | Method name from tasks.json | Method name from tasks.json |
| `canvasName` | From tasks.json `canvasName` field (may differ from `name`: `arrayPush`→`push`) | Same |
| `location` | `"Application"` | `"Adapter"` |
| `locationType` | `null` | Same as `app` |
| `app` | App name (e.g., `WorkFlowEngine`) | From `apps.json` (NOT tasks.json) |
| `type` | `"operation"` for utility tasks | `"automatic"` for adapter calls |
| `actor` | `"Pronghorn"` | `"Pronghorn"` |
| `displayName` | App name | May differ from `app` |

**Adapter tasks also require `adapter_id`** in incoming variables — the adapter instance name from `health/adapters`.

### Task IDs

Task IDs must be **hex-only**: `[0-9a-f]{1,4}`. Non-hex IDs (e.g., `apush`) cause `$var` references to silently fail.

### Transitions

```json
"transitions": {
  "workflow_start": {
    "a1b2": {"type": "standard", "state": "success"}
  },
  "a1b2": {
    "c3d4": {"type": "standard", "state": "success"},
    "err1": {"type": "standard", "state": "error"}
  },
  "c3d4": {
    "workflow_end": {"type": "standard", "state": "success"}
  },
  "err1": {
    "workflow_end": {"type": "standard", "state": "success"}
  },
  "workflow_end": {}
}
```

**Transition states:**
- `success` — task completed without error (all tasks)
- `error` — task encountered errors (all tasks)
- `failure` — evaluation didn't match or query returned undefined (evaluation/query only)
- `loop` — forEach loop iteration (forEach only)

**Transition types:**
- `standard` — moves forward
- `revert` — moves backward to a previous task (retry loops)

**MANDATORY: Every adapter/external task needs an error transition.** Without one, errors cause "Job has no available transitions" and the job gets stuck forever.

**JSON duplicate key problem:** If both success and error need to go to `workflow_end`, you can't use `workflow_end` as a key twice. Route error to an intermediate task (e.g., `newVariable` to set error status), then route that to `workflow_end`.

### Create Response Shape

Both workflow and template creation return `{created, edit}` — NOT `{message, data, metadata}`:
```json
{
  "created": {"_id": "...", "name": "..."},
  "edit": "/automation-studio/#/edit?..."
}
```

---

## $var Resolution Rules

`$var` only resolves as **direct top-level incoming variable values:**

| Wiring | Works? | Why |
|--------|--------|-----|
| `"deviceName": "$var.job.x"` | Yes | Direct top-level value |
| `"variables": {"key": "$var.job.x"}` | **NO** | Nested inside object |
| `"body": {"data": "$var.job.x"}` | **NO** | Nested — stored as literal string |

**Workaround:** Use `merge`, `makeData`, or `query` to build the nested object, then reference the task's output with `$var.taskId.merged_object`.

**Task ID validation:** `$var.taskId.x` only resolves when `taskId` matches `[0-9a-f]{1,4}`. Non-hex IDs silently fail.

---

## Utility Tasks (WorkFlowEngine)

These are built-in tasks that require no adapter. They handle data manipulation and control flow.

### query

Extract nested values from objects using dot-path syntax.

**Incoming:** `pass_on_null` (boolean), `query` (string — dot-path), `obj` (object — usually `$var` ref)
**Outgoing:** `return_data` (any)
**Transitions:** `success` (found), `failure` (null/undefined when `pass_on_null: false`)

```json
{
  "incoming": {
    "pass_on_null": false,
    "query": "response.id",
    "obj": "$var.a1b2.result"
  },
  "outgoing": {
    "return_data": "$var.job.changeId"
  }
}
```

### merge

Build an object from multiple resolved values. Primary workaround for `$var` not resolving inside nested objects.

**Incoming:** `data_to_merge` (array, min 2 items)
**Outgoing:** `merged_object` (object)

**IMPORTANT: The field is `"variable"` NOT `"value"`** in the reference objects inside `data_to_merge`.

**Reference format in `data_to_merge`:**
- `{"task": "job", "variable": "varName"}` — pull from a job variable
- `{"task": "static", "variable": "literalValue"}` — literal value
- `{"task": "taskId", "variable": "outVar"}` — pull from a previous task's output

```json
{
  "incoming": {
    "data_to_merge": [
      {"key": "hostname", "value": {"task": "static", "variable": "IOS-CAT8KV-1"}},
      {"key": "details", "value": {"task": "job", "variable": "deviceInfo"}},
      {"key": "config", "value": {"task": "a1b2", "variable": "renderedTemplate"}}
    ]
  },
  "outgoing": {
    "merged_object": "$var.job.requestBody"
  }
}
```

**Gotchas:** Requires at least 2 items (1 item = silently null). Outgoing MUST declare `"merged_object": null` (empty `{}` makes it unreachable).

### evaluation

Conditional branching. **MUST have BOTH success AND failure transitions.**

**Incoming:** `all_true_flag` (boolean), `evaluation_groups` (array)
**Outgoing:** `return_value` (boolean)
**Transitions:** `success` (true), `failure` (false)

**Operand reference format (uses `"variable"`, same as merge):**
- `{"task": "job", "variable": "varName"}`
- `{"task": "static", "variable": "literalValue"}`

```json
{
  "incoming": {
    "all_true_flag": true,
    "evaluation_groups": [{
      "all_true_flag": true,
      "evaluations": [{
        "operand_1": {"variable": "status", "task": "job"},
        "operator": "==",
        "operand_2": {"variable": "success", "task": "static"}
      }]
    }]
  },
  "outgoing": {"return_value": null}
}
```

### childJob

Run another workflow as a sub-job. **Use helper template** `helpers/workflow-task-childjob.json`.

**Critical differences from normal tasks:**
- **`actor` MUST be `"job"`** — not `"Pronghorn"`
- **`task` MUST be `""`** (empty string)
- **`outgoing.job_details` MUST be `null`** — do NOT override with `$var.job.X`
- **All incoming fields required** — even unused ones: `"data_array": ""`, `"transformation": ""`, `"loopType": ""`

**Variables use `{"task", "value"}` syntax — NOT `$var`:**
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

**childJob uses `"value"`. merge/evaluation use `"variable"`. Do NOT mix them.**

**Variable passing:**
- `{"task": "static", "value": [...]}` — literal value
- `{"task": "job", "value": "varName"}` — parent job variable (must exist at start)
- `{"task": "taskId", "value": "outVar"}` — previous task's output (preferred for runtime data)

**Loop modes:** `loopType: ""` (single), `"parallel"` (multiple simultaneous), `"sequential"` (one at a time). With loops, use `data_array` (each element becomes a child job's variables) and set `variables: {}`.

**Querying childJob output:**
```json
{
  "name": "query",
  "variables": {
    "incoming": {
      "query": "taskStatus",
      "obj": "$var.f48f.job_details",
      "pass_on_null": false
    }
  }
}
```
Use flat variable names, NOT nested paths. For loop output: `"[**].fieldName"`.

### forEach

Iterate over an array. **Deprecated** — prefer `childJob` with `loopType`. Still common in existing workflows.

**Incoming:** `data_array` (array)
**Outgoing:** `current_item` (any)

**Transition pattern (critical):**
```
forEach --state:loop--> firstBodyTask -> ... -> lastBodyTask --(empty {})
forEach --state:success--> nextTaskAfterLoop
```
The last task in the loop body has an **empty transition `{}`**. Do NOT connect it back to forEach.

### newVariable

Create or set a job variable at runtime.

**Incoming:** `name` (string), `value` (any)
**Outgoing:** `value` (any)

```json
{
  "incoming": {"name": "taskStatus", "value": "success"},
  "outgoing": {"value": "$var.job.taskStatus"}
}
```

**GOTCHA:** `$var` inside `value` does NOT resolve. The literal string is stored. Use merge + query to build dynamic values.

### makeData

Construct data with `<!var!>` variable substitution.

**Incoming:** `input` (string with `<!var!>` placeholders), `outputType` (`"string"`/`"json"`/`"number"`/`"boolean"`), `variables` (object)
**Outgoing:** `output` (any)

**The `variables` field must be a resolved object.** Use merge first to build it, then pass via `$var.taskId.merged_object`:

```
merge (build variables object) → makeData (use $var.taskId.merged_object as variables)
```

### delay

Pause execution. **Incoming:** `time` (integer, seconds). **Outgoing:** `time_in_milliseconds`.

### push / pop / shift

Array manipulation on job variables **by name** (plain string, NOT `$var` reference).

```json
{
  "incoming": {
    "job_variable": "collectedResults",
    "item_to_push": "$var.c3d4.return_data"
  }
}
```

**GOTCHA:** Pass `"myArray"`, NOT `"$var.job.myArray"`.

### Additional Utility Tasks (60+)

Search `tasks.json` for the full catalog:
```bash
jq '.[] | select(.app == "WorkFlowEngine") | {name, summary}' {use-case}/tasks.json
```

| Category | Examples |
|----------|---------|
| String | `stringConcat`, `replace`, `split`, `toLowerCase`, `toUpperCase`, `trim`, `substring` |
| Array | `arrayConcat`, `arrayPush`, `sort`, `join`, `arraySlice`, `map`, `reverse` |
| Object | `assign`, `keys`, `values`, `objectHasOwnProperty`, `setObjectKey` |
| Time | `getTime`, `addDuration`, `convertTimezone`, `calculateTimeDiff` |
| Tools | `restCall`, `csvStringToJson`, `excelToJson`, `asciiToBase64` |

Fetch full schemas with `POST /automation-studio/multipleTaskDetails?dereferenceSchemas=true`.

---

## Templates (Jinja2 / TextFSM)

```
POST /automation-studio/templates
```
```json
{
  "template": {
    "name": "VLAN_Interface_Config",
    "type": "jinja2",
    "group": "Cisco IOS",
    "command": "configure terminal",
    "description": "Generates VLAN interface config",
    "template": "interface Vlan{{ vlan_id }}\n description {{ description }}\n ip address {{ ip_address }} {{ subnet_mask }}\n no shutdown",
    "data": "{\"vlan_id\": 100, \"description\": \"Management\", \"ip_address\": \"10.0.1.1\", \"subnet_mask\": \"255.255.255.0\"}"
  }
}
```

**Required fields:** `name`, `group`, `command`, `description`, `template`, `data`, `type`

**Types:** `jinja2` (config generation) or `textfsm` (output parsing)

**Test rendering directly:**
```
POST /template_builder/templates/{name}/renderJinja
```
```json
{"context": {"vlan_id": 100, "description": "Management"}}
```

**Gotchas:**
- `group` cannot be empty or whitespace-only
- Use underscores in template names (e.g., `IOS_Switchport_Config`)
- `data` field is a JSON string, not an object
- Variable syntax is `{{ var }}` (Jinja2), NOT `$var` or `<!var!>`

---

## Command Templates (MOP)

MOP manages command templates for running CLI commands with validation rules. **MOP is read-only validation only — never use it to push config.**

### Create a Command Template

```
POST /mop/createTemplate
```
```json
{
  "mop": {
    "name": "Port_Turn_Up_Pre_Check",
    "description": "Validates interface and VLAN",
    "os": "",
    "passRule": true,
    "ignoreWarnings": false,
    "commands": [
      {
        "command": "show interface <!interface!>",
        "passRule": true,
        "rules": [
          {
            "rule": "line protocol is",
            "eval": "contains",
            "severity": "error"
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
            "severity": "error"
          }
        ]
      }
    ]
  }
}
```

**Variable syntax:** `<!variable_name!>` in both commands and rules (NOT `{{ }}` or `$var`)

### passRule Logic

- **Template-level `passRule: true`** = ALL commands must pass (AND)
- **Template-level `passRule: false`** = ONE command must pass (OR)
- **Command-level** = same logic for rules within a command

### Rule Evaluation

| Eval | Purpose | Example |
|------|---------|---------|
| `contains` | String exists in output | `"line protocol is"` |
| `!contains` | String does NOT exist | `"ERROR"` |
| `contains1` | String exists exactly once | `"Active"` |
| `RegEx` | Regex matches (capital R, E!) | `"/\\d+\\.\\d+/"` |
| `!RegEx` | Regex does NOT match | `"/ERROR/"` |
| `#comparison` | Extract + compare two values | See below |

**#comparison:** Extract values with regex, compare numerically:
```json
{
  "rule": "/Available: (\\d+)/",
  "ruleB": "/Total: (\\d+)/",
  "eval": "#comparison",
  "evaluator": ">=",
  "severity": "error"
}
```
Evaluators: `=`, `!=`, `<`, `>`, `<=`, `>=`, `%` (percentage)

**Flags:** `case: true` = case-INSENSITIVE (confusing name), `global: true`, `multiline: true` (RegEx only)

### Run a Command Template

**Standalone:**
```
POST /mop/RunCommandTemplate
```
```json
{
  "template": "Port_Turn_Up_Pre_Check",
  "variables": {"interface": "GigabitEthernet0/1", "vlan_id": "100"},
  "devices": ["IOS-CAT8KV-1"]
}
```

**In a workflow (MOP.RunCommandTemplate task):**
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

### Response Shape

```json
{
  "all_pass_flag": true,
  "result": true,
  "name": "Port_Turn_Up_Pre_Check",
  "commands_results": [
    {
      "raw": "show interface <!interface!>",
      "evaluated": "show interface GigabitEthernet0/1",
      "all_pass_flag": true,
      "device": "IOS-CAT8KV-1",
      "response": "...command output...",
      "result": true,
      "rules": [{"rule": "line protocol is", "eval": "contains", "result": true}]
    }
  ]
}
```

### Update a Command Template

```
POST /mop/updateTemplate/{mopID}
```
`mopID` is the template name (URL-encoded). Body is `{"mop": {...}}` — **full replacement**, include ALL fields.

### Analytic Templates (Pre/Post Comparison)

```
POST /mop/createAnalyticTemplate
```
```json
{
  "name": "Interface_Change_Validation",
  "os": "cisco-ios",
  "passRule": true,
  "prepostCommands": [
    {
      "preRawCommand": "show interface GigabitEthernet0/1",
      "postRawCommand": "show interface GigabitEthernet0/1",
      "passRule": true,
      "rules": [
        {
          "type": "matches",
          "preRegex": "/line protocol is (\\w+)/",
          "postRegex": "/line protocol is (\\w+)/",
          "evaluator": "="
        }
      ]
    }
  ]
}
```

**In a workflow (MOP.runAnalyticsTemplate task):**
```json
{
  "incoming": {
    "pre": "$var.preCheckTaskId.mop_template_results",
    "post": "$var.postCheckTaskId.mop_template_results",
    "analytic_template_name": "Interface_Change_Validation",
    "variables": {}
  },
  "outgoing": {"analytic_result": null}
}
```

---

## Testing & Debugging

### Start a Job

```
POST /operations-manager/jobs/start
```
```json
{
  "workflow": "My Workflow Name",
  "options": {
    "description": "Test run",
    "type": "automation",
    "variables": {"deviceName": "IOS-CAT8KV-1"}
  }
}
```

Response: `{"message": "...", "data": {"_id": "jobId", "status": "running"}}`

### Check Job Status

```
GET /operations-manager/jobs/{jobId}
```

Response wrapped in `{message, data, metadata}`:
- `data.status` — `"running"`, `"complete"`, `"error"`, `"canceled"`
- `data.variables` — all job variables including outputs
- `data.error` — array of error objects on failure

### Debug Failed Jobs

1. `GET /operations-manager/jobs/{jobId}` — check `data.status`
2. If `"error"`, read `data.error[]` — each has `task` (ID) and `message.IAPerror.displayString`
3. Identify the failing task ID, check its `metrics.finish_state`

**Common failures:**
| Symptom | Cause | Fix |
|---------|-------|-----|
| "Method not found" validation error | Task name doesn't exist | Search `tasks.json` |
| "No available transitions" | Missing error transition | Add `"state": "error"` transition |
| `$var` resolves to literal string | Non-hex task ID or nested object | Check task IDs, use merge |
| "Cannot find workflow" | childJob ref broken after project move | Update `workflow` field with `@projectId:` prefix |
| Schema validation error | Wrong/missing fields | Check `task-schemas.json` |
| Adapter error | Wrong app name or adapter down | Check `apps.json` and `GET /health/adapters` |

### Standalone Test Endpoints

Some tasks have REST endpoints for quick testing without creating workflows:
- **query:** `POST /workflow_engine/query` (needs dummy `job_id`)
- **Jinja2 render:** `POST /template_builder/templates/{name}/renderJinja` with `{"context": {...}}`
- **MOP:** `POST /mop/RunCommandTemplate` with `{"template": "name", "devices": [...], "variables": {...}}`

### Updating Assets (Edit Locally, PUT to Update)

| Asset | Create | Update |
|-------|--------|--------|
| Workflow | `POST /automation-studio/automations` | `PUT /automation-studio/automations/{id}` with `{"update": {...}}` |
| Template | `POST /automation-studio/templates` | `PUT /automation-studio/templates/{id}` with `{"update": {...}}` |
| Command Template | `POST /mop/createTemplate` | `POST /mop/updateTemplate/{name}` with `{"mop": {...}}` (full replacement) |

---

## Workflow Patterns

### Error Handling: Try-Catch

**In child workflows:** catch errors with `newVariable` to set a status flag:
```
task --success--> newVariable("taskStatus" = "success") -> workflow_end
task --error--> newVariable("taskStatus" = "error") -> workflow_end
```

**In parent workflows:** after childJob, extract and check:
```
childJob -> query (extract taskStatus from job_details) -> evaluation (== "success"?)
  |-- success -> continue
  |-- failure -> handle error
```

### Error Transitions on Adapter Tasks

Every adapter task needs both success and error transitions. Route errors to an intermediate `newVariable` task if both need to reach `workflow_end`:

```json
"transitions": {
  "a1b2": {
    "c3d4": {"type": "standard", "state": "success"},
    "err1": {"type": "standard", "state": "error"}
  },
  "err1": {
    "workflow_end": {"type": "standard", "state": "success"}
  }
}
```

### Manual Tasks (Human-in-the-Loop)

```json
{
  "name": "ViewData",
  "type": "manual",
  "view": "/workflow_engine/task/ViewData",
  "variables": {
    "incoming": {
      "header": "Approval Required",
      "message": "Review and approve.",
      "body": "$var.job.dataToReview",
      "btn_success": "Approve",
      "btn_failure": "Reject"
    }
  }
}
```

### Modular Workflow Design

- Build each child workflow independently testable via `jobs/start`
- Use `childJob` with `data_array` + `loopType: "parallel"` to fan out
- Check for existing workflows before building new ones
- Keep all asset JSON locally — edit locally, PUT to update

### Network Device Config Pattern

1. **MOP command templates** for validation checks only (show commands + rules)
2. **Jinja2 templates** to generate configuration
3. **Push config** via existing workflow or adapter task — ask the engineer
4. **Test CLI commands** on the actual device BEFORE building workflows

---

## Variable Syntax Reference

| Context | Syntax | Example |
|---------|--------|---------|
| Jinja2 templates | `{{ var }}` | `interface Vlan{{ vlan_id }}` |
| Command templates (MOP) | `<!var!>` | `show interface <!interface!>` |
| `makeData` input | `<!var!>` | `{"name": "<!name!>"}` |
| Workflow variable refs | `$var.job.x` or `$var.taskId.x` | `$var.job.deviceName` |
| childJob variable refs | `{"task":"job","value":"varName"}` | `{"task":"static","value":["a"]}` |
| merge/evaluation refs | `{"task":"job","variable":"varName"}` | `{"task":"static","variable":"success"}` |

**childJob uses `"value"`. merge/evaluation use `"variable"`. Do NOT mix them.**

---

## API Response Shapes

| Endpoint | Shape |
|----------|-------|
| `POST /operations-manager/jobs/start` | `{message, data: {_id, status}}` |
| `GET /operations-manager/jobs/{id}` | `{message, data: {status, variables, error}}` |
| `POST /automation-studio/projects` | `{message, data: {_id, name}}` |
| `POST /automation-studio/automations` | `{created: {_id, name}, edit: "..."}` |
| `POST /automation-studio/templates` | `{created: {_id, name}, edit: "..."}` |
| `GET /automation-studio/workflows` | `{items: [...], skip, limit, total}` |
| `GET /automation-studio/templates` | `{items: [...], skip, limit, total}` |

### Adapter Response Shapes

**Adapters transform upstream API responses.** Don't assume the native API's response structure. For example, ServiceNow's Table API returns `result.sys_id`, but the Itential adapter flattens it to `response.id`. Always verify by calling the adapter directly or checking `openapi.json`.

### Adapter URI Prefix

`genericAdapterRequest` auto-prepends the adapter's `base_path` to `uriPath`. Don't include `/api/v1` in `uriPath`. Use `genericAdapterRequestNoBasePath` to bypass.

---

## Gotchas

### Projects
1. **Create project FIRST, then build inside it** — moving assets renames them with `@projectId:` prefix but does NOT update internal references (childJob `workflow` fields, template names).
2. **`copy` mode silently no-ops for pre-prefixed workflows** — use `move` instead.
3. **Component type is `mopCommandTemplate`** not `mop`.
4. **Members PATCH is full replacement** — include ALL members.

### Workflows
5. **`canvasName` must come from `tasks.json`** — some differ from method name: `arrayPush`→`push`, `stringConcat`→`concat`.
6. **Task IDs must be hex `[0-9a-f]{1,4}`** — non-hex causes silent `$var` failure.
7. **Validation errors = draft workflow** that cannot be started.
8. **`$var` inside nested objects doesn't resolve** — use merge/makeData/query to build the object.
9. **Every adapter/external task needs an error transition** — without one, jobs get stuck.
10. **JSON can't have duplicate keys** — if success and error both go to `workflow_end`, use an intermediate task.

### Utility Tasks
11. **merge uses `"variable"`, childJob uses `"value"`** — don't mix them.
12. **merge requires at least 2 items** — 1 item = silently null.
13. **childJob `actor` MUST be `"job"`**, `task` MUST be `""`, `job_details` MUST be `null`.
14. **childJob `variables` use `{"task","value"}` NOT `$var`** — `$var` inside causes indefinite hang.
15. **`evaluation` MUST have both success AND failure transitions.**
16. **`forEach` last body task transition must be empty `{}`.**
17. **`push`/`pop`/`shift` take variable NAME as string** — `"myArray"` not `"$var.job.myArray"`.
18. **`newVariable` value with `$var` stores the literal string** — use merge + query.
19. **`makeData` `variables` must be a resolved object** — use merge first.

### Templates
20. **Template `group` cannot be empty or whitespace-only.**
21. **TextFSM templates may have control chars** that break jq — use Python with control-char strip.

### MOP
22. **Missing variable = skip = PASS (not fail)** — verify variables are passed correctly.
23. **`case: true` = case-INsensitive** — confusing name.
24. **Eval types are case-sensitive** — `"RegEx"` not `"regex"`.
25. **Empty rules = auto-pass** — add at least one rule for validation.
26. **MOP update is full replacement** — include ALL fields.
27. **MOP is read-only** — never use it to push config.

### General
28. **Adapter `app` must come from `apps.json`** — NOT `tasks.json` (names can differ completely).
29. **`status: complete` doesn't mean CLI commands succeeded** — check `stdout`.
30. **Endpoint base paths differ** — tasks at `/workflow_builder/tasks/list`, schemas at `/automation-studio/multipleTaskDetails` (NOT `/workflow_builder/multipleTaskDetails`).

---

## Helper Templates

**ALWAYS start from a helper template.** Read the file, modify for your use case, POST it.

| File | Purpose |
|------|---------|
| `helpers/create-project.json` | Project creation |
| `helpers/create-workflow.json` | Workflow scaffold (start/end) |
| `helpers/workflow-task-application.json` | Application task template |
| `helpers/workflow-task-adapter.json` | Adapter task template (includes error transition guidance) |
| `helpers/workflow-task-childjob.json` | childJob task (`actor: "job"`, `task: ""`) |
| `helpers/create-template-jinja2.json` | Jinja2 template |
| `helpers/create-template-textfsm.json` | TextFSM template |
| `helpers/create-command-template.json` | MOP command template |
| `helpers/update-command-template.json` | Update command template (full replacement) |
| `helpers/add-components-to-project.json` | Add assets to project |
| `helpers/update-project-members.json` | Update project membership |
| `helpers/reference-parent-workflow.json` | Reference: parent with childJob orchestration |
| `helpers/reference-child-workflow.json` | Reference: child with makeData/query/merge |
| `helpers/reference-merge-makedata.json` | Reference: merge → makeData pattern |
