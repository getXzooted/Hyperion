#!/bin/bash
# hyperion-engine.sh
# The Hyperion Provisioning Engine


set -e


# --- Configuration & Constants ---
STATE_DIR="/etc/hyperion/state"
COMPONENTS_DIR="/opt/Hyperion/components"
CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
UNATTENDED_REBOOT=false
export NEEDS_REBOOT="false"


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

run_core_tasks() {
    if [ ! -d "$CORE_TASK_DIR" ]; then return; fi

    for SCRIPT_PATH in $(ls -v ${CORE_TASK_DIR}/*.sh); do
        local SCRIPT_NAME=$(basename "$SCRIPT_PATH")
        local STATE_NAME=${SCRIPT_NAME%.sh}

        if ! check_task_done "$STATE_NAME"; then
            log_info "--> Running Core Task: ${SCRIPT_NAME}"

            sudo bash "$SCRIPT_PATH" || local TASK_EXIT_CODE=$?
            mark_task_done "$STATE_NAME"

            # If a script exits with 10, it signals a required reboot.
            if [[ "${TASK_EXIT_CODE}" -eq 10 ]]; then
                UNATTENDED_REBOOT=$(jq -r '.parameters.reboot_unattended' "$CONFIG_FILE")
                if [ "$UNATTENDED_REBOOT" = true ]; then
                    log_warn "--> Task '${SCRIPT_NAME}' requires reboot. Rebooting automatically in 10 seconds..."
                    sleep 10
                    sudo reboot
                else
                    log_warn "--> ACTION REQUIRED: Task '${SCRIPT_NAME}' requires a reboot. Please run 'sudo reboot' now."
                    # We stop the service cleanly to allow manual reboot.
                    sudo systemctl stop hyperion.service
                fi
                exit 0
            fi
        fi
    done
}

# --- Main Execution ---
sudo mkdir -p "$STATE_DIR"
log_info "--- Hyperion Forged Provisioning Engine Started ---"
if [ ! -f "$CONFIG_FILE" ]; then log_error "Config file not found: ${CONFIG_FILE}"; exit 1; fi

# 1. Run all mandatory core tasks in their specified order
run_core_tasks

# 2. Future logic for optional, GitOps-managed services will go here



if [ "$NEEDS_REBOOT" = "true" ]; then
   if [ "$UNATTENDED_REBOOT" = true ]; then
      echo "--> Provisioner has requested a reboot. REBOOTING NOW..."
      sleep 5
      reboot
      exit 0
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
    sudo systemctl disable hyperion.service
    log_info "Provisioning service has been disabled."
fi