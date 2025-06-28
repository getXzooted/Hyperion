#!/bin/bash
# master-provisioner.sh
# The Hyperion Provisioning Engine
# Creates a REBOOT_REQUIRED file instead of rebooting itself.

set -e

# --- Configuration & Constants ---
CONFIG_DIR="/etc/hyperion/config"
ENGINE_DIR="/opt/Hyperion"
STATE_DIR="/etc/hyperion/state"
TASK_DIR="${ENGINE_DIR}/provisioner/tasks"
HOSTNAME=$(hostname)
CONFIG_FILE="${CONFIG_DIR}/config-${HOSTNAME}.json"
SERVICES_FILE="${ENGINE_DIR}/configs/services.json"
REBOOT_FLAG_FILE="${STATE_DIR}/REBOOT_REQUIRED"

# --- Logging & State Functions ---
log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: $1"; }
log_error() { echo >&2 "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1"; }
ensure_state_dir() { if [ ! -d "$STATE_DIR" ]; then mkdir -p "$STATE_DIR"; fi; }
check_task_done() { [ -f "${STATE_DIR}/$1.done" ]; }
mark_task_done() { log_info "Marking task '$1' as complete."; touch "${STATE_DIR}/$1.done"; }

# --- Main Engine Logic ---
log_info "--- Hyperion Provisioning Engine Started ---"
ensure_state_dir
if [ ! -f "$CONFIG_FILE" ]; then log_error "Config file not found: ${CONFIG_FILE}"; exit 1; fi
if [ ! -f "$SERVICES_FILE" ]; then log_error "Services manifest not found: ${SERVICES_FILE}"; exit 1; fi
log_info "Starting State Machine..."

# TASK: 01-system-init
if ! check_task_done "01-system-init"; then
    log_info "Executing Task: System Initialization..."
    if bash "${TASK_DIR}/01-system-init.sh"; then mark_task_done "01-system-init"; else log_error "Task 'System Initialization' failed."; exit 1; fi
fi

# TASK: 02-cgroup-fix
if ! check_task_done "02-cgroup-fix"; then
    log_info "Executing Task: Raspberry Pi CGroup Check..."
    bash "${TASK_DIR}/02-cgroup-fix.sh"; TASK_EXIT_CODE=$?
    if [ $TASK_EXIT_CODE -eq 0 ]; then
        log_info "CGroup settings OK."; mark_task_done "02-cgroup-fix"
    elif [ $TASK_EXIT_CODE -eq 10 ]; then
        log_info "CGroup settings applied. Signaling for reboot."; mark_task_done "02-cgroup-fix"
        touch "${REBOOT_FLAG_FILE}" # Set the tripwire
        exit 0
    else log_error "CGroup check task failed."; exit 1; fi
fi

# TASK: 03-k3s-install
if ! check_task_done "03-k3s-install"; then
    log_info "Executing Task: K3s Installation...";
    if bash "${TASK_DIR}/03-k3s-install.sh"; then mark_task_done "03-k3s-install"; else log_error "Task 'K3s Installation' failed."; exit 1; fi
fi

# TASK: 03a-k3s-reboot
if ! check_task_done "03a-k3s-reboot"; then
    log_info "Executing Task: Signaling for K3s Stability Reboot...";
    mark_task_done "03a-k3s-reboot"
    touch "${REBOOT_FLAG_FILE}" # Set the tripwire
    exit 0
fi

# TASK: 04-k3s-networking
if ! check_task_done "04-k3s-networking"; then
    log_info "Executing Task: K3s Networking Deployment...";
    if bash "${TASK_DIR}/04-k3s-networking.sh" "$CONFIG_FILE"; then mark_task_done "04-k3s-networking"; else log_error "Task 'K3s Networking Deployment' failed."; exit 1; fi
fi

log_info "--- Platform Provisioning Steps Complete ---"