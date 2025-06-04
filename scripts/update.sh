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
    read -r -p "WARNING | Are you sure you want to start Tuoni update? Tuoni may be restarted. [y/N]" response
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

echo "INFO | Running Tuoni update script ..."

# Update scripts and repo
cd "$PROJECT_ROOT" && git pull

# Function to compare versions
# Returns 0 if the first version is greater than or equal to the second version
version_gte() {
    # Use sort with version sort flag and check the first line
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

TUONI_CONFIG_VERSION=$(grep VERSION "${PROJECT_ROOT}/config/tuoni.env" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' )
TUONI_GIT_VERSION=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "${PROJECT_ROOT}/version.yml")

# TUONI_VERSION from env
if [[ -n "${TUONI_VERSION+x}" ]]; then
    TUONI_CONFIG_VERSION=${TUONI_VERSION}
fi

if [[ $TUONI_CONFIG_VERSION != "$TUONI_GIT_VERSION" ]]; then
    echo "INFO | Tuoni is going to be stopped ..."
    "$PROJECT_ROOT/tuoni" stop

    version_check=0
    if version_gte "${TUONI_CONFIG_VERSION}" "${TUONI_GIT_VERSION}"; then
            echo "INFO | Tuoni git version ${TUONI_GIT_VERSION}, tuoni config/env version ${TUONI_CONFIG_VERSION}"
    else
            echo "WARNING | Tuoni git version ${TUONI_GIT_VERSION} is lower than the version set in the config/env: ${TUONI_CONFIG_VERSION}"
            version_check=1
    fi

    # prompt a warning if installed version is higher than the git version
    if [ "${version_check}" -eq 1 ]; then
    # Skip prompt if SILENT is set to 1
        if [[ "$SILENT" != "1" ]]; then
            read -r -p "WARNING | Do you want to proceed with the installation? (y/N): " -n 1 -r </dev/tty
            echo    # (optional) move to a new line
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "\n\n\n\n\n"
                echo "INFO | Update aborted by the user ..."
                exit 1
            fi
        fi
    fi

    echo "INFO | TUONI_VERSION ${TUONI_VERSION:-$TUONI_GIT_VERSION}"
    sed -i "s/VERSION=.*/VERSION=${TUONI_VERSION:-$TUONI_GIT_VERSION}/g" "$PROJECT_ROOT/config/tuoni.env"

    echo "INFO | Pulling Tuoni ${TUONI_VERSION:-$TUONI_GIT_VERSION} docker images..."
    ${TUONI_SUDO_COMMAND} env COMPOSE_PROFILES=app,utility ${TUONI_DOCKER_COMPOSE_COMMAND} pull

    echo -e "\n\n\n\n\n"
    echo "================================================================"
    echo "INFO | Update script finished - tuoni will be restarted."
    echo "================================================================"
    echo -e "\n\n\n\n\n"

    # Run post-update checks

    . "$PROJECT_ROOT/scripts/check-packages.sh"
    . "$PROJECT_ROOT/scripts/check-docker.sh"
    . "$PROJECT_ROOT/scripts/check-configuration.sh"
    . "$PROJECT_ROOT/scripts/check-autocomplete.sh"

    $PROJECT_ROOT/tuoni start

else
    echo "INFO | Tuoni is already up to date."
fi
