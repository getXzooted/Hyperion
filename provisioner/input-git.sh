#!/bin/bash
#
# input-git.sh 
# Separating the Git Login logic for future


set -e


echo "  ---------> Please provide your GitHub credentials to clone your private config repository."
read -p "Enter your GitHub Username: " GITHUB_USER
read -s -p "Enter your GitHub Personal Access Token (PAT): " GITHUB_PAT
echo


echo "  ---------> Cloning repositories <---------  "
git clone https://github.com/getXzooted/Hyperion.git /opt/Hyperion

mkdir -p /etc/hyperion
git clone "https://_:${GITHUB_PAT}@github.com/${GITHUB_USER}/Hyperion-config.git" /etc/hyperion/config


export GITHUB_USER
export GITHUB_PAT
sudo /opt/Hyperion/provisioner/hyperion-deployment.sh