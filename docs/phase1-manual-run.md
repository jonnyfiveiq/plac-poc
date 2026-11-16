# Phase 1: Manual EE Execution

This guide covers building and running the AAP Platform Lifecycle Execution Environment (EE) manually, without the Operator or CRD.

## Prerequisites

### Development Tools (macOS)

Install the following tools on your Mac:

```bash
# Install ansible-builder
pip3 install ansible-builder

# Install ansible-navigator (optional, for advanced testing)
pip3 install ansible-navigator

# Install/verify podman
brew install podman
podman machine init
podman machine start
```

### Required Credentials

1. **Automation Hub Token** (for `ansible.platform` collection)
   - Get from: https://console.redhat.com/ansible/automation-hub/token
   - Set in `.env` as `ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN`

2. **Quay Robot Account** (provided)
   - Username: `jhardy+bob`
   - Token: Set `REGISTRY_PASSWORD` in `.env` (never commit this token)
   - Repository: https://quay.io/repository/jhardy/poc-plac

3. **AAP Gateway Credentials**
   - Gateway URL (e.g., `https://gateway.aap.example.com`)
   - Admin token (preferred) OR username/password

## Setup

1. **Clone the repository** (if not already done):
   ```bash
   cd ~/upstream/POC-Platform-lifecycle-as-code
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env and fill in your credentials:
   #   - ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN
   #   - REGISTRY_PASSWORD (Quay robot token)
   #   - AAP_GATEWAY_URL
   #   - AAP_TOKEN (or AAP_USERNAME/AAP_PASSWORD)
   ```

3. **Verify tools**:
   ```bash
   make help
   ```

## Building the EE

```bash
# Build the execution environment image
make ee-build
```

This will:
- Use `ansible-builder` to create a container image
- Install `ansible.platform` collection from Automation Hub
- Embed the reconcile role and entrypoint
- Tag as `quay.io/jhardy/poc-plac:latest`

**Build time:** 5-10 minutes (first time; cached afterward)

## Testing Locally (Dry Run Mode)

Before connecting to a real AAP instance, test the EE in dry-run mode:

```bash
make test-dry-run
```

This will:
- Load the example desired-state file
- Parse and validate the structure
- Show what **would** be created (without API calls)
- Verify the role logic works

**Expected output:**
```
==> File mode: using /state/desired-state.yml
==> Running in APPLY mode (apply)
DRY RUN MODE - No actual changes will be made
[DRY RUN] Display organizations to be created
Would create organization: Engineering
Would create organization: Operations
...
```

## Running Against Real AAP

### 1. Validate the Desired State File

```bash
make validate STATE_FILE=examples/desired-state.example.yml
```

### 2. Plan (Check Mode)

Show what changes would be made **without** applying them:

```bash
make plan
```

**Exit code:**
- `0` = No changes needed (idempotent)
- `Non-zero` = Changes would be made

### 3. Diff (Detailed Changes)

See a detailed before/after diff:

```bash
make diff
```

### 4. Apply (Execute Changes)

Apply the desired state to your AAP instance:

```bash
make apply
```

**Re-running `apply`** should report zero changes (idempotence test).

## File-Based vs CR-Based Mode

The EE supports two modes:

### File-Based Mode (Default)

Mount a YAML file:

```bash
podman run --rm \
  -v ./examples/desired-state.example.yml:/state/desired-state.yml:ro \
  -e AAP_GATEWAY_URL="https://your-gateway" \
  -e AAP_TOKEN="your-token" \
  quay.io/jhardy/poc-plac:latest apply
```

### CR-Based Mode (Early Testing for Phase 3)

Run against a `PlatformState` custom resource **without the operator**:

```bash
# First, create the CR:
oc apply -f examples/platformstate-sample.yaml

# Then run the EE pointing at the CR:
podman run --rm \
  -v ~/.kube/config:/root/.kube/config:ro \
  -e CR_NAME="example-platform" \
  -e CR_NAMESPACE="aap-lifecycle-poc" \
  -e AAP_GATEWAY_URL="https://your-gateway" \
  -e AAP_TOKEN="your-token" \
  quay.io/jhardy/poc-plac:latest apply
```

The EE will:
1. Use `oc` to fetch the CR's `.spec`
2. Extract the desired state
3. Reconcile AAP to match

This proves the schema works before building the operator.

## Verbs Reference

| Verb | Description | Check Mode | Diff Output |
|------|-------------|------------|-------------|
| `validate` | Validate YAML syntax (Phase 2: full schema) | N/A | No |
| `plan` | Show if changes are needed | Yes | No |
| `diff` | Show detailed before/after | Yes | Yes |
| `apply` | Execute changes | No | No |

## Troubleshooting

### Build Fails: "ansible.platform not found"

**Cause:** Automation Hub token not set or invalid.

**Fix:**
```bash
# Verify token is set:
echo $ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN

# Re-export and rebuild:
export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN="your-token"
make ee-build
```

### Runtime Fails: "AAP_GATEWAY_URL not set"

**Cause:** Missing environment variables.

**Fix:** Check your `.env` file and re-run with explicit vars:
```bash
AAP_GATEWAY_URL="https://your-gateway" AAP_TOKEN="your-token" make apply
```

### CR Mode Fails: "oc command not found"

**Cause:** The EE image doesn't include `oc` by default.

**Fix:** Add `oc` to the EE definition in Phase 3, or use file mode for now.

## Next Steps

After Phase 1 acceptance criteria pass:
- **Phase 2:** Add JSON Schema validation
- **Phase 3:** Build the Operator and CRD

---

**Phase 1 Acceptance Criteria:**
- [x] A1: `make ee-build` produces an image containing `ansible.platform`
- [ ] A2: `apply` against a clean AAP creates every resource in the example file
- [ ] A3: Re-running `apply` reports zero changes (idempotent)
- [ ] A4: Manually deleting one resource, then `plan`, reports drift; `apply` restores it
- [ ] A5: `diff` prints a readable before/after for a pending change
