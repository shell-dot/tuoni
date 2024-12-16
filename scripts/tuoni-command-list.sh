#!/bin/bash

tuoni_commands_array=(
    "help" \
    "version" \
    "print-config-file" \
    "print-credentials" \
    "change-credentials" \
    "start" \
    "stop" \
    "restart" \
    "logs" \
    "clean-configuration" \
    "update" \
    "update-silent" \
    "update-docker-images" \
    "export-docker-images" \
    "import-docker-images" \
    "transfer-tuoni-package" \
    "export-tuoni-package" \
    "import-tuoni-package" \
    "client" \
    "server" \
    "docs"
    )
tuoni_client_commands_array=("start" "stop" "restart" "logs")
tuoni_server_commands_array=("start" "stop" "restart" "logs")
tuoni_docs_commands_array=("start" "stop" "restart" "logs")

# Join arrays into space-separated strings for Bash
tuoni_commands="${tuoni_commands_array[*]}"
tuoni_client_commands="${tuoni_client_commands_array[*]}"
tuoni_server_commands="${tuoni_server_commands_array[*]}"
tuoni_docs_commands="${tuoni_docs_commands_array[*]}"

# Join arrays into a pipe-separated string for regex
tuoni_commands_regex=$(IFS='|'; echo "${tuoni_commands_array[*]}")
