#!/bin/bash
#
# master-provisioner.sh
# The Hyperion Provisioning Engine
# Reads configuration, manages state, and calls task scripts.

set -e

# --- Configuration & Constants ---
CONFIG_DIR="/etc/hyperion/config"
ENGINE_DIR="/opt/Hyperion"
STATE_DIR="/etc/hyperion/state"
TASK_DIR="${ENGINE_DIR}/provisioner/tasks"
HOSTNAME=$(hostname)
CONFIG_FILE="${CONFIG_DIR}/config-${HOSTNAME}.json"
SERVICES_FILE="${ENGINE_DIR}/configs/services.json"
UNATTENDED_REBOOT=false # Default value

# --- Logging Function ---
log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: $1"; }
log_error() { echo >&2 "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1"; }
log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') - WARN: $1"; }

# --- State Management Functions ---
ensure_state_dir() {
    if [ ! -d "$STATE_DIR" ]; then
        log_info "Creating state directory at ${STATE_DIR}..."
        mkdir -p "$STATE_DIR"
    fi
}
check_task_done() { [ -f "${STATE_DIR}/$1.done" ]; }
mark_task_done() {
    log_info "Marking task '$1' as complete."
    touch "${STATE_DIR}/$1.done"
}

# --- Main Engine Logic ---
log_info "--- Hyperion Provisioning Engine Started ---"

# 1. Parse Command Line Flags (e.g., -y for auto-reboot)
if [ "$1" == "-y" ]; then
    log_info "'-y' flag detected. Will not prompt for reboot."
    UNATTENDED_REBOOT=true
fi

# 2. Ensure state directory exists
ensure_state_dir

# 3. Check for existence of config files
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Configuration file not found at ${CONFIG_FILE}! Exiting."
    exit 1
fi
if [ ! -f "$SERVICES_FILE" ]; then
    log_error "Services manifest not found at ${SERVICES_FILE}! Exiting."
    exit 1
fi

# 4. Load reboot policy from config file, allowing CLI flag to override
CONFIG_REBOOT_POLICY=$(jq -r '.parameters.reboot_unattended' "$CONFIG_FILE")
if [ "$UNATTENDED_REBOOT" = false ] && [ "$CONFIG_REBOOT_POLICY" = true ]; then
    log_info "Unattended reboot enabled by config file."
    UNATTENDED_REBOOT=true
fi

# 5. --- STATE MACHINE ---
log_info "Starting State Machine..."

# TASK: 01-system-init
if ! check_task_done "01-system-init"; then
    log_info "Executing Task: System Initialization..."
    if bash "${TASK_DIR}/01-system-init.sh"; then
        mark_task_done "01-system-init"
    else
        log_error "Task 'System Initialization' failed. Exiting."; exit 1
    fi
fi

# TASK: 02-cgroup-fix
if ! check_task_done "02-cgroup-fix"; then
    log_info "Executing Task: Raspberry Pi CGroup Check..."
    bash "${TASK_DIR}/02-cgroup-fix.sh"
    TASK_EXIT_CODE=$?
    if [ $TASK_EXIT_CODE -eq 0 ]; then
        log_info "CGroup settings OK. No reboot needed."
        mark_task_done "02-cgroup-fix"
    elif [ $TASK_EXIT_CODE -eq 10 ]; then
        log_info "CGroup settings were applied. Reboot is required."
        mark_task_done "02-cgroup-fix"
        if [ "$UNATTENDED_REBOOT" = true ]; then
            log_warn "Instructing systemd to reboot now for cgroup changes..."
            systemctl reboot
        else
            log_warn "Please reboot the system manually ('sudo reboot') to continue provisioning."
        fi
        exit 0
    else
        log_error "CGroup check task failed unexpectedly. Exiting."; exit 1
    fi
fi

# TASK: 03-k3s-install
if ! check_task_done "03-k3s-install"; then
    log_info "Executing Task: K3s Installation..."
    if bash "${TASK_DIR}/03-k3s-install.sh"; then
        mark_task_done "03-k3s-install"
    else
        log_error "Task 'K3s Installation' failed."; exit 1
    fi
fi

# TASK: 03a-k3s-reboot (Logic is now inside the master script)
if ! check_task_done "03a-k3s-reboot"; then
    log_info "Executing Task: Forcing K3s Stability Reboot..."
    log_info "K3s has been installed. A reboot is required to ensure stability."
    mark_task_done "03a-k3s-reboot"
    if [ "$UNATTENDED_REBOOT" = true ]; then
        log_warn "Instructing systemd to reboot now for K3s stability..."
        systemctl reboot
    else
        log_warn "Please reboot the system manually ('sudo reboot') to continue provisioning."
    fi
    exit 0
fi

# TASK: 04-k3s-networking
if ! check_task_done "04-k3s-networking"; then
    log_info "Executing Task: K3s Networking Deployment..."
    if bash "${TASK_DIR}/04-k3s-networking.sh" "$CONFIG_FILE"; then
        mark_task_done "04-k3s-networking"
    else
        log_error "Task 'K3s Networking Deployment' failed."; exit 1
    fi
fi

log_info "--- Platform Provisioning Steps Complete ---"