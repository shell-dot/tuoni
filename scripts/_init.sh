#!/bin/bash

set -e

SUDO_COMMAND=
if command -v "sudo" &>/dev/null; then
  SUDO_COMMAND="sudo "
fi

PROJECT_ROOT="$( cd -- "$(dirname "$0")/" >/dev/null 2>&1 || exit ; pwd -P )"
