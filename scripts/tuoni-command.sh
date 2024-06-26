#!/bin/bash

### include env variables
. "$PROJECT_ROOT/config/tuoni.env"
. "$PROJECT_ROOT/scripts/_init.sh"

TUONI_CONFIG_FILE_PATH="$PROJECT_ROOT/config/tuoni.yml"

export TUONI_CLIENT_PORT=$($PROJECT_ROOT/scripts/tools/yq '.client.port' $TUONI_CONFIG_FILE_PATH)
export TUONI_CLIENT_LOGGER_ENABLED=$($PROJECT_ROOT/scripts/tools/yq '.client.logger.to_file' $TUONI_CONFIG_FILE_PATH)
export TUONI_CLIENT_LOGGER_CONSOLE=$($PROJECT_ROOT/scripts/tools/yq '.client.logger.to_console' $TUONI_CONFIG_FILE_PATH)
export TUONI_CLIENT_LOGGER_LEVEL=$($PROJECT_ROOT/scripts/tools/yq '.client.logger.level' $TUONI_CONFIG_FILE_PATH)
export TUONI_CLIENT_LOGGER_SH=$($PROJECT_ROOT/scripts/tools/yq '.client.logger.sh' $TUONI_CONFIG_FILE_PATH)
export TUONI_CLIENT_LOGGER_HEADERS=$($PROJECT_ROOT/scripts/tools/yq -o=json '.client.logger.headers' $TUONI_CONFIG_FILE_PATH | jq -c)

TUONI_DOCKER_COMPOSE_COMMAND="docker compose --env-file ${PROJECT_ROOT}/config/tuoni.env -f ${PROJECT_ROOT}/docker-compose.yml"

TUONI_COMPONENT=$(basename "$0")
TUONI_COMMAND="$1"
TUONI_SUBCOMMAND="$2"

if [ "$TUONI_COMPONENT" == "tuoni" ]; then
  TUONI_COMPONENT="app"
fi

# Function to handle client commands
handle_client_command() {
    local command="$1"
    case "$command" in
        start)
            echo "INFO | Starting client ..."
            ${SUDO_COMMAND} COMPOSE_PROFILES=client ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach
            ;;
        stop)
            echo "INFO | Stopping client ..."
            ${SUDO_COMMAND} COMPOSE_PROFILES=client ${TUONI_DOCKER_COMPOSE_COMMAND} stop
            ;;
        restart)
            echo "INFO | Restarting client ..."
            ${SUDO_COMMAND} COMPOSE_PROFILES=client ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach --force-recreate
            ;;
        logs)
            echo "INFO | Showing client logs ..."
            ${SUDO_COMMAND} COMPOSE_PROFILES=client ${TUONI_DOCKER_COMPOSE_COMMAND} logs -f
            ;;
        *)
            echo "WARNING | Invalid client command. Available commands: start, stop, restart, logs."
            ;;
    esac
}

# Function to handle server commands
handle_server_command() {
    local command="$1"
    case "$command" in
        start)
            echo "INFO | Starting server..."
            ${SUDO_COMMAND} COMPOSE_PROFILES=server ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach
            ;;
        stop)
            echo "INFO | Stopping server..."
            ${SUDO_COMMAND} COMPOSE_PROFILES=server ${TUONI_DOCKER_COMPOSE_COMMAND} stop
            ;;
        restart)
            echo "INFO | Restarting server..."
            ${SUDO_COMMAND} COMPOSE_PROFILES=server ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach --force-recreate
            ;;
        logs)
            echo "INFO | Showing server logs..."
            ${SUDO_COMMAND} COMPOSE_PROFILES=server ${TUONI_DOCKER_COMPOSE_COMMAND} logs -f
            ;;
        *)
            echo "WARNING | Invalid server command. Available commands: start, stop, restart, logs."
            ;;
    esac
}

if ! [[ "$TUONI_COMMAND" =~ ^(version|print-config-file|print-credentials|start|stop|restart|logs|clean-configuration|update|update-silent|client|server)$ ]]; then
  cat << EOF
$(tput bold)TUONI Command Line Interface (CLI) - Version $VERSION$(tput sgr0)

$(tput smul)USAGE:$(tput rmul)
    $(tput setaf 2)tuoni <command>$(tput sgr0)
    $(tput setaf 2)tuoni client <command>$(tput sgr0)
    $(tput setaf 2)tuoni server <command>$(tput sgr0)

$(tput smul)AVAILABLE COMMANDS:$(tput rmul)
    $(tput setaf 3)help$(tput sgr0)                 Display help.
    $(tput setaf 3)version$(tput sgr0)              Display version.
    $(tput setaf 3)print-config-file$(tput sgr0)    Display config file.
    $(tput setaf 3)print-credentials$(tput sgr0)    Display tuoni credentials.
    $(tput setaf 3)start$(tput sgr0)                Starts the Tuoni dockers.
    $(tput setaf 3)stop$(tput sgr0)                 Stops the Tuoni dockers.
    $(tput setaf 3)restart$(tput sgr0)              Restarts the Tuoni dockers.
    $(tput setaf 3)logs$(tput sgr0)                 Tails the logs for the Tuoni dockers.
    $(tput setaf 3)clean-configuration$(tput sgr0)  Prompt which configuration files to remove and resets them to default.
    $(tput setaf 3)update$(tput sgr0)               Perform git and docker pull.
    $(tput setaf 3)update-silent$(tput sgr0)        Perform git and docker pull silently.

$(tput smul)ADDITIONAL INFORMATION:$(tput rmul)
    Tuoni URL:           $(tput setaf 4)https://localhost:12702/$(tput sgr0)
    Documentation:       $(tput setaf 4)https://docs.shelldot.com/$(tput sgr0)
    Configuration Path:  $(tput setaf 6)${PROJECT_ROOT}/config/tuoni.yml$(tput sgr0)

For further assistance or to report issues, please visit our documentation or contact support through our website.

EOF

  exit 0
fi

echo "TUONI ${TUONI_COMPONENT^^} running command: $TUONI_COMMAND $TUONI_SUBCOMMAND"

if [ "$TUONI_COMMAND" == "version" ]; then
  cat ${PROJECT_ROOT}/config/tuoni.env | grep VERSION
fi

if [ "$TUONI_COMMAND" == "print-config-file" ]; then
  echo "INFO | Printing configuration file from ${PROJECT_ROOT}/config/tuoni.yml ..."
  ${PROJECT_ROOT}/scripts/tools/yq ${PROJECT_ROOT}/config/tuoni.yml
fi

if [ "$TUONI_COMMAND" == "print-credentials" ]; then
  echo "INFO | Printing credentials from ${PROJECT_ROOT}/config/tuoni.yml ..."
  ${PROJECT_ROOT}/scripts/tools/yq '.tuoni.auth.credentials' ${PROJECT_ROOT}/config/tuoni.yml
fi

if [ "$TUONI_COMMAND" == "clean-configuration" ]; then
  . "$PROJECT_ROOT/scripts/clean-configuration.sh"
fi

if [ "$TUONI_COMMAND" == "update" ]; then
  . "$PROJECT_ROOT/scripts/update.sh"
fi

if [ "$TUONI_COMMAND" == "update-silent" ]; then
  SILENT=1 . "$PROJECT_ROOT/scripts/update.sh"
fi

if [ "$TUONI_COMMAND" == "logs" ]; then
  ${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} logs -f
fi

if [ "$TUONI_COMMAND" == "start" ]; then
  ${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach
  echo "INFO | Tuoni url: https://localhost:12702/"
fi

if [ "$TUONI_COMMAND" == "stop" ]; then
  ${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} stop
fi

if [ "$TUONI_COMMAND" == "restart" ]; then
  ${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach --force-recreate
fi

if [ "$TUONI_COMMAND" == "client" ]; then
  handle_client_command "$TUONI_SUBCOMMAND"
fi

if [ "$TUONI_COMMAND" == "server" ]; then
  handle_server_command "$TUONI_SUBCOMMAND"
fi

### print the credentials during setup
if [ -n "${TUONI_USERNAME_TO_CONFIG}" ]; then
  echo -e "\n\n\n\n\n"
  echo "INFO | tuoni url: https://localhost:12702/"
  echo "INFO | tuoni username: ${TUONI_USERNAME_TO_CONFIG}"
  echo "INFO | tuoni password: ${TUONI_PASSWORD_TO_CONFIG}"
fi
