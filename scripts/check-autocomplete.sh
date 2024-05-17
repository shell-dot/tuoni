#!/bin/bash

TUONI_AUTOCOMPLETE_SCRIPT="tuoni-autocomplete.sh"
TUONI_AUTOCOMPLETE_PATH="$PROJECT_ROOT/scripts/$TUONI_AUTOCOMPLETE_SCRIPT"
TUONI_SCRIPT_PATH="$PROJECT_ROOT" # Directory where the tuoni script is located

# Unique identifier for the script inclusion line
COMMENT_TAG="# Tuoni Autocomplete Script"
PATH_COMMENT_TAG="# Tuoni Script Path"

# Adjusted INCLUDE_LINE with a runtime existence check
INCLUDE_LINE="if [ -f \"$TUONI_AUTOCOMPLETE_PATH\" ]; then source \"$TUONI_AUTOCOMPLETE_PATH\"; fi # Tuoni Autocomplete Script"
PATH_INCLUDE_LINE="export PATH=\"\$PATH:$TUONI_SCRIPT_PATH\" $PATH_COMMENT_TAG"

# Function to update shell configuration file
update_shell_config() {
    local config_file="$1"

    # Update or add the autocomplete source line with existence check
    if grep -qF "$COMMENT_TAG" "$config_file"; then
        sed -i "/$COMMENT_TAG/c\\$INCLUDE_LINE" "$config_file"
    else
        echo -e "\n$INCLUDE_LINE" >> "$config_file"
        echo "INFO | Autocomplete script check added to $config_file."
    fi

    # Update or add the PATH export line
    if grep -qF "$PATH_COMMENT_TAG" "$config_file"; then
        sed -i "/$PATH_COMMENT_TAG/c\\$PATH_INCLUDE_LINE" "$config_file"
    else
        echo "$PATH_INCLUDE_LINE" >> "$config_file"
    fi
}

# Check and update .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    update_shell_config "$HOME/.bashrc"
fi

# Check and update .zshrc if it exists
if [ -f "$HOME/.zshrc" ]; then
    update_shell_config "$HOME/.zshrc"
fi

# Check if the 'tuoni' command is accessible in the PATH
if ! which tuoni > /dev/null; then
    echo "WARNING | 'tuoni' command not found in your PATH. To use 'tuoni' from any directory, please restart your shell or source your shell configuration file:"
    echo "         source ~/.bashrc or source ~/.zshrc"
    echo "INFO | This will activate the autocomplete feature and ensure 'tuoni' can be executed from anywhere."
fi
