#!/bin/bash
set -e

# Check if the yq tool is available in the tools directory
if [ ! -f "$PROJECT_ROOT/scripts/tools/yq" ]; then
    echo "INFO | yq missing from $PROJECT_ROOT/scripts/tools, exporting from docker ..."

    # Export yq from the tuoni-utility image
    ${SUDO_COMMAND} docker run --rm -v "$PROJECT_ROOT/scripts/tools:/tools" "${TUONI_UTILITY_IMAGE}" cp /usr/bin/yq /tools/yq
    
    # Make the yq tool executable
    ${SUDO_COMMAND} chmod +x "$PROJECT_ROOT/scripts/tools/yq"
    echo "INFO | yq has been exported to $PROJECT_ROOT/scripts/tools/yq ..."
fi
