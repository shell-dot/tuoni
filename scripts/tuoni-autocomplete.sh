# tuoni-autocomplete.sh

# Define the function for autocompletion
_tuoni_commands() {
    local cur prev commands client_commands server_commands
    commands="help version print-config-file print-credentials start stop restart logs clean-configuration update update-silent"
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

# Zsh-specific autocompletion function
_tuoni_commands_zsh() {
    local -a commands client_commands server_commands
    commands=("help" "version" "print-config-file" "print-credentials" "start" "stop" "restart" "logs" "clean-configuration" "update" "update-silent" "client" "server")
    client_commands=("start" "stop" "restart" "logs")
    server_commands=("start" "stop" "restart" "logs")

    _arguments -C \
        '1: :->command' \
        '2: :->subcommand' \
        '*::arg:->args'

    case "$state" in
        command)
            _describe -t commands 'tuoni commands' commands
            ;;
        subcommand)
            if [[ ${words[2]} == "client" ]]; then
                _describe -t client_commands 'tuoni client commands' client_commands
            elif [[ ${words[2]} == "server" ]]; then
                _describe -t server_commands 'tuoni server commands' server_commands
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
