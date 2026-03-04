# Itential Platform — AI-Assisted Development

Skills and specs that enable an AI agent (Claude Code) to help engineers build automation on the Itential Platform.

## What's Here

```
.claude/skills/              Claude Code slash commands (8 skills)
  itential-setup/            Entry point: auth, bootstrap, route
  itential-studio/           Workflow/template/project CRUD, task palette
  itential-workflow-engine/  Run jobs, utility tasks, $var, patterns, debugging
  itential-mop/              Command templates, eval types, analytic templates
  itential-devices/          Devices, backups, diffs, device groups
  itential-golden-config/    Golden config, compliance, grading, remediation
  iag/                       Automation Gateway: iagctl + workflow integration
  solution-design/           Spec-driven: discover → design → build

environments/                Pre-configured platform credentials
  local-dev.env              localhost:4000, admin/admin
  cloud-lab.env              Cloud OAuth template
  staging.env                Staging OAuth template

helpers/                     JSON/YAML templates + bootstrap script
spec-files/                  21 technology-agnostic HLD use-case specs
docs/                        Architecture diagrams
CLAUDE.md                    Agent instructions (auto-loaded by Claude Code)
```

## Setup

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- Access to an Itential Automation Platform instance

### Getting Started

```bash
git clone https://github.com/keepithuman/itential-skills.git
cd itential-skills
claude
```

Claude Code automatically loads `CLAUDE.md` and the 8 skills.

### Connect to Your Platform

**Option 1 — Use an env file (no questions asked):**

Copy an environment file and edit if needed:
```bash
cp environments/local-dev.env .env
```

Then just run `/itential-setup` — it reads the env file and authenticates automatically.

**Option 2 — Tell the agent directly:**
```
> /itential-setup
> localhost:4000, admin/admin
```

### Choose Your Path

After setup, the agent asks: **"Ad-hoc or spec-based?"**

**Build from a spec** — pick a use-case (e.g., Port Turn-Up, Software Upgrade):

```
Spec Driven Flow:

  DISCOVER → SPEC REVIEW → DESIGN REVIEW → BUILD
                Gate 1 ✓      Gate 2 ✓
```

1. Forks the spec to your working directory (your copy to customize)
2. Discovers your environment (devices, adapters, workflows)
3. Collects your business context (naming conventions, policies)
4. **Gate 1:** Presents your customized spec for review — you approve before design starts
5. Produces a solution design matching your environment
6. **Gate 2:** Presents the design for review — you approve before build starts
7. Builds and tests everything step by step

Your spec (`{use-case}/spec.md`) is your source of truth. Change it later to add features, then re-run.

**Explore / build freestyle** — lighter bootstrap, use skills directly:
```
> List all devices and their OS types
> Create a command template for show vlan brief
> Build a workflow that backs up all Cisco devices
```

See `docs/developer-flow.md` for the full process diagram.

## Skills

| Skill | What It Does |
|-------|-------------|
| `/itential-setup` | **Start here.** Auth (from env file or interactive), bootstrap, route to spec-based or freestyle. |
| `/itential-studio` | Create workflows, Jinja2/TextFSM templates, projects. Discover tasks from the palette and get schemas. |
| `/itential-workflow-engine` | Run and test workflows. Utility tasks (query, merge, evaluation, childJob, forEach). $var resolution, patterns, debugging. |
| `/itential-mop` | Build command templates with validation rules. Run CLI checks against devices. Analytic templates for pre/post comparison. |
| `/itential-devices` | List devices, backup configs, diff configs, manage device groups, apply templates. |
| `/itential-golden-config` | Create golden config trees, config specs, compliance plans. Run compliance, grade, remediate. |
| `/iag` | Build IAG services (Python, Ansible, OpenTofu) with iagctl. Call them from workflows via GatewayManager. |
| `/solution-design` | Entered from setup. Two approval gates: spec review → design review → build. |

## Spec Files

21 technology-agnostic HLD specs that describe **what** to automate, not how:

| Spec | Use Case |
|------|----------|
| `spec-port-turn-up.md` | L2/L3 port provisioning with ITSM, IPAM, DCIM, and monitoring updates |
| `spec-software-upgrade.md` | Network device OS upgrade with pre/post validation and rollback |
| `spec-vlan-provisioning.md` | VLAN create/modify/delete across campus and DC switches |
| `spec-circuit-provisioning.md` | Dual-sided circuit turn-up with A-side/Z-side coordination |
| `spec-bgp-peer-provisioning.md` | Add/modify/remove BGP sessions with both-side deployment and verification |
| `spec-vpn-tunnel-provisioning.md` | IPsec/GRE tunnel setup with both-endpoint config and traffic verification |
| `spec-wan-bandwidth-modification.md` | Circuit bandwidth upgrade/downgrade with QoS policy updates |
| `spec-firewall-rule-lifecycle.md` | Rule request → validate → deploy → verify → recertify → decommission |
| `spec-cloud-security-groups.md` | AWS SG / Azure NSG / GCP firewall rule management with blast-radius analysis |
| `spec-ssl-certificate-lifecycle.md` | Certificate request → deploy → verify → monitor expiry → auto-renew |
| `spec-device-onboarding.md` | Day-0/Day-1 provisioning: base config, register, monitor, verify |
| `spec-device-decommissioning.md` | Remove from monitoring, IPAM, inventory, archive configs |
| `spec-config-backup-compliance.md` | Scheduled config backups with drift detection and compliance checking |
| `spec-config-drift-remediation.md` | Detect config drift from golden standard, classify, remediate or ticket |
| `spec-network-compliance-audit.md` | Scan configs against standards, grade, report, optionally remediate |
| `spec-network-health-check.md` | Standardized health check: CPU, memory, interfaces, neighbors, reachability |
| `spec-change-management.md` | Maintenance window orchestration: ticket, approve, suppress, execute, restore |
| `spec-incident-auto-remediation.md` | Alert → classify → match playbook → remediate → verify → close |
| `spec-dns-record-management.md` | DNS record CRUD across providers with propagation verification |
| `spec-load-balancer-vip.md` | VIP provisioning with pool, health monitors, and persistence profiles |
| `spec-ipam-lifecycle.md` | IP allocate → assign → track → reclaim with DNS/DHCP integration |

Each spec has 9 sections: Problem Statement, High-Level Flow, Phases, Key Design Decisions, Scope, Risks, Requirements, Batch Strategy, and Acceptance Criteria.

## Environments

Pre-configured environment files in `environments/`:

| File | Platform | Auth |
|------|----------|------|
| `local-dev.env` | `http://localhost:4000` | username/password (admin/admin) |
| `cloud-lab.env` | Cloud instance | OAuth client_credentials |
| `staging.env` | Staging instance | OAuth client_credentials |

Copy to your use-case directory: `cp environments/local-dev.env my-use-case/.env`

## Helpers

JSON/YAML templates in `helpers/` — always start from these when creating assets:

| File | Purpose |
|------|---------|
| `bootstrap.sh` | Bootstrap a use-case working directory with task catalog, adapters, apps |
| `create-workflow.json` | Workflow scaffold with start/end tasks |
| `workflow-task-adapter.json` | Adapter task template for workflows |
| `workflow-task-application.json` | Application task template for workflows |
| `workflow-task-childjob.json` | childJob task template (actor: "job", correct variable syntax) |
| `create-command-template.json` | Command template with validation rules |
| `update-command-template.json` | Update command template (full replacement) |
| `create-template-jinja2.json` | Jinja2 template for config generation |
| `create-template-textfsm.json` | TextFSM template for output parsing |
| `create-project.json` | Project creation |
| `add-components-to-project.json` | Add assets to project (with move warning) |
| `import-project.json` | Import a project |
| `update-project-members.json` | Update project membership |
| `create-golden-config-tree.json` | Golden config tree |
| `create-golden-config-node.json` | Child node |
| `update-node-config.json` | Node template with full syntax reference |
| `add-devices-to-node.json` | Assign devices to a node |
| `create-compliance-plan.json` | Compliance plan |
| `run-compliance-plan.json` | Run compliance plan |
| `run-compliance.json` | Run compliance directly |
| `helpers/iag/` | IAG service examples (Python, Ansible, OpenTofu, multi-service) |
