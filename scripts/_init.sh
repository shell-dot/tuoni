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

# This is required for the docker-compose.yml file know where to direct the traffic to.
DOCKER_HOST_FQDN=$(hostname -f)
export DOCKER_HOST_FQDN
