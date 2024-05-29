#!/bin/bash

set -e

# Function to compare versions
# Returns 0 if the first version is greater than or equal to the second version
version_gte() {
  # Use sort with version sort flag and check the first line
  [ "$1" = "$(echo -e "$1\n$2" | sort -V | tail -n1)" ]
}

docker_installed=0
docker_version_ok=0
docker_compose_version_ok=0

# Check if Docker is installed
if command -v "docker" &>/dev/null; then
  docker_installed=1
  installed_docker_version=$(${SUDO_COMMAND} docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if version_gte "$installed_docker_version" "25.0.0"; then
    docker_version_ok=1
  fi
fi

# Check if Docker Compose is installed and its version
if [ "$docker_installed" -eq 1 ]; then
    # Adjusted command to correctly capture and parse the Docker Compose version
    installed_compose_version=$(${SUDO_COMMAND} docker compose version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | cut -c 2-)
    if version_gte "$installed_compose_version" "2.0.0"; then
        docker_compose_version_ok=1
    fi
fi

# Correct the condition to exit if both Docker and Docker Compose versions are OK
if [ "$docker_version_ok" -eq 1 ] && [ "$docker_compose_version_ok" -eq 1 ]; then
  # Check if the Docker service is running and start it if not
  if ! ${SUDO_COMMAND} systemctl is-active --quiet docker; then
    echo "INFO | Docker service is not running. Starting Docker service..."
    ${SUDO_COMMAND} systemctl start docker
    echo "INFO | Docker service started."
  fi
  #echo "INFO | Docker and Docker Compose meet the required version. Exiting the installation script."
  return;
fi

# If Docker is not installed, proceed without prompt
if [ "$docker_installed" -eq 0 ]; then
  echo "INFO | Docker is not installed, proceeding with installation ..."
# If versions do not meet the requirement, ask if the user wants to continue
else
  echo -e "\n\n\n\n\n"
  echo "WARNING | Docker or Docker Compose do not meet the required version."
  echo "INFO | Docker version: $installed_docker_version, required version: 25.0.0"
  echo "INFO | Docker Compose version: $installed_compose_version, required version: 2.0.0"
  echo "INFO | Before installing new packages, the setup will first remove any existing Docker-related packages if found:"
  echo "       docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc"

  # Skip prompt if SILENT is set to 1  
  if [[ "$SILENT" != "1" ]]; then
    read -r -p "Do you want to proceed with the installation? (y/N): " -n 1 -r </dev/tty
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "\n\n\n\n\n"
      echo "INFO | Docker installation aborted by the user, setup is not complete ..."
      exit 1
    fi
  fi

  ${SUDO_COMMAND} systemctl stop docker --quiet
  ${SUDO_COMMAND} systemctl disable docker --quiet
  # Remove all docker related packages, list taken from docker docs
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do ${SUDO_COMMAND} apt-get remove -y $pkg || true; done
  ${SUDO_COMMAND} systemctl daemon-reload
fi

echo "INFO | Docker installation ..."
echo "INFO | Adding Docker repo for $(lsb_release -cs)..."

if grep -q "ID=ubuntu" /etc/os-release; then

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | ${SUDO_COMMAND} gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --yes
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | ${SUDO_COMMAND} tee /etc/apt/sources.list.d/docker.list > /dev/null

elif grep -q "ID=kali" /etc/os-release; then

  curl -fsSL https://download.docker.com/linux/debian/gpg | ${SUDO_COMMAND} gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --yes
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  bullseye stable" | ${SUDO_COMMAND} tee /etc/apt/sources.list.d/docker.list > /dev/null

elif grep -q "ID=debian" /etc/os-release; then

  curl -fsSL https://download.docker.com/linux/debian/gpg | ${SUDO_COMMAND} gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --yes
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | ${SUDO_COMMAND} tee /etc/apt/sources.list.d/docker.list > /dev/null

fi

${SUDO_COMMAND} apt-get update
${SUDO_COMMAND} apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin
${SUDO_COMMAND} systemctl daemon-reload
${SUDO_COMMAND} systemctl enable docker

# Clear the restart counter for the Docker service
${SUDO_COMMAND} systemctl reset-failed docker.service

set +e

# Check if Docker is running, and start it if not
if ! ${SUDO_COMMAND} systemctl is-active --quiet docker; then
    ${SUDO_COMMAND} systemctl start docker
fi

# Initial sleep duration
sleep_duration=2

# Try to start Docker service up to 10 times
for i in {1..10}; do
    if ${SUDO_COMMAND} systemctl is-active --quiet docker; then
        echo "INFO | Docker is running."
        break
    else
        echo "INFO | Attempt $i to start Docker ..."
        echo "INFO | Sleeping for $sleep_duration seconds..."
        sleep $sleep_duration  # Add a brief delay between attempts
        sleep_duration=$((sleep_duration + 2))  # Increase sleep duration by 2 seconds each time
        ${SUDO_COMMAND} systemctl reset-failed docker.service
        ${SUDO_COMMAND} systemctl start docker
    fi
done

# Final check if Docker failed to start
if ! ${SUDO_COMMAND} systemctl is-active --quiet docker; then
    echo "ERROR | Failed to start Docker after 10 attempts ..."
    exit 1;
fi
