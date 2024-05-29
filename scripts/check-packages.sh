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

if [ ! -f "$PROJECT_ROOT/scripts/tools/yq" ]; then
    echo "INFO | yq missing from $PROJECT_ROOT/scripts/tools, going to download ..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        wget https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_amd64 -O $PROJECT_ROOT/scripts/tools/yq
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        wget https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_arm64 -O $PROJECT_ROOT/scripts/tools/yq
    else
        echo -e "\n\n\n\n\n"
        echo "ERROR | Unsupported architecture: $ARCH"
        exit 1;
    fi

    chmod +x $PROJECT_ROOT/scripts/tools/yq
    echo "INFO | yq has been downloaded to $PROJECT_ROOT/scripts/tools/yq."
fi

# Install other missing packages
if [ "${#REQUIRED_PACKAGES[@]}" -ne 0 ]; then
    echo "INFO | Following packages are not found, installing: ${REQUIRED_PACKAGES[*]} ..."
     ${SUDO_COMMAND} apt-get update && ${SUDO_COMMAND} apt-get install -y ${REQUIRED_PACKAGES[*]}
fi
