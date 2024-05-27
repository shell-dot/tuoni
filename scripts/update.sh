#!/bin/bash

set -e

ENV_PATH="$PROJECT_ROOT/config/tuoni.env"
CONFIG_PATH="$PROJECT_ROOT/config/tuoni.yml"

# Skip prompt if SILENT is set to 1
if [[ "$SILENT" != "1" ]]; then
    ### ask for confirmation
    echo -e "\n\n\n\n\n"
    read -r -p "Are you sure you want to update? [y/N]" response
    case "$response" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            echo -e "\n\n\n\n\n"
            echo "INFO | User aborted update process ..."
            exit 1
            ;;
    esac
fi

echo "INFO | Running update script"

### update scripts and repo
cd $PROJECT_ROOT && git pull

### update the image version in env file
LATEST_VERSION=$(cat $PROJECT_ROOT/version.yml | cut -d ' ' -f 2)
sed -i "s/VERSION=.*/VERSION=${LATEST_VERSION}/g" "${ENV_PATH}"

echo "INFO | Pulling docker images..."
${SUDO_COMMAND} docker pull ghcr.io/shell-dot/tuoni/client:${LATEST_VERSION}
${SUDO_COMMAND} docker pull ghcr.io/shell-dot/tuoni/server:${LATEST_VERSION}

echo "================================================================"
echo "INFO | Update script finished - make sure to restart the service"

. $PROJECT_ROOT/scripts/check-packages.sh
. $PROJECT_ROOT/scripts/check-docker.sh
. $PROJECT_ROOT/scripts/check-configuration.sh
. $PROJECT_ROOT/scripts/check-autocomplete.sh
