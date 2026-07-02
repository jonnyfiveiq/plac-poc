# Quick Start Guide

Get the AAP Platform Lifecycle EE running in 5 minutes.

## 1. Install Prerequisites (macOS)

```bash
# Install tools
pip3 install ansible-builder ansible-navigator
brew install podman

# Start podman
podman machine init
podman machine start
```

## 2. Configure Credentials

```bash
# Copy the example env file
cp .env.example .env

# Edit .env and set these REQUIRED values:
# - ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN (from console.redhat.com)
# - REGISTRY_PASSWORD (Quay robot token provided)
# - AAP_GATEWAY_URL (your AAP Gateway URL)
# - AAP_TOKEN (your Gateway admin token)

# Or use username/password for dev:
# - AAP_USERNAME=admin
# - AAP_PASSWORD=yourpassword
```

## 3. Test Without AAP (Dry Run)

```bash
# Build the EE
make ee-build

# Test in dry-run mode (no AAP required)
make test-dry-run
```

**Expected:** You'll see "Would create organization: Engineering..." messages showing what the EE would do.

## 4. Run Against Real AAP

```bash
# Validate the example file
make validate

# See what would change (check mode)
make plan

# Apply the desired state
make apply
```

## 5. Verify Idempotence

```bash
# Run apply again - should report zero changes
make apply
```

## What Just Happened?

The EE reconciled your AAP instance to match `examples/desired-state.example.yml`:

- ✅ Created 2 organizations (Engineering, Operations)
- ✅ Created 2 teams
- ✅ Created 3 users
- ✅ Created 2 projects
- ✅ Created 2 execution environments
- ✅ Created 1 authenticator (OIDC example)

## Next: Test Drift Detection

```bash
# 1. Manually delete an organization in AAP UI

# 2. Run plan - should detect the drift
make plan

# 3. Run apply - should restore it
make apply
```

## Troubleshooting

**"ansible.platform not found"**
- Check `ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN` in `.env`
- Get a token from: https://console.redhat.com/ansible/automation-hub/token

**"AAP_GATEWAY_URL not set"**
- Make sure `.env` exists and has valid credentials
- Run: `source .env` then retry

**Build takes forever**
- First build downloads base images (~2GB)
- Subsequent builds use cache (~1-2 minutes)

## Full Documentation

- [Phase 1 Manual Run Guide](docs/phase1-manual-run.md)
- [Repository README](README.md)
