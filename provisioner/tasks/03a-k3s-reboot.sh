#!/bin/bash
# Task: 03a-k3s-reboot.sh
# Forces a reboot after K3s installation to ensure the service stabilizes.

set -e
echo "  -> K3s has been installed. Forcing a reboot to ensure stability before network configuration."
# This script will exit with code 10 to signal to the master provisioner
# that a reboot is required.
exit 10
