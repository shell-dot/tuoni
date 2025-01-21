#!/bin/bash

set -e

# Define file paths
TUONI_ENV_FILE_PATH="$PROJECT_ROOT/config/tuoni.env"
TUONI_CONFIG_FILE_PATH="$PROJECT_ROOT/config/tuoni.yml"
TUONI_CONFIG_EXAMPLE_FILE_PATH="$PROJECT_ROOT/config/example/example.tuoni.yml"

# Check if tuoni.env file exists, create if not
if [ ! -f "$TUONI_ENV_FILE_PATH" ]; then
  echo "INFO | config/tuoni.env file not found, creating ..."
  cp $PROJECT_ROOT/config/example/example.tuoni.env ${TUONI_ENV_FILE_PATH}
fi

# Use the Tuoni version from env
if [[ ! -z "${TUONI_VERSION+x}" ]]; then
  sed -i "s/VERSION=.*/VERSION=${TUONI_VERSION}/g" ${TUONI_ENV_FILE_PATH}
fi

# Check if TUONI_DOCKER_IPV6_ENABLED variable is set
if [ "$TUONI_DOCKER_IPV6_ENABLED" ]; then
  # Remove existing TUONI_DOCKER_IPV6_ENABLED entry
  sed -i '/^TUONI_DOCKER_IPV6_ENABLED=/d' $TUONI_ENV_FILE_PATH

  # Ensure the file ends with a newline before appending, only if the file is non-empty
  if [ -s "$TUONI_ENV_FILE_PATH" ] && [ "$(tail -c 1 "$TUONI_ENV_FILE_PATH")" != "" ]; then
    echo "" >> "$TUONI_ENV_FILE_PATH"
  fi
  
  echo "TUONI_DOCKER_IPV6_ENABLED=$TUONI_DOCKER_IPV6_ENABLED" >> $TUONI_ENV_FILE_PATH
fi

# Check if tuoni.yml file exists, create if not
if [ ! -f "$TUONI_CONFIG_FILE_PATH" ]; then
  echo "INFO | config/tuoni.yml file not found, creating ..."
  cp $PROJECT_ROOT/config/example/example.tuoni.yml ${TUONI_CONFIG_FILE_PATH}

  # Generate default username and password
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

  # Update the configuration file with the username and password
  YQ_USERNAME=${TUONI_USERNAME_TO_CONFIG} $PROJECT_ROOT/scripts/tools/yq '.tuoni.auth.credentials.username=strenv(YQ_USERNAME)' --inplace $TUONI_CONFIG_FILE_PATH
  YQ_PASSWORD=${TUONI_PASSWORD_TO_CONFIG} $PROJECT_ROOT/scripts/tools/yq '.tuoni.auth.credentials.password=strenv(YQ_PASSWORD)' --inplace $TUONI_CONFIG_FILE_PATH
fi

# Check if 'client' attribute exists, pre 0.3.2
if [[ ! $($PROJECT_ROOT/scripts/tools/yq '.client.port' $TUONI_CONFIG_FILE_PATH) =~ ^[0-9]+$ ]]; then
  echo "INFO | 'client' attribute is missing or invalid in config, adding ..."
  $PROJECT_ROOT/scripts/tools/yq '.client = load("'$TUONI_CONFIG_EXAMPLE_FILE_PATH'").client' --inplace $TUONI_CONFIG_FILE_PATH 
fi

# Ensure necessary directories exist
for dir in data logs/server logs/client logs/nginx payload-templates plugins transfer; do
  if [ ! -d "$PROJECT_ROOT/$dir" ]; then
    echo "INFO | $dir directory not found, creating ..."
    mkdir -p "$PROJECT_ROOT/$dir"
  fi
done

# Ensure correct ownership of logs/client folder
if [ "$(stat -c "%u:%g" "$PROJECT_ROOT/logs/client")" != "1000:1000" ]; then
  echo "INFO | ownership of $PROJECT_ROOT/logs/client will be changed to 1000:1000 ..."
  ${TUONI_SUDO_COMMAND} chown -R 1000:1000 "$PROJECT_ROOT/logs/client"
fi

# Move old server log to new location, pre 0.3.2
if [ -f "$PROJECT_ROOT/logs/tuoni-server.log" ]; then
  echo "INFO | logs/tuoni-server.log found, moving to logs/server folder ..."
  ${TUONI_SUDO_COMMAND} mv $PROJECT_ROOT/logs/tuoni-server.lo* $PROJECT_ROOT/logs/server/
fi

# Ensure server keystore exists
if [ ! -f "$PROJECT_ROOT/ssl/server/server-selfsigned.keystore" ]; then
  echo "INFO | ssl/server/server-selfsigned.keystore file not found, creating ..."
  
  if [ -d "$PROJECT_ROOT/ssl/server/hsperfdata_root" ]; then
    ${TUONI_SUDO_COMMAND} rmdir "${PROJECT_ROOT}/ssl/server/hsperfdata_root"
  fi

  ${TUONI_SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/server:/tmp" -w /tmp --user "$UID:$UID" ${TUONI_UTILITY_IMAGE} \
    keytool -genkey -alias selfsigned \
    -keyalg RSA \
    -keystore server-selfsigned.keystore \
    -validity 3650 \
    -storetype JKS \
    -dname "CN=localhost, OU=Tuoni, O=ShellDot, L=Tallinn, C=Estonia" \
    -keypass selfsigned -storepass selfsigned
  ${TUONI_SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/server:/tmp" -w /tmp --user "$UID:$UID" ${TUONI_UTILITY_IMAGE} \
    keytool -exportcert -alias selfsigned \
    -keystore server-selfsigned.keystore \
    -file /tmp/server-certificate.crt \
    -rfc -storepass selfsigned
fi

# Ensure server private key exists
if [ ! -f "$PROJECT_ROOT/ssl/server/server-private.pem" ]; then
  echo "INFO | ssl/server/server-private.pem file not found, creating ..."
  ${TUONI_SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/server:/tmp" -w /tmp --user "$UID:$UID" ${TUONI_UTILITY_IMAGE} \
    openssl genpkey -algorithm RSA -out server.pem -pkeyopt rsa_keygen_bits:2048
  ${TUONI_SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/server:/tmp" -w /tmp --user "$UID:$UID" ${TUONI_UTILITY_IMAGE} \
    openssl rsa -pubout -in server.pem -out server-public.pem
  ${TUONI_SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/server:/tmp" -w /tmp --user "$UID:$UID" ${TUONI_UTILITY_IMAGE} \
    openssl pkcs8 -topk8 -in server.pem -nocrypt -out server-private.pem
fi

# Ensure client private key exists
if [ ! -f "$PROJECT_ROOT/ssl/client/client-private.pem" ]; then
  echo "INFO | ssl/client/client-private.pem file not found, creating ..."
  ${TUONI_SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/client:/tmp" -w /tmp --user "$UID:$UID" ${TUONI_UTILITY_IMAGE} \
    openssl genpkey -algorithm RSA -out client-private.pem -pkeyopt rsa_keygen_bits:2048
  ${TUONI_SUDO_COMMAND} docker run --rm -v "${PROJECT_ROOT}/ssl/client:/tmp" -w /tmp --user "$UID:$UID" ${TUONI_UTILITY_IMAGE} \
    openssl req -new -key client-private.pem -x509 -days 365 -out client.crt -subj "/C=EE/ST=YourState/L=YourCity/O=YourOrganization/CN=yourdomain.com"
fi

# Ensure nginx configuration file exists
if [ ! -f "$PROJECT_ROOT/nginx/tuoni.conf" ]; then
  echo "INFO | nginx/tuoni.conf file not found, creating ..."
  cp $PROJECT_ROOT/nginx/example/example.tuoni.conf $PROJECT_ROOT/nginx/tuoni.conf
fi

# Update nginx listen port from tuoni config file
TUONI_CLIENT_PORT=$($PROJECT_ROOT/scripts/tools/yq '.client.port' $TUONI_CONFIG_FILE_PATH)
awk -i inplace -v port="$TUONI_CLIENT_PORT" '
    BEGIN { in_server=0; server_count=0 }
    /^server\s*{/ {
        server_count++
        if (server_count == 1) in_server=1
        else in_server=0
    }
    {
        if (in_server && /^\s*listen\s/) {
            # Use gensub for proper backreference handling
            $0 = gensub(/(listen\s(\[::\]:)?)[0-9]+(.*)/, "\\1" port "\\3", 1)
        }
        print
        if (in_server && /^}/) {
            in_server=0
        }
    }
' $PROJECT_ROOT/nginx/tuoni.conf

# Ensure correct permissions for ssl directory
${TUONI_SUDO_COMMAND} chown $USER:$USER -R "${PROJECT_ROOT}/ssl"
${TUONI_SUDO_COMMAND} chmod +r "${PROJECT_ROOT}/ssl"/*
