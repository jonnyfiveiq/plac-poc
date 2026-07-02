.PHONY: help ee-build ee-push ee-login plan apply diff validate test-dry-run clean

# Load environment variables from .env if it exists
-include .env
export

# Default values (override in .env)
IMAGE_NAME ?= quay.io/jhardy/poc-plac
IMAGE_TAG ?= latest
IMAGE_FULL := $(IMAGE_NAME):$(IMAGE_TAG)
REGISTRY_USERNAME ?= jhardy+bob
REGISTRY_PASSWORD ?=

# AAP connection (for testing)
AAP_GATEWAY_URL ?=
AAP_TOKEN ?=
AAP_USERNAME ?=
AAP_PASSWORD ?=

# Files
STATE_FILE ?= $(PWD)/examples/desired-state.example.yml
CONTEXT_DIR := execution-environment/context

help:
	@echo "AAP Platform Lifecycle as Code - Makefile"
	@echo ""
	@echo "Phase 1 Targets:"
	@echo "  ee-build          Build the Execution Environment image"
	@echo "  ee-push           Push the EE image to registry (requires ee-login first)"
	@echo "  ee-login          Login to container registry"
	@echo "  plan              Run in check mode (show what would change)"
	@echo "  apply             Apply desired state to AAP"
	@echo "  diff              Show detailed diff of pending changes"
	@echo "  validate          Validate desired state file syntax"
	@echo "  test-dry-run      Test the EE in dry-run mode (no AAP required)"
	@echo "  clean             Remove build artifacts"
	@echo ""
	@echo "Configuration:"
	@echo "  Copy .env.example to .env and fill in your values"
	@echo "  Or set environment variables:"
	@echo "    - ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN"
	@echo "    - REGISTRY_PASSWORD"
	@echo "    - AAP_GATEWAY_URL, AAP_TOKEN (or AAP_USERNAME/AAP_PASSWORD)"

check-builder:
	@command -v ansible-builder >/dev/null 2>&1 || { \
		echo "ERROR: ansible-builder not found. Install with: pip install ansible-builder"; \
		exit 1; \
	}

check-podman:
	@command -v podman >/dev/null 2>&1 || { \
		echo "ERROR: podman not found. Install podman for macOS"; \
		exit 1; \
	}

check-hub-token:
	@if [ -z "$$ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN" ]; then \
		echo "ERROR: ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN not set"; \
		echo "Get a token from https://console.redhat.com/ansible/automation-hub/token"; \
		exit 1; \
	fi

ee-build: check-builder check-podman check-hub-token
	@echo "==> Building Execution Environment: $(IMAGE_FULL)"
	cd execution-environment && \
		ANSIBLE_BUILDER_IGNORE_INTROSPECT_ERRORS=1 ansible-builder build \
			--tag=$(IMAGE_FULL) \
			--container-runtime=podman \
			--build-arg PKGMGR_PRESERVE_CACHE=never \
			--build-arg ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN="$(ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN)" \
			--verbosity=3
	@echo "==> Build complete: $(IMAGE_FULL)"

ee-login: check-podman
	@if [ -z "$(REGISTRY_PASSWORD)" ]; then \
		echo "ERROR: REGISTRY_PASSWORD not set in .env"; \
		exit 1; \
	fi
	@echo "==> Logging in to registry..."
	@echo "$(REGISTRY_PASSWORD)" | podman login $(REGISTRY_URL) -u "$(REGISTRY_USERNAME)" --password-stdin
	@echo "==> Logged in successfully"

ee-push: check-podman
	@echo "==> Pushing $(IMAGE_FULL) to registry"
	podman push $(IMAGE_FULL)
	@echo "==> Push complete"

plan: check-podman
	@if [ ! -f "$(STATE_FILE)" ]; then \
		echo "ERROR: State file not found: $(STATE_FILE)"; \
		exit 1; \
	fi
	@echo "==> Running PLAN (check mode) against AAP"
	podman run --rm \
		--entrypoint=/runner/reconcile/entrypoint.sh \
		-v $(STATE_FILE):/state/desired-state.yml:ro \
		-e AAP_GATEWAY_URL="$(AAP_GATEWAY_URL)" \
		-e AAP_TOKEN="$(AAP_TOKEN)" \
		-e AAP_USERNAME="$(AAP_USERNAME)" \
		-e AAP_PASSWORD="$(AAP_PASSWORD)" \
		$(IMAGE_FULL) plan

apply: check-podman
	@if [ ! -f "$(STATE_FILE)" ]; then \
		echo "ERROR: State file not found: $(STATE_FILE)"; \
		exit 1; \
	fi
	@echo "==> Running APPLY against AAP"
	podman run --rm \
		--entrypoint=/runner/reconcile/entrypoint.sh \
		-v $(STATE_FILE):/state/desired-state.yml:ro \
		-e AAP_GATEWAY_URL="$(AAP_GATEWAY_URL)" \
		-e AAP_TOKEN="$(AAP_TOKEN)" \
		-e AAP_USERNAME="$(AAP_USERNAME)" \
		-e AAP_PASSWORD="$(AAP_PASSWORD)" \
		$(IMAGE_FULL) apply

diff: check-podman
	@if [ ! -f "$(STATE_FILE)" ]; then \
		echo "ERROR: State file not found: $(STATE_FILE)"; \
		exit 1; \
	fi
	@echo "==> Running DIFF (check mode with diff) against AAP"
	podman run --rm \
		--entrypoint=/runner/reconcile/entrypoint.sh \
		-v $(STATE_FILE):/state/desired-state.yml:ro \
		-e AAP_GATEWAY_URL="$(AAP_GATEWAY_URL)" \
		-e AAP_TOKEN="$(AAP_TOKEN)" \
		-e AAP_USERNAME="$(AAP_USERNAME)" \
		-e AAP_PASSWORD="$(AAP_PASSWORD)" \
		$(IMAGE_FULL) diff

validate: check-podman
	@if [ ! -f "$(STATE_FILE)" ]; then \
		echo "ERROR: State file not found: $(STATE_FILE)"; \
		exit 1; \
	fi
	@echo "==> Validating desired state file"
	podman run --rm \
		--entrypoint=/runner/reconcile/entrypoint.sh \
		-v $(STATE_FILE):/state/desired-state.yml:ro \
		$(IMAGE_FULL) validate

test-dry-run: check-podman
	@echo "==> Testing EE in DRY RUN mode (no AAP required)"
	@echo "This simulates what would happen without making actual API calls"
	podman run --rm \
		--entrypoint=/runner/reconcile/entrypoint.sh \
		-v $(STATE_FILE):/state/desired-state.yml:ro \
		-e DRY_RUN=true \
		-e AAP_GATEWAY_URL="https://fake.example.com" \
		-e AAP_TOKEN="fake-token-for-dry-run" \
		$(IMAGE_FULL) apply

clean:
	@echo "==> Cleaning build artifacts"
	rm -rf $(CONTEXT_DIR)
	@echo "==> Clean complete"
