#!/bin/bash

set -e

# Enable silent mode if SILENT is set to 1
if [[ "$SILENT" == "1" ]]; then
  echo "INFO | Silent mode enabled, no confirmation prompts ..."
fi

# Use named preservation: sudo-rs on Ubuntu 25.10/26.04 ignores sudo -E.
# Respect explicit overrides, including an empty string for running without sudo.
if [[ -z "${TUONI_SUDO_COMMAND+x}" ]]; then
  TUONI_SUDO_COMMAND=""
  if command -v "sudo" &>/dev/null; then
    TUONI_SUDO_PRESERVE_ENV=(
      # Docker's user configuration, credentials and SSH connections.
      HOME SSH_AUTH_SOCK
      # Inputs used by docker-compose.yml, including values exported later.
      VERSION TUONI_CONTAINER_REPO TUONI_DOCKER_IPV6_ENABLED TUONI_HOST_FQDN
      TUONI_CLIENT_PORT TUONI_CLIENT_LOGGER_ENABLED TUONI_CLIENT_LOGGER_CONSOLE
      TUONI_CLIENT_LOGGER_LEVEL TUONI_CLIENT_LOGGER_HEADERS
      # Preserve the selected daemon, TLS requirements and image platform.
      DOCKER_HOST DOCKER_CONTEXT DOCKER_CONFIG DOCKER_TLS DOCKER_TLS_VERIFY
      DOCKER_CERT_PATH DOCKER_API_VERSION DOCKER_DEFAULT_PLATFORM DOCKER_CUSTOM_HEADERS
      DOCKER_BUILDKIT DOCKER_CONTENT_TRUST DOCKER_CONTENT_TRUST_SERVER
      # Compose project identity and command behavior.
      COMPOSE_PROJECT_NAME COMPOSE_PROFILES COMPOSE_PARALLEL_LIMIT COMPOSE_COMPATIBILITY
      COMPOSE_IGNORE_ORPHANS COMPOSE_REMOVE_ORPHANS COMPOSE_ANSI COMPOSE_STATUS_STDOUT
      COMPOSE_PROGRESS COMPOSE_MENU COMPOSE_EXPERIMENTAL
      # Package installation and network configuration.
      DEBIAN_FRONTEND DEBIAN_PRIORITY DEBCONF_NONINTERACTIVE_SEEN APT_CONFIG NEEDRESTART_MODE
      http_proxy https_proxy ftp_proxy no_proxy all_proxy
      HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY ALL_PROXY SSL_CERT_FILE SSL_CERT_DIR
    )
    # Pass names only; sudo reads their current values at each invocation.
    TUONI_SUDO_COMMAND="sudo --preserve-env=$(IFS=,; printf '%s' "${TUONI_SUDO_PRESERVE_ENV[*]}")"
    echo "INFO | tuoni default TUONI_SUDO_COMMAND to: $TUONI_SUDO_COMMAND ..."
  fi
fi

# Set project root directory
PROJECT_ROOT="$( cd -- "$(dirname "$0")/" >/dev/null 2>&1 || exit ; pwd -P )"

# TUONI_VERSION from env
if [[ ! -z "${TUONI_VERSION+x}" ]]; then
  echo "INFO | TUONI_VERSION set in env: $TUONI_VERSION ..."
fi

# Export necessary environment variables
export TUONI_GIT_VERSION=$(grep version ${PROJECT_ROOT}/version.yml | cut -d':' -f2 | tr -d '[:space:]')
export TUONI_UTILITY_IMAGE="ghcr.io/shell-dot/tuoni/utility:${TUONI_VERSION:-$TUONI_GIT_VERSION}"
export TUONI_HOST_FQDN=$(hostname -f) # Required for docker-compose.yml to direct traffic
