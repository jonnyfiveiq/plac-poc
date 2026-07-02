#!/bin/bash
# Verify Phase 1 setup and prerequisites

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

echo -e "${BLUE}======================================"
echo "AAP Platform Lifecycle - Setup Verification"
echo "======================================${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Check tools
echo -e "${BLUE}[1/5] Checking required tools...${NC}"

if command -v podman &> /dev/null; then
    PODMAN_VERSION=$(podman --version | cut -d' ' -f3)
    echo -e "${GREEN}✓ podman${NC} (version ${PODMAN_VERSION})"
else
    echo -e "${RED}✗ podman not found${NC}"
    echo "  Install: brew install podman"
    ((ERRORS++))
fi

if command -v ansible-builder &> /dev/null; then
    BUILDER_VERSION=$(ansible-builder --version 2>&1 | head -n1 | awk '{print $2}')
    echo -e "${GREEN}✓ ansible-builder${NC} (version ${BUILDER_VERSION})"
else
    echo -e "${RED}✗ ansible-builder not found${NC}"
    echo "  Install: pip3 install ansible-builder"
    ((ERRORS++))
fi

if command -v ansible-navigator &> /dev/null; then
    echo -e "${GREEN}✓ ansible-navigator${NC}"
else
    echo -e "${YELLOW}⚠ ansible-navigator not found (optional)${NC}"
    echo "  Install: pip3 install ansible-navigator"
    ((WARNINGS++))
fi

echo ""

# Check podman machine
echo -e "${BLUE}[2/5] Checking podman machine...${NC}"

if podman machine list 2>/dev/null | grep -q "running"; then
    echo -e "${GREEN}✓ podman machine is running${NC}"
elif podman machine list 2>/dev/null | grep -q "Currently running"; then
    echo -e "${GREEN}✓ podman machine is running${NC}"
else
    echo -e "${YELLOW}⚠ podman machine not running${NC}"
    echo "  Start: podman machine start"
    echo "  Or init: podman machine init && podman machine start"
    ((WARNINGS++))
fi

echo ""

# Check .env file
echo -e "${BLUE}[3/5] Checking configuration (.env)...${NC}"

if [[ -f .env ]]; then
    echo -e "${GREEN}✓ .env file exists${NC}"

    # Source it
    source .env 2>/dev/null || true

    # Check key variables
    if [[ -n "${ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN:-}" ]]; then
        echo -e "${GREEN}✓ ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN set${NC}"
    else
        echo -e "${RED}✗ ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN not set${NC}"
        echo "  Get token from: https://console.redhat.com/ansible/automation-hub/token"
        ((ERRORS++))
    fi

    if [[ -n "${REGISTRY_PASSWORD:-}" ]]; then
        echo -e "${GREEN}✓ REGISTRY_PASSWORD set${NC}"
    else
        echo -e "${YELLOW}⚠ REGISTRY_PASSWORD not set${NC}"
        echo "  Use provided robot token in .env.example"
        ((WARNINGS++))
    fi

    if [[ -n "${AAP_GATEWAY_URL:-}" ]]; then
        echo -e "${GREEN}✓ AAP_GATEWAY_URL set${NC}"
    else
        echo -e "${YELLOW}⚠ AAP_GATEWAY_URL not set${NC}"
        echo "  Required for testing against real AAP"
        ((WARNINGS++))
    fi

    if [[ -n "${AAP_TOKEN:-}" ]] || [[ -n "${AAP_USERNAME:-}" ]]; then
        echo -e "${GREEN}✓ AAP auth configured${NC}"
    else
        echo -e "${YELLOW}⚠ AAP authentication not configured${NC}"
        echo "  Set AAP_TOKEN or AAP_USERNAME/AAP_PASSWORD"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗ .env file not found${NC}"
    echo "  Create: cp .env.example .env"
    echo "  Then edit .env with your credentials"
    ((ERRORS++))
fi

echo ""

# Check repository structure
echo -e "${BLUE}[4/5] Checking repository structure...${NC}"

REQUIRED_DIRS=(
    "execution-environment"
    "reconcile"
    "reconcile/roles/platform_state"
    "examples"
    "docs"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}✓ $dir/${NC}"
    else
        echo -e "${RED}✗ $dir/ missing${NC}"
        ((ERRORS++))
    fi
done

REQUIRED_FILES=(
    "execution-environment/execution-environment.yml"
    "reconcile/entrypoint.sh"
    "reconcile/playbooks/reconcile.yml"
    "examples/desired-state.example.yml"
    "Makefile"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ $file${NC}"
    else
        echo -e "${RED}✗ $file missing${NC}"
        ((ERRORS++))
    fi
done

echo ""

# Check file permissions
echo -e "${BLUE}[5/5] Checking file permissions...${NC}"

if [[ -x reconcile/entrypoint.sh ]]; then
    echo -e "${GREEN}✓ reconcile/entrypoint.sh is executable${NC}"
else
    echo -e "${YELLOW}⚠ reconcile/entrypoint.sh not executable${NC}"
    chmod +x reconcile/entrypoint.sh
    echo "  Fixed: chmod +x reconcile/entrypoint.sh"
fi

if [[ -x test-phase1.sh ]]; then
    echo -e "${GREEN}✓ test-phase1.sh is executable${NC}"
else
    echo -e "${YELLOW}⚠ test-phase1.sh not executable${NC}"
    chmod +x test-phase1.sh
    echo "  Fixed: chmod +x test-phase1.sh"
fi

echo ""
echo -e "${BLUE}======================================"
echo "Summary"
echo "======================================${NC}"

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ No errors found${NC}"
else
    echo -e "${RED}✗ $ERRORS error(s) found - must fix before building${NC}"
fi

if [[ $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ No warnings${NC}"
else
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) - may affect functionality${NC}"
fi

echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}You're ready to build!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. make ee-build          # Build the execution environment"
    echo "  2. make test-dry-run      # Test without AAP"
    echo "  3. make validate          # Validate example file"
    echo ""
    if [[ $WARNINGS -gt 0 ]]; then
        echo "Note: Warnings above are optional but recommended for full testing"
    fi
    exit 0
else
    echo -e "${RED}Please fix the errors above before proceeding${NC}"
    exit 1
fi
