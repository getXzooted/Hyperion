#!/bin/bash
#
# system-init
# Configures required kernel modules and settings for container networking,
# Then updates the system with update and upgrade


set -e


echo "  ---------> Applying required kernel modules and sysctl settings for K3s networking <---------  "

# Ensure the br_netfilter module is loaded on boot
cat <<EOF | tee /etc/modules-load.d/k3s.conf
br_netfilter
EOF

# Load the module for the current session
/sbin/modprobe br_netfilter

# Ensure required bridge-netfilter settings are enabled in the kernel
cat <<EOF | tee /etc/sysctl.d/99-k3s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
EOF

# Apply the new sysctl settings for the current session
/sbin/sysctl --system

echo "  ---------> Kernel networking settings applied."


echo "  ---------> Checking for and fixing any interrupted package operations <---------  "
dpkg --configure -a

echo "  ---------> Updating package lists <---------  "
apt-get update

echo "  ---------> Upgrading existing packages <---------  "
apt-get install --fix-broken -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confnew"
echo "  ---------> Update and Upgrade complete. <---------  "


echo "  ---------> Waiting for systemd to settle after upgrade <---------  "
# This loop waits until the system is in a stable 'running' state.
TIMEOUT=300 # 5 minute timeout
SECONDS=0
while [[ $(systemctl is-system-running) != 'running' && $(systemctl is-system-running) != 'degraded' ]]; do
  if [ $SECONDS -ge $TIMEOUT ]; then
    echo "  ---------> ERROR: Timed out waiting for systemd to settle. <---------  "
    exit 1
  fi
  echo "  ---------> System state is '$(systemctl is-system-running)'. Waiting 10 more seconds <---------  "
  sleep 10
  SECONDS=$((SECONDS + 10))
done


echo "  ---------> System has settled. OS Preparation is truly complete. <---------  "