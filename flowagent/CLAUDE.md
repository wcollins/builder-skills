# Itential Platform — FlowAgent Guide

Skills for creating and running AI agents on the Itential Platform. Agents use LLMs to autonomously call platform tools and complete objectives.

## Skill Router

| Skill | Owns | When to Use |
|-------|------|-------------|
| `/flowagent` | **AI Agents** | Create agents, configure LLM providers, discover tools, run missions, track results. |

## Key Rules

1. **Set up a provider first** — agents need an LLM. `POST /automationagency/providers` with type + API key.
2. **Discover tools before creating agents** — `POST /automationagency/discover/tools` scans the platform.
3. **Tool identifiers use `//`** — `adapter_name//method_name`, e.g., `ServiceNow//createChangeRequest`
4. **Agent identity = platform credentials** — the agent authenticates as that user. Controls what it can access.
5. **Capabilities are a whitelist** — only tools, projects, workflows, and agents listed in capabilities are available to the agent.
6. **callAgent is synchronous** — waits for the mission to complete before returning.

## When Something Doesn't Work

1. **Read the error** — `"Missing default_provider"`, `"Provider instance not found"`, `"Unknown provider type"` tell you exactly what's wrong
2. **Check `openapi.json`** — fetch it: `curl -s "{BASE}/help/openapi?url={ENCODED_BASE}" -H "Authorization: Bearer {TOKEN}" > openapi.json`. Search: `jq '.paths | keys[] | select(contains("automationagency"))'`
3. **Check the body wrapper** — `POST /agents` uses `{details: {...}}`, `POST /providers` uses `{details: {...}}`
4. **If schema is empty** — send `{}` and read the `"Missing Params"` error for required fields
5. **Agent fails silently** — check the mission: `GET /missions/{id}` for `success`, `conclusion`, and `toolStats`
