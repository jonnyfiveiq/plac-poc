# Build Notes and Workarounds

## Known Issues

### systemd-python Build Failure

**Issue:** `ansible-builder` introspects all collections in the base EE (`registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9`), including `ansible.eda`, which has a dependency on `systemd-python`. This package requires `systemd-devel` and `python3-devel` at build time, which aren't available in the builder stage.

**Impact:** The build fails with:
```
Cannot find libsystemd or libsystemd-journal
```

**Root cause:** We don't actually use `ansible.eda` for platform lifecycle management, but ansible-builder collects ALL transitive dependencies from all collections in the base image.

**Workaround implemented:**
1. Created custom `requirements.txt` and `bindep.txt` to avoid full introspection
2. Added `append_builder` step to remove `systemd-python` from the generated requirements:
   ```yaml
   append_builder:
     - RUN sed -i '/systemd-python/d' /tmp/src/requirements.txt || true
   ```

**Why this works:** The base EE already has all the collections we need (`ansible.platform`, etc.). We're only adding:
- `kubernetes.core` (for CR-based mode)
- Our custom reconcile role
- A few lightweight Python deps (pyyaml, jsonschema, kubernetes client)

We **don't** need EDA collections or their dependencies.

**Alternative solutions considered:**
1. ❌ Add `systemd-devel` and `pkg-config` - requires keeping `python3-devel` in final image (bloat)
2. ❌ Use `--build-arg EE_BUILDER_IMAGE` with a custom builder - complex, harder to maintain
3. ✅ Skip the problematic dep with `sed` - simple, no runtime impact

## Verifying the Build

After a successful build, verify `ansible.platform` is present:

```bash
podman run --rm quay.io/jhardy/poc-plac:latest ansible-galaxy collection list | grep ansible.platform
```

Expected output:
```
ansible.platform    1.x.x
```

## Future Improvements

- Consider using `ansible-builder` 3.1+ `exclude` feature (if available) to skip EDA deps
- File upstream issue with ansible-builder about selective introspection
- Create a minimal base EE with only platform collections (longer term)
