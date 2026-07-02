#!/bin/bash
set -euo pipefail

# AAP Platform Lifecycle EE - Entrypoint
# Supports file-based and CR-based desired state

VERB="${1:-apply}"
STATE_FILE="${STATE_FILE:-/state/desired-state.yml}"
CHECK_MODE=""
DIFF_MODE=""

# Dual-mode: file vs CR
if [[ -n "${CR_NAME:-}" ]]; then
  echo "==> CR mode: fetching spec from PlatformState ${CR_NAMESPACE:-default}/${CR_NAME}"
  if ! command -v oc &> /dev/null; then
    echo "ERROR: oc CLI not found. CR mode requires oc binary in container." >&2
    exit 1
  fi

  # Extract .spec from CR and write to temp file
  STATE_FILE="/tmp/cr-desired-state.yml"
  oc get platformstate "${CR_NAME}" -n "${CR_NAMESPACE:-default}" -o jsonpath='{.spec}' > "${STATE_FILE}"

  if [[ ! -s "${STATE_FILE}" ]]; then
    echo "ERROR: Failed to fetch CR spec or CR is empty" >&2
    exit 1
  fi
  echo "==> CR spec extracted to ${STATE_FILE}"
else
  echo "==> File mode: using ${STATE_FILE}"
  if [[ ! -f "${STATE_FILE}" ]]; then
    echo "ERROR: Desired state file not found: ${STATE_FILE}" >&2
    echo "Mount a file at ${STATE_FILE} or set STATE_FILE env var" >&2
    exit 1
  fi
fi

# Validate authentication
if [[ -z "${AAP_GATEWAY_URL:-}" ]]; then
  echo "ERROR: AAP_GATEWAY_URL environment variable required" >&2
  exit 1
fi

if [[ -z "${AAP_TOKEN:-}" ]] && [[ -z "${AAP_USERNAME:-}" ]]; then
  echo "ERROR: Either AAP_TOKEN or AAP_USERNAME/AAP_PASSWORD required" >&2
  exit 1
fi

# Handle verbs
case "${VERB}" in
  plan)
    echo "==> Running in CHECK mode (plan)"
    CHECK_MODE="--check"
    ;;
  diff)
    echo "==> Running in CHECK mode with DIFF (diff)"
    CHECK_MODE="--check"
    DIFF_MODE="--diff"
    ;;
  apply)
    echo "==> Running in APPLY mode (apply)"
    ;;
  validate)
    echo "==> Validating desired state schema"
    # Schema validation will be added in Phase 2
    python3 /runner/reconcile/validate_schema.py "${STATE_FILE}"
    exit $?
    ;;
  *)
    echo "ERROR: Unknown verb '${VERB}'. Valid: plan, apply, diff, validate" >&2
    exit 1
    ;;
esac

# Run the reconcile playbook
echo "==> Executing reconcile playbook"
exec ansible-playbook \
  ${CHECK_MODE} \
  ${DIFF_MODE} \
  -e "desired_state_file=${STATE_FILE}" \
  -e "aap_gateway_url=${AAP_GATEWAY_URL}" \
  -e "aap_token=${AAP_TOKEN:-}" \
  -e "aap_username=${AAP_USERNAME:-}" \
  -e "aap_password=${AAP_PASSWORD:-}" \
  /runner/reconcile/playbooks/reconcile.yml
