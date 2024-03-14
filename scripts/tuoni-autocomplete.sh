# tuoni-autocomplete.sh

# Define the function for autocompletion
_tuoni_commands() {
    local commands="start stop restart logs clean-configuration update"

    if [ -n "$BASH_VERSION" ]; then
        # Bash: Use COMPREPLY for completion replies
        COMPREPLY=($(compgen -W "${commands}" -- "${COMP_WORDS[COMP_CWORD]}"))
    elif [ -n "$ZSH_VERSION" ]; then
        # Zsh: Directly specify matches for completion
        local -a matches
        matches=($(echo ${commands}))
        _describe -t commands 'tuoni command' matches
    fi
}

# Register the completion function
if [ -n "$ZSH_VERSION" ]; then
    # For Zsh: Use compdef
    compdef _tuoni_commands tuoni
elif [ -n "$BASH_VERSION" ]; then
    # For Bash: Use complete
    complete -F _tuoni_commands tuoni
fi
