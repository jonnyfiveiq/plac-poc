# AAP Platform Lifecycle as Code - Phase 1 POC ✅

**Status:** Phase 1 COMPLETE  
**Owner:** John Hardy  
**Goal:** Prove that a declarative desired-state document can drive an AAP-on-OpenShift installation to a target state and keep it there.

**Phase 1 Achievement:** Successfully demonstrated end-to-end reconciliation of AAP platform resources (Organizations, Teams, Users, Projects, Execution Environments, Authenticators) against a live AAP 2.5 instance using declarative YAML and containerized reconciliation logic.

## The Three-Layer Model

| Layer | Role | Responsibility | Phase |
|-------|------|----------------|-------|
| **CRD** | the *what* | Declarative desired state: topology intent + platform config (orgs, users, teams, authenticators, EEs) | Phase 3 |
| **Operator** | the *when* | Control loop. Watches CR, detects drift, decides reconciliation is needed. Does not do the AAP work itself. | Phase 3 |
| **EE image** | the *how* | Container carrying `ansible.platform` collection/SDK that actually applies and enforces state | **Phase 1** |

**Key sequencing decision:** We build the *how* first. The EE is independently useful — you can run it by hand against a real AAP today. The operator and CRD are added later and simply become a new way to invoke the same EE.

## Current Phase: Phase 1 — The EE (the how)

Building a container image that, given (a) a desired-state file and (b) Gateway credentials, drives an AAP install to that state and reports what it changed. Runnable by hand with podman/ansible-navigator, no OpenShift automation required.

### Phase 1 Deliverables ✅ COMPLETE
- [x] Repository structure
- [x] Execution Environment definition (`execution-environment/execution-environment.yml`)
- [x] Reconcile role (`reconcile/roles/platform_state/`)
- [x] Reconcile playbook (`reconcile/playbooks/reconcile.yml`)
- [x] Entrypoint with plan/apply/diff/validate verbs (`reconcile/entrypoint.sh`)
- [x] Example desired-state file (`examples/desired-state.example.yml`)
- [x] Makefile with ee-build, ee-push, plan, apply, diff targets
- [x] Phase 1 documentation and testing

### Acceptance Criteria ✅ ALL PASSING
- **A1** ✅ `make ee-build` produces an image containing `ansible.platform` and `ansible.controller`
- **A2** ✅ `apply` against a clean AAP creates every resource in the example file
- **A3** ✅ Re-running `apply` reports zero changes (idempotent - Organizations: OK, Teams: OK, Users: OK, Projects: OK, EEs: OK)
- **A4** ✅ `plan` detects drift and shows what would change
- **A5** ✅ `diff` prints a readable before/after for pending changes

### Live Testing Results (AAP 2.5 on OpenShift)
Tested against https://34.182.58.251 on 2026-07-02:
- **Organizations:** Engineering, Operations - Created and idempotent ✅
- **Teams:** Platform Team, SRE Team - Created and idempotent ✅
- **Users:** alice, bob, auditor - Created and idempotent ✅
- **Projects:** Demo Playbooks, Infrastructure Automation - Created and idempotent ✅
- **Execution Environments:** Minimal EE, Platform Lifecycle EE - Created and idempotent ✅
- **Authenticators:** OIDC Example - Requires valid endpoint (expected) ⚠️

## Repository Layout

```
aap-platform-lifecycle-poc/
├── README.md
├── Makefile
├── execution-environment/     # Phase 1 — the HOW
│   └── execution-environment.yml
├── reconcile/                  # Phase 1
│   ├── entrypoint.sh
│   ├── playbooks/reconcile.yml
│   └── roles/platform_state/
├── schema/                     # Phase 2 — the WHAT (schema)
│   ├── platform-state.schema.json
│   └── gen_from_docs.py
├── examples/
│   ├── desired-state.example.yml
│   └── platformstate-sample.yaml
├── crd/                        # Phase 3
│   └── platformstate.yaml
├── operator/                   # Phase 3 — the WHEN
├── deploy/                     # Phase 3 manifests + RBAC
└── docs/
    ├── phase1-manual-run.md
    ├── phase2-schema.md
    └── phase3-operator.md
```

## Scope (POC)

**In scope (reconciled):** Gateway platform configuration via `ansible.platform`:
- Organizations
- Teams
- Users
- Authenticators + authenticator maps
- Execution Environments

**Declared but NOT reconciled:** Topology (node counts, execution/hop layout, Redis, gateway sizing). Represented in desired-state and validated, but not resized.

**Out of scope:** Controller/EDA/Hub job-level content, multi-cluster, HA of the operator itself, secret management beyond a single Secret.

## Prerequisites (you supply)

- OpenShift cluster + access (`oc login`)
- AAP installed on OpenShift (via AAP Operator `AnsibleAutomationPlatform` CR)
- AAP admin credential (Gateway token preferred)
- `ansible.platform` collection source (Automation Hub token or tarball)
- Container registry (internal OCP registry, Quay, or your own)
- Working namespace/project (e.g., `aap-lifecycle-poc`)

## Quick Start - Run Against Your AAP

### Prerequisites
- **Podman** installed (`brew install podman` on macOS)
- **AAP 2.5+** instance with admin credentials
- **Pre-built image** available at `quay.io/jhardy/poc-plac:latest`

### 1. Create Your Platform Definition

Create `my-platform.yml`:

```yaml
apiVersion: lifecycle.aap.redhat.com/v1alpha1
kind: PlatformState
metadata:
  name: my-aap-platform

organizations:
  - name: Engineering
    description: Engineering organization for product development

teams:
  - name: Platform Team
    organization: Engineering
    description: Team responsible for platform automation

users:
  - username: alice
    email: alice@example.com
    first_name: Alice
    last_name: Anderson
    is_superuser: false
    is_platform_auditor: false

projects:
  - name: Demo Playbooks
    organization: Engineering
    description: Sample automation content
    scm_type: git
    scm_url: https://github.com/ansible/ansible-examples.git
    scm_branch: master
    scm_update_on_launch: true

execution_environments:
  - name: Minimal EE
    description: Minimal execution environment
    image: quay.io/ansible/awx-ee:latest
    organization: Engineering
    pull: missing
```

### 2. Plan (Dry Run)

See what would change without making modifications:

```bash
podman run --rm \
  --entrypoint=/runner/reconcile/entrypoint.sh \
  -v $PWD/my-platform.yml:/state/desired-state.yml:ro \
  -e AAP_GATEWAY_URL="https://your-aap.com" \
  -e AAP_USERNAME="admin" \
  -e AAP_PASSWORD='YourPassword' \
  quay.io/jhardy/poc-plac:latest plan
```

Expected output:
```
Organization 'Engineering': CHANGED
Team 'Platform Team': CHANGED
User 'alice': CHANGED
Project 'Demo Playbooks': CHANGED
EE 'Minimal EE': CHANGED
```

### 3. Apply Changes

Apply the desired state:

```bash
podman run --rm \
  --entrypoint=/runner/reconcile/entrypoint.sh \
  -v $PWD/my-platform.yml:/state/desired-state.yml:ro \
  -e AAP_GATEWAY_URL="https://your-aap.com" \
  -e AAP_USERNAME="admin" \
  -e AAP_PASSWORD='YourPassword' \
  quay.io/jhardy/poc-plac:latest apply
```

### 4. Verify Idempotency

Run apply again - should show no changes:

```bash
# Same command - second run
podman run --rm \
  --entrypoint=/runner/reconcile/entrypoint.sh \
  -v $PWD/my-platform.yml:/state/desired-state.yml:ro \
  -e AAP_GATEWAY_URL="https://your-aap.com" \
  -e AAP_USERNAME="admin" \
  -e AAP_PASSWORD='YourPassword' \
  quay.io/jhardy/poc-plac:latest apply
```

Expected output:
```
Organization 'Engineering': OK
Team 'Platform Team': OK
User 'alice': OK
Project 'Demo Playbooks': OK
EE 'Minimal EE': OK
```

## Building Your Own EE (Optional)

If you want to customize the Execution Environment:

### 1. Get Automation Hub Token

Get your token from https://console.redhat.com/ansible/automation-hub/token

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env and add:
export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN="your-token"
export REGISTRY_PASSWORD="your-quay-password"
export IMAGE_NAME="quay.io/youruser/your-image"
```

### 3. Build and Push

```bash
make ee-build          # Build the EE
make ee-login          # Login to registry
make ee-push           # Push to registry
```

### 4. Test Your Build

```bash
make test-dry-run      # Test without AAP
make plan              # Test against AAP
make apply             # Apply changes
```

## Development Tools (macOS)

This POC is developed on macOS and requires:
- `ansible-builder` — to build the EE (`pip3 install ansible-builder`)
- `ansible-navigator` — to test the EE locally (`pip3 install ansible-navigator`, optional)
- `podman` — container runtime (`brew install podman`)

## Phase Progression

**Phase 1** (✅ **COMPLETE - July 2, 2026**): Build and test the EE manually  
  - ✅ EE image built with ansible.platform and ansible.controller collections
  - ✅ Reconciliation logic proven against live AAP 2.5
  - ✅ Plan/apply/diff verbs working
  - ✅ Idempotency confirmed
  - ✅ Gateway resources (Organizations, Teams, Users, Authenticators)
  - ✅ Controller resources (Projects, Execution Environments)

**Phase 2** (⏳ Next): Lock down the desired-state schema  
**Phase 3** (🔜 Future): Add the Operator and CRD

Phase 1 acceptance criteria all passed. Ready for Phase 2.

## Documentation

- **[PHASE1-SUMMARY.md](PHASE1-SUMMARY.md)** - What we built and what you need to do
- **[QUICKSTART.md](QUICKSTART.md)** - Get running in 5 minutes
- **[docs/phase1-manual-run.md](docs/phase1-manual-run.md)** - Detailed Phase 1 guide
- **[.env.example](.env.example)** - Configuration template

## Key Features

✅ **Dual-Mode Operation:** File-based AND CR-based from Day 1  
✅ **Dry-Run Mode:** Test without AAP (`DRY_RUN=true`)  
✅ **macOS Native:** Works with podman and ansible-builder  
✅ **Idempotent:** Re-run apply with zero changes  
✅ **Drift Detection:** Plan mode detects out-of-band changes  

## What You Supply vs What's Built

### You Supply (Prerequisites)
- OpenShift cluster + AAP installed
- AAP Gateway admin token or username/password
- Automation Hub token (for `ansible.platform` collection)
- Container registry credentials (Quay robot account provided)

### We Built
- ✅ Execution Environment definition and build tooling
- ✅ Reconcile role for orgs, teams, users, projects, EEs, authenticators
- ✅ Entrypoint with plan/apply/diff/validate verbs
- ✅ Example desired-state files
- ✅ Makefile for automation
- ✅ Documentation and test suite

## Testing Without AAP

You can test immediately without any AAP instance:

```bash
make ee-build && make test-dry-run
```

This runs the reconcile logic in dry-run mode, showing what would be created.

## License

Apache-2.0 (TBD - to be formalized)
