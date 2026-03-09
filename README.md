# Itential Platform — AI-Assisted Development

Skills and specs that enable an AI agent (Claude Code) to help engineers build automation on the Itential Platform.

## What's Here

```
.claude/skills/              Claude Code slash commands (12 skills)
  itential-setup/            Entry point: auth, bootstrap, route
  itential-builder/          Build everything: projects, workflows, templates, MOP, utility tasks, $var, debugging
  itential-studio/           Workflow/template/project CRUD, task palette
  itential-mop/              Command templates, eval types, analytic templates
  itential-devices/          Devices, backups, diffs, device groups
  itential-golden-config/    Golden config, compliance, grading, remediation
  itential-inventory/        Device inventories, nodes, actions, tags (IAG5)
  itential-lcm/              Resource models, instances, lifecycle actions
  iag/                       Automation Gateway: iagctl + workflow integration
  flowagent/                 AI agents: LLM providers, tools, missions
  solution-design/           Spec-driven: discover → design → build

environments/                Pre-configured platform credentials
  local-dev.env              localhost:4000, admin/admin
  cloud-lab.env              Cloud OAuth template
  staging.env                Staging OAuth template

helpers/                     JSON/YAML templates, reference workflows
spec-files/                  21 technology-agnostic HLD use-case specs
evals/                       Skill evaluation suite + e2e integration tests
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

Claude Code automatically loads `CLAUDE.md` and the skills.

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
> Build a workflow with merge, childJob, and query tasks
> Create a pre-check command template for interface validation
> Create an AI agent that monitors device health and creates ServiceNow tickets
> Back up configs for all Cisco devices and diff against last known good
> Build a compliance plan for golden config
```

See `docs/developer-flow.md` for the full process diagram.

## Skills

| Skill | What It Does |
|-------|-------------|
| `/itential-setup` | **Start here.** Auth (from env file or interactive), bootstrap, route to spec-based or freestyle. |
| `/itential-builder` | **Build everything.** Projects, workflows, templates (Jinja2/TextFSM), command templates (MOP). Wire utility tasks, run jobs, debug. $var resolution, workflow patterns, adapter discovery. |
| `/itential-studio` | Create workflows, Jinja2/TextFSM templates, projects. Discover tasks from the palette and get schemas. |
| `/itential-mop` | Build command templates with validation rules. Run CLI checks against devices. Analytic templates for pre/post comparison. |
| `/itential-devices` | List devices, backup configs, diff configs, manage device groups, apply templates. |
| `/itential-golden-config` | Create golden config trees, config specs, compliance plans. Run compliance, grade, remediate. |
| `/iag` | Build IAG services (Python, Ansible, OpenTofu) with iagctl. Call them from workflows via GatewayManager. |
| `/itential-inventory` | Manage device inventories, nodes, actions, and tags. Required for IAG5 integration. |
| `/itential-lcm` | Define resource models with schemas and actions. Manage instances, run lifecycle actions, track execution history. |
| `/flowagent` | Create and run AI agents on the platform. Configure LLM providers (Claude, OpenAI, Ollama), discover tools, run missions, debug. |
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

JSON/YAML templates in `helpers/` — always start from these when creating assets.

**Scaffolds** — start here when creating new assets:

| File | Purpose |
|------|---------|
| `bootstrap.sh` | Bootstrap a use-case working directory with task catalog, adapters, apps |
| `create-workflow.json` | Workflow scaffold with start/end tasks |
| `create-template-jinja2.json` | Jinja2 template for config generation |
| `create-template-textfsm.json` | TextFSM template for output parsing |
| `create-command-template.json` | Command template (MOP) with validation rules |
| `update-command-template.json` | Update command template (full replacement) |
| `create-project.json` | Project creation |

**Workflow task templates** — embed these inside workflows:

| File | Purpose |
|------|---------|
| `workflow-task-adapter.json` | Adapter task (add `adapter_id`, error transition) |
| `workflow-task-application.json` | Application task (WorkFlowEngine, TemplateBuilder, etc.) |
| `workflow-task-childjob.json` | childJob task (`actor: "job"`, `{"task","value"}` syntax) |

**Reference workflows** — tested patterns to study and copy:

| File | Purpose |
|------|---------|
| `reference-adapter-workflow.json` | merge → adapter create → query → adapter update, with error handling |
| `reference-childjob-loop.json` | Parent + child workflows for childJob loop pattern |
| `reference-parent-workflow.json` | Parent orchestrator: childJob → query → evaluation branching |
| `reference-child-workflow.json` | Child workflow with try-catch (always sets taskStatus) |
| `reference-merge-makedata.json` | merge → makeData pattern for string/JSON construction |

**Projects** — packaging and delivery:

| File | Purpose |
|------|---------|
| `add-components-to-project.json` | Add assets to project (move/copy warning) |
| `import-project.json` | Import a project |
| `update-project-members.json` | Update project membership (full replacement) |

**Golden config & compliance:**

| File | Purpose |
|------|---------|
| `create-golden-config-tree.json` | Golden config tree |
| `create-golden-config-node.json` | Child node |
| `update-node-config.json` | Node template with full syntax reference |
| `add-devices-to-node.json` | Assign devices to a golden config node |
| `create-compliance-plan.json` | Compliance plan |
| `run-compliance-plan.json` | Run compliance plan |
| `run-compliance.json` | Run compliance directly |

**Other:**

| File | Purpose |
|------|---------|
| `lcm-action-workflow.json` | LCM action workflow (must output `instance` variable) |
| `helpers/iag/` | IAG service examples (Python, Ansible, OpenTofu, multi-service) |

## Evals

Skill evaluation suite in `evals/`:

| File | Purpose |
|------|---------|
| `evals.json` | 32 assertion-based test cases across 5 skills (81 assertions) |
| `COVERAGE-REPORT.md` | Gotcha coverage matrix — 58/58 documented, 24/24 critical tested |
| `e2e/run-e2e-tests.sh` | End-to-end test runner (deploys workflows, runs jobs, validates) |
| `e2e/e2e-results.json` | Latest results: 11/11 pass on cloud platform |
| `e2e/test1-*.json` | Utility chain: merge → makeData → query → evaluation branching |
| `e2e/test2-*.json` | childJob loop: parent fans out to child per device |
| `e2e/test3-*.json` | Adapter pattern: merge → ServiceNow create → query response |

Run e2e tests: `bash evals/e2e/run-e2e-tests.sh`
