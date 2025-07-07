#!/bin/bash
# master-provisioner.sh
# The Hyperion Provisioning Engine

set -e

# --- Configuration & Constants ---
CONFIG_DIR="/etc/hyperion/config"
ENGINE_DIR="/opt/Hyperion"
STATE_DIR="/etc/hyperion/state"
TASK_DIR="${ENGINE_DIR}/provisioner/tasks"
HOSTNAME=$(hostname)
CONFIG_FILE="${CONFIG_DIR}/config-${HOSTNAME}.json"
SERVICES_FILE="${ENGINE_DIR}/configs/services.json"
UNATTENDED_REBOOT=false

# --- Logging & State Functions (collapsed for brevity) ---
log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: $1"; }
log_error() { echo >&2 "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1"; }
log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') - WARN: $1"; }
ensure_state_dir() { if [ ! -d "$STATE_DIR" ]; then mkdir -p "$STATE_DIR"; fi; }
check_task_done() { [ -f "${STATE_DIR}/$1.done" ]; }
mark_task_done() { log_info "Marking task '$1' as complete."; touch "${STATE_DIR}/$1.done"; }

# --- Variables ---
export NEEDS_REBOOT="false"

# --- Main Engine Logic ---
log_info "--- Hyperion Provisioning Engine Started ---"
if [ "$1" == "-y" ]; then UNATTENDED_REBOOT=true; fi
ensure_state_dir
if [ ! -f "$CONFIG_FILE" ]; then log_error "Config not found: ${CONFIG_FILE}"; exit 1; fi
CONFIG_REBOOT_POLICY=$(jq -r '.parameters.reboot_unattended' "$CONFIG_FILE")
if [ "$UNATTENDED_REBOOT" = false ] && [ "$CONFIG_REBOOT_POLICY" = true ]; then UNATTENDED_REBOOT=true; fi

log_info "Starting State Machine..."

# TASK: 01-system-init
if ! check_task_done "01-system-init"; then
    bash "${TASK_DIR}/01-system-init.sh"; mark_task_done "01-system-init"
fi

# TASK: 02-cgroup-fix
if ! check_task_done "02-cgroup-fix"; then
    log_info "Executing Task 02: CGroup Fix..."
    # Run the cgroup fix script and capture its exit code.
    sudo bash "${TASK_DIR}/02-cgroup-fix.sh" ||  TASK_EXIT_CODE=$?

    # If the exit code is 10, it means a reboot is required.
    if [ "${TASK_EXIT_CODE}" -eq 10 ]; then
        log_warn "Flagging that a reboot is now required for cgroup changes."
        NEEDS_REBOOT="true"
    fi
    mark_task_done "02-cgroup-fix"
fi

# TASK: 03-k3s-install
if ! check_task_done "03-k3s-install"; then
    if [ "$NEEDS_REBOOT" = "false" ]; then
        log_info "Executing Task 03: K3s Installation..."
        sudo bash "${TASK_DIR}/03-k3s-install.sh"
        mark_task_done "03-k3s-install"
        log_warn "Flagging that a reboot is now required for K3s stability."
        NEEDS_REBOOT="true"
    else
        log_warn "Skipping Task 03: A reboot is required from a previous step."
    fi
fi

# TASK: 04-k3s-networking
if ! check_task_done "04-k3s-networking"; then
    if [ "$NEEDS_REBOOT" = "false" ]; then
        log_info "Executing Task 04: K3s Networking Deployment..."
        sudo bash "${TASK_DIR}/04-k3s-networking.sh"
        mark_task_done "04-k3s-networking"
    else
        log_warn "Skipping Task 04: A reboot is required from a previous step."
    fi
fi


if [ "$NEEDS_REBOOT" = "true" ]; then
   if [ "$UNATTENDED_REBOOT" = true ]; then
      touch /etc/hyperion/state/REBOOT_REQUIRED
   else
       log_warn "--------------------------------------------------------"
       log_warn "          ACTION REQUIRED: A reboot is needed.          "
       log_warn "            Please run 'sudo reboot' now.               "
       log_warn "            The provisioning service will               "
       log_warn "          continue automatically after reboot.          "
       log_warn "--------------------------------------------------------"
   fi
else
    log_info "--- ALL PROVISIONING COMPLETE ---"
    sudo systemctl disable pi-provisioner.service
    log_info "Provisioning service has been disabled."
fi