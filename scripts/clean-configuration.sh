#!/bin/bash

set -e

CLEAN_ERROR=" "
options[0]="config"
options[1]="data"
options[2]="logs"
options[3]="payload-templates"
options[4]="ssl/server"
options[5]="ssl/client"
options[6]="plugins/server"
options[7]="plugins/client"
options[8]="nginx"

# Clear screen for menu
clear

# Menu function
function CLEAN_MENU {
    echo "TUONI Configuration cleaner options:"
    for NUM in ${!options[@]}; do
        echo "[""${choices[NUM]:- }""]" $(( NUM+1 ))") ${options[NUM]}"
    done
    echo "$CLEAN_ERROR"
}

# Menu loop
while CLEAN_MENU && read -e -p "Select the which configuration folders to purge using their number (again to uncheck, ENTER when done): " -n1 SELECTION && [[ -n "$SELECTION" ]]; do
    clear
    if [[ "$SELECTION" == *[[:digit:]]* && $SELECTION -ge 1 && $SELECTION -le ${#options[@]} ]]; then
        (( SELECTION-- ))
        if [[ "${choices[SELECTION]}" == "+" ]]; then
            choices[SELECTION]=""
        else
            choices[SELECTION]="+"
        fi
        CLEAN_ERROR=" "
    else
        CLEAN_ERROR="Invalid option: $SELECTION"
    fi
done

echo -e "\n\n\n\n\n"

# Ask for confirmation
read -r -p "WARNING | Are you sure you want to stop the service and clean the configuration? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        ;;
    *)
        echo "INFO | Aborting configuration cleaner ..."
        exit 1
        ;;
esac

ENV_PATH="$PROJECT_ROOT/config/tuoni.env"
CONFIG_PATH="$PROJECT_ROOT/config/tuoni.yml"

echo "INFO | Tuoni dockers will be stopped ..."
TUONI_DOCKER_COMPOSE_COMMAND="docker compose --env-file ${PROJECT_ROOT}/config/tuoni.env -f ${PROJECT_ROOT}/docker-compose.yml"

echo "${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} stop"
${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} stop
${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} rm -fv
echo "INFO | Tuoni docker containers stopped and removed."

# Remove selected configuration files and directories
if [[ ${choices[0]} ]]; then
  rm ${ENV_PATH} || true
  rm ${CONFIG_PATH} || true
fi

# Remove selected data
if [[ ${choices[1]} ]]; then rm -rf $PROJECT_ROOT/data/* || true; fi
# Remove selected logs
if [[ ${choices[2]} ]]; then rm -rf $PROJECT_ROOT/logs/* || true; fi
# Remove selected payload-templates
if [[ ${choices[3]} ]]; then rm -rf $PROJECT_ROOT/payload-templates/* || true; fi
# Remove selected ssl/server
if [[ ${choices[4]} ]]; then rm -rf $PROJECT_ROOT/ssl/server/* || true; fi
# Remove selected ssl/client
if [[ ${choices[5]} ]]; then rm -rf $PROJECT_ROOT/ssl/client/* || true; fi
# Remove selected plugins/server
if [[ ${choices[6]} ]]; then 
    rm -rf $PROJECT_ROOT/plugins/server/* || true;
    cd $PROJECT_ROOT && git checkout $PROJECT_ROOT/plugins/server/;
fi
# Remove selected plugins/client
if [[ ${choices[7]} ]]; then
    rm -rf $PROJECT_ROOT/plugins/client/* || true;
    cd $PROJECT_ROOT && git checkout $PROJECT_ROOT/plugins/client/;
fi
# Remove selected nginx configuration
if [[ ${choices[8]} ]]; then rm -rf $PROJECT_ROOT/nginx/tuoni.conf || true; fi

echo "INFO | Tuoni configuration cleaned."

. $PROJECT_ROOT/scripts/check-configuration.sh
