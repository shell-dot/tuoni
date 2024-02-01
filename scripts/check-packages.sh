#!/bin/bash
set -e

REQUIRED_PACKAGES=()
if ! command -v "curl" &>/dev/null; then REQUIRED_PACKAGES+=('curl'); fi
if ! command -v "jq" &>/dev/null; then REQUIRED_PACKAGES+=('jq'); fi
if ! command -v "git" &>/dev/null; then REQUIRED_PACKAGES+=('git'); fi

if [ -n "${REQUIRED_PACKAGES}" ]; then
    echo "INFO | Following packages are not found, installing ... ${REQUIRED_PACKAGES[*]}"
    ${SUDO_COMMAND} apt-get update && ${SUDO_COMMAND} apt-get install -y ${REQUIRED_PACKAGES[*]}
fi