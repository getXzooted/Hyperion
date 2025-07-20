#!/bin/bash
# hyperion-engine.sh
# The Hyperion Provisioning Engine


set -e


# --- Configuration & Constants ---
BASE_PLATFORM_COMPLETE="/etc/hyperion/state/base_platform_complete.done"
COMPONENTS_ENGINE="opt/Hyperion/provisioner/components-engine.sh"
CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"
STATE_DIR="/etc/hyperion/state"
COMPONENTS_DIR="/opt/Hyperion/components"
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


# --- Components Engine Call ---
sudo -E bash "$COMPONENTS_ENGINE"

# --- Reboot Logic ---
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
    log_info "--- BASE PROVISIONING COMPLETE YOU CAN NOW MOVE TO DEPLOYMENT ---"
    log_info "--- USE SUDO HYPERION TO PROMPT GIT INPUT FOR PRIVATE CONFIGS ---"
    touch "$BASE_PLATFORM_COMPLETE"
fi