# AAP Collections in the EE

## Collections Installed

The Execution Environment now includes these AAP collections from Automation Hub:

### ansible.platform (2.7.x)
**Purpose:** Gateway platform configuration  
**Modules:** organization, team, user, authenticator, authenticator_map, settings, etc.  
**Scope:** AAP Gateway-level resources

### ansible.controller (4.x)
**Purpose:** Automation Controller configuration  
**Modules:** project, execution_environment, credential, inventory, job_template, workflow, etc.  
**Scope:** Controller resources (jobs, inventories, projects)

### ansible.eda (2.x)
**Purpose:** Event-Driven Ansible configuration  
**Modules:** rulebook_activation, decision_environment, eda_credential, etc.  
**Scope:** EDA resources

### ansible.hub (1.x)
**Purpose:** Private Automation Hub configuration  
**Modules:** collection, namespace, repository, etc.  
**Scope:** Hub resources

### kubernetes.core (3.x)
**Purpose:** Kubernetes/OpenShift interaction  
**Modules:** k8s, k8s_info, helm, etc.  
**Scope:** CR-based mode support

## Module Parameter Differences

### Gateway vs Controller Modules

**ansible.platform modules** use:
```yaml
gateway_url: https://gateway.example.com
gateway_token: xxx
# or
gateway_username: admin
gateway_password: xxx
```

**ansible.controller modules** use:
```yaml
controller_host: https://controller.example.com
controller_oauthtoken: xxx
# or
controller_username: admin
controller_password: xxx
```

### How the Role Handles This

The `platform_state` role defaults `controller_host` to `gateway_url` since in AAP on OpenShift they're often the same endpoint. You can override if different:

```yaml
# In desired-state.yml or as env vars:
gateway_url: https://aap-gateway.apps.example.com
controller_host: https://aap-controller.apps.example.com  # if different
```

## Resource Coverage

| Resource | Collection | Module | Status |
|----------|-----------|--------|--------|
| Organizations | ansible.platform | organization | ✅ Implemented |
| Teams | ansible.platform | team | ✅ Implemented |
| Users | ansible.platform | user | ✅ Implemented |
| Authenticators | ansible.platform | authenticator | ✅ Implemented |
| Projects | ansible.controller | project | ✅ Implemented |
| Execution Environments | ansible.controller | execution_environment | ✅ Implemented |
| Credentials | ansible.controller | credential | 🔜 Phase 2 |
| Inventories | ansible.controller | inventory | 🔜 Phase 2 |
| Job Templates | ansible.controller | job_template | 🔜 Phase 2 |
| Workflows | ansible.controller | workflow_job_template | 🔜 Phase 2 |
| EDA Activations | ansible.eda | rulebook_activation | 🔜 Phase 2+ |
| Hub Collections | ansible.hub | collection | 🔜 Phase 2+ |

## Adding More Resources

To add a new resource type:

1. **Find the module:**
   ```bash
   podman run --rm quay.io/jhardy/poc-plac:latest ansible-doc -l | grep inventory
   ```

2. **Check parameters:**
   ```bash
   podman run --rm quay.io/jhardy/poc-plac:latest ansible-doc ansible.controller.inventory
   ```

3. **Create task file:**
   ```yaml
   # reconcile/roles/platform_state/tasks/reconcile_inventories.yml
   - name: Ensure inventories exist
     ansible.controller.inventory:
       name: "{{ item.name }}"
       organization: "{{ item.organization }}"
       controller_host: "{{ controller_host }}"
       controller_oauthtoken: "{{ controller_token if controller_token else omit }}"
       state: present
     loop: "{{ platform_state.inventories }}"
   ```

4. **Include in main.yml:**
   ```yaml
   - name: Reconcile Inventories
     ansible.builtin.include_tasks: reconcile_inventories.yml
     when: platform_state.inventories is defined
   ```

5. **Update example file:**
   ```yaml
   inventories:
     - name: Dev Inventory
       organization: Engineering
       description: Development environment inventory
   ```

## Build Notes

- All collections are installed from **Automation Hub** (requires token)
- Collections are pre-release (`--pre` flag) as they track AAP versions
- Total image size: ~1.6 GB (includes all collections + Python deps)
- Build time: ~5-10 minutes (first time; faster with cache)

## Troubleshooting

### Module not found

If you see `couldn't resolve module/action 'ansible.xyz.foo'`:

1. Check collection is in the EE:
   ```bash
   podman run --rm quay.io/jhardy/poc-plac:latest ansible-galaxy collection list | grep ansible.xyz
   ```

2. Check module exists:
   ```bash
   podman run --rm quay.io/jhardy/poc-plac:latest ansible-doc -l | grep ansible.xyz.foo
   ```

3. Check correct parameter names:
   ```bash
   podman run --rm quay.io/jhardy/poc-plac:latest ansible-doc ansible.xyz.foo
   ```

### Authentication failures

- **Gateway modules**: Need `gateway_url` + (`gateway_token` OR `gateway_username`/`gateway_password`)
- **Controller modules**: Need `controller_host` + (`controller_oauthtoken` OR `controller_username`/`controller_password`)
- **Both can point to the same URL** in AAP on OpenShift

### Version mismatches

If modules behave differently than expected, check versions:
```bash
podman run --rm quay.io/jhardy/poc-plac:latest ansible-galaxy collection list
```

AAP 2.5 uses:
- ansible.platform ~2.7
- ansible.controller ~4.6
- ansible.eda ~2.10
- ansible.hub ~1.0
