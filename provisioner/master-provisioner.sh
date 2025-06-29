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
    sudo bash "${TASK_DIR}/02-cgroup-fix.sh"
    TASK_EXIT_CODE=$?
    mark_task_done "02-cgroup-fix" # Mark as done regardless of exit code
    if [ $TASK_EXIT_CODE -eq 10 ]; then
        if [ "$UNATTENDED_REBOOT" = true ]; then
            log_warn "CRITICAL: Rebooting for cgroup changes..."
            log_info "Waiting for systemd-logind to be ready..."
            until systemctl is-active systemd-logind.service >/dev/null 2>&1; do sleep 2; done
            sleep 5
            sudo /bin/systemctl reboot
        else
            log_warn "CRITICAL: Please reboot manually for cgroup changes."
        fi
        exit 1
    fi
fi

# TASK: 03-k3s-install
if ! check_task_done "03-k3s-install"; then
    log_info "Executing Task 03: K3s Installation..."
    sudo bash "${TASK_DIR}/03-k3s-install.sh"
    mark_task_done "03-k3s-install"

    if [ "$UNATTENDED_REBOOT" = true ]; then
        log_warn "CRITICAL: Rebooting for K3s stability..."
        log_info "Waiting for systemd-logind to be ready..."
        until systemctl is-active systemd-logind.service >/dev/null 2>&1; do sleep 2; done
        sleep 5
        sudo /bin/systemctl reboot
    else
        log_warn "CRITICAL: Please reboot manually for K3s stability."
    fi
    exit 1

fi

# TASK: 04-k3s-networking
if ! check_task_done "04-k3s-networking"; then
    bash "${TASK_DIR}/04-k3s-networking.sh" "$CONFIG_FILE"; mark_task_done "04-k3s-networking"
fi

log_info "--- Platform Provisioning Steps Complete ---"