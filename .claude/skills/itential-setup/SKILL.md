---
name: itential-setup
description: Connect to an Itential Platform, then choose ad-hoc exploration or spec-driven build. This is the single entry point for all work.
argument-hint: "[use-case-name]"
---

# Itential Setup — Entry Point

This is the entry point. Ask what the user wants, then route them.

```
/itential-setup
    │
    ├── "What are you here to do?"
    │     │
    │     ├── Exploring → Auth → Pull bootstrap → Summarize → Use skills
    │     │
    │     └── Build from spec → Pick spec → Fork → Set expectations → /solution-design
    │
    └── Already set up? → Reuse existing working directory
```

---

## Step 1: Ask Intent

**Do not authenticate first. Ask what the user wants to do.**

Two paths:
- **Explore** — inspect the platform, browse capabilities, build freestyle
- **Build from a spec** — implement a use case from an HLD spec

If the user already has a working directory from a previous session, offer to reuse it.

---

## Path A: Exploring

The engineer wants to look around, build freestyle, or isn't sure yet.

### 1. Authenticate

**Check for an env file first.** If one exists, use it — don't ask questions.

Look for environment files in this order:
1. `{use-case}/.env` — use-case-specific (if working directory already exists)
2. `environments/*.env` — pre-configured environments at repo root

If an env file is found, read it and authenticate automatically. If not, ask the engineer:
1. Platform URL
2. Credentials (username/password or client_id/secret)

### 2. Pull bootstrap data

```bash
mkdir -p {use-case-name}

# Run these in parallel
curl -s "{BASE}/help/openapi?url={ENCODED_BASE}&token=TOKEN" > {use-case}/openapi.json
curl -s "{BASE}/workflow_builder/tasks/list?token=TOKEN" > {use-case}/tasks.json
curl -s "{BASE}/automation-studio/apps/list?token=TOKEN" > {use-case}/apps.json
curl -s "{BASE}/health/adapters?token=TOKEN" > {use-case}/adapters.json
curl -s "{BASE}/health/applications?token=TOKEN" > {use-case}/applications.json
```

### 3. Save auth for other skills

```bash
cat > {use-case}/.auth.json << EOF
{
  "platform_url": "https://platform.example.com",
  "auth_method": "oauth",
  "token": "eyJhbG...",
  "timestamp": "2026-03-08T10:00:00Z"
}
EOF
```

### 4. Present summary and point to skills

Show: adapter count, app count, task count, what's running.

Point to:
- **`/itential-builder`** — projects, workflows, templates, command templates (MOP), run/test
- **`/itential-devices`** — devices, backups, diffs, device groups
- **`/itential-golden-config`** — golden config, compliance, remediation
- **`/iag`** — IAG services (Python, Ansible, OpenTofu)
- **`/flowagent`** — AI agents
- **`/itential-lcm`** — lifecycle management
- **`/itential-inventory`** — device inventories

---

## Path B: Build from a Spec

The engineer wants to build a use case from an HLD spec.

**No auth here. No data pulls. Just route.**

### 1. Pick a spec

Present available specs from `spec-files/`, grouped by category:

| Category | Specs |
|----------|-------|
| **Networking** | Port Turn-Up, VLAN Provisioning, Circuit Provisioning, BGP Peer, VPN Tunnel, WAN Bandwidth |
| **Operations** | Software Upgrade, Config Backup, Health Check, Device Onboarding, Device Decommissioning, Change Management, Incident Remediation |
| **Security** | Firewall Rules, Cloud Security Groups, SSL Certificates |
| **Infrastructure** | DNS Records, IPAM Lifecycle, Load Balancer VIP, Config Drift Remediation, Compliance Audit |

Or the engineer describes what they need and you recommend a spec.

### 2. Fork the spec

Create working directory and fork:

```bash
mkdir -p {use-case-name}
# Only fork if it doesn't already exist (engineer may have customized from a previous session)
[ ! -f {use-case}/customer-spec.md ] && cp spec-files/spec-port-turn-up.md {use-case}/customer-spec.md
```

**Note:** The forked file is now `customer-spec.md` (not `{use-case}-spec.md`). This is the artifact that gets refined and approved.

### 3. Set expectations

Tell the engineer what happens next:

> "Here's the plan from here:
>
> 1. **Understand** — I'll read the spec, ask about your business context, and refine it with you.
> 2. **Approve the spec** (Gate 1) — You review and lock the intent.
> 3. **Discover** — I'll connect to your platform and check what's available against your approved spec.
> 4. **Design** — I'll produce a solution design with what to build, reuse, and skip.
> 5. **Approve the design** (Gate 2) — You review and lock the plan.
> 6. **Build** — I'll execute the plan, test each piece, and deliver a project.
>
> You own both gates. Nothing gets built without your sign-off."

### 4. Hand off to `/solution-design`

**Artifact-based handoff.** The workspace contains exactly one file:

```
{use-case}/
  customer-spec.md    ← forked spec (untouched, unanalyzed)
```

No auth. No bootstrap data. No environment analysis. Solution-design owns all of that.

If the engineer provided credentials or an `.env` file exists, save it to `{use-case}/.env` so solution-design can use it later (after Gate 1). But do NOT authenticate yet.

---

## Authentication Reference

### Environment File Format

```bash
# environments/local-dev.env
PLATFORM_URL=http://localhost:4000
AUTH_METHOD=password       # "password" or "oauth"
USERNAME=admin             # for password auth
PASSWORD=admin             # for password auth
CLIENT_ID=your-id          # for oauth
CLIENT_SECRET=your-secret  # for oauth
```

Pre-configured environments are in `environments/`:
- `local-dev.env` — local development (localhost:4000, admin/admin)
- `cloud-lab.env` — cloud lab instance (OAuth)
- `staging.env` — staging instance (OAuth)

### Local Development (username/password)

```
POST /login
Content-Type: application/json

{"username": "admin", "password": "admin"}
```

Returns a token string. Use as query parameter: `GET /endpoint?token=TOKEN`

### Cloud / OAuth (client_credentials)

```
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

client_id=YOUR_CLIENT_ID
client_secret=YOUR_CLIENT_SECRET
grant_type=client_credentials
```

Returns `{"access_token": "eyJhbG..."}`. Use as Bearer header: `Authorization: Bearer eyJhbG...`

### Token Persistence

After authentication, save to `.auth.json`:

```bash
cat > {use-case}/.auth.json << EOF
{
  "platform_url": "https://platform.example.com",
  "auth_method": "oauth",
  "token": "eyJhbG...",
  "timestamp": "2026-03-08T10:00:00Z"
}
EOF
```

All skills check `.auth.json` before making API calls:
1. Read token and platform URL
2. Make the API call
3. On 401/403: re-authenticate using `.env` and update `.auth.json`
4. Never ask the user for credentials if `.env` exists

### Token Expiration

Tokens expire. On auth errors, re-authenticate using `.env` and update `.auth.json`. The user never re-enters credentials manually.

---

## Gotchas

- OAuth MUST use `Content-Type: application/x-www-form-urlencoded`, not JSON
- Tokens expire mid-session — on auth errors, re-authenticate silently
- `tasks/list` `app` field has WRONG casing for adapters — use `apps/list` for correct names
- OpenAPI spec is ~1.5MB — search it locally with `jq`, never load into context

---

## Files Created

### Exploring

| File | Purpose |
|------|---------|
| `.auth.json` | Auth token for all skills |
| `openapi.json` | Full API reference — search locally |
| `tasks.json` | Task catalog — search with jq/grep |
| `apps.json` | Apps with `name` and `type` |
| `adapters.json` | Adapter details: `id`, `package_id`, `state` |
| `applications.json` | Application details with state |

### Spec-based

| File | Purpose |
|------|---------|
| `customer-spec.md` | Forked spec — unmodified, handed to solution-design |
| `.env` | Credentials (if provided) — saved for later auth |

That's it. No bootstrap data, no environment analysis. Solution-design handles everything after Gate 1.

---

## Key Adapter Mapping

- `app` field in workflow tasks uses `apps/list` `name` (e.g., `Servicenow`)
- `adapter_id` in workflow tasks uses `health/adapters` `id` (e.g., `ServiceNow`)
- `tasks/list` `app` field may have WRONG casing — don't trust it for adapter names
