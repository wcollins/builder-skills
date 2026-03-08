---
name: flowagent
description: Create and run AI agents on the Itential Platform. Agents use LLMs to autonomously call platform tools (adapters, workflows, IAG services) to complete objectives. Use when setting up agents, configuring LLM providers, managing tools, or running missions.
argument-hint: "[action or agent-name]"
---

# Automation Agency - FlowAgent Skills Guide

Automation Agency lets you create AI agents that use LLMs (Claude, OpenAI, Ollama, Databricks) to autonomously operate the Itential Platform. Agents can call adapters, run workflows, invoke IAG services, and delegate to other agents — all driven by natural language objectives.

## Concepts

- **Agent** — a named AI entity with an LLM provider, system/user messages, an identity (platform credentials), and capabilities (which tools, projects, workflows, and sub-agents it can use)
- **Tool** — a callable function discovered from the platform (adapter methods, IAG services, application methods). Auto-discovered, stored in a toolchest.
- **Mission** — a single execution of an agent. Tracks start/end, objective, conclusion, token usage, and tool call statistics.
- **Provider Instance** — a configured LLM connection (Claude, OpenAI, Ollama, Databricks) with API keys and model settings.
- **Capabilities** — what an agent is allowed to use: specific tools (by identifier), projects, workflows, and sub-agents.

## How to Build an Agent

### Step 1: Understand the intent

Before building anything, ask:
- What is the agent supposed to accomplish?
- What external systems does it need to interact with? (ServiceNow, devices, cloud, etc.)
- Is this a one-time task or a reusable agent?
- Does it need to make changes or just gather information?
- Should it ask for approval before acting?

### Step 2: Discover the environment

Pull the tools locally so you can search and plan:

```bash
# Discover all platform tools
POST /automationagency/discover/tools

# Pull the full list locally
GET /automationagency/tools > tools.json

# Search by keyword
jq '.[] | select(.identifier | contains("ServiceNow"))' tools.json
jq '.[] | select(.schema.description | contains("device"))' tools.json

# Check what adapters/integrations are available
GET /health/adapters
GET /integrations

# Check what providers are configured
GET /automationagency/providers
```

### Step 3: Plan the agent

Based on the intent and available tools, design:

1. **Which tools does the agent need?** Search `tools.json` for matching capabilities. Check for duplicate tool names across adapters — if found, pick the right adapter instance.
2. **What's the execution flow?** Map out the steps: "first get device info, then check config, then create ticket if needed."
3. **What identity does it need?** The agent runs as a platform user — does that user have permissions for the tools and APIs it needs?
4. **What LLM provider and model?** Pick based on complexity — simple tasks can use smaller/cheaper models, complex multi-tool orchestration benefits from stronger models.

### Step 4: Write the prompts

**System prompt** — tell the agent WHO it is and HOW to work:
- Its role and expertise
- What tools are available and when to use each one
- Expected output format
- Constraints (read-only, require approval, etc.)

**User prompt** — the specific OBJECTIVE for this run:
- Be specific about inputs (device names, ticket details)
- For reusable agents, keep the user prompt generic and pass specifics via `context`

### Step 5: Test the tools BEFORE giving them to the agent

Don't give an agent a tool you haven't tested yourself. Every tool is a platform API call — test it directly first.

**What a tool entry contains:**
```json
{
  "type": "adapter",
  "identifier": "ServiceNow//createChangeRequest",
  "schema": {
    "name": "createChangeRequest",
    "description": "Creates a change request",
    "schema": {"type": "object", "properties": {"body": {...}}}
  },
  "active": true
}
```
- `type` — `adapter`, `app`, or `service` (IAG)
- `identifier` — `source//method` format
- `schema` — input parameters with types and descriptions (this is what the LLM sees)

**The tool entry does NOT contain the direct route.** Map it yourself:

| Tool type | Identifier | Direct test route |
|-----------|-----------|------------------|
| `adapter` | `ServiceNow//createChangeRequest` | `POST /ServiceNow/createChangeRequest` |
| `adapter` | `AutomationGateway//sendCommand` | `POST /AutomationGateway/sendCommand` |
| `app` | `ConfigurationManager//getDevice` | Check `openapi.json` for the route under `configuration_manager` |
| `service` | `cluster_1//my-service` | `POST /gateway_manager/v1/gateways/cluster_1/services/my-service/run` |
| integration | `dog-api//listAllBreeds` | `POST /dog-api/listAllBreeds` |

For **app** tools, the route is not the same as the identifier — look it up in `openapi.json`:
```bash
jq '.paths | keys[] | select(contains("configuration_manager"))' openapi.json
```

**Test the tool directly:**
```bash
# Check what inputs the tool expects
GET /automationagency/tools/{tool_id}
# Look at schema.schema.properties for the input fields

# Or check the openapi spec for the underlying endpoint
jq '.paths | keys[] | select(contains("ServiceNow"))' openapi.json
jq '.paths["/ServiceNow/createChangeRequest"].post.requestBody' openapi.json

# Call it directly to see what it returns
POST /ServiceNow/createChangeRequest
{"body": {"short_description": "test", "summary": "test"}}
```

**Testing each tool type:**

Adapter call:
```bash
# Tool: ServiceNow//createChangeRequest
# Direct test:
POST /ServiceNow/createChangeRequest
{"body": {"short_description": "test", "summary": "test"}}
```

Application call:
```bash
# Tool: ConfigurationManager//getDevice
# Direct test:
POST /configuration_manager/getDevice
{"name": "IOS-CAT8KV-1"}

# Or check the endpoint in openapi:
jq '.paths | keys[] | select(contains("configuration_manager"))' openapi.json
```

Workflow call (run a workflow the agent would trigger):
```bash
# Tool references a workflow by ID/name
# Test it directly:
POST /operations-manager/jobs/start
{"workflow": "My Workflow", "options": {"type": "automation", "variables": {"input1": "value"}}}

# Check the result:
GET /operations-manager/jobs/{jobId}
```

IAG service call:
```bash
# Tool: cluster_1//my-python-service
# Test via GatewayManager:
POST /gateway_manager/v1/gateways/{clusterId}/services/{serviceName}/run
{"params": {"device_ip": "10.0.0.1"}}

# Or via CLI:
iagctl run service python-script my-python-service --set device_ip=10.0.0.1
```

Integration call (codeless adapter):
```bash
# Tool: dog-api//listAllBreeds
# Direct test:
POST /dog-api/listAllBreeds
{}
# Response is raw HTTP — data is in the "body" field
```

If the direct call fails, the agent will fail too. Fix the inputs first, then teach the agent the right way via the system prompt.

### Step 6: Create, run, and troubleshoot

```
1. POST /automationagency/agents → create with tools + prompts
2. POST /automationagency/agents/{name}/call → run it
3. GET /automationagency/missions → check the result
```

**When a mission fails, debug like this:**

1. **Check the mission** — `GET /automationagency/missions/{id}`
   - `conclusion` — what the agent said at the end (may include error details)
   - `toolStats.tools` — which tools were called and how many times
   - `tokenUsage` — if very high, the agent may be looping or confused

2. **Identify which tool failed** — the conclusion usually says which tool errored and why

3. **Test that tool directly** — call the same API endpoint with the same parameters the agent used. Check the openapi spec for the correct request format.

4. **Fix the system prompt** — if the agent is passing wrong parameters, add guidance:
   ```
   When calling createChangeRequest, the body MUST include "summary" field.
   The device name for getDevice is the exact name like "IOS-CAT8KV-1", not an IP address.
   ```

5. **Re-run and iterate** — update the agent (`PUT /automationagency/agents/{name}`), call again, check mission again

**Common issues and fixes:**

| Problem | Cause | Fix |
|---------|-------|-----|
| Tool returns error | Wrong parameters | Test tool directly, check openapi for correct inputs, update system prompt |
| Agent calls wrong tool | Unclear objective | Be more specific in user prompt about what to do |
| Agent loops | Too many tools or vague prompt | Reduce tools, add step-by-step guidance in system prompt |
| "Tool names must be unique" | Duplicate method names across adapters | Remove conflicting tools from capabilities |
| Agent doesn't use tools | Tools not in capabilities or prompt doesn't suggest using them | Add tools to `capabilities.toolset`, mention them in system prompt |
| High token usage | Agent is exploring too many options | Constrain with "use ONLY these tools" in system prompt |

### How the agent runs

1. Agent receives the objective (messages + context)
2. LLM decides which tools to call based on the objective
3. Tools execute on the platform (adapter calls, workflow runs, etc.)
4. Results feed back to the LLM
5. Repeats until the objective is met
6. Mission is recorded with conclusion, token usage, and tool stats

## API Reference

**Base Path:** `/automationagency`

### Agents

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/automationagency/agents` | Create an agent |
| GET | `/automationagency/agents` | List all agents |
| GET | `/automationagency/agents/{agent_id}` | Get agent details |
| PUT | `/automationagency/agents/{name}` | Update an agent |
| DELETE | `/automationagency/agents/{agent_id}` | Delete an agent |
| POST | `/automationagency/agents/{agent_id}/call` | Run an agent (starts a mission) |
| POST | `/automationagency/adhoc_agent` | Run a one-off agent without saving it |

**Create an agent:**
```
POST /automationagency/agents
```
```json
{
  "details": {
    "name": "network-ops-agent",
    "description": "Monitors device health and creates ServiceNow tickets for issues",
    "identity": {
      "agent_account": "agent-user",
      "agent_password": "agent-pass"
    },
    "llm": {
      "provider": "Production Claude",
      "overrides": {
        "model": "claude-sonnet-4-20250514"
      }
    },
    "messages": [
      {
        "role": "system",
        "content": "You are a network operations agent. You monitor device health and create tickets for any issues found."
      },
      {
        "role": "user",
        "content": "Check the health of all Cisco IOS devices and create a ServiceNow ticket for any that are unreachable."
      }
    ],
    "capabilities": {
      "agents": [],
      "projects": ["Network Operations"],
      "toolset": [
        "ServiceNow//createChangeRequest",
        "AutomationGateway//sendCommand"
      ],
      "workflows": [
        {"id": "workflow-uuid", "name": "Device Health Check"}
      ]
    }
  }
}
```

**Agent fields:**
- `name` — unique agent name
- `description` — what the agent does
- `identity.agent_account` / `agent_password` — platform credentials the agent uses to authenticate. The agent runs API calls AS this user — controls what the agent can access.
- `llm.provider` — name of a provider instance (e.g., `"Production Claude"`)
- `llm.overrides` — optional: override model, apiKey, temperature, etc.
- `messages` — system prompt and user objective. Array of `{role: "system"|"user", content: "..."}`
- `capabilities.toolset` — array of tool identifiers the agent can use. Format: `"adapter_name//method_name"` or `"cluster//service_name"` for IAG
- `capabilities.agents` — names of other agents this agent can call (delegation)
- `capabilities.projects` — project names the agent has access to
- `capabilities.workflows` — workflows the agent can run directly (array of `{id, name}`)

**Call an agent:**
```
POST /automationagency/agents/{agent_id}/call
```
```json
{
  "context": {
    "device_list": ["IOS-CAT8KV-1", "IOS-CAT8KV-2"],
    "priority": "high"
  }
}
```
- `context` — optional key-value data passed to the agent's execution. Appended to messages or available as context.
- Returns when the mission completes (synchronous — waits for the agent to finish)

**Ad-hoc agent (no save):**
```
POST /automationagency/adhoc_agent
```
```json
{
  "description": "Quick device check",
  "objective": "Check if IOS-CAT8KV-1 is reachable and get its version",
  "tools": ["AutomationGateway//sendCommand"],
  "context": {}
}
```
Requires `default_provider` to be set in app properties.

### Tools

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/automationagency/tools` | List all discovered tools |
| GET | `/automationagency/tools/{tool_id}` | Get tool details (schema, type) |
| DELETE | `/automationagency/tools/{tool_id}` | Delete a tool |
| DELETE | `/automationagency/tools` | Clear all tools |
| POST | `/automationagency/discover/tools` | Discover tools from platform |
| POST | `/automationagency/activate/tools` | Activate specific tools |
| POST | `/automationagency/deactivate/tools` | Deactivate specific tools |

**Discover tools:**
```
POST /automationagency/discover/tools
```
No body needed. Scans the platform and finds:
- **Adapter methods** — from all running adapters (each method becomes a tool)
- **IAG services** — from GatewayManager (each service becomes a tool)
- **Application methods** — from platform apps

Each tool gets an `identifier` in the format `source//method_name`:
- Adapter: `ServiceNow//createChangeRequest`
- IAG: `cluster_1//my-python-service`

**Tool structure:**
```json
{
  "type": "adapter",
  "identifier": "ServiceNow//createChangeRequest",
  "schema": {
    "name": "createChangeRequest",
    "description": "Creates a change request",
    "schema": {"type": "object", "properties": {...}}
  },
  "active": true,
  "sync": true
}
```

**Activate/deactivate tools:**
```
POST /automationagency/activate/tools
{"tools": ["ServiceNow//createChangeRequest", "AutomationGateway//sendCommand"]}

POST /automationagency/deactivate/tools
{"tools": ["ServiceNow//createChangeRequest"]}
```

### Missions

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/automationagency/missions` | List all missions |
| GET | `/automationagency/missions/{mission_id}` | Get mission details |
| DELETE | `/automationagency/missions/{mission_id}` | Delete a mission |
| DELETE | `/automationagency/missions` | Clear all missions |

**Mission structure:**
```json
{
  "mission": "uuid",
  "agent": "network-ops-agent",
  "start": "2026-03-04T...",
  "end": "2026-03-04T...",
  "objective": "Check device health...",
  "conclusion": "All devices healthy. No tickets needed.",
  "success": true,
  "tokenUsage": {
    "input_tokens": 1234,
    "output_tokens": 567
  },
  "modelMetadata": {
    "model": "claude-sonnet-4-20250514",
    "provider": "Production Claude"
  },
  "toolStats": {
    "totalCalls": 3,
    "tools": {"sendCommand": 2, "createChangeRequest": 1}
  }
}
```

### LLM Providers

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/automationagency/provider-types` | List supported LLM types |
| GET | `/automationagency/providers` | List provider instances |
| GET | `/automationagency/providers/{name}` | Get provider instance (secrets redacted) |
| POST | `/automationagency/providers` | Add a provider instance |
| PUT | `/automationagency/providers/{name}` | Update a provider instance |
| DELETE | `/automationagency/providers/{name}` | Delete a provider instance |
| GET | `/automationagency/providers/{name}/models` | List available models for a provider |

**Supported provider types:** `claude`, `openai`, `llama` (Ollama), `databricks`

**Add a Claude provider:**
```
POST /automationagency/providers
```
```json
{
  "details": {
    "name": "Production Claude",
    "type": "claude",
    "config": {
      "apiKey": "sk-ant-...",
      "model": "claude-sonnet-4-20250514"
    }
  }
}
```

**Add an Ollama provider (local):**
```json
{
  "details": {
    "name": "Local Llama",
    "type": "llama",
    "config": {
      "url": "http://localhost:11434",
      "model": "llama3"
    }
  }
}
```

**Add an OpenAI provider:**
```json
{
  "details": {
    "name": "GPT Production",
    "type": "openai",
    "config": {
      "apiKey": "sk-...",
      "model": "gpt-4o"
    }
  }
}
```

**List available models:**
```
GET /automationagency/providers/Production%20Claude/models
```
Returns models available from the provider's API.

## Gotchas

- Tool identifiers use `//` as separator: `adapter_name//method_name`, NOT `/` or `.`
- Agent `identity` credentials determine what platform APIs the agent can call — the agent authenticates as that user
- `callAgent` is synchronous — it waits for the mission to complete before returning
- `adHocAgent` requires `default_provider` set in app properties (`PUT /applications/AutomationAgency/properties`)
- Tool discovery (`POST /discover/tools`) scans ALL adapters, apps, and IAG — can generate thousands of tools
- `capabilities.toolset` filters which discovered tools the agent can actually use — don't give agents access to everything
- `capabilities.workflows` takes `{id, name}` objects, not just names
- Provider secrets are redacted in GET responses — `config.hasApiKey: true` instead of the actual key
- Missions store token usage and tool call stats — use for cost tracking
- Agent runs in a worker thread — the main platform thread is not blocked
- `messages` array order matters: system prompt first, then user objective
- `llm.overrides` can override ANY provider config (model, temperature, apiKey) per-agent
- **"Tool names must be unique" error** — happens when multiple adapters expose methods with the same name (e.g., `getDevice` on two adapters). The LLM provider rejects duplicate tool names. Use specific tool identifiers in `capabilities.toolset` to avoid loading conflicting tools.
- **callAgent response may be empty** — the call is async via event system. Check `GET /missions` after calling to get the result.

## Using Agents in Workflows

All agent operations are available as workflow tasks under `AutomationAgency`:

| Task | Purpose | Key Inputs |
|------|---------|------------|
| `callAgent` | Run a saved agent | `agent_id`, `context` |
| `adHocAgent` | Run a one-off agent | `description`, `objective`, `tools`, `context` |
| `listAgents` | List all agents | — |
| `describeAgent` | Get agent details | `agent_id` |
| `getMission` | Get mission result | `mission_id` |
| `listTools` | List available tools | — |
| `describeTool` | Get tool schema | `tool_id` |
| `discoverTools` | Scan platform for tools | — |

**Calling an agent from a workflow:**
```json
{
  "name": "callAgent",
  "app": "AutomationAgency",
  "type": "operation",
  "location": "Application",
  "variables": {
    "incoming": {
      "agent_id": "$var.job.agentName",
      "context": "$var.job.agentContext"
    },
    "outgoing": {
      "result": "$var.job.agentResult"
    }
  }
}
```

This lets you build workflows that orchestrate agents — call an agent, check its mission result, branch on success/failure, or chain multiple agents together.

## Patterns

### Minimal agent (no tools, just LLM)
```json
{
  "details": {
    "name": "poet",
    "description": "writes poems",
    "identity": {"agent_account": "admin", "agent_password": "admin"},
    "llm": {"provider": "Production Claude"},
    "messages": [
      {"role": "system", "content": "You are a poet."},
      {"role": "user", "content": "Write a haiku about network automation."}
    ],
    "capabilities": {"toolset": [], "agents": [], "projects": []}
  }
}
```

### Agent with platform tools
```json
{
  "details": {
    "name": "device-checker",
    "description": "Checks device health using platform adapters",
    "identity": {"agent_account": "agent-svc", "agent_password": "pass"},
    "llm": {"provider": "Production Claude"},
    "messages": [
      {"role": "system", "content": "You check device health using available tools."},
      {"role": "user", "content": "Check if IOS-CAT8KV-1 is reachable."}
    ],
    "capabilities": {
      "toolset": ["AutomationGateway//sendCommand"],
      "agents": [],
      "projects": []
    }
  }
}
```

### Agent that delegates to sub-agents
```json
{
  "capabilities": {
    "agents": ["device-checker", "ticket-creator"],
    "toolset": [],
    "projects": []
  }
}
```
The agent can call other agents by name — they appear as tools.

## Developer Scenarios

### 1. Set up from scratch
```
1. POST /automationagency/providers              → configure LLM (Claude/OpenAI/Ollama)
2. POST /automationagency/discover/tools          → scan platform for available tools
3. GET  /automationagency/tools                   → review what's available
4. POST /automationagency/agents                  → create agent with tools + prompt
5. POST /automationagency/agents/{id}/call        → run it
6. GET  /automationagency/missions/{id}           → check results
```

### 2. Quick test with ad-hoc agent
```
1. Set default_provider in app properties
2. POST /automationagency/adhoc_agent with description + objective + tools
3. Returns mission result directly
```

### 3. Debug a failed mission
```
1. GET /automationagency/missions/{id}            → check success, conclusion, errors
2. Check tokenUsage                                → did it run out of context?
3. Check toolStats                                 → which tools were called?
4. Check agent identity                            → does the agent user have permissions?
5. Check tool identifiers                          → correct format: source//method?
```
