# tuoni-autocomplete.sh

# Define the function for autocompletion
_tuoni_commands() {
    local cur prev commands client_commands server_commands
    commands="help start stop restart logs clean-configuration update update-silent"
    client_commands="start stop restart logs"
    server_commands="start stop restart logs"

    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ ${prev} == "tuoni" ]]; then
        COMPREPLY=($(compgen -W "${commands} client server" -- "${cur}"))
    elif [[ ${COMP_WORDS[1]} == "client" ]]; then
        COMPREPLY=($(compgen -W "${client_commands}" -- "${cur}"))
    elif [[ ${COMP_WORDS[1]} == "server" ]]; then
        COMPREPLY=($(compgen -W "${server_commands}" -- "${cur}"))
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
