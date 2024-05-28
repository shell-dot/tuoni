#!/bin/bash

set -e

SUDO_COMMAND=
if command -v "sudo" &>/dev/null; then
  SUDO_COMMAND="sudo -E"
fi

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
else
  echo "INFO | tuoni directory already exists. Skipping git clone."
fi

cd /srv/tuoni

./tuoni start
