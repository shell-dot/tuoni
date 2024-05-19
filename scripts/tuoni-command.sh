#!/bin/bash

### include env variables
. "$PROJECT_ROOT/config/tuoni.env"
. "$PROJECT_ROOT/scripts/_init.sh"

TUONI_DOCKER_COMPOSE_COMMAND="docker compose --env-file ${PROJECT_ROOT}/config/tuoni.env -f ${PROJECT_ROOT}/docker-compose.yml"

# echo "TUONI VERSION: $VERSION"
TUONI_COMPONENT=$(basename "$0")
TUONI_COMMAND="$1"

if [ "$TUONI_COMPONENT" == "tuoni" ]; then
  TUONI_COMPONENT="app"
fi
# echo ${TUONI_COMPONENT^^}
# echo ${TUONI_COMMAND^^}

if ! [[ "$1" =~ ^(start|stop|restart|logs|clean-configuration|update|update-silent)$ ]]; then
  cat << EOF
$(tput bold)TUONI Command Line Interface (CLI) - Version $VERSION$(tput sgr0)

$(tput smul)USAGE:$(tput rmul)
    $(tput setaf 2)./tuoni <command>$(tput sgr0)

$(tput smul)AVAILABLE COMMANDS:$(tput rmul)
    $(tput setaf 3)start$(tput sgr0)                Starts the Tuoni docker.
    $(tput setaf 3)stop$(tput sgr0)                 Stops the Tuoni dockers.
    $(tput setaf 3)restart$(tput sgr0)              Restarts the Tuoni dockers.
    $(tput setaf 3)logs$(tput sgr0)                 Tails the logs for the Tuoni dockers.
    $(tput setaf 3)clean-configuration$(tput sgr0)  Prompt which configuration files to remove and resets them to default.
    $(tput setaf 3)update$(tput sgr0)               Perform git and docker pull.
    $(tput setaf 3)update-silent$(tput sgr0)        Perform git and docker pull silently.

$(tput smul)ADDITIONAL INFORMATION:$(tput rmul)
    Tuoni URL:           $(tput setaf 4)https://localhost:12702/$(tput sgr0)
    Documentation:       $(tput setaf 4)https://docs.shelldot.com/$(tput sgr0)
    Configuration Path:  $(tput setaf 6)config/tuoni.yml$(tput sgr0)

For further assistance or to report issues, please visit our documentation or contact support through our website.

EOF

  exit 0
fi

echo "TUONI ${TUONI_COMPONENT^^} running command: $1"

if [ "$1" == "clean-configuration" ]; then
  . "$PROJECT_ROOT/scripts/clean-configuration.sh"
fi

if [ "$1" == "update" ]; then
  . "$PROJECT_ROOT/scripts/update.sh"
fi

if [ "$1" == "update-silent" ]; then
  . "$PROJECT_ROOT/scripts/update.sh" silent
fi

if [ "$1" == "logs" ]; then
  ${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} logs -f
fi

if [ "$1" == "start" ]; then
  ${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach
  echo "INFO | Tuoni url: https://localhost:12702/"
fi

if [ "$1" == "stop" ]; then
  ${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} stop
fi

if [ "$1" == "restart" ]; then
  ${SUDO_COMMAND} COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach --force-recreate
fi

### print the auto-generated username and password
if [ -n "${AUTOGENERATED_USERNAME}" ]; then
  echo "INFO | Auto-generated username: ${AUTOGENERATED_USERNAME}"
fi
if [ -n "${AUTOGENERATED_PASSWORD}" ]; then
  echo "INFO | Auto-generated password: ${AUTOGENERATED_PASSWORD}"
fi

### show url if auto-generated username or password is not empty
if [ -n "${AUTOGENERATED_USERNAME}" ] || [ -n "${AUTOGENERATED_PASSWORD}" ]; then
  echo "INFO | Tuoni url: https://localhost:12702/"
fi
