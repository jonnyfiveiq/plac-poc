# Automation Hub Authentication for ansible.platform

## Why Authentication is Required

The `ansible.platform` collection is **Red Hat Certified Content**, not community content. It's only available from:
- **console.redhat.com/ansible/automation-hub** (Red Hat Automation Hub)
- **Private Automation Hub** instances

It is **NOT** available on:
- ansible-galaxy.ansible.com (community Galaxy)
- quay.io or other public registries

## Getting Your Token

1. Go to: https://console.redhat.com/ansible/automation-hub/token
2. Log in with your Red Hat account
3. Click **"Load token"**
4. Copy the token value

## Setting the Token for Builds

The token must be available at **build time** so `ansible-galaxy collection install` can authenticate.

### Method 1: Environment Variable (Recommended)

```bash
# In your .env file:
ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN=your_token_here

# Then build normally:
make ee-build
```

The Makefile passes this as a build arg to `ansible-builder`.

### Method 2: Inline

```bash
ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN="your_token" make ee-build
```

## How It Works

1. **Makefile** passes the token as a build arg:
   ```make
   --build-arg ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN="$(ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN)"
   ```

2. **execution-environment.yml** declares the ARG and sets it as ENV:
   ```yaml
   prepend_galaxy:
     - ARG ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN
     - ENV ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN=$ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN
   ```

3. **ansible-galaxy** reads the env var and authenticates to Automation Hub

4. **ansible.cfg** points to the Hub URL:
   ```ini
   [galaxy_server.automation_hub]
   url = https://console.redhat.com/api/automation-hub/content/published/
   ```

## Security Notes

- ✅ The token is **NOT** baked into the final image - it's only used during build
- ✅ The token is **NOT** committed to git (`.gitignore` blocks `.env`)
- ⚠️ The token **IS** visible in build logs if you use `--verbosity=3`
- ⚠️ Docker/Podman build args are visible in image history (use `podman history`)

For CI/CD, store the token in a secure secret manager (GitHub Secrets, GitLab CI Variables, etc.).

## Troubleshooting

### Error: "Could not satisfy the following requirements: ansible.platform"

**Cause:** Token not set or invalid.

**Fix:**
```bash
# Check if token is set:
echo $ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN

# If empty, set it:
export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN="your_token"

# Or add to .env
echo "ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN=your_token" >> .env
```

### Error: "401 Unauthorized"

**Cause:** Token expired or revoked.

**Fix:** Get a fresh token from console.redhat.com.

### Error: "403 Forbidden"

**Cause:** Your Red Hat account doesn't have access to Automation Hub.

**Fix:** Contact your Red Hat admin or purchase an Ansible Automation Platform subscription.

## Alternative: Use the Full AAP EE

If you can't get an Automation Hub token, you can use the pre-built AAP EE which already has `ansible.platform`:

```yaml
# In execution-environment.yml:
images:
  base_image:
    name: 'registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel9:latest'

dependencies:
  galaxy:
    collections:
      # Remove ansible.platform - it's already in the base
      - name: kubernetes.core
        version: '>=2.4.0'
```

**Trade-off:** You get 80+ collections you don't need, but skip the Hub auth requirement.

**Note:** You'll still need registry.redhat.io credentials for the base image pull.
