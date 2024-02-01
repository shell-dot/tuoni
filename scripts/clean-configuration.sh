#!/bin/bash

set -e

CLEAN_ERROR=" "
options[0]="config"
options[1]="data"
options[2]="logs"
options[3]="agent-templates"
options[4]="ssl/server"
options[5]="ssl/client"

#Clear screen for menu
clear

#Menu function
function CLEAN_MENU {
    echo "CLEAN Options"
    for NUM in ${!options[@]}; do
        echo "[""${choices[NUM]:- }""]" $(( NUM+1 ))") ${options[NUM]}"
    done
    echo "$CLEAN_ERROR"
}

#Menu loop
while CLEAN_MENU && read -e -p "Select the which configuration folders to purge using their number ( again to uncheck, ENTER when done): " -n1 SELECTION && [[ -n "$SELECTION" ]]; do
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


### ask for confirmation
read -r -p "Are you sure you want to stop the service and clean the configuration? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        ;;
    *)
        echo "INFO | Aborting"
        exit 1
        ;;
esac

ENV_PATH="./config/tuoni.env"
CONFIG_PATH="./config/tuoni.yml"

${SUDO_COMMAND} docker compose --env-file ${PROJECT_ROOT}/config/tuoni.env -f ${PROJECT_ROOT}/docker-compose.yml down -v --rmi all --remove-orphans
echo "INFO | Docker containers stopped and removed"

if [[ ${choices[0]} ]]; then
  rm ${ENV_PATH} || true
  rm ${CONFIG_PATH} || true
fi

if [[ ${choices[1]} ]]; then rm -rf ./data/* || true; fi
if [[ ${choices[2]} ]]; then rm -rf ./logs/* || true; fi
if [[ ${choices[3]} ]]; then rm -rf ./agent-templates/* || true; fi
if [[ ${choices[4]} ]]; then rm -rf ./ssl/server/* || true; fi
if [[ ${choices[5]} ]]; then rm -rf ./ssl/client/* || true; fi

echo "INFO | Configuration cleaned"

. ./scripts/check-configuration.sh
