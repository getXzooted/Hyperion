#!/bin/bash
# component-configs.sh (The "Customizer" Engine)


set -e


COMPONENTS_DIR="/opt/Hyperion/components"
CONFIG_FILE="/etc/hyperion/config/config-$(hostname).json"

echo "--- Hyperion Customization Engine Started ---"

# Read the user's provision list to know which configs to apply
PROVISION_LIST=$(jq -r '.provision_list[]' "$CONFIG_FILE")

for component in $PROVISION_LIST; do
    CONFIG_SCRIPT_PATH="${COMPONENTS_DIR}/${component}/scripts/apply-configs.sh"
    if [ -f "$CONFIG_SCRIPT_PATH" ]; then
        echo "--> Applying custom configuration for component: ${component}"
        sudo bash "$CONFIG_SCRIPT_PATH"
    fi
done

echo "--- All custom configurations applied successfully. ---"