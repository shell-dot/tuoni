#!/bin/bash

### include env variables
. "$PROJECT_ROOT/config/tuoni.env"
. "$PROJECT_ROOT/scripts/_init.sh"
. "$PROJECT_ROOT/scripts/tuoni-command-list.sh"

TUONI_CONFIG_FILE_PATH="$PROJECT_ROOT/config/tuoni.yml"

export TUONI_CLIENT_PORT=$($PROJECT_ROOT/scripts/tools/yq '.client.port' $TUONI_CONFIG_FILE_PATH)
export TUONI_CLIENT_LOGGER_ENABLED=$($PROJECT_ROOT/scripts/tools/yq '.client.logger.to_file' $TUONI_CONFIG_FILE_PATH)
export TUONI_CLIENT_LOGGER_CONSOLE=$($PROJECT_ROOT/scripts/tools/yq '.client.logger.to_console' $TUONI_CONFIG_FILE_PATH)
export TUONI_CLIENT_LOGGER_LEVEL=$($PROJECT_ROOT/scripts/tools/yq '.client.logger.level' $TUONI_CONFIG_FILE_PATH)
export TUONI_CLIENT_LOGGER_HEADERS=$($PROJECT_ROOT/scripts/tools/yq -o=json '.client.logger.headers' $TUONI_CONFIG_FILE_PATH | jq -c)

export TUONI_DOCKER_COMPOSE_COMMAND="docker compose --env-file ${PROJECT_ROOT}/config/tuoni.env -f ${PROJECT_ROOT}/docker-compose.yml"

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
            ${SUDO_COMMAND} env COMPOSE_PROFILES=client ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach
            ;;
        stop)
            echo "INFO | Stopping client ..."
            ${SUDO_COMMAND} env COMPOSE_PROFILES=client ${TUONI_DOCKER_COMPOSE_COMMAND} stop
            ;;
        restart)
            echo "INFO | Restarting client ..."
            ${SUDO_COMMAND} env COMPOSE_PROFILES=client ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach --force-recreate
            ;;
        logs)
            echo "INFO | Showing client logs ..."
            ${SUDO_COMMAND} env COMPOSE_PROFILES=client ${TUONI_DOCKER_COMPOSE_COMMAND} logs --tail 100 -f
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
            ${SUDO_COMMAND} env COMPOSE_PROFILES=server ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach
            ;;
        stop)
            echo "INFO | Stopping server..."
            ${SUDO_COMMAND} env COMPOSE_PROFILES=server ${TUONI_DOCKER_COMPOSE_COMMAND} stop
            ;;
        restart)
            echo "INFO | Restarting server..."
            ${SUDO_COMMAND} env COMPOSE_PROFILES=server ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach --force-recreate
            ;;
        logs)
            echo "INFO | Showing server logs..."
            ${SUDO_COMMAND} env COMPOSE_PROFILES=server ${TUONI_DOCKER_COMPOSE_COMMAND} logs --tail 100 -f
            ;;
        *)
            echo "WARNING | Invalid server command. Available commands: start, stop, restart, logs."
            ;;
    esac
}

# Function to handle docs commands
handle_docs_command() {
    local command="$1"
    case "$command" in
        start)
            echo "INFO | Starting docs..."
            echo "${SUDO_COMMAND} env COMPOSE_PROFILES=docs ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach"
            ${SUDO_COMMAND} env COMPOSE_PROFILES=docs ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach
            echo "INFO | Tuoni docs url: https://localhost:${TUONI_DOCS_PORT}/"
            ;;
        stop)
            echo "INFO | Stopping docs..."
            ${SUDO_COMMAND} env COMPOSE_PROFILES=docs ${TUONI_DOCKER_COMPOSE_COMMAND} stop
            ;;
        restart)
            echo "INFO | Restarting docs..."
            ${SUDO_COMMAND} env COMPOSE_PROFILES=docs ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach --force-recreate
            ;;
        logs)
            echo "INFO | Showing docs logs..."
            ${SUDO_COMMAND} env COMPOSE_PROFILES=docs ${TUONI_DOCKER_COMPOSE_COMMAND} logs --tail 100 -f
            ;;
        *)
            echo "WARNING | Invalid docs command. Available commands: start, stop, restart, logs."
            ;;
    esac
}

if ! [[ "$TUONI_COMMAND" =~ ^(${tuoni_commands_regex})$ ]] || [[ "$TUONI_COMMAND" == "help" ]]; then
  cat << EOF
$(tput bold)TUONI Command Line Interface (CLI) - Version $VERSION$(tput sgr0)

$(tput smul)USAGE:$(tput rmul)
    $(tput setaf 2)tuoni <command>$(tput sgr0)
    $(tput setaf 2)tuoni client <command>$(tput sgr0)
    $(tput setaf 2)tuoni server <command>$(tput sgr0)
    $(tput setaf 2)tuoni docs <command>$(tput sgr0)

$(tput smul)AVAILABLE COMMANDS:$(tput rmul)
    $(tput setaf 3)help$(tput sgr0)                   Display help.
    $(tput setaf 3)version$(tput sgr0)                Display version.
    $(tput setaf 3)print-config-file$(tput sgr0)      Display config file.
    $(tput setaf 3)print-credentials$(tput sgr0)      Display tuoni credentials.
    $(tput setaf 3)change-credentials$(tput sgr0)     Change user credentials.
    $(tput setaf 3)start$(tput sgr0)                  Starts the Tuoni dockers.
    $(tput setaf 3)stop$(tput sgr0)                   Stops the Tuoni dockers.
    $(tput setaf 3)restart$(tput sgr0)                Restarts the Tuoni dockers.
    $(tput setaf 3)logs$(tput sgr0)                   Tails the logs for the Tuoni dockers.
    $(tput setaf 3)clean-configuration$(tput sgr0)    Prompt which configuration files to remove and resets them to default.
    $(tput setaf 3)update$(tput sgr0)                 Perform git and docker pull.
    $(tput setaf 3)update-silent$(tput sgr0)          Perform git and docker pull silently.
    $(tput setaf 3)update-docker-images$(tput sgr0)   Perform docker pull.
    $(tput setaf 3)export-docker-images$(tput sgr0)   Export docker images to transfer folder.
    $(tput setaf 3)import-docker-images$(tput sgr0)   Import docker images from transfer folder.
    $(tput setaf 3)transfer-tuoni-package$(tput sgr0) Rsync transfer folder to remote defined in config/tuoni.env.
    $(tput setaf 3)export-tuoni-package$(tput sgr0)   Export current git repository and docker images to transfer folder.
    $(tput setaf 3)import-tuoni-package$(tput sgr0)   Import git repository and docker images from transfer folder.
    
$(tput smul)ADDITIONAL INFORMATION:$(tput rmul)
    Tuoni URL:           $(tput setaf 4)https://${TUONI_HOST_FQDN}:${TUONI_CLIENT_PORT}/$(tput sgr0)
    Tuoni URL Localhost: $(tput setaf 4)https://localhost:${TUONI_CLIENT_PORT}/$(tput sgr0)
    Offline Docs:        $(tput setaf 4)https://${TUONI_HOST_FQDN}:${TUONI_CLIENT_PORT}/tuoni-docs/$(tput sgr0)
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

if [ "$TUONI_COMMAND" == "change-credentials" ]; then
  if [[ "$(printf '%s\n' "0.6.2" "$VERSION" | sort -V | head -n1)" != "0.6.2" ]]; then
    echo "ERROR | This command is only available for Tuoni version 0.6.2 and above."
    exit 1
  fi

  echo "INFO | Start changing credentials ..."
  echo -e "\n\n\n\n\n"

  # Prompt for username
  read -r -p "INPUT | Enter username to change: " input_username </dev/tty
  if [[ -z "$input_username" ]]; then
    echo "ERROR | Username cannot be blank."
    exit 1
  fi

  # Escape username for SQLite
  escaped_username=$(printf '%q' "$input_username")

  # Check if the username exists in the database
  user_exists=$(${SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/data/tuoni-db.sqlite3:/tmp/tuoni-db.sqlite3" \
    -w /tmp --user "$UID:$UID" ${TUONI_UTILITY_IMAGE} sqlite3 /tmp/tuoni-db.sqlite3 \
    "SELECT COUNT(*) FROM users WHERE username='$escaped_username';")

  if [ "$user_exists" -eq 0 ]; then
    echo "ERROR | Username '$input_username' does not exist."
    exit 1
  fi

  # Prompt for password
  read -r -p "INPUT | Enter password for user [$escaped_username]: " input_password </dev/tty
  if [[ -z "$input_password" ]]; then
    echo "ERROR | Password cannot be blank."
    exit 1
  fi

  # Generate bcrypt hash for the password
  HASH=$( ${SUDO_COMMAND} docker run --rm -w /tmp --user "$UID:$UID" \
    ${TUONI_UTILITY_IMAGE} htpasswd -nbB "${input_username}" "${input_password}" | cut -d ":" -f 2 )

  SQL_STATEMENT="UPDATE users SET password='{bcrypt}$HASH' WHERE username='$escaped_username';"

  # Run the SQLite command inside Docker
  ${SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/data/tuoni-db.sqlite3:/tmp/tuoni-db.sqlite3" \
    -w /tmp --user "$UID:$UID" ${TUONI_UTILITY_IMAGE} sqlite3 /tmp/tuoni-db.sqlite3 "$SQL_STATEMENT"

  echo "INFO | Credentials for user '$escaped_username' have been updated ..."

fi

if [ "$TUONI_COMMAND" == "clean-configuration" ]; then
  . "$PROJECT_ROOT/scripts/clean-configuration.sh"
  ${SUDO_COMMAND} env COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach
fi

if [ "$TUONI_COMMAND" == "update" ]; then
  . "$PROJECT_ROOT/scripts/update.sh"
fi

if [ "$TUONI_COMMAND" == "update-silent" ]; then
  SILENT=1 . "$PROJECT_ROOT/scripts/update.sh"
fi

if [ "$TUONI_COMMAND" == "update-docker-images" ]; then
  ${SUDO_COMMAND} env COMPOSE_PROFILES=app,utility ${TUONI_DOCKER_COMPOSE_COMMAND} pull
fi

if [ "$TUONI_COMMAND" == "export-docker-images" ] || [ "$TUONI_COMMAND" == "export-tuoni-package" ]; then
  echo "INFO | Exporting docker images to $PROJECT_ROOT/transfer/tuoni-docker-images.tar ..."
  ${SUDO_COMMAND} rm -f $PROJECT_ROOT/transfer/tuoni-docker-images.tar
  ${SUDO_COMMAND} docker save -o $PROJECT_ROOT/transfer/tuoni-docker-images.tar \
    ghcr.io/shell-dot/tuoni/server:${VERSION} \
    ghcr.io/shell-dot/tuoni/client:${VERSION} \
    ghcr.io/shell-dot/tuoni/utility:${VERSION} \
    ghcr.io/shell-dot/tuoni/docs:${VERSION} \
    nginx:alpine
fi

if [ "$TUONI_COMMAND" == "export-tuoni-package" ]; then
  echo "INFO | Exporting current git repository to $PROJECT_ROOT/transfer/git ..."
  rm -rf $PROJECT_ROOT/transfer/git
  mkdir -p $PROJECT_ROOT/transfer/git
  git clone --mirror $PROJECT_ROOT $PROJECT_ROOT/transfer/git
  echo "INFO | Git repository exported to $PROJECT_ROOT/transfer/git"
fi

if [ "$TUONI_COMMAND" == "import-tuoni-package" ]; then
  echo "INFO | Importing git repository from $PROJECT_ROOT/transfer/git ..."
  cd $PROJECT_ROOT
  if git remote | grep -q transfer; then
    git remote remove transfer
  fi
  git remote add transfer $PROJECT_ROOT/transfer/git
  git fetch transfer
  git pull transfer main
  echo "INFO | Git repository updated from $PROJECT_ROOT/transfer/git"

  TUONI_IMPORT_VERSION=$(cat $PROJECT_ROOT/version.yml | cut -d ' ' -f 2)
  sed -i "s/VERSION=.*/VERSION=${TUONI_IMPORT_VERSION}/g" "$PROJECT_ROOT/config/tuoni.env"
fi

if [ "$TUONI_COMMAND" == "import-docker-images" ] || [ "$TUONI_COMMAND" == "import-tuoni-package" ]; then
  echo "INFO | Importing docker images from $PROJECT_ROOT/transfer/tuoni-docker-images.tar ..."
  ${SUDO_COMMAND} docker load -i $PROJECT_ROOT/transfer/tuoni-docker-images.tar
fi

if [ "$TUONI_COMMAND" == "transfer-tuoni-package" ]; then
  . "$PROJECT_ROOT/scripts/transfer.sh"
fi

if [ "$TUONI_COMMAND" == "logs" ]; then
  ${SUDO_COMMAND} env COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} logs --tail 100 -f
fi

if [ "$TUONI_COMMAND" == "start" ]; then
  ${SUDO_COMMAND} env COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach
  echo "INFO | Tuoni url: https://${TUONI_HOST_FQDN}:${TUONI_CLIENT_PORT}/"
fi

if [ "$TUONI_COMMAND" == "stop" ]; then
  ${SUDO_COMMAND} env COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} stop
fi

if [ "$TUONI_COMMAND" == "restart" ]; then
  ${SUDO_COMMAND} env COMPOSE_PROFILES=${TUONI_COMPONENT} ${TUONI_DOCKER_COMPOSE_COMMAND} up --detach --force-recreate
fi

if [ "$TUONI_COMMAND" == "client" ]; then
  handle_client_command "$TUONI_SUBCOMMAND"
fi

if [ "$TUONI_COMMAND" == "server" ]; then
  handle_server_command "$TUONI_SUBCOMMAND"
fi

if [ "$TUONI_COMMAND" == "docs" ]; then
  handle_docs_command "$TUONI_SUBCOMMAND"
fi

# Display Tuoni URL, username, and password during setup
if [ -n "${TUONI_USERNAME_TO_CONFIG}" ]; then
  echo -e "\n\n\n\n\n"
  echo "INFO | Tuoni url: https://${TUONI_HOST_FQDN}:${TUONI_CLIENT_PORT}/"
  echo "INFO | Tuoni username: ${TUONI_USERNAME_TO_CONFIG}"
  echo "INFO | Tuoni password: ${TUONI_PASSWORD_TO_CONFIG}"
fi
