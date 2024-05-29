#!/bin/bash

set -e

TUONI_ENV_FILE_PATH="$PROJECT_ROOT/config/tuoni.env"
TUONI_CONFIG_FILE_PATH="$PROJECT_ROOT/config/tuoni.yml"
TUONI_CONFIG_EXAMPLE_FILE_PATH="$PROJECT_ROOT/config/example/example.tuoni.yml"

if [ ! -f "$PROJECT_ROOT/config/tuoni.env" ]; then
    echo "INFO | config/tuoni.env file not found, creating ..."
    cp $PROJECT_ROOT/config/example/example.tuoni.env ${TUONI_ENV_FILE_PATH}
fi

if [ ! -f "$PROJECT_ROOT/config/tuoni.yml" ]; then
    echo "INFO | config/tuoni.yml file not found, creating ..."
    cp $PROJECT_ROOT/config/example/example.tuoni.yml ${TUONI_CONFIG_FILE_PATH}

    AUTOGENERATED_USERNAME=tuoni
    AUTOGENERATED_PASSWORD=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 32)

    TUONI_USERNAME_TO_CONFIG=${TUONI_USERNAME:-${AUTOGENERATED_USERNAME}}
    TUONI_PASSWORD_TO_CONFIG=${TUONI_PASSWORD:-${AUTOGENERATED_PASSWORD}}
    if [[ "$SILENT" != "1" ]]; then
        echo -e "\n\n\n\n\n"
        echo "INFO | Tuoni username and password not found in config, select your own or use the pregenerated options by hitting enter ..."
        read -r -p "INPUT | Enter Tuoni username [$TUONI_USERNAME_TO_CONFIG]: " input_username </dev/tty
        read -r -p "INPUT | Enter Tuoni password [$TUONI_PASSWORD_TO_CONFIG]: " input_password </dev/tty

        # Assign only if user has provided an input
        if [[ -n "$input_username" ]]; then
            TUONI_USERNAME_TO_CONFIG="$input_username"
        fi
        if [[ -n "$input_password" ]]; then
            TUONI_PASSWORD_TO_CONFIG="$input_password"
        fi
    fi

    YQ_USERNAME=${TUONI_USERNAME_TO_CONFIG} $PROJECT_ROOT/scripts/tools/yq '.tuoni.auth.credentials.username=strenv(YQ_USERNAME)' --inplace $TUONI_CONFIG_FILE_PATH
    YQ_PASSWORD=${TUONI_PASSWORD_TO_CONFIG} $PROJECT_ROOT/scripts/tools/yq '.tuoni.auth.credentials.password=strenv(YQ_PASSWORD)' --inplace $TUONI_CONFIG_FILE_PATH
fi

# Check if 'client' attribute exists, pre 0.3.2
if [[ ! $($PROJECT_ROOT/scripts/tools/yq '.client.port' $TUONI_CONFIG_FILE_PATH) =~ ^[0-9]+$ ]]; then
  echo "INFO | 'client' attribute is missing or invalid in config, adding it..."
  $PROJECT_ROOT/scripts/tools/yq '.client = load("'$TUONI_CONFIG_EXAMPLE_FILE_PATH'").client' --inplace $TUONI_CONFIG_FILE_PATH 
fi

for dir in data logs/server logs/client logs/nginx payload-templates plugins; do
    if [ ! -d "$PROJECT_ROOT/$dir" ]; then
        echo "INFO | $dir directory not found, creating ..."
        mkdir -p "$PROJECT_ROOT/$dir"
    fi
done

### Check if we have server log in the old location, move it if so, pre 0.3.2 
if [ -f "$PROJECT_ROOT/logs/tuoni-server.log" ]; then
  echo "INFO | logs/tuoni-server.log found, moving to logs/server folder ..."
  ${SUDO_COMMAND} mv $PROJECT_ROOT/logs/tuoni-server.lo* $PROJECT_ROOT/logs/server/
fi

### check if logs/client folder has 1000:1000, and apply if needed
if [ "$(stat -c "%u:%g" "$PROJECT_ROOT/logs/client")" != "1000:1000" ]; then
  echo "INFO | ownership of $PROJECT_ROOT/logs/client will be changed to 1000:1000 ..."
  # Change the ownership to 1000:1000
  chown -R 1000:1000 "$PROJECT_ROOT/logs/client"
fi

if [ ! -f "$PROJECT_ROOT/ssl/server/server-selfsigned.keystore" ]; then
    echo "INFO | ssl/server/server-selfsigned.keystore file not found, creating ..."
    echo $PROJECT_ROOT
    ${SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/server:/tmp" -v "${PROJECT_ROOT}/ssl/server:/tmp/hsperfdata_root" -w /tmp --user "$UID:$UID" openjdk:21-jdk-slim-bookworm \
      keytool -genkey -alias selfsigned \
      -keyalg RSA \
      -keystore server-selfsigned.keystore \
      -validity 3650\
      -storetype JKS \
      -dname "CN=localhost, OU=Tuoni, O=ShellDot, L=Tallinn, C=Estonia" \
      -keypass selfsigned -storepass \
      selfsigned
    ${SUDO_COMMAND} rmdir "${PROJECT_ROOT}/ssl/server/hsperfdata_root"
fi

if [ ! -f "$PROJECT_ROOT/ssl/server/server-private.pem" ]; then
    echo "INFO | ssl/server/server-private.pem file not found, creating ..."
    ${SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/server:/tmp" -w /tmp --user "$UID:$UID" openjdk:21-jdk-slim-bookworm \
      openssl genpkey -algorithm RSA -out server.pem -pkeyopt rsa_keygen_bits:2048
    ${SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/server:/tmp" -w /tmp --user "$UID:$UID" openjdk:21-jdk-slim-bookworm \
      openssl rsa -pubout -in server.pem -out server-public.pem
    ${SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/server:/tmp" -w /tmp --user "$UID:$UID" openjdk:21-jdk-slim-bookworm \
      openssl pkcs8 -topk8 -in server.pem -nocrypt -out server-private.pem
fi

if [ ! -f "$PROJECT_ROOT/ssl/client/client-private.pem" ]; then
    echo "INFO | ssl/client/client-private.pem file not found, creating ..."
    ${SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/client:/tmp" -w /tmp --user "$UID:$UID" openjdk:21-jdk-slim-bookworm \
      openssl genpkey -algorithm RSA -out client-private.pem -pkeyopt rsa_keygen_bits:2048

    ${SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/client:/tmp" -w /tmp --user "$UID:$UID" openjdk:21-jdk-slim-bookworm \
      openssl req -new -key client-private.pem -x509 -days 365 -out client.crt -subj "/C=EE/ST=YourState/L=YourCity/O=YourOrganization/CN=yourdomain.com"
fi

if [ ! -f "$PROJECT_ROOT/nginx/tuoni.conf" ]; then
    echo "INFO | nginx/tuoni.conf file not found, creating ..."
    cp $PROJECT_ROOT/nginx/example/example.tuoni.conf $PROJECT_ROOT/nginx/tuoni.conf
fi

### make sure nginx has correct listen port from tuoni config file
TUONI_CLIENT_PORT=$($PROJECT_ROOT/scripts/tools/yq '.client.port' $TUONI_CONFIG_FILE_PATH)
sed -i "s/\(listen \)[0-9]\+\(.*\)/\1$TUONI_CLIENT_PORT\2/" $PROJECT_ROOT/nginx/tuoni.conf

${SUDO_COMMAND} chown $USER:$USER -R "${PROJECT_ROOT}/ssl"
${SUDO_COMMAND} chmod +r "${PROJECT_ROOT}/ssl"/*
