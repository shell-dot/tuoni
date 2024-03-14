# tuoni-autocomplete.sh

# Function to add autocomplete for tuoni commands
_tuoni_commands() {
    local commands="start stop restart logs clean-configuration update"

    # Bash
    if [ -n "$BASH_VERSION" ]; then
        COMPREPLY=($(compgen -W "${commands}" -- "${COMP_WORDS[COMP_CWORD]}"))
    fi

    # Zsh
    if [ -n "$ZSH_VERSION" ]; then
        reply=($(compgen -W "${commands}" -- "${words[CURRENT]}"))
    fi
}

# Check if we're using Zsh or Bash and setup autocomplete
if [ -n "$ZSH_VERSION" ]; then
    # Use compdef for Zsh
    autoload -U +X compinit && compinit
    autoload -U +X bashcompinit && bashcompinit
    compdef _tuoni_commands tuoni
elif [ -n "$BASH_VERSION" ]; then
    # Use complete for Bash
    complete -F _tuoni_commands tuoni
fi
