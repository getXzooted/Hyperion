#!/bin/bash
# hyperion-engine.sh
# The Hyperion Provisioning Engine


set -e


# --- Configuration & Constants ---
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
# Read the base config for a stable k3s environment
PROVISION_LIST=$(jq -c '.provision_list[]' "$CONFIG_FILE")
if [ -z "$PROVISION_LIST" ]; then
    log_error "The 'provision_list' in your config file is empty or missing."
    exit 1
fi

# This is the main dependency resolution loop.
# It will continue to loop until all components in the list are marked as .done
while true; do
    ALL_COMPONENTS_DONE=true
    PROGRESS_MADE_THIS_LOOP=false

    while IFS= read -r COMPONENT_NAME; do
        COMPONENT_NAME=$(echo "$COMPONENT_NAME" | tr -d '"') # Clean the name from jq output
        MANIFEST_FILE="${COMPONENTS_DIR}/${COMPONENT_NAME}/component.json"

        if ! check_task_done "$COMPONENT_NAME"; then
            ALL_COMPONENTS_DONE=false # At least one component is not done
            ALL_DEPS_MET=true
            
            for DEP in $(jq -c '.dependencies[]' "$MANIFEST_FILE" | tr -d '"'); do
                if ! check_task_done "$DEP"; then
                    ALL_DEPS_MET=false
                    break # A dependency is not met, no need to check others
                fi
            done

            if [ "$ALL_DEPS_MET" = true ]; then
                log_info "--> Provisioning component: ${COMPONENT_NAME}"
                INSTALL_SCRIPT=$(jq -r '.provisions.install' "$MANIFEST_FILE")
                REBOOT_AFTER=$(jq -r '.provisions.reboot_after' "$MANIFEST_FILE")

                sudo GITHUB_USER="$GITHUB_USER" GITHUB_TOKEN="$GITHUB_TOKEN" bash "${COMPONENTS_DIR}/${COMPONENT_NAME}/${INSTALL_SCRIPT}" || TASK_EXIT_CODE=$?
                # ONLY if the task succeeded, mark it as done and record progress
               if [[ -z "$TASK_EXIT_CODE" || "$TASK_EXIT_CODE" -eq 0 ]]; then
                    # Case 1: The script succeeded (exit code 0).
                    mark_task_done "$COMPONENT_NAME"
                    PROGRESS_MADE_THIS_LOOP=true
                elif [[ "$TASK_EXIT_CODE" -eq 10 ]]; then
                    # Case 2: The script requested a reboot (exit code 10).
                    UNATTENDED_REBOOT=$(jq -r '.parameters.reboot_unattended' "$CONFIG_FILE")
                    if [ "$UNATTENDED_REBOOT" = true ]; then
                        log_warn "--> Task '${COMPONENT_NAME}' requires reboot. Rebooting automatically..."
                        sleep 10
                        sudo reboot
                    else
                        log_warn "--> ACTION REQUIRED: Task '${COMPONENT_NAME}' requires a reboot."
                        sudo systemctl stop hyperion.service # Stop cleanly
                    fi
                    # Exit the engine immediately since a reboot is pending.
                    exit 0
                else
                    # Case 3: The script failed with a different error (e.g., exit code 1).
                    log_error "Task '${COMPONENT_NAME}' failed with a fatal error (Exit Code: ${TASK_EXIT_CODE})."
                    log_error "Halting the provisioning engine."
                    # Exit the engine with a failure code to prevent further loops.
                    exit 1
                fi

            fi
        fi
    done <<< "$PROVISION_LIST"

    # If we are finished, break the main loop
    if [ "$ALL_COMPONENTS_DONE" = true ]; then
        break
    fi

    # If we went through a whole loop without making progress, there is a dependency deadlock
    if [ "$PROGRESS_MADE_THIS_LOOP" = false ]; then
        log_error "Stalled due to unmet or circular dependencies. Please check your config."
        exit 1
    fi
done

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
    touch "/etc/hyperion/state/base_platform_complete.done"
fi