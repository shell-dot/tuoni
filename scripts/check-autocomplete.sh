#!/bin/bash

TUONI_AUTOCOMPLETE_SCRIPT="tuoni-autocomplete.sh"
TUONI_AUTOCOMPLETE_PATH="$PROJECT_ROOT/scripts/$TUONI_AUTOCOMPLETE_SCRIPT"
TUONI_SCRIPT_PATH="$PROJECT_ROOT" # Directory where the tuoni script is located

# Unique identifier for the script inclusion line
COMMENT_TAG="# Tuoni Autocomplete Script"
PATH_COMMENT_TAG="# Tuoni Script Path"

# Initialize variable to track if the shell is supported
SUPPORTED_SHELL=false

# Detect the shell and set the appropriate config file and install location
if [[ $SHELL == */zsh ]]; then
    # Zsh detected
    USER_SHELL_CONFIG_FILE="$HOME/.zshrc"
    SUPPORTED_SHELL=true
elif [[ $SHELL == */bash ]]; then
    # Bash detected
    USER_SHELL_CONFIG_FILE="$HOME/.bashrc"
    SUPPORTED_SHELL=true
else
    echo "WARNING | Unsupported shell. This installer optimally supports Bash and Zsh. Autocomplete installation will be skipped."
fi

if [[ "$SUPPORTED_SHELL" = true ]]; then
    # Prepare the script inclusion line with a comment tag
    INCLUDE_LINE="source $TUONI_AUTOCOMPLETE_PATH $COMMENT_TAG"
    PATH_INCLUDE_LINE="export PATH=\"\$PATH:$TUONI_SCRIPT_PATH\" $PATH_COMMENT_TAG"

    # Update or add the autocomplete source line
    if grep -qF "$COMMENT_TAG" "$USER_SHELL_CONFIG_FILE"; then
        sed -i "/$COMMENT_TAG/c\\$INCLUDE_LINE" "$USER_SHELL_CONFIG_FILE"
    else
        echo "$INCLUDE_LINE" >> "$USER_SHELL_CONFIG_FILE"
        echo "INFO | Autocomplete script installed successfully."
    fi

    # Update or add the PATH export line
    if grep -qF "$PATH_COMMENT_TAG" "$USER_SHELL_CONFIG_FILE"; then
        sed -i "/$PATH_COMMENT_TAG/c\\$PATH_INCLUDE_LINE" "$USER_SHELL_CONFIG_FILE"
    else
        echo "$PATH_INCLUDE_LINE" >> "$USER_SHELL_CONFIG_FILE"
    fi

    if ! which tuoni > /dev/null; then
        echo "INFO | 'tuoni' command not found in your PATH. To use 'tuoni' from any directory, please restart your shell or source your config file:"
        echo "         source $USER_SHELL_CONFIG_FILE"
        echo "INFO | This will activate the autocomplete feature and ensure 'tuoni' can be executed from anywhere."
    fi
fi
