#!/bin/bash

set -e

TUONI_PLUGINS_URI="https://api.tuoni.io/tuoni"
TUONI_PLUGINS_TEMP_FILE="/tmp/tuoni-plugins.zip"

echo "Updating Tuoni plugins..."

# Checking if Tuoni licence key is set as env variable, if not then asking it from user
if [[ -z "${TUONI_LICENCE_KEY}" ]]; then
    read -rp "Please enter your Tuoni licence key: " TUONI_LICENCE_KEY
    export TUONI_LICENCE_KEY
fi

# Checking that the Tuoni licence key variable is not empty
if [[ -z "${TUONI_LICENCE_KEY}" ]]; then
    echo "Tuoni licence key is not set. Please set the TUONI_LICENCE_KEY environment variable or provide it when prompted."
    exit 1
fi

# Verifying the Tuoni licence key is correct
CURRENT_DATE=$(date +%s) # Getting the date in an unix timestamp format
LICENCE_TOKEN=$(echo -n "${TUONI_LICENCE_KEY}:${CURRENT_DATE}" | sha256sum | cut -d ' ' -f1)
LICENCE_KEY_VALID=$(curl --request POST "${TUONI_PLUGINS_URI}" \
    --silent \
    --data '{
        "timestamp": '"${CURRENT_DATE}"',
        "hashedToken": "'"${LICENCE_TOKEN}"'",
        "version": "'"${TUONI_VERSION}"'"
    }')

# Check if the response contains "Invalid token"
if echo "$LICENCE_KEY_VALID" | grep -q "Invalid token"; then
    echo "Error: Invalid license token. Please check your Tuoni license key."
    exit 1
fi

if [[ -z "${SILENT}" ]]; then

    CURRENT_DATE=$(date +%s) # Getting the date in an unix timestamp format
    LICENCE_TOKEN=$(echo -n "${TUONI_LICENCE_KEY}:${CURRENT_DATE}" | sha256sum | cut -d ' ' -f1)
    AVAILABLE_VERSIONS=$(curl --request POST "${TUONI_PLUGINS_URI}" \
        --silent \
        --data '{
            "timestamp": '"${CURRENT_DATE}"',
            "hashedToken": "'"${LICENCE_TOKEN}"'",
            "version": "'"${TUONI_VERSION}"'"
        }')

    echo "Available versions:"
    mapfile -t VERSIONS < <(echo "$AVAILABLE_VERSIONS" | jq -r '.resources.versions[].name')

    if [ ${#VERSIONS[@]} -eq 0 ]; then
        echo "No versions available"
        exit 0
    fi

    # Display versions with numbers
    for i in "${!VERSIONS[@]}"; do
        echo "  $((i+1)). ${VERSIONS[$i]}"
    done

    # Prompt for selection
    read -rp "Select version number (or press Enter for latest): " VERSION_SELECTION

    # Default to the latest (first) version if no selection
    if [[ -z "$VERSION_SELECTION" ]]; then
        TUONI_VERSION="${VERSIONS[0]}"
    else
        # Adjust for zero-based indexing
        SELECTED_INDEX=$((VERSION_SELECTION-1))

        # Validate selection
        if [[ $SELECTED_INDEX -ge 0 && $SELECTED_INDEX -lt ${#VERSIONS[@]} ]]; then
            TUONI_VERSION="${VERSIONS[$SELECTED_INDEX]}"
        else
            echo "Invalid selection. Using latest version: ${VERSIONS[0]}"
            TUONI_VERSION="${VERSIONS[0]}"
        fi
    fi

    echo "Selected version: $TUONI_VERSION"

else

    # Checking if Tuoni version is defined in the environment variable, if not then reading it from the config file
    if [[ -z "${TUONI_VERSION}" ]]; then
        TUONI_VERSION=$(grep VERSION "${PROJECT_ROOT}/config/tuoni.env" | cut -d '=' -f2)
    fi

fi

# Remove temp file if it exists to ensure clean download
${TUONI_SUDO_COMMAND} rm -f "${TUONI_PLUGINS_TEMP_FILE}"

# Downloading the plugins zip file
echo "Downloading Tuoni plugins version ${TUONI_VERSION}..."
CURRENT_DATE=$(date +%s) # Getting the date in an unix timestamp format
LICENCE_TOKEN=$(echo -n "${TUONI_LICENCE_KEY}:${CURRENT_DATE}" | sha256sum | cut -d ' ' -f1)
curl "${TUONI_PLUGINS_URI}" \
    --silent \
    --location \
    --output "${TUONI_PLUGINS_TEMP_FILE}" \
    --data '{
        "timestamp": '"${CURRENT_DATE}"',
        "hashedToken": "'"${LICENCE_TOKEN}"'",
        "action": "download",
        "version": "'"${TUONI_VERSION}"'"
    }'

# if SILENT is not defined in the environment variable, then ask the user if they want to overwrite the existing files
if [[ -z "${SILENT}" ]]; then
    read -rp "The update will overwrite the existing plugins in ${PROJECT_ROOT}/plugins do you want to contionue? (y/n): " OVERWRITE_FILES
    if [[ "${OVERWRITE_FILES}" != "y" ]]; then
        echo Update cancelled
        exit 0
    fi
fi

# Unzipping the downloaded file to the plugins directory, overwriting any existing files
unzip -oq "${TUONI_PLUGINS_TEMP_FILE}" -d "${PROJECT_ROOT}"

# Remove temp file after unzipping
${TUONI_SUDO_COMMAND} rm -f "${TUONI_PLUGINS_TEMP_FILE}"

echo "Updated Tuoni plugins in ${PROJECT_ROOT}/plugins folder"