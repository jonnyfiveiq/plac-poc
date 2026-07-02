# What's Next After Phase 1

## ✅ What You Have Now

**Execution Environment (`quay.io/jhardy/poc-plac:latest`):**
- ✅ ansible.platform 2.7 (Gateway configuration)
- ✅ ansible.controller 4.8 (Controller resources)
- ✅ ansible.eda 2.12 (Event-Driven Ansible)
- ✅ ansible.hub 1.1 (Private Automation Hub)
- ✅ kubernetes.core 3.0 (CR mode support)

**Reconcile Role Coverage:**
- ✅ Organizations (Gateway)
- ✅ Teams (Gateway)
- ✅ Users (Gateway)
- ✅ Authenticators (Gateway)
- ✅ Projects (Controller)
- ✅ Execution Environments (Controller)

**Capabilities:**
- ✅ Dual-mode: file-based AND CR-based
- ✅ Dry-run mode (test without AAP)
- ✅ Plan/apply/diff verbs
- ✅ Idempotent reconciliation
- ✅ Makefile automation

## 🧪 Immediate Testing (Today)

### 1. Test Without AAP (Dry-Run)

```bash
# This works RIGHT NOW - no AAP required
podman run --rm \
  --entrypoint=/runner/reconcile/entrypoint.sh \
  -v $PWD/examples/desired-state.example.yml:/state/desired-state.yml:ro \
  -v $PWD/execution-environment/ansible.cfg:/etc/ansible/ansible.cfg:ro \
  -e DRY_RUN=true \
  -e AAP_GATEWAY_URL="https://fake.example.com" \
  -e AAP_TOKEN="fake-token" \
  quay.io/jhardy/poc-plac:latest apply
```

**Expected:** Shows what would be created (orgs, teams, users, projects, EEs)

### 2. Validate Syntax

```bash
podman run --rm \
  --entrypoint=/runner/reconcile/entrypoint.sh \
  -v $PWD/examples/desired-state.example.yml:/state/desired-state.yml:ro \
  quay.io/jhardy/poc-plac:latest validate
```

### 3. Fix the Entrypoint (Makefile Update Needed)

The image's ENTRYPOINT is still set to the builder default. Update Makefile's test targets to use `--entrypoint=/runner/reconcile/entrypoint.sh` or rebuild the EE with a fixed entrypoint.

## 🚀 Testing Against Real AAP

Once you have an AAP instance ready:

### 1. Set Credentials

```bash
# In .env:
AAP_GATEWAY_URL=https://your-aap-gateway.apps.example.com
AAP_TOKEN=your_gateway_admin_token
```

### 2. Run Plan (Check Mode)

```bash
podman run --rm \
  --entrypoint=/runner/reconcile/entrypoint.sh \
  -v $PWD/examples/desired-state.example.yml:/state/desired-state.yml:ro \
  -v $PWD/execution-environment/ansible.cfg:/etc/ansible/ansible.cfg:ro \
  -e AAP_GATEWAY_URL="$AAP_GATEWAY_URL" \
  -e AAP_TOKEN="$AAP_TOKEN" \
  quay.io/jhardy/poc-plac:latest plan
```

**Expected:** Shows what would change, exits non-zero if changes needed

### 3. Run Apply

```bash
# Same command, change 'plan' to 'apply'
podman run --rm \
  --entrypoint=/runner/reconcile/entrypoint.sh \
  -v $PWD/examples/desired-state.example.yml:/state/desired-state.yml:ro \
  -v $PWD/execution-environment/ansible.cfg:/etc/ansible/ansible.cfg:ro \
  -e AAP_GATEWAY_URL="$AAP_GATEWAY_URL" \
  -e AAP_TOKEN="$AAP_TOKEN" \
  quay.io/jhardy/poc-plac:latest apply
```

### 4. Verify Idempotence

Re-run apply - should report **zero changes**.

### 5. Test Drift Detection

1. Manually delete one organization in AAP UI
2. Run `plan` - should detect the drift
3. Run `apply` - should restore it

## 📋 Phase 1 Acceptance Criteria

| ID | Criteria | How to Test | Status |
|----|----------|-------------|--------|
| **A1** | `make ee-build` produces image with ansible.platform | `podman images \| grep poc-plac` | ✅ Done |
| **A2** | `apply` creates all resources in example file | Run against clean AAP | 🟡 Needs AAP |
| **A3** | Re-running `apply` reports zero changes | Run `apply` twice | 🟡 Needs AAP |
| **A4** | `plan` detects drift after manual deletion | Delete resource, run `plan` | 🟡 Needs AAP |
| **A5** | `diff` prints readable before/after | Run `diff` verb | 🟡 Needs AAP |

## 🔜 Phase 2: Schema Validation

Once Phase 1 is validated:

### Goals
1. Create `schema/platform-state.schema.json` (OpenAPI v3 compatible)
2. Implement proper `validate` verb using jsonschema
3. Generate schema from `ansible.platform`/`ansible.controller` module docs
4. Ensure schema can drop into CRD in Phase 3

### Deliverables
- JSON Schema file
- Schema generator script (`schema/gen_from_docs.py`)
- Updated `validate` verb
- Documentation explaining "one schema, three surfaces" (file/CRD/modules)

### Acceptance Criteria
- **B1:** Malformed file fails `validate` with clear error
- **B2:** Example file validates clean
- **B3:** Generator demonstrates schema derived from module docs

## 🔮 Phase 3: Operator + CRD

### Goals
1. Create CRD using Phase 2 schema
2. Build lightweight operator (kopf recommended)
3. Operator launches EE as Kubernetes Job
4. Status updates written back to CR

### Deliverables
- `crd/platformstate.yaml`
- `operator/` (kopf app or Operator SDK)
- `deploy/` (manifests, RBAC, ServiceAccount)
- Sample CR
- Operator documentation

### Acceptance Criteria
- **C1:** `oc apply` of manifests brings up healthy operator
- **C2:** Creating PlatformState CR triggers Job that reconciles AAP
- **C3:** Editing CR triggers new reconciliation
- **C4:** Out-of-band drift corrected on resync
- **C5:** Bad spec surfaces as failed condition on CR

## 📝 Open Questions / Decisions

1. **Operator choice:** Kopf (Python, clean separation) vs Ansible Operator SDK (faster)?
2. **Topology reconciliation:** Stretch goal or Phase 4?
3. **Additional Controller resources:** Credentials, Inventories, Job Templates in Phase 2?
4. **Secret management:** Single Secret OK for POC, or design for Vault integration?

## 📚 Documentation You Have

- **QUICKSTART.md** - Get running in 5 minutes
- **PHASE1-SUMMARY.md** - What was built and what you need to supply
- **README.md** - Project overview
- **docs/phase1-manual-run.md** - Detailed Phase 1 guide
- **docs/cr-mode-testing.md** - Testing with CRs before operator exists
- **docs/collections-added.md** - All AAP collections and module reference
- **docs/automation-hub-auth.md** - How authentication works
- **docs/build-notes.md** - Build troubleshooting

## 🤝 Getting Help

- Review acceptance criteria status
- Check `docs/` for specific topics
- Grep the reconcile role for examples: `grep -r "ansible.controller" reconcile/`
- List available modules: `podman run --rm quay.io/jhardy/poc-plac:latest ansible-doc -l | grep ansible.controller`

---

**Status:** Phase 1 Implementation Complete  
**Next Action:** Test with real AAP, then move to Phase 2 Schema  
**Contact:** See MAINTAINERS.md
