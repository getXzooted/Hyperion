#!/bin/bash
#
# cgroup-fix
# Fixes the cgroup for Raspberry Pi


set -e


if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model; then
  echo "  ---------> Not a Raspberry Pi. Skipping cgroup check. <---------  "
  exit 0
fi

echo "  ---------> Checking CGroup Settings. <---------  "

if grep -q "cgroup_enable=memory cgroup_memory=1" /boot/firmware/cmdline.txt; then
  echo "  ---------> CGroup settings already present. <---------  "
  exit 0
else
  echo "  ---------> CGroup settings not found. Appending to /boot/firmware/cmdline.txt <---------  "
  sed -i '$ s/$/ cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
  echo "  ---------> CGroup settings applied. <---------  "
  exit 10
fi