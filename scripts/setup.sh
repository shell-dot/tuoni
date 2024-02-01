#!/bin/bash

set -e

SUDO_COMMAND=
if command -v "sudo" &>/dev/null; then
  SUDO_COMMAND="sudo "
fi

if ! command -v "git" &>/dev/null; then
  echo "INFO | git is not found, installing ..."
  ${SUDO_COMMAND} apt-get update && ${SUDO_COMMAND} apt-get install git -y
fi

git clone https://github.com/shell-dot/tuoni.git

cd tuoni

./tuoni start
