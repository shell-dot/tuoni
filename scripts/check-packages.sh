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

# Special check for yq due to potential repository issues
if ! command_exists "yq"; then
    # Try to install yq from the repository first
    echo "INFO | Following packages are not found, installing: yq"
    if ${SUDO_COMMAND} apt-get install -y yq &>/dev/null; then
        echo "INFO | yq installed successfully from apt repository"
    else
        # If yq is not available in the repository, download it manually
        echo "INFO | yq not available in apt repository, downloading from GitHub..."
        ${SUDO_COMMAND} wget https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_arm64 -O /usr/local/bin/yq
        ${SUDO_COMMAND} chmod +x /usr/local/bin/yq
        echo "INFO | yq has been installed to /usr/local/bin/yq"
    fi
fi

# Install other missing packages
if [ "${#REQUIRED_PACKAGES[@]}" -ne 0 ]; then
    echo "INFO | Following packages are not found, installing: ${REQUIRED_PACKAGES[*]}"
     ${SUDO_COMMAND} apt-get update && ${SUDO_COMMAND} apt-get install -y ${REQUIRED_PACKAGES[*]}
fi
