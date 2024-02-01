#!/bin/bash

set -e

ENV_PATH="./config/tuoni.env"
CONFIG_PATH="./config/tuoni.yml"


### ask for confirmation
read -r -p "Are you sure you want to update? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        ;;
    *)
        echo "INFO | Aborting"
        exit 1
        ;;
esac

echo "INFO | Running update script"

### update scripts and repo
git pull

### update the image version in env file
LATEST_VERSION=$(cat ./version.yml | cut -d ' ' -f 2)
sed -i "s/VERSION=.*/VERSION=${LATEST_VERSION}/g" "${ENV_PATH}"

echo "INFO | Pull docker images"
${SUDO_COMMAND} docker pull ghcr.io/shell-dot/tuoni/client:${LATEST_VERSION}
${SUDO_COMMAND} docker pull ghcr.io/shell-dot/tuoni/server:${LATEST_VERSION}

echo "================================================================"
echo "INFO | Update script finished - make sure to restart the service"

. ./scripts/check-configuration.sh
