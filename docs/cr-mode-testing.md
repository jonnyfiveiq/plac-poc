# CR-Based Testing Without the Operator

One of the key features we built into Phase 1 is the ability to test the `PlatformState` CR schema **before building the Operator**. This lets you validate end-to-end integration early.

## Why This Matters

The three-layer model (CRD → Operator → EE) means:
1. **CRD** defines the desired state schema (`.spec`)
2. **Operator** watches the CR and launches the EE
3. **EE** reads the `.spec` and reconciles AAP

By supporting CR-based mode in the EE from Day 1, we can:
- ✅ Prove the schema works before Phase 3
- ✅ Validate that `oc apply` → EE works end-to-end
- ✅ Test the exact data structure the Operator will use
- ✅ Build confidence that Phase 3 is just "add the control loop"

## Prerequisites

1. OpenShift cluster access (`oc login`)
2. The EE image built and pushed to Quay
3. A namespace/project (e.g., `aap-lifecycle-poc`)
4. AAP Gateway credentials

## Step-by-Step CR Testing

### 1. Create the CRD (Placeholder)

For Phase 1 testing, we don't need the full CRD. Create a minimal ConfigMap-based CR:

```bash
# This is a temporary CR format - real CRD comes in Phase 3
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-state-example
  namespace: aap-lifecycle-poc
  labels:
    app: aap-lifecycle
    type: platform-state
data:
  spec.yaml: |
$(cat examples/desired-state.example.yml | sed 's/^/    /')
EOF
```

**Note:** In Phase 3, this becomes a real `PlatformState` CR. For now, ConfigMap is enough to prove the pattern.

### 2. Run the EE Against the ConfigMap

```bash
podman run --rm \
  -v ~/.kube/config:/root/.kube/config:ro \
  -e CONFIG_MAP_MODE=true \
  -e CR_NAMESPACE="aap-lifecycle-poc" \
  -e CR_NAME="platform-state-example" \
  -e AAP_GATEWAY_URL="https://your-gateway" \
  -e AAP_TOKEN="your-token" \
  quay.io/jhardy/poc-plac:latest apply
```

**What happens:**
1. EE mounts your `~/.kube/config` (read-only)
2. Uses `oc get configmap` to fetch the spec
3. Extracts the YAML from the ConfigMap
4. Reconciles AAP to match

### 3. Verify It Worked

```bash
# Check what was created in AAP via the UI or API
# Re-run the same command - should report zero changes (idempotent)
```

## Real CR Mode (Phase 3 Preview)

Once the CRD exists in Phase 3, the command becomes:

```bash
# Apply a real PlatformState CR
oc apply -f examples/platformstate-sample.yaml

# Run EE pointing at the real CR
podman run --rm \
  -v ~/.kube/config:/root/.kube/config:ro \
  -e CR_NAME="example-platform" \
  -e CR_NAMESPACE="aap-lifecycle-poc" \
  -e AAP_GATEWAY_URL="https://your-gateway" \
  -e AAP_TOKEN="your-token" \
  quay.io/jhardy/poc-plac:latest apply
```

The entrypoint detects `CR_NAME` and uses:
```bash
oc get platformstate example-platform -n aap-lifecycle-poc -o jsonpath='{.spec}'
```

## Running as a Kubernetes Job

You can also run the EE as a Kubernetes Job (this is what the Operator will do in Phase 3):

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: platform-reconcile
  namespace: aap-lifecycle-poc
spec:
  template:
    spec:
      serviceAccountName: platform-lifecycle-sa
      containers:
      - name: reconcile
        image: quay.io/jhardy/poc-plac:latest
        env:
        - name: CR_NAME
          value: "example-platform"
        - name: CR_NAMESPACE
          value: "aap-lifecycle-poc"
        - name: AAP_GATEWAY_URL
          value: "https://your-gateway"
        - name: AAP_TOKEN
          valueFrom:
            secretKeyRef:
              name: aap-gateway-token
              key: token
      restartPolicy: Never
  backoffLimit: 3
```

**What this proves:**
- The EE can read CRs from inside a pod
- Credentials can come from Secrets
- Job pattern works (Operator in Phase 3 just creates this Job)

## Why File Mode Still Matters

Even with CR support, file mode remains useful:

1. **Local development** - Test on your Mac without OpenShift
2. **CI/CD** - Validate desired-state files in pipelines
3. **Manual operations** - Quick reconcile without CRs
4. **Debugging** - Easier to iterate on YAML files than CRs

## Comparing Modes

| Feature | File Mode | CR Mode | Operator (Phase 3) |
|---------|-----------|---------|-------------------|
| Input source | YAML file | Kubernetes CR | Kubernetes CR |
| Trigger | Manual `podman run` | Manual `podman run` | Automatic (watch) |
| Credentials | Env vars | Env vars or Secrets | Secrets |
| Status | stdout | stdout | CR `.status` |
| Drift correction | Manual re-run | Manual re-run | Periodic resync |
| Best for | Dev, testing, CI | Early integration | Production |

## Next: Add Schema Validation (Phase 2)

Right now, both modes accept any YAML structure. Phase 2 adds JSON Schema validation:

```bash
make validate  # File mode
# or
oc get platformstate example -o json | jq .spec | validate-schema  # CR mode
```

This ensures the CR's `.spec` matches the file format exactly.

## Summary

CR-based mode in Phase 1 proves:
- ✅ The schema works end-to-end
- ✅ `oc apply` → EE → AAP reconcile path is solid
- ✅ Phase 3 Operator just needs to add the watch loop
- ✅ No "translation layer" between file and CR formats

**Your question answered:** Yes, you can absolutely test the EE against a CR without the Operator. The EE is designed to work both ways from Day 1.
