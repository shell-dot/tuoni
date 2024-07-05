# tuoni-autocomplete.sh

if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR=$(dirname "$0:A")
elif [ -n "$BASH_VERSION" ]; then
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

# Source the command definitions
. $SCRIPT_DIR/tuoni-command-list.sh

# Define the function for autocompletion
_tuoni_commands() {
    local cur prev 

    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ ${prev} == "tuoni" ]]; then
        COMPREPLY=($(compgen -W "${tuoni_commands} client server docs" -- "${cur}"))
    elif [[ ${COMP_WORDS[1]} == "client" ]]; then
        COMPREPLY=($(compgen -W "${tuoni_client_commands}" -- "${cur}"))
    elif [[ ${COMP_WORDS[1]} == "server" ]]; then
        COMPREPLY=($(compgen -W "${tuoni_server_commands}" -- "${cur}"))
    elif [[ ${COMP_WORDS[1]} == "docs" ]]; then
        COMPREPLY=($(compgen -W "${tuoni_docs_commands}" -- "${cur}"))        
    fi
}

# Zsh-specific autocompletion function
_tuoni_commands_zsh() {
    _arguments -C \
        '1: :->command' \
        '2: :->subcommand' \
        '*::arg:->args'

    case "$state" in
        command)
            _describe -t tuoni_commands_array 'tuoni commands' tuoni_commands_array
            ;;
        subcommand)
            if [[ ${words[2]} == "client" ]]; then
                _describe -t tuoni_client_commands_array 'tuoni client commands' tuoni_client_commands_array
            elif [[ ${words[2]} == "server" ]]; then
                _describe -t tuoni_server_commands_array 'tuoni server commands' tuoni_server_commands_array
            elif [[ ${words[2]} == "docs" ]]; then
                _describe -t tuoni_docs_commands_array 'tuoni docs commands' tuoni_docs_commands_array
            fi
            ;;
    esac
}

# Register the completion function
if [ -n "$ZSH_VERSION" ]; then
    # For Zsh: Use compdef
    compdef _tuoni_commands_zsh tuoni
elif [ -n "$BASH_VERSION" ]; then
    # For Bash: Use complete
    complete -F _tuoni_commands tuoni
fi
