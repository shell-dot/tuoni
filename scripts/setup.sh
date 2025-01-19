#!/bin/bash

set -e
echo "INFO | tuoni setup script started ..."


# SUDO_COMMAND default value
if [[ -z "${SUDO_COMMAND+x}" ]]; then
  SUDO_COMMAND=""
  if command -v "sudo" &>/dev/null; then
    SUDO_COMMAND="sudo -E"
    echo "INFO | tuoni setup script default SUDO_COMMAND to: $SUDO_COMMAND ..."
  fi
else 
  echo "INFO | tuoni setup script set SUDO_COMMAND to: $SUDO_COMMAND ..."
fi

# Install git if not found
if ! command -v "git" &>/dev/null; then
  echo "INFO | git is not found, installing ..."
  ${SUDO_COMMAND} apt-get update && ${SUDO_COMMAND} apt-get install git -y
fi

# Check if the tuoni directory exists
if [ ! -d "/srv/tuoni" ]; then
  echo "INFO | Cloning tuoni repository into /srv/tuoni ..."
  cd /srv 
  ${SUDO_COMMAND} mkdir /srv/tuoni 
  ${SUDO_COMMAND} chown $USER:$USER /srv/tuoni
  git clone https://github.com/shell-dot/tuoni.git /srv/tuoni
  cd /srv/tuoni
  ./tuoni start
elif [[ "$NO_UPDATE" == "1" ]]; then
  echo "INFO | tuoni directory already exists and NO_UPDATE=1 is set. Skipping update ..."
else
  echo "INFO | tuoni directory already exists. Updating ..."
  cd /srv/tuoni
  ./tuoni update-silent
fi
