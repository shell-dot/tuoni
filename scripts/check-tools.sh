#!/bin/bash
set -e

# Check if the yq tool is available in the tools directory
if [ ! -f "$PROJECT_ROOT/scripts/tools/yq" ]; then
    echo "INFO | yq missing from $PROJECT_ROOT/scripts/tools, exporting from docker ..."

    # Export yq from the tuoni-utility image
    docker run --rm -v $PROJECT_ROOT/scripts/tools:/scripts ${TUONI_UTILITY_IMAGE} cp /usr/bin/yq /scripts/yq
    
    chmod +x $PROJECT_ROOT/scripts/tools/yq
    echo "INFO | yq has been exported to $PROJECT_ROOT/scripts/tools/yq ..."
fi
