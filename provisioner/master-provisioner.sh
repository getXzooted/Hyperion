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

# TASK: 02-cgroup-fix
if ! check_task_done "02-cgroup-fix"; then
    bash "${TASK_DIR}/02-cgroup-fix.sh"; TASK_EXIT_CODE=$?
    if [ $TASK_EXIT_CODE -eq 10 ]; then
        mark_task_done "02-cgroup-fix"
        if [ "$UNATTENDED_REBOOT" = true ]; then log_warn "cgroup fix applied. Instructing systemd to reboot..."; systemctl reboot; else log_warn "cgroup fix applied. Please reboot manually."; fi
        exit 0
    fi
    mark_task_done "02-cgroup-fix"
fi

# TASK: 03-k3s-install
if ! check_task_done "03-k3s-install"; then
    bash "${TASK_DIR}/03-k3s-install.sh"; mark_task_done "03-k3s-install"
fi

# TASK: 03a-k3s-reboot
if ! check_task_done "03a-k3s-reboot"; then
    mark_task_done "03a-k3s-reboot"
    if [ "$UNATTENDED_REBOOT" = true ]; then log_warn "K3s installed. Instructing systemd to reboot for stability..."; systemctl reboot; else log_warn "K3s installed. Please reboot manually for stability."; fi
    exit 0
fi

# TASK: 04-k3s-networking
if ! check_task_done "04-k3s-networking"; then
    bash "${TASK_DIR}/04-k3s-networking.sh" "$CONFIG_FILE"; mark_task_done "04-k3s-networking"
fi

log_info "--- Platform Provisioning Steps Complete ---"