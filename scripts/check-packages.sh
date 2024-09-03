#!/bin/bash
set -e

# Define required packages
REQUIRED_PACKAGES=()
MISSING_PACKAGES=()

# Function to check if a command is available
command_exists() {
    command -v "$1" &>/dev/null
}

# Check for necessary commands and add to the install list if missing
if ! command_exists "curl"; then REQUIRED_PACKAGES+=('curl'); fi
if ! command_exists "jq"; then REQUIRED_PACKAGES+=('jq'); fi
if ! command_exists "git"; then REQUIRED_PACKAGES+=('git'); fi
if ! command_exists "rsync"; then REQUIRED_PACKAGES+=('rsync'); fi

# Install other missing packages
if [ "${#REQUIRED_PACKAGES[@]}" -ne 0 ]; then
    echo "INFO | Following packages are not found, installing: ${REQUIRED_PACKAGES[*]} ..."
     ${SUDO_COMMAND} apt-get update && ${SUDO_COMMAND} apt-get install -y ${REQUIRED_PACKAGES[*]}
fi
