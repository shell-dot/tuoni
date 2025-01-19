#!/bin/bash

set -e

ENV_PATH="$PROJECT_ROOT/config/tuoni.env"
CONFIG_PATH="$PROJECT_ROOT/config/tuoni.yml"

# Check if NO_UPDATE is set to 1
if [[ "$NO_UPDATE" == "1" ]]; then
  echo "INFO | NO_UPDATE=1 is set. Skipping update ..."
  return;
fi

# Skip prompt if SILENT is set to 1
if [[ "$SILENT" != "1" ]]; then
    ### ask for confirmation
    echo -e "\n\n\n\n\n"
    read -r -p "WARNING | Are you sure you want to start Tuoni update? Tuoni will be restarted. [y/N]" response
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

echo "INFO | Tuoni is going to be stopped ..."

$PROJECT_ROOT/tuoni stop

echo "INFO | Running Tuoni update script ..."

# Update scripts and repo
cd $PROJECT_ROOT && git pull

# Update the image version in env file
TUONI_GIT_VERSION=$(cat $PROJECT_ROOT/version.yml | cut -d ' ' -f 2)
echo "INFO | TUONI_VERSION ${TUONI_VERSION:-$TUONI_GIT_VERSION}"
sed -i "s/VERSION=.*/VERSION=${TUONI_VERSION:-$TUONI_GIT_VERSION}/g" "$PROJECT_ROOT/config/tuoni.env"

echo "INFO | Pulling Tuoni ${TUONI_VERSION:-$TUONI_GIT_VERSION} docker images..."
${SUDO_COMMAND} env COMPOSE_PROFILES=app,utility ${TUONI_DOCKER_COMPOSE_COMMAND} pull

echo -e "\n\n\n\n\n"
echo "================================================================"
echo "INFO | Update script finished - tuoni will be restarted."
echo "================================================================"
echo -e "\n\n\n\n\n"

# Run post-update checks
. $PROJECT_ROOT/scripts/check-packages.sh
. $PROJECT_ROOT/scripts/check-docker.sh
. $PROJECT_ROOT/scripts/check-configuration.sh
. $PROJECT_ROOT/scripts/check-autocomplete.sh

$PROJECT_ROOT/tuoni start
