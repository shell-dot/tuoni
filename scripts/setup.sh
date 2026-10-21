#!/bin/bash

set -e
echo "INFO | tuoni setup script started ..."

# TUONI_REPO default value
if [[ -z "${TUONI_REPO+x}" ]]; then
  TUONI_REPO='https://github.com/shell-dot/tuoni.git'
else 
  echo "INFO | tuoni setup set TUONI_REPO to: $TUONI_REPO ..."
fi

# TUONI_BRANCH default value
if [[ -z "${TUONI_BRANCH+x}" ]]; then
  TUONI_BRANCH="main"
else
  echo "INFO | tuoni setup set TUONI_BRANCH to: $TUONI_BRANCH ..."
fi

# This standalone installer needs only package-manager and proxy settings under
# sudo. The child tuoni process selects its own Docker/Compose preservation list.
if [[ -z "${TUONI_SUDO_COMMAND+x}" ]]; then
  TUONI_SUDO_COMMAND=""
  if command -v "sudo" &>/dev/null; then
    TUONI_SUDO_PRESERVE_ENV=(
      DEBIAN_FRONTEND DEBIAN_PRIORITY DEBCONF_NONINTERACTIVE_SEEN APT_CONFIG NEEDRESTART_MODE
      http_proxy https_proxy ftp_proxy no_proxy all_proxy
      HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY ALL_PROXY SSL_CERT_FILE SSL_CERT_DIR
    )
    TUONI_SUDO_COMMAND="sudo --preserve-env=$(IFS=,; printf '%s' "${TUONI_SUDO_PRESERVE_ENV[*]}")"
    echo "INFO | Using sudo with environment preservation."
  fi
else
  echo "INFO | tuoni setup script set TUONI_SUDO_COMMAND to: $TUONI_SUDO_COMMAND ..."
fi

# Install git if not found
if ! command -v "git" &>/dev/null; then
  echo "INFO | git is not found, installing ..."
  ${TUONI_SUDO_COMMAND} apt-get update && ${TUONI_SUDO_COMMAND} apt-get install git -y
fi

# Check if the tuoni directory exists
if [ ! -d "/srv/tuoni" ]; then
  echo "INFO | Cloning tuoni repository into /srv/tuoni ..."
  cd /srv
  ${TUONI_SUDO_COMMAND} mkdir /srv/tuoni
  ${TUONI_SUDO_COMMAND} chown $USER:$USER /srv/tuoni
  git clone -b $TUONI_BRANCH $TUONI_REPO /srv/tuoni
  cd /srv/tuoni
  ./tuoni start
elif [[ "$NO_UPDATE" == "1" ]]; then
  echo "INFO | tuoni directory already exists and NO_UPDATE=1 is set. Skipping update ..."
  cd /srv/tuoni
  ./tuoni start
else
  echo "INFO | tuoni directory already exists. Updating ..."
  cd /srv/tuoni
  ./tuoni update-silent
  ./tuoni start
fi
