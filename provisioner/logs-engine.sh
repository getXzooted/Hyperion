#!/bin/bash
# logs-engine.sh
#
# A specialized engine for collecting full system diagnostics.


set -e


# --- Script Arguments ---
LOG_FILENAME="$1"
EXTERNAL_SAVE_PATH="$2"
LOG_MODE="$3" # This will be 'new' or 'append'

# --- Main Logic ---
if [ -n "$EXTERNAL_SAVE_PATH" ]; then
    echo "--> External save path provided. Locating and mounting external drive..."
    # Find the first 'sda' block device (assumes the first USB drive is the target)
    # We look for partitions, which are the mountable parts of a drive.
    EXT_DRIVE_PARTITION=$(lsblk -o NAME,TYPE | grep "sda" | grep "part" | head -n 1 | awk '{print $1}')

    if [ -z "$EXT_DRIVE_PARTITION" ]; then
        echo "--> ERROR: Could not find a mountable partition on an external USB drive (sda)."
        exit 1
    fi

    MOUNT_POINT="/mnt/external_log_drive"
    sudo mkdir -p "$MOUNT_POINT"
    # Mount the identified partition
    sudo mount "/dev/${EXT_DRIVE_PARTITION}" "$MOUNT_POINT"

    # The final, full path for the log file on the external drive
    FINAL_LOG_PATH="${MOUNT_POINT}${EXTERNAL_SAVE_PATH}${LOG_FILENAME}"
    echo "--> External drive mounted. Log will be saved to: ${FINAL_LOG_PATH}"
else
    # If no external path is provided, save to the local home directory
    FINAL_LOG_PATH="/home/jelogan/${LOG_FILENAME}"
    echo "--> No external path specified. Log will be saved to: ${FINAL_LOG_PATH}"
fi

# Create the destination directory if it doesn't exist
sudo mkdir -p "$(dirname "$FINAL_LOG_PATH")"

# This is the diagnostic command block
DIAGNOSTIC_DATA=$(
{
    echo "--- [ HYPERION ANALYSIS LOG - $(date) ] ---"
    echo ""
    echo "---[ NODE STATUS ]---"
    kubectl get nodes -o wide
    echo ""
    echo "---[ ALL PODS STATUS ]---"
    kubectl get pods -A -o wide
    echo ""
    echo "---[ FLUX KUSTOMIZATION STATUS ]---"
    kubectl get kustomizations -n flux-system
    echo ""
    echo "---[ FULL PROJECT CODE REVIEW ]---"
    find /opt/Hyperion -type f \( -name "*.sh" -o -name "*.json" -o -name "*.yaml" \) -print -exec echo "---" \; -exec cat {} \;
}
)

if [ "$LOG_MODE" == "new" ]; then
    echo "--> Creating new log file."
    # Use 'tee' without the append flag to overwrite.
    echo "$DIAGNOSTIC_DATA" | sudo tee "$FINAL_LOG_PATH" > /dev/null
else
    echo "--> Appending to existing log file (cache mode)."
    # Use 'tee -a' to append to the file.
    echo "$DIAGNOSTIC_DATA" | sudo tee -a "$FINAL_LOG_PATH" > /dev/null
fi

# Unmount the drive if we used it
if [ -n "$EXTERNAL_SAVE_PATH" ]; then
    sudo umount "$MOUNT_POINT"
    echo "--> External drive unmounted."
fi

echo ""
echo "---[ ANALYSIS COMPLETE ]---"
echo "Log file saved to: ${FINAL_LOG_PATH}"