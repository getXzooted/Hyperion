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

if [ "$UNATTENDED_REBOOT" = true ]; then
    log_warn "cgroup fix applied. Forcing immediate reboot now..."
    /usr/sbin/reboot -f
else
    log_warn "cgroup fix applied. Please reboot manually ('sudo reboot')."
fi

# TASK: 02-cgroup-fix
if ! check_task_done "02-cgroup-fix"; then
    log_info "Executing Task 02: CGroup Fix..."
    # We run the task and use || true to prevent the master script from exiting
    # if the task script returns a non-zero code (like 10).
    sudo bash "${TASK_DIR}/02-cgroup-fix.sh" || true 
    TASK_EXIT_CODE=$?
    mark_task_done "02-cgroup-fix"

    # Now, we check the exit code. If it was 10, we print the message and exit.
    if [ $TASK_EXIT_CODE -eq 10 ]; then
        log_warn "CRITICAL: A reboot is required to apply cgroup changes."
        log_warn "Please run 'sudo reboot' now, then after it comes back online, re-run this script manually:"
        log_warn "sudo bash /usr/local/bin/master-provisioner.sh"
        exit 0 # Stop execution and wait for the manual reboot.
    fi
fi


# TASK: 03-k3s-install
if ! check_task_done "03-k3s-install"; then
    log_info "Executing Task 03: K3s Installation..."
    # Run the installation script
    sudo bash "${TASK_DIR}/03-k3s-install.sh"
    mark_task_done "03-k3s-install"

    # Now, stop and tell the user to reboot for stability.
    log_warn "CRITICAL: A reboot is required to stabilize the K3s service."
    log_warn "Please run 'sudo reboot' now, then after it comes back online, re-run this script manually:"
    log_warn "sudo bash /usr/local/bin/master-provisioner.sh"
    exit 0 # Stop execution and wait for the manual reboot.
fi


# TASK: 04-k3s-networking
if ! check_task_done "04-k3s-networking"; then
    bash "${TASK_DIR}/04-k3s-networking.sh" "$CONFIG_FILE"; mark_task_done "04-k3s-networking"
fi

log_info "--- Platform Provisioning Steps Complete ---"