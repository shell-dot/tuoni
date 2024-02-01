#!/bin/bash

set -e

if command -v "docker" &>/dev/null; then
  return;
fi

echo "INFO | Docker is not found, installing ..."
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
