#!/bin/bash

set -e

if [[ "$SILENT" == "1" ]]; then
  echo "INFO | Silent mode enabled, no confirmation prompts ..."
fi

SUDO_COMMAND=
if command -v "sudo" &>/dev/null; then
  SUDO_COMMAND="sudo -E"
fi

PROJECT_ROOT="$( cd -- "$(dirname "$0")/" >/dev/null 2>&1 || exit ; pwd -P )"
export TUONI_GIT_VERSION=$(grep version ${PROJECT_ROOT}/version.yml | cut -d':' -f2 | tr -d '[:space:]')
export TUONI_UTILITY_IMAGE="ghcr.io/shell-dot/tuoni/utility:${TUONI_UTILITY_VERSION:-$TUONI_GIT_VERSION}"

# This is also required for the docker-compose.yml file know where to direct the traffic to.
export TUONI_HOST_FQDN=$(hostname -f)
