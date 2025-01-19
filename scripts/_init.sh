#!/bin/bash

set -e

# Enable silent mode if SILENT is set to 1
if [[ "$SILENT" == "1" ]]; then
  echo "INFO | Silent mode enabled, no confirmation prompts ..."
fi

# SUDO_COMMAND default value
if [[ -z "${SUDO_COMMAND+x}" ]]; then
  SUDO_COMMAND=""
  if command -v "sudo" &>/dev/null; then
    SUDO_COMMAND="sudo -E"
    echo "INFO | tuoni default SUDO_COMMAND to: $SUDO_COMMAND ..."
  fi
fi

# Set project root directory
PROJECT_ROOT="$( cd -- "$(dirname "$0")/" >/dev/null 2>&1 || exit ; pwd -P )"

# Export necessary environment variables
export TUONI_GIT_VERSION=$(grep version ${PROJECT_ROOT}/version.yml | cut -d':' -f2 | tr -d '[:space:]')
export TUONI_UTILITY_IMAGE="ghcr.io/shell-dot/tuoni/utility:${TUONI_UTILITY_VERSION:-$TUONI_GIT_VERSION}"
export TUONI_HOST_FQDN=$(hostname -f) # Required for docker-compose.yml to direct traffic
